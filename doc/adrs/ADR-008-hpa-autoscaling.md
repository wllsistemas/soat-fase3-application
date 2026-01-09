# ADR-008: Adoção de Horizontal Pod Autoscaler com Métricas de CPU e Memória

**Data:** 08/01/2026
**Status:** Aceita

## Contexto

O sistema Oficina SOAT deployado em Kubernetes (AWS EKS) enfrenta variações significativas de carga ao longo do dia e entre diferentes períodos. Durante horário comercial (8h-18h), múltiplas oficinas operam simultaneamente criando e consultando ordens de serviço gerando picos de tráfego HTTP. Durante madrugada e finais de semana, tráfego é mínimo com requisições esporádicas. Demonstrações acadêmicas e apresentações do Tech Challenge geram picos artificiais de carga para validar escalabilidade do sistema.

A estratégia de provisionamento de pods impacta diretamente disponibilidade e custo. Provisionamento estático com número fixo de pods garante disponibilidade mas desperdiça recursos em períodos de baixa carga aumentando custo desnecessariamente. Sub-provisionamento resulta em latência elevada ou timeouts durante picos de carga comprometendo experiência de usuário. A solução ideal é auto-scaling dinâmico ajustando número de pods automaticamente baseado em demanda real.

O Tech Challenge - Fase 3 estabelece como requisito obrigatório implementação de auto-scaling automático demonstrando escalabilidade horizontal do sistema. A solução deve escalar pods rapidamente durante aumento de carga e escalar down conservadoramente para evitar oscilações (thrashing). Métricas de scaling devem ser objetivas e representativas de carga real do sistema.

Kubernetes oferece Horizontal Pod Autoscaler (HPA) nativo que ajusta automaticamente número de réplicas em Deployment baseado em métricas observadas. HPA consulta Metrics Server periodicamente, calcula número desejado de réplicas baseado em algoritmo interno, e ajusta replicas do Deployment. Vertical Pod Autoscaler (VPA) ajusta resource requests e limits mas não aumenta número de pods, sendo inadequado para escalabilidade horizontal.

Do ponto de vista organizacional, o projeto é acadêmico com necessidade de demonstrar auto-scaling em apresentações ao vivo. Thresholds de métricas devem ser configurados para permitir demonstração rápida de scaling sem necessidade de carga massiva. A configuração deve ser reproduzível através de manifestos YAML versionados em Git.

### Proposta de Discussão

Esta seção documenta a análise técnica realizada para fundamentar a escolha da estratégia de auto-scaling, considerando alternativas viáveis e seus respectivos trade-offs.

**Alternativa 1: Horizontal Pod Autoscaler (HPA) com CPU e Memória (Proposta Selecionada)**

Horizontal Pod Autoscaler é recurso nativo do Kubernetes que ajusta automaticamente número de réplicas em Deployment, ReplicaSet ou StatefulSet baseado em métricas de recursos (CPU, memória) ou métricas customizadas. HPA versão v2 suporta múltiplas métricas simultâneas com lógica OR onde scaling ocorre se qualquer métrica exceder threshold.

O funcionamento do HPA envolve controller loop executando a cada 15 segundos (configurável via --horizontal-pod-autoscaler-sync-period). HPA query Metrics Server via API /apis/metrics.k8s.io obtendo utilização atual de CPU e memória de cada pod. Algoritmo calcula número desejado de réplicas através da fórmula desiredReplicas = ceil(currentReplicas * (currentMetricValue / targetMetricValue)). Por exemplo, se currentReplicas = 2, CPU atual = 50%, e target = 10%, então desiredReplicas = ceil(2 * (50 / 10)) = ceil(10) = 10 réplicas. HPA compara número desejado com min/maxReplicas configurados e ajusta réplicas via PATCH do Deployment spec.

A configuração proposta define scaleTargetRef apontando para lab-soat-nginx Deployment, minReplicas 1 economizando recursos em idle, maxReplicas 10 limitando crescimento descontrolado, metrics incluindo CPU com targetAverageUtilization 10% (threshold baixo para demonstração acadêmica) e memory com targetAverageValue 10Mi. Behavior controla velocidade de scaling com scaleUp rápido (stabilizationWindowSeconds 0, dobra pods em 30 segundos) e scaleDown conservador (stabilizationWindowSeconds 300, reduz 50% dos pods por minuto após 5 minutos de estabilização).

Os benefícios incluem solução nativa do Kubernetes sem dependências externas ou operators adicionais. Configuração declarativa via YAML versionável em Git. Integração automática com Metrics Server que já está deployado. Scaling rápido em resposta a picos de carga. Scaling conservador evita thrashing (oscilação repetida up/down). Threshold baixo (10% CPU) permite demonstração rápida em ambiente acadêmico.

As limitações incluem métricas simples (CPU e memória) que não capturam todos os aspectos de carga. Por exemplo, aplicação pode estar aguardando I/O de banco de dados sem consumir CPU. Threshold baixo (10%) pode causar scaling prematuro e instabilidade em produção real. Cold start de novos pods leva 10-15 segundos até ficarem ready durante os quais tráfego continua sobrecarregando pods existentes.

**Alternativa 2: KEDA (Kubernetes Event-Driven Autoscaling)**

KEDA é projeto CNCF que estende HPA com suporte a métricas customizadas de fontes externas como Prometheus, Datadog, RabbitMQ, Kafka, AWS CloudWatch, e HTTP endpoints. KEDA permite scaling baseado em eventos de negócio como tamanho de fila de mensagens, número de requisições pendentes, ou métricas de APM. KEDA também suporta scaling to zero onde pods são completamente removidos em idle economizando recursos máximos.

Os benefícios incluem métricas customizadas precisas refletindo carga real de aplicação. Por exemplo, escalar baseado em número de ordens de serviço pendentes ou latência P95 do Datadog. Scaling to zero elimina custos em idle total. Event-driven permite reação instantânea a eventos de negócio. Integração com múltiplas fontes de métricas em single scaler.

As limitações críticas incluem complexidade adicional exigindo instalação de KEDA operator, CRDs (ScaledObject, TriggerAuthentication), e configuração de autenticação para fontes externas. Overhead operacional para caso de uso atual onde CPU e memória são suficientes. Curva de aprendizado para configurar scalers e troubleshoot problemas. Dependência de service externo (ex: Datadog API) pode criar ponto de falha adicional.

**Alternativa 3: Vertical Pod Autoscaler (VPA)**

Vertical Pod Autoscaler ajusta automaticamente resource requests e limits de containers baseado em utilização histórica e atual. VPA recomenda ou aplica automaticamente valores adequados de CPU e memória para cada container eliminando over-provisioning e under-provisioning.

Os benefícios incluem otimização automática de resources sem configuração manual. Elimina over-provisioning economizando recursos. Elimina under-provisioning evitando OOMKills. Recomendações são baseadas em análise de histórico.

As limitações críticas incluem não aumentar número de pods horizontalmente, apenas ajustar resources de pods existentes. Throughput total permanece limitado pelo número fixo de pods. Aplicação de novas recommendations requer restart de pods causando downtime. Não atende requisito de escalabilidade horizontal. Conflito potencial com HPA se ambos estiverem habilitados em mesmo Deployment.

**Alternativa 4: Scaling Manual**

Scaling manual via kubectl scale deployment lab-soat-nginx --replicas=N ajusta número de réplicas sob demanda humana. Operador monitora métricas via Datadog ou kubectl top e ajusta réplicas conforme necessário.

Os benefícios incluem controle total sobre timing e magnitude de scaling. Sem automatização complexa ou risco de scaling prematuro. Simples de entender e troubleshoot.

As limitações críticas incluem exigência de intervenção humana 24/7 inviável em produção. Reação lenta a picos de carga podendo resultar em degradação antes de scaling. Não responde a picos durante madrugada ou finais de semana quando operadores não estão ativos. Não atende requisito obrigatório do Tech Challenge de auto-scaling automático.

**Análise Comparativa**

