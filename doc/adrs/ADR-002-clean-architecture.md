# ADR-002: Adoção de Clean Architecture no Laravel

**Data:** 08/01/2026
**Status:** Aceita

## Contexto

O projeto Oficina SOAT é um sistema acadêmico desenvolvido no contexto do programa de pós-graduação FIAP em Arquitetura de Software, utilizando Laravel 12 como framework principal. Laravel oferece uma estrutura Model-View-Controller (MVC) tradicional que facilita desenvolvimento rápido e prototipagem, com convenções bem estabelecidas e produtividade imediata. Contudo, a abordagem MVC padrão do Laravel incentiva o uso de ActiveRecord via Eloquent ORM, o que frequentemente resulta em acoplamento forte entre lógica de negócio e detalhes de persistência.

O sistema manipula seis entidades principais: Cliente, Veículo, Usuário, Serviço, Material e Ordem de Serviço. A entidade Ordem é particularmente complexa, envolvendo relacionamentos múltiplos com materiais e serviços, transições de estado, validações de negócio, e cálculos agregados. A complexidade dessas regras de negócio exige uma arquitetura que promova separação clara de responsabilidades, testabilidade rigorosa, e evolução sustentável do código.

Os requisitos funcionais incluem operações CRUD completas para todas as entidades, regras de negócio complexas como validação de CPF, transições de estado de ordens de serviço, cálculo de valores totais considerando materiais e serviços, autenticação JWT, e middlewares de validação. Os requisitos não-funcionais críticos incluem testabilidade com meta de cobertura superior a 80%, manutenibilidade permitindo adição de novas features sem refatorações massivas, escalabilidade para suportar crescimento do sistema em múltiplas unidades da oficina, e independência de framework onde a lógica de negócio não deve depender diretamente do Laravel.

Do ponto de vista organizacional, o projeto possui prazos definidos com entregas divididas em três fases distintas. A equipe é composta por três desenvolvedores com conhecimento sólido em SOLID e Design Patterns, mas experiência limitada com arquiteturas avançadas. O projeto será revisado por professores e arquitetos da FIAP, sendo requisito demonstrar conhecimento arquitetural através de documentação completa incluindo ADRs, RFCs e diagramas C4.

Laravel incentiva MVC tradicional onde Models Eloquent funcionam como ActiveRecord concentrando lógica de negócio, persistência e validação. Controllers tendem a se tornar "gordos" acumulando regras de negócio, validações e orquestração. Essa abordagem funciona bem para aplicações simples, mas dificulta testes unitários, manutenção de longo prazo e evolução arquitetural. Clean Architecture introduz complexidade inicial através de mais arquivos, interfaces, camadas de abstração e código boilerplate, mas a equipe reconhece que essa complexidade é investimento para qualidade de longo prazo.

### Proposta de Discussão

Esta seção documenta a análise técnica realizada para fundamentar a escolha do padrão arquitetural, considerando alternativas viáveis e seus respectivos trade-offs no contexto acadêmico e técnico do projeto.

**Alternativa 1: Clean Architecture (Proposta Selecionada)**

Clean Architecture é um padrão arquitetural proposto por Robert C. Martin (Uncle Bob) que organiza código em camadas concêntricas onde dependências apontam de fora para dentro. A camada mais interna (Domain) contém entidades e regras de negócio puras, completamente independentes de frameworks, bancos de dados ou interfaces de usuário. A camada intermediária contém casos de uso (Use Cases) que orquestram fluxo de dados entre entidades e aplicam regras de aplicação. A camada mais externa (Infrastructure) contém detalhes de implementação como frameworks, bancos de dados, APIs e interfaces de usuário.

