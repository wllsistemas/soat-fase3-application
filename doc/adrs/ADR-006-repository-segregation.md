# ADR-006: Segregação em Quatro Repositórios Git Independentes

**Data:** 08/01/2026
**Status:** Aceita

## Contexto

O projeto Oficina SOAT é composto por múltiplos componentes tecnologicamente heterogêneos incluindo aplicação Laravel em containers Docker, infraestrutura Kubernetes provisionada via Terraform, banco de dados PostgreSQL gerenciado via Terraform, e função serverless AWS Lambda para autenticação. O Tech Challenge - Fase 3 estabelece como requisito obrigatório a organização do código em quatro repositórios Git separados com CI/CD independente para cada componente.

A escolha entre monorepo (repositório único contendo todos os componentes) versus multirepo (repositórios separados por componente) impacta significativamente aspectos operacionais críticos incluindo ownership e responsabilidade de times, velocidade de pipelines CI/CD, granularidade de permissões e segurança, facilidade de deploy independente, e complexidade de coordenação entre componentes.

Do ponto de vista organizacional, equipes especializadas gerenciam diferentes aspectos do sistema onde desenvolvedores backend focam em aplicação Laravel, engenheiros DevOps/SRE gerenciam infraestrutura Kubernetes, DBAs gerenciam configuração e otimização de PostgreSQL, e especialistas serverless gerenciam Lambda functions. A separação física de código em repositórios diferentes alinha ownership com especialização técnica.

Do ponto de vista técnico, componentes possuem ciclos de vida de deploy distintos onde aplicação Laravel evolui rapidamente com features e bug fixes, infraestrutura Kubernetes evolve lentamente com mudanças esporádicas de configuração, banco de dados evolve raramente com migrations e tuning ocasional, e Lambda functions evolvem independentemente para adicionar novos métodos de autenticação.

### Proposta de Discussão

Esta seção documenta a análise técnica realizada para fundamentar a escolha da estratégia de versionamento de código, considerando alternativas viáveis e seus respectivos trade-offs.

**Alternativa 1: Quatro Repositórios Independentes (Proposta Selecionada)**

Estrutura multirepo organiza código em quatro repositórios Git completamente independentes hospedados em GitHub sob organização wllsistemas. Repositório soat-fase3-application contém código da aplicação Laravel, manifests Kubernetes para deploy, Dockerfiles para build de imagens, testes unitários e feature, e CI/CD completo (build, test, push Docker Hub, deploy K8s). Repositório soat-fase3-infra contém código Terraform para provisionar EKS cluster, configuração de IAM roles, integração Datadog, HPA e Metrics Server, e CI/CD para Terraform (init, validate, plan, apply manual).

Repositório soat-fase3-database contém código Terraform para provisionamento de PostgreSQL autogerenciado, PersistentVolumeClaim e StorageClass, secrets de credenciais, e CI/CD para Terraform. Repositório soat-fase3-lambda contém código Node.js da função Lambda, testes unitários com Jest, dependências npm, e CI/CD para deploy Lambda (test, zip, aws lambda update-function-code).

Os benefícios incluem deploy completamente independente onde CI/CD de cada repositório executa isoladamente sem dependências. Deploy de Lambda não requer rebuild de aplicação Laravel. Rollback granular permite reverter mudanças em componente específico sem afetar outros. Testes isolados onde falha em Lambda não bloqueia pipeline de Application. Build cache é mantido separadamente por repositório reduzindo tempo de CI.

Ownership claro define responsabilidades por repositório. Backend developers são owners de soat-fase3-application com permissões de merge. DevOps/SRE team são owners de soat-fase3-infra. DBAs são owners de soat-fase3-database. Serverless team são owners de soat-fase3-lambda. GitHub teams mapeiam permissões por repositório.

Velocidade de CI/CD é maximizada através de pipelines paralelos executando simultaneamente sem bloqueio. Application pipeline executa testes PHP enquanto Lambda pipeline executa testes Jest em paralelo. Mudanças em Application não triggeram rebuild de infraestrutura. Feedback loop é acelerado com pipelines focados.

Segurança é melhorada através de permissões granulares via GitHub teams. Secrets isolados onde cada repositório armazena secrets próprios (AWS credentials, DB passwords, API keys) sem exposição cross-repo. Branch protection independente permite políticas distintas (ex: Infra requer 2 approvers, Application requer 1).

Cumprimento do requisito do Tech Challenge Fase 3 é completo com 4 repositórios separados. README.md dedicado por componente documenta especificidades. Clareza de documentação facilita onboarding.

As limitações incluem sincronização onde mudanças cross-repo exigem coordenação manual. Mudança em schema de banco (migration) requer atualização em Application repository. API contracts entre Lambda e Application devem ser sincronizados manualmente. Overhead de comunicação aumenta entre times.

Potencial duplicação de configurações compartilhadas como Terraform modules, GitHub Actions workflows, e linting rules. Esse impacto é mitigado através de Terraform modules reutilizáveis publicados em registry privado, GitHub Actions workflows composable via actions compartilhadas, e linting configs via npm packages compartilhados.

Complexidade de setup inicial onde desenvolvedores devem clonar 4 repositórios, configurar 4 ambientes de desenvolvimento localmente, e entender 4 pipelines CI/CD distintos.

**Alternativa 2: Monorepo**

Monorepo consolida todos os componentes em repositório Git único organizando código em diretórios /application, /infrastructure, /database, /lambda com tooling compartilhado para build, test e deploy.

Os benefícios incluem código compartilhado fácil onde Terraform modules, GitHub Actions workflows, e utilidades são compartilhados sem publicação. Refactoring atômico permite mudanças cross-component em single commit. Single source of truth simplifica descoberta de código. Menor overhead de setup com único clone de repositório.

As limitações críticas incluem CI/CD lento onde pipeline único deve buildar e testar todos os componentes mesmo se mudança afeta apenas um. Timeout de CI aumenta proporcionalmente ao tamanho do monorepo. Permissões difíceis onde GitHub não oferece permissões granulares por diretório dentro de repositório. Impossível limitar acesso de backend developers apenas a /application. Ownership ambíguo onde responsabilidade por componentes é menos clara. Não atende requisito explícito do Tech Challenge de 4 repositórios separados.

**Alternativa 3: Dois Repositórios (Application + Infraestrutura)**

Estrutura híbrida consolida código relacionado em dois repositórios: soat-application-full contendo /backend (Laravel), /lambda (auth), e soat-infrastructure contendo /kubernetes (manifestos), /terraform (provisioning).

Os benefícios incluem redução de overhead comparado a 4 repositórios, co-location de Application e Lambda que frequentemente interagem, e separação de concerns entre código de aplicação e infraestrutura.

As limitações críticas incluem não atendimento do requisito obrigatório do Tech Challenge de 4 repositórios separados. Ownership ainda ambíguo dentro de repositórios. Benefícios de multirepo são parcialmente perdidos.

**Análise Comparativa**

Quatro repositórios independentes oferece cumprimento completo do requisito obrigatório do Tech Challenge, máxima autonomia de times especializados, velocidade de CI/CD através de pipelines paralelos focados, e segurança através de permissões granulares. Overhead de sincronização é aceito considerando benefícios de independência.

Monorepo seria tecnicamente mais simples para setup e refactoring mas viola requisito obrigatório do Tech Challenge, gera CI/CD lento, e não permite permissões granulares. Dois repositórios também viola requisito obrigatório e perde benefícios de separação completa.

## Decisão

A equipe decidiu adotar estrutura de quatro repositórios Git completamente independentes hospedados em GitHub sob organização wllsistemas: soat-fase3-application, soat-fase3-infra, soat-fase3-database, e soat-fase3-lambda. Cada repositório possui CI/CD independente, ownership claro, e segregação completa de código e configuração. Essa decisão fundamenta-se no requisito obrigatório do Tech Challenge, benefícios de autonomia de times, velocidade de CI/CD paralelos, e segurança via permissões granulares.

Repositório soat-fase3-application contém aplicação Laravel completa em /backend, manifests Kubernetes em /k8s para deploy, Dockerfiles em /build para construção de imagens PHP e Nginx, testes em /tests (Unit e Feature), CI pipeline (.github/workflows/application.yaml) executando tests → build Docker → push Docker Hub → email notification, e CD pipeline executando validate CI → copy manifests K8s → kubectl apply → email notification. Branch main protegida exigindo pull request e 1 approval. README.md documenta stack Laravel, setup local, comandos úteis e estrutura Clean Architecture.

Repositório soat-fase3-infra contém código Terraform em arquivos .tf (eks.tf, datadog.tf, hpa.tf, roles.tf, metrics-server.tf), backend S3 configurado em provider.tf com state em s3-fiap-soat-fase3/terraform.tfstate, CI/CD pipeline (.github/workflows/terraform.yaml) com workflow_dispatch manual executando init → validate → plan → apply, e README.md documentando recursos provisionados e comandos Terraform.

Repositório soat-fase3-database contém código Terraform para PostgreSQL (pod-postgres.tf, pvc-postgres.tf, svc-postgres.tf, secret-postgres.tf, storage.tf), backend S3 com state em s3-fiap-soat-fase3/database/terraform.tfstate, CI/CD pipeline similar a Infra com trigger manual, e README.md documentando configuração PostgreSQL e storage.

Repositório soat-fase3-lambda contém código Node.js em /hello-world/app.mjs com 3 actions (validate document, validate customer status, generate token), dependências em package.json (pg, jsonwebtoken, bcryptjs), testes unitários em /tests, CI/CD pipeline executando npm install → npm test → zip → aws lambda update-function-code, e README.md documentando actions disponíveis e exemplos de payload.

Branch protection configurada em todos os repositórios exigindo pull requests para branch main/master. Application e Lambda exigem 1 approval. Infra e Database exigem 2 approvals devido a impacto crítico em infraestrutura. Status checks obrigatórios incluindo CI pipeline success. Deletion de branches após merge habilitado.

GitHub Teams mapeiam ownership com Backend Team (read/write em soat-fase3-application), DevOps Team (read/write em soat-fase3-infra), DBA Team (read/write em soat-fase3-database), e Serverless Team (read/write em soat-fase3-lambda). Admin team possui acesso total a todos os repositórios.

Secrets gerenciados separadamente em GitHub Secrets por repositório. Application armazena DOCKER_HUB_USERNAME, DOCKER_HUB_TOKEN, KUBECONFIG. Infra armazena AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY (ou OIDC role). Database armazena credenciais similares. Lambda armazena AWS credentials e JWT_SECRET.

## Consequências

### Positivas

Autonomia completa de times permite trabalho independente sem bloqueios. Backend developers fazem deploy de features sem esperar aprovação de DevOps. DBAs ajustam configuração PostgreSQL sem coordenação com Application. Serverless team adiciona novos métodos de autenticação em Lambda sem impactar aplicação principal.

Velocidade de CI/CD é maximizada através de pipelines paralelos executando simultaneamente. Application pipeline completo em aproximadamente 5 minutos. Lambda pipeline completo em aproximadamente 2 minutos. Infra pipeline (plan only) em aproximadamente 1 minuto. Falha em um pipeline não bloqueia outros.

Clareza de ownership elimina ambiguidade de responsabilidade. Code review assignments são automáticos via CODEOWNERS file. Incident response identifica rapidamente time responsável baseado em repositório afetado.

Segurança aprimorada através de permissões granulares onde backend developers não têm acesso a secrets de infraestrutura. Junior developers podem ter acesso apenas a repositório Application. Audit trail é claro rastreando mudanças por repositório.

Cumprimento completo do requisito obrigatório do Tech Challenge Fase 3 com 4 repositórios separados, CI/CD independente para cada componente, e README.md dedicado documentando especificidades.

### Negativas

Sincronização cross-repo exige coordenação manual. Mudanças em API contracts entre Lambda e Application requerem PRs em ambos os repositórios coordenados temporalmente. Mudanças em schema de banco (migration) requerem atualização de código Application sincronizada. Overhead de comunicação aumenta entre times para garantir compatibilidade.

Potencial duplicação de configurações compartilhadas como GitHub Actions workflows (setup de AWS credentials, notification emails repetidos em todos os pipelines), linting configs (.eslintrc, phpcs.xml replicados), e Terraform modules (potencialmente duplicados entre Infra e Database). Mitigação via GitHub Actions composite actions, npm packages compartilhados para configs, e Terraform module registry privado.

Complexidade de setup para novos desenvolvedores onde onboarding requer clonar 4 repositórios, configurar 4 ambientes locais, e entender 4 pipelines CI/CD. Mitigação via script de setup automatizado e documentação consolidada em wiki centralizado.

Overhead de manutenção de 4 pipelines CI/CD onde atualizações de GitHub Actions (ex: upgrade de actions/checkout v3 para v4) devem ser replicadas em 4 workflows. Mitigação via Dependabot automatizado e batch updates.

## Notas de Implementação

Repositórios criados em GitHub sob organização wllsistemas com visibilidade private. URLs: github.com/wllsistemas/soat-fase3-application, github.com/wllsistemas/soat-fase3-infra, github.com/wllsistemas/soat-fase3-database, github.com/wllsistemas/soat-fase3-lambda.

Branch protection configurada via Settings → Branches → Add rule com pattern main ou master, require pull request before merging habilitado, require approvals configurado (1 para Application/Lambda, 2 para Infra/Database), require status checks to pass habilitado com CI pipeline como check obrigatório, e automatically delete head branches habilitado.

CODEOWNERS file adicionado em cada repositório definindo ownership automático. Application .github/CODEOWNERS contém * @wllsistemas/backend-team. Infra contém * @wllsistemas/devops-team. Database contém * @wllsistemas/dba-team. Lambda contém * @wllsistemas/serverless-team.

GitHub Teams criados via Settings → Teams com Backend Team, DevOps Team, DBA Team, Serverless Team, e Admin Team. Permissions configuradas via repository settings → Manage access → Add teams com role Write para teams específicos.

## Revisões

- **05/11/2024**: Decisão inicial (Aceita)
- **10/11/2024**: Criação dos 4 repositórios em GitHub
- **15/11/2024**: Configuração de branch protection e teams
- **20/11/2024**: Setup de CI/CD em todos os repositórios
- **08/01/2026**: Revisão para documentação Fase 3 com formato ADR+RFC rigoroso

## Referências

- Monorepo vs Multirepo - https://www.atlassian.com/git/tutorials/monorepos
- GitHub Branch Protection - https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches
- GitHub CODEOWNERS - https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/customizing-your-repository/about-code-owners
- GitHub Teams Permissions - https://docs.github.com/en/organizations/managing-peoples-access-to-your-organization-with-roles/about-teams

## Palavras-Chave

Git, Monorepo, Multirepo, Repository Strategy, CI/CD, Ownership, Segregation, Branch Protection, GitHub Teams, Code Organization, ADR, RFC, Tech Challenge
