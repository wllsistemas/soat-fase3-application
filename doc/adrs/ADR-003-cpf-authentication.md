# ADR-003: Autenticação Serverless com Validação de CPF e JWT

**Data:** 08/01/2026
**Status:** Aceita

## Contexto

O projeto Oficina SOAT é um sistema de gerenciamento de oficina mecânica desenvolvido no contexto do Tech Challenge - Fase 3 da FIAP. Um dos requisitos obrigatórios desta fase é implementar autenticação protegida por API Gateway utilizando Function Serverless para validação de credenciais e geração de tokens JWT. Especificamente, o sistema deve validar CPF de clientes e autenticar usuários do sistema (mecânicos, atendentes) através de email e senha.

A arquitetura original do sistema implementava autenticação monolítica onde todo o fluxo de autenticação ocorria dentro da aplicação Laravel executando em Kubernetes. O cliente enviava requisição HTTP para Nginx, que encaminhava para Laravel, onde ocorria validação de credenciais via Eloquent ORM consultando PostgreSQL, geração de JWT usando biblioteca PHP, e retorno do token. Essa abordagem apresentava acoplamento forte entre autenticação e aplicação principal, escalabilidade limitada pois autenticação escala junto com todo o monolito, custos fixos mesmo em períodos sem autenticações, e não atendia o requisito obrigatório do Tech Challenge de utilizar Function Serverless e API Gateway.

Os requisitos do Tech Challenge - Fase 3 especificam claramente a necessidade de API Gateway para controlar e rotear requisições, Function Serverless para validar credenciais e gerar JWT, validação de CPF com verificação de dígitos verificadores segundo algoritmo da Receita Federal, consulta de existência de clientes e usuários na base de dados, geração de JWT com claims customizados incluindo identificação do usuário, e proteção de rotas sensíveis da aplicação através de validação de JWT.

Do ponto de vista técnico, AWS Lambda oferece escalabilidade automática de zero a milhares de execuções concorrentes sem configuração manual. AWS API Gateway integra nativamente com Lambda e oferece funcionalidades de segurança como rate limiting, validação de requisições e Lambda Authorizers. JWT é padrão stateless amplamente adotado adequado para arquiteturas distribuídas e microserviços. O algoritmo de validação de CPF baseado em dígitos verificadores é determinístico e pode ser implementado sem dependências externas.

Do ponto de vista organizacional, o projeto é acadêmico com restrições orçamentárias favorecendo uso de free tier da AWS. A equipe possui conhecimento em AWS e infraestrutura serverless. O sistema é distribuído em quatro repositórios separados incluindo repositório específico para Lambda, facilitando CI/CD independente e ownership claro de responsabilidades.

### Proposta de Discussão

Esta seção documenta a análise técnica realizada para fundamentar a escolha da estratégia de autenticação, considerando alternativas viáveis e seus respectivos trade-offs no contexto do Tech Challenge e requisitos técnicos do sistema.

**Alternativa 1: AWS Lambda com API Gateway (Proposta Selecionada)**

AWS Lambda é um serviço de computação serverless que executa código em resposta a eventos sem necessidade de provisionar ou gerenciar servidores. AWS API Gateway é um serviço gerenciado para criar, publicar, manter, monitorar e proteger APIs em qualquer escala. A combinação desses serviços atende perfeitamente o requisito do Tech Challenge permitindo desacoplamento completo da autenticação.

A implementação proposta utiliza AWS Lambda escrito em Node.js com três ações distintas identificadas por parâmetro action. A ação ACT_VALIDATE_USER_DOCUMENT valida se um CPF possui formato correto (11 dígitos numéricos) e dígitos verificadores válidos segundo algoritmo da Receita Federal. O algoritmo remove máscaras do CPF, verifica se possui exatamente 11 dígitos, rejeita sequências uniformes como 111.111.111-11, calcula primeiro dígito verificador multiplicando os 9 primeiros dígitos por pesos de 10 a 2 e aplicando módulo 11, calcula segundo dígito verificador multiplicando os 10 primeiros dígitos por pesos de 11 a 2 e aplicando módulo 11, e compara os dígitos calculados com os dígitos fornecidos.