A estrutura proposta organiza o código em três camadas principais. Domain contém Entity com entidades puras do domínio (Cliente, Veículo, Ordem, Material, Servico, Usuario), cada uma com sua interface de repositório e mapper. Domain também contém UseCase com casos de uso para cada operação (CreateUseCase, ReadUseCase, UpdateUseCase, DeleteUseCase) organizados por entidade. Infrastructure contém Controller (adaptadores HTTP), Gateway (integrações externas), Presenter (formatação de respostas), Repositories (implementações concretas de persistência), Service (serviços de infraestrutura como BusinessEventLogger), e Dto (Data Transfer Objects). Http contém Middleware específicos do Laravel como JsonWebTokenMiddleware e DocumentoObrigatorioMiddleware. Models contém Eloquent Models como camada externa acessada apenas por repositórios. Exception contém exceções customizadas, e Signature contém interfaces e contratos globais.

Os benefícios da Clean Architecture incluem isolamento completo de regras de negócio onde entidades são classes PHP puras sem dependências externas, testáveis sem framework, banco ou HTTP. Use Cases encapsulam lógica de aplicação e podem ser testados com mocks de repositórios. Repository Pattern abstrai persistência através de interfaces permitindo trocar Eloquent por Doctrine, MongoDB ou qualquer outra tecnologia sem alterar Domain. Controllers são finos atuando apenas como adaptadores HTTP para Use Cases. A testabilidade é maximizada com testes unitários para entidades e Use Cases isolados, e testes de integração para repositórios e controllers. Princípios SOLID são aplicados rigorosamente através de Single Responsibility (cada UseCase tem uma responsabilidade), Open/Closed (extensão via novos UseCases), Liskov Substitution (interfaces permitem substituição), Interface Segregation (interfaces pequenas e específicas), e Dependency Inversion (Domain depende de interfaces, Infrastructure implementa).

As limitações incluem complexidade inicial com mais arquivos e estrutura de pastas (aproximadamente 30% mais código que MVC tradicional), curva de aprendizado para equipe familiarizada apenas com MVC, e verbosidade devido a código boilerplate como interfaces e DTOs. Para MVPs e protótipos descartáveis, Clean Architecture pode ser over-engineering.

**Alternativa 2: MVC Tradicional do Laravel**

MVC tradicional do Laravel segue a estrutura padrão do framework onde Models Eloquent implementam ActiveRecord contendo lógica de negócio, persistência, validações e relacionamentos. Controllers orquestram operações recebendo requisições HTTP, validando dados, invocando métodos de Models, e retornando views ou JSON. Views renderizam HTML usando Blade templates. Esta abordagem é o padrão oficial do Laravel documentado extensivamente.

Os benefícios incluem desenvolvimento mais rápido inicialmente devido a convenções do framework e scaffolding automático. A estrutura de pastas é mais simples com menos arquivos. A curva de aprendizado é menor pois é o padrão Laravel conhecido pela maioria dos desenvolvedores PHP. Documentação oficial do Laravel assume MVC tradicional. Para aplicações CRUD simples, MVC tradicional é perfeitamente adequado e produtivo.

As limitações críticas incluem lógica de negócio misturada com framework onde Models Eloquent acoplam regras de negócio a ActiveRecord. Controllers tendem a se tornar "gordos" acumulando regras de negócio, validações complexas e orquestração de múltiplos models. Testes unitários são difíceis sem banco de dados e HTTP pois Models Eloquent dependem de conexão com banco. Acoplamento forte ao Eloquent dificulta migração para outros ORMs ou padrões de persistência. Violação de princípios SOLID especialmente Single Responsibility e Dependency Inversion. Escalabilidade de código é limitada onde adicionar complexidade resulta em Controllers e Models cada vez maiores e mais difíceis de manter.

**Alternativa 3: Hexagonal Architecture (Ports & Adapters)**

Hexagonal Architecture, também conhecida como Ports & Adapters, é um padrão proposto por Alistair Cockburn que organiza código em núcleo de negócio (hexágono central) cercado por portas (interfaces) e adaptadores (implementações). Ports são interfaces que definem contratos de comunicação, divididas em Inbound Ports (APIs que o núcleo expõe) e Outbound Ports (APIs que o núcleo requer). Adapters são implementações concretas como REST controllers, repositories, message queues, etc.

