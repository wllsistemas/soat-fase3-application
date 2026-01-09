# RFC-001: Estratégia de Autenticação com API Gateway

**Data:** 25/11/2024
**Status:** ✅ Implementado
**Autor:** Equipe Oficina SOAT (Felipe, Nicolas, William)

## Resumo Executivo

Este RFC define a estratégia de autenticação do sistema Oficina SOAT, implementando autenticação via CPF com geração de JWT através de AWS Lambda integrada a AWS API Gateway.

## Contexto

O Tech Challenge - Fase 3 exige:
- ✅ Implementação de API Gateway para controle e roteamento
- ✅ Function Serverless para validação de CPF e geração de JWT
- ✅ Proteção de rotas sensíveis da aplicação

### Problema

**Como garantir autenticação segura e escalável para um sistema distribuído (Lambda + EKS) sem acoplar autenticação à aplicação principal?**

## Proposta

Implementar **AWS API Gateway + Lambda Authorizer** como camada de autenticação desacoplada.

### Arquitetura Proposta

```
┌──────────┐
│ Cliente  │
└────┬─────┘
     │ 1. POST /auth/login {"cpf": "xxx"}
     ▼
┌──────────────────┐
│ AWS API Gateway  │ ← Ponto de entrada único
└────┬─────────────┘
     │ 2. Invoca Lambda Auth
     ▼
┌────────────────────────────┐
│ Lambda: soat-auth-cpf      │
│ ┌────────────────────────┐ │
│ │ • Valida formato CPF   │ │
│ │ • Valida dígitos       │ │
│ │ • Consulta PostgreSQL  │ │
│ │ • Verifica status      │ │
│ │ • Gera JWT (HS256)     │ │
│ └────────────────────────┘ │
└────┬───────────────────────┘
     │ 3. Retorna JWT
     ▼
┌──────────┐
│ Cliente  │ ← Armazena token
└────┬─────┘
     │ 4. GET /api/clientes
     │    Header: Authorization: Bearer <JWT>
     ▼
┌──────────────────┐
│ API Gateway      │
│ Lambda Authorizer│ ← Valida JWT
└────┬─────────────┘
     │ 5. JWT válido → Allow
     ▼
┌─────────────────┐
│ Laravel (EKS)   │ ← Processa requisição
└─────────────────┘
```

## Opções Consideradas

### Opção 1: AWS API Gateway + Lambda Authorizer ✅ ESCOLHIDA

**Prós:**
- ✅ Desacoplamento total entre auth e aplicação
- ✅ Escalabilidade automática (serverless)
- ✅ Integração nativa AWS
- ✅ Rate limiting e DDoS protection (API Gateway)
- ✅ Custo sob demanda (~$0 em free tier)
- ✅ Lambda Authorizer valida JWT antes de atingir aplicação

**Contras:**
- ⚠️ Cold start (~100-300ms)
- ⚠️ Latência de rede adicional
- ⚠️ Vendor lock-in AWS (mitigado: Lambda pode rodar em container)

**Custos Estimados:**
- Free tier: 1M requisições/mês
- Pós-free tier: $3.50 por milhão de requisições
- Estimativa: ~$5-10/mês para 100k req/dia

### Opção 2: Kong API Gateway + Plugin JWT

**Prós:**
- Open-source
- Self-hosted (controle total)
- Plugins extensíveis

**Contras:**
- Overhead operacional (gerenciar Kong)
- Custos fixos (infra sempre ativa)
- Complexidade de configuração

**Motivo da Rejeição:** Overhead operacional vs. Lambda serverless.

### Opção 3: Traefik + Middleware Customizado

**Prós:**
- Integração nativa com Kubernetes
- Configuração via labels (K8s-native)
- Open-source

**Contras:**
- Middleware customizado requer desenvolvimento
- Menos features que API Gateway (rate limiting, etc.)
- Não atende requisito de serverless

**Motivo da Rejeição:** Não utiliza Function Serverless (requisito Tech Challenge).

## Decisão

**Adotamos AWS API Gateway + Lambda Authorizer.**

### Implementação

**Repositório:** `soat-fase3-lambda`

**Endpoints Implementados:**

1. **POST /auth/login** (público)
   - Valida CPF
   - Consulta cliente no PostgreSQL
   - Gera JWT
   - Retorna token + dados do cliente