A ação ACT_VALIDATE_CUSTOMER_STATUS verifica se um cliente existe na base de dados consultando a tabela clientes filtrando por campo documento (CPF sem máscaras) e deletado_em IS NULL para ignorar soft deletes. Retorna UUID do cliente se encontrado permitindo que cliente seja identificado em requisições subsequentes. Esta validação é necessária para garantir que apenas clientes cadastrados possam acessar funcionalidades do sistema.

A ação ACT_GENERATE_TOKEN autentica usuários do sistema (mecânicos, atendentes, administradores) através de email e senha. Consulta a tabela usuarios filtrando por email e deletado_em IS NULL. Compara senha fornecida com hash armazenado usando bcryptjs que implementa bcrypt com salt automático resistente a rainbow tables e ataques de força bruta. Gera token JWT contendo issuer (emissor do token), audience (público-alvo), iat (issued at timestamp), nbf (not before timestamp), exp (expiration timestamp configurado para 24 horas), sub (subject com UUID do usuário), e perf (perfil do usuário para controle de permissões). O token é assinado com secret armazenado em variável de ambiente JWT_SECRET usando algoritmo HS256.

A integração com API Gateway permite configurar endpoints REST mapeados para a Lambda, validação automática de requisições, Lambda Authorizer para validar JWT em requisições subsequentes, rate limiting para proteção contra DDoS, CORS configurável, logging automático em CloudWatch Logs, e métricas em CloudWatch Metrics.

Os benefícios incluem desacoplamento total onde autenticação é completamente isolada da aplicação principal permitindo deploy, scaling e manutenção independentes. Escalabilidade automática de zero a milhares de execuções concorrentes sem configuração manual através de Auto Scaling nativo do Lambda. Custo otimizado pois paga-se apenas pelo uso real com free tier de 1 milhão de requisições por mês e 400 mil GB-segundo de compute gratuitos mensalmente. Segurança através de API Gateway atuando como camada de proteção com rate limiting, validação de requisições e integração com WAF. Validação robusta de CPF através de algoritmo matemático determinístico. JWT stateless permitindo validação local sem consulta a banco em cada requisição. Cumprimento completo do requisito obrigatório do Tech Challenge Fase 3.

As limitações incluem cold start onde primeira execução após período de inatividade possui latência de 100-300ms enquanto Lambda inicializa runtime Node.js e carrega dependências. Latência de rede adicional para comunicação Lambda → PostgreSQL especialmente se Lambda e banco estão em VPCs diferentes. Debugging mais complexo através de CloudWatch Logs que é menos intuitivo que logs locais durante desenvolvimento. Vendor lock-in parcial na AWS Lambda embora código Node.js possa ser containerizado e executado em outras plataformas.

**Alternativa 2: Autenticação Monolítica no Laravel**

Manter autenticação dentro da aplicação Laravel utilizando Laravel Passport ou implementação manual de JWT via bibliotecas PHP como firebase/php-jwt. O fluxo seria Cliente → Nginx → Laravel → Validação Eloquent → Geração JWT → Resposta.

Os benefícios incluem implementação mais rápida aproveitando convenções do Laravel, menor complexidade arquitetural sem necessidade de Lambda e API Gateway, sem latência de rede adicional pois tudo ocorre no mesmo processo, debugging mais simples através de logs locais e ferramentas tradicionais de desenvolvimento PHP.

As limitações críticas incluem não atendimento do requisito obrigatório do Tech Challenge que exige explicitamente Function Serverless e API Gateway. Acoplamento forte entre autenticação e aplicação principal impossibilitando evolução independente. Escalabilidade limitada pois autenticação escala junto com todo o monolito exigindo scaling de todos os pods Kubernetes mesmo se apenas autenticação está sob carga. Custos fixos de pods Kubernetes sempre ativos mesmo sem requisições de autenticação.

**Alternativa 3: AWS Cognito**

AWS Cognito é um serviço gerenciado de autenticação e autorização que oferece User Pools para gerenciamento de usuários, sign-up e sign-in com validações integradas, suporte a MFA (Multi-Factor Authentication), OAuth 2.0 e OpenID Connect, integração nativa com API Gateway, e UI customizável para login.