Os benefícios incluem conceitos similares a Clean Architecture com foco em isolamento de negócio, ênfase explícita em interfaces (ports) facilitando substituição de implementações (adapters), e flexibilidade para múltiplos adaptadores (REST API + GraphQL + CLI compartilhando mesmo núcleo).

As limitações incluem menor reconhecimento que Clean Architecture na comunidade, documentação menos abundante especialmente para PHP/Laravel, terminologia menos intuitiva (ports/adapters vs domain/infrastructure), e maior abstração conceitual que pode confundir equipe sem experiência prévia.

**Alternativa 4: Domain-Driven Design Puro (DDD)**

Domain-Driven Design é uma abordagem proposta por Eric Evans que enfatiza modelagem do domínio através de linguagem ubíqua, agregados, value objects, domain events, bounded contexts e camadas de domínio. DDD completo implementa conceitos avançados como Aggregates (clusters de entidades com raiz), Value Objects (objetos imutáveis sem identidade), Domain Events (eventos de negócio para comunicação entre agregados), Bounded Contexts (fronteiras lógicas de subdomínios), e Anti-Corruption Layer (camada de proteção entre contextos).

Os benefícios incluem modelagem rica do domínio alinhada com linguagem de negócio, agregados garantindo consistência transacional, value objects melhorando expressividade do código, domain events permitindo arquitetura event-driven, e bounded contexts facilitando modularização de sistemas grandes.

As limitações críticas incluem complexidade significativamente maior que Clean Architecture, curva de aprendizado steep especialmente para equipe sem experiência DDD, over-engineering para escopo atual do projeto que possui domínio relativamente simples, e risco de análise paralítica onde a equipe gasta tempo excessivo em modelagem ao invés de implementação.

**Análise Comparativa**

Clean Architecture oferece o melhor equilíbrio entre separação de responsabilidades, testabilidade, independência de framework e complexidade gerenciável. É amplamente conhecida na indústria com vasta documentação e exemplos. Atende os requisitos acadêmicos de demonstrar conhecimento arquitetural sem complexidade excessiva de DDD completo. Permite evolução gradual do sistema através de adição de novos Use Cases sem grandes refatorações.

MVC tradicional seria inadequado pois não atende requisito de independência de framework, dificulta testes unitários, e viola princípios SOLID que são requisitos acadêmicos. Hexagonal Architecture é conceitualmente similar a Clean Architecture mas menos conhecida e documentada. DDD completo seria over-engineering para o escopo atual e arriscaria análise paralítica comprometendo prazos.

## Decisão

A equipe decidiu adotar Clean Architecture com separação clara em três camadas principais: Domain, Infrastructure e Http. Essa decisão fundamenta-se na análise comparativa de alternativas considerando requisitos funcionais, não-funcionais, restrições acadêmicas e capacidade técnica da equipe.

A camada Domain contém a lógica de negócio pura e independente de qualquer framework ou tecnologia externa. Entidades são implementadas como classes PHP puras sem herança de ActiveRecord ou qualquer framework. Cada entidade reside em namespace próprio contendo a classe da entidade, interface de repositório e mapper para conversão entre entidade e model Eloquent. As entidades implementam validações de negócio em construtores e setters privados, garantindo que objetos inválidos não possam ser construídos. Por exemplo, a entidade Cliente valida que nome possui no mínimo 3 caracteres, CPF é válido segundo algoritmo de verificação, email possui formato válido, e telefone não está vazio.

Use Cases residem na camada Domain e encapsulam regras de aplicação orquestrando fluxo entre entidades e repositórios. Cada Use Case possui responsabilidade única como CreateClienteUseCase, ReadClienteUseCase, UpdateClienteUseCase e DeleteClienteUseCase. Use Cases recebem dependências via injeção de construtor, especificamente interfaces de repositórios. O método execute recebe dados primitivos ou DTOs e retorna entidades ou tipos primitivos. Use Cases não conhecem detalhes de HTTP, JSON, Eloquent ou qualquer framework. Por exemplo, CreateClienteUseCase gera UUID via Ramsey/Uuid, instancia entidade Cliente validando dados no construtor, persiste via interface de repositório sem conhecer Eloquent, e retorna entidade criada.

