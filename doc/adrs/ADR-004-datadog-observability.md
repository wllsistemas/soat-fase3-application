# ADR-004: Adoção do Datadog como Plataforma de Observabilidade

**Data:** 08/01/2026
**Status:** Aceita

## Contexto

O sistema Oficina SOAT é uma aplicação distribuída composta por múltiplos componentes executando em ambientes distintos: AWS Lambda para autenticação serverless, cluster AWS EKS (Elastic Kubernetes Service) para aplicação Laravel, e PostgreSQL para persistência de dados. Essa arquitetura distribuída apresenta desafios significativos de observabilidade pois comportamento e performance do sistema emergem da interação entre componentes distribuídos geograficamente e tecnologicamente heterogêneos.

O Tech Challenge - Fase 3 estabelece requisitos obrigatórios de monitoramento e observabilidade incluindo monitoramento de latência de APIs com percentis P95 e P99, monitoramento de recursos Kubernetes (CPU, memória, pods), healthchecks automatizados de aplicação e banco de dados, logs estruturados em formato JSON com correlação entre requisições, dashboards visualizando volume de ordens de serviço e tempo médio de processamento, dashboards de performance geral do sistema, dashboards de erros e logs agregados por severidade, e alertas proativos para degradação de performance, erros acima de threshold definido e indisponibilidade de componentes.

Os desafios técnicos de observabilidade em sistemas distribuídos incluem distributed tracing onde requisição atravessa múltiplos serviços (API Gateway → Lambda → Laravel → PostgreSQL) exigindo rastreamento end-to-end. Log aggregation é necessário para agregar logs de múltiplos pods Kubernetes e execuções Lambda em local centralizado. Metrics collection deve coletar métricas de infraestrutura (Kubernetes nodes, pods) e aplicação (throughput, latência, erros). Correlation entre logs, traces e métricas é essencial para troubleshooting efetivo onde investigação de erro requer navegar entre log específico, trace distribuído correspondente e métricas de contexto. Alerting proativo deve detectar degradação antes de impactar usuários finais através de thresholds configurados em métricas e anomaly detection.

Do ponto de vista organizacional, o projeto é acadêmico com restrições orçamentárias favorecendo soluções com free tier generoso. A equipe possui conhecimento limitado em observabilidade avançada preferindo soluções com setup simplificado e documentação abundante. O tempo disponível para implementação é limitado devido a prazos de entrega do Tech Challenge, favorecendo soluções com integração rápida ao invés de customização extensa.

### Proposta de Discussão

Esta seção documenta a análise técnica realizada para fundamentar a escolha da plataforma de observabilidade, considerando alternativas viáveis no mercado e seus respectivos trade-offs em contexto de sistema distribuído acadêmico.

**Alternativa 1: Datadog (Proposta Selecionada)**

Datadog é uma plataforma SaaS de observabilidade completa oferecendo APM (Application Performance Monitoring), log management, infrastructure monitoring, synthetics, e real user monitoring em solução unificada. O modelo de negócio é subscription-based com pricing por hosts monitorados, mas oferece free tier generoso para projetos educacionais e startups.

O APM (Application Performance Monitoring) do Datadog oferece auto-instrumentation para PHP através da extensão ddtrace que captura automaticamente requisições HTTP com método, URL, status code, duração e headers relevantes. Queries SQL são rastreadas automaticamente com banco de dados, query text, duração e explain plans. Laravel routing e middleware são capturados incluindo nomes de rotas, controllers e middlewares executados. Exceptions e stack traces completos são capturados automaticamente com contexto de execução. Distributed tracing rastreia requisições atravessando múltiplos serviços injetando trace IDs em headers HTTP.

Log Management agrega logs de múltiplos sources (Kubernetes pods, Lambda executions, databases) em índice centralizado pesquisável. Logs estruturados em JSON são parseados automaticamente extraindo fields como severity, timestamp, message, trace_id e custom attributes. Correlação automática entre logs e traces é habilitada através de dd.trace_id injection permitindo clicar em log e visualizar trace completo correspondente. Log patterns e analytics permitem agrupar logs similares e identificar patterns anômalos. Retention configurável balanceia custo e auditability.

