# C4 Model - Nível 1: Diagrama de Contexto

**Sistema:** Oficina SOAT - Gestão de Ordens de Serviço
**Data:** 08/01/2025
**Versão:** 1.0

## Visão Geral

O diagrama de contexto mostra o sistema Oficina SOAT e como ele interage com usuários e sistemas externos. Este é o nível mais alto de abstração do modelo C4.

## Descrição do Sistema

**Oficina SOAT** é um sistema de gestão para oficinas mecânicas que permite:
- Cadastro de clientes e veículos
- Registro de ordens de serviço
- Gestão de materiais e serviços
- Acompanhamento de status de ordens
- Autenticação via CPF

## Atores (Usuários)

### 1. Cliente da Oficina
**Descrição:** Proprietário de veículo que solicita serviços
**Responsabilidades:**
- Autenticar-se via CPF
- Consultar seus veículos cadastrados
- Visualizar ordens de serviço
- Aprovar/reprovar orçamentos

**Canais de Acesso:**
- Aplicação Web (browser)
- Aplicação Mobile (futuro)
- API REST (integrações)

### 2. Atendente da Oficina
**Descrição:** Funcionário responsável pelo atendimento
**Responsabilidades:**
- Cadastrar clientes e veículos
- Criar ordens de serviço
- Registrar materiais e serviços utilizados
- Atualizar status de ordens

**Canais de Acesso:**
- Aplicação Web (backoffice)

### 3. Mecânico
**Descrição:** Profissional que executa os serviços
**Responsabilidades:**
- Visualizar ordens atribuídas
- Atualizar progresso de execução
- Registrar observações técnicas

**Canais de Acesso:**
- Aplicação Web (mobile-friendly)

### 4. Gestor da Oficina
**Descrição:** Administrador do sistema
**Responsabilidades:**
- Gerenciar usuários do sistema
- Configurar serviços e materiais
- Visualizar dashboards de desempenho
- Acompanhar métricas de negócio

**Canais de Acesso:**
- Aplicação Web (backoffice)
- Dashboards Datadog

## Sistemas Externos

### 1. AWS API Gateway
**Tipo:** Sistema de Infraestrutura (Gerenciado)
**Responsabilidade:** Ponto de entrada único para todas as requisições HTTP
**Provedor:** Amazon Web Services
**Interação:**
- Recebe requisições dos clientes
- Roteia para Lambda Authorizer (autenticação)
- Roteia para aplicação backend (após autorização)
- Aplica rate limiting e DDoS protection

**Protocolos:** HTTPS (TLS 1.2+)

### 2. AWS Lambda (Serverless)
**Tipo:** Sistema de Autenticação (Gerenciado)
**Responsabilidade:** Validação de CPF e geração de JWT
**Provedor:** Amazon Web Services
**Interação:**
- Valida formato e dígitos verificadores do CPF
- Consulta PostgreSQL para verificar existência do cliente
- Gera token JWT com claims do cliente
- Valida JWT em requisições protegidas (Lambda Authorizer)

**Protocolos:** AWS SDK (invocação síncrona)

### 3. AWS EKS (Kubernetes)
**Tipo:** Plataforma de Orquestração (Gerenciado)
**Responsabilidade:** Executa aplicação Laravel containerizada
**Provedor:** Amazon Web Services
**Interação:**
- Gerencia ciclo de vida dos pods (PHP-FPM, Nginx, PostgreSQL)
- Auto-scaling horizontal (HPA)
- Health checks e self-healing
- Service discovery interno

**Protocolos:** Kubernetes API

### 4. PostgreSQL 17.5
**Tipo:** Banco de Dados Relacional (Autogerenciado)
**Responsabilidade:** Persistência de dados da aplicação
**Provedor:** PostgreSQL Community (imagem Docker oficial)
**Interação:**
- Armazena: clientes, veículos, ordens, materiais, serviços, usuários
- Executa queries transacionais (ACID)
- Fornece dados para autenticação Lambda

**Protocolos:** PostgreSQL Wire Protocol (TCP 5432)

### 5. Datadog
**Tipo:** Plataforma de Observabilidade (SaaS)
**Responsabilidade:** Monitoramento, logs e APM
**Provedor:** Datadog Inc.
**Interação:**
- Coleta logs estruturados (JSON) via agent
- Captura traces distribuídos (APM)
- Agrega métricas de negócio e infraestrutura
- Envia alertas via email

**Protocolos:** HTTPS (API REST), UDP (StatsD)

### 6. GitHub
**Tipo:** Sistema de Versionamento e CI/CD
**Responsabilidade:** Controle de versão e pipelines automatizados
**Provedor:** GitHub Inc.
**Interação:**
- Armazena código-fonte (4 repositórios)
- Executa CI/CD via GitHub Actions
- Build e push de imagens Docker
- Deploy em Kubernetes via kubectl

**Protocolos:** HTTPS (Git), GitHub API

### 7. Docker Hub
**Tipo:** Registry de Imagens Docker
**Responsabilidade:** Armazenar imagens containerizadas
**Provedor:** Docker Inc.
**Interação:**
- Recebe imagens via CI/CD (push)
- Fornece imagens para Kubernetes (pull)
- Versionamento via tags (fase2, latest)

**Protocolos:** HTTPS (Docker Registry API)

## Diagrama de Contexto (Descrição Textual)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          SISTEMA OFICINA SOAT                            │
│                                                                           │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                     Core Business Application                      │ │
│  │                                                                    │ │
│  │  • Gestão de Clientes e Veículos                                  │ │
│  │  • Gestão de Ordens de Serviço                                    │ │
│  │  • Gestão de Materiais e Serviços                                 │ │
│  │  • Autenticação e Autorização                                     │ │
│  │  • Logs de Eventos de Negócio                                     │ │
│  └────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────┘
                                     ▲
                                     │
          ┌──────────────────────────┼──────────────────────────┐
          │                          │                          │
          │                          │                          │
    ┌─────▼─────┐            ┌───────▼───────┐         ┌───────▼────────┐
    │  Cliente  │            │  Atendente    │         │  Mecânico      │
    │  Oficina  │            │  Oficina      │         │                │
    │           │            │               │         │                │
    │ [Pessoa]  │            │ [Pessoa]      │         │ [Pessoa]       │
    │           │            │               │         │                │
    │ • Autentica│            │ • Cadastra   │         │ • Visualiza    │
    │   via CPF │            │   clientes   │         │   ordens       │
    │ • Consulta │            │ • Cria OS    │         │ • Atualiza     │
    │   veículos │            │ • Adiciona   │         │   status       │
    │ • Aprova  │            │   materiais  │         │                │
    │   orçamento│            │              │         │                │
    └───────────┘            └───────────────┘         └────────────────┘

                    ┌────────────────┐
                    │ Gestor Oficina │
                    │                │
                    │ [Pessoa]       │
                    │                │
                    │ • Gerencia     │
                    │   usuários     │
                    │ • Dashboards   │
                    │ • Métricas     │
                    └───────┬────────┘
                            │
                            ▼
        ┌───────────────────────────────────────────────────────┐
        │                SISTEMAS EXTERNOS                       │
        ├───────────────────────────────────────────────────────┤
        │                                                        │
        │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐│
        │  │ AWS API      │  │ AWS Lambda   │  │ AWS EKS     ││
        │  │ Gateway      │  │ (Auth CPF)   │  │ (K8s)       ││
        │  │              │  │              │  │             ││
        │  │ [Infra]      │  │ [Serverless] │  │ [Platform]  ││
        │  └──────────────┘  └──────────────┘  └─────────────┘│
        │                                                        │
        │  ┌──────────────┐  ┌──────────────┐  ┌─────────────┐│
        │  │ PostgreSQL   │  │ Datadog      │  │ GitHub      ││
        │  │ 17.5         │  │ (Observ.)    │  │ (CI/CD)     ││
        │  │              │  │              │  │             ││
        │  │ [Database]   │  │ [SaaS]       │  │ [VCS]       ││
        │  └──────────────┘  └──────────────┘  └─────────────┘│
        │                                                        │
        │  ┌──────────────┐                                     │
        │  │ Docker Hub   │                                     │
        │  │ (Registry)   │                                     │
        │  │              │                                     │
        │  │ [SaaS]       │                                     │
        │  └──────────────┘                                     │
        └───────────────────────────────────────────────────────┘
```

## Fluxos Principais

### Fluxo 1: Autenticação de Cliente
1. **Cliente** acessa aplicação web/mobile
2. **Sistema** redireciona para tela de login
3. **Cliente** informa CPF
4. **Sistema** envia CPF para **AWS API Gateway**
5. **API Gateway** invoca **AWS Lambda** (auth-cpf)
6. **Lambda** valida CPF e consulta **PostgreSQL**
7. **Lambda** gera JWT e retorna para **Sistema**
8. **Sistema** armazena token e libera acesso

### Fluxo 2: Criação de Ordem de Serviço
1. **Atendente** acessa sistema (autenticado)
2. **Atendente** seleciona cliente e veículo
3. **Atendente** cria ordem de serviço
4. **Sistema** persiste ordem no **PostgreSQL**
5. **Sistema** envia evento de negócio para **Datadog**
6. **Sistema** confirma criação para **Atendente**

### Fluxo 3: Monitoramento e Alertas
1. **Sistema** executa operações de negócio
2. **Sistema** envia logs/métricas para **Datadog Agent** (assíncrono)
3. **Datadog** processa e armazena dados
4. **Gestor** acessa dashboards no **Datadog**
5. **Datadog** envia alertas via email se thresholds violados

### Fluxo 4: Deploy Contínuo
1. **Desenvolvedor** faz push para **GitHub**
2. **GitHub Actions** executa CI (testes, build, push Docker Hub)
3. **GitHub Actions** executa CD (deploy Kubernetes via kubectl)
4. **Kubernetes** realiza rolling update dos pods
5. **Datadog** monitora saúde do deploy

## Fronteiras do Sistema

**Dentro do escopo:**
- ✅ Gestão de clientes, veículos, ordens, materiais, serviços
- ✅ Autenticação via CPF + JWT
- ✅ Logs e monitoramento
- ✅ API REST
- ✅ Auto-scaling horizontal

**Fora do escopo (Tech Challenge Fase 3):**
- ❌ Pagamentos online (gateway de pagamento)
- ❌ Notificações push (email/SMS)
- ❌ Integração com fornecedores de peças
- ❌ Aplicação mobile nativa (apenas web responsiva)
- ❌ Multi-tenancy (suporte a múltiplas oficinas)

## Requisitos Não-Funcionais (High-Level)

**Performance:**
- Latência P95 <300ms (incluindo cold start Lambda)
- Throughput: 1.000 req/s (com HPA 10 pods)

**Disponibilidade:**
- Uptime: 99% (ambiente acadêmico)
- Self-healing: Kubernetes restart automático
- Auto-scaling: 1-10 pods baseado em CPU/Memória

**Segurança:**
- HTTPS obrigatório (TLS 1.2+)
- JWT com expiração de 1 hora
- Secrets via AWS Secrets Manager
- Volume PostgreSQL criptografado (EBS)

**Observabilidade:**
- Logs estruturados (JSON) centralizados
- Distributed tracing (APM Datadog)
- 3 dashboards de negócio
- 3 monitors com alertas

**Escalabilidade:**
- Horizontal: HPA Kubernetes
- Serverless: Lambda auto-scaling
- Database: Connection pool (100 conexões)

## Tecnologias Principais

- **Backend:** Laravel 12 (PHP 8.4)
- **Database:** PostgreSQL 17.5
- **Web Server:** Nginx (event-driven)
- **Auth:** JWT (HS256)
- **Infra:** Kubernetes (EKS), Terraform
- **Cloud:** AWS (us-east-2)
- **Monitoring:** Datadog
- **CI/CD:** GitHub Actions

## Referências

- [C4 Model Documentation](https://c4model.com/)
- [RFC-001: API Gateway Authentication](../rfcs/RFC-001-api-gateway-authentication.md)
- [RFC-002: Database Deployment Strategy](../rfcs/RFC-002-database-deployment-strategy.md)
- [RFC-003: Communication Patterns](../rfcs/RFC-003-communication-patterns.md)
- [ADR-005: Kubernetes + Terraform](../adrs/ADR-005-kubernetes-terraform.md)

## Palavras-Chave

`C4 Model` `Context Diagram` `System Boundary` `External Systems` `Actors` `Use Cases` `Oficina SOAT` `Architecture`