Repository Pattern abstrai completamente detalhes de persistência através de interfaces definidas na camada Domain. Interfaces de repositório declaram métodos de persistência como save, findByUuid, findByCpf, findAll e delete, trabalhando exclusivamente com entidades do domínio sem exposição de Models Eloquent. Implementações concretas residem em Infrastructure/Repositories e traduzem entre entidades de domínio e Models Eloquent. Por exemplo, ClienteRepositorio implementa ClienteRepositorioInterface usando Eloquent internamente através de updateOrCreate e métodos de query, mas Use Cases dependem apenas da interface permitindo substituição de implementação.

Controllers da Clean Architecture residem em Infrastructure/Controller e funcionam como adaptadores entre HTTP e Domain. Controllers são classes finas que recebem dependências via injeção de construtor incluindo Use Cases necessários e Presenters para formatação de resposta. Métodos de controller recebem Request do Laravel, extraem dados via request->all(), invocam Use Case passando dados, recebem entidade ou resultado, formatam resposta via Presenter, e retornam JsonResponse. Controllers não contêm lógica de negócio, apenas adaptação HTTP para Domain. Por exemplo, método store do controller Cliente invoca CreateClienteUseCase, recebe entidade criada, e usa JsonPresenter para retornar JSON com status 201.

Presenters residem em Infrastructure/Presenter e formatam entidades de domínio para representações externas como JSON ou XML. JsonPresenter recebe entidade de domínio, extrai dados via getters, formata como array associativo, e retorna JsonResponse do Laravel. Presenters isolam formatação permitindo múltiplas representações da mesma entidade sem alterar Domain.

Middlewares específicos do Laravel residem em Http/Middleware e lidam com aspectos transversais como autenticação e validação. JsonWebTokenMiddleware valida tokens JWT extraindo token do header Authorization, verificando assinatura e expiração, e injetando dados do usuário no request. DocumentoObrigatorioMiddleware valida presença de documento (CPF) em requisições específicas. Middlewares acessam camada Domain apenas via Use Cases, nunca diretamente.

Models Eloquent residem em app/Models como camada mais externa acessada exclusivamente por repositórios. Models definem schema de banco, relacionamentos Eloquent, e casting de atributos. Models não contêm lógica de negócio, servindo apenas como mapeamento objeto-relacional. Repositórios traduzem entre entidades de domínio (lógica rica) e Models Eloquent (persistência).

Injeção de dependências é gerenciada pelo Laravel Service Container através de bindings em AppServiceProvider. Interfaces de repositórios são ligadas a implementações concretas permitindo que Use Cases recebam implementações corretas automaticamente. Rotas do Laravel apontam diretamente para Controllers da Clean Architecture sem camada intermediária. Migrations do Laravel permanecem em estrutura padrão database/migrations gerenciando schema do banco.

A aplicação rigorosa de princípios SOLID garante qualidade arquitetural. Single Responsibility Principle é aplicado onde cada Use Case tem uma responsabilidade, cada Controller trata uma entidade, e cada Repository implementa uma interface. Open/Closed Principle permite extensão através de novos Use Cases e implementações de interface sem modificar código existente. Liskov Substitution Principle é garantido através de interfaces permitindo substituir implementações de repositórios sem afetar Use Cases. Interface Segregation Principle mantém interfaces pequenas e específicas onde repositórios expõem apenas métodos necessários. Dependency Inversion Principle inverte dependências onde camada Domain define interfaces que Infrastructure implementa.

Object Calisthenics é aplicado onde viável para maximizar qualidade de código. Métodos mantêm um nível de indentação preferindo early returns. Estruturas else são evitadas através de guard clauses e early returns. Nomes são claros e autoexplicativos dispensando comentários. Classes são mantidas pequenas com menos de 200 linhas preferindo composição.