Infrastructure Monitoring coleta métricas de hosts, containers e orquestração automaticamente. Kubernetes integration via DaemonSet captura métricas de nodes (CPU, memória, disco, rede), pods (resource usage, restarts, OOMKills), deployments (replicas, rollout status), e services (endpoints, latência). AWS integration captura métricas de Lambda (invocations, duration, errors, throttles), EKS (cluster health), e RDS/PostgreSQL (connections, throughput, latência). Métricas customizadas podem ser enviadas via DogStatsD para business metrics como número de ordens criadas por minuto.

Dashboards personalizáveis permitem criar visualizações combinando métricas, logs e traces. Widgets suportam timeseries, heatmaps, top lists, query values, e logs stream. Template variables permitem filtrar dashboards por environment, service ou custom tags. Dashboards podem ser compartilhados via URL público para stakeholders sem acesso Datadog.

Monitors e Alerting permitem configurar thresholds em métricas (ex: latência P95 > 2 segundos por 5 minutos) com notificações via email, Slack, PagerDuty, webhooks. Anomaly detection usa machine learning para detectar desvios de padrões históricos. Composite monitors combinam múltiplas condições com lógica AND/OR. Downtime scheduling silencia alertas durante manutenções programadas.

Os benefícios incluem solução unificada eliminando necessidade de integrar múltiplas ferramentas. Setup rápido através de agents pré-configurados e auto-instrumentation. Correlação nativa entre APM, logs e métricas facilitando troubleshooting. Documentação extensa com guias específicos para PHP, Laravel, Kubernetes e AWS Lambda. Free tier generoso para ambientes acadêmicos com limitações aceitáveis. Interface intuitiva reduzindo curva de aprendizado.

As limitações incluem custo potencialmente elevado em produção pós-free tier com pricing por hosts monitorados. Vendor lock-in em plataforma SaaS onde migração futura para solução alternativa requer reconfiguração completa. Dependência de conectividade internet para visualizar dashboards e receber alertas. Menor controle sobre retenção e processamento de dados comparado a soluções self-hosted.

**Alternativa 2: New Relic**

New Relic é plataforma SaaS de observabilidade similar ao Datadog oferecendo APM, log management, infrastructure monitoring e synthetics. Modelo de negócio subscription-based com pricing por data ingest e usuários.

Os benefícios incluem APM robusto com distributed tracing, interface moderna e intuitiva, integrações com AWS e Kubernetes, free tier disponível embora com limitações maiores que Datadog.

As limitações incluem custo geralmente mais elevado que Datadog pós-free tier. APM para PHP menos maduro que para linguagens como Java e .NET. Documentação menos abundante para stack PHP/Laravel comparada ao Datadog. Menor adoção na comunidade PHP resultando em menos recursos de troubleshooting disponíveis.

**Alternativa 3: CloudWatch + Prometheus + Grafana**

Stack open-source e AWS-native combinando AWS CloudWatch para logs e métricas de serviços AWS (Lambda, EKS), Prometheus para coleta de métricas de aplicação e Kubernetes, e Grafana para visualização e dashboards.

Os benefícios incluem custo potencialmente menor usando componentes open-source. CloudWatch nativo para Lambda elimina configuração adicional. Prometheus é padrão de facto para monitoramento Kubernetes. Grafana oferece dashboards altamente customizáveis. Controle total sobre dados sem vendor lock-in SaaS.

As limitações críticas incluem complexidade significativa de integração entre 3 ferramentas distintas. CloudWatch não oferece APM automático para Laravel exigindo instrumentação manual. Correlação entre logs CloudWatch, métricas Prometheus e traces requer configuração customizada complexa. Prometheus requer operação de infraestrutura adicional (Prometheus server, Alertmanager, storage). Grafana self-hosted adiciona overhead operacional. Tempo de setup e configuração significativamente maior que solução SaaS.

**Alternativa 4: Elastic Stack (ELK)**

