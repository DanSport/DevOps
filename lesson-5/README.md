# Terraform AWS Infrastructure (Lesson-5)

Цей проєкт створює інфраструктуру в AWS за допомогою **Terraform**.  
Він включає:

- **S3 + DynamoDB** — бекенд для зберігання та блокування Terraform state.
- **VPC** — мережева інфраструктура (публічні та приватні підмережі, Internet Gateway, NAT Gateway, таблиці маршрутів).
- **ECR (Elastic Container Registry)** — репозиторій для зберігання Docker-образів.

---

## 📂 Структура проєкту
lesson-5/
├── main.tf # Підключення всіх модулів
├── backend.tf # Налаштування бекенду (S3 + DynamoDB)
├── outputs.tf # Загальні вихідні дані
├── variables.tf # Глобальні змінні
├── modules/ # Модулі Terraform
│ ├── s3-backend/ # S3 + DynamoDB для стейтів
│ ├── vpc/ # Мережева інфраструктура
│ └── ecr/ # Репозиторій ECR
└── README.md # Документація


---

## ⚙️ Модулі

### 1. `s3-backend`
- Створює **S3-бакет** для збереження стейт-файлів Terraform.
- Увімкнено **версіонування**.
- Використовується **DynamoDB** для блокування.

### 2. `vpc`
- VPC із CIDR `10.0.0.0/16`.
- 3 публічні підмережі (для зовнішніх сервісів).
- 3 приватні підмережі (для внутрішніх сервісів).
- Internet Gateway для публічного доступу.
- NAT Gateway для приватних підмереж.
- Таблиці маршрутів для підключення.

### 3. `ecr`
- Створює репозиторій **ECR**.
- Автоматичне сканування образів при push.
- Виводить URL репозиторію.

---

## 🚀 Використання

### 1. Ініціалізація
```bash
terraform init


### 2. Перевірка плану
terraform plan

### 3. Застосування змін
terraform apply


(підтвердіть введенням yes)

### 4. Знищення ресурсів
terraform destroy

📤 Outputs

Після apply Terraform виведе:

state_bucket_name — ім’я S3-бакета для стейтів

state_dynamodb_table — таблиця DynamoDB

vpc_id — ID створеної VPC

public_subnet_ids — список публічних підмереж

private_subnet_ids — список приватних підмереж

ecr_repository_url — URL ECR-репозиторію


📌 Примітки

Регіон за замовчуванням: us-east-1 (N. Virginia).

Потрібно встановити і налаштувати AWS CLI:

aws configure


В обліковому записі AWS має бути достатньо прав для створення:

S3

DynamoDB

VPC/Subnets/NAT/IGW

ECR