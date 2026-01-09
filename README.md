# SOAT FASE 03 - Application

_Tech challenge_ da pós tech em arquitetura de software - FIAP Fase 3

# Alunos

- Felipe
    - RM: `365154`
    - discord: `felipeoli7eira`
    - LinkedIn: [@felipeoli7eira](https://www.linkedin.com/in/felipeoli7eira)
- Nicolas
    - RM: `365746`
    - discord: `nic_hcm`
    - LinkedIn: [@Nicolas Martins](https://www.linkedin.com/in/nicolas-henrique/)
- William
    - RM: `365973`
    - discord: `wllsistemas`
    - LinkedIn: [@William Francisco Leite](https://www.linkedin.com/in/william-francisco-leite-9b3ba9269/?utm_source=share&utm_campaign=share_via&utm_content=profile&utm_medium=android_app)

# Material
- [Vídeo de apresentação](https://www.youtube.com/watch?v=POC_FaWt39E)
- [Documento de entrega - PDF](https://drive.google.com/file/d/1zYUQeFIhgjaYiCnvH5A9drwDD8-x_zzp/view?usp=sharing)

# Sobre o projeto
Este projeto foi desenvolvido com [Laravel](https://laravel.com), [nginx](https://nginx.org) e [postgresql](https://www.postgresql.org) e por volta dessas 3 tecnologias, está o [docker](https://www.docker.com)/[docker compose](https://docs.docker.com/compose) e toda uma arquitetura com kubernetes que entraremos em mais detalhes em seções posteriores.


O Laravel foi escolhido por ser um dos principais (se não o principal) framework PHP atualmente, e por suas facilidades para criar APIs **RESTful** de verdade, com o mínimo de esforço. Com ele conseguimos alcançar a [excelência do modelo de maturidade REST](https://mundoapi.com.br/destaques/alcancando-a-excelencia-do-rest-com-um-modelo-de-maturidade-eficiente/). Além disso, são mais de 10 anos no campo de batalha, comprovando sua eficiência e segurança, além de uma grande comunidade e um ecossistema que não para de crescer.


O **Nginx** foi escolhido como servidor web por sua [arquitetura assíncrona orientada a eventos](https://nginx.org/en/docs/http/ngx_http_core_module.html), que permite lidar com milhares de conexões simultâneas consumindo poucos recursos do sistema.
Diferente do Apache em seus modos mais tradicionais (como o MPM prefork, que cria um processo por conexão), o Nginx adota um modelo de worker processes, onde cada processo é capaz de gerenciar milhares de conexões de forma não bloqueante, por meio de I/O assíncrono. Isso o torna altamente eficiente em ambientes com alta concorrência. Embora o Apache também tenha evoluído e ofereça um modo event mais moderno, o Nginx ainda é amplamente preferido em contextos de alta performance.
Além disso, sua configuração tende a ser mais simples e direta para casos como servir arquivos estáticos, atuar como _reverse proxy_ para aplicações PHP-FPM, fazer load balancing ou cache de conteúdo.
Essa eficiência e flexibilidade explicam sua ampla adoção por [grandes empresas como Netflix, Airbnb e Dropbox](https://www.nginx.com/case-studies/), que o utilizam para escalar aplicações em ambientes de alta demanda.


O **PostgreSQL** é uma escolha de longo prazo segura, [preparada para o futuro](https://www.enterprisedb.com/blog/postgres-developers-favorite-database-2024?lang=en). O que o destaca é a [maneira como ele lida com tarefas básicas e complexas](https://www.nucamp.co/blog/coding-bootcamp-backend-with-python-2025-postgresql-vs-mysql-in-2025-choosing-the-best-database-for-your-backend) - desde armazenamento simples de dados até recursos avançados, como tratamento de dados geoespaciais e suporte nativo a JSON. Postgres [virou líder em 6 anos](https://survey.stackoverflow.co/2024/technology#1-databases), saindo de 33% para 49% de uso vs MySQL que caiu de 59% para ~40%. Nós o escolhemos por sua [escalabilidade, extensibilidade, licença e outros](https://www.bytebase.com/blog/postgres-vs-mysql/).

# Documentação ADR, RFC, Arquitetura
[Link da Documentação: ](doc/README.md)  

## 🚀 Pipeline GitHub Actions

#### 1. Aprovação de um PR para merge com a `main`
No branch `main` são efetuados merges mediante aprovação dos PRs.

#### 2. Execução da Pipeline CI
Ao executar o merge, é disparada a pipeline `application.yaml` que executa:
- Provisionamento do POD com imagem Nginx
- Provisionamento do POD com imagem PHP-FPM
- Provisionamento do Serviço ClusterIP para PHP-FPM
- Provisionamento do Serviço LoadBalancer para o Nginx
- Persiste o estado do terraform no bucket S3
- Imagem PHP-FPM possui instalado o módulo **ddtrace** para monitoramendo **Datadog**

## 🚀 State Terraform no Bucket S3
Para persistência do estado dos recursos provisionados via terraform, é utilizado um repositório Bucket S3 na AWS, onde os arquivos de persistência foram separados por repositório (infra, database e application).

## 🚀 Deploy da Aplicação

- Foram escritos 2 arquivos Dockerfile que estão na pasta **./build/backend**
    1. **nginx**
    2. **php:8.4-fpm-alpine3.22**

> [!NOTE]
> O container PostgreSQL é criado a partir de uma imagem no Docker Hub **postgres:17.5**.

> [!NOTE]
> O banco de dados da aplicação é criado após o container do **PHP** ser executado, as rotinas de **migrations** e **seeders** são executadas via comando `artisan` do laravel durante a inicialização do container, através do script **/build/backend/startup.sh**.


#### Build Imagem Docker
- **Nginx**: executar comando à partir da raiz do projeto
```bash
  docker build -t wllsistemas/nginx_lab_soat:fase3-v3.0 -f build/backend/Dockerfile-nginx .
```
- **PHP + Código Fonte**: executar comando à partir da raiz do projeto
```bash
  docker build -t wllsistemas/php_lab_soat:fase3-v3.0 -f build/backend/Dockerfile .
```

# API Documentation

O [postman](https://www.postman.com) foi usado para criar a documentação da API. O workspace com a collection está [disponível aqui](https://www.postman.com/foliveirateam/workspace/oficina-soat). Você notará que cada recurso está organizado em pastas:

- pasta `usuario`: CRUD de usuários do sistema (mecânicos, atendentes, etc...)
- pasta `servico`: CRUD de serviços da oficina, como troca de óleo, revisões e etc...
- pasta `material: peça / insumo`: CRUD de materiais (peças e insumos) usados nas ordens de serviço, como pastilha de freio, filtros de ar e óleo, etc...
- pasta `cliente`: CRUD de clientes da oficina
- pasta `veiculo`: CRUD de veículos dos clientes
- pasta `ordem`: CRUD da ordem de serviço
- pasta `auth`: Autenticação de usuários do sistema.

No momento da inicialização dos containers mapeados no [docker-compose.yaml](./docker-compose.yml), a base de dados é populada com um usuário de teste, como descrito no arquivo [DatabaseSeeder.php](./backend/database/seeders/DatabaseSeeder.php). Você pode usar os dados desse usuário para obter um token JWT e testar todo os fluxos da API. Os dados desse usuário são os seguintes:

- Usuário: `soat@example.com`
- Senha: `padrao`