Elastic Stack combina Elasticsearch para armazenamento e busca, Logstash ou Filebeat para coleta de logs, Kibana para visualização, e APM Server para distributed tracing.

Os benefícios incluem stack completo open-source sem licensing costs. Elasticsearch oferece busca full-text poderosa em logs. Kibana permite dashboards customizáveis e análise exploratória. Elastic APM oferece distributed tracing. Controle total sobre dados e retenção.

As limitações críticas incluem complexidade operacional de gerenciar cluster Elasticsearch com alta disponibilidade, replicação e backups. Overhead de infraestrutura exigindo recursos computacionais significativos para Elasticsearch cluster. Curva de aprendizado steep para configuração adequada de índices, shards e replicas. Integração com Kubernetes requer deployment de múltiplos componentes (APM Server, Filebeat DaemonSet, Metricbeat). Tempo de setup significativamente maior que solução SaaS. Escalabilidade horizontal de Elasticsearch requer expertise.

**Análise Comparativa**

Datadog oferece o melhor equilíbrio entre completude de features, velocidade de setup, facilidade de uso e custo em contexto acadêmico. APM automático via ddtrace elimina instrumentação manual. Correlação nativa entre logs e traces reduz drasticamente tempo de troubleshooting. Dashboards pré-configurados para Kubernetes e Laravel aceleram time-to-value. Free tier generoso atende projeto acadêmico. Interface intuitiva reduz curva de aprendizado para equipe sem experiência profunda em observabilidade.

New Relic seria alternativa aceitável mas possui custo superior e APM menos maduro para PHP. Stack CloudWatch + Prometheus + Grafana seria inadequado devido a complexidade de integração incompatível com prazo de entrega do Tech Challenge. Elastic Stack seria inadequado devido a overhead operacional incompatível com capacidade da equipe e restrições de infraestrutura.

## Decisão

A equipe decidiu adotar Datadog como plataforma única de observabilidade integrando APM (Application Performance Monitoring), log management, infrastructure monitoring, dashboards customizados e alertas proativos. Essa decisão fundamenta-se na análise comparativa de alternativas considerando requisitos obrigatórios do Tech Challenge, complexidade da arquitetura distribuída, restrições de tempo e orçamento, e capacidade técnica da equipe.

A implementação de APM utiliza ddtrace extension para PHP instalada via Docker no container PHP-FPM. A extension é configurada através de variáveis de ambiente DD_SERVICE definindo nome do serviço como "oficina-soat-api", DD_ENV especificando environment (development, staging, production), DD_VERSION identificando versão da aplicação para tracking de deployments, DD_AGENT_HOST apontando para Datadog Agent (localhost em Docker Compose, datadog-agent service em Kubernetes), e DD_TRACE_SAMPLE_RATE configurando sampling (1.0 para 100% em ambiente acadêmico). Auto-instrumentation captura automaticamente todas as requisições HTTP, queries SQL via PDO/Eloquent, execuções de Jobs Laravel, invocações de Queue, chamadas HTTP outbound via Guzzle, exceptions não tratadas, e custom spans podem ser criados via OpenTelemetry API para lógica de negócio específica.

O log management utiliza BusinessEventLogger trait implementado em app/Infrastructure/Service/BusinessEventLogger.php para logs estruturados de eventos de negócio. O trait injeta automaticamente dd.trace_id extraído de Datadog span context current permitindo correlação automática com traces. Campos customizados são adicionados incluindo ordem.uuid, cliente.uuid, status.anterior, status.novo, valor.total, e qualquer campo relevante ao contexto de negócio. Severity levels seguem padrão PSR-3 (debug, info, warning, error, critical). Formato JSON estruturado facilita parsing e indexação no Datadog. Eventos de negócio rastreados incluem ordem.criada logado quando ordem de serviço é criada, ordem.status.atualizado logado em transições de estado, ordem.aprovada logado quando cliente aprova orçamento, ordem.reprovada logado quando cliente rejeita orçamento, e ordem.finalizada logado quando ordem é concluída.

