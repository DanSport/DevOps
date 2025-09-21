#!/usr/bin/env bash
set -euo pipefail

: "${AWS_REGION:?Set AWS_REGION}"
: "${VPC_ID:?Set VPC_ID}"

echo "== Clean VPC $VPC_ID in $AWS_REGION =="

# --- 0. Підчистити EKS ELB/TargetGroups (інколи лишаються після кластерів)
echo "[ELBv2] Delete Target Groups in VPC..."
for TG in $(aws elbv2 describe-target-groups --region "$AWS_REGION" \
  --query "TargetGroups[?VpcId=='$VPC_ID'].TargetGroupArn" --output text); do
  aws elbv2 delete-target-group --region "$AWS_REGION" --target-group-arn "$TG" || true
done

echo "[ELBv2] Delete ALB/NLB in VPC..."
for ALB in $(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
  --query "LoadBalancers[?VpcId=='$VPC_ID'].LoadBalancerArn" --output text); do
  aws elbv2 delete-load-balancer --region "$AWS_REGION" --load-balancer-arn "$ALB" || true
done

# Класичні ELB
echo "[ELB classic] Delete CLB in VPC..."
for NAME in $(aws elb describe-load-balancers --region "$AWS_REGION" \
  --query "LoadBalancerDescriptions[?VPCId=='$VPC_ID'].LoadBalancerName" --output text 2>/dev/null || true); do
  aws elb delete-load-balancer --region "$AWS_REGION" --load-balancer-name "$NAME" || true
done

echo "Waiting ELBv2/ELB to disappear..."
for i in {1..40}; do
  CNT_V2=$(aws elbv2 describe-load-balancers --region "$AWS_REGION" \
    --query "length(LoadBalancers[?VpcId=='$VPC_ID'])" --output text 2>/dev/null || echo 0)
  CNT_CLB=$(aws elb describe-load-balancers --region "$AWS_REGION" \
    --query "length(LoadBalancerDescriptions[?VPCId=='$VPC_ID'])" --output text 2>/dev/null || echo 0)
  [[ "$CNT_V2" == "0" && "$CNT_CLB" == "0" ]] && break
  sleep 10
done
echo "OK: ELB are gone (or none)."

# --- 1. NAT Gateways + їхні EIP
echo "[NAT] Delete NAT Gateways..."
# Зберемо всі allocation-id від NAT, щоб потім релізнути EIP
ALL_EIPS=()
for NGW in $(aws ec2 describe-nat-gateways --region "$AWS_REGION" \
  --filter Name=vpc-id,Values="$VPC_ID" \
  --query 'NatGateways[].NatGatewayId' --output text); do
  mapfile -t EIPS < <(aws ec2 describe-nat-gateways --region "$AWS_REGION" \
     --nat-gateway-ids "$NGW" \
     --query 'NatGateways[].NatGatewayAddresses[].AllocationId' --output text)
  ALL_EIPS+=("${EIPS[@]}")
  aws ec2 delete-nat-gateway --region "$AWS_REGION" --nat-gateway-id "$NGW" || true
done

# Чекаємо повне видалення NAT
for i in {1..60}; do
  LEFT=$(aws ec2 describe-nat-gateways --region "$AWS_REGION" \
    --filter Name=vpc-id,Values="$VPC_ID" \
    --query 'length(NatGateways[?State!=`deleted`])' --output text)
  [[ "$LEFT" == "0" ]] && break
  sleep 10
done
echo "OK: NAT Gateways deleted."

# Реліз EIP, що належали NAT (після видалення NGW вони розасоційовані, але ще виділені)
echo "[EIP] Release NAT EIPs (if any)..."
for ALLOC in "${ALL_EIPS[@]:-}"; do
  [[ -n "${ALLOC:-}" && "${ALLOC:-None}" != "None" ]] && \
    aws ec2 release-address --region "$AWS_REGION" --allocation-id "$ALLOC" || true
done

# Також релізнемо будь-які інші EIP у цій VPC (на випадок, якщо лишились)
for EIP_ALLOC in $(aws ec2 describe-addresses --region "$AWS_REGION" \
  --query "Addresses[?AssociationId==null].AllocationId" --output text); do
  aws ec2 release-address --region "$AWS_REGION" --allocation-id "$EIP_ALLOC" || true
done

