# RFC-003: Padrão de Comunicação entre Componentes

**Data:** 20/11/2024
**Status:** Implementado
**Autor:** Equipe Oficina SOAT (Felipe, Nicolas, William)

## Resumo Executivo

Este RFC define o padrão de comunicação entre os componentes distribuídos do sistema Oficina SOAT (API Gateway, Lambda, Aplicação Kubernetes, PostgreSQL, Datadog), optando por comunicação **síncrona via HTTP/REST** para requisições críticas e **assíncrona via agentes** para observabilidade.

## Contexto

O Tech Challenge - Fase 3 implementa arquitetura distribuída com:
- AWS API Gateway (ponto de entrada)
- AWS Lambda (autenticação serverless)
- Aplicação Laravel em Kubernetes (lógica de negócio)
- PostgreSQL autogerenciado (persistência)
- Datadog (observabilidade)

### Problema

**Como garantir comunicação eficiente, rastreável e resiliente entre componentes distribuídos (serverless + Kubernetes + banco de dados) mantendo baixa latência e simplicidade operacional?**

## Proposta

Implementar **padrão híbrido de comunicação**:
- **Síncrono via HTTP/REST** para fluxo crítico (autenticação, APIs de negócio)
- **Assíncrono via agentes** para observabilidade (logs, métricas, traces)

### Arquitetura Proposta

```
┌──────────┐
│ Cliente  │ (Mobile/Web/Postman)
└────┬─────┘
     │ ① HTTP/REST (HTTPS)
     ▼
┌─────────────────────────────────┐
│ AWS API Gateway                 │
│ ┌─────────────────────────────┐ │
│ │ Lambda Authorizer (JWT)     │ │ ② Síncrono
│ │ - Valida token              │ │    (invocação Lambda)
│ │ - Retorna IAM Policy        │ │
│ └─────────────────────────────┘ │
└────┬────────────────────────────┘
     │ ③ HTTP/REST (autorizado)
     │    Header: x-api-key
     ▼
┌─────────────────────────────────┐
│ Laravel Application (EKS)       │
│ ┌─────────────────────────────┐ │
│ │ Nginx (reverse proxy)       │ │
│ │   ▼                         │ │
│ │ PHP-FPM (Laravel 12)        │ │
│ │   │                         │ │
│ │   ├─④ TCP (sync)────────────┼─┼─────┐
│ │   │                         │ │     │
│ │   └─⑤ UDP (async)──────────────────┼────┐
│ └─────────────────────────────┘ │     │    │
└─────────────────────────────────┘     │    │
                                        ▼    ▼
              ┌──────────────────┐   ┌──────────────┐
              │ PostgreSQL 17.5  │   │ Datadog      │
              │ (ClusterIP)      │   │ Agent        │
              │ - Port 5432      │   │ ┌──────────┐ │
              │ - lab-soat NS    │   │ │ APM      │ │
              └──────────────────┘   │ │ Logs     │ │
                                     │ │ Metrics  │ │
                                     │ └──────────┘ │
                                     └──────────────┘
                                            │ ⑥ HTTPS (async)
                                            ▼
                                     ┌──────────────┐
                                     │ Datadog SaaS │
                                     │ (Cloud)      │
                                     └──────────────┘

Legenda:
① Cliente → API Gateway: HTTP/REST síncrono (HTTPS obrigatório)
② API Gateway ↔ Lambda: Invocação síncrona (validação JWT)
③ API Gateway → Laravel: HTTP/REST síncrono (via Nginx)
④ Laravel → PostgreSQL: TCP síncrono (queries SQL via PDO)
⑤ Laravel → Datadog: UDP assíncrono (logs, métricas, traces)
⑥ Datadog Agent → Cloud: HTTPS assíncrono (batching 10s)
```

## Opções Consideradas

### Opção 1: Comunicação Síncrona via HTTP/REST — ESCOLHIDA (Parcial)

**Aplicação:** Cliente ↔ API Gateway ↔ Laravel ↔ PostgreSQL

**Prós:**
- Simplicidade de implementação (RESTful API padrão)
- Request-response imediato (requisito de negócio)
- Rastreabilidade via correlation IDs
- Compatível com Lambda Authorizer
- Suporte nativo em todos os componentes
- Fácil debug (logs sequenciais)

**Contras:**
- Acoplamento temporal (cliente espera resposta)
- Timeout se componente downstream falhar
- Latência acumulada (rede + processamento)