Testabilidade é maximizada através de separação de camadas. Testes unitários testam entidades isoladamente verificando validações de negócio sem framework, banco ou HTTP. Testes unitários testam Use Cases com mocks de repositórios verificando orquestração correta. Testes de integração testam repositórios com banco PostgreSQL real verificando persistência e queries. Testes de feature testam controllers com HTTP simulado verificando integração completa. A cobertura atual atinge aproximadamente 85% considerando testes unitários e de integração combinados.

## Consequências

### Positivas

A testabilidade é maximizada através de separação rigorosa de camadas. Entidades de domínio são testáveis sem framework, banco de dados ou HTTP através de testes unitários puros que verificam regras de negócio isoladamente. Use Cases são testáveis com mocks de repositórios verificando orquestração correta entre entidades e persistência. Repositórios são testáveis com banco de dados real através de testes de integração. Controllers são testáveis com HTTP simulado. A cobertura de testes atinge 85% combinando testes unitários e de integração, superando a meta de 80%.

A manutenibilidade é significativamente melhorada através de separação clara de responsabilidades. Mudanças em regras de negócio são localizadas na camada Domain sem afetar Infrastructure. Mudanças em persistência (trocar Eloquent por Doctrine) são localizadas em Repositories sem afetar Use Cases. Mudanças em interface HTTP (adicionar GraphQL) requerem apenas novos Controllers sem afetar Domain. Adicionar novas entidades ou Use Cases segue estrutura estabelecida sem refatorações massivas.

A independência de framework é garantida através de inversão de dependências. A lógica de negócio em Domain não depende de Laravel, Eloquent ou qualquer framework específico. Migração de Laravel para Symfony, por exemplo, requereria apenas reescrever camada Infrastructure mantendo Domain intacto. Essa independência reduz risco de lock-in tecnológico e facilita evolução arquitetural.

A separação de responsabilidades é clara e bem definida. Entidades contêm apenas regras de negócio. Use Cases contêm apenas lógica de aplicação. Controllers contêm apenas adaptação HTTP. Repositories contêm apenas persistência. Essa separação facilita compreensão do código e onboarding de novos desenvolvedores.

A qualidade de código é elevada através de aplicação rigorosa de SOLID e Object Calisthenics. Single Responsibility garante classes focadas. Open/Closed permite extensão sem modificação. Liskov Substitution garante substituição segura de implementações. Interface Segregation mantém contratos específicos. Dependency Inversion inverte dependências corretamente. Object Calisthenics reduz complexidade ciclomática e melhora legibilidade.

A documentação é rica através de interfaces servindo como contratos claros. Interfaces de repositório documentam operações de persistência disponíveis. Interfaces de Use Cases documentam fluxos de aplicação. Type hints em PHP 8.4 documentam tipos esperados e retornados. Essa documentação viva no código complementa ADRs e diagramas C4.

A escalabilidade de código é facilitada através de estrutura extensível. Adicionar nova entidade segue padrão estabelecido: criar entidade em Domain/Entity, criar interface de repositório, criar Use Cases (Create/Read/Update/Delete), implementar repositório em Infrastructure, criar controller em Infrastructure. Adicionar nova funcionalidade a entidade existente cria novo Use Case sem modificar existentes.

### Negativas

A complexidade inicial é significativamente maior comparada a MVC tradicional. A estrutura de pastas é mais profunda com mais arquivos. Cada entidade requer entidade pura, interface de repositório, mapper, 4+ Use Cases, repositório concreto, controller, e model Eloquent. Essa complexidade pode intimidar desenvolvedores acostumados apenas com MVC e reduzir velocidade inicial de desenvolvimento.

A curva de aprendizado é steep para equipe sem experiência prévia com Clean Architecture. Desenvolvedores precisam compreender separação de camadas, inversão de dependências, Repository Pattern, Use Case Pattern, e injeção de dependências. Esse aprendizado consome tempo nas fases iniciais do projeto podendo atrasar entregas se não gerenciado adequadamente.

