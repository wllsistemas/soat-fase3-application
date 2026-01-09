# ADR-005: Adoção de Kubernetes (EKS) e Terraform para Infraestrutura como Código

**Data:** 08/01/2026
**Status:** Aceita

## Contexto

O sistema Oficina SOAT requer infraestrutura cloud robusta que permita escalabilidade horizontal automática, alta disponibilidade, recuperação automática de falhas, deployment consistente entre ambientes, e versionamento completo de toda a configuração de infraestrutura. O Tech Challenge - Fase 3 estabelece requisitos obrigatórios incluindo uso de Kubernetes para orquestração de containers, infraestrutura como código (IaC) através de Terraform, auto-scaling automático com HPA (Horizontal Pod Autoscaler), alta disponibilidade com múltiplas réplicas, CI/CD automatizado para infraestrutura, e segregação de recursos de infraestrutura em repositório dedicado separado da aplicação.

A infraestrutura deve suportar workload distribuído composto por aplicação Laravel em containers Docker, PostgreSQL como banco de dados, Nginx como reverse proxy e web server, Datadog Agent para observabilidade, e integração com AWS Lambda para autenticação. A escalabilidade é requisito crítico pois sistema deve suportar crescimento de múltiplas unidades de oficina mecânica com picos de carga imprevisíveis durante horários comerciais. A resiliência é essencial pois indisponibilidade do sistema impacta operação das oficinas impedindo criação e consulta de ordens de serviço.

Do ponto de vista organizacional, o projeto é acadêmico mas deve demonstrar conhecimento de práticas de mercado em DevOps e SRE. A equipe possui conhecimento em AWS mas experiência limitada com Kubernetes nativo, favorecendo Kubernetes gerenciado. O sistema deve ser multi-ambiente suportando development, staging e production com configurações distintas mas infra estrutura reproduzível. A portabilidade é desejável para evitar vendor lock-in permitindo eventual migração para GCP ou Azure.

### Proposta de Discussão

Esta seção documenta a análise técnica realizada para fundamentar a escolha da plataforma de orquestração e ferramenta de IaC, considerando alternativas viáveis e seus respectivos trade-offs.

**Alternativa 1: AWS EKS (Kubernetes Gerenciado) + Terraform (Proposta Selecionada)**

AWS Elastic Kubernetes Service (EKS) é Kubernetes gerenciado pela AWS onde control plane é completamente gerenciado pela AWS incluindo API server, etcd, scheduler e controller manager. Worker nodes são EC2 instances gerenciadas pelo usuário através de Auto Scaling Groups ou Managed Node Groups. Terraform é ferramenta open-source de Infrastructure as Code que permite definir infraestrutura através de linguagem declarativa HCL (HashiCorp Configuration Language).

Kubernetes oferece orquestração avançada de containers com escalabilidade horizontal através de HPA (Horizontal Pod Autoscaler) escalando pods baseado em CPU, memória ou custom metrics. Self-healing automaticamente reinicia containers falhando, substitui nodes não responsivos, e mata containers não passando health checks. Rolling updates permitem deploy sem downtime atualizando pods gradualmente com rollback automático em caso de falha. Service discovery e load balancing distribuem tráfego entre pods automaticamente. Declarative configuration via YAML define estado desejado e Kubernetes reconcilia continuamente.

EKS gerenciado oferece vantagens críticas onde AWS gerencia control plane incluindo alta disponibilidade multi-AZ, patches de segurança automáticos, e upgrades de versão Kubernetes. Integração nativa com serviços AWS inclui IAM para autenticação e autorização, EBS para persistent volumes, ELB/ALB para load balancing externo, CloudWatch para logs e métricas, e VPC para networking privado. Certificações de conformidade incluem SOC, PCI-DSS, HIPAA facilitando compliance. Custo fixo de $0.10 por hora por cluster ($73 por mês) mais custo de worker nodes EC2.

Terraform provê Infrastructure as Code declarativo onde arquivos .tf definem estado desejado e Terraform calcula e aplica mudanças incrementais. Versionamento em Git permite code review de mudanças de infraestrutura, rollback para versões anteriores, e auditoria completa de histórico. State management através de backend remoto (S3) com locking (DynamoDB) previne mudanças concorrentes e corrupção de state. Modules reutilizáveis permitem componentização de infraestrutura compartilhada entre environments. Multi-provider suporta AWS, Datadog, Kubernetes provider permitindo gerenciar recursos heterogêneos em single workflow. Plan-and-apply workflow mostra preview de mudanças antes de aplicar permitindo validação.

Os benefícios incluem escalabilidade automática via HPA, resiliência através de self-healing e multi-AZ, portabilidade de Kubernetes permitindo eventual migração multi-cloud, reprodutibilidade onde terraform apply recria infraestrutura identicamente, e demonstração de conhecimento de tecnologias padrão de mercado.

As limitações incluem complexidade operacional de Kubernetes com curva de aprendizado steep, custo fixo de EKS cluster ($73/mês) mais worker nodes, overhead de gerenciar worker nodes mesmo com Managed Node Groups, e complexidade de networking VPC, subnets, security groups.

**Alternativa 2: AWS ECS (Elastic Container Service) + CloudFormation**

ECS é orquestração de containers nativa da AWS com integração profunda com ecossistema AWS. CloudFormation é IaC nativo da AWS usando templates YAML/JSON. ECS Fargate elimina gerenciamento de worker nodes provisionando compute sob demanda.

Os benefícios incluem simplicidade comparada a Kubernetes especialmente com Fargate, integração nativa profunda com AWS, menor curva de aprendizado para equipe familiarizada com AWS, e custo potencialmente menor sem custo fixo de cluster.

As limitações críticas incluem vendor lock-in total na AWS impossibilitando portabilidade, menor adoção no mercado comparado a Kubernetes reduzindo transferibilidade de conhecimento, menos features avançadas que Kubernetes (service mesh, operators, CRDs), e não demonstra conhecimento de Kubernetes que é requisito de mercado.

**Alternativa 3: Google Kubernetes Engine (GKE) + Terraform**

GKE é Kubernetes gerenciado pelo Google Cloud considerado mais maduro que EKS com features avançadas como autopilot mode (serverless Kubernetes) e melhor integração com ecossistema Google.

Os benefícios incluem Kubernetes gerenciado considerado best-in-class, autopilot mode eliminando gerenciamento de nodes, networking simplificado comparado a AWS VPC, e custo competitivo.

As limitações incluem menor familiaridade da equipe com Google Cloud, migração de conhecimento AWS existente, custo de aprendizado de novos serviços (Cloud SQL vs RDS, Cloud Storage vs S3), e menor adoção corporativa no Brasil comparado a AWS.

**Alternativa 4: Heroku / Google App Engine (Platform as a Service)**

Heroku e App Engine são PaaS abstraindo completamente infraestrutura onde desenvolvedores fazem deploy de código e plataforma gerencia tudo (servers, scaling, load balancing).

Os benefícios incluem máxima simplicidade com zero gerenciamento de infraestrutura, deployment extremamente rápido via git push heroku main, e auto-scaling automático.

As limitações críticas incluem vendor lock-in severo, menor controle sobre infraestrutura, custo significativamente mais alto em escala, não demonstra conhecimento de Kubernetes e IaC que são requisitos de mercado, e limitações de customização.

**Análise Comparativa**

AWS EKS + Terraform oferece melhor equilíbrio entre controle técnico, portabilidade, demonstração de conhecimento padrão de mercado, e familiaridade da equipe com AWS. Kubernetes é requisito implícito do Tech Challenge e standard de facto para orquestração. Terraform é padrão de mercado para IaC multi-cloud. EKS gerenciado reduz complexidade operacional comparado a Kubernetes autogerenciado mantendo flexibilidade completa.

