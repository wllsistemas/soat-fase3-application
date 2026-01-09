# Infraestrutura - Kubernetes + Terraform

**Sistema:** Oficina SOAT - Gestão de Ordens de Serviço
**Provedor:** AWS (us-east-2)
**IaC:** Terraform 1.5+
**Orquestração:** Kubernetes 1.28+ (AWS EKS)
**Data:** 08/01/2025

## Visão Geral

A infraestrutura do sistema é provisionada via **Terraform** e orquestrada via **Kubernetes (AWS EKS)**. Todos os componentes são declarativos, versionados em Git e reproduzíveis.

**Princípios:**
- **Infrastructure as Code (IaC):** Terraform para provisionamento
- **GitOps:** Infraestrutura versionada em Git
- **Declarativo:** Manifests Kubernetes YAML
- **Escalabilidade:** HPA automático
- **Separação de Responsabilidades:** 4 repositórios independentes

## Arquitetura de Infraestrutura

```
┌────────────────────────────────────────────────────────────────┐
│                         AWS Cloud (us-east-2)                  │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ┌──────────────────────────────────────────────────────────┐ │
│  │               AWS EKS Cluster                            │ │
│  │        fiap-soat-eks-cluster                             │ │
│  │                                                          │ │
│  │  ┌────────────────────────────────────────────────────┐ │ │
│  │  │  Control Plane (Managed by AWS)                    │ │ │
│  │  │  • API Server                                      │ │ │
│  │  │  • etcd                                            │ │ │
│  │  │  │  • Scheduler                                    │ │ │
│  │  │  • Controller Manager                              │ │ │
│  │  └────────────────────────────────────────────────────┘ │ │
│  │                                                          │ │
│  │  ┌────────────────────────────────────────────────────┐ │ │
│  │  │  Worker Nodes (EC2 Instances)                      │ │ │
│  │  │                                                    │ │ │
│  │  │  ┌──────────────────────────────────────────────┐ │ │ │
│  │  │  │ Namespace: lab-soat                          │ │ │ │
│  │  │  │                                              │ │ │ │
│  │  │  │  ┌────────────┐  ┌────────────┐             │ │ │ │
│  │  │  │  │ Nginx Pod  │  │ PHP Pod    │             │ │ │ │
│  │  │  │  │ (1-10x)    │  │ (1-10x)    │             │ │ │ │
│  │  │  │  └────────────┘  └────────────┘             │ │ │ │
│  │  │  │                                              │ │ │ │
│  │  │  │  ┌────────────┐  ┌────────────┐             │ │ │ │
│  │  │  │  │ Postgres   │  │ Datadog    │             │ │ │ │
│  │  │  │  │ Pod (1x)   │  │ Agent      │             │ │ │ │
│  │  │  │  └──────┬─────┘  │ DaemonSet  │             │ │ │ │
│  │  │  │         │        └────────────┘             │ │ │ │
│  │  │  └─────────┼──────────────────────────────────┘ │ │ │
│  │  │            │                                      │ │ │
│  │  │            ▼                                      │ │ │
│  │  │  ┌──────────────────────────────────────────┐   │ │ │
│  │  │  │ AWS EBS CSI Driver                       │   │ │ │
│  │  │  │ • Persistent Volumes                     │   │ │ │
│  │  │  └──────────┬───────────────────────────────┘   │ │ │
│  │  └─────────────┼──────────────────────────────────┘ │ │
│  └────────────────┼────────────────────────────────────┘ │
│                   │                                      │
│                   ▼                                      │
│  ┌────────────────────────────────────────────────────┐  │
│  │ AWS EBS Volumes (gp3)                              │  │
│  │ • postgres-pv (1 GB)                               │  │
│  │ • Encrypted (AES-256)                              │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ AWS Secrets Manager                                │  │
│  │ • soat/jwt-secret                                  │  │
│  │ • soat/db-password                                 │  │
│  └────────────────────────────────────────────────────┘  │
│                                                          │
│  ┌────────────────────────────────────────────────────┐  │
│  │ AWS VPC                                            │  │
│  │ • Public Subnets (2 AZs)                           │  │
│  │ • Private Subnets (2 AZs)                          │  │
│  │ • Internet Gateway                                 │  │
│  │ • NAT Gateway                                      │  │
│  └────────────────────────────────────────────────────┘  │
└────────────────────────────────────────────────────────────┘
```