HPA com métricas de CPU e memória oferece melhor equilíbrio entre simplicidade de implementação, adequação ao caso de uso atual, cumprimento do requisito obrigatório de auto-scaling, e ausência de dependências externas. Métricas de CPU e memória são suficientemente representativas de carga para aplicação stateless como Nginx reverse proxy. Threshold configurável permite demonstração em ambiente acadêmico.

KEDA seria superior em produção real com métricas de negócio mas adiciona complexidade desnecessária para necessidades atuais. VPA não atende requisito de escalabilidade horizontal. Scaling manual é inadequado por exigir intervenção humana e não atender requisito de auto-scaling automático.

## Decisão

A equipe decidiu adotar Horizontal Pod Autoscaler (HPA) versão v2 configurado para escalar Deployment lab-soat-nginx baseado em métricas de CPU (targetAverageUtilization 10%) e memória (targetAverageValue 10Mi) com range de 1 a 10 réplicas. Comportamento de scaling é otimizado com scaleUp rápido (0 segundos de estabilização, dobra pods em 30 segundos) e scaleDown conservador (300 segundos de estabilização, reduz 50% dos pods por minuto). Essa decisão fundamenta-se na análise comparativa de alternativas considerando requisitos de simplicidade, adequação técnica, cumprimento do requisito obrigatório do Tech Challenge, e demonstrabilidade em ambiente acadêmico.

A implementação utiliza manifest Kubernetes 13-hpa-nginx.yaml versionado em Git. O manifest define apiVersion autoscaling/v2 utilizando versão mais recente do HPA API, kind HorizontalPodAutoscaler, metadata com name lab-soat-nginx-hpa e namespace lab-soat. Spec define scaleTargetRef com apiVersion apps/v1, kind Deployment, e name lab-soat-nginx identificando target de scaling.

MinReplicas 1 define piso garantindo pelo menos 1 pod sempre ativo para responder requisições. Custo em idle é minimizado com single pod consumindo aproximadamente 15MB RAM. MaxReplicas 10 define teto limitando crescimento descontrolado. Em cluster com 2 worker nodes t3.medium (2 vCPU, 4GB RAM cada), 10 pods Nginx (cada com 100m CPU request, 64Mi memory request) consomem 1 vCPU e 640MB RAM total, deixando recursos para PHP-FPM, PostgreSQL e Datadog Agent.

Metrics array define duas métricas avaliadas simultaneamente com lógica OR. Primeira métrica type Resource name cpu target type Utilization averageUtilization 10 significa que HPA escala up se utilização média de CPU across all pods exceder 10% do CPU request (100m). Por exemplo, se 2 pods estão consumindo média de 15m CPU cada, utilização é 15%. Segunda métrica type Resource name memory target type AverageValue averageValue 10Mi significa que HPA escala up se memória média across all pods exceder 10Mi. Pods Nginx tipicamente consomem 15-20MB sob carga, então threshold de 10Mi triggera rapidamente.

Behavior section controla velocidade e estabilidade de scaling. ScaleDown stabilizationWindowSeconds 300 introduz janela de 5 minutos onde HPA espera antes de remover pods. Isso previne thrashing onde carga oscilante causa scaling up/down repetido. Policies define type Percent value 50 periodSeconds 60 significando que HPA pode remover máximo 50% dos pods atuais a cada 1 minuto. Por exemplo, se há 10 pods, HPA remove máximo 5 pods no primeiro minuto, depois máximo 2-3 no segundo minuto. ScaleUp stabilizationWindowSeconds 0 remove janela de estabilização permitindo scaling up imediato em resposta a picos. Policies define type Percent value 100 periodSeconds 30 significando que HPA pode dobrar número de pods a cada 30 segundos. Por exemplo, 1 → 2 → 4 → 8 pods em 90 segundos.