ECS + CloudFormation seria tecnicamente mais simples mas cria vendor lock-in severo e não demonstra conhecimento Kubernetes. GKE seria tecnicamente superior mas requer migração de conhecimento AWS. PaaS seria inadequado por não demonstrar conhecimento de infraestrutura e limitações de controle.

## Decisão

A equipe decidiu adotar AWS EKS (Elastic Kubernetes Service) como plataforma de orquestração de containers provisionada e gerenciada via Terraform como ferramenta de Infrastructure as Code. Essa decisão fundamenta-se na análise comparativa de alternativas considerando requisitos do Tech Challenge, necessidade de demonstrar conhecimento de tecnologias padrão de mercado, familiaridade da equipe com AWS, e requisitos de escalabilidade e resiliência.

A implementação utiliza repositório dedicado soat-fase3-infra segregando recursos de infraestrutura de código de aplicação conforme requisito do Tech Challenge de 4 repositórios separados. Terraform configurado com backend remoto S3 em bucket s3-fiap-soat-fase3 para armazenamento de state file, state locking via DynamoDB table terraform-lock prevenindo execuções concorrentes, região us-east-2 (Ohio) selecionada por custo e latência, e encryption at rest habilitado para state file.

Recursos provisionados via Terraform incluem EKS Cluster em eks.tf criando control plane gerenciado pela AWS com versão Kubernetes 1.28, configuração de VPC com subnets privadas em múltiplas AZs para worker nodes, security groups controlando tráfego entre control plane e workers, e IAM role para cluster com políticas necessárias (AmazonEKSClusterPolicy). Managed Node Group cria worker nodes EC2 em Auto Scaling Group com instance type t3.medium (2 vCPU, 4 GB RAM), capacidade de 2-4 nodes com escalabilidade baseada em demanda de pods, disk size 20 GB EBS gp3 por node, e labels e taints para scheduling.

EBS CSI Driver em eks-ebs-csi.tf habilita provisionamento dinâmico de Elastic Block Store volumes como Persistent Volumes no Kubernetes. IAM role for service account (IRSA) permite CSI driver criar e attachar EBS volumes. Storage Class gp3 configurado como default com encryption at rest habilitado. PostgreSQL utiliza PersistentVolumeClaim de 1 GB provisionado dinamicamente via EBS CSI Driver.

IAM Roles em roles.tf definem controle de acesso com EKS Cluster Role permitindo Kubernetes gerenciar recursos AWS, EKS Node Group Role permitindo worker nodes registrar no cluster e puxar imagens ECR, e service accounts roles para componentes específicos (EBS CSI Driver, Datadog Agent).

Datadog integration em datadog.tf provisiona DaemonSet do Datadog Agent via Terraform Kubernetes provider. Secret armazena DD_API_KEY recuperada de AWS Secrets Manager. RBAC (ServiceAccount, ClusterRole, ClusterRoleBinding) configurado permitindo Agent acessar Kubernetes API. Environment variables injetadas em DaemonSet via Terraform variables permitindo customização por environment.

HPA (Horizontal Pod Autoscaler) em hpa.tf define auto-scaling para Nginx deployment com minReplicas 1 e maxReplicas 10. Metrics incluem CPU com targetAverageUtilization 10% (threshold baixo para demonstração em ambiente acadêmico) e memory com targetAverageValue 10Mi. Metrics Server em metrics-server.tf provê resource metrics necessários para HPA funcionar coletando métricas de kubelet.

CI/CD via GitHub Actions em .github/workflows/terraform.yaml executado via workflow_dispatch (trigger manual) com opções apply (provisionar), destroy (destruir), ou plan_destroy (planejar destruição). Jobs incluem terraform init inicializando backend S3, terraform validate validando sintaxe HCL, terraform plan gerando execution plan com preview de mudanças, terraform apply aplicando mudanças com auto-approve flag em CI, e notificação via email de sucesso ou falha. Autenticação AWS via OIDC eliminando necessidade de access keys de longa duração.