## Repositórios de Infraestrutura

### Estrutura de Repositórios

```
github.com/wllsistemas/
├── soat-fase3-application/     # Aplicação Laravel + K8s manifests
│   ├── backend/
│   ├── k8s/                    # Manifests Kubernetes
│   │   ├── 00-metrics-server.yaml
│   │   ├── 01-namespace.yaml
│   │   ├── 02-configmap.yaml
│   │   ├── 03-secret.yaml
│   │   ├── 04-secret-postgres.yaml
│   │   ├── 05-pv-postgres.yaml
│   │   ├── 06-pvc-postgres.yaml
│   │   ├── 07-svc-postgres.yaml
│   │   ├── 08-svc-php.yaml
│   │   ├── 09-svc-nginx.yaml
│   │   ├── 10-pod-postgres.yaml
│   │   ├── 11-pod-php.yaml
│   │   ├── 12-pod-nginx.yaml
│   │   ├── 13-hpa-nginx.yaml
│   │   ├── 14-secret-datadog.yaml
│   │   ├── 15-datadog-rbac.yaml
│   │   └── 16-datadog-agent.yaml
│   └── .github/workflows/      # CI/CD
│
├── soat-fase3-infra/           # Infraestrutura base (EKS, IAM, etc.)
│   ├── eks.tf
│   ├── eks-ebs-csi.tf
│   ├── roles.tf
│   ├── datadog.tf
│   ├── hpa.tf
│   ├── metrics-server.tf
│   ├── provider.tf
│   ├── variables.tf
│   └── .github/workflows/      # Terraform apply/destroy
│
├── soat-fase3-database/        # PostgreSQL (Terraform)
│   ├── pod-postgres.tf
│   ├── svc-postgres.tf
│   ├── pvc-postgres.tf
│   ├── secret-postgres.tf
│   ├── storage.tf
│   ├── provider.tf
│   └── .github/workflows/      # Terraform apply/destroy
│
└── soat-fase3-lambda/          # Autenticação Serverless
    ├── src/
    ├── tests/
    └── .github/workflows/      # Lambda deploy
```

---

## Terraform - Provisionamento

### Backend Terraform

**S3 Remote State:**
```hcl
# provider.tf (todos os repos)
terraform {
  backend "s3" {
    bucket = "s3-fiap-soat-fase3"
    key    = "terraform.tfstate"  # ou "database/terraform.tfstate"
    region = "us-east-2"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.20"
    }
  }
}

provider "aws" {
  region = "us-east-2"
}
```

**State Locking (DynamoDB):**
```hcl
# backend.tf (opcional - não implementado ainda)
terraform {
  backend "s3" {
    bucket         = "s3-fiap-soat-fase3"
    key            = "terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-state-lock"  # Previne execuções concorrentes
  }
}
```

---

### Repositório: soat-fase3-infra

**Recursos Provisionados:**

#### 1. EKS Cluster (eks.tf)
```hcl
resource "aws_eks_cluster" "main" {
  name     = "fiap-soat-eks-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  version  = "1.28"

  vpc_config {
    subnet_ids = var.subnet_ids  # Public + Private subnets
  }

  tags = {
    Name        = "fiap-soat-eks-cluster"
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
}

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "fiap-soat-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = var.private_subnet_ids

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  instance_types = ["t3.medium"]  # 2 vCPUs, 4 GB RAM

  tags = {
    Name = "fiap-soat-node-group"
  }
}
```

