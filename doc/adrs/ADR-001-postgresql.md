# ADR-001: Adoção do PostgreSQL como SGBD Principal

**Data:** 08/01/2026
**Status:** Aceita

## Contexto

O sistema Oficina SOAT é uma aplicação de gerenciamento de oficina mecânica que manipula entidades fortemente relacionais como clientes, veículos, ordens de serviço, materiais e serviços. A escolha do Sistema Gerenciador de Banco de Dados impacta diretamente aspectos críticos como performance, escalabilidade, integridade transacional, manutenibilidade e custo operacional de longo prazo.

O sistema apresenta requisitos específicos que influenciam a escolha do SGBD. A integridade de dados é fundamental devido aos relacionamentos complexos entre clientes e seus veículos, ordens de serviço vinculadas a múltiplos materiais e serviços, e a necessidade de rastreabilidade completa de todas as operações. A natureza transacional do domínio exige garantias ACID rigorosas, especialmente ao criar ordens de serviço que envolvem múltiplos recursos simultaneamente. A escalabilidade é um requisito de longo prazo, considerando que o sistema deve suportar o crescimento de múltiplas unidades da oficina. Por fim, a compatibilidade com o framework Laravel e a capacidade de armazenar dados semiestruturados em JSON para logs e configurações são considerações técnicas relevantes.

Do ponto de vista organizacional, o projeto é de natureza acadêmica no contexto do programa de pós-graduação FIAP em Arquitetura de Software, o que implica restrições orçamentárias e a preferência por soluções open-source. A equipe possui conhecimento sólido em SQL e princípios de modelagem relacional. A arquitetura do sistema segue Clean Architecture com Repository Pattern, o que abstrai detalhes específicos do banco de dados e permite flexibilidade na escolha tecnológica.

### Proposta de Discussão

Esta seção documenta a análise técnica realizada para fundamentar a escolha do SGBD, considerando alternativas viáveis no mercado e seus respectivos trade-offs.

**Alternativa 1: PostgreSQL 17.5**

PostgreSQL é um SGBD relacional open-source conhecido por sua robustez, extensibilidade e conformidade com padrões SQL. A versão 17.5 oferece recursos avançados como UUID nativo utilizado como chave primária em todas as entidades do domínio, tipo de dados JSONB para armazenar metadados e configurações sem alterar o schema, full-text search para futuros requisitos de busca de ordens de serviço, e extensões como PostGIS para geolocalização de unidades.

A performance do PostgreSQL é otimizada através de MVCC (Multi-Version Concurrency Control) onde leituras não bloqueiam escritas, query optimizer avançado que melhora a execução de joins complexos, múltiplos tipos de índices (B-tree, Hash, GIN, GiST) para otimizações específicas, e WAL (Write-Ahead Logging) garantindo durabilidade e recuperação de falhas. A escalabilidade é suportada tanto verticalmente para grandes volumes de dados quanto horizontalmente através de replicação nativa e particionamento de tabelas.

A licença PostgreSQL é permissiva e open-source sem restrições comerciais. A comunidade é extremamente ativa com 49% de taxa de adoção no Stack Overflow Survey 2024, sendo líder desde 2019. A integração com a stack tecnológica é de primeira classe no Laravel 12, possui imagem oficial Docker atualizada, operators disponíveis para Kubernetes, e providers Terraform para implantação em AWS RDS, Aurora ou autogerenciado.

**Alternativa 2: MySQL 8.0**

MySQL é o SGBD relacional open-source mais popular da indústria, conhecido pela simplicidade e performance em operações de leitura. Apresenta maior familiaridade na indústria, performance superior em leituras simples e índices otimizados, e possui MariaDB como alternativa compatível. No entanto, oferece extensões limitadas comparadas ao PostgreSQL, suporte JSON inferior (tipo JSON sem otimização comparado ao JSONB), e licença dual (GPL e comercial) que pode gerar confusão em contextos empresariais. A principal limitação é a ausência de recursos avançados que podem ser necessários no longo prazo, como suporte robusto a tipos de dados complexos e extensões especializadas.

**Alternativa 3: SQL Server**

Microsoft SQL Server é um SGBD relacional corporativo com ferramentas robustas e integração nativa com o ecossistema .NET. Oferece ferramentas de gestão avançadas como SQL Server Management Studio (SSMS) e integração profunda com Azure. Contudo, apresenta licenciamento custoso que inviabiliza projetos acadêmicos ou startups, dependência de infraestrutura Windows ou Azure que limita flexibilidade, e menor adequação para ambientes Linux e Kubernetes. O custo e a dependência de ecossistema proprietário são fatores eliminatórios para o contexto do projeto.

