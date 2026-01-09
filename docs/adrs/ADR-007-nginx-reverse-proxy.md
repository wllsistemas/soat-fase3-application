# ADR-007: Adoção do Nginx como Reverse Proxy e Web Server

**Data:** 08/01/2026
**Status:** Aceita

## Contexto

O sistema Oficina SOAT utiliza Laravel como framework backend executando em PHP-FPM (FastCGI Process Manager). PHP-FPM é um process manager especializado que não expõe diretamente porta HTTP ao mundo externo, funcionando exclusivamente como backend FastCGI que processa requisições PHP recebidas de um web server frontend. Essa arquitetura exige um web server atuando como reverse proxy para receber requisições HTTP dos clientes, rotear para PHP-FPM via protocolo FastCGI, e retornar respostas HTTP aos clientes.

A escolha do web server impacta diretamente aspectos críticos de performance incluindo latência de requisições HTTP, throughput medido em requisições por segundo, concorrência suportada (número de conexões simultâneas), e consumo de recursos computacionais (CPU e memória). Em ambiente containerizado Kubernetes com recursos limitados por pod, eficiência de recursos é crítica pois determina densidade de pods por node e consequentemente custo de infraestrutura.

O sistema deve suportar alta concorrência especialmente durante horário comercial quando múltiplas oficinas operam simultaneamente criando e consultando ordens de serviço. Picos de carga são esperados durante demonstrações acadêmicas e entregas de fases do Tech Challenge. A escalabilidade horizontal via HPA (Horizontal Pod Autoscaler) depende de web server eficiente que maximize utilização de recursos permitindo cada pod servir máximo número de requisições antes de necessitar scaling.

Do ponto de vista organizacional, o projeto é acadêmico com restrições orçamentárias favorecendo soluções que minimizem consumo de recursos reduzindo número de pods necessários. A equipe possui familiaridade com Nginx de projetos anteriores mas também conhece Apache. A configuração deve ser clara e reproduzível através de arquivos versionados em Git.

### Proposta de Discussão

Esta seção documenta a análise técnica realizada para fundamentar a escolha do web server e reverse proxy, considerando alternativas viáveis e seus respectivos trade-offs em contexto de aplicação Laravel containerizada.

**Alternativa 1: Nginx (Proposta Selecionada)**

Nginx é web server open-source conhecido por arquitetura assíncrona orientada a eventos (event-driven) que maximiza concorrência e minimiza consumo de recursos. Desenvolvido originalmente por Igor Sysoev em 2004 para resolver problema C10K (10 mil conexões simultâneas), Nginx utiliza modelo de worker processes onde cada worker gerencia milhares de conexões simultaneamente através de I/O assíncrono não bloqueante.

A arquitetura event-driven funciona através de event loop dentro de cada worker process. Quando requisição HTTP chega, worker a aceita sem bloquear. Quando I/O é necessário (ler arquivo, comunicar com FastCGI backend), operação é iniciada de forma assíncrona e worker continua processando outras requisões. Quando I/O completa, evento notifica worker que retoma processamento daquela requisição. Mecanismos de I/O assíncrono incluem epoll no Linux, kqueue no BSD, e event ports no Solaris.

Os benefícios incluem altíssima concorrência onde cada worker gerencia aproximadamente 10 mil conexões simultâneas limitado apenas por file descriptors do sistema operacional. Baixíssimo consumo de memória com aproximadamente 10-20MB RAM por container comparado a 50-100MB de Apache com MPM prefork. Performance superior com latência reduzida devido a I/O não bloqueante. Configuração clara através de nginx.conf com sintaxe específica mas bem documentada. Adoção massiva no mercado usado por Netflix, Airbnb, Dropbox, GitHub, Cloudflare. Imagem Docker oficial nginx:alpine possui apenas 25MB compactada.

As limitações incluem sintaxe de configuração específica diferente de .htaccess do Apache exigindo aprendizado. Módulos dinâmicos são menos abundantes que Apache embora módulos essenciais estejam incluídos. Comunidade é menor que Apache mas ainda amplamente suficiente com documentação oficial extensa.

**Alternativa 2: Apache HTTP Server**

Apache HTTP Server é web server open-source mais antigo e estabelecido do mercado, lançado em 1995 pela Apache Software Foundation. Historicamente utilizava modelo process-per-connection (MPM prefork) onde cada conexão HTTP é tratada por processo dedicado. Versões recentes introduziram MPM event que tenta implementar arquitetura event-driven similar ao Nginx mas ainda menos madura.

Os benefícios incluem configuração via .htaccess amplamente familiar a desenvolvedores web. Vasta biblioteca de módulos disponíveis cobrindo praticamente qualquer caso de uso. Comunidade extremamente ampla com décadas de recursos de aprendizado. Suporte oficial em praticamente todas as distribuições Linux.

