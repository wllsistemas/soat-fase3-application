# Monitoramento e Observabilidade - Datadog

**Sistema:** Oficina SOAT - Gestão de Ordens de Serviço
**Plataforma:** Datadog SaaS
**Namespace Kubernetes:** lab-soat
**Data:** 08/01/2025

## Visão Geral

O sistema utiliza **Datadog** como plataforma unificada de observabilidade, consolidando:
- **APM (Application Performance Monitoring):** Traces distribuídos e latência de endpoints
- **Logs:** Centralizados e estruturados (JSON)
- **Métricas:** Sistema, Kubernetes, negócio e customizadas
- **Dashboards:** Visualização de KPIs de negócio e performance
- **Monitors:** Alertas automáticos via email

## Arquitetura de Monitoramento

```
┌──────────────────────────────────────────────────────────────┐
│                  APLICAÇÃO (Kubernetes)                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐            │
│  │ Nginx Pod  │  │ PHP Pod    │  │ Postgres   │            │
│  │            │  │            │  │ Pod        │            │
│  │ • Access   │  │ • App Logs │  │ • Query    │            │
│  │   Logs     │  │ • Business │  │   Logs     │            │
│  │ • Error    │  │   Events   │  │ • Errors   │            │
│  │   Logs     │  │ • Traces   │  │            │            │
│  └──────┬─────┘  └──────┬─────┘  └──────┬─────┘            │
│         │               │               │                   │
│         │ ① UDP (8125)  │ ② UDP (8126)  │ ③ Files          │
│         │ StatsD        │ APM Traces    │ /var/log/        │
│         ▼               ▼               ▼                   │
│  ┌──────────────────────────────────────────────────────┐   │
│  │          Datadog Agent (DaemonSet)                   │   │
│  │                                                      │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │   │
│  │  │ StatsD       │  │ APM Agent    │  │ Log       │ │   │
│  │  │ Collector    │  │              │  │ Collector │ │   │
│  │  │              │  │ • Traces     │  │           │ │   │
│  │  │ • Metrics    │  │ • Spans      │  │ • Nginx   │ │   │
│  │  │ • Events     │  │ • Profiles   │  │ • PHP     │ │   │
│  │  │ • Gauges     │  │              │  │ • Postgres│ │   │
│  │  └──────────────┘  └──────────────┘  └───────────┘ │   │
│  │                                                      │   │
│  │  ┌──────────────────────────────────────────────┐   │   │
│  │  │ Kubernetes Metrics Collector                 │   │   │
│  │  │ • Pod CPU/Memory                             │   │   │
│  │  │ • Node resources                             │   │   │
│  │  │ • HPA metrics                                │   │   │
│  │  └──────────────────────────────────────────────┘   │   │
│  └────────────────────────┬─────────────────────────────┘   │
│                           │                                 │
└───────────────────────────┼─────────────────────────────────┘
                            │
                            │ ④ HTTPS (batching 10s)
                            │ Compressed (gzip)
                            ▼
              ┌─────────────────────────────┐
              │   Datadog SaaS (Cloud)      │
              ├─────────────────────────────┤
              │                             │
              │  • Log Indexing & Search    │
              │  • APM Trace Analytics      │
              │  • Metrics Time Series DB   │
              │  • Dashboards               │
              │  • Monitors & Alerting      │
              │  • Incident Management      │
              └──────────────┬──────────────┘
                             │
                             │ ⑤ Email Alerts
                             ▼
                      ┌─────────────┐
                      │ Gestor      │
                      │ Equipe      │
                      └─────────────┘
```

---

## Instalação e Setup

### 1. Secret Datadog API Key

**k8s/14-secret-datadog.yaml:**
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: datadog-secret
  namespace: lab-soat
type: Opaque
data:
  api-key: <BASE64_ENCODED_API_KEY>
```

**Criação:**
```bash
# Obter API Key do Datadog (https://app.datadoghq.com/organization-settings/api-keys)
API_KEY="your-datadog-api-key"

# Criar secret via kubectl
kubectl create secret generic datadog-secret \
  --from-literal=api-key=$API_KEY \
  -n lab-soat

# Ou via base64 manual
echo -n "your-datadog-api-key" | base64
# Copiar output para o YAML acima
```

---

### 2. RBAC (ServiceAccount, Role, ClusterRole)

**k8s/15-datadog-rbac.yaml:**
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
  # Metrics Server
  - apiGroups: [""]
    resources:
      - nodes
      - nodes/metrics
      - nodes/proxy
      - nodes/stats
      - pods
      - services
      - endpoints
      - events
      - namespaces
      - componentstatuses
    verbs: ["get", "list", "watch"]

  # HPA metrics
  - apiGroups: ["apps"]
    resources:
      - deployments
      - replicasets
      - daemonsets
      - statefulsets
    verbs: ["get", "list", "watch"]

  # Horizontal Pod Autoscaler
  - apiGroups: ["autoscaling"]
    resources:
      - horizontalpodautoscalers
    verbs: ["get", "list", "watch"]

  # Metrics API
  - apiGroups: ["metrics.k8s.io"]
    resources:
      - nodes
      - pods
    verbs: ["get", "list"]
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
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: datadog-agent
  namespace: lab-soat
rules:
  - apiGroups: [""]
    resources:
      - configmaps
    resourceNames:
      - datadog-leader-election
    verbs: ["get", "update"]
  - apiGroups: [""]
    resources:
      - configmaps
    verbs: ["create"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: datadog-agent
  namespace: lab-soat
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: datadog-agent
subjects:
  - kind: ServiceAccount
    name: datadog-agent
    namespace: lab-soat
```

---

### 3. Datadog Agent (DaemonSet)

**k8s/16-datadog-agent.yaml:**
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: datadog-agent
  namespace: lab-soat
spec:
  selector:
    matchLabels:
      app: datadog-agent
  template:
    metadata:
      labels:
        app: datadog-agent
      annotations:
        # Auto-discovery para APM
        ad.datadoghq.com/datadog-agent.check_names: '["datadog-agent"]'
    spec:
      serviceAccountName: datadog-agent
      containers:
        - name: datadog-agent
          image: datadog/agent:latest

          env:
            # API Key
            - name: DD_API_KEY
              valueFrom:
                secretKeyRef:
                  name: datadog-secret
                  key: api-key

            # Site (US1, EU, etc.)
            - name: DD_SITE
              value: "datadoghq.com"

            # Kubernetes
            - name: DD_KUBERNETES_KUBELET_HOST
              valueFrom:
                fieldRef:
                  fieldPath: status.hostIP

            # Logs
            - name: DD_LOGS_ENABLED
              value: "true"
            - name: DD_LOGS_CONFIG_CONTAINER_COLLECT_ALL
              value: "true"
            - name: DD_LOGS_CONFIG_AUTO_MULTI_LINE_DETECTION
              value: "true"

            # APM (Traces)
            - name: DD_APM_ENABLED
              value: "true"
            - name: DD_APM_NON_LOCAL_TRAFFIC
              value: "true"

            # DogStatsD (Metrics)
            - name: DD_DOGSTATSD_NON_LOCAL_TRAFFIC
              value: "true"
            - name: DD_DOGSTATSD_PORT
              value: "8125"

            # Process Agent
            - name: DD_PROCESS_AGENT_ENABLED
              value: "true"

            # Tags
            - name: DD_TAGS
              value: "env:prod service:oficina-soat namespace:lab-soat"

            # Cluster Name
            - name: DD_CLUSTER_NAME
              value: "fiap-soat-eks-cluster"

          ports:
            # StatsD (UDP)
            - containerPort: 8125
              name: dogstatsd
              protocol: UDP

            # APM Traces (TCP)
            - containerPort: 8126
              name: traceport
              protocol: TCP

          resources:
            requests:
              cpu: 200m
              memory: 256Mi
            limits:
              cpu: 200m
              memory: 512Mi

          volumeMounts:
            # Docker socket (logs, container metadata)
            - name: dockersocket
              mountPath: /var/run/docker.sock
              readOnly: true

            # Proc filesystem (process metrics)
            - name: procdir
              mountPath: /host/proc
              readOnly: true

            # Sys filesystem (system metrics)
            - name: cgroups
              mountPath: /host/sys/fs/cgroup
              readOnly: true

            # Logs
            - name: pointerdir
              mountPath: /opt/datadog-agent/run

          livenessProbe:
            httpGet:
              path: /live
              port: 5555
            initialDelaySeconds: 15
            periodSeconds: 15

          readinessProbe:
            httpGet:
              path: /ready
              port: 5555
            initialDelaySeconds: 15
            periodSeconds: 15

      volumes:
        - name: dockersocket
          hostPath:
            path: /var/run/docker.sock

        - name: procdir
          hostPath:
            path: /proc

        - name: cgroups
          hostPath:
            path: /sys/fs/cgroup

        - name: pointerdir
          emptyDir: {}
