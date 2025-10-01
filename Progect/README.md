Фінальний проєкт
Компоненти: VPC, EKS, RDS, ECR, Jenkins, Argo CD, Prometheus, Grafana

Production-friendly демо інфраструктури:
- **Terraform** розгортає **VPC + EKS + ECR + Argo CD + Jenkins**.
- **Jenkins (Kaniko + IRSA)** збирає образ, пушить у **ECR** і **оновлює `image.tag` у `Progect/charts/django-app/values.yaml` гілки `main`**.
- **Argo CD** підхоплює коміт із `main` і синхронізує застосунок у кластері.
- **HPA** масштабує `Deployment` за метриками.

> **Поточний стан:** застосунок деплоїться в **namespace `default`** (реліз Helm: `django-app`, Deployment: `django-app-django-app`).  
> **EKS:** `lesson-7-eks` • **ECR:** `lesson-7-ecr` • **GitOps-branch:** `main`.

---

## 0) Передумови

- AWS акаунт із правами на EKS/ECR/VPC/IRSA.
- Встановлено локально: `terraform` ≥ 1.5, `kubectl`, `awscli`, `helm` (опц. `yq`).
- Налаштований `aws configure` або окремий профіль.
- Docker потрібен лише для локальних перевірок (Kaniko у CI працює без Docker).

---

## 1) Структура репозиторію

Project/
│
├── main.tf         # Головний файл для підключення модулів
├── backend.tf        # Налаштування бекенду для стейтів (S3 + DynamoDB
├── outputs.tf        # Загальні виводи ресурсів
│
├── modules/         # Каталог з усіма модулями
│  ├── s3-backend/     # Модуль для S3 та DynamoDB
│  │  ├── s3.tf      # Створення S3-бакета
│  │  ├── dynamodb.tf   # Створення DynamoDB
│  │  ├── variables.tf   # Змінні для S3
│  │  └── outputs.tf    # Виведення інформації про S3 та DynamoDB
│  │
│  ├── vpc/         # Модуль для VPC
│  │  ├── vpc.tf      # Створення VPC, підмереж, Internet Gateway
│  │  ├── routes.tf    # Налаштування маршрутизації
│  │  ├── variables.tf   # Змінні для VPC
│  │  └── outputs.tf  
│  ├── ecr/         # Модуль для ECR
│  │  ├── ecr.tf      # Створення ECR репозиторію
│  │  ├── variables.tf   # Змінні для ECR
│  │  └── outputs.tf    # Виведення URL репозиторію
│  │
│  ├── eks/           # Модуль для Kubernetes кластера
│  │  ├── eks.tf        # Створення кластера
│  │  ├── aws_ebs_csi_driver.tf # Встановлення плагіну csi drive
│  │  ├── variables.tf   # Змінні для EKS
│  │  └── outputs.tf    # Виведення інформації про кластер
│  │
│  ├── rds/         # Модуль для RDS
│  │  ├── rds.tf      # Створення RDS бази даних  
│  │  ├── aurora.tf    # Створення aurora кластера бази даних  
│  │  ├── shared.tf    # Спільні ресурси  
│  │  ├── variables.tf   # Змінні (ресурси, креденшели, values)
│  │  └── outputs.tf  
│  │ 
│  ├── jenkins/       # Модуль для Helm-установки Jenkins
│  │  ├── jenkins.tf    # Helm release для Jenkins
│  │  ├── variables.tf   # Змінні (ресурси, креденшели, values)
│  │  ├── providers.tf   # Оголошення провайдерів
│  │  ├── values.yaml   # Конфігурація jenkins
│  │  └── outputs.tf    # Виводи (URL, пароль адміністратора)
│  │ 
│  └── argo_cd/       # ✅ Новий модуль для Helm-установки Argo CD
│    ├── jenkins.tf    # Helm release для Jenkins
│    ├── variables.tf   # Змінні (версія чарта, namespace, repo URL тощо)
│    ├── providers.tf   # Kubernetes+Helm. переносимо з модуля jenkins
│    ├── values.yaml   # Кастомна конфігурація Argo CD
│    ├── outputs.tf    # Виводи (hostname, initial admin password)
│		  └──charts/         # Helm-чарт для створення app'ів
│ 	 	  ├── Chart.yaml
│	 	  ├── values.yaml     # Список applications, repositories
│			  └── templates/
│		    ├── application.yaml
│		    └── repository.yaml
├── charts/
│  └── django-app/
│    ├── templates/
│    │  ├── deployment.yaml
│    │  ├── service.yaml
│    │  ├── configmap.yaml
│    │  └── hpa.yaml
│    ├── Chart.yaml
│    └── values.yaml   # ConfigMap зі змінними середовища
└──Django
			 ├── app\
			 ├── Dockerfile
			 ├── Jenkinsfile
			 └── docker-compose.yaml