**Implementação:**

**API Gateway → Lambda (Authorizer):**
```json
// Request Event
{
  "type": "REQUEST",
  "methodArn": "arn:aws:execute-api:us-east-2:*/GET/api/clientes",
  "headers": {
    "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
  }
}

// Response (IAM Policy)
{
  "principalId": "cliente-uuid-123",
  "policyDocument": {
    "Statement": [{
      "Action": "execute-api:Invoke",
      "Effect": "Allow",
      "Resource": "arn:aws:execute-api:*"
    }]
  }
}
```

**API Gateway → Laravel:**
```http
GET https://api.gateway.aws/prod/api/clientes HTTP/1.1
Host: api.gateway.aws
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
x-api-key: <gateway-api-key>
x-correlation-id: 7f8c9d2e-4b3a-1c2d-8e9f-0a1b2c3d4e5f

# Response
HTTP/1.1 200 OK
Content-Type: application/json
x-correlation-id: 7f8c9d2e-4b3a-1c2d-8e9f-0a1b2c3d4e5f

{
  "data": [
    {"uuid": "abc-123", "nome": "João Silva"}
  ]
}
```

**Laravel → PostgreSQL:**
```php
// backend/app/Infrastructure/Repositories/ClienteRepository.php
public function listar(): Collection
{
    // PDO connection pool (TCP persistente)
    return DB::connection('pgsql')
        ->table('clientes')
        ->get(); // Query síncrona
}
```

**Latência Observada (P95):**
- Cliente → API Gateway: ~50ms
- Lambda Authorizer: ~20-50ms (warm) / ~150ms (cold start)
- API Gateway → Laravel: ~30ms
- Laravel → PostgreSQL: <5ms
- **Total:** ~100-150ms (warm) / ~250ms (cold start)

### Opção 2: Comunicação Assíncrona via Mensageria — ESCOLHIDA (Observabilidade)

**Aplicação:** Laravel → Datadog (logs, métricas, traces)

**Prós:**
- Desacoplamento (não bloqueia requisição)
- Batching automático (eficiência de rede)
- Retry automático se falhar
- Não impacta latência do usuário

**Contras:**
- Eventual consistency (logs chegam com delay)
- Complexidade de debug (traces assíncronos)

**Implementação:**

**Datadog Agent (DaemonSet K8s):**
```yaml
# k8s/16-datadog-agent.yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: datadog-agent
  namespace: lab-soat
spec:
  template:
    spec:
      containers:
      - name: datadog-agent
        image: datadog/agent:latest
        env:
        - name: DD_API_KEY
          valueFrom:
            secretKeyRef:
              name: datadog-secret
              key: api-key
        - name: DD_LOGS_ENABLED
          value: "true"
        - name: DD_APM_ENABLED
          value: "true"
```

**Laravel → Datadog (via agent local):**
```php
// backend/app/Infrastructure/Service/BusinessEventLogger.php
trait BusinessEventLogger
{
    protected function logBusinessEvent(string $event, array $data): void
    {
        // Log estruturado (JSON) → Datadog Agent (UDP)
        Log::channel('datadog')->info($event, [
            'event_type' => $event,
            'timestamp' => now()->toIso8601String(),
            'correlation_id' => request()->header('x-correlation-id'),
            'data' => $data,
        ]);

        // Não bloqueia execução (fire-and-forget)
    }
}
```

**Datadog Agent → SaaS:**
- Batching: A cada 10 segundos
- Protocolo: HTTPS (TLS 1.2+)
- Compressão: gzip
- Retry: Exponential backoff (3 tentativas)

### Opção 3: Event-Driven via SQS/SNS (Rejeitada para MVP)

**Aplicação Potencial:** Notificações assíncronas (email, SMS, webhooks)

**Prós:**
- Desacoplamento total
- Retry e Dead Letter Queue (DLQ)
- Escalabilidade horizontal (consumers)
- Garantia de entrega (at-least-once)

**Contras:**
- Complexidade adicional (SQS, Lambda consumers)
- Custo adicional (~$0.40 por milhão de requisições)
- Latência adicional (eventual consistency)
- Não necessário para MVP acadêmico

**Motivo da Rejeição:** Overhead desnecessário para escopo atual. Requisições críticas (criação de ordem, consulta de clientes) precisam de resposta síncrona. Notificações não são requisito obrigatório da Fase 3.

