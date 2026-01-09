# C4 Model - Nível 2: Diagrama de Containers

**Sistema:** Oficina SOAT - Gestão de Ordens de Serviço
**Data:** 08/01/2025
**Versão:** 1.0

## Visão Geral

O diagrama de containers mostra os principais componentes executáveis do sistema Oficina SOAT e como eles se comunicam. Este é o segundo nível de abstração do modelo C4.

**Nota:** "Container" no C4 Model refere-se a qualquer unidade executável (aplicação web, banco de dados, serverless function, etc.), não apenas containers Docker.

## Containers do Sistema

### 1. AWS API Gateway
**Tipo:** API Gateway (Managed Service)
**Tecnologia:** AWS API Gateway REST API
**Responsabilidade:** Ponto de entrada único e roteamento

**Funcionalidades:**
- Recebe requisições HTTPS dos clientes
- Invoca Lambda Authorizer para validação JWT
- Roteia requisições autorizadas para Laravel Application
- Rate limiting (10k req/s)
- DDoS protection
- CORS habilitado

**Configuração:**
- **Região:** us-east-2 (Ohio)
- **Protocolo:** HTTPS (TLS 1.2+)
- **Timeout:** 29 segundos (limite AWS)
- **Stage:** prod

**Endpoints Expostos:**
```
POST   /auth/login              # Autenticação (público)
GET    /api/clientes            # Lista clientes (protegido)
POST   /api/clientes            # Cria cliente (protegido)
GET    /api/veiculos            # Lista veículos (protegido)
GET    /api/ordens              # Lista ordens (protegido)
POST   /api/ordens              # Cria ordem (protegido)
PUT    /api/ordens/{uuid}       # Atualiza ordem (protegido)
POST   /api/ordens/{uuid}/aprovar   # Aprovação de ordem (protegido)
POST   /api/ordens/{uuid}/reprovar  # Reprovação de ordem (protegido)
GET    /api/ping                # Health check (público)
```

**Dependências:**
- → **Lambda Authorizer** (validação JWT)
- → **Laravel Application** (lógica de negócio)

---

### 2. Lambda Authorizer (soat-auth-cpf)
**Tipo:** Serverless Function
**Tecnologia:** AWS Lambda (Node.js 18.x)
**Responsabilidade:** Autenticação e autorização

**Funcionalidades:**
- **Endpoint /auth/login:**
  - Valida formato do CPF (XXX.XXX.XXX-XX)
  - Valida dígitos verificadores
  - Consulta PostgreSQL para verificar cliente
  - Gera JWT (HS256) com claims do cliente
  - Retorna token + dados do cliente

- **Lambda Authorizer (interno):**
  - Valida JWT em requisições protegidas
  - Verifica assinatura (secret via AWS Secrets Manager)
  - Verifica expiração (1 hora)
  - Retorna IAM Policy (Allow/Deny) para API Gateway

**Configuração:**
- **Runtime:** Node.js 18.x
- **Memória:** 256 MB
- **Timeout:** 10 segundos
- **Concurrency:** 100 execuções simultâneas
- **Cold start:** ~100-300ms

**Bibliotecas:**
- `jsonwebtoken`: Geração e validação JWT
- `pg`: Cliente PostgreSQL
- CPF validator customizado

**JWT Claims:**
```json
{
  "sub": "cliente-uuid-123",
  "cpf": "123.456.789-00",
  "nome": "João Silva",
  "email": "joao@example.com",
  "iat": 1640000000,
  "exp": 1640003600
}
```

**Dependências:**
- → **PostgreSQL** (consulta clientes)
- ← **AWS Secrets Manager** (JWT secret)

---

### 3. Laravel Application
**Tipo:** Web Application (Backend API)
**Tecnologia:** Laravel 12 (PHP 8.4-FPM-Alpine)
**Responsabilidade:** Lógica de negócio e persistência

**Funcionalidades:**
- CRUD de clientes, veículos, usuários
- CRUD de serviços e materiais
- Gestão de ordens de serviço (criação, atualização, aprovação)
- Relacionamento ordem ↔ materiais ↔ serviços
- Cálculo de valores (custo total da ordem)
- Logs de eventos de negócio (BusinessEventLogger)
- Migrations e seeders

**Arquitetura Interna:**
- **Clean Architecture** (Domain, Infrastructure, Http)
- **Repository Pattern**
- **Use Case Pattern**
- **Presenter Pattern**

**Camadas:**
```
backend/app/
├── Domain/Entity/          # Entidades de negócio (Cliente, Veiculo, Ordem, etc.)
├── Domain/UseCase/         # Casos de uso (CreateUseCase, ReadUseCase, etc.)
├── Infrastructure/
│   ├── Controller/         # Controllers REST
│   ├── Repositories/       # Implementação de repositórios (Eloquent)
│   ├── Presenter/          # Presenters de resposta JSON
│   ├── Gateway/            # Gateways de integração
│   └── Service/            # Serviços (BusinessEventLogger)
├── Http/Middleware/        # Middlewares HTTP
└── Models/                 # Eloquent Models (camada externa)
```

**Configuração:**
- **Replicas (K8s):** 1-10 pods (HPA)
- **CPU Request:** 100m
- **CPU Limit:** 200m
- **Memory Request:** 64Mi
- **Memory Limit:** 128Mi
- **Port:** 9000 (PHP-FPM)

**Dependências:**
- → **PostgreSQL** (persistência)
- → **Datadog Agent** (logs, métricas, traces)
- ← **Nginx** (reverse proxy)

---

### 4. Nginx Reverse Proxy
**Tipo:** Web Server
**Tecnologia:** Nginx (Alpine, event-driven)
**Responsabilidade:** Reverse proxy e entrega de requisições HTTP

**Funcionalidades:**
- Recebe requisições HTTP do API Gateway
- Roteia requisições para PHP-FPM (FastCGI)
- Serve arquivos estáticos (public/)
- Compressão gzip
- Caching de conteúdo estático

**Arquitetura:**
- **Modelo:** Event-driven (assíncrono, não bloqueante)
- **Workers:** 1 worker por CPU
- **Conexões:** ~10.000 conexões simultâneas por worker
- **Consumo Memória:** ~15-20MB por pod

**Configuração:**
```nginx
server {
    listen 80;
    index index.php;
    root /var/www/html/public;

    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    location ~ \.php$ {
        fastcgi_pass php:9000;  # Laravel Application
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }
}
```

**Configuração K8s:**
- **Replicas:** 1-10 pods (HPA)
- **CPU Request:** 100m
- **Memory Request:** 64Mi
- **Port:** 80 (HTTP)
- **Service:** NodePort 31000

**Dependências:**
- → **Laravel Application** (PHP-FPM)
- ← **API Gateway** (requisições HTTP)

---

### 5. PostgreSQL Database
**Tipo:** Relational Database
**Tecnologia:** PostgreSQL 17.5 (Docker oficial)
**Responsabilidade:** Persistência de dados

**Funcionalidades:**
- Armazena dados relacionais (ACID)
- Executa queries transacionais
- Backup manual via pg_dump
- Suporte a JSON (JSONB)

**Esquema (Entidades Principais):**
- `clientes` (uuid, cpf, nome, email, telefone, timestamps)
- `veiculos` (uuid, cliente_uuid, placa, marca, modelo, ano, timestamps)
- `usuarios` (uuid, nome, email, senha_hash, tipo, timestamps)
- `servicos` (uuid, nome, descricao, valor, timestamps)
- `materiais` (uuid, nome, descricao, valor, timestamps)
- `ordens` (uuid, cliente_uuid, veiculo_uuid, status, valor_total, timestamps)
- `ordem_servico` (ordem_uuid, servico_uuid, quantidade, valor)
- `ordem_material` (ordem_uuid, material_uuid, quantidade, valor)

**Configuração:**
- **Versão:** 17.5
- **Database:** oficina_soat
- **User:** postgres
- **Port:** 5432 (ClusterIP interno)
- **Storage:** 1 GB (AWS EBS gp3 encrypted)
- **Connection Pool:** Max 100 conexões (Laravel)

**Backup:**
- Manual via `kubectl exec` + `pg_dump`
- Volume persistente (dados preservados em restart)

**Dependências:**
- ← **Laravel Application** (queries SQL via PDO)
- ← **Lambda Authorizer** (consulta clientes)
- → **AWS EBS Volume** (armazenamento persistente)

---

### 6. Datadog Agent
**Tipo:** Observability Agent (DaemonSet)
**Tecnologia:** Datadog Agent (latest)
**Responsabilidade:** Coleta de logs, métricas e traces

**Funcionalidades:**
- **Logs:**
  - Coleta logs de todos os pods Kubernetes
  - Parsing de logs JSON estruturados
  - Correlação de logs via correlation_id
  - Envio para Datadog SaaS (batching 10s)

- **Métricas:**
  - Métricas de sistema (CPU, memória, disco, rede)
  - Métricas de Kubernetes (pods, deployments, HPA)
  - Métricas customizadas (BusinessEventLogger)

- **APM (Application Performance Monitoring):**
  - Distributed tracing (correlação de requests)
  - Latência de endpoints
  - Flame graphs de queries

**Configuração:**
- **Tipo:** DaemonSet (1 agent por worker node)
- **Namespace:** lab-soat
- **API Key:** Secret Kubernetes (datadog-secret)
- **Logs Enabled:** true
- **APM Enabled:** true
- **Dogstatsd Port:** 8125 (UDP)

**Dashboards:**
1. **Volume de Ordens:** Ordens criadas, aprovadas, reprovadas por período
2. **Performance:** Latência P50/P95/P99, throughput, taxa de erro
3. **Erros e Logs:** Erros por endpoint, stack traces, logs de negócio

**Monitors (Alertas):**
1. **Latência Alta:** P95 > 500ms por 5 minutos → Email
2. **Taxa de Erro Alta:** Erro >5% por 5 minutos → Email
3. **Container Parado:** Pod não-ready por 2 minutos → Email

**Dependências:**
- ← **Laravel Application** (logs via UDP)
- ← **Nginx** (logs de acesso)
- ← **PostgreSQL** (logs de queries lentas)
- → **Datadog SaaS** (envio via HTTPS)

---

### 7. AWS EBS Volume
**Tipo:** Persistent Storage
**Tecnologia:** AWS EBS gp3 (SSD)
**Responsabilidade:** Armazenamento persistente do PostgreSQL

**Funcionalidades:**
- Persistência de dados do PostgreSQL
- Criptografia at-rest (AES-256)
- Snapshot backup (manual)
- IOPS garantido (3000 baseline)

**Configuração:**
- **Tamanho:** 1 GB
- **Tipo:** gp3 (SSD)
- **IOPS:** 3000 (baseline)
- **Throughput:** 125 MB/s
- **Encryption:** Habilitada (AWS KMS)
- **Mount Point:** `/var/lib/postgresql/data/pgdata`

**Kubernetes:**
- **PVC:** lab-soat-postgres-pvc
- **Storage Class:** gp3-encrypted
- **Access Mode:** ReadWriteOnce

**Dependências:**
- ← **PostgreSQL** (montagem de volume)

---

## Diagrama de Containers (Descrição Textual)

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            CLIENTE (Browser/Mobile)                       │
└────────────────────────┬─────────────────────────────────────────────────┘
                         │ ① HTTPS
                         ▼
         ┌───────────────────────────────────────────┐
         │    AWS API Gateway (REST API)             │
         │    [Managed Service]                      │
         │                                           │
         │    • Rate limiting (10k req/s)            │
         │    • DDoS protection                      │
         │    • CORS                                 │
         │    • Timeout: 29s                         │
         └───────┬───────────────────┬───────────────┘
                 │                   │
          ② Invoke                   │ ③ Route
        (Lambda Auth)          (Authorized Requests)
                 │                   │
                 ▼                   ▼
  ┌──────────────────────────┐   ┌───────────────────────────────────┐
  │ AWS Lambda Authorizer    │   │ Nginx Reverse Proxy               │
  │ [Serverless - Node.js]   │   │ [Container - Alpine]              │
  │                          │   │                                   │
  │ soat-auth-cpf            │   │ • Event-driven (async I/O)        │
  │ • Valida CPF             │   │ • Port 80                         │
  │ • Gera JWT (HS256)       │   │ • HPA: 1-10 pods                  │
  │ • Consulta PostgreSQL    │   │ • NodePort 31000                  │
  │ • Retorna IAM Policy     │   │                                   │
  │                          │   └────────┬──────────────────────────┘
  │ Runtime: Node.js 18.x    │            │
  │ Memory: 256 MB           │            │ ④ FastCGI (PHP-FPM)
  │ Timeout: 10s             │            │
  └──────────┬───────────────┘            ▼
             │                ┌────────────────────────────────────────┐
             │                │ Laravel Application                    │
             │                │ [Container - PHP 8.4-FPM-Alpine]       │
             │                │                                        │
             │ ⑤ Query        │ • Clean Architecture                   │
             │  Cliente       │ • Repository Pattern                   │
             │                │ • Use Case Pattern                     │
             │                │ • BusinessEventLogger                  │
             ▼                │                                        │
  ┌──────────────────────┐   │ Port: 9000 (PHP-FPM)                   │
  │ PostgreSQL 17.5      │   │ HPA: 1-10 pods                         │
  │ [Container]          │◄──┤ CPU: 100m-200m                         │
  │                      │   │ Memory: 64Mi-128Mi                     │
  │ Database:            │   │                                        │
  │   oficina_soat       │   └───────┬────────────────────────────────┘
  │                      │           │
  │ Port: 5432           │           │ ⑥ UDP (logs/metrics/traces)
  │ ClusterIP (interno)  │           │
  │ Replicas: 1          │           ▼
  │                      │   ┌───────────────────────────────────────┐
  │ Storage:             │   │ Datadog Agent (DaemonSet)             │
  │   ▼                  │   │ [Container - Datadog]                 │
  │ ┌──────────────────┐ │   │                                       │
  │ │ AWS EBS Volume   │ │   │ • Logs collection                     │
  │ │ [gp3 - 1 GB]     │ │   │ • APM tracing                         │
  │ │                  │ │   │ • Metrics aggregation                 │
  │ │ Encrypted (AES)  │ │   │ • Dogstatsd: 8125 (UDP)               │
  │ │ IOPS: 3000       │ │   │                                       │
  │ │ Mount:           │ │   │ Dashboards: 3                         │
  │ │ /var/lib/        │ │   │ Monitors: 3 (alertas)                 │
  │ │ postgresql/data  │ │   │                                       │
  │ └──────────────────┘ │   └────────┬──────────────────────────────┘
  └──────────────────────┘            │
                                      │ ⑦ HTTPS (batching 10s)
                                      ▼
                           ┌──────────────────────────┐
                           │ Datadog SaaS (Cloud)     │
                           │ [External System]        │
                           │                          │
                           │ • APM dashboards         │
                           │ • Log analytics          │
                           │ • Alerting via email     │
                           └──────────────────────────┘

┌────────────────────────────────────────────────────────────────────┐
│                    SUPPORTING CONTAINERS                           │
├────────────────────────────────────────────────────────────────────┤
│                                                                    │
│  ┌─────────────────┐  ┌──────────────────┐  ┌─────────────────┐ │
│  │ AWS Secrets     │  │ Kubernetes       │  │ GitHub Actions  │ │
│  │ Manager         │  │ Metrics Server   │  │ (CI/CD)         │ │
│  │                 │  │                  │  │                 │ │
│  │ [Managed Svc]   │  │ [K8s Component]  │  │ [External Svc]  │ │
│  │                 │  │                  │  │                 │ │
│  │ • JWT Secret    │  │ • CPU metrics    │  │ • Build Docker  │ │
│  │ • DB Password   │  │ • Memory metrics │  │ • Push Hub      │ │
│  │ • Datadog Key   │  │ • HPA source     │  │ • Deploy K8s    │ │
│  └─────────────────┘  └──────────────────┘  └─────────────────┘ │
└────────────────────────────────────────────────────────────────────┘
```

## Fluxos de Comunicação

### Fluxo 1: Autenticação (POST /auth/login)
```
Cliente → ① API Gateway → ② Lambda (soat-auth-cpf)
                             ② Lambda → ⑤ PostgreSQL (query cliente)
                             ② Lambda ← PostgreSQL (dados cliente)
                             ② Lambda (gera JWT)
Cliente ← ① API Gateway ← ② Lambda (retorna JWT + dados)
```

### Fluxo 2: Requisição Protegida (GET /api/clientes)
```
Cliente → ① API Gateway (header: Authorization: Bearer <JWT>)
              ① API Gateway → ② Lambda Authorizer (valida JWT)
              ① API Gateway ← ② Lambda Authorizer (IAM Policy: Allow)
              ① API Gateway → ③ Nginx → ④ Laravel
                                         ④ Laravel → PostgreSQL (query)
                                         ④ Laravel ← PostgreSQL (dados)
                                         ④ Laravel → ⑥ Datadog (log evento)
Cliente ← ① API Gateway ← ③ Nginx ← ④ Laravel (response JSON)
```

### Fluxo 3: Observabilidade (Assíncrono)
```
Laravel → ⑥ Datadog Agent (UDP - logs/metrics/traces)
Nginx → ⑥ Datadog Agent (logs de acesso)
PostgreSQL → ⑥ Datadog Agent (logs de queries lentas)

Datadog Agent → ⑦ Datadog SaaS (HTTPS batching 10s)
                   ⑦ Datadog SaaS (processa e armazena)
                   ⑦ Datadog SaaS (envia alertas via email)
```

## Tecnologias por Container

| Container | Tecnologia | Versão | Linguagem | Port | Protocolo |
|-----------|------------|--------|-----------|------|-----------|
| API Gateway | AWS API Gateway | - | - | 443 | HTTPS |
| Lambda Auth | AWS Lambda | Node.js 18.x | JavaScript | - | AWS SDK |
| Nginx | Nginx Alpine | latest | C | 80 | HTTP |
| Laravel | PHP-FPM Alpine | PHP 8.4 | PHP | 9000 | FastCGI |
| PostgreSQL | PostgreSQL | 17.5 | C | 5432 | PostgreSQL |
| Datadog Agent | Datadog Agent | latest | Go/Python | 8125 | UDP/HTTPS |
| EBS Volume | AWS EBS gp3 | - | - | - | iSCSI |

## Limites de Recursos (Kubernetes)

| Container | CPU Request | CPU Limit | Memory Request | Memory Limit |
|-----------|-------------|-----------|----------------|--------------|
| Nginx | 100m | 200m | 64Mi | 128Mi |
| Laravel (PHP-FPM) | 100m | 200m | 64Mi | 128Mi |
| PostgreSQL | 250m | 500m | 256Mi | 512Mi |
| Datadog Agent | 200m | 200m | 256Mi | 512Mi |

## Auto-Scaling

**HPA (Horizontal Pod Autoscaler):**
- **Target:** Nginx pods
- **Min Replicas:** 1
- **Max Replicas:** 10
- **Métricas:**
  - CPU: 10% de utilização média
  - Memory: 10Mi de consumo médio
- **Scale Up:** Dobra pods em 30s se threshold excedido
- **Scale Down:** Reduz 50% a cada 60s após 5 min de estabilização

## Segurança

**Secrets Management:**
- JWT Secret: AWS Secrets Manager (rotação manual)
- DB Password: Kubernetes Secret (secret-postgres)
- Datadog API Key: Kubernetes Secret (secret-datadog)

**Network Policies:**
- PostgreSQL: ClusterIP (não exposto publicamente)
- Nginx: NodePort 31000 (acesso local K8s)
- API Gateway: HTTPS público (TLS 1.2+)

**Criptografia:**
- Em trânsito: HTTPS (TLS 1.2+), FastCGI via Unix socket
- At-rest: EBS Volume (AES-256), Secrets (KMS)

## Monitoramento

**Health Checks:**
- Laravel: `/api/ping` (HTTP 200)
- PostgreSQL: `pg_isready`
- Nginx: TCP check porta 80

**Readiness Probes (Kubernetes):**
```yaml
readinessProbe:
  httpGet:
    path: /api/ping
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 5
```

## Referências

- [C4 Model - Containers](https://c4model.com/#ContainerDiagram)
- [ADR-002: Clean Architecture](../adrs/ADR-002-clean-architecture.md)
- [ADR-003: Autenticação via CPF + JWT](../adrs/ADR-003-cpf-authentication.md)
- [ADR-007: Nginx Reverse Proxy](../adrs/ADR-007-nginx-reverse-proxy.md)
- [RFC-003: Communication Patterns](../rfcs/RFC-003-communication-patterns.md)

## Palavras-Chave

`C4 Model` `Container Diagram` `AWS Lambda` `API Gateway` `Laravel` `Nginx` `PostgreSQL` `Datadog` `Kubernetes` `Microservices`