## 2) Розгортання інфраструктури (Terraform)

```bash
cd Progect

# Ініціалізація
terraform init

# Старт. За потреби підкоригуйте значення змінних.
terraform apply -auto-approve \
  -var="aws_region=us-east-1" \
  -var="ecr_name=lesson-7-ecr" \
  -var="eks_cluster_name=lesson-7-eks" \
  -var="eks_version=1.29"

# Корисні вихідні дані
terraform output
terraform output -raw ecr_repository_url
terraform output -raw cluster_name
terraform output -raw argocd_namespace
terraform output -raw jenkins_namespace


## 3) kubectl доступ до EKS

```bash
AWS_REGION=us-east-1
EKS_NAME=$(terraform output -raw cluster_name)

aws eks --region "$AWS_REGION" update-kubeconfig --name "$EKS_NAME"

kubectl config get-contexts
kubectl cluster-info
kubectl get nodes -o wide
```

---

## 4) CI/CD — перевірка (Jenkins → ECR → GitOps → Argo CD → K8s)

```bash
# Спільні змінні
AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO=lesson-7-ecr
IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO"

# 4.1. Який тег зараз у GitOps (гілка main)?
TAG=$(curl -s https://raw.githubusercontent.com/DanSport/DevOps/main/Progect/charts/django-app/values.yaml \
  | awk '/^[[:space:]]+tag:/ {print $2}')
echo "GitOps tag: $TAG"

# 4.2. Є такий тег в ECR?
aws ecr describe-images --region "$AWS_REGION" --repository-name "$REPO" \
  --query "imageDetails[?contains(imageTags, \`${TAG}\`)].imageTags" --output table

# 4.3. Що деплоїться в кластері?
kubectl -n default get deploy django-app-django-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}'

# 4.4. Перевірка відповідності тега GitOps vs Deployment
DEPLOY_TAG=$(kubectl -n default get deploy django-app-django-app \
  -o jsonpath='{.spec.template.spec.containers[0].image}{"\n"}' | awk -F: '{print $NF}')
echo "Deploy tag: $DEPLOY_TAG"
test "$TAG" = "$DEPLOY_TAG" && echo "✅ OK: теги збігаються" || echo "❌ MISMATCH: теги різні"

# 4.5. Статус розкатки
kubectl -n default rollout status deploy/django-app-django-app

## 5) Ручна збірка/публікація (не обов’язково)

AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REPO=lesson-7-ecr
IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$REPO"

aws ecr get-login-password --region "$AWS_REGION" \
 | docker login --username AWS --password-stdin "$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com"

docker build -t django-app:local .
docker tag django-app:local "$IMAGE_URI:local"
docker push "$IMAGE_URI:local"

aws ecr describe-images --region "$AWS_REGION" --repository-name "$REPO" \
  --query 'imageDetails[].imageTags' --output table


---

## 6) Локальне розгортання demo-чарта (за потреби)

AWS_REGION=us-east-1
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
IMAGE_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/lesson-7-ecr"

helm upgrade --install django-app ./charts/django-app \
  --set image.repository="$IMAGE_REPO" \
  --set image.tag="local" \
  --set service.type=ClusterIP

helm status django-app
kubectl -n default get deploy,svc,hpa,pods -l app.kubernetes.io/instance=django-app -o wide


