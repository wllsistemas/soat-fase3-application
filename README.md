# Oficina SOAT - Arquitetura de Software

<div align="center">

**Sistema de Gestão para Oficinas Mecânicas**

_Tech Challenge - Pós Tech em Arquitetura de Software - FIAP Fase 3_

[![Laravel](https://img.shields.io/badge/Laravel-12-FF2D20?style=flat&logo=laravel&logoColor=white)](https://laravel.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-17.5-316192?style=flat&logo=postgresql&logoColor=white)](https://www.postgresql.org)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-326CE5?style=flat&logo=kubernetes&logoColor=white)](https://kubernetes.io)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-7B42BC?style=flat&logo=terraform&logoColor=white)](https://www.terraform.io)
[![Datadog](https://img.shields.io/badge/Datadog-APM-632CA6?style=flat&logo=datadog&logoColor=white)](https://www.datadoghq.com)

</div>

---

## 📋 Índice

- [Equipe](#-equipe)
- [Material de Apresentação](#-material-de-apresentação)
- [Visão Geral](#-visão-geral)
- [Arquitetura de Software](#️-arquitetura-de-software)
  - [Clean Architecture](#clean-architecture)
  - [Diagramas C4](#diagramas-c4)
  - [Padrões de Design](#padrões-de-design)
- [Decisões Arquiteturais](#-decisões-arquiteturais)
- [Infraestrutura](#-infraestrutura)
- [Modelo de Dados](#-modelo-de-dados)
- [Monitoramento e Observabilidade](#-monitoramento-e-observabilidade)
- [Guias Técnicos](#-guias-técnicos)
- [Documentação Completa](#-documentação-completa)

---

## 👥 Equipe

| Nome | RM | Discord | LinkedIn |
|------|-----|---------|----------|
| **Felipe Oliveira** | 365154 | `felipeoli7eira` | [@felipeoli7eira](https://www.linkedin.com/in/felipeoli7eira) |
| **Nicolas Martins** | 365746 | `nic_hcm` | [@Nicolas Henrique](https://www.linkedin.com/in/nicolas-henrique/) |
| **William Leite** | 365973 | `wllsistemas` | [@William Francisco Leite](https://www.linkedin.com/in/william-francisco-leite-9b3ba9269/) |

---

## 📦 Material de Apresentação

- **[Vídeo de Apresentação](https://www.youtube.com/watch?v=POC_FaWt39E)** - Demonstração completa do sistema
- **[Documento de Entrega - PDF](https://drive.google.com/file/d/1Xl_8YgZHRIELfM3yCWjbswp4tD7Gxoin/view?usp=drive_link)** - Documentação oficial do projeto

---

## 🎯 Visão Geral

### O Problema

Oficinas mecânicas frequentemente enfrentam desafios na gestão de ordens de serviço, acompanhamento de materiais e serviços utilizados, e comunicação eficaz com clientes. Sistemas legados são rígidos, pouco escaláveis e carecem de observabilidade.

### A Solução

**Oficina SOAT** é um sistema moderno de gestão para oficinas mecânicas, construído com **arquitetura limpa**, **padrões de design sólidos** e **infraestrutura escalável**, permitindo:

- Gestão completa de clientes, veículos e ordens de serviço
- Controle detalhado de materiais (peças/insumos) e serviços
- Autenticação segura via CPF + JWT (serverless)
- Auto-scaling horizontal (Kubernetes HPA)
- Observabilidade completa (Datadog APM, logs, métricas)
- Infraestrutura como código (Terraform)
- CI/CD automatizado (GitHub Actions)

### Tech Stack

**Backend:**
- **Framework:** Laravel 12 (PHP 8.4-FPM-Alpine)
- **Web Server:** Nginx (event-driven, async I/O)
- **Banco de Dados:** PostgreSQL 17.5 (autogerenciado em Kubernetes)
- **Autenticação:** JWT (HS256) via AWS Lambda

**Infraestrutura:**
- **Cloud:** AWS (us-east-2)
- **Orquestração:** Kubernetes (AWS EKS 1.28+)
- **IaC:** Terraform 1.5+
- **API Gateway:** AWS API Gateway (REST)
- **Serverless:** AWS Lambda (Node.js 18.x)
- **Storage:** AWS EBS gp3 (encrypted)

**Observabilidade:**
- **Plataforma:** Datadog (APM, logs, métricas)
- **Dashboards:** 3 dashboards de negócio
- **Alertas:** 3 monitors com notificações

---

## 🏛️ Arquitetura de Software

### Clean Architecture

O sistema segue **Clean Architecture** (Robert C. Martin) com separação clara de responsabilidades em 3 camadas concêntricas:

```
┌─────────────────────────────────────────────────────────┐
│                    HTTP LAYER                           │
│  (Apresentação - Controllers, Middleware, Routes)       │
└────────────────┬────────────────────────────────────────┘
                 │ Dependency Flow ▼
┌────────────────▼────────────────────────────────────────┐
│               INFRASTRUCTURE LAYER                       │
│  (Implementações - Repositories, Gateways, Presenters)  │
└────────────────┬────────────────────────────────────────┘
                 │ Dependency Flow ▼
┌────────────────▼────────────────────────────────────────┐
│                   DOMAIN LAYER                           │
│  (Regras de Negócio - Entities, Use Cases, Interfaces)  │
└─────────────────────────────────────────────────────────┘
```

**Princípios Aplicados:**

1. **Dependency Rule:** Dependências apontam sempre de fora para dentro
2. **Separation of Concerns:** Cada camada tem responsabilidade única
3. **Testability:** Domain é 100% testável (sem dependências externas)
4. **Framework Independence:** Lógica de negócio não conhece Laravel

**Estrutura de Pastas:**

```
backend/app/
├── Domain/                    # Núcleo de Negócio
│   ├── Entity/                # Entidades (Cliente, Veiculo, Ordem, etc.)
│   │   ├── Cliente/
│   │   │   ├── Cliente.php    # Entidade com validações
│   │   │   ├── RepositorioInterface.php  # Contrato de persistência
│   │   │   └── Mapper.php     # Conversão array ↔ Entity
│   │   └── Ordem/
│   │       ├── Ordem.php
│   │       ├── RepositorioInterface.php
│   │       └── Mapper.php
│   └── UseCase/               # Casos de Uso (orquestração)
│       ├── Cliente/
│       │   ├── CreateUseCase.php
│       │   ├── ReadUseCase.php
│       │   ├── UpdateUseCase.php
│       │   └── DeleteUseCase.php
│       └── Ordem/
│           ├── CreateUseCase.php
│           ├── AprovarUseCase.php
│           ├── AdicionarMaterialUseCase.php
│           └── AdicionarServicoUseCase.php
│
├── Infrastructure/            # Implementações Técnicas
│   ├── Controller/            # Controllers (delegam para Use Cases)
│   ├── Repositories/          # Implementação de repositórios (Eloquent)
│   ├── Presenter/             # Formatação de respostas JSON
│   ├── Gateway/               # Integrações externas (futuro)
│   └── Service/               # Serviços (BusinessEventLogger)
│
├── Http/                      # Camada de Apresentação
│   ├── Middleware/            # JWT, DocumentoObrigatorio
│   └── Routes/                # Rotas da API (api.php, cliente.php, etc.)
│
├── Models/                    # Eloquent Models (camada externa)
│
├── Exception/                 # Exceções customizadas
│
└── Signature/                 # Interfaces e contratos globais
```

---

### Diagramas C4

O sistema é documentado em 4 níveis de abstração (C4 Model):

#### 1. **Diagrama de Contexto** (C4 Level 1)
Visão geral do sistema, atores (Cliente, Atendente, Mecânico, Gestor) e sistemas externos (API Gateway, Lambda, EKS, PostgreSQL, Datadog, GitHub).

📄 **Documentação completa:** [`docs/architecture/c4-level1-context.md`](./docs/architecture/c4-level1-context.md)

---

#### 2. **Diagrama de Containers** (C4 Level 2)
Componentes executáveis do sistema:

```
Cliente → AWS API Gateway → Lambda Authorizer (JWT)
                          → Nginx → Laravel (PHP-FPM)
                                  → PostgreSQL
                                  → Datadog Agent
```

- **API Gateway:** Ponto de entrada único (HTTPS), rate limiting, DDoS protection
- **Lambda Authorizer:** Validação JWT (Node.js 18.x), autenticação via CPF
- **Nginx:** Reverse proxy (event-driven), HPA 1-10 pods
- **Laravel:** Lógica de negócio (Clean Architecture), HPA 1-10 pods
- **PostgreSQL:** Banco relacional (17.5), volume EBS gp3 encrypted
- **Datadog Agent:** DaemonSet (logs, métricas, APM)

📄 **Documentação completa:** [`docs/architecture/c4-level2-containers.md`](./docs/architecture/c4-level2-containers.md)

---

#### 3. **Diagrama de Componentes** (C4 Level 3)
Estrutura interna da aplicação Laravel:

- **Domain Layer:** Entities, Use Cases, Repository Interfaces
- **Infrastructure Layer:** Controllers, Repositories, Presenters, Services
- **Http Layer:** Middleware, Routes

📄 **Documentação completa:** [`docs/architecture/c4-level3-components.md`](./docs/architecture/c4-level3-components.md)

---

### Padrões de Design

**Padrões Aplicados:**
- **Repository Pattern:** Abstração de persistência via interfaces
- **Use Case Pattern:** Orquestração de regras de negócio
- **Presenter Pattern:** Formatação de respostas JSON
- **Dependency Injection:** Via Laravel Service Container
- **Factory Pattern:** Criação de entidades (Mappers)

**Princípios SOLID:**
- **S** - Single Responsibility: Cada Use Case tem uma única responsabilidade
- **O** - Open/Closed: Extensível via novos Use Cases sem modificar existentes
- **L** - Liskov Substitution: Repositories implementam interfaces
- **I** - Interface Segregation: Interfaces específicas por entidade
- **D** - Dependency Inversion: Controllers dependem de abstrações

**Object Calisthenics:**
- 1 nível de indentação por método
- Sem `else` (early return)
- Encapsulamento de primitivos
- Nomes claros e autoexplicativos

---

## 📝 Decisões Arquiteturais

### ADRs (Architecture Decision Records)

Todas as decisões técnicas significativas foram documentadas via ADRs:

| ADR | Decisão | Status | Data |
|-----|---------|--------|------|
| [ADR-001](./docs/adrs/ADR-001-postgresql.md) | PostgreSQL 17.5 como SGBD | Aceito | 15/11/2024 |
| [ADR-002](./docs/adrs/ADR-002-clean-architecture.md) | Clean Architecture + Hexagonal | Aceito | 20/10/2024 |
| [ADR-003](./docs/adrs/ADR-003-cpf-authentication.md) | Autenticação via CPF + JWT Serverless | Aceito | 01/12/2024 |
| [ADR-004](./docs/adrs/ADR-004-datadog-observability.md) | Datadog para Observabilidade | Aceito | 10/11/2024 |
| [ADR-005](./docs/adrs/ADR-005-kubernetes-terraform.md) | Kubernetes (EKS) + Terraform | Aceito | 01/11/2024 |
| [ADR-006](./docs/adrs/ADR-006-repository-segregation.md) | Segregação em 4 Repositórios Git | Aceito | 05/11/2024 |
| [ADR-007](./docs/adrs/ADR-007-nginx-reverse-proxy.md) | Nginx como Reverse Proxy | Aceito | 20/10/2024 |
| [ADR-008](./docs/adrs/ADR-008-hpa-autoscaling.md) | HPA com CPU e Memória | Aceito | 15/11/2024 |

**Destaques:**

- **PostgreSQL vs MySQL:** Escolhemos PostgreSQL por extensibilidade, JSONB nativo, performance e licença open-source (ADR-001)
- **Autenticação Serverless:** Lambda elimina acoplamento entre autenticação e aplicação, oferece auto-scaling e custo sob demanda (ADR-003)
- **HPA Agressivo:** Thresholds de 10% CPU/Memória para demonstrar escalabilidade rapidamente em ambiente acadêmico (ADR-008)

---

### RFCs (Request for Comments)

RFCs documentam propostas técnicas e implementações complexas:

| RFC | Proposta | Status | Data |
|-----|----------|--------|------|
| [RFC-001](./docs/rfcs/RFC-001-api-gateway-authentication.md) | Estratégia de Autenticação com API Gateway | Implementado | 25/11/2024 |
| [RFC-002](./docs/rfcs/RFC-002-database-deployment-strategy.md) | Banco de Dados Gerenciado vs Autogerenciado | Implementado | 15/11/2024 |
| [RFC-003](./docs/rfcs/RFC-003-communication-patterns.md) | Padrão de Comunicação entre Componentes | Implementado | 20/11/2024 |

**Destaques:**

- **RFC-001:** Optamos por **AWS API Gateway + Lambda Authorizer** ao invés de Kong ou Traefik, priorizando integração nativa AWS e serverless
- **RFC-002:** Escolhemos **PostgreSQL autogerenciado no EKS** ao invés de RDS, reduzindo custos (~$1 vs $18/mês) e mantendo controle total
- **RFC-003:** Padrão **híbrido**: síncrono (HTTP/REST) para APIs críticas, assíncrono (UDP) para observabilidade

---

## 🏗️ Infraestrutura

### Estrutura de Repositórios

Infraestrutura segregada em **4 repositórios Git** independentes:

```
github.com/wllsistemas/
├── soat-fase3-application/     # Aplicação Laravel + K8s manifests
├── soat-fase3-infra/           # EKS cluster, IAM roles, Datadog, HPA
├── soat-fase3-database/        # PostgreSQL deployment, PVC, secrets
└── soat-fase3-lambda/          # Autenticação serverless (Node.js)
```

**Benefícios:**
- Deploy independente por componente
- CI/CD paralelo (falha em Lambda não bloqueia Application)
- Ownership claro (times especializados)
- Permissões granulares (GitHub teams)

📄 **Documentação completa:** [`docs/infrastructure/kubernetes-terraform.md`](./docs/infrastructure/kubernetes-terraform.md)

---

### Kubernetes (AWS EKS)

**Recursos Provisionados:**

- **Cluster:** `fiap-soat-eks-cluster` (EKS 1.28+, us-east-2)
- **Worker Nodes:** 2x `t3.medium` (2 vCPU, 4 GB RAM)
- **Namespace:** `lab-soat` (isolamento de recursos)

**Deployments:**

| Deployment | Replicas | CPU Request | Memory Request | HPA |
|------------|----------|-------------|----------------|-----|
| `lab-soat-nginx` | 1-10 | 100m | 64Mi | CPU 10%, Mem 10Mi |
| `lab-soat-php` | 1-10 | 100m | 64Mi | Manual |
| `lab-soat-postgres` | 1 | 250m | 256Mi | ❌ Stateful |

**Services:**

| Service | Type | Port | Endpoint |
|---------|------|------|----------|
| `lab-soat-nginx` | NodePort | 31000 | `http://localhost:31000/api/ping` |
| `lab-soat-php` | ClusterIP | 9000 | Interno (PHP-FPM) |
| `lab-soat-postgres` | ClusterIP | 5432 | `lab-soat-postgres.lab-soat.svc.cluster.local` |

**Persistent Volumes:**

- **Storage Class:** `gp3-encrypted` (AWS EBS CSI Driver)
- **PVC:** `lab-soat-postgres-pvc` (1 GB, ReadWriteOnce)
- **Encryption:** AES-256 (at-rest)

---

### Terraform (IaC)

**Backend Terraform:**
```hcl
backend "s3" {
  bucket = "s3-fiap-soat-fase3"
  key    = "terraform.tfstate"
  region = "us-east-2"
}
```

**Recursos Principais:**

- **EKS Cluster** (`eks.tf`): Control plane, node groups, VPC config
- **EBS CSI Driver** (`eks-ebs-csi.tf`): Persistent volumes
- **IAM Roles** (`roles.tf`): EKS cluster, node group, EBS CSI
- **Metrics Server** (`metrics-server.tf`): HPA metrics source
- **Datadog** (`datadog.tf`): DaemonSet, RBAC, secrets

**Comandos:**

```bash
# Inicializar
terraform init

# Aplicar infra
terraform apply -auto-approve

# Destruir
terraform destroy -auto-approve
```

---

### CI/CD (GitHub Actions)

**Pipeline CI (Application):**

```yaml
Trigger: Push to main
Steps:
  1. Run PHPUnit tests
  2. Build Docker image (wllsistemas/php_lab_soat:fase3)
  3. Push to Docker Hub
  4. Send email notification
```

**Pipeline CD (Application):**

```yaml
Trigger: CI success
Steps:
  1. Validate CI completed
  2. Copy K8s manifests to VPS
  3. Deploy to Kubernetes (kubectl apply)
  4. Send email notification
```

**Pipeline Terraform (Infra/Database):**

```yaml
Trigger: Manual (workflow_dispatch)
Options:
  - apply: Provisionar recursos
  - destroy: Destruir recursos
  - plan_destroy: Preview de destruição
Steps:
  1. Configure AWS credentials (OIDC)
  2. Terraform init
  3. Terraform validate
  4. Terraform apply/destroy
```

---

## 🗄️ Modelo de Dados

### Entidades Principais

O sistema gerencia 8 entidades relacionais:

```
CLIENTES (1) ───────> (N) VEICULOS
    │                       │
    │                       │
    └─────> (N) ORDENS <────┘
                 │
      ┌──────────┴──────────┐
      ▼                     ▼
  ORDEM_MATERIAL      ORDEM_SERVICO
      │                     │
      ▼                     ▼
  MATERIAIS             SERVICOS
```

**Tabelas:**

| Tabela | Descrição | PK | Registros Estimados |
|--------|-----------|----|--------------------|
| `clientes` | Proprietários de veículos | uuid | ~1.000 |
| `veiculos` | Veículos dos clientes | uuid | ~3.000 |
| `usuarios` | Atendentes, mecânicos, gestores | uuid | ~50 |
| `servicos` | Troca de óleo, revisão, etc. | uuid | ~100 |
| `materiais` | Pastilhas, filtros, óleos, etc. | uuid | ~500 |
| `ordens` | Ordens de serviço | uuid | ~10.000/ano |
| `ordem_material` | N:N Ordens ↔ Materiais | id | ~30.000/ano |
| `ordem_servico` | N:N Ordens ↔ Serviços | id | ~20.000/ano |

**Decisões de Design:**

- **UUIDs como PK:** Segurança (não expõe volume), distribuição, URLs amigáveis
- **Normalização 3NF:** Sem redundância, integridade de dados
- **Snapshot de Valores:** Tabelas pivot armazenam valores históricos (ordem_material.valor)
- **Foreign Keys + ON DELETE:** Integridade referencial (RESTRICT para histórico, CASCADE para dependências)

📄 **Documentação completa:** [`docs/database/data-model.md`](./docs/database/data-model.md)

---

### Diagrama ER (Resumido)

```
┌──────────────┐       ┌──────────────┐
│  CLIENTES    │       │  VEICULOS    │
├──────────────┤       ├──────────────┤
│ uuid (PK)    │       │ uuid (PK)    │
│ cpf (UNIQUE) │◄──────┤ cliente_uuid │
│ nome         │ 1   N │ placa        │
│ email        │       │ marca, modelo│
└──────┬───────┘       └──────┬───────┘
       │ 1                    │ 1
       │                      │
       │        N             │ N
       │   ┌──────────────────┴──┐
       └──►│     ORDENS          │
           ├─────────────────────┤
           │ uuid (PK)           │
           │ cliente_uuid (FK)   │
           │ veiculo_uuid (FK)   │
           │ status              │
           │ valor_total         │
           └──────┬──────────────┘
                  │
       ┌──────────┴──────────┐
       ▼                     ▼
  ORDEM_MATERIAL        ORDEM_SERVICO
       │                     │
       ▼                     ▼
  MATERIAIS             SERVICOS
```

---

## 📊 Monitoramento e Observabilidade

### Datadog (Plataforma Unificada)

**Componentes:**

- **APM (Application Performance Monitoring):** Traces distribuídos, latência de endpoints, SQL queries
- **Logs:** Centralizados (JSON), correlação via `dd.trace_id`
- **Métricas:** Sistema, Kubernetes, negócio (DogStatsD)
- **Dashboards:** 3 dashboards de negócio
- **Monitors:** 3 alertas automáticos

---

### Dashboards

#### 1. **Volume de Ordens**
Monitora throughput e volume de requisições:

- Ordens criadas por hora
- Ordens aprovadas vs reprovadas (24h)
- Top 5 clientes por volume
- Valor total de ordens (R$)
- Status de ordens (heat map)

#### 2. **Performance da Aplicação**
Monitora APM, latência e recursos:

- Latência P50/P95/P99 por endpoint
- Throughput (req/s)
- Taxa de erro (%)
- CPU/Memória dos pods (time series)
- HPA - Réplicas (desired vs current)
- Queries PostgreSQL lentas (>1s)

#### 3. **Erros e Logs**
Monitora erros e exceções:

- Taxa de erro HTTP (5xx)
- Total de erros (24h)
- Top erros por endpoint
- Logs ERROR/CRITICAL (stream)
- Exceptions mais frequentes (tabela)

---

### Monitors (Alertas)

| Monitor | Condição | Warning | Critical | Notificação |
|---------|----------|---------|----------|-------------|
| **Latência Alta** | P95 > 500ms por 5 min | 300ms | 500ms | Email |
| **Taxa de Erro Alta** | Erro >5% por 5 min | 3% | 5% | Email |
| **Container Parado** | Pod não-ready por 2 min | - | 0 pods | Email + Priority P1 |

---

### Logs de Negócio (BusinessEventLogger)

Trait customizado para logging estruturado de eventos de negócio:

**Eventos Implementados:**
- `ordem.criada` - Ordem criada
- `ordem.status.atualizado` - Status alterado
- `ordem.servico.adicionado` - Serviço adicionado
- `ordem.material.adicionado` - Material adicionado
- `ordem.aprovada` - Aprovação pelo cliente
- `ordem.reprovada` - Reprovação (warning level)

**Exemplo de Log:**
```json
{
  "event_type": "ordem.criada",
  "timestamp": "2025-01-08T14:30:00Z",
  "correlation_id": "7f8c9d2e-4b3a-1c2d-8e9f-0a1b2c3d4e5f",
  "dd.trace_id": "123456789",
  "dd.span_id": "987654321",
  "data": {
    "ordem_uuid": "abc-123",
    "cliente_uuid": "def-456",
    "valor_total": 150.00
  }
}
```

**Queries Úteis:**
```
# Histórico de uma ordem
service:oficina-soat ordem.uuid:abc-123

# Eventos de uma trace
service:oficina-soat dd.trace_id:123456789

# Ordens reprovadas
service:oficina-soat event.name:ordem.reprovada status:warning
```

📄 **Documentação completa:** [`docs/monitoring/datadog-observability.md`](./docs/monitoring/datadog-observability.md)

---

## 🚀 Guias Técnicos

### Setup Local (Docker Compose)

**Pré-requisitos:**
- Docker >= 28.4.0
- Docker Compose >= 2.0

**Portas Utilizadas:**
- `8080` - Nginx (API)
- `5432` - PostgreSQL

**Execução:**

```bash
# Clone o repositório
git clone git@github.com:felipeoli7eira/oficina-soat.git
cd oficina-soat

# Suba os containers
docker compose up -d --build

# Verificar saúde
curl http://localhost:8080/api/ping
# Resposta esperada: {"msg":"pong","err":false}
```

**Testes:**

```bash
# Executar todos os testes
docker compose exec php php artisan test

# Com cobertura
docker compose exec php php artisan test --coverage

# Relatório HTML: backend/var/coverage/index.html
```

---

### Setup Kubernetes

**Pré-requisitos:**
- kubectl >= 1.32.2
- Cluster Kubernetes (Minikube, Kind, EKS)

**Deploy:**

```bash
# Aplicar todos os manifestos (ordem importa!)
kubectl apply -f k8s/

# Verificar pods
kubectl get pods -n lab-soat

# Verificar serviços
kubectl get services -n lab-soat

# Health check
curl http://localhost:31000/api/ping
```

**Deletar:**

```bash
kubectl delete namespace lab-soat
```

---

### Setup Terraform

**Pré-requisitos:**
- Terraform >= 1.13.3
- AWS CLI configurado
- Credenciais AWS (OIDC ou access keys)

**Provisionar EKS Cluster:**

```bash
# Repositório: soat-fase3-infra
cd soat-fase3-infra

terraform init
terraform plan
terraform apply -auto-approve
```

**Provisionar PostgreSQL:**

```bash
# Repositório: soat-fase3-database
cd soat-fase3-database

terraform init
terraform apply -auto-approve -var="postgres_password=senha_segura"
```

**Destruir:**

```bash
terraform destroy -auto-approve
```

---

### API Documentation (Postman)

**Workspace:** [https://app.getpostman.com/join-team?invite_code=a8f7c5db50618a4d057b1e50ca129cef16d68fbd74f03c9d4f532c18e9fff4c3](https://app.getpostman.com/join-team?invite_code=a8f7c5db50618a4d057b1e50ca129cef16d68fbd74f03c9d4f532c18e9fff4c3)

**Usuário Padrão (Seeder):**
- Email: `soat@example.com`
- Senha: `padrao`

**Pastas:**
- `auth` - Login (POST /auth/login)
- `cliente` - CRUD de clientes
- `veiculo` - CRUD de veículos
- `usuario` - CRUD de usuários
- `servico` - CRUD de serviços
- `material` - CRUD de materiais
- `ordem` - CRUD de ordens de serviço

**Fluxo Principal (Ordem de Serviço):**

1. **Login:** POST `/auth/login` → Obter JWT
2. **Criar Ordem:** POST `/api/ordem` (cliente_uuid + veiculo_uuid)
3. **Adicionar Material:** POST `/api/ordem/ordem-material/adiciona-material`
4. **Adicionar Serviço:** POST `/api/ordem/ordem-servico/adiciona-servico`
5. **Atualizar Status:** PUT `/api/ordem/{uuid}/update-status`
6. **Aprovar:** PUT `/api/ordem/{uuid}/aprovar`

---

## 📚 Documentação Completa

### Estrutura de Documentação

```
docs/
├── architecture/              # Diagramas C4
│   ├── c4-level1-context.md
│   ├── c4-level2-containers.md
│   └── c4-level3-components.md
├── adrs/                      # Architecture Decision Records
│   ├── ADR-001-postgresql.md
│   ├── ADR-002-clean-architecture.md
│   ├── ADR-003-cpf-authentication.md
│   ├── ADR-004-datadog-observability.md
│   ├── ADR-005-kubernetes-terraform.md
│   ├── ADR-006-repository-segregation.md
│   ├── ADR-007-nginx-reverse-proxy.md
│   └── ADR-008-hpa-autoscaling.md
├── rfcs/                      # Request for Comments
│   ├── RFC-001-api-gateway-authentication.md
│   ├── RFC-002-database-deployment-strategy.md
│   └── RFC-003-communication-patterns.md
├── database/                  # Modelo de Dados
│   └── data-model.md
├── infrastructure/            # Infraestrutura
│   └── kubernetes-terraform.md
├── monitoring/                # Observabilidade
│   └── datadog-observability.md
└── img/                       # Imagens e diagramas
    ├── arquitetura-kubernetes.png
    ├── clean-arch.png
    └── testes.png
```

---

## Aprendizados e Boas Práticas

**Arquitetura:**
 - Clean Architecture isola regras de negócio de frameworks
 - Dependency Rule garante testabilidade e manutenibilidade
 - ADRs documentam contexto e trade-offs de decisões técnicas

**Infraestrutura:**
 - IaC (Terraform) permite reproduzir ambientes identicamente
 - Kubernetes HPA responde automaticamente a picos de carga
 - Segregação de repositórios acelera CI/CD e permite ownership claro

**Observabilidade:**
 - Datadog APM correlaciona logs ↔ traces automaticamente
 - Logs estruturados (JSON) facilitam queries e dashboards
 - Dashboards de negócio conectam métricas técnicas ao valor de negócio

**Custos:**
 - Lambda serverless reduz custo (~$0 vs $30/mês para EC2 fixo)
 - PostgreSQL autogerenciado economiza ~$17/mês vs RDS
 - HPA escala para 1 pod em idle (custo mínimo)

---

## 📄 Licença

Este projeto é desenvolvido para fins acadêmicos como parte do Tech Challenge - Pós Tech em Arquitetura de Software da FIAP.

---

## 📞 Contato

Dúvidas ou sugestões? Entre em contato com a equipe:

- **Felipe Oliveira:** [LinkedIn](https://www.linkedin.com/in/felipeoli7eira)
- **Nicolas Martins:** [LinkedIn](https://www.linkedin.com/in/nicolas-henrique/)
- **William Leite:** [LinkedIn](https://www.linkedin.com/in/william-francisco-leite-9b3ba9269/)

---