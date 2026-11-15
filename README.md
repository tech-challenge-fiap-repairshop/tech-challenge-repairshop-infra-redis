# ⚡🧠 Repair Shop — Infra ElastiCache Redis (`infra-redis`)

[![CI/CD Pipeline](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-redis/actions/workflows/ci-cd-redis.yml/badge.svg)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-redis/actions/workflows/ci-cd-redis.yml)
[![Terraform](https://img.shields.io/badge/Terraform-1.8.5-7B42BC?logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Amazon ElastiCache](https://img.shields.io/badge/Amazon%20ElastiCache-Redis%207.0-D82C20?logo=redis&logoColor=white)](https://aws.amazon.com/elasticache/)

Repositório de **Infraestrutura como Código (Terraform)** responsável pelo provisionamento do cluster em memória **Amazon ElastiCache for Redis 7.0** da plataforma **Repair Shop (Tech Challenge FIAP — 15SOAT)** em sub-redes privadas da VPC, fornecendo infraestrutura de baixa latência para cache de autenticação e sessões do [`app-register-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-register-service).

---

## 📋 Índice

- [Recursos Provisionados e Segurança de Rede](#recursos-provisionados-e-segurança-de-rede)
- [Arquitetura Atual — Motivação e Benefícios dos Componentes](#arquitetura-atual--motivação-e-benefícios-dos-componentes)
- [Por que DynamoDB em vez de Banco Relacional nos Contextos de OS e Pagamentos?](#por-que-dynamodb-em-vez-de-banco-relacional-nos-contextos-de-os-e-pagamentos)
- [Como Executar e Validar Localmente (Terraform)](#como-executar-e-validar-localmente-terraform)
- [Como Executar em Produção (Esteira CI/CD GitHub Actions)](#como-executar-em-produção-esteira-cicd-github-actions)
- [Documentação Técnica e Collection do Postman](#documentação-técnica-e-collection-do-postman)

---

## Recursos Provisionados e Segurança de Rede

Conforme definido em [`infra/main.tf`](infra/main.tf) e nos arquivos `infra/environments/{dev,hml,prd}.tfvars`:

| Recurso AWS | Configuração Técnica | Benefício |
| :--- | :--- | :--- |
| **`aws_elasticache_cluster.redis`** | • Identificador: `${cluster_name}-user-login-cache-${environment}` (ex.: `repairshop-user-login-cache-prd`)<br>• Engine: **Redis `7.0`** (`default.redis7`), `num_cache_nodes = 1`, porta **`6379`**<br>• Tipo de nó: `cache.t3.micro` (`dev`/`hml`) e `cache.t3.small` (`prd`) | Armazenamento em memória sub-milissegundo provisionado de forma gerenciada sem carga administrativa de manutenção. |
| **`aws_elasticache_subnet_group`** | Alocado exclusivamente nas sub-redes privadas lidas do state remoto `network/${ENV}.tfstate` | Isola o serviço de cache dentro da camada privada da VPC. |
| **`aws_security_group.redis`** | Ingresso TCP `6379` restrito aos CIDRs das sub-redes privadas | Bloqueia qualquer acesso externo fora dos workloads autorizados da VPC. |

> **Integração transparente com o `app-register-service`**: A esteira de CI/CD do `app-register-service` descobre automaticamente o endpoint primário desse cluster e o injeta via Kubernetes Secret/ConfigMap (`SPRING_DATA_REDIS_HOST`/`PORT`), além do container `redis:7.0-alpine` já configurado no `docker-compose.yml` local. *(Nota transparente: a dependência `spring-boot-starter-data-redis` e as configurações já estão preparadas, embora os casos de uso em Kotlin do `register-service` ainda não gravem chaves de sessão ativamente no Redis em runtime).*

---

## Arquitetura Atual — Motivação e Benefícios dos Componentes

| Pilar / Tecnologia | Papel no Ecossistema | Motivação Técnica e Pontos Positivos |
| :--- | :--- | :--- |
| **RDS (PostgreSQL 16)** | Persistência relacional cadastral ([`infra-db-rds`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-db-rds)) | Garante consistência ACID e integridade referencial para Clientes, Veículos e Usuários (`tb_customer`, `tb_vehicle`, `tb_user` via Flyway) no `register-service`. |
| **DynamoDB (NoSQL)** | Persistência transacional de OS e Pagamentos ([`infra-db-dynamo`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-db-dynamo)) | Garante escala automática `PAY_PER_REQUEST`, Single-Table Design (`TransactWriteItems`) e GSIs para OS e Pagamentos sem sobrecarga de conexões relacionais. |
| **ElastiCache (Redis 7.0)** | **Camada provisionada por este repositório** | Reduz futuros acessos repetitivos ao RDS para validação de sessões/tokens JWT, entregando latência de resposta na casa de sub-milissegundos sob rajadas de login. |
| **Apps (EKS + Lambda Auth)** | Computação híbrida ([`infra-eks`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-eks), [`lambda-auth`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-lambda-auth)) | Separa autenticação serverless na borda (`lambda-auth`) dos 4 microsserviços especializados rodando em **EKS 1.31** com HPA. |
| **Amazon SQS (Mensageria + DLQ)** | Comunicação assíncrona ([`infra-sqs`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-sqs)) | Orquestra a **Saga Coreografada** através de 5 filas + 5 DLQs (14 dias de retenção), assegurando resiliência no fluxo de orçamentos, pagamentos e notificações. |
| **API Gateway (HTTP API v2)** | Borda gerenciada ([`infra-apigateway`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-infra-apigateway)) | Roteamento único para Lambda Auth e NLBs do EKS com suporte CORS aos headers W3C (`traceparent`, `tracestate`). |
| **Observabilidade (Grafana)** | OpenTelemetry + Prometheus + Loki + Jaeger + Grafana | Centraliza métricas, logs correlacionados e tracing distribuído em 11 dashboards JSON versionados. |

---

## Por que DynamoDB em vez de Banco Relacional nos Contextos de OS e Pagamentos?

Na distribuição de responsabilidades de armazenamento (**RDS** para cadastro mestre + **Redis** para camada de cache + **DynamoDB** para execução de OS e pagamentos):

1. **Zero gargalo de conexões sob HPA e mensageria paralela**: Pods de `service-order` e `payment` que escalam automaticamente no EKS abririam dezenas de conexões simultâneas contra um RDS `db.t3.micro`; o DynamoDB opera via API HTTPS *stateless* sem limite prático de conexões.
2. **Agregados polimórficos e evolução livre de atributos**: `ORDER#<id>` e `BILLING#<serviceOrderId>` reúnem histórico, tarefas extras e dados externos do Mercado Pago em **Single-Table Design** com `TransactWriteItems`, dispensando `JOIN`s e *ALTER TABLE* bloqueantes.
3. **Consultas assíncronas otimizadas**: Índices secundários (`pending-dispatch-index` e `dispatch-notification-index`) permitem varreduras cirúrgicas para enfileiramento no SQS em modo `PAY_PER_REQUEST`.

---

## Como Executar e Validar Localmente (Terraform)

> **Pré-requisitos**: **Terraform `1.8.5`**, **AWS CLI v2** autenticado e state prévio da camada de rede (`network/${ENV}.tfstate`).

```bash
cd infra

# Inicializar com state remoto no S3 (ex.: dev)
terraform init \
  -backend-config="bucket=SEU_BUCKET_TERRAFORM_STATE" \
  -backend-config="key=redis/dev.tfstate" \
  -backend-config="region=us-east-1"

terraform fmt -check -recursive
terraform validate
terraform plan -var-file="environments/dev.tfvars"
```

> Para executar apenas um Redis 7.0 local para testes com o `register-service`, utilize `docker compose up -d redis` no repositório [`app-register-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-register-service).

---

## Como Executar em Produção (Esteira CI/CD GitHub Actions)

Definida em [`.github/workflows/ci-cd-redis.yml`](.github/workflows/ci-cd-redis.yml) e destruição controlada em [`.github/workflows/destroy.yml`](.github/workflows/destroy.yml).

### Mapeamento de Ambientes
- `develop` -> **`dev`** (`infra/environments/dev.tfvars`)
- `homolog` -> **`hml`** (`infra/environments/hml.tfvars`)
- `main` -> **`prd`** (`infra/environments/prd.tfvars`)

### Etapas da Pipeline
1. `terraform fmt -check` e `terraform validate`.
2. `terraform init` apontando para o state `redis/${ENV}.tfstate` no bucket `AWS_TERRAFORM_STATE_BUCKET`.
3. `terraform plan -var-file="environments/${ENV}.tfvars"`.
4. `terraform apply -auto-approve` em push para `develop`, `homolog` e `main`.

> **Dependência obrigatória**: Execute **`infra-network`** antes deste repositório para disponibilizar a VPC e sub-redes privadas.

---

## Documentação Técnica e Collection do Postman

- **Arquivos Terraform deste Repositório**: [`infra/main.tf`](infra/main.tf) | [`infra/environments/dev.tfvars`](infra/environments/dev.tfvars) | [`infra/environments/hml.tfvars`](infra/environments/hml.tfvars) | [`infra/environments/prd.tfvars`](infra/environments/prd.tfvars)
- **Consumidor Configurado**: [`tech-challenge-repairshop-app-register-service`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-register-service)
- **ADRs, RFCs e Diagrama Cloud**:
  - [ADRs (`ADR-001` a `ADR-013`)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/ADRs/README.md)
  - [RFCs (`RFC-001` a `RFC-014`)](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/RFCs/README.md)
  - [`Diagrama de Infraestrutura Cloud`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/delivery/infrastructure/repairshop-diagrama-infra-cloud.svg)
- **Postman Collections & Environments (Organização)**:
  - Collection Principal: [`Repair Shop (Tech Challenge FIAP)`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Repair%20Shop%20%28Tech%20Challenge%20FIAP%29.postman_collection.json)
  - Collection Completa: [`Tech Challenge FIAP - Completo`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Tech_Challenge_Fiap_-_Completo.postman_collection.json)
  - Environment Local: [`Local.postman_environment.json`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/Local.postman_environment.json)
  - Guia do Postman: [`docs/postman/README.md`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/blob/main/docs/postman/README.md)
- **Dashboards Grafana (11 JSONs)**: [`dashboards/`](https://github.com/tech-challenge-fiap-repairshop/tech-challenge-repairshop-app-service-order-execution-service/tree/main/local/observability/grafana/dashboards)