## 7) HPA та Metrics Server

Перевірка метрик:
```bash
kubectl top nodes
kubectl top pods -A
kubectl get hpa -A
```

Генерація навантаження:
```bash
kubectl run looper --rm -it --image=busybox --restart=Never --   sh -c 'for i in $(seq 1 3000); do wget -q -O- http://django-app-django-app.default.svc.cluster.local/admin/login/ >/dev/null; done'
```

---

## 8) Доступ до Jenkins та Argo CD

**Jenkins**
```bash
kubectl get svc -n jenkins
# Якщо serviceType=ClusterIP — порт-форвардинг:
kubectl -n jenkins port-forward svc/jenkins 8080:8080
# Пароль (якщо не задавав явно):
kubectl -n jenkins get secret jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d; echo
```

**Argo CD**
# Стан компонентів
kubectl -n argocd get pods
kubectl -n argocd get applications

# Веб-доступ (порт-форвардинг)
kubectl -n argocd port-forward svc/argocd-server 8081:80

# Пароль admin
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d; echo

Щоб деплоїти не в default, змініть у Application:
spec.destination.namespace: django-app + аннотацію argocd.argoproj.io/sync-options: CreateNamespace=true.
---

## 9) Змінні та `terraform.tfvars`

Приклад `terraform.tfvars`:
```hcl
aws_region        = "us-east-1"

# GitOps (для приватного репо)
github_username   = "<your_github_user>"
github_token      = "<your_github_pat>"
github_repo_url   = "git@github.com:<org>/<repo>.git"

# Імена
ecr_name          = "lesson-7-ecr"
eks_cluster_name  = "lesson-7-eks"
eks_version       = "1.29"
```

---

## 10) Типові перевірки

```bash
# EKS
kubectl get nodes -o wide
kubectl -n kube-system get pods

# Argo CD
kubectl -n argocd get applications
kubectl -n argocd describe application <app-name>

# Jenkins
kubectl -n jenkins get pods
kubectl -n jenkins logs deploy/jenkins -f

# ECR
aws ecr describe-repositories
aws ecr describe-images --repository-name lesson-7-ecr
```

---

## 11) Прибирання

```bash
# Якщо ставив demo-чарт:
helm uninstall django-app || true

# Вся інфраструктура:
terraform destroy -auto-approve
```

---

## Нотатки безпеки

- **IRSA** для Jenkins/Kaniko → **жодних AWS ключів у Secret**.
- **ECR** за замовчуванням з **immutable** тегами та lifecycle-політикою (налаштовується).
- Для приватних Git репозиторіїв використовуйте **SSH ключі** або Sealed/External Secrets для токенів.

---

## Що ще можна додати

- **Ingress** (ALB/Nginx) для Jenkins/Argo CD.
- Окремі **IRSA-ролі** для аддонів (EBS CSI із власним policy).
- Замість `tag` фіксувати `image.digest` у GitOps (детерміновані деплоя).


![alt text](image.png)
<img width="1737" height="619" alt="image" src="https://github.com/user-attachments/assets/c1581540-a238-4932-a28a-23baf3a48308" />

<img width="1772" height="568" alt="image" src="https://github.com/user-attachments/assets/efd36371-5f04-4822-bc2f-f8208bf5b163" />

# RDS/Aurora модуль — використання та змінні

Цей модуль піднімає **або** звичайну RDS-інстансу (PostgreSQL/MySQL), **або** **Aurora**-кластер (writer) — залежно від прапорця `use_aurora`.

---

## 🔧 Приклади використання

### 1) Звичайна RDS PostgreSQL

  use_aurora     = false
  

### 2) Aurora PostgreSQL (кластер + writer)

  use_aurora     = true
 

### 3) Aurora MySQL (мінімум)
```hcl
module "rds" {
  source = "./modules/rds"

  name           = "app-aurora-mysql"
  use_aurora     = true
  engine_base    = "mysql"
  engine_version = "8.0.35"

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnet_ids

  aurora_instance_class = "db.r6g.large"
}
```