# --- 2. ENI з public-ip (після NAT/ELB зазвичай нема, але перевіримо)
echo "[ENI] Cleanup public-associated ENI..."
for ENI in $(aws ec2 describe-network-interfaces --region "$AWS_REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" Name=association.public-ip,Values='*' \
  --query 'NetworkInterfaces[].NetworkInterfaceId' --output text); do
  ATTACH_ID=$(aws ec2 describe-network-interfaces --region "$AWS_REGION" \
    --network-interface-ids "$ENI" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text)
  if [[ "$ATTACH_ID" != "None" ]]; then
    aws ec2 detach-network-interface --region "$AWS_REGION" --attachment-id "$ATTACH_ID" --force || true
    sleep 3
  fi
  aws ec2 delete-network-interface --region "$AWS_REGION" --network-interface-id "$ENI" || true
done

# --- 3. VPC Endpoints (часто блокують сабнети/маршрути)
echo "[Endpoints] Delete VPC endpoints..."
for EP in $(aws ec2 describe-vpc-endpoints --region "$AWS_REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'VpcEndpoints[].VpcEndpointId' --output text); do
  aws ec2 delete-vpc-endpoints --region "$AWS_REGION" --vpc-endpoint-ids "$EP" || true
done

# --- 4. Відчепити та видалити IGW
IGW_ID=$(aws ec2 describe-internet-gateways --region "$AWS_REGION" \
  --filters Name=attachment.vpc-id,Values="$VPC_ID" \
  --query 'InternetGateways[].InternetGatewayId' --output text || true)

if [[ -n "$IGW_ID" && "$IGW_ID" != "None" ]]; then
  echo "[IGW] Detach $IGW_ID..."
  aws ec2 detach-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$IGW_ID" --vpc-id "$VPC_ID" || true
  # іноді треба трохи почекати
  sleep 5
  echo "[IGW] Delete $IGW_ID..."
  aws ec2 delete-internet-gateway --region "$AWS_REGION" --internet-gateway-id "$IGW_ID" || true
fi

# --- 5. Маршрутні таблиці (не main)
echo "[RT] Delete non-main route tables..."
for RT in $(aws ec2 describe-route-tables --region "$AWS_REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query "RouteTables[?Associations[?Main!=\`true\`]].RouteTableId" --output text); do
  # Зняти асоціації сабнетів
  for A in $(aws ec2 describe-route-tables --region "$AWS_REGION" \
      --route-table-ids "$RT" --query 'RouteTables[0].Associations[].RouteTableAssociationId' --output text); do
    aws ec2 disassociate-route-table --region "$AWS_REGION" --association-id "$A" || true
  done
  aws ec2 delete-route-table --region "$AWS_REGION" --route-table-id "$RT" || true
done

# --- 6. Сабнети
echo "[Subnets] Delete subnets..."
for SUB in $(aws ec2 describe-subnets --region "$AWS_REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'Subnets[].SubnetId' --output text); do
  aws ec2 delete-subnet --region "$AWS_REGION" --subnet-id "$SUB" || true
done

# --- 7. Сек’юріті групи (не default)
echo "[SG] Delete non-default SG..."
for SG in $(aws ec2 describe-security-groups --region "$AWS_REGION" \
  --filters Name=vpc-id,Values="$VPC_ID" \
  --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
  # прибрати референси між SG (інакше видалення падає)
  aws ec2 revoke-security-group-egress  --region "$AWS_REGION" --group-id "$SG" --protocol -1 --port -1 --cidr 0.0.0.0/0 2>/dev/null || true
  aws ec2 revoke-security-group-ingress --region "$AWS_REGION" --group-id "$SG" --protocol -1 --port -1 --cidr 0.0.0.0/0 2>/dev/null || true
  aws ec2 delete-security-group --region "$AWS_REGION" --group-id "$SG" || true
done

# --- 8. DHCP options associations (розлинкувати, щоб видалити VPC)
DOPT=$(aws ec2 describe-vpcs --region "$AWS_REGION" --vpc-ids "$VPC_ID" --query 'Vpcs[0].DhcpOptionsId' --output text || true)
if [[ -n "$DOPT" && "$DOPT" != "None" ]]; then
  echo "[DHCP] Associate default options..."
  DEF=$(aws ec2 describe-dhcp-options --region "$AWS_REGION" \
    --filters Name=tag:Name,Values=default --query 'DhcpOptions[0].DhcpOptionsId' --output text 2>/dev/null || echo "default")
  aws ec2 associate-dhcp-options --region "$AWS_REGION" --dhcp-options-id default --vpc-id "$VPC_ID" || true
fi

# --- 9. Нарешті — VPC
echo "[VPC] Delete VPC $VPC_ID..."
aws ec2 delete-vpc --region "$AWS_REGION" --vpc-id "$VPC_ID"
echo "Done."