**Consideração Futura:** Se o sistema evoluir para enviar notificações (e.g., "Ordem aprovada" via email), SQS pode ser adotado:
```
Laravel → SNS Topic → SQS Queue → Lambda Consumer → SES (email)
```

## Decisão

**Adotamos padrão híbrido:**

1. **Síncrono via HTTP/REST (RFC 7231)**
   - Cliente ↔ API Gateway
   - API Gateway ↔ Lambda Authorizer
   - API Gateway ↔ Laravel (Nginx)
   - Laravel ↔ PostgreSQL

2. **Assíncrono via Agentes**
   - Laravel → Datadog Agent (UDP)
   - Datadog Agent → Datadog SaaS (HTTPS batching)

### Implementação

**Componentes e Protocolos:**

| Comunicação | Protocolo | Síncrono/Assíncrono | Latência (P95) | Retry |
|-------------|-----------|---------------------|----------------|-------|
| Cliente → API Gateway | HTTPS (REST) | Síncrono | ~50ms | Manual |
| API Gateway → Lambda | AWS SDK (Invoke) | Síncrono | ~20-50ms | Automático (3x) |
| API Gateway → Laravel | HTTP (REST) | Síncrono | ~30ms | Automático (Gateway) |
| Laravel → PostgreSQL | TCP (PDO) | Síncrono | <5ms | Manual |
| Laravel → Datadog | UDP (StatsD) | Assíncrono | N/A | Fire-and-forget |
| Datadog Agent → SaaS | HTTPS | Assíncrono | ~100ms | Exponential backoff |

**Correlation IDs (Rastreabilidade):**
```http
# Cada requisição recebe UUID único propagado em headers
GET /api/clientes HTTP/1.1
x-correlation-id: 7f8c9d2e-4b3a-1c2d-8e9f-0a1b2c3d4e5f

# Propagado para PostgreSQL e Datadog
SELECT * FROM clientes; -- [correlation_id: 7f8c9d2e...]
Log::info('Clientes listados'); -- {correlation_id: "7f8c9d2e..."}
```

**Timeouts Configurados:**
```yaml
# API Gateway
timeout: 29s  # Máximo AWS (Lambda max: 30s)

# Laravel (php.ini)
max_execution_time: 30

# PostgreSQL
statement_timeout: 10s  # Previne queries lentas

# Datadog Agent
forwarder_timeout: 20s
```

## Impactos

### Performance

**Latência Total (P95):**
- Endpoint simples (GET /api/ping): ~50ms
- Endpoint com autenticação: ~150ms
- Endpoint com DB query: ~200ms
- Cold start Lambda: +100-150ms (primeira requisição)

**Throughput:**
- API Gateway: até 10.000 req/s (limite AWS)
- Laravel (1 pod): ~100 req/s
- Laravel (10 pods HPA): ~1.000 req/s
- PostgreSQL: ~500 queries/s

### Resiliência

**Retry Automático:** API Gateway retenta 3x em caso de erro 5xx
**Circuit Breaker:** Lambda tem timeout de 30s (evita cascading failures)
**Health Checks:** Kubernetes readiness probe (`/api/ping`)
**Sem DLQ:** Requisições falhadas são logadas mas não reprocessadas (aceito para MVP)

### Observabilidade

**Distributed Tracing:** Datadog APM com correlation IDs
**Logs Centralizados:** Todos os componentes enviam para Datadog
**Métricas de Negócio:** BusinessEventLogger trait
**Dashboards:** 3 dashboards Datadog (Volume, Performance, Erros)

## Plano de Rollout

### Fase 1: Comunicação Síncrona (Concluída)
- API Gateway configurado
- Lambda Authorizer implementado
- Nginx reverse proxy
- PostgreSQL connection pool

### Fase 2: Observabilidade Assíncrona (Concluída)
- Datadog Agent DaemonSet
- APM traces habilitado
- Logs estruturados (JSON)
- BusinessEventLogger trait

### Fase 3: Rastreabilidade (Concluída)
- Correlation IDs em headers
- Propagação de IDs para logs
- Dashboards com filtros por correlation_id

### Fase 4: Melhorias Futuras (Opcional)