Infrastructure monitoring é realizado através de Datadog Agent deployado como DaemonSet em Kubernetes garantindo um pod Agent por node. O Agent coleta métricas de nodes Kubernetes (CPU usage, memory usage, disk I/O, network I/O), métricas de pods (resource requests/limits, restarts, OOMKills, readiness/liveness probes), métricas de containers Docker (CPU throttling, memory usage, network), métricas de aplicação via DogStatsD (custom metrics enviados da aplicação Laravel), e integração com AWS para métricas de EKS, Lambda e RDS. RBAC (Role-Based Access Control) é configurado via ServiceAccount, ClusterRole e ClusterRoleBinding permitindo Agent acessar Kubernetes API para coletar métricas. Secret armazena DD_API_KEY de forma segura via Kubernetes Secret.

Três dashboards personalizados foram implementados. Dashboard "Volume de Ordens de Serviço" (ID: mba-eyq-v9q) visualiza throughput de ordens criadas por minuto via custom metric enviada por BusinessEventLogger, latência P50/P95/P99 de endpoint POST /ordem via APM traces, distribuição de status de ordens via log aggregation, e tempo médio de processamento de ordem calculado via custom span. Dashboard "Performance Geral" (ID: zwb-yuc-jc5) visualiza CPU e memória de pods PHP e Nginx via infrastructure metrics, número de traces por segundo indicando throughput geral, latência P99 de todas as requisições HTTP, error rate percentual de requisições com status 5xx, e throughput e latência de queries SQL ao PostgreSQL. Dashboard "Erros e Logs" (ID: u5k-e35-r5t) visualiza taxa de erros 5xx agregada por endpoint, logs agregados por severity level (error, warning, info), top 10 exceptions por tipo com contagem, e log stream filtrado por severity error para investigação imediata.

Três monitors com alertas proativos foram configurados. Monitor "Latência Alta P95" (ID: 17436379) dispara quando latência P95 de qualquer endpoint excede 2 segundos por período de 5 minutos consecutivos. Notificação é enviada via email para equipe com link direto para APM traces do período afetado. Threshold de warning em 1.5 segundos permite ação preventiva. Monitor "Taxa de Erro Alta" (ID: 17436427) dispara quando percentual de requisições com status 5xx excede 5% em janela de 5 minutos. Notificação inclui breakdown por endpoint identificando origem dos erros. Threshold de warning em 3% permite detecção precoce. Monitor "Container PHP Parado" (ID: 17436428) dispara quando número de pods PHP running em namespace lab-soat cai para zero indicando total indisponibilidade. Notificação crítica via email e Slack exige ação imediata. Recovery notification é enviada quando pods retornam a estado running.

A configuração de ambiente local via Docker Compose inclui service datadog-agent com image datadog/agent:latest, variáveis de ambiente DD_API_KEY obtida de arquivo .env, DD_SITE us5.datadoghq.com especificando datacenter, DD_APM_ENABLED true habilitando APM, DD_LOGS_ENABLED true habilitando log collection, DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL true coletando logs de todos os containers, e volumes montando /var/run/docker.sock para acesso a Docker API, /proc/ para métricas de host, /sys/fs/cgroup/ para métricas de cgroups.

A configuração de ambiente Kubernetes inclui três manifestos. Secret 14-secret-datadog.yaml armazena DD_API_KEY codificada em base64. RBAC 15-datadog-rbac.yaml define ServiceAccount datadog-agent, ClusterRole com permissões get/list/watch em nodes, pods, services, endpoints, events, e ClusterRoleBinding vinculando ServiceAccount a ClusterRole. DaemonSet 16-datadog-agent.yaml deploya Agent em todos os nodes com containers datadog-agent executando main agent, trace-agent processando APM traces, e process-agent coletando métricas de processos. Variáveis de ambiente são injetadas via secretRef e fieldRef para node metadata. Volume mounts incluem /var/run/docker.sock, /proc/, /sys/fs/cgroup/, /etc/passwd para user resolution.

## Consequências

### Positivas