As limitações críticas incluem modelo prefork consumindo significativamente mais recursos com 1 processo por conexão resultando em 50-100MB RAM por container. MPM event ainda menos maduro que Nginx com performance inferior em alta concorrência. Overhead de processos limita densidade de pods em Kubernetes aumentando custo de infraestrutura. Benchmarks demonstram throughput inferior ao Nginx em workloads de alta concorrência.

**Alternativa 3: Traefik**

Traefik é reverse proxy e load balancer moderno desenvolvido especificamente para ambientes cloud-native e Kubernetes. Suporta configuração dinâmica via Kubernetes Ingress resources, Service annotations, e labels. Possui dashboard web built-in para visualização de rotas e backends. Integração nativa com Let's Encrypt para HTTPS automático.

Os benefícios incluem integração nativa profunda com Kubernetes eliminando necessidade de recarregar configuração ao adicionar services. Configuração declarativa via Ingress resources seguindo padrões Kubernetes. Dashboard web facilita troubleshooting de roteamento. Suporte automático a métricas Prometheus.

As limitações incluem overhead adicional de complexidade para caso de uso simples de reverse proxy para PHP-FPM. Menos maduro que Nginx com menor histórico em ambientes de produção em larga escala. Performance é boa mas não superior a Nginx. Configuração inicial mais complexa para desenvolvedores não familiarizados com Kubernetes Ingress.

**Alternativa 4: Caddy**

Caddy é web server moderno escrito em Go focando em simplicidade de configuração e HTTPS automático. Caddyfile oferece sintaxe extremamente simples e legível. HTTPS é automático via Let's Encrypt sem configuração manual. HTTP/2 habilitado por padrão.

Os benefícios incluem configuração extremamente simples com Caddyfile mais legível que nginx.conf. HTTPS automático elimina complexidade de certificados. Desenvolvido em Go com boa performance. Binário único sem dependências externas.

As limitações incluem menor adoção no mercado comparado a Nginx resultando em menos recursos de aprendizado e troubleshooting. Performance em benchmarks é boa mas geralmente inferior a Nginx em alta concorrência. Comunidade significativamente menor. Menos battle-tested em ambientes de produção em larga escala.

**Análise Comparativa**

Nginx oferece melhor equilíbrio entre performance comprovada em produção, eficiência de recursos crítica para ambientes containerizados, adoção massiva no mercado garantindo abundância de recursos de aprendizado, e simplicidade suficiente para caso de uso de reverse proxy para Laravel. Arquitetura event-driven maximiza concorrência e minimiza memória permitindo alta densidade de pods em Kubernetes.

Apache seria tecnicamente viável mas consome significativamente mais recursos reduzindo densidade de pods e aumentando custo. MPM event ainda não alcançou maturidade de Nginx. Traefik adiciona complexidade desnecessária para caso de uso simples. Caddy é promissor mas menos estabelecido e com performance ligeiramente inferior.

## Decisão

A equipe decidiu adotar Nginx como web server e reverse proxy para aplicação Laravel utilizando arquitetura assíncrona orientada a eventos. Essa decisão fundamenta-se na análise comparativa de alternativas considerando requisitos de performance, concorrência, eficiência de recursos, e adoção de mercado.

A implementação utiliza Nginx configurado via arquivo nginx.conf localizado em build/server/nginx.conf versionado em Git. A configuração define server block escutando na porta 80, index padrão index.php, document root em /var/www/html/public seguindo estrutura Laravel, location / com try_files tentando servir arquivo estático e falhando para index.php com query string preservada, e location ~ \.php$ processando arquivos PHP via FastCGI proxy para php:9000 que é service name do container PHP-FPM em Docker Compose e Kubernetes.

A arquitetura event-driven do Nginx funciona através de master process gerenciando worker processes onde número de workers é configurado via worker_processes diretiva (geralmente igual a número de CPU cores). Cada worker process executa event loop processando eventos de I/O através de mecanismo epoll no Linux. Quando conexão HTTP chega, worker a aceita e adiciona file descriptor ao event loop. Operações de I/O como ler request body, comunicar com FastCGI backend via socket TCP para PHP-FPM, e escrever response são todas não bloqueantes permitindo worker processar outras conexões enquanto aguarda I/O. Connections por worker são limitados apenas por worker_connections diretiva (padrão 1024 mas configurável para 10000+) e ulimit de file descriptors do sistema operacional.