```

---

## Configuração da Aplicação Laravel

### 1. Logs Estruturados (JSON)

**backend/config/logging.php:**
```php
'channels' => [
    // Canal padrão (stack)
    'stack' => [
        'driver' => 'stack',
        'channels' => ['daily', 'datadog'],
        'ignore_exceptions' => false,
    ],

    // Canal Datadog (UDP StatsD)
    'datadog' => [
        'driver' => 'monolog',
        'handler' => Monolog\Handler\SyslogUdpHandler::class,
        'handler_with' => [
            'host' => env('DD_AGENT_HOST', '127.0.0.1'),
            'port' => env('DD_DOGSTATSD_PORT', 8125),
        ],
        'formatter' => Monolog\Formatter\JsonFormatter::class,
        'level' => env('LOG_LEVEL', 'debug'),
    ],

    // Daily file (fallback)
    'daily' => [
        'driver' => 'daily',
        'path' => storage_path('logs/laravel.log'),
        'level' => env('LOG_LEVEL', 'debug'),
        'days' => 14,
    ],
],
```

**backend/.env:**
```env
# Datadog Agent (ClusterIP service)
DD_AGENT_HOST=datadog-agent.lab-soat.svc.cluster.local
DD_DOGSTATSD_PORT=8125
DD_TRACE_AGENT_PORT=8126

# APM
DD_SERVICE=oficina-soat
DD_ENV=prod
DD_VERSION=1.0.0
```

---

### 2. BusinessEventLogger Trait

**backend/app/Infrastructure/Service/BusinessEventLogger.php:**
```php
<?php

namespace App\Infrastructure\Service;

use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

trait BusinessEventLogger
{
    /**
     * Loga evento de negócio estruturado para Datadog
     *
     * @param string $event Tipo do evento (ex: ordem.criada, cliente.atualizado)
     * @param array $data Dados do evento
     * @return void
     */
    protected function logBusinessEvent(string $event, array $data): void
    {
        $correlationId = request()->header('x-correlation-id') ?? Str::uuid()->toString();

        Log::channel('datadog')->info($event, [
            // Metadados do evento
            'event_type' => $event,
            'timestamp' => now()->toIso8601String(),
            'correlation_id' => $correlationId,

            // Contexto do usuário
            'user_id' => auth()->id() ?? 'guest',
            'user_email' => auth()->user()->email ?? null,

            // Contexto da requisição
            'request_id' => request()->header('x-request-id'),
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),

            // Dados do negócio
            'data' => $data,

            // Tags para filtragem no Datadog
            'tags' => [
                'env' => config('app.env'),
                'service' => 'oficina-soat',
                'namespace' => 'lab-soat',
            ],
        ]);
    }
}
```

**Uso no Controller:**
```php
namespace App\Infrastructure\Controller;

use App\Infrastructure\Service\BusinessEventLogger;

class Ordem extends Controller
{
    use BusinessEventLogger;

    public function create(Request $request): JsonResponse
    {
        $ordem = $this->createUseCase->execute($request->all());

        // Log de evento de negócio
        $this->logBusinessEvent('ordem.criada', [
            'ordem_uuid' => $ordem->getUuid(),
            'cliente_uuid' => $ordem->getClienteUuid(),
            'veiculo_uuid' => $ordem->getVeiculoUuid(),
            'valor_total' => $ordem->getValorTotal(),
            'status' => $ordem->getStatus(),
        ]);

        return $this->presenter->success($ordem, 201);
    }