#### 2. EBS CSI Driver (eks-ebs-csi.tf)
```hcl
resource "aws_eks_addon" "ebs_csi_driver" {
  cluster_name = aws_eks_cluster.main.name
  addon_name   = "aws-ebs-csi-driver"
  addon_version = "v1.25.0-eksbuild.1"

  service_account_role_arn = aws_iam_role.ebs_csi_driver.arn

  tags = {
    Name = "ebs-csi-driver"
  }
}

resource "aws_iam_role" "ebs_csi_driver" {
  name = "AmazonEKS_EBS_CSI_DriverRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.eks.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_csi_driver" {
  role       = aws_iam_role.ebs_csi_driver.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy"
}
```

#### 3. IAM Roles (roles.tf)
```hcl
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

resource "aws_iam_role" "eks_node_group" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

resource "aws_iam_role_policy_attachment" "eks_container_registry" {
  role       = aws_iam_role.eks_node_group.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}
```

#### 4. Metrics Server (metrics-server.tf)
```hcl
resource "kubernetes_service_account" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_cluster_role_binding" "metrics_server" {
  metadata {
    name = "metrics-server:system:auth-delegator"
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "system:auth-delegator"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "metrics-server"
    namespace = "kube-system"
  }
}

resource "kubernetes_deployment" "metrics_server" {
  metadata {
    name      = "metrics-server"
    namespace = "kube-system"
  }

  spec {
    selector {
      match_labels = {
        k8s-app = "metrics-server"
      }
    }

    template {
      metadata {
        labels = {
          k8s-app = "metrics-server"
        }
      }

      spec {
        service_account_name = kubernetes_service_account.metrics_server.metadata[0].name

        container {
          name  = "metrics-server"
          image = "registry.k8s.io/metrics-server/metrics-server:v0.6.4"

          args = [
            "--cert-dir=/tmp",
            "--secure-port=4443",
            "--kubelet-preferred-address-types=InternalIP",
            "--kubelet-use-node-status-port",
            "--metric-resolution=15s"
          ]

          port {
            container_port = 4443
            protocol       = "TCP"
          }

          resources {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }
        }
      }
    }
  }
}
```

#### 5. Datadog (datadog.tf)
```hcl
resource "kubernetes_secret" "datadog" {
  metadata {
    name      = "datadog-secret"
    namespace = "lab-soat"
  }

  data = {
    api-key = var.datadog_api_key  # Passado via tfvars ou env
  }

  type = "Opaque"
}

resource "kubernetes_daemon_set" "datadog_agent" {
  metadata {
    name      = "datadog-agent"
    namespace = "lab-soat"
  }

  spec {
    selector {
      match_labels = {
        app = "datadog-agent"
      }
    }

    template {
      metadata {
        labels = {
          app = "datadog-agent"
        }
      }

      spec {
        service_account_name = "datadog-agent"

        container {
          name  = "datadog-agent"
          image = "datadog/agent:latest"

          env {
            name = "DD_API_KEY"
            value_from {
              secret_key_ref {
                name = "datadog-secret"
                key  = "api-key"
              }
            }
          }

          env {
            name  = "DD_LOGS_ENABLED"
            value = "true"
          }

          env {
            name  = "DD_APM_ENABLED"
            value = "true"
          }

          env {
            name  = "DD_DOGSTATSD_NON_LOCAL_TRAFFIC"
            value = "true"
          }

          port {
            container_port = 8125
            protocol       = "UDP"
          }

          resources {
            requests = {
              cpu    = "200m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "512Mi"
            }
          }

          volume_mount {
            name       = "dockersocket"
            mount_path = "/var/run/docker.sock"
          }
        }

        volume {
          name = "dockersocket"
          host_path {
            path = "/var/run/docker.sock"
          }
        }
      }
    }
  }
}
```

---

### Repositório: soat-fase3-database

**Recursos Provisionados:**

#### 1. Storage Class (storage.tf)
```hcl
resource "kubernetes_storage_class" "gp3_encrypted" {
  metadata {
    name = "gp3-encrypted"
  }

  storage_provisioner = "ebs.csi.aws.com"
  volume_binding_mode = "WaitForFirstConsumer"

  parameters = {
    type      = "gp3"
    encrypted = "true"
    fsType    = "ext4"
  }

  allow_volume_expansion = true
}
```