**Alternativa 4: NoSQL (MongoDB, DynamoDB)**

Bancos de dados NoSQL oferecem escalabilidade horizontal nativa e flexibilidade de schema. MongoDB oferece suporte a documentos JSON e DynamoDB fornece latência previsível com escalabilidade automática. Entretanto, relacionamentos complexos são desafiadores de implementar e manter, transações ACID são limitadas ou recentes (MongoDB 4.0+), e a natureza do domínio da oficina é fundamentalmente relacional com múltiplos relacionamentos entre cliente, veículo, ordem, materiais e serviços. A impedância entre o modelo de dados relacional do domínio e o paradigma orientado a documentos torna essa alternativa inadequada.

**Análise Comparativa**

PostgreSQL se destaca pela combinação de conformidade com padrões SQL, recursos avançados necessários ao longo prazo, licença permissiva, comunidade ativa, e excelente integração com a stack tecnológica escolhida (Laravel, Docker, Kubernetes, AWS). MySQL seria uma escolha aceitável para casos de uso simples, mas não oferece os recursos avançados que podem ser necessários no futuro. SQL Server é inviável devido ao custo e dependência de ecossistema proprietário. NoSQL é inadequado para um domínio fundamentalmente relacional.

## Decisão

A equipe decidiu adotar PostgreSQL 17.5 como Sistema Gerenciador de Banco de Dados principal do projeto Oficina SOAT. Essa decisão se baseia na análise comparativa de alternativas considerando requisitos funcionais, não-funcionais, restrições organizacionais e visão de longo prazo do sistema.

PostgreSQL atende todos os requisitos críticos do sistema. As garantias ACID são essenciais para operações transacionais envolvendo ordens de serviço com múltiplos materiais e serviços, e o PostgreSQL implementa conformidade rigorosa com essas propriedades. O suporte nativo a UUID permite utilizar identificadores globalmente únicos como chaves primárias em todas as entidades do domínio, eliminando colisões e facilitando eventual distribuição do sistema. O tipo de dados JSONB oferece flexibilidade para armazenar metadados, configurações e logs estruturados sem necessidade de alterações no schema, alinhando-se perfeitamente com o BusinessEventLogger implementado no sistema.

A performance do PostgreSQL é superior em cenários de workload misto com leituras e escritas concorrentes, exatamente o padrão esperado em uma oficina mecânica onde ordens são criadas, materiais adicionados, serviços atualizados e relatórios consultados simultaneamente. O MVCC garante que leituras nunca bloqueiam escritas, maximizando concorrência. O query optimizer avançado otimiza joins complexos entre as múltiplas tabelas do domínio.

A escalabilidade futura está assegurada tanto verticalmente quanto horizontalmente. O PostgreSQL suporta volumes de dados na escala de terabytes com performance adequada. A replicação nativa por streaming permite criar réplicas de leitura para distribuir carga. O particionamento de tabelas permite dividir dados históricos de ordens de serviço por períodos de tempo. O PgBouncer oferece connection pooling eficiente para alta concorrência.

A extensibilidade do PostgreSQL permite adicionar funcionalidades avançadas conforme o sistema evolui. A extensão PostGIS possibilita implementar geolocalização de unidades e otimização de rotas. O full-text search nativo permite implementar busca avançada em ordens de serviço, materiais e serviços. Extensões de criptografia como pgcrypto podem proteger dados sensíveis. Essa capacidade de extensão sem migração de SGBD é um diferencial estratégico.

A integração com a stack tecnológica é de primeira classe. Laravel 12 oferece suporte nativo completo ao PostgreSQL com migrations, query builder e Eloquent ORM otimizados. A imagem oficial Docker postgres:17.5 é atualizada e confiável. Operators Kubernetes como Zalando Postgres e Crunchy Data permitem orquestração avançada. Providers Terraform para AWS RDS PostgreSQL, Aurora PostgreSQL e instâncias autogerenciadas viabilizam infraestrutura como código.

A licença open-source permissiva elimina custos de licenciamento e restrições comerciais, alinhando-se com as restrições orçamentárias do projeto acadêmico. A comunidade PostgreSQL é extremamente ativa com ampla adoção na indústria (49% no Stack Overflow Survey 2024), garantindo abundância de recursos de aprendizado, bibliotecas, ferramentas e suporte comunitário.