    public function aprovar(string $uuid): JsonResponse
    {
        $ordem = $this->aprovarUseCase->execute($uuid);

        $this->logBusinessEvent('ordem.aprovada', [
            'ordem_uuid' => $ordem->getUuid(),
            'valor_total' => $ordem->getValorTotal(),
        ]);

        return $this->presenter->success($ordem);
    }
}
```

---

## Dashboards Datadog

### Dashboard 1: Volume de Ordens

**Nome:** `[SOAT] Volume de Ordens de Serviço`
**ID:** mba-eyq-v9q

**Widgets:**

1. **Ordens Criadas (Time Series)**
   - Métrica: `count(ordem.criada)`
   - Agregação: Por hora
   - Filtro: `service:oficina-soat`

2. **Ordens Aprovadas vs Reprovadas (Pie Chart)**
   - Métricas:
     - `count(ordem.aprovada)`
     - `count(ordem.reprovada)`
   - Período: Últimas 24 horas

3. **Top 5 Clientes por Ordens (Top List)**
   - Métrica: `count(ordem.criada)`
   - Group by: `data.cliente_uuid`
   - Limit: 5

4. **Valor Total de Ordens (Query Value)**
   - Métrica: `sum(data.valor_total)`
   - Filtro: `event_type:ordem.criada`
   - Formato: BRL (R$)

5. **Status de Ordens (Heat Map)**
   - Métrica: `count(*)`
   - Group by: `data.status`
   - Períodos: 1 hora

**Criação via UI:**
```
1. Acessar https://app.datadoghq.com/dashboard/lists
2. Clicar em "New Dashboard"
3. Nomear: "[SOAT] Volume de Ordens de Serviço"
4. Adicionar widgets conforme acima
```

---

### Dashboard 2: Performance da Aplicação

**Nome:** `[SOAT] Performance - Latência e Throughput`
**ID:** zwb-yuc-jc5

**Widgets:**

1. **Latência P50/P95/P99 (Time Series)**
   - Métrica: `trace.laravel.request.duration`
   - Agregações: p50, p95, p99
   - Group by: `resource_name` (endpoint)

2. **Throughput (Requests/s) (Query Value)**
   - Métrica: `trace.laravel.request.hits.count`
   - Agregação: Por segundo

3. **Taxa de Erro (%) (Query Value)**
   - Fórmula: `(count(status:error) / count(*)) * 100`
   - Threshold: >5% (vermelho)

4. **Queries PostgreSQL Lentas (Table)**
   - Métrica: `postgresql.query.duration`
   - Filtro: `duration > 1000ms`
   - Colunas: query, duration, timestamp

5. **CPU e Memória dos Pods (Time Series)**
   - Métricas:
     - `kubernetes.cpu.usage`
     - `kubernetes.memory.usage`
   - Group by: `pod_name`

6. **HPA - Número de Réplicas (Time Series)**
   - Métrica: `kubernetes.hpa.desired_replicas`
   - Métrica: `kubernetes.hpa.current_replicas`
   - Filtro: `hpa_name:lab-soat-nginx-hpa`

---

### Dashboard 3: Erros e Logs

**Nome:** `[SOAT] Erros e Logs Críticos`
**ID:** u5k-e35-r5t

**Widgets:**

1. **Erros por Endpoint (Top List)**
   - Métrica: `count(*)`
   - Filtro: `status:error`
   - Group by: `resource_name`
   - Limit: 10

2. **Log Stream (Error 500+) (Log Stream)**
   - Query: `status:error @http.status_code:>=500`
   - Display: 50 linhas

3. **Exceptions Mais Frequentes (Table)**
   - Métrica: `count(*)`
   - Filtro: `@error.kind:*`
   - Group by: `error.kind`, `error.message`
   - Limit: 20

4. **Alertas Ativos (Monitors Summary)**
   - Status: Triggered
   - Tags: `service:oficina-soat`

---

## Monitors (Alertas)

### Monitor 1: Latência Alta

**Nome:** `[SOAT] Latência P95 Alta (>500ms)`

**Tipo:** APM - Trace Analytics

**Query:**
```
trace.laravel.request.duration.by(resource_name).rollup(avg, 60).p95() > 500
```

**Condições:**
- **Warning:** P95 > 300ms por 3 minutos
- **Alert:** P95 > 500ms por 5 minutos

**Notificações:**
```
[SOAT] Latência Alta Detectada

Endpoint: {{resource_name.name}}
P95: {{value}} ms (threshold: 500ms)