Os benefícios incluem solução completamente gerenciada eliminando necessidade de implementar lógica de autenticação, segurança enterprise-grade com conformidade a padrões de mercado, escalabilidade automática sem configuração, e integração facilitada com outros serviços AWS.

As limitações incluem validação customizada de CPF limitada pois Cognito espera username/email/telefone como identificadores primários. Implementar validação de dígitos verificadores de CPF requereria Lambda Trigger adicionando complexidade. Custo pós-free tier superior ao Lambda pois Cognito cobra por MAU (Monthly Active Users). Menor controle sobre fluxo de autenticação e estrutura de JWT. Não demonstra conhecimento técnico de implementação de autenticação sendo requisito acadêmico implementar solução própria.

**Alternativa 4: Soluções SaaS (Auth0, Okta)**

Auth0 e Okta são plataformas de Identity as a Service (IDaaS) oferecendo autenticação enterprise-grade, UI completa para login com customização visual, suporte a Social Login (Google, Facebook, etc), MFA e gestão de sessões, SDKs para múltiplas linguagens, e dashboards de analytics.

Os benefícios incluem implementação extremamente rápida através de SDKs prontos, segurança e conformidade gerenciadas pela plataforma, UI profissional sem necessidade de desenvolvimento frontend, e suporte técnico especializado.

As limitações críticas incluem custo elevado especialmente para ambientes de produção, dependência de serviço terceiro externo à AWS, não demonstração de conhecimento técnico sendo requisito acadêmico implementar solução própria, e complexidade de integração com validação customizada de CPF.

**Análise Comparativa**

AWS Lambda com API Gateway oferece o equilíbrio ideal entre cumprimento de requisitos acadêmicos, desacoplamento arquitetural, custo-benefício e controle técnico. Atende explicitamente o requisito obrigatório do Tech Challenge de utilizar Function Serverless e API Gateway. Permite implementação customizada de validação de CPF com controle total sobre lógica e fluxo. Custo otimizado através de modelo pay-per-use adequado a ambientes acadêmicos com orçamento limitado. Demonstra conhecimento técnico de arquitetura serverless, validação de credenciais, geração de JWT e integração de serviços AWS.

Autenticação monolítica no Laravel seria inadequada pois não atende requisito obrigatório do Tech Challenge apesar de ser tecnicamente mais simples. AWS Cognito adiciona custo e complexidade desnecessários para validação customizada de CPF. Soluções SaaS como Auth0 e Okta são inviáveis devido a custo elevado e não demonstram conhecimento técnico necessário para projeto acadêmico.

## Decisão

A equipe decidiu adotar AWS Lambda integrado com AWS API Gateway para implementar autenticação com validação de CPF de clientes e autenticação email/senha de usuários do sistema, gerando tokens JWT stateless. Essa decisão fundamenta-se na análise comparativa de alternativas considerando requisitos obrigatórios do Tech Challenge, arquitetura distribuída do sistema, restrições orçamentárias e demonstração de conhecimento técnico.

A implementação utiliza AWS Lambda escrita em Node.js utilizando ES6 modules com suporte a import/export. As dependências incluem pg versão 8.16.3 para conexão com PostgreSQL através de connection pool configurado com máximo de 20 conexões, jsonwebtoken versão 9.0.3 para geração e validação de tokens JWT, bcryptjs versão 3.0.3 para comparação segura de senhas com hashes bcrypt, e dotenv versão 17.2.3 para carregamento de variáveis de ambiente durante desenvolvimento.

A arquitetura de fluxo implementada funciona da seguinte forma. O cliente envia requisição POST para AWS API Gateway no endpoint /auth/{action} onde action especifica a operação desejada. API Gateway valida formato da requisição e invoca AWS Lambda passando action, body e headers. Lambda executa handler principal que despacha para ação específica baseada no parâmetro action recebido.