**Event-Driven para Notificações:**
```
┌──────────────┐
│ Laravel      │
└──────┬───────┘
       │ Publish evento
       ▼
┌──────────────┐
│ SNS Topic    │
│ "ordem-      │
│  aprovada"   │
└──────┬───────┘
       │
       ├──────────────┐
       ▼              ▼
┌──────────┐   ┌──────────┐
│ SQS      │   │ SQS      │
│ Email    │   │ SMS      │
│ Queue    │   │ Queue    │
└────┬─────┘   └────┬─────┘
     ▼              ▼
┌──────────┐   ┌──────────┐
│ Lambda   │   │ Lambda   │
│ SES      │   │ SNS      │
└──────────┘   └──────────┘
```

## Métricas de Sucesso

- Latência P95 <300ms (incluindo cold start)
- Taxa de sucesso >99%
- 100% requisições rastreáveis (correlation ID)
- Logs chegam no Datadog em <30s
- Zero perda de logs críticos

## Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Lambda cold start lento | Média | Baixo | Provisioned concurrency (se necessário) |
| PostgreSQL connection pool esgotado | Baixa | Alto | Max connections: 100 (Laravel) |
| Datadog agent down | Baixa | Médio | Logs locais de fallback |
| API Gateway throttling | Baixa | Alto | Rate limit: 10k req/s (suficiente) |
| Cascading failure | Baixa | Alto | Circuit breaker + timeouts |

## Alternativas Futuras

### Curto Prazo (3-6 meses)
- Implementar retry logic no Laravel (Guzzle middleware)
- Cache de queries frequentes (Redis)

### Médio Prazo (6-12 meses)
- Event-driven para notificações (SQS + Lambda)
- GraphQL para reduzir over-fetching

### Longo Prazo (12+ meses)
- Service mesh (Istio) para comunicação inter-pods
- gRPC para comunicação interna (se microsserviços)

## Aprovações

- **Arquiteto de Software:** Nicolas Martins
- **Tech Lead:** William Leite
- **DevOps:** Felipe Oliveira
- **Data:** 20/11/2024

## Referências

- [RFC 7231 - HTTP/1.1 Semantics](https://tools.ietf.org/html/rfc7231)
- [AWS Lambda Best Practices](https://docs.aws.amazon.com/lambda/latest/dg/best-practices.html)
- [Datadog APM Documentation](https://docs.datadoghq.com/tracing/)
- [Laravel HTTP Client](https://laravel.com/docs/12.x/http-client)
- [ADR-003: Autenticação via CPF + JWT Serverless](../adrs/ADR-003-cpf-authentication.md)
- [ADR-004: Datadog para Observabilidade](../adrs/ADR-004-datadog-observability.md)

## Anexos

### Exemplo de Fluxo Completo

**Request:**
```http
POST https://api.gateway.aws/prod/api/ordens HTTP/1.1
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
Content-Type: application/json
x-correlation-id: 7f8c9d2e-4b3a-1c2d-8e9f-0a1b2c3d4e5f

{
  "cliente_uuid": "abc-123",
  "veiculo_uuid": "xyz-789",
  "descricao": "Troca de óleo"
}
```

**Response:**
```http
HTTP/1.1 201 Created
Content-Type: application/json
x-correlation-id: 7f8c9d2e-4b3a-1c2d-8e9f-0a1b2c3d4e5f

{
  "data": {
    "uuid": "ordem-456",
    "status": "CRIADA",
    "valor_total": 150.00
  }
}
```

**Logs Datadog (assíncrono):**
```json
{
  "timestamp": "2024-11-20T14:30:00.000Z",
  "level": "info",
  "event_type": "ordem.criada",
  "correlation_id": "7f8c9d2e-4b3a-1c2d-8e9f-0a1b2c3d4e5f",
  "data": {
    "ordem_uuid": "ordem-456",
    "cliente_uuid": "abc-123",
    "valor_total": 150.00
  },
  "service": "oficina-soat",
  "env": "prod"
}
```

### Códigos de Erro

| Código | Descrição | Retry | Origem |
|--------|-----------|-------|--------|
| 401 | Token inválido | Não | Lambda Authorizer |
| 403 | Token expirado | Não | Lambda Authorizer |
| 404 | Recurso não encontrado | Não | Laravel |
| 422 | Validação falhou | Não | Laravel |
| 500 | Erro interno | Sim (3x) | Laravel/PostgreSQL |
| 502 | Bad Gateway | Sim (3x) | API Gateway |
| 503 | Serviço indisponível | Sim (3x) | API Gateway |
| 504 | Gateway Timeout | Sim (3x) | API Gateway |