Segregação de ambientes utiliza Terraform workspaces (development, staging, production) compartilhando mesmo código .tf mas mantendo state files separados. Variables em terraform.tfvars customizam environment (cluster_name, instance_type, node_count, etc). Naming conventions incluem prefixo de environment em recursos (fiap-soat-dev-eks-cluster, fiap-soat-prod-eks-cluster).

## Consequências

### Positivas

A escalabilidade horizontal automática é alcançada via HPA escalando pods de 1 a 10 réplicas baseado em CPU e memória sem intervenção manual. Kubernetes scheduler distribui pods entre worker nodes balanceando carga. Auto Scaling Group de worker nodes escala nodes baseado em pending pods que não podem ser scheduled por falta de recursos.

A resiliência e alta disponibilidade são garantidas através de EKS control plane multi-AZ gerenciado pela AWS com SLA 99.95%. Self-healing reinicia automaticamente containers falhando e reschedula pods de nodes falhando. Liveness e readiness probes detectam aplicações não saudáveis prevenindo tráfego para pods não prontos. Rolling updates permitem deploy sem downtime atualizando pods gradualmente com rollback automático se readiness probes falham.

A reprodutibilidade completa é alcançada através de Infrastructure as Code onde terraform apply recria infraestrutura identicamente a partir de código versionado. Ambientes development, staging e production são idênticos modulando apenas variables. Disaster recovery é simplificado recriando infraestrutura completa via terraform apply após destruição total.

A portabilidade multi-cloud é viabilizada através de Kubernetes abstraindo cloud provider permitindo migração de EKS para GKE ou AKS alterando apenas provider Terraform e mantendo manifestos Kubernetes. Conhecimento de Kubernetes é transferível entre clouds. Vendor lock-in é limitado ao EKS managed control plane mas worker nodes e workloads são portáveis.

O versionamento completo de infraestrutura através de Git permite code review de mudanças de infraestrutura via pull requests, rollback para versões anteriores via git revert, auditoria completa de histórico de mudanças com author e timestamp, e colaboração em equipe com aprovações obrigatórias.

O cumprimento de requisitos do Tech Challenge inclui Kubernetes para orquestração, Terraform para IaC, auto-scaling via HPA, e segregação em repositório dedicado.

### Negativas

A complexidade operacional de Kubernetes possui curva de aprendizado steep para conceitos como pods, deployments, services, ingress, persistent volumes, RBAC, network policies. Debugging de problemas requer conhecimento profundo de Kubernetes internals. Troubleshooting de networking (CoreDNS, kube-proxy, CNI) é complexo. Gerenciamento de state Terraform requer cuidado para evitar corrupção.

O custo fixo de EKS é $73 por mês por cluster independente de uso mais custo de worker nodes EC2 (2x t3.medium = aproximadamente $60/mês) totalizando aproximadamente $133/mês. Comparativamente Fargate ou PaaS poderiam ser mais econômicos em baixa escala. Esse custo é aceito no contexto acadêmico demonstrando infraestrutura real de produção.

O overhead de gerenciamento de worker nodes mesmo com Managed Node Groups requer configuração de Auto Scaling, AMI updates, security patching de OS, e monitoring de node health. Comparativamente GKE Autopilot ou Fargate eliminam completamente esse overhead.

A complexidade de networking AWS VPC com subnets privadas e públicas em múltiplas AZs, security groups controlando tráfego inbound/outbound, NAT gateways para acesso internet de subnets privadas, e route tables. Essa complexidade é necessária para segurança mas aumenta superfície de erro.

A latência de provisionamento via Terraform onde terraform apply pode levar 15-20 minutos para criar EKS cluster completo. Mudanças incrementais são mais rápidas mas still adicionam overhead comparado a mudanças manuais. Esse impacto é aceito pois benefícios de IaC superam latência de provisionamento.

## Notas de Implementação