A visibilidade total do sistema é alcançada através de plataforma unificada combinando APM, logs, métricas e infrastructure monitoring eliminando context switching entre ferramentas. Single pane of glass permite visualizar estado completo do sistema distribuído em interface única. Troubleshooting end-to-end é facilitado navegando de alerta para métrica para log para trace em poucos cliques.

A correlação automática entre logs e traces através de dd.trace_id injection permite investigar erro clicando em log e visualizando trace distribuído completo mostrando exatamente onde requisição falhou. Inversamente, clicar em trace exibe todos os logs gerados durante processamento daquela requisição específica. Isso reduz drasticamente tempo médio de resolução (MTTR) de incidentes.

Dashboards operacionais prontos atendem requisitos obrigatórios do Tech Challenge sem desenvolvimento customizado. Dashboard de Volume de Ordens visualiza throughput e latência conforme especificação. Dashboard de Performance monitora recursos Kubernetes e APM conforme especificação. Dashboard de Erros e Logs agrega erros por severidade conforme especificação.

Alertas proativos permitem detecção de degradação antes de impacto total aos usuários. Monitor de Latência Alta detecta degradação de performance permitindo investigação preventiva. Monitor de Taxa de Erro Alta detecta aumento de falhas permitindo correção antes de indisponibilidade total. Monitor de Container Parado detecta indisponibilidade completa exigindo ação imediata de recovery.

Setup rápido através de agents pré-configurados e auto-instrumentation permitiu implementação completa de observabilidade em aproximadamente 2 dias de trabalho. Datadog Agent em Kubernetes requer apenas 3 manifestos YAML. APM em Laravel requer apenas instalação de ddtrace extension e configuração de variáveis de ambiente. Sem necessidade de instrumentação manual de código.

Interface intuitiva reduz curva de aprendizado para equipe sem experiência profunda em observabilidade. Dashboards drag-and-drop simplificam criação de visualizações. Query language é acessível para desenvolvedores sem background em observabilidade. Documentação interativa com exemplos específicos para PHP/Laravel acelera onboarding.

Cumprimento completo dos requisitos obrigatórios do Tech Challenge Fase 3 incluindo monitoramento de latência com percentis, monitoramento de recursos Kubernetes, logs estruturados com correlação, dashboards de volume/performance/erros, e alertas proativos.

### Negativas

O custo de licença Datadog pode ser significativo em ambiente de produção real pós-free tier. Pricing é baseado em hosts monitorados (aproximadamente $15-31 por host por mês dependendo do plano) e data ingestion para logs (aproximadamente $0.10 por GB ingerido). Esse impacto é mitigado no contexto acadêmico através de free tier generoso com limites aceitáveis para projeto de pequeno porte. Em eventual transição para produção comercial, custo deve ser reavaliado e possivelmente migração para solução open-source considerada.

O vendor lock-in em plataforma SaaS cria dependência de Datadog para observabilidade crítica. Dashboards, monitors, queries e correlações são proprietários da plataforma. Migração futura para New Relic, Elastic ou solução open-source requereria reconfiguração completa de dashboards, monitors, instrumentação e treinamento de equipe. Esse impacto é aceito no contexto acadêmico considerando benefícios de velocidade de setup e facilidade de uso. Mitigação futura pode incluir adoção de OpenTelemetry para instrumentação vendor-neutral permitindo trocar backend de observabilidade sem reinstrumentação de código.

A dependência de conectividade internet para visualizar dashboards e receber alertas pode ser problemática em ambientes com conectividade instável ou requisitos de air-gap. Datadog é exclusivamente SaaS sem opção self-hosted. Interrupção de conectividade impede acesso a dashboards embora aplicação continue funcionando. Esse impacto é negligenciável em ambiente cloud-native AWS onde conectividade é confiável.

O menor controle sobre retenção e processamento de dados comparado a soluções self-hosted como Elastic Stack. Datadog define políticas de retenção padrão (15 dias para logs, 15 meses para métricas) com opções limitadas de customização. Logs contendo dados sensíveis são processados em servidores Datadog embora sejam criptografados em trânsito e em repouso. Esse impacto é aceito no contexto acadêmico onde dados não são sensíveis. Em produção com dados regulados (LGPD, GDPR), políticas de Data Processing Agreement devem ser revisadas.