Para validação de documento (ACT_VALIDATE_USER_DOCUMENT), Lambda recebe CPF no body da requisição, remove máscaras mantendo apenas dígitos, verifica se possui exatamente 11 dígitos numéricos, rejeita sequências uniformes como 111.111.111-11 ou 000.000.000-00, calcula primeiro dígito verificador através de soma ponderada dos 9 primeiros dígitos com pesos de 10 a 2 seguida de módulo 11, calcula segundo dígito verificador através de soma ponderada dos 10 primeiros dígitos com pesos de 11 a 2 seguida de módulo 11, compara dígitos calculados com dígitos fornecidos, e retorna sucesso ou erro descritivo.

Para validação de status de cliente (ACT_VALIDATE_CUSTOMER_STATUS), Lambda recebe CPF no body, remove máscaras do CPF, executa query SQL SELECT uuid FROM clientes WHERE documento = $1 AND deletado_em IS NULL LIMIT 1 passando CPF como parâmetro, retorna UUID do cliente se encontrado, ou retorna erro 404 se cliente não existe ou foi deletado.

Para geração de token (ACT_GENERATE_TOKEN), Lambda recebe email e password no body da requisição, executa query SQL SELECT * FROM usuarios WHERE email = $1 AND deletado_em IS NULL LIMIT 1, compara senha fornecida com hash armazenado usando bcryptjs.compare que implementa comparação timing-safe resistente a timing attacks, gera token JWT com issuer http://localhost:9000, audience http://localhost:9000, iat (issued at) timestamp atual, nbf (not before) timestamp atual, exp (expiration) timestamp atual mais 24 horas (86400 segundos), sub (subject) UUID do usuário, e perf (perfil) perfil do usuário para controle de permissões. O token é assinado com secret armazenado em variável de ambiente JWT_SECRET usando algoritmo HS256. Lambda retorna token JWT, tempo de expiração em segundos, e dados do usuário autenticado.

AWS API Gateway é configurado com endpoints REST mapeando rotas para Lambda, configuração de CORS para permitir requisições cross-origin de aplicações frontend, rate limiting para proteção contra DDoS, Lambda Authorizer customizado para validar JWT em requisições subsequentes a endpoints protegidos, e logging integrado com CloudWatch para auditoria.

O Lambda Authorizer funciona como middleware de validação onde requisições a endpoints protegidos incluem header Authorization: Bearer <token>. API Gateway invoca Lambda Authorizer antes de encaminhar requisição para aplicação Laravel. Lambda Authorizer extrai token do header, valida assinatura usando mesmo secret, verifica expiração comparando exp claim com timestamp atual, extrai claims sub e perf para identificação e autorização, gera IAM Policy com Allow ou Deny, e API Gateway permite ou bloqueia requisição baseado na policy retornada.

A conexão com PostgreSQL utiliza pool de conexões configurado com máximo de 20 conexões simultâneas, host obtido de variável de ambiente DB_HOST, porta obtida de DB_PORT (padrão 5432), usuário obtido de DB_USER, senha obtida de DB_PASSWORD, e database obtido de DB_NAME. O pool reutiliza conexões entre invocações Lambda quando possível através de container reuse reduzindo latência de estabelecimento de conexão.

As variáveis de ambiente necessárias incluem DB_HOST apontando para PostgreSQL (RDS ou service ClusterIP no EKS), DB_PORT com porta do PostgreSQL, DB_USER com usuário de banco, DB_PASSWORD com senha de banco, DB_NAME com nome do database, e JWT_SECRET com secret para assinatura de tokens armazenado preferencialmente em AWS Secrets Manager.

O monitoramento é realizado através de CloudWatch Logs capturando console.log e erros, CloudWatch Metrics rastreando invocations (número de execuções), duration (tempo de execução), errors (execuções com erro), e throttles (execuções throttled por limites de concorrência). Opcionalmente AWS X-Ray pode ser habilitado para tracing distribuído visualizando latência de cada operação incluindo conexão PostgreSQL e geração de JWT.

## Consequências

### Positivas

O desacoplamento total entre autenticação e aplicação principal permite deploy independente onde Lambda pode ser atualizado sem deploy de Kubernetes, scaling independente onde picos de autenticação não afetam aplicação principal, e manutenção isolada onde bugs em autenticação são corrigidos sem tocar aplicação.