#### 2. PersistentVolumeClaim (pvc-postgres.tf)
```hcl
resource "kubernetes_persistent_volume_claim" "postgres" {
  metadata {
    name      = "lab-soat-postgres-pvc"
    namespace = "lab-soat"
  }

  spec {
    access_modes       = ["ReadWriteOnce"]
    storage_class_name = kubernetes_storage_class.gp3_encrypted.metadata[0].name

    resources {
      requests = {
        storage = "1Gi"
      }
    }
  }
}
```

#### 3. Deployment PostgreSQL (pod-postgres.tf)
```hcl
resource "kubernetes_deployment" "postgres" {
  metadata {
    name      = "lab-soat-postgres"
    namespace = "lab-soat"
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "postgres"
      }
    }

    template {
      metadata {
        labels = {
          app = "postgres"
        }
      }

      spec {
        container {
          name  = "postgres"
          image = "postgres:17.5"

          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = "lab-soat-postgres-secret"
                key  = "database"
              }
            }
          }

          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = "lab-soat-postgres-secret"
                key  = "username"
              }
            }
          }

          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = "lab-soat-postgres-secret"
                key  = "password"
              }
            }
          }

          env {
            name  = "PGDATA"
            value = "/var/lib/postgresql/data/pgdata"
          }

          port {
            container_port = 5432
          }

          volume_mount {
            name       = "postgres-storage"
            mount_path = "/var/lib/postgresql/data"
          }

          resources {
            requests = {
              cpu    = "250m"
              memory = "256Mi"
            }
            limits = {
              cpu    = "500m"
              memory = "512Mi"
            }
          }

          liveness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 30
            period_seconds        = 10
          }

          readiness_probe {
            exec {
              command = ["pg_isready", "-U", "postgres"]
            }
            initial_delay_seconds = 5
            period_seconds        = 5
          }
        }

        volume {
          name = "postgres-storage"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.postgres.metadata[0].name
          }
        }
      }
    }
  }
}
```

#### 4. Service ClusterIP (svc-postgres.tf)
```hcl
resource "kubernetes_service" "postgres" {
  metadata {
    name      = "lab-soat-postgres"
    namespace = "lab-soat"
  }

  spec {
    selector = {
      app = "postgres"
    }

    port {
      port        = 5432
      target_port = 5432
    }

    type = "ClusterIP"
  }
}
```

#### 5. Secret (secret-postgres.tf)
```hcl
resource "kubernetes_secret" "postgres" {
  metadata {
    name      = "lab-soat-postgres-secret"
    namespace = "lab-soat"
  }

  data = {
    database = base64encode("oficina_soat")
    username = base64encode("postgres")
    password = base64encode(var.postgres_password)  # Via tfvars
  }

  type = "Opaque"
}
```

---

## Kubernetes Manifests

### Namespace

**k8s/01-namespace.yaml:**
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: lab-soat
  labels:
    name: lab-soat
    environment: prod
```

---

### ConfigMap

**k8s/02-configmap.yaml:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: lab-soat-config
  namespace: lab-soat
data:
  APP_NAME: "Oficina SOAT"
  APP_ENV: "production"
  APP_DEBUG: "false"
  DB_CONNECTION: "pgsql"
  DB_HOST: "lab-soat-postgres.lab-soat.svc.cluster.local"
  DB_PORT: "5432"
```

---

### Secrets

**k8s/03-secret.yaml (Laravel):**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: lab-soat-secret
  namespace: lab-soat
type: Opaque
data:
  APP_KEY: <base64-encoded-key>
  DB_DATABASE: b2ZpY2luYV9zb2F0  # oficina_soat
  DB_USERNAME: cG9zdGdyZXM=      # postgres
  DB_PASSWORD: cG9zdGdyZXM=      # postgres
```

**k8s/04-secret-postgres.yaml:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: lab-soat-postgres-secret
  namespace: lab-soat
type: Opaque
data:
  database: b2ZpY2luYV9zb2F0
  username: cG9zdGdyZXM=
  password: cG9zdGdyZXM=
```