A compatibilidade futura com serviços gerenciados na nuvem oferece flexibilidade na evolução da infraestrutura. AWS RDS PostgreSQL oferece backup automatizado, multi-AZ para alta disponibilidade, e monitoramento integrado. AWS Aurora PostgreSQL oferece compatibilidade com escalabilidade serverless. Essa compatibilidade permite migração gradual de uma instância autogerenciada em Kubernetes para um serviço totalmente gerenciado conforme o sistema amadurece.

## Consequências

### Positivas

A adoção do PostgreSQL garante robustez através de conformidade rigorosa com propriedades ACID, assegurando integridade transacional em operações críticas de ordens de serviço envolvendo múltiplos materiais e serviços simultaneamente. A durabilidade dos dados é garantida por WAL (Write-Ahead Logging) com recuperação automática de falhas.

A escalabilidade é suportada tanto verticalmente, onde o PostgreSQL gerencia eficientemente volumes de dados na escala de terabytes, quanto horizontalmente através de replicação nativa por streaming e particionamento de tabelas. Connection pooling via PgBouncer permite gerenciar alta concorrência de conexões.

A extensibilidade permite implementar funcionalidades avançadas sem migração de SGBD. PostGIS habilita geolocalização de unidades e otimização de rotas. Full-text search nativo permite busca avançada em ordens de serviço. JSONB oferece flexibilidade para armazenar logs estruturados através do BusinessEventLogger sem alterações no schema.

A performance é otimizada através de MVCC onde leituras nunca bloqueiam escritas, query optimizer avançado que otimiza joins complexos entre múltiplas tabelas do domínio, e diversos tipos de índices (B-tree, Hash, GIN, GiST) permitindo otimizações específicas por caso de uso.

O custo operacional é minimizado pela licença open-source permissiva sem restrições comerciais, eliminando custos de licenciamento. A imagem Docker oficial e operators Kubernetes disponíveis reduzem complexidade de deployment.

A comunidade ativa com 49% de adoção no Stack Overflow Survey 2024 garante abundância de recursos de aprendizado, bibliotecas, ferramentas e suporte comunitário. A documentação oficial é extensa e de alta qualidade.

A integração com a stack tecnológica é de primeira classe. Laravel 12 oferece suporte nativo completo com migrations, query builder e Eloquent ORM otimizados. Providers Terraform para AWS RDS, Aurora e autogerenciado viabilizam infraestrutura como código.

### Negativas

A curva de aprendizado para recursos avançados do PostgreSQL é ligeiramente maior comparada ao MySQL, especialmente para features como JSONB, full-text search e extensões especializadas. Esse impacto é mitigado pelo conhecimento sólido da equipe em SQL e pela abundância de documentação e recursos de aprendizado disponíveis.

A configuração inicial e tuning de performance requerem expertise específica em parâmetros como shared_buffers, work_mem, effective_cache_size e WAL configuration. Esse impacto é mitigado pelo fato de que as configurações padrão do PostgreSQL são adequadas para ambientes de desenvolvimento e MVP, permitindo otimização gradual conforme o sistema amadurece e padrões de uso são observados.

A estratégia de backup requer planejamento robusto envolvendo WAL archiving para point-in-time recovery e pg_dump para backups completos. A ausência de backup automatizado em implantações autogerenciadas aumenta a responsabilidade operacional. Esse impacto pode ser mitigado no futuro através de migração para AWS RDS PostgreSQL que oferece backup automatizado com retenção configurável de 7 a 35 dias.

O consumo de recursos pode ser maior comparado a SGBDs mais leves dependendo da configuração. A imagem Docker oficial postgres:17.5 possui aproximadamente 400MB, embora a variante Alpine reduza para aproximadamente 230MB. O consumo de memória é configurável via shared_buffers e work_mem, permitindo ajuste conforme recursos disponíveis.

A complexidade operacional de gerenciar PostgreSQL em Kubernetes com alta disponibilidade e replicação é maior comparada a utilizar um serviço gerenciado como AWS RDS. A implementação atual no repositório soat-fase3-database possui single replica sem mecanismo de alta disponibilidade, tornando o banco de dados um ponto único de falha onde indisponibilidade do pod causa downtime até Kubernetes reschedular. Esse impacto é aceito no contexto acadêmico do projeto, mas deve ser reavaliado em eventual transição para produção real através de migração para RDS Multi-AZ ou implementação de streaming replication com failover automático.

O gerenciamento de credenciais na implementação atual armazena POSTGRES_USER e POSTGRES_PASSWORD diretamente no arquivo secret-postgres.tf versionado no repositório Git, criando security concern significativo onde credenciais sensíveis ficam expostas no histórico de commits. Esse impacto deve ser mitigado através de migração para AWS Secrets Manager com rotação automática de credenciais ou HashiCorp Vault, e imediata rotação das credenciais atuais caso o repositório seja público.