Ações recomendadas:
1. Verificar queries lentas no PostgreSQL
2. Checar logs de erro no Datadog
3. Analisar traces distribuídos

Dashboard: https://app.datadoghq.com/dashboard/xyz
```
**ID:** 17436379

**Destinatários:**
- Email: `equipe-soat@example.com`
- Slack (opcional): `#soat-alerts`

---

### Monitor 2: Taxa de Erro Alta

**Nome:** `[SOAT] Taxa de Erro >5%`

**Tipo:** APM - Service Metrics

**Query:**
```
(sum:trace.laravel.request.errors{service:oficina-soat}.as_count() /
 sum:trace.laravel.request.hits{service:oficina-soat}.as_count()) * 100 > 5
```

**Condições:**
- **Warning:** Taxa > 3% por 3 minutos
- **Alert:** Taxa > 5% por 5 minutos

**Notificações:**
```
[SOAT] Taxa de Erro Crítica

Taxa de Erro: {{value}}% (threshold: 5%)
Período: Últimos 5 minutos

Erros mais frequentes:
{{#is_alert}}
- Verificar logs: https://app.datadoghq.com/logs?query=status:error
- Verificar traces: https://app.datadoghq.com/apm/traces?query=status:error
{{/is_alert}}
```
**ID:** 17436427

**Destinatários:**
- Email: `equipe-soat@example.com`

---

### Monitor 3: Container Parado

**Nome:** `[SOAT] Pod Não-Ready`

**Tipo:** Kubernetes - Pod Status

**Query:**
```
min(last_5m):avg:kubernetes.pods.running{namespace:lab-soat} by {pod_name} < 1
```

**Condições:**
- **Alert:** Pod não-ready por 2 minutos

**Notificações:**
```
[SOAT] Container Parado

Pod: {{pod_name.name}}
Namespace: lab-soat
Status: Not Ready

Comandos úteis:
kubectl describe pod {{pod_name.name}} -n lab-soat
kubectl logs {{pod_name.name}} -n lab-soat
kubectl get events -n lab-soat --sort-by='.lastTimestamp'
```
**ID:** 17436428

**Destinatários:**
- Email: `devops-soat@example.com`

---

## APM (Application Performance Monitoring)

### Instrumentação Automática

**PHP APM Extension:**

**Instalação (Dockerfile):**
```dockerfile
FROM php:8.4-fpm-alpine

# Instalar APM Datadog
RUN curl -LO https://github.com/DataDog/dd-trace-php/releases/latest/download/datadog-php-tracer.tar.gz
RUN tar -xzf datadog-php-tracer.tar.gz -C /
RUN php /datadog-setup.php --php-bin=all

# Habilitar extensão
RUN echo "extension=ddtrace.so" > /usr/local/etc/php/conf.d/98-ddtrace.ini

# Configurar APM
ENV DD_SERVICE="oficina-soat"
ENV DD_ENV="prod"
ENV DD_VERSION="1.0.0"
ENV DD_TRACE_AGENT_URL="http://datadog-agent.lab-soat.svc.cluster.local:8126"
```

**Verificação:**
```bash
# Verificar extensão instalada
php -m | grep ddtrace

# Verificar configuração
php -i | grep ddtrace
```

### Traces Distribuídos

**Exemplo de Trace:**
```
┌──────────────────────────────────────────────────────────┐
│ Trace ID: 7f8c9d2e-4b3a-1c2d-8e9f-0a1b2c3d4e5f           │
├──────────────────────────────────────────────────────────┤
│                                                          │
│ ┌──────────────────────────────────────────────────┐    │
│ │ nginx.request                                    │    │
│ │ Duration: 145ms                                  │    │
│ │                                                  │    │
│ │ ┌──────────────────────────────────────────────┐│    │
│ │ │ php-fpm.request                              ││    │
│ │ │ Duration: 130ms                              ││    │
│ │ │                                              ││    │
│ │ │ ┌──────────────────────────────────────────┐││    │
│ │ │ │ laravel.controller                       │││    │
│ │ │ │ Resource: Ordem::create                  │││    │
│ │ │ │ Duration: 120ms                          │││    │
│ │ │ │                                          │││    │
│ │ │ │ ┌──────────────────────────────────────┐│││    │
│ │ │ │ │ postgresql.query                     ││││    │
│ │ │ │ │ Query: INSERT INTO ordens ...        ││││    │
│ │ │ │ │ Duration: 15ms                       ││││    │
│ │ │ │ └──────────────────────────────────────┘│││    │
│ │ │ │                                          │││    │
│ │ │ │ ┌──────────────────────────────────────┐│││    │
│ │ │ │ │ datadog.log                          ││││    │
│ │ │ │ │ Event: ordem.criada                  ││││    │
│ │ │ │ │ Duration: 2ms (async)                ││││    │
│ │ │ │ └──────────────────────────────────────┘│││    │
│ │ │ └──────────────────────────────────────────┘││    │
│ │ └──────────────────────────────────────────────┘│    │
│ └──────────────────────────────────────────────────┘    │
└──────────────────────────────────────────────────────────┘
```