2. **Lambda Authorizer** (interno API Gateway)
   - Valida JWT em todas as rotas protegidas
   - Retorna IAM Policy (Allow/Deny)

**Tecnologias:**
- **Runtime:** Node.js 18.x
- **JWT:** `jsonwebtoken` library
- **Database:** `pg` (PostgreSQL driver)
- **Validation:** Custom CPF validator

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

**Expiração:** 24 horas (configurável via env `JWT_EXPIRATION`)

**Secret:** AWS Secrets Manager (`soat/jwt-secret`)

## Impactos

### Aplicação Laravel (EKS)

**Antes:**
- Middleware `JsonWebTokenMiddleware` validava JWT internamente
- Acoplamento forte

**Depois:**
- Middleware `JsonWebTokenMiddleware` permanece ativo (defesa em profundidade)
- Aplicação assume que requisições chegam autenticadas
- Simplificação do código

### Segurança

**Rate Limiting:** API Gateway protege contra DDoS
**JWT Validation:** Lambda Authorizer impede tokens inválidos
**Secret Management:** AWS Secrets Manager (não hardcoded)
**HTTPS:** Obrigatório no API Gateway

### Performance

- **Latência adicional:** ~50-100ms (Lambda warm)
- **Cold start:** ~100-300ms (primeira requisição)
- **Mitigação:** Provisioned concurrency (se necessário)

## Plano de Rollout

### Fase 1: Implementação Lambda (Concluída)
- Lambda `soat-auth-cpf` criada
- Validação de CPF implementada
- Integração com PostgreSQL

### Fase 2: API Gateway (Concluída)
- Endpoint `/auth/login` configurado
- Lambda Authorizer configurado
- CORS habilitado

### Fase 3: Integração Aplicação (Concluída)
- Middleware JWT do Laravel mantido (`JsonWebTokenMiddleware`)
- Testes de integração
- Documentação atualizada

### Fase 4: Monitoramento (Em Progresso)
- CloudWatch Logs para Lambda
- CloudWatch Metrics (latência, erros, throttles)
- Alarmes configurados (taxa de erro >5%)

## Métricas de Sucesso

- Taxa de sucesso de autenticação >99%
- Latência P95 <300ms (incluindo cold start)
- Custo mensal <$10 (100k requisições/dia)
- Zero downtime durante deploys

## Riscos e Mitigações

| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Cold start lento | Média | Baixo | Provisioned concurrency ou warm-up |
| Lambda timeout | Baixa | Médio | Timeout configurado (10s) + retry |
| Secret leak | Baixa | Alto | AWS Secrets Manager + rotação |
| API Gateway throttle | Baixa | Alto | Aumentar limits ou implementar cache |

## Alternativas Futuras

### Curto Prazo (3-6 meses)
- Implementar cache de JWT (Redis) para reduzir validações
- Provisioned concurrency para eliminar cold starts

### Médio Prazo (6-12 meses)
- Migrar para AWS Cognito (se crescimento justificar)
- Implementar MFA (Multi-Factor Authentication)

### Longo Prazo (12+ meses)
- OAuth 2.0 / OpenID Connect
- Integração com IdP externo (Google, Facebook)

## Aprovações

- ✅ **Arquiteto de Software:** Nicolas Martins
- ✅ **Tech Lead:** William Leite
- ✅ **DevOps:** Felipe Oliveira
- ✅ **Data:** 25/11/2024

## Referências

- [AWS Lambda Authorizers](https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html)
- [JWT Best Practices](https://tools.ietf.org/html/rfc8725)
- [ADR-003: Autenticação via CPF + JWT Serverless](../adrs/ADR-003-cpf-authentication.md)

## Anexos

### Exemplo de Request/Response

**Login:**
```bash
curl -X POST https://api.gateway.aws/prod/auth/login \
  -H "Content-Type: application/json" \
  -d '{"cpf": "123.456.789-00"}'

# Response:
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "expiresIn": 3600,
  "cliente": {
    "uuid": "abc-123",
    "nome": "João Silva"
  }
}
```

**Requisição Autenticada:**
```bash
curl -X GET https://api.gateway.aws/prod/api/clientes \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."

# API Gateway valida JWT via Lambda Authorizer antes de rotear para Laravel
```
