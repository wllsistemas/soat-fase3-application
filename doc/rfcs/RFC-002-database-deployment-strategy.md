# RFC-002: Estratégia de Deploy do Banco de Dados PostgreSQL

**Data:** 15/11/2024
**Status:** Implementado
**Autor:** Equipe Oficina SOAT (Felipe, Nicolas, William)

## Resumo Executivo

Este RFC define a estratégia de deploy do banco de dados PostgreSQL para o sistema Oficina SOAT, optando por PostgreSQL autogerenciado em Kubernetes (EKS) ao invés de serviço gerenciado (RDS).

## Contexto

O Tech Challenge - Fase 3 exige:
- Banco de Dados Gerenciado (PostgreSQL/MySQL/SQL Server)
- Infraestrutura provisionada via Terraform
- Repositório Git dedicado com CI/CD

### Problema

**Como provisionar banco de dados PostgreSQL balanceando custos, controle técnico e requisitos acadêmicos sem comprometer a entrega do projeto?**

## Proposta

Implementar **PostgreSQL 17.5 autogerenciado em Kubernetes (EKS)** provisionado via Terraform, com volume persistente EBS.

### Arquitetura Proposta

```
┌────────────────────────────────────────┐
│     AWS EKS Cluster (us-east-2)       │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │  Namespace: lab-soat             │ │
│  │                                  │ │
│  │  ┌────────────────────────────┐ │ │
│  │  │ PostgreSQL 17.5 Pod        │ │ │
│  │  │ ┌────────────────────────┐ │ │ │
│  │  │ │ Image: postgres:17.5   │ │ │ │
│  │  │ │ Port: 5432             │ │ │ │
│  │  │ │ Database: oficina_soat │ │ │ │
│  │  │ │ User: postgres         │ │ │ │
│  │  │ └────────────────────────┘ │ │ │
│  │  │          ▼                 │ │ │
│  │  │ ┌────────────────────────┐ │ │ │
│  │  │ │ PersistentVolumeClaim │ │ │ │
│  │  │ │ Size: 1Gi              │ │ │ │
│  │  │ │ StorageClass: gp3      │ │ │ │
│  │  │ └────────────────────────┘ │ │ │
│  │  │          ▼                 │ │ │
│  │  │ ┌────────────────────────┐ │ │ │
│  │  │ │ AWS EBS Volume (gp3)   │ │ │ │
│  │  │ │ Encrypted: true        │ │ │ │
│  │  │ │ /var/lib/postgresql/   │ │ │ │
│  │  │ │ data/pgdata            │ │ │ │
│  │  │ └────────────────────────┘ │ │ │
│  │  └────────────────────────────┘ │ │
│  │                                  │ │
│  │  ┌────────────────────────────┐ │ │
│  │  │ Service: ClusterIP         │ │ │
│  │  │ Name: lab-soat-postgres    │ │ │
│  │  │ Port: 5432                 │ │ │
│  │  └────────────────────────────┘ │ │
│  └──────────────────────────────────┘ │
│                                        │
│  ┌──────────────────────────────────┐ │
│  │ Laravel Application Pods         │ │
│  │ DB_HOST=lab-soat-postgres.      │ │
│  │ lab-soat.svc.cluster.local      │ │
│  └──────────────────────────────────┘ │
└────────────────────────────────────────┘
```

## Opções Consideradas

### Opção 1: PostgreSQL Autogerenciado em Kubernetes (EKS) — ESCOLHIDA

**Prós:**
- Controle total sobre configurações e versões
- Integração nativa com Kubernetes (Service Discovery)
- Custo reduzido (~$0-5/mês vs. RDS ~$15-30/mês)
- Ambiente acadêmico (não exige HA 99.99%)
- Provisionamento via Terraform (IaC)
- Volumes persistentes com EBS (dados seguros)
- Migrations gerenciadas pela aplicação Laravel

**Contras:**
- Backup manual (sem RDS automated backups)
- Alta disponibilidade complexa (single replica)
- Overhead operacional (gerenciar patches)
- Sem Multi-AZ automático (RDS oferece nativamente)

**Custos Estimados:**
- EBS Volume (1 GB gp3): ~$0.08/mês
- Compute (incluído no worker node do EKS): $0
- Total estimado: <$1/mês