A implementação completa da infraestrutura Kubernetes reside no repositório soat-fase3-infra hospedado em GitHub sob organização wllsistemas. O repositório contém código Terraform em arquivos .tf organizados por responsabilidade incluindo eks.tf (provisionamento do EKS cluster e control plane), eks-ebs-csi.tf (EBS CSI Driver para volumes persistentes dinâmicos), roles.tf (IAM roles e policies para cluster e nodes), datadog.tf (DaemonSet do Datadog Agent via Terraform Kubernetes provider), hpa.tf (Horizontal Pod Autoscaler para Nginx deployment), metrics-server.tf (Metrics Server para fornecer métricas ao HPA), provider.tf (configuração de providers e backend), variables.tf (variáveis de entrada), terraform.tfvars (valores de variáveis), e outputs.tf (outputs exportados).

Backend Terraform configurado em provider.tf com backend "s3" apontando para bucket s3-fiap-soat-fase3, key terraform.tfstate, region us-east-2 (Ohio), e dynamodb_table terraform-lock para state locking prevenindo execuções concorrentes. Bucket S3 deve ser criado manualmente antes de terraform init com versioning habilitado para recuperação de state anterior e encryption at rest habilitado via AES256.

EKS Cluster criado via aws_eks_cluster resource em eks.tf com name fiap-soat-eks-cluster, kubernetes version 1.28 (versão estável suportada pela AWS), role_arn apontando para IAM role com policy AmazonEKSClusterPolicy permitindo Kubernetes gerenciar recursos AWS, vpc_config com subnet_ids privadas em múltiplas AZs para alta disponibilidade, security_group_ids controlando tráfego entre control plane e workers, e endpoint_private_access true e endpoint_public_access true permitindo acesso tanto interno quanto externo ao cluster. Outputs exportam cluster_endpoint (https://XXXXXXXX.gr7.us-east-2.eks.amazonaws.com) e cluster_certificate_authority_data para configuração de kubectl.

Worker Nodes provisionados via aws_eks_node_group resource com instance_types [t3.medium] oferecendo 2 vCPU e 4GB RAM por node, scaling_config com desired_size 2, min_size 2, max_size 4 permitindo auto-scaling baseado em demanda de pods, disk_size 20 GB EBS gp3 por node, ami_type AL2_x86_64 (Amazon Linux 2 otimizada para EKS), e labels map adicionando kubernetes.io/role=worker e environment=production para identificação de nodes e pod scheduling.

EBS CSI Driver instalado via aws_eks_addon resource em eks-ebs-csi.tf com addon_name aws-ebs-csi-driver e addon_version latest permitindo provisionamento dinâmico de Elastic Block Store volumes como PersistentVolumes no Kubernetes. IAM role for service account (IRSA) configurado em roles.tf permitindo CSI driver criar, attachar, montar e deletar EBS volumes sem necessidade de credenciais AWS hardcoded. StorageClass gp3 configurado como default com parameters type=gp3, encrypted=true, e iops=3000 garantindo encryption at rest.

IAM Roles definidos em roles.tf incluem EKS Cluster Role com policy AmazonEKSClusterPolicy permitindo Kubernetes gerenciar ELB, EC2, VPC resources, EKS Node Group Role com policies AmazonEKSWorkerNodePolicy, AmazonEC2ContainerRegistryReadOnly, AmazonEKS_CNI_Policy permitindo nodes registrar no cluster e puxar imagens ECR, EBS CSI Driver Role com policy EBS_CSI_Driver_Policy permitindo gerenciar volumes EBS, e Datadog Agent Role com policy Datadog_Agent_Policy permitindo acessar AWS APIs para métricas integradas.

HPA (Horizontal Pod Autoscaler) configurado em hpa.tf via Terraform Kubernetes provider definindo resource kubernetes_horizontal_pod_autoscaler_v2 com target_ref apontando para Deployment lab-soat-nginx, min_replicas 1, max_replicas 10, e metrics incluindo CPU targetAverageUtilization 10% e memory targetAverageValue 10Mi. Behavior controla velocidade de scaling com scaleUp rápido e scaleDown conservador conforme descrito em ADR-008.

Metrics Server provisionado em metrics-server.tf via Terraform Kubernetes provider criando ServiceAccount, ClusterRole, ClusterRoleBinding, Service e Deployment no namespace kube-system. Deployment usa imagem k8s.gcr.io/metrics-server/metrics-server:v0.6.1 com args --kubelet-insecure-tls e --kubelet-preferred-address-types=InternalIP necessários para EKS. Resources requests cpu 100m memory 200Mi e limits cpu 1000m memory 1000m garantem estabilidade.

Datadog integration provisionada em datadog.tf conforme descrito em ADR-004 criando Secret, ServiceAccount, ClusterRole, ClusterRoleBinding e DaemonSet via Terraform Kubernetes provider permitindo gerenciar recursos Kubernetes como código versionado em Git.

Kubectl configurado localmente via aws eks update-kubeconfig --name fiap-soat-eks-cluster --region us-east-2 atualizando ~/.kube/config com credenciais do cluster. Autenticação via AWS IAM usando aws-iam-authenticator automaticamente instalado por aws-cli v2. Context kubectl alterado via kubectl config use-context arn:aws:eks:us-east-2:ACCOUNT_ID:cluster/fiap-soat-eks-cluster.

Manifestos Kubernetes da aplicação residem no repositório soat-fase3-application em k8s/ e são aplicados via kubectl apply -f k8s/ após cluster estar provisionado. Ordem de aplicação importa onde 01-namespace.yaml aplicado primeiro criando namespace lab-soat, seguido por configmaps e secrets, PVCs para PostgreSQL, deployments para PostgreSQL/PHP/Nginx, services para exposição interna e externa, e finalmente HPA para auto-scaling. Datadog DaemonSet é provisionado via Terraform em soat-fase3-infra não via manifestos manuais.

CI/CD workflow GitHub Actions localizado em .github/workflows/terraform.yaml é triggered manualmente via workflow_dispatch permitindo execução on-demand. Workflow aceita input action com opções apply (provisionar recursos), destroy (destruir todos os recursos), ou plan_destroy (gerar execution plan de destruição sem aplicar). Jobs incluem terraform init inicializando backend S3 e baixando providers, terraform validate validando sintaxe HCL, terraform plan gerando execution plan com preview de mudanças mostrando resources a serem criados/modificados/destruídos, terraform apply aplicando mudanças com auto-approve flag em CI mediante confirmação via input action, e notificação via email em sucesso ou falha. Autenticação AWS via OIDC (OpenID Connect) eliminando necessidade de access keys de longa duração armazenadas em GitHub Secrets. OIDC role ARN configurado em AWS IAM com trust policy permitindo GitHub Actions assumir role temporariamente durante workflow execution. Branch main possui proteção exigindo pull request, aprovação obrigatória, e terraform plan output em PR comments para review antes de merge.

## Revisões

- **01/11/2024**: Decisão inicial (Aceita)
- **05/11/2024**: Implementação completa de EKS cluster via Terraform
- **10/11/2024**: Configuração de HPA e Metrics Server
- **15/11/2024**: Setup de CI/CD para Terraform
- **08/01/2026**: Revisão para documentação Fase 3 com formato ADR+RFC rigoroso

## Referências

- AWS EKS Documentation - https://docs.aws.amazon.com/eks/
- Terraform AWS Provider - https://registry.terraform.io/providers/hashicorp/aws/
- Kubernetes Horizontal Pod Autoscaler - https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- Terraform Backend S3 - https://www.terraform.io/docs/language/settings/backends/s3.html
- EKS Best Practices - https://aws.github.io/aws-eks-best-practices/

## Palavras-Chave

Kubernetes, EKS, Elastic Kubernetes Service, Terraform, Infrastructure as Code, IaC, HPA, Horizontal Pod Autoscaler, AWS, Auto Scaling, Orchestration, Cloud Native, DevOps, ADR, RFC