A verbosidade do código aumenta devido a boilerplate necessário. Interfaces de repositório duplicam assinaturas de métodos. DTOs duplicam estrutura de dados. Mappers traduzem entre entidades e models. Essa verbosidade aumenta linhas de código em aproximadamente 30% comparado a MVC tradicional, embora melhore clareza e manutenibilidade.

O risco de over-engineering existe especialmente para features simples. Operações CRUD triviais requerem mesma estrutura completa que operações complexas. Para MVPs e protótipos descartáveis, Clean Architecture pode ser excessivo retardando time-to-market. Esse risco é mitigado no contexto acadêmico onde demonstrar conhecimento arquitetural é requisito explícito.

A performance possui impacto negligenciável mas mensurável. Camadas adicionais de abstração introduzem overhead mínimo em chamadas de método. Tradução entre entidades e models adiciona processamento. Em PHP interpretado esse overhead é negligenciável (microsegundos), mas em sistemas de altíssima performance pode ser consideração relevante.

## Notas de Implementação

A implementação completa da Clean Architecture reside no repositório soat-fase3-application hospedado em GitHub sob organização wllsistemas. O repositório contém aplicação Laravel 12 completa em /backend, manifests Kubernetes em /k8s para deploy, Dockerfiles em /build para construção de imagens PHP e Nginx, e testes em /tests.

O sistema utiliza PHP 8.4-FPM-Alpine como runtime executando em container Docker. A imagem Docker é construída via Dockerfile localizado em build/backend/Dockerfile estendendo imagem oficial php:8.4-fpm-alpine. Extensões PHP instaladas incluem pdo_pgsql para PostgreSQL, bcmath para cálculos precisos, e ddtrace para Datadog APM. Composer instala dependências incluindo Laravel 12, firebase/php-jwt para autenticação, e PHPUnit para testes. Script startup.sh executa migrations e seeders automaticamente na inicialização do container.

A aplicação é servida via Nginx como reverse proxy configurado em build/backend/Dockerfile-nginx. Nginx recebe requisições HTTP na porta 80, roteia requisições PHP via FastCGI para PHP-FPM na porta 9000, e serve arquivos estáticos diretamente. Configuração Nginx em build/server/nginx.conf implementa front controller pattern do Laravel roteando todas as requisições para public/index.php.

Laravel Service Container gerencia injeção de dependências através de bindings registrados em app/Providers/AppServiceProvider.php vinculando interfaces a implementações concretas. Por exemplo, ClienteRepositorioInterface é ligado a ClienteRepositorio permitindo que Use Cases recebam implementação correta automaticamente via injeção de construtor. Bindings são registrados para todas as seis entidades principais (Cliente, Veiculo, Usuario, Servico, Material, Ordem).

Rotas do Laravel são definidas em arquivos separados por domínio em backend/routes/ incluindo api.php (rotas principais), cliente.php, veiculo.php, usuario.php, servico.php, material.php e ordem.php. As rotas apontam diretamente para Controllers da Clean Architecture em App\Infrastructure\Controller. Por exemplo, Route::post('/clientes', [Cliente::class, 'store']) invoca método store do controller Cliente. Middlewares JsonWebTokenMiddleware e DocumentoObrigatorioMiddleware são aplicados via groups protegendo endpoints sensíveis. Endpoints públicos incluem /api/ping para health check e endpoints de aprovação/reprovação de ordem.

Laravel Migrations permanecem em estrutura padrão database/migrations/ gerenciando schema do banco PostgreSQL. Migrations definem tabelas incluindo clientes, veiculos, usuarios, servicos, materiais e ordens com UUID como chave primária, timestamps created_at e updated_at, soft deletes via deleted_at (deletado_em), e constraints de integridade referencial. Seeders residem em database/seeders/ populando dados iniciais incluindo usuário padrão com email soat@example.com e senha padrao para autenticação.

Eloquent Models residem em app/Models/ como camada mais externa. Models definem tabela via propriedade $table, chave primária via $primaryKey (uuid) com $keyType string e $incrementing false, casting de atributos via $casts incluindo UUID para uuid, e relacionamentos via métodos hasMany, belongsTo, etc. Models não contêm lógica de negócio servindo exclusivamente como mapeamento objeto-relacional acessado apenas por repositórios em Infrastructure/Repositories/.