**Configuração Implementada:**
```hcl
# pod-postgres.tf (Terraform)
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "lab-soat-postgres"
    namespace = "lab-soat"
  }

  spec {
    replicas = 1

    template {
      spec {
        container {
          image = "postgres:17.5"
          name  = "postgres"

          env {
            name  = "POSTGRES_DB"
            value = "oficina_soat"
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
            sub_path   = "pgdata"
          }
        }
      }
    }
  }
}

# pvc-postgres.tf
resource "kubernetes_persistent_volume_claim" "postgres" {
  metadata {
    name      = "lab-soat-postgres-pvc"
    namespace = "lab-soat"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = "gp3-encrypted"

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}
```

### Opção 2: AWS RDS PostgreSQL Gerenciado

**Prós:**
- Backup automático (point-in-time recovery)
- Multi-AZ com failover automático
- Patches automáticos
- CloudWatch Metrics integrado
- Performance Insights

**Contras:**
- Custo elevado (~$15-30/mês para db.t3.micro)
- Overhead para ambiente acadêmico
- Menos controle sobre configurações
- Latência de rede adicional (fora do cluster K8s)

**Custos Estimados:**
- db.t3.micro (1 vCPU, 1 GB RAM): ~$15/mês
- Storage (20 GB): ~$2.30/mês
- Backup (20 GB): ~$0.95/mês
- Total estimado: ~$18-20/mês

**Motivo da Rejeição:** Custo elevado para ambiente acadêmico + overhead desnecessário para projeto de curta duração.

### Opção 3: Google Cloud SQL ou Azure Database

**Prós:**
- Funcionalidades similares ao RDS
- Integração nativa com GCP/Azure

**Contras:**
- Equipe já tem expertise AWS
- Multi-cloud aumenta complexidade
- Custo similar ao RDS

**Motivo da Rejeição:** Equipe padronizou AWS como provedor principal.

## Decisão

**Adotamos PostgreSQL 17.5 autogerenciado em Kubernetes (EKS) com volumes persistentes EBS.**

### Implementação

**Repositório:** `soat-fase3-database`

**Recursos Provisionados:**

1. **Deployment PostgreSQL** (pod-postgres.tf)
   - Imagem: `postgres:17.5`
   - Replicas: 1
   - Banco: `oficina_soat`
   - Volume: `/var/lib/postgresql/data/pgdata`

2. **Persistent Volume Claim** (pvc-postgres.tf)
   - Tamanho: 1 GB
   - Storage Class: `gp3-encrypted`
   - Access Mode: ReadWriteOnce

3. **Service ClusterIP** (svc-postgres.tf)
   - Nome: `lab-soat-postgres`
   - Porta: 5432
   - DNS interno: `lab-soat-postgres.lab-soat.svc.cluster.local`

4. **Secret** (secret-postgres.tf)
   - Credenciais: `POSTGRES_USER`, `POSTGRES_PASSWORD`

5. **Storage Class** (storage.tf)
   - Tipo: AWS EBS gp3
   - Criptografia: Habilitada
   - Provisioner: `ebs.csi.aws.com`

**Tecnologias:**
- **SGBD:** PostgreSQL 17.5
- **Container:** Docker (imagem oficial)
- **Storage:** AWS EBS gp3 (encrypted)
- **Provisioning:** Terraform (IaC)
- **Namespace:** `lab-soat` (isolamento)

**Conexão Aplicação:**
```php
// backend/.env (Laravel)
DB_CONNECTION=pgsql
DB_HOST=lab-soat-postgres.lab-soat.svc.cluster.local
DB_PORT=5432
DB_DATABASE=oficina_soat
DB_USERNAME=postgres
DB_PASSWORD=postgres
```

## Impactos

### Aplicação Laravel

**Migrations:**
- Executam via `php artisan migrate` no startup do container PHP
- Controladas pela aplicação (não pelo banco)
- Script: `build/backend/startup.sh`

**Seeders:**
- População inicial via `php artisan db:seed`
- Dados de demonstração e usuário padrão

### Segurança

**Criptografia:** Volume EBS criptografado por padrão
**Isolamento:** Service ClusterIP (não exposto publicamente)
**Secrets:** Kubernetes Secrets (melhorar com Sealed Secrets)
**Backup:** Manual via `pg_dump` (não automatizado)

### Performance

- **Latência:** <5ms (mesma VPC, Service Discovery interno)
- **Throughput:** Limitado pelo worker node (~100-500 req/s)
- **Storage IOPS:** 3000 IOPS (EBS gp3 baseline)

## Plano de Rollout

### Fase 1: Provisionamento Terraform (Concluída)
- Storage Class criada
- PVC criado
- Deployment PostgreSQL criado
- Service exposto internamente

