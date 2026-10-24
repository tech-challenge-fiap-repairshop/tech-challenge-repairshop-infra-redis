# 🔴 Tech Challenge RepairShop - Infra Redis (AWS ElastiCache Redis)

> **Repositório de Infraestrutura como Código (Terraform) para Cache em Memória e Sessões**  
> **Tech Challenge SOAT (Fase 4)**  
> **Organização GitHub:** `tech-challenge-fiap-repairshop`

---

## 📌 Visão Geral

O repositório **`tech-challenge-repairshop-infra-redis`** centraliza o provisionamento e governança de infraestrutura em nuvem via **Terraform** para o cluster em memória **AWS ElastiCache Redis** (`user-login-cache`).

Ele oferece cache de baixa latência para sessões ativas e tokens JWT gerados pelo `register-service` e validados pelo `lambda-auth`.

---

## 🏛️ Recursos Provisionados

- **`aws_elasticache_cluster`**: Cluster Redis 7.0 (`user-login-cache`).
- **`aws_elasticache_subnet_group`**: Subnet group vinculado às subnets privadas da VPC (obtidas via remote state do `infra-network`).
- **`aws_security_group`**: Liberação estrita da porta TCP 6379 apenas para conexões originadas dentro da rede privada da VPC.

---

## 📂 Estrutura de Diretórios

```
tech-challenge-repairshop-infra-redis/
├── .github/workflows/         # Pipeline Terraform Plan & Apply (GitHub Actions)
├── infra/
│   ├── environments/          # dev.tfvars, hml.tfvars, prd.tfvars
│   ├── backend.tf             # Remote state S3 (bucket: fiap-repairshop2)
│   ├── main.tf                # Cluster Redis, Subnet Group e Security Group
│   ├── outputs.tf             # Endpoint, porta e SG ID
│   ├── providers.tf           # Configuração do AWS Provider
│   ├── variables.tf           # Parametrização por ambiente e tipo de nó
│   └── versions.tf            # Versões mínimas requeridas
├── .gitignore
└── README.md
```

---

## 🚀 Como Aplicar Localmente

```bash
cd infra

# Inicializar Terraform
terraform init

# Validar configurações
terraform validate

# Planejar (dev)
terraform plan -var-file="environments/dev.tfvars"

# Aplicar (dev)
terraform apply -var-file="environments/dev.tfvars"
```

---

## 🛡️ Governança de Branches
- `main`: Branch de produção (protegida contra push direto).
- `homolog`: Branch de homologação.
- `develop`: Branch de desenvolvimento ativo.
- `feat/*`, `fix/*`, `chore/*`: Branches de trabalho.