Middlewares customizados residem em app/Http/Middleware/ implementando aspectos transversais. JsonWebTokenMiddleware valida tokens JWT extraindo token do header Authorization Bearer, verificando assinatura via firebase/php-jwt usando chave secreta de ambiente JWT_SECRET, validando expiração, e injetando dados do usuário autenticado no request. DocumentoObrigatorioMiddleware valida presença de documento (CPF) em payload de requisições específicas garantindo conformidade com regras de negócio.

BusinessEventLogger reside em app/Infrastructure/Service/ como trait aplicável a controllers para logging estruturado de eventos de negócio. O logger formata eventos como JSON contendo timestamp ISO8601, nivel (info/warning/error), mensagem descritiva, contexto com dados relevantes, trace_id para correlação Datadog, e metadados adicionais. Logs são enviados para Datadog via ddtrace permitindo correlação entre traces APM e logs.

Testes são organizados em tests/Unit/ para testes unitários de entidades e Use Cases isolados sem banco ou HTTP, e tests/Feature/ para testes de integração de repositórios com PostgreSQL real e controllers com HTTP simulado. PHPUnit é configurado via phpunit.xml com bootstrap de Laravel, configuração de banco de teste em memória via SQLite ou PostgreSQL dedicado, e cobertura de código habilitada. Relatórios de cobertura são gerados via PHPUnit --coverage em formato HTML em backend/var/coverage/index.html e texto compacto em backend/var/coverage.txt. Cobertura atual atinge aproximadamente 85% combinando testes unitários e de integração.

Deployment em Kubernetes utiliza manifests YAML em k8s/ incluindo namespace lab-soat, configmaps e secrets, PersistentVolumeClaim para PostgreSQL, Deployments para PHP e Nginx, Services ClusterIP internos e NodePort externo, e HorizontalPodAutoscaler para Nginx escalando de 1 a 10 pods baseado em CPU 10% e memória 10Mi. Datadog Agent é deployado via DaemonSet com RBAC configurado para coletar métricas de Kubernetes API, logs de containers, e traces APM.

CI/CD é implementado via GitHub Actions com dois workflows principais. Workflow ci.yaml triggered em push para branch main executa testes via php artisan test --coverage, constrói imagens Docker para PHP e Nginx via docker build, faz push para Docker Hub sob namespace wllsistemas com tags versionadas, e envia notificação via email em sucesso ou falha. Workflow cd.yaml triggered manualmente ou automaticamente após CI bem-sucedido valida sucesso do CI, aplica manifests Kubernetes via kubectl apply -f k8s/, verifica saúde dos pods via readiness probes, e envia notificação via email. Branch main possui proteção exigindo pull request e aprovação obrigatória antes de merge.

## Revisões

- **20/10/2024**: Decisão inicial (Aceita)
- **25/10/2024**: Implementação completa de Cliente, Veículo, Usuário
- **10/11/2024**: Implementação de Ordem, Material, Servico
- **08/01/2026**: Revisão para documentação Fase 3 com formato ADR+RFC rigoroso

## Referências

- Clean Architecture by Robert C. Martin - https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html
- Laravel Best Practices - Clean Architecture - https://github.com/alexeymezenin/laravel-best-practices
- SOLID Principles in PHP - https://www.php.net/manual/en/language.oop5.patterns.php
- Object Calisthenics - https://williamdurand.fr/2013/06/03/object-calisthenics/
- The Clean Code Blog - https://blog.cleancoder.com/
- Domain-Driven Design by Eric Evans - https://www.domainlanguage.com/ddd/

## Palavras-Chave

Clean Architecture, Laravel, SOLID, Repository Pattern, Use Case, Domain-Driven, Testability, Separation of Concerns, Hexagonal Architecture, Architecture Decision, ADR, RFC, Dependency Inversion, Object Calisthenics