### Fase 2: Integração Aplicação (Concluída)
- Variáveis de ambiente configuradas
- Migrations executadas
- Seeders aplicados

### Fase 3: CI/CD (Concluída)
- GitHub Actions configurado (workflow_dispatch)
- Opções: `apply`, `destroy`, `plan_destroy`
- Backend Terraform S3: `s3-fiap-soat-fase3/database/terraform.tfstate`

### Fase 4: Melhorias Futuras (Opcional)

**Backup Automatizado:**
```yaml
# CronJob para backup diário
apiVersion: batch/v1
kind: CronJob
metadata:
  name: postgres-backup
spec:
  schedule: "0 2 * * *"  # 2 AM diariamente
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: backup
            image: postgres:17.5
            command:
            - /bin/sh
            - -c
            - pg_dump -h lab-soat-postgres -U postgres oficina_soat | gzip > /backup/db-$(date +%Y%m%d).sql.gz
```

**Alta Disponibilidade (se necessário):**
- Stolon/Patroni para HA PostgreSQL em K8s
- Replicação master-slave
- Automatic failover

## Métricas de Sucesso

- Provisionamento via Terraform em <5 min
- Uptime >99% durante período acadêmico
- Latência de queries <50ms P95
- Custo mensal <$5
- Zero perda de dados (volume persistente)

## Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Perda de dados (pod restart) | Baixa | Alto | Volume persistente EBS |
| Pod crash sem HA | Média | Médio | Kubernetes restart automático |
| Credenciais hardcoded | Média | Alto | Migrar para Sealed Secrets |
| Backup manual | Alta | Médio | CronJob automatizado (futuro) |
| Storage cheio (1 GB) | Baixa | Médio | Monitorar uso + alarme Datadog |

## Alternativas Futuras

### Curto Prazo (3-6 meses)
- Implementar backup automatizado via CronJob
- Migrar secrets para AWS Secrets Manager ou Sealed Secrets
- Aumentar storage para 5 GB

### Médio Prazo (6-12 meses)
- Implementar HA com Stolon/Patroni
- Replicação read-replica para queries pesadas
- Connection pooling via PgBouncer

### Longo Prazo (12+ meses)
- Migrar para RDS se crescimento justificar
- Multi-AZ deployment
- Aurora PostgreSQL (se budget permitir)

## Aprovações

- **Arquiteto de Software:** Nicolas Martins
- **Tech Lead:** William Leite
- **DevOps:** Felipe Oliveira
- **Data:** 15/11/2024

## Referências

- [PostgreSQL 17.5 Documentation](https://www.postgresql.org/docs/17/)
- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [AWS EBS CSI Driver](https://github.com/kubernetes-sigs/aws-ebs-csi-driver)
- [ADR-001: Escolha do PostgreSQL](../adrs/ADR-001-postgresql.md)

## Anexos

### Comandos Úteis

**Acessar PostgreSQL via kubectl:**
```bash
kubectl exec -it deployment/lab-soat-postgres -n lab-soat -- psql -U postgres -d oficina_soat
```

**Backup manual:**
```bash
kubectl exec deployment/lab-soat-postgres -n lab-soat -- pg_dump -U postgres oficina_soat > backup.sql
```

**Restore:**
```bash
cat backup.sql | kubectl exec -i deployment/lab-soat-postgres -n lab-soat -- psql -U postgres -d oficina_soat
```

**Verificar volume:**
```bash
kubectl get pvc -n lab-soat
kubectl describe pvc lab-soat-postgres-pvc -n lab-soat
```

### Estrutura do Repositório

```
soat-fase3-database/
├── pod-postgres.tf       # Deployment PostgreSQL
├── svc-postgres.tf       # Service ClusterIP
├── pvc-postgres.tf       # Persistent Volume Claim
├── secret-postgres.tf    # Credenciais (melhorar segurança)
├── storage.tf            # Storage Class EBS gp3
├── provider.tf           # AWS + Kubernetes provider
├── variables.tf          # Variáveis Terraform
├── backend.tf            # S3 backend
└── .github/
    └── workflows/
        └── database.yaml # CI/CD GitHub Actions
```

### CI/CD Workflow

```yaml
name: Database Infrastructure
on:
  workflow_dispatch:
    inputs:
      action:
        type: choice
        options:
          - apply
          - destroy
          - plan_destroy

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Configure AWS Credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-2

      - name: Terraform Init
        run: terraform init

      - name: Terraform ${{ github.event.inputs.action }}
        run: terraform ${{ github.event.inputs.action }} -auto-approve
```