> Після `apply` зручно мати узагальнений output у корені:
> ```hcl
> output "db_endpoint" {
>   value = coalesce(module.rds.rds_endpoint, module.rds.aurora_endpoint)
> }
> ```

---

## 📤 Виводи (Outputs)
- `db_subnet_group_name`, `security_group_id`
- **RDS**: `rds_instance_id`, `rds_instance_arn`, `rds_endpoint`, `rds_address`
- **Aurora**: `aurora_cluster_id`, `aurora_cluster_arn`, `aurora_endpoint`, `aurora_reader_endpoint`, `aurora_writer_instance_id`

---

## ⚙️ Змінні модуля з поясненнями

### Основні
| Змінна | Тип / Дефолт | Пояснення |
|---|---|---|
| `name` | `string` | Базова назва ресурсів БД. |
| `name_prefix` | `string` \| `null` | Префікс для імен (якщо заданий — використовується в SG/Subnet Group/PG). |
| `use_aurora` | `bool` (default: `false`) | **Перемикач**: `false` → RDS, `true` → Aurora. |
| `engine_base` | `string` (default: `"postgres"`) | Сімейство рушія: `"postgres"` \| `"mysql"`. |
| `engine_version` | `string` | Версія рушія (напр. `"16.3"` або `"8.0.35"`). |
| `port` | `number` \| `null` | Порт БД (за замовчуванням 5432/3306). |
| `db_name` | `string` (default: `"appdb"`) | Початкова база. |
| `db_username` | `string` (default: `"appuser"`) | Користувач. |
| `db_password` | `string` \| `null` (**sensitive**) | Пароль; якщо `null`, генерується випадковий. |
| `tags` | `map(string)` (default: `{}`) | Додаткові теги для всіх ресурсів. |

### Мережа
| Змінна | Тип / Дефолт | Пояснення |
|---|---|---|
| `vpc_id` | `string` | ID VPC, де розгортається БД. |
| `subnet_ids` | `list(string)` | Приватні сабнети для DB Subnet Group (2+ AZ). |
| `allowed_cidr_blocks` | `list(string)` (default: `[]`) | CIDR’и, з яких дозволено доступ до порту БД. |
| `allowed_security_group_ids` | `list(string)` (default: `[]`) | SG, яким дозволено доступ (рекомендовано SG→SG). |

### Безпека / життєвий цикл
| Змінна | Тип / Дефолт | Пояснення |
|---|---|---|
| `publicly_accessible` | `bool` (default: `false`) | Публічний доступ до інстансу/кластера. |
| `backup_retention_period` | `number` (default: `7`) | Дні зберігання бекапів. |
| `deletion_protection` | `bool` (default: `false`) | Захист від видалення. |
| `skip_final_snapshot` | `bool` (default: `true`) | Пропуск фінального snapshot **(тільки RDS)**. |
| `apply_immediately` | `bool` (default: `true`) | Застосовувати зміни негайно (можливий даунтайм). |
| `iam_database_authentication_enabled` | `bool` (default: `false`) | IAM-автентифікація до БД. |
| `maintenance_window` | `string` \| `null` | Вікно обслуговування, напр. `Sun:23:00-Mon:01:30`. |
| `backup_window` | `string` \| `null` | Вікно бекапів, напр. `02:00-03:00`. |

### Звичайна RDS (актуально, коли `use_aurora = false`)
| Змінна | Тип / Дефолт | Пояснення |
|---|---|---|
| `instance_class` | `string` (default: `"db.t4g.small"`) | Клас інстансу RDS. |
| `storage_gb` | `number` (default: `20`) | Розмір диска. |
| `max_allocated_storage` | `number` (default: `0`) | Авто‑масштаб диска (0 — вимкнено). |
| `storage_type` | `string` (default: `"gp3"`) | Тип сховища (`gp3/gp2/io1` тощо). |
| `multi_az` | `bool` (default: `false`) | Multi‑AZ для RDS (на Aurora не впливає). |

