# Lesson 7 — AWS EKS + ECR + Helm + Django + HPA

## 1. Ініціалізація Terraform та створення інфраструктури

```bash
cd lesson-7

terraform init
terraform apply -auto-approve \
  -var="ecr_name=lesson-7-ecr"

Очікувані вихідні змінні:

cluster_endpoint

cluster_name

ecr_repository_url

vpc_id

## 2. Налаштування kubectl для роботи з EKS
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws eks --region $AWS_REGION update-kubeconfig --name lesson-7-eks

kubectl cluster-info
kubectl get nodes -o wide

## 3. Підготовка Docker-образу

# Локально збираємо образ
docker build -t lesson-7-django:small .

# Тегуємо для ECR
docker tag lesson-7-django:small \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lesson-7-ecr:small

# Логінимось в ECR
aws ecr get-login-password --region $AWS_REGION \
  | docker login --username AWS \
    --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Публікуємо
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lesson-7-ecr:small

Перевірка:

aws ecr describe-images \
  --region $AWS_REGION \
  --repository-name lesson-7-ecr \
  --query 'imageDetails[].imageTags' --output table

## 4. Розгортання застосунку через Helm

helm upgrade --install django-app ./lesson-7/charts/django-app \
  --set image.repository="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lesson-7-ecr" \
  --set image.tag=small \
  --set service.type=ClusterIP

Перевірка:

helm list
helm status django-app
kubectl get deploy,svc,hpa,cm,pods -l app.kubernetes.io/instance=django-app -o wide

## 5. LoadBalancer

helm upgrade --install django-app ./lesson-7/charts/django-app \
  --set image.repository="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lesson-7-ecr" \
  --set image.tag=small \
  --set service.type=LoadBalancer

LB_HOST=$(kubectl get svc django-app-django-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I "http://$LB_HOST/admin/login/"


# Коли Loadbalancer не потрібний то повертаємо у ClusterIP, щоб не спалювати Free Tier
helm upgrade --install django-app ./lesson-7/charts/django-app \
  --set image.repository="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lesson-7-ecr" \
  --set image.tag=small \
  --set service.type=ClusterIP

## 6. Перевірка ConfigMap і Secret

kubectl get configmap django-app-django-app-config -o yaml

kubectl get secret django-db-secret -o jsonpath='{.data.POSTGRES_PASSWORD}' | base64 -d; echo

## 7. Перевірка доступу до бази зсередини кластера

kubectl run --rm -it psql-test --image=postgres:15 --restart=Never \
  --env PGPASSWORD=appsecret -- \
  psql -h db -U appuser -d appdb -c 'SELECT 1;'

Очікуваний результат:

 ?column?
----------
        1
(1 row)

## 8. HPA і Metrics Server

Встановлення Metrics Server

helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm upgrade --install metrics-server metrics-server/metrics-server -n kube-system

Перевірка метрик і HPA

kubectl top nodes
kubectl top pods
kubectl get hpa django-app-django-app
kubectl describe hpa django-app-django-app

## 9. Генерація навантаження для перевірки HPA

kubectl run looper --rm -it --image=busybox --restart=Never -- \
  sh -c 'for i in $(seq 1 3000); do wget -q -O- http://django-app-django-app.default.svc.cluster.local/admin/login/ >/dev/null; done'

Через 1–3 хв:

kubectl get hpa django-app-django-app
kubectl get pods -l app=django-app

Очікується, що кількість реплік зросте (наприклад, 2 → 4 → 5).

## 10. Завершення роботи (щоб не витрачати гроші)

helm uninstall django-app
terraform destroy -auto-approve