A complexidade de billing pode surpreender em casos de uso inesperado. Métricas customizadas excessivas podem gerar custos adicionais. Log ingestion de aplicações verbose pode exceder limites de free tier. Falta de monitoring de custos no próprio Datadog dificulta previsão de billing. Esse impacto é mitigado através de sampling de logs (não coletar logs debug em produção), agregação de métricas customizadas, e revisão mensal de usage via Datadog billing dashboard.

## Notas de Implementação

A instalação do Datadog Agent em Docker Compose local utiliza service datadog-agent definido em docker-compose.yaml com image datadog/agent:latest garantindo versão mais recente. Variáveis de ambiente são carregadas de arquivo .env contendo DD_API_KEY obtida da página API Keys em app.datadoghq.com. Volumes montam /var/run/docker.sock:ro permitindo Agent acessar Docker API, /proc/:ro para métricas de host, /sys/fs/cgroup/:ro para métricas de cgroups. Network é compartilhada com services da aplicação permitindo Agent coletar métricas de containers PHP e Nginx.

A instalação do Datadog Agent em Kubernetes utiliza provisionamento via Terraform no repositório soat-fase3-infra através do arquivo datadog.tf. O Terraform Kubernetes provider cria todos os recursos necessários incluindo Secret contendo DD_API_KEY recuperada de AWS Secrets Manager ou variável de ambiente, ServiceAccount datadog-agent no namespace lab-soat para identidade do Agent, ClusterRole datadog-agent com permissões para ler métricas de nodes, pods, deployments, services e events via Kubernetes API, ClusterRoleBinding ligando ServiceAccount a ClusterRole, e DaemonSet datadog-agent deployando Agent em todos os nodes com image datadog/agent:latest, update strategy RollingUpdate garantindo rolling update sem downtime, tolerations para master nodes permitindo Agent coletar métricas de control plane, resource requests (memory: 256Mi, cpu: 200m) e limits (memory: 512Mi, cpu: 500m), liveness probe httpGet /health port 5555 e readiness probe httpGet /ready port 5555 verificando health de Agent, environment variables injetadas via Terraform variables incluindo DD_API_KEY via Secret, DD_SITE (datadoghq.com), DD_LOGS_ENABLED (true), DD_APM_ENABLED (true), DD_KUBERNETES_KUBELET_HOST via downward API, e volumes montando /var/run/docker.sock, /proc/, /sys/fs/cgroup/ para coleta de métricas. Backend Terraform utiliza mesmo bucket S3 s3-fiap-soat-fase3 na região us-east-2 compartilhado com outros recursos de infraestrutura.

A configuração de APM em Laravel instala ddtrace extension via composer ou pecl durante build de Docker image. Dockerfile adiciona linha RUN pecl install ddtrace && docker-php-ext-enable ddtrace. Variáveis de ambiente DD_SERVICE, DD_ENV, DD_VERSION, DD_AGENT_HOST são injetadas via ConfigMap em Kubernetes ou environment section em docker-compose.yaml. Laravel logging channel datadog é configurado em config/logging.php adicionando driver 'monolog', handler DatadogHandler::class, formatter DatadogFormatter::class, e level env('LOG_LEVEL', 'debug').

BusinessEventLogger trait é implementado em app/Infrastructure/Service/BusinessEventLogger.php como trait reutilizável. Método logBusinessEvent recebe event name, context array e severity. Implementação extrai trace_id de \DDTrace\current_context() se disponível, mescla context com trace_id e custom attributes, serializa em JSON, e envia para Laravel logger via Log::channel('datadog')->{severity}(). Trait é utilizado via use BusinessEventLogger em Use Cases onde eventos de negócio são logados como $this->logBusinessEvent('ordem.criada', ['ordem.uuid' => $uuid], 'info').