A escalabilidade automática do Lambda escala de zero execuções em períodos sem uso para milhares de execuções concorrentes em picos de carga sem configuração manual. O Auto Scaling é instantâneo sem necessidade de esperar provisionamento de pods Kubernetes. Lambda mantém pool de containers aquecidos reduzindo cold starts após primeira execução.

O custo otimizado através de modelo pay-per-use cobra apenas por execuções reais sem custos fixos em idle. AWS free tier oferece 1 milhão de requisições por mês gratuitas e 400 mil GB-segundo de compute gratuitos mensalmente. Estimativas indicam que 1000 autenticações por dia resultam em aproximadamente 30 mil requisições mensais custando aproximadamente $0.60 por mês pós-free tier. Comparativamente, pod Kubernetes dedicado a autenticação em instância t3.medium custaria aproximadamente $30 mensais resultando em economia de aproximadamente 98%.

A segurança é reforçada através de API Gateway atuando como camada de proteção com rate limiting configurável prevenindo DDoS. Lambda Authorizer valida JWT antes de requisição atingir aplicação Laravel. Secret de JWT é armazenado em AWS Secrets Manager com rotação automática opcional. Conexão Lambda → PostgreSQL pode ser configurada via VPC peering garantindo tráfego privado.

A validação robusta de CPF implementa algoritmo matemático determinístico baseado em dígitos verificadores segundo especificação da Receita Federal. Rejeita sequências uniformes inválidas. Opera sem dependências externas sendo completamente local e rápida.

JWT stateless permite validação local sem consulta a banco de dados em cada requisição. Claims customizados transportam identificação e perfil do usuário eliminando lookups adicionais. Expiração de 24 horas balanceia segurança e experiência de usuário.

O cumprimento completo do requisito obrigatório do Tech Challenge Fase 3 atende especificação de Function Serverless e API Gateway. Demonstra conhecimento técnico de arquitetura serverless, autenticação distribuída e segurança em nuvem. Repositório Lambda separado evidencia segregação de responsabilidades conforme requisito de 4 repositórios distintos.

### Negativas

Cold start introduz latência de 100-300ms na primeira execução após período de inatividade enquanto Lambda inicializa runtime Node.js e carrega dependências (pg, jsonwebtoken, bcryptjs). Esse impacto é mitigado através de Provisioned Concurrency que mantém containers aquecidos mediante custo adicional, ou warm-up scheduled via EventBridge invocando Lambda periodicamente.

A latência de rede adicional ocorre na comunicação Lambda → PostgreSQL especialmente se estão em VPCs diferentes exigindo VPC peering. Cada query adiciona roundtrip network latency de aproximadamente 1-5ms dependendo da região e configuração de rede. Esse impacto é mitigado através de connection pooling reutilizando conexões entre invocações, ou migrando banco para RDS na mesma VPC da Lambda.

O debugging é mais complexo através de CloudWatch Logs que é menos intuitivo que logs locais durante desenvolvimento. Stack traces em erros são menos detalhados que ambiente local. Teste local de Lambda requer ferramentas como SAM CLI ou Serverless Framework. Esse impacto é mitigado através de testes unitários abrangentes executados localmente via Jest, e logging estruturado capturando contexto completo de erros.

O vendor lock-in parcial existe na AWS Lambda embora código Node.js seja portável. Migração para outro provedor (GCP Cloud Functions, Azure Functions) requer ajustes em deployment e configuração. API Gateway é específico da AWS exigindo substituição por API Gateway equivalente de outro provedor. Esse impacto é aceito no contexto acadêmico e pode ser mitigado no futuro através de containerização do código Lambda executável em Kubernetes via Knative Serving.

A complexidade de 4 repositórios separados exige CI/CD independente para cada repositório. Sincronização de mudanças em schemas de banco entre repositórios requer comunicação e documentação. Debugging de fluxos distribuídos atravessando Lambda → API Gateway → Laravel é mais complexo que monolito. Esse impacto é mitigado através de documentação clara de contratos de API, versionamento semântico rigoroso, e tracing distribuído via X-Ray.

## Notas de Implementação