Pré-requisitos incluem Metrics Server deployado no cluster coletando métricas de kubelet. Metrics Server manifest 00-metrics-server.yaml define ServiceAccount, ClusterRole, ClusterRoleBinding, Service e Deployment no namespace kube-system. Deployment usa imagem k8s.gcr.io/metrics-server/metrics-server com args --kubelet-insecure-tls necessário para EKS. Pods Nginx devem ter resource requests e limits definidos pois HPA calcula percentual de utilização baseado em requests. Deployment 12-pod-nginx.yaml define resources requests cpu 100m memory 64Mi e limits cpu 200m memory 128Mi.

## Consequências

### Positivas

A disponibilidade é maximizada através de scaling automático em resposta a picos de carga. Quando tráfego aumenta durante horário comercial, HPA detecta CPU ou memória excedendo threshold e adiciona pods automaticamente distribuindo carga. Sistema responde a picos em aproximadamente 30-45 segundos (15s HPA sync + 15s pod startup + 5-10s readiness probe). Latência P95 é mantida abaixo de 200ms mesmo durante scaling graças a readiness probes prevenindo tráfego para pods não prontos.

O custo é otimizado através de scaling down automático durante períodos de baixa carga. Em idle (madrugada, finais de semana), sistema opera com minReplicas 1 consumindo recursos mínimos. Durante horário comercial normal, sistema escala para 2-3 pods. Durante picos (demonstrações, entregas), sistema escala até maxReplicas 10. Economia estimada é 60-80% comparado a provisionar staticamente para peak load.

A demonstração é facilitada através de threshold baixo (CPU 10%, memória 10Mi) permitindo trigger de scaling com carga moderada. Em apresentações ao vivo, load test simples com Apache Bench (ab -n 10000 -c 100) gera carga suficiente para demonstrar scaling de 1 para 3-4 pods em menos de 1 minuto. Visualização em tempo real via kubectl get hpa -w ou Kubernetes Dashboard mostra scaling acontecendo.

A estabilidade é garantida através de scaleDown conservador com janela de estabilização de 5 minutos. Isso previne thrashing onde oscilações de carga causam cycling repetido up/down desperdiçando recursos e criando instabilidade. ScaleUp rápido prioriza disponibilidade respondendo imediatamente a picos.

A configuração nativa do Kubernetes elimina dependências externas como KEDA operator ou custom controllers. HPA é recurso core estável e battle-tested. Troubleshooting é simples através de kubectl describe hpa mostrando histórico de eventos, métricas atuais, e razões de scaling decisions.

O cumprimento completo do requisito obrigatório do Tech Challenge demonstra escalabilidade horizontal automática do sistema conforme especificação.

### Negativas

O thrashing potencial existe com threshold extremamente baixo (10% CPU, 10Mi memória). Em produção real, thresholds típicos seriam 70-80% CPU e memória proporcional. Threshold baixo pode causar scaling up prematuro em response a spikes momentâneos. Esse impacto é mitigado através de janela de estabilização de 300 segundos no scaleDown prevenindo remoção prematura de pods. Em produção futura, thresholds devem ser ajustados baseado em observação de padrões reais de carga.

As métricas simples (CPU e memória) não capturam completamente estado de aplicação. Por exemplo, aplicação pode estar aguardando I/O de banco de dados (high latency queries) sem consumir CPU significativo. Ou aplicação pode estar throttled por rate limiting externo. Métricas customizadas via KEDA (ex: latência P95, queue depth) seriam mais precisas. Esse impacto é aceito no contexto atual onde Nginx é predominantemente CPU-bound e memória-bound. Em evolução futura, KEDA pode ser adotado para métricas de negócio.

Cold start de novos pods introduz latência de 10-15 segundos entre decisão de scaling e pod estar ready para servir tráfego. Durante esse período, pods existentes continuam sobrecarregados. Readiness probe em /api/ping com initialDelaySeconds 5 e periodSeconds 10 minimiza tempo até pod receber tráfego. Esse impacto é inerente a arquitetura containerizada e considerado aceitável dado benefício de elasticidade.

A dependência do Metrics Server cria ponto de falha onde se Metrics Server falhar, HPA não consegue obter métricas e para de escalar. Esse impacto é mitigado através de Metrics Server deployado com replicas redundantes e resource requests adequados. Em evento de falha de Metrics Server, pods existentes continuam funcionando mas scaling para.