Três dashboards foram criados via Datadog web UI em app.datadoghq.com/dashboard/list atendendo requisitos obrigatórios do Tech Challenge. Dashboard "Volume de Ordens de Serviço" (ID: mba-eyq-v9q) visualiza métricas de negócio incluindo total de ordens criadas, ordens por status (pendente, aprovada, em andamento, concluída), tempo médio de processamento de ordens, distribuição temporal de criação de ordens via timeseries, e top 5 clientes com mais ordens. Dashboard "Performance do Sistema" (ID: zwb-yuc-jc5) visualiza métricas técnicas incluindo latência P50/P95/P99 de endpoints API segregados por rota, throughput (requisições por segundo) via timeseries, CPU e memória de pods PHP e Nginx, número de pods running vs desired do HPA, e response time distribution via heatmap. Dashboard "Erros e Logs" (ID: u5k-e35-r5t) visualiza logs estruturados incluindo log stream filtrado por severity ERROR e CRITICAL, top errors agrupados por mensagem, error rate (porcentagem de requisições com status 5xx) via timeseries, trace flamegraph de requisições lentas identificando bottlenecks, e correlação de logs com traces via dd.trace_id permitindo clicar em log e visualizar trace completo. Widgets utilizam query language Datadog para filtrar métricas via tags service:oficina-soat-api, env:production, namespace:lab-soat. Template variables permitem filtrar dashboards dinamicamente por environment ou specific service. Dashboards podem ser compartilhados via URL público para stakeholders sem acesso Datadog.

Três monitors foram configurados via Datadog web UI em app.datadoghq.com/monitors/manage implementando alertas proativos. Monitor "Latência Alta da API" (ID: 17436379) alerta quando latência P95 de trace.servlet.request.duration{service:oficina-soat-api} excede 2 segundos por mais de 5 minutos consecutivos, com notificação via email para equipe de desenvolvimento e webhook para Slack channel #alerts. Monitor "Taxa de Erro Alta" (ID: 17436427) alerta quando error rate calculado via (count:trace.servlet.request{http.status_code:5xx,service:oficina-soat-api} / count:trace.servlet.request{service:oficina-soat-api}) * 100 excede 5% por mais de 3 minutos consecutivos, com severidade crítica e notificação imediata. Monitor "Container PHP Parado" (ID: 17436428) alerta quando kubernetes.pods.running{namespace:lab-soat,app:php} cai abaixo de 1 por mais de 1 minuto indicando indisponibilidade completa da aplicação, com severidade crítica e notificação imediata via email e Slack. Notification templates incluem {{value}} mostrando valor atual, {{threshold}} mostrando threshold configurado, {{last_triggered_at}} mostrando timestamp do último trigger, link direto para dashboard relevante, e runbook link para procedimentos de troubleshooting. Monitors utilizam composite conditions combinando múltiplas métricas com lógica AND/OR quando necessário. Downtime scheduling é configurado para silenciar alertas durante manutenções programadas evitando false positives.

## Revisões

- **05/12/2024**: Decisão inicial (Aceita)
- **10/12/2024**: Implementação completa de Agent, APM e dashboards
- **15/12/2024**: Configuração de monitors e alertas
- **20/12/2024**: Deploy de BusinessEventLogger em Use Cases
- **08/01/2026**: Revisão para documentação Fase 3 com formato ADR+RFC rigoroso

## Referências

- Datadog APM PHP Documentation - https://docs.datadoghq.com/tracing/trace_collection/dd_libraries/php/
- Datadog Kubernetes Integration - https://docs.datadoghq.com/containers/kubernetes/
- Datadog Log Management - https://docs.datadoghq.com/logs/
- Datadog Monitors - https://docs.datadoghq.com/monitors/
- Datadog DaemonSet Deployment - https://docs.datadoghq.com/containers/kubernetes/installation/

## Palavras-Chave

Datadog, Observability, APM, Application Performance Monitoring, Logs, Log Management, Metrics, Infrastructure Monitoring, Monitoring, Distributed Tracing, Kubernetes, DaemonSet, Alerting, Dashboards, ADR, RFC, Tech Challenge, FIAP