---

### Horizontal Pod Autoscaler (HPA)

**k8s/13-hpa-nginx.yaml:**
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: lab-soat-nginx-hpa
  namespace: lab-soat
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: lab-soat-nginx
  minReplicas: 1
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 10  # 10% (threshold baixo para demonstração)
    - type: Resource
      resource:
        name: memory
        target:
          type: AverageValue
          averageValue: 10Mi  # 10 MB (threshold baixo para demonstração)
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # 5 min antes de scale down
      policies:
        - type: Percent
          value: 50  # Reduz 50% dos pods por vez
          periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0  # Sem delay para scale up
      policies:
        - type: Percent
          value: 100  # Dobra pods imediatamente
          periodSeconds: 30
```

---

## Comandos Terraform

### Inicialização

```bash
# Repositório: soat-fase3-infra
cd soat-fase3-infra
terraform init

# Repositório: soat-fase3-database
cd soat-fase3-database
terraform init
```

### Planejamento

```bash
# Preview de mudanças
terraform plan

# Com variáveis
terraform plan -var="postgres_password=senha_segura"
```

### Aplicação

```bash
# Aplicar manualmente
terraform apply

# Aplicar sem confirmação (CI/CD)
terraform apply -auto-approve -var="postgres_password=senha_segura"
```

### Destruição

```bash
# Destruir recursos
terraform destroy

# Com variáveis
terraform destroy -auto-approve -var="postgres_password=senha_segura"
```

### Comandos Úteis

```bash
# Listar resources no state
terraform state list

# Mostrar output de resource específico
terraform state show kubernetes_deployment.postgres

# Validar sintaxe
terraform validate

# Formatar arquivos
terraform fmt -recursive

# Atualizar providers
terraform init -upgrade
```

---

## Comandos Kubernetes

### Aplicar Manifests

```bash
# Aplicar todos os manifests (ordem importa!)
kubectl apply -f k8s/

# Aplicar arquivo específico
kubectl apply -f k8s/01-namespace.yaml
kubectl apply -f k8s/10-pod-postgres.yaml
```

### Listar Recursos

```bash
# Listar pods
kubectl get pods -n lab-soat

# Listar services
kubectl get services -n lab-soat

# Listar HPA
kubectl get hpa -n lab-soat

# Listar PVCs
kubectl get pvc -n lab-soat

# Modo watch (atualização contínua)
kubectl get pods -n lab-soat -w
```

### Descrever Recursos

```bash
# Descrever pod (eventos, status, etc.)
kubectl describe pod <pod-name> -n lab-soat

# Descrever HPA (métricas atuais)
kubectl describe hpa lab-soat-nginx-hpa -n lab-soat

# Descrever PVC (binding status)
kubectl describe pvc lab-soat-postgres-pvc -n lab-soat
```

### Logs

```bash
# Logs de pod específico
kubectl logs <pod-name> -n lab-soat

# Logs em tempo real (follow)
kubectl logs -f <pod-name> -n lab-soat

# Logs de container específico (multi-container pod)
kubectl logs <pod-name> -c <container-name> -n lab-soat

# Logs anteriores (pod restartado)
kubectl logs <pod-name> --previous -n lab-soat
```

### Exec em Pods

```bash
# Shell interativo no PostgreSQL
kubectl exec -it deployment/lab-soat-postgres -n lab-soat -- bash

# Acessar PostgreSQL (psql)
kubectl exec -it deployment/lab-soat-postgres -n lab-soat -- \
  psql -U postgres -d oficina_soat

# Executar comando único
kubectl exec deployment/lab-soat-postgres -n lab-soat -- \
  pg_dump -U postgres oficina_soat > backup.sql
```

### Port Forwarding

```bash
# Port forward para PostgreSQL (local:5432 → pod:5432)
kubectl port-forward -n lab-soat service/lab-soat-postgres 5432:5432