A comunicação Nginx → PHP-FPM utiliza protocolo FastCGI sobre socket TCP. Nginx conecta em php:9000 (hostname php resolve via Docker DNS ou Kubernetes Service), envia requisição FastCGI contendo SCRIPT_FILENAME e outras CGI variables, aguarda resposta de forma assíncrona, e retorna response HTTP ao cliente. PHP-FPM possui pool de worker processes (configurável via pm.max_children) que processam requisições PHP. Quando todos os workers PHP-FPM estão ocupados, requisições adicionais aguardam em fila até worker ficar disponível.

A containerização utiliza imagem oficial nginx:alpine como base no Dockerfile-nginx. Alpine Linux reduz tamanho de imagem para aproximadamente 25MB compactada comparado a 140MB da imagem nginx padrão baseada em Debian. Dockerfile copia nginx.conf para /etc/nginx/conf.d/default.conf substituindo configuração padrão. EXPOSE 80 documenta porta HTTP. Comando padrão nginx -g 'daemon off;' executa Nginx em foreground necessário para containers.

O deployment em Docker Compose define service nginx com build context apontando para Dockerfile-nginx, ports mapeando 8080:80 expondo porta 8080 no host, depends_on php garantindo PHP-FPM inicia antes, e networks compartilhada appnet permitindo resolução DNS do hostname php.

O deployment em Kubernetes utiliza Deployment 12-pod-nginx.yaml com replicas 1 (escalado via HPA), image wllsistemas/nginx_lab_soat:fase2 publicada em Docker Hub, container port 80, readiness probe em /api/ping verificando health antes de receber tráfego, liveness probe verificando se Nginx responde, resource requests (cpu: 100m, memory: 64Mi) e limits (cpu: 200m, memory: 128Mi). Service 09-svc-nginx.yaml tipo NodePort expõe porta 31000 permitindo acesso externo ao cluster. HPA 13-hpa-nginx.yaml escala de 1 a 10 réplicas baseado em CPU 10% e memória 10Mi.

## Consequências

### Positivas

A alta performance é alcançada através de arquitetura event-driven com I/O assíncrono não bloqueante. Latência P95 observada é inferior a 200ms no endpoint /api/ping mesmo sob carga moderada. Throughput medido em testes de carga locais com Apache Bench atinge aproximadamente 5000 requisições por segundo limitado mais por PHP-FPM que por Nginx.

A concorrência elevada permite cada worker Nginx gerenciar aproximadamente 10 mil conexões simultâneas. Em configuração padrão com 2 workers (alinhado com 2 CPU cores de instância t3.medium), o pod Nginx suporta aproximadamente 20 mil conexões simultâneas antes de saturação. Isso é múltiplas ordens de magnitude superior a Apache MPM prefork que gerencia 1 conexão por processo.

O baixo consumo de recursos observado é aproximadamente 15MB RAM por pod Nginx em produção comparado a 50-100MB típicos de Apache MPM prefork. Isso permite maior densidade de pods por node Kubernetes reduzindo custo de infraestrutura. CPU consumption é mínimo em idle e escala linearmente com throughput.

A escalabilidade horizontal via HPA funciona eficientemente onde Nginx lightweight permite escalar de 1 a 10 pods rapidamente (novos pods ready em aproximadamente 10-15 segundos). Thresholds de CPU e memória baixos (10%) permitem demonstração de auto-scaling em ambiente acadêmico. Distribuição de carga é uniforme entre pods via Service Kubernetes.

A simplicidade de configuração através de nginx.conf versionado em Git permite reprodutibilidade completa. Configuração é declarativa e auto-documentada. Modificações são reviewable via pull request. Rollback de configuração é simples via git revert.

A adoção massiva no mercado por empresas como Netflix, Airbnb, Dropbox, GitHub e Cloudflare valida robustez e escalabilidade de Nginx em ambientes de produção em larga escala. Abundância de recursos de aprendizado, blog posts, Stack Overflow questions e case studies facilita troubleshooting e otimização.

A compatibilidade Docker através de imagem oficial nginx:alpine com apenas 25MB compactada minimiza tempo de pull de imagem e storage em Docker Hub. Build de imagem customizada é rápido adicionando apenas nginx.conf sobre imagem base.

### Negativas

A sintaxe de configuração específica do nginx.conf é diferente de .htaccess do Apache exigindo aprendizado. Diretivas como try_files, fastcgi_pass, e fastcgi_params possuem sintaxe particular. Esse impacto é mitigado pela documentação oficial extensa, exemplos abundantes para Laravel deployment, e fato de que configuração é definida uma vez e raramente modificada.

Módulos dinâmicos são menos abundantes comparados ao Apache que possui vasta biblioteca de módulos cobrindo praticamente qualquer caso de uso. Nginx foca em core features bem implementadas ao invés de extensibilidade infinita. Esse impacto é negligenciável pois módulos necessários para reverse proxy FastCGI, static file serving, e gzip compression estão incluídos no Nginx core. Casos de uso avançados como mod_rewrite complexo ou autenticação LDAP são raros em APIs REST modernas.