### Aurora (актуально, коли `use_aurora = true`)
| Змінна | Тип / Дефолт | Пояснення |
|---|---|---|
| `aurora_instance_class` | `string` (default: `"db.r6g.large"`) | Клас інстансу для writer (і майбутніх reader’ів). |

### Тюнінг Postgres (коли `engine_base = "postgres"`)
| Змінна | Тип / Дефолт | Пояснення |
|---|---|---|
| `pg_max_connections` | `number` (default: `200`) | `max_connections` у параметр‑групі. |
| `pg_log_statement` | `string` (default: `"none"`) | `none|ddl|mod|all`. |
| `pg_work_mem` | `string` (default: `"4MB"`) | `work_mem`. |

### Тюнінг MySQL (коли `engine_base = "mysql"`)
| Змінна | Тип / Дефолт | Пояснення |
|---|---|---|
| `mysql_max_connections` | `number` (default: `200`) | `max_connections`. |
| `mysql_general_log` | `bool` (default: `false`) | Ввімкнути загальний лог. |
| `mysql_slow_query_log` | `bool` (default: `true`) | Ввімкнути slow query log. |
| `mysql_long_query_time` | `number` (default: `2`) | Поріг повільних запитів, сек. |

> Модуль автоматично обирає правильну **parameter group family** (напр. `postgres16`, `aurora-postgresql15`, `mysql8.0`, `aurora-mysql8.0`) на основі `engine_base` і `engine_version`.

---

## 🔁 Як перемкнути тип БД, рушій і класи інстансів

### Тип БД
- `use_aurora = false` → створюється **`aws_db_instance`** (звичайна RDS).
- `use_aurora = true`  → створюється **`aws_rds_cluster`** + **`aws_rds_cluster_instance` (writer)**.
> ⚠️ Перемикання зазвичай призводить до **recreate** ресурсів. Для продакшну плануйте міграцію/бекапи.

### Рушій та версія
- `engine_base = "postgres"` або `"mysql"`
- `engine_version = "16.3"` (PG) / `"8.0.35"` (MySQL/Aurora MySQL) тощо.

### Класи інстансів
- Для RDS: `instance_class` (напр. `db.t4g.small`, `db.m7g.large`).
- Для Aurora: `aurora_instance_class` (напр. `db.r6g.large`).

### Порт і доступ
- Порт можна перевизначити через `port` (інакше 5432/3306).
- Доступ відкривається **або** через `allowed_security_group_ids` (рекомендовано), **або** `allowed_cidr_blocks` (обережно з `0.0.0.0/0`).

---

## ✅ Що створюється в будь-якому випадку
- `aws_db_subnet_group`
- `aws_security_group` + ingress‑правила за `allowed_*`
- **Parameter Group** (або `aws_db_parameter_group`, або `aws_rds_cluster_parameter_group`) із базовими параметрами.


# Моніторинг: Prometheus + Grafana (kube-prometheus-stack)


## Що встановлюється

- **Prometheus Operator** – менеджмент CRD (`ServiceMonitor`, `PodMonitor`, `PrometheusRule`).  
- **Prometheus** – збір метрик з Kubernetes та ваших сервісів.  
- **Alertmanager** – маршрутизація алертів (за потреби підключається e-mail/Slack).  
- **Grafana** – готові дашборди Kubernetes (Cluster/Namespace/Pod/Node).  
- **kube-state-metrics**, **node-exporter** – ключові джерела метрик кластера.

**Збереження даних**:  
- Prometheus: PVC розміром `prometheus_pvc_size` (напр. `20Gi`), retention `prometheus_retention` (напр. `7d`).  
- Grafana: PVC `grafana_persistence_size` (напр. `5Gi`).  
- StorageClass: `storage_class` (напр. `gp3`).

---

## Доступ і швидка перевірка

```bash
# Перевірити реліз/поди/сервіси
helm list -n monitoring
kubectl get pods -n monitoring
kubectl get svc  -n monitoring

# Доступ до Grafana (локально)
kubectl -n monitoring port-forward svc/grafana 3000:80
# Відкрити http://localhost:3000  (логін: admin, пароль: див. нижче)

# Доступ до Prometheus (локально)
kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
# Відкрити http://localhost:9090 → Status → Targets (очікувано "UP")
```