A ausência de backup automatizado na implementação atual aumenta significativamente o risco de perda de dados permanente em caso de corrupção de volume EBS, erro humano (DROP TABLE acidental), ou falha catastrófica do cluster. Esse impacto deve ser mitigado através de implementação de CronJob Kubernetes executando pg_dump periodicamente com upload para S3, configuração de WAL archiving para point-in-time recovery, ou migração para AWS RDS que oferece backup automatizado com retenção configurável.

## Notas de Implementação

O sistema utiliza PostgreSQL 17.5 lançada em 2024. As principais features utilizadas incluem UUID v4 como chave primária em todas as entidades, JSONB para armazenamento de metadados e logs estruturados, índices B-tree e GIN para otimização de queries, e constraints de integridade referencial (FK, CHECK, UNIQUE).

A configuração para ambiente local via Docker Compose utiliza a imagem oficial postgres:17.5 com banco de dados oficina_soat, porta padrão 5432 exposta, e volume persistente pgdata montado em /var/lib/postgresql/data para durabilidade dos dados entre restarts.

A configuração para ambiente de produção em Kubernetes utiliza provisionamento via Terraform no repositório dedicado soat-fase3-database. A infraestrutura é definida através de arquivos .tf incluindo pod-postgres.tf (Deployment com 1 réplica), pvc-postgres.tf (PersistentVolumeClaim de 1GB), storage.tf (StorageClass EBS gp3 com encryption), svc-postgres.tf (Service ClusterIP para comunicação interna), e secret-postgres.tf (credenciais do banco). O backend Terraform utiliza S3 bucket s3-fiap-soat-fase3 com state file em database/terraform.tfstate na região us-east-2. CI/CD via GitHub Actions permite provisionamento via workflow_dispatch com opções apply, destroy ou plan_destroy.

O Deployment PostgreSQL utiliza imagem oficial postgres:17.5, PersistentVolumeClaim de 1GB provisionado dinamicamente via EBS CSI Driver com StorageClass gp3 encrypted garantindo encryption at rest, variáveis de ambiente POSTGRES_DB, POSTGRES_USER e POSTGRES_PASSWORD definidas via Secret, volume montado em /var/lib/postgresql/data/pgdata para persistência, e readinessProbe em porta 5432 verificando disponibilidade. Service ClusterIP expõe porta 5432 internamente no cluster com nome postgres permitindo resolução DNS de outros pods.

Limitações da implementação atual incluem credenciais armazenadas diretamente em secret-postgres.tf como security concern que deve ser migrado para AWS Secrets Manager ou HashiCorp Vault, ausência de backup automatizado aumentando risco de perda de dados que deve ser implementado via pg_dump scheduled job ou migração para RDS, single replica sem alta disponibilidade onde falha do pod causa indisponibilidade temporária até Kubernetes reschedular, e ausência de read replicas limitando escalabilidade de leitura.

A estratégia de migração futura recomendada é transicionar para AWS RDS PostgreSQL quando o sistema evoluir para produção real. O RDS oferece backup automatizado com retenção configurável de 7 a 35 dias, Multi-AZ para alta disponibilidade com failover automático em menos de 60 segundos, read replicas para escalabilidade de leitura, secrets gerenciados via AWS Secrets Manager com rotação automática, e monitoramento integrado com CloudWatch. Essa migração é facilitada pela compatibilidade total entre PostgreSQL autogerenciado e RDS PostgreSQL, exigindo apenas ajuste de connection strings e migração de dados via pg_dump/pg_restore.

## Revisões

- **15/11/2024**: Decisão inicial (Aceita)
- **01/12/2024**: Deployment em produção (EKS)
- **08/01/2026**: Revisão para documentação Fase 3 com formato ADR+RFC rigoroso

## Referências

- PostgreSQL vs MySQL: Choosing the Best Database (2025) - https://www.bytebase.com/blog/postgres-vs-mysql/
- Stack Overflow Survey 2024 - PostgreSQL 49% adoption - https://survey.stackoverflow.co/2024/technology#1-databases
- Postgres: Developers' Favorite Database 2024 - https://www.enterprisedb.com/blog/postgres-developers-favorite-database-2024
- Laravel 12 Database Documentation - https://laravel.com/docs/12.x/database
- PostgreSQL 17 Release Notes - https://www.postgresql.org/docs/17/release-17.html

## Palavras-Chave

PostgreSQL, Database, SGBD, Relational, ACID, Scalability, Open Source, Laravel, Architecture Decision, Data Persistence, ADR, RFC