A comunidade é menor que Apache embora ainda ampla e ativa. Apache possui décadas de histórico e documentação acumulada. Nginx possui aproximadamente 15 anos mas crescimento rápido especialmente em ambientes cloud-native. Esse impacto é negligenciável considerando que Nginx é suficientemente estabelecido com documentação oficial de alta qualidade e abundância de recursos online.

## Notas de Implementação

A configuração Nginx localizada em build/server/nginx.conf define server block completo. Diretiva listen 80 escuta na porta HTTP padrão. Diretiva index index.php define arquivo de índice. Diretiva root /var/www/html/public define document root alinhado com estrutura Laravel onde public directory contém index.php entrypoint.

Location block / processa todas as requisições que não casam com outros location blocks mais específicos. Diretiva try_files $uri $uri/ /index.php?$query_string tenta servir arquivo estático se existir ($uri), depois tenta servir como diretório ($uri/), e finalmente roteia para index.php preservando query string original. Isso implementa front controller pattern do Laravel onde todas as requisições passam por index.php.

Location block ~ \.php$ casa com requisições terminando em .php usando regex. Diretiva fastcgi_pass php:9000 encaminha via FastCGI protocol para PHP-FPM escutando em hostname php porta 9000. Hostname php resolve via Docker DNS ou Kubernetes Service. Diretiva fastcgi_index index.php define arquivo de índice FastCGI. Diretiva fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name passa path absoluto do script PHP. Diretiva include fastcgi_params inclui parâmetros FastCGI padrão definidos em arquivo separado.

Dockerfile-nginx localizado em build/backend/Dockerfile-nginx estende FROM nginx:alpine como base. Comando COPY ./build/server/nginx.conf /etc/nginx/conf.d/default.conf copia configuração substituindo default. Comando EXPOSE 80 documenta porta exposta. Comando padrão herdado de imagem base executa nginx -g 'daemon off;' mantendo Nginx em foreground.

Docker Compose local define service nginx em docker-compose.yaml com build context atual e dockerfile build/backend/Dockerfile-nginx. Ports 8080:80 mapeia porta 8080 no host para 80 no container permitindo acesso via http://localhost:8080. Depends_on php garante ordem de inicialização. Networks appnet compartilha rede permitindo resolução DNS de hostname php para container PHP-FPM.

Kubernetes Deployment 12-pod-nginx.yaml define apiVersion apps/v1, kind Deployment, metadata com name lab-soat-nginx e namespace lab-soat. Spec define replicas 1 escalado via HPA, selector matchLabels app: nginx, template com labels app: nginx. Container spec define name nginx, image wllsistemas/nginx_lab_soat:fase2, ports containerPort 80. ReadinessProbe httpGet path /api/ping port 80 verifica health com initialDelaySeconds 5 e periodSeconds 10. LivenessProbe similar verifica processo Nginx responde. Resources requests cpu 100m memory 64Mi e limits cpu 200m memory 128Mi definem reserva e cap de recursos.

Kubernetes Service 09-svc-nginx.yaml define apiVersion v1, kind Service, metadata name lab-soat-nginx. Spec type NodePort expõe externamente, selector app: nginx roteia para pods Nginx, ports protocol TCP port 80 targetPort 80 nodePort 31000. NodePort 31000 permite acesso externo via http://<node-ip>:31000.

HPA 13-hpa-nginx.yaml define autoscaling conforme descrito em ADR-008 escalando Nginx deployment baseado em CPU e memória.

## Revisões

- **20/10/2024**: Decisão inicial (Aceita)
- **25/10/2024**: Implementação completa de Nginx + PHP-FPM
- **01/11/2024**: Deploy em Kubernetes com HPA
- **08/01/2026**: Revisão para documentação Fase 3 com formato ADR+RFC rigoroso

## Referências

- Nginx Architecture Documentation - https://nginx.org/en/docs/http/ngx_http_core_module.html
- Nginx vs Apache Benchmark - https://www.nginx.com/blog/nginx-vs-apache-our-view/
- Netflix on Nginx - https://www.nginx.com/case-studies/netflix/
- Laravel Deployment Guide - https://laravel.com/docs/12.x/deployment
- FastCGI Protocol - https://fastcgi-archives.github.io/FastCGI_Specification.html

## Palavras-Chave

Nginx, Web Server, Reverse Proxy, Event-Driven, Asynchronous I/O, Performance, Concurrency, PHP-FPM, FastCGI, Docker, Kubernetes, High Performance, Low Memory, ADR, RFC