O repositório Lambda está localizado em /home/nicolas/Dev/pessoal/fase 3/soat-fase3-lambda com estrutura hello-world/app.mjs contendo handler principal e funções de validação, hello-world/package.json definindo dependências, .github/workflows/lambda.yaml para CI/CD automatizado, e README.md documentando ações disponíveis e exemplos de uso.

O handler principal em app.mjs exporta função lambdaHandler que recebe event e context, extrai action de event.action ou event.queryStringParameters.action, despacha para função específica baseada em action (validateUserDocument para ACT_VALIDATE_USER_DOCUMENT, validateCustomerStatus para ACT_VALIDATE_CUSTOMER_STATUS, generateToken para ACT_GENERATE_TOKEN), captura erros retornando status 500 com mensagem de erro, e retorna response com statusCode, headers incluindo CORS, e body stringified JSON.

A função validateUserDocument (ACT_VALIDATE_USER_DOCUMENT) recebe CPF via event.body.cpf, invoca função ehDocumentoValido que implementa algoritmo completo de validação de dígitos verificadores, retorna status 200 com mensagem "CPF válido" se válido, ou retorna status 400 com mensagem "CPF inválido" se inválido.

A função validateCustomerStatus (ACT_VALIDATE_CUSTOMER_STATUS) recebe CPF via event.body.cpf, remove máscaras mantendo apenas dígitos, executa query parametrizada SELECT uuid FROM clientes WHERE documento = $1 AND deletado_em IS NULL LIMIT 1, retorna status 200 com UUID do cliente se encontrado, ou retorna status 404 com mensagem "Cliente não encontrado" se não existe.

A função generateToken (ACT_GENERATE_TOKEN) recebe email e password via event.body, executa query SELECT * FROM usuarios WHERE email = $1 AND deletado_em IS NULL LIMIT 1, valida senha usando bcryptjs.compare comparando password fornecido com hash armazenado, retorna status 401 com mensagem "Credenciais inválidas" se senha incorreta, gera token JWT usando jwt.sign com payload contendo iss, aud, iat, nbf, exp (24h), sub (UUID), perf (perfil), secret obtido de process.env.JWT_SECRET, e algoritmo HS256. Retorna status 200 com token, expiresIn (86400 segundos), e dados do usuário.

O CI/CD Pipeline via GitHub Actions localizado em .github/workflows/lambda.yaml é triggered em push para branch main, executa npm install instalando dependências, executa npm test rodando testes unitários, empacota código em ZIP, autentica na AWS via OIDC ou access keys, e executa aws lambda update-function-code atualizando função Lambda na região us-east-2.

A integração com API Gateway mapeia endpoint POST /auth/validate-document para action=ACT_VALIDATE_USER_DOCUMENT, endpoint POST /auth/validate-customer para action=ACT_VALIDATE_CUSTOMER_STATUS, e endpoint POST /auth/login para action=ACT_GENERATE_TOKEN. Headers de CORS são configurados permitindo Access-Control-Allow-Origin. Rate limiting é configurado prevenindo abuse com limite de 100 requisições por segundo por IP.

## Revisões

- **01/12/2024**: Decisão inicial (Aceita)
- **10/12/2024**: Implementação completa Lambda com 3 ações
- **15/12/2024**: Integração com API Gateway e deploy em produção
- **08/01/2026**: Revisão para documentação Fase 3 com formato ADR+RFC rigoroso e correção de informações técnicas baseadas em código real

## Referências

- AWS Lambda Documentation - https://docs.aws.amazon.com/lambda/
- AWS API Gateway Lambda Authorizers - https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-use-lambda-authorizer.html
- JWT.io JSON Web Tokens - https://jwt.io/
- Node.js pg (PostgreSQL client) - https://node-postgres.com/
- bcryptjs Documentation - https://github.com/dcodeIO/bcrypt.js
- Validação de CPF Receita Federal - https://www.gov.br/receitafederal/pt-br

## Palavras-Chave

AWS Lambda, Serverless, JWT, Authentication, CPF, API Gateway, Lambda Authorizer, Node.js, PostgreSQL, bcrypt, Scaling, Microservices, Architecture Decision, Cloud Native, ADR, RFC, Tech Challenge, FIAP