# Port forward para Nginx (local:8080 → pod:80)
kubectl port-forward -n lab-soat service/lab-soat-nginx 8080:80
```

### Deletar Recursos

```bash
# Deletar pod específico (recreado automaticamente pelo Deployment)
kubectl delete pod <pod-name> -n lab-soat

# Deletar deployment (remove todos os pods)
kubectl delete deployment <deployment-name> -n lab-soat

# Deletar namespace completo (remove tudo)
kubectl delete namespace lab-soat

# Deletar via manifest
kubectl delete -f k8s/10-pod-postgres.yaml
```

---

## CI/CD - GitHub Actions

### Workflow: Terraform Apply (soat-fase3-infra)

**.github/workflows/terraform.yaml:**
```yaml
name: Terraform Infrastructure

on:
  workflow_dispatch:
    inputs:
      action:
        description: 'Terraform action'
        required: true
        type: choice
        options:
          - apply
          - destroy
          - plan_destroy

permissions:
  id-token: write  # OIDC auth
  contents: read

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@v3

      - name: Configure AWS Credentials (OIDC)
        uses: aws-actions/configure-aws-credentials@v2
        with:
          role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
          aws-region: us-east-2

      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        with:
          terraform_version: 1.5.0

      - name: Terraform Init
        run: terraform init

      - name: Terraform Validate
        run: terraform validate

      - name: Terraform Plan
        if: github.event.inputs.action == 'apply'
        run: terraform plan -out=tfplan

      - name: Terraform Apply
        if: github.event.inputs.action == 'apply'
        run: terraform apply -auto-approve tfplan

      - name: Terraform Destroy
        if: github.event.inputs.action == 'destroy'
        run: terraform destroy -auto-approve
```

---

## Segurança

### Secrets Management

**Opções Implementadas:**
1. **Kubernetes Secrets:** Credenciais básicas (DB, API keys)
2. **AWS Secrets Manager:** JWT secret (Lambda)

**Melhorias Futuras:**
- Sealed Secrets (Bitnami)
- External Secrets Operator
- Vault (HashiCorp)

### Network Policies

**Isolamento de Namespace:**
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: lab-soat-network-policy
  namespace: lab-soat
spec:
  podSelector: {}
  policyTypes:
    - Ingress
    - Egress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              name: lab-soat
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              name: lab-soat
    - to:  # Allow internet access
        - namespaceSelector: {}
```

### RBAC (Role-Based Access Control)

**ServiceAccount Datadog:**
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: datadog-agent
  namespace: lab-soat
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: datadog-agent
rules:
  - apiGroups: [""]
    resources: ["nodes", "pods", "services", "events"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments", "replicasets", "daemonsets"]
    verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: datadog-agent
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: datadog-agent
subjects:
  - kind: ServiceAccount
    name: datadog-agent
    namespace: lab-soat
```

---

## Custos Estimados

| Recurso | Tipo | Custo Mensal (USD) |
|---------|------|-------------------|
| EKS Control Plane | Managed | $73.00 |
| EC2 Worker Nodes (2x t3.medium) | Compute | ~$60.00 |
| EBS Volumes (1 GB gp3) | Storage | ~$0.10 |
| Data Transfer | Network | ~$5.00 |
| **Total Estimado** | | **~$138/mês** |

**Otimizações:**
- Usar Spot Instances (70% desconto em workers)
- Fargate ao invés de EC2 (pagar apenas por pod ativo)
- Auto-scaling agressivo (escalar para 0 em idle)

---

## Referências

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [AWS EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [ADR-005: Kubernetes + Terraform](../adrs/ADR-005-kubernetes-terraform.md)
- [ADR-008: HPA Autoscaling](../adrs/ADR-008-hpa-autoscaling.md)
- [RFC-002: Database Deployment Strategy](../rfcs/RFC-002-database-deployment-strategy.md)

## Palavras-Chave

`Terraform` `Kubernetes` `AWS EKS` `Infrastructure as Code` `IaC` `GitOps` `HPA` `Auto-Scaling` `EBS CSI` `Datadog`