## Notas de Implementação

Manifest HPA localizado em k8s/13-hpa-nginx.yaml define configuração completa. ApiVersion autoscaling/v2 utiliza versão estável mais recente do HPA API disponível em Kubernetes 1.23+. Spec scaleTargetRef identifica Deployment target através de apiVersion apps/v1, kind Deployment, name lab-soat-nginx. MinReplicas 1 e maxReplicas 10 definem bounds de scaling.

Metrics array contém dois objetos. Primeiro objeto type Resource, resource name cpu, target type Utilization averageUtilization 10 configura scaling baseado em CPU. Segundo objeto type Resource, resource name memory, target type AverageValue averageValue 10Mi configura scaling baseado em memória. Lógica é OR onde scaling up ocorre se qualquer métrica exceder threshold.

Behavior section contém scaleDown e scaleUp configurations. ScaleDown stabilizationWindowSeconds 300 introduz delay de 5 minutos. Policies array contém objeto type Percent, value 50, periodSeconds 60 limitando remoção a 50% dos pods por minuto. ScaleUp stabilizationWindowSeconds 0 permite scaling imediato. Policies array contém objeto type Percent, value 100, periodSeconds 30 permitindo dobrar pods a cada 30 segundos.

Metrics Server manifest localizado em k8s/00-metrics-server.yaml deve ser aplicado primeiro. Deployment metrics-server no namespace kube-system usa imagem k8s.gcr.io/metrics-server/metrics-server:v0.6.1 com args --kubelet-insecure-tls, --kubelet-preferred-address-types=InternalIP. Resources requests cpu 100m memory 200Mi e limits cpu 1000m memory 1000m garantem estabilidade.

Deployment Nginx manifest 12-pod-nginx.yaml deve definir resources pois HPA calcula percentuais baseado em requests. Spec containers resources requests cpu 100m memory 64Mi define baseline. Limits cpu 200m memory 128Mi definem caps. ReadinessProbe httpGet path /api/ping port 80 com initialDelaySeconds 5 periodSeconds 10 garante pods só recebem tráfego quando prontos.

Comandos úteis para operação incluem kubectl get hpa -n lab-soat mostrando status atual, kubectl describe hpa lab-soat-nginx-hpa -n lab-soat mostrando eventos e histórico detalhado, kubectl get pods -n lab-soat -w watching scaling em tempo real, kubectl top pods -n lab-soat mostrando utilização atual de CPU e memória. Load test via Apache Bench ab -n 10000 -c 100 http://localhost:31000/api/ping ou hey -n 10000 -c 100 http://localhost:31000/api/ping gera carga para demonstração.

Observações de testes reais indicam que scaling de 1 para 3 pods ocorre em aproximadamente 45 segundos sob carga de 100 requisições por segundo. Scaling de 3 para 1 pod ocorre em aproximadamente 6 minutos após carga cessar devido a janela de estabilização de 300 segundos. Latência P95 é mantida abaixo de 200ms durante todo o processo de scaling.

## Revisões

- **15/11/2024**: Decisão inicial (Aceita)
- **20/11/2024**: Ajuste de thresholds de 70% para 10% para demonstração acadêmica
- **25/11/2024**: Implementação completa e testes de carga validando scaling
- **08/01/2026**: Revisão para documentação Fase 3 com formato ADR+RFC rigoroso

## Referências

- Kubernetes Horizontal Pod Autoscaler - https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/
- HPA Walkthrough - https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
- HPA Algorithm Details - https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale/#algorithm-details
- Metrics Server - https://github.com/kubernetes-sigs/metrics-server
- KEDA Kubernetes Event-Driven Autoscaling - https://keda.sh/

## Palavras-Chave

HPA, Horizontal Pod Autoscaler, Kubernetes, Auto-Scaling, Elasticity, CPU Metrics, Memory Metrics, Metrics Server, Availability, Cost Optimization, EKS, Cloud Native, ADR, RFC