---

## Métricas Customizadas

### DogStatsD (StatsD Client)

**Instalação:**
```bash
composer require datadog/php-datadogstatsd
```

**Uso:**
```php
use DataDog\DogStatsd;

// Configuração
$statsd = new DogStatsd([
    'host' => env('DD_AGENT_HOST', '127.0.0.1'),
    'port' => env('DD_DOGSTATSD_PORT', 8125),
    'tags' => [
        'env' => config('app.env'),
        'service' => 'oficina-soat',
    ],
]);

// Counter (incremento)
$statsd->increment('ordem.criada', 1, ['status' => 'CRIADA']);

// Gauge (valor absoluto)
$statsd->gauge('ordem.valor_total', $ordem->getValorTotal(), ['cliente_uuid' => $uuid]);

// Histogram (distribuição de valores)
$statsd->histogram('ordem.processing_time', $duration);

// Timing (latência)
$start = microtime(true);
// ... operação ...
$statsd->timing('ordem.create.duration', (microtime(true) - $start) * 1000);
```

---

## Verificação e Troubleshooting

### Verificar Datadog Agent

```bash
# Status do agent
kubectl exec -it daemonset/datadog-agent -n lab-soat -- agent status

# Logs do agent
kubectl logs -f daemonset/datadog-agent -n lab-soat

# Verificar conectividade
kubectl exec -it daemonset/datadog-agent -n lab-soat -- \
  agent diagnose all
```

### Verificar Envio de Métricas

```bash
# Enviar métrica de teste
kubectl exec -it deployment/lab-soat-php -n lab-soat -- \
  php artisan tinker

>>> \DataDog\DogStatsd::increment('test.metric', 1);
```

**Verificar no Datadog:**
```
Metrics → Explorer → Metric: test.metric
```

### Verificar Logs

**Query no Datadog:**
```
service:oficina-soat env:prod
```

**Filtros úteis:**
- `status:error` - Apenas erros
- `@event_type:ordem.criada` - Eventos de negócio específicos
- `@http.status_code:>=500` - Erros 5xx

---

## Custos Datadog

| Categoria | Uso Estimado | Custo Mensal (USD) |
|-----------|--------------|-------------------|
| APM Traces | 1M spans/mês | $31 (Included in Pro) |
| Logs Indexados | 1 GB/mês | $0.10/GB = $0.10 |
| Métricas Customizadas | 100 métricas | Included |
| Hosts | 2 nodes | $15/host * 2 = $30 |
| **Total Estimado** | | **~$30-40/mês** |

**Plano:** Datadog Pro ($15/host/mês)

**Otimizações:**
- Filtrar logs no agent (não enviar debug em prod)
- Sampling de traces (50% se volume alto)
- Retention de logs: 7 dias (vs. 15 padrão)

---

## Referências

- [Datadog Agent - Kubernetes](https://docs.datadoghq.com/containers/kubernetes/)
- [Datadog APM - PHP](https://docs.datadoghq.com/tracing/setup_overview/setup/php/)
- [DogStatsD](https://docs.datadoghq.com/developers/dogstatsd/)
- [ADR-004: Datadog para Observabilidade](../adrs/ADR-004-datadog-observability.md)
- Repositório de infraestrutura (Terraform Datadog): soat-fase3-infra

## Palavras-Chave

`Datadog` `Observability` `APM` `Logs` `Metrics` `Monitoring` `Kubernetes` `DaemonSet` `DogStatsD` `Distributed Tracing`