Отримати пароль Grafana:
```bash
kubectl -n monitoring get secret -l app.kubernetes.io/name=grafana   -o jsonpath='{.items[0].data.admin-password}' | base64 -d; echo
```
(Якщо пароль задається в Terraform змінною `grafana_admin_password` — використовуйте його.)

> **Зовнішній доступ**: встановіть `grafana_service_type = "LoadBalancer"` у модулі та застосуйте `terraform apply`, тоді беріть `EXTERNAL-IP` сервісу Grafana.

---

## Готові дашборди в Grafana

- **Kubernetes / Compute Resources / Cluster, Namespace, Pod**  
- **Nodes / Node Exporter Full**  
- **Kubernetes / Networking / Cluster**

Цих дашбордів достатньо, щоб показати стан кластера, нод, навантаження на поди/неймспейси, мережу.
<img width="1867" height="962" alt="image" src="https://github.com/user-attachments/assets/56ce0e2b-ba39-439f-a3bd-d5d1837a61a1" />
<img width="1279" height="662" alt="image" src="https://github.com/user-attachments/assets/b18dcedb-5f02-40b9-b8e7-48c58282d6d9" />

---

## Підключення метрик застосунку

Щоб Prometheus збирав метрики з вашого сервісу (наприклад, Django на `/metrics`), додайте **ServiceMonitor** у Helm-чарт застосунку:

```yaml
# charts/django-app/templates/servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: django-app
  labels:
    release: monitoring             # має збігатися з назвою Helm-релізу стека моніторингу
spec:
  namespaceSelector:
    matchNames: [default]           # або ваш namespace застосунку
  selector:
    matchLabels:
      app.kubernetes.io/name: django-app  # лейбл Service
  endpoints:
    - port: http                    # ім'я порту з Service (наприклад, "http")
      path: /metrics
      interval: 30s
```

Після застосування `helm upgrade` або `kubectl apply` таргет з’явиться у Prometheus → **Status → Targets**.

---

## Автомасштабування (HPA) і метрики

- **CPU/RAM HPA** працює через `metrics-server` (стандартні метрики).  
- **Кастомні метрики** для HPA (з Prometheus) потребують **Prometheus Adapter** (необов’язково для цього проєкту; додається окремим чартом).

---

## Налаштування (через Terraform змінні модуля)

- `grafana_service_type`: `ClusterIP` / `LoadBalancer` / `NodePort`  
- `grafana_persistence_size`: розмір PVC Grafana (напр. `5Gi`)  
- `prometheus_retention`: період зберігання (напр. `7d`)  
- `prometheus_pvc_size`: розмір PVC Prometheus (напр. `20Gi`)  
- `storage_class`: назва StorageClass (напр. `gp3`)  
- `grafana_admin_password` (**sensitive**): пароль адміністратора Grafana

---

## Траблшутинг

- **Targets в Prometheus “DOWN”**  
  Переконайтесь, що `kubelet`, `kube-state-metrics`, `node-exporter` працюють (`kubectl get pods -n monitoring`). Дивіться логи оператора:  
  `kubectl logs -n monitoring deploy/monitoring-kube-prometheus-operator`.

- **PVC у статусі Pending**  
  Невірний `storageClassName` або відсутній EBS CSI. Перевірте `StorageClass` та наявність `aws-ebs-csi-driver`.

- **Не пам’ятаєте пароль Grafana**  
  Отримайте з Kubernetes Secret (команда вище) або змініть через Terraform і `apply`.

- **Port-forward не відкриває сторінку**  
  Перевірте, що порт не зайнятий локально; використайте інший локальний порт (наприклад, `3001:80`).

---

## Видалення

Спочатку приберіть реліз моніторингу, потім інфраструктуру:
```bash
terraform destroy -target=module.monitoring -auto-approve
terraform destroy -auto-approve
```
> Якщо destroy блокується «DependencyViolation» (NAT/ELB/ENI) — видаліть залишки в VPC, тоді повторіть `terraform destroy`.

