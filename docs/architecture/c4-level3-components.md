# C4 Model - Nível 3: Diagrama de Componentes

**Sistema:** Oficina SOAT - Gestão de Ordens de Serviço
**Container:** Laravel Application (Backend API)
**Data:** 08/01/2025
**Versão:** 1.0

## Visão Geral

O diagrama de componentes mostra a estrutura interna da aplicação Laravel, seguindo **Clean Architecture** com separação clara de responsabilidades em camadas: Domain, Infrastructure e Http.

Este nível detalha como os componentes internos colaboram para implementar as funcionalidades de negócio.

## Arquitetura Clean Architecture

### Princípios Aplicados

**1. Dependency Rule (Regra de Dependência)**
- Dependências apontam sempre de fora para dentro
- Domain não conhece Infrastructure ou Http
- Infrastructure conhece Domain (via interfaces)
- Http conhece Infrastructure e Domain

**2. Separation of Concerns (Separação de Responsabilidades)**
- **Domain:** Regras de negócio puras (sem frameworks)
- **Infrastructure:** Implementações técnicas (Eloquent, APIs, etc.)
- **Http:** Camada de apresentação (Controllers, Middleware)

**3. Testability (Testabilidade)**
- Domain facilmente testável (sem dependências externas)
- Infrastructure testável via mocks
- Testes de integração via Http

## Estrutura de Camadas

```
┌──────────────────────────────────────────────────────────────┐
│                         CAMADA HTTP                          │
│  (Interface com mundo externo - Controllers, Middleware)     │
└────────────────┬─────────────────────────────────────────────┘
                 │ Dependency Flow ▼
┌────────────────▼─────────────────────────────────────────────┐
│                   CAMADA INFRASTRUCTURE                       │
│  (Implementações técnicas - Repositories, Gateways, etc.)    │
└────────────────┬─────────────────────────────────────────────┘
                 │ Dependency Flow ▼
┌────────────────▼─────────────────────────────────────────────┐
│                      CAMADA DOMAIN                            │
│  (Regras de negócio puras - Entities, Use Cases)             │
└──────────────────────────────────────────────────────────────┘
```

## Componentes por Camada

### CAMADA 1: Domain (Núcleo de Negócio)

#### 1.1 Domain/Entity
**Responsabilidade:** Representar entidades de negócio com regras internas

**Componentes:**
- **Cliente/Cliente.php**
  - CPF obrigatório e único
  - Validação de formato CPF
  - Relacionamento com Veículos

- **Veiculo/Veiculo.php**
  - Placa obrigatória e única
  - Relacionamento com Cliente (owner)
  - Validação de ano (1900-atual)

- **Ordem/Ordem.php**
  - Estados: CRIADA, AGUARDANDO_APROVACAO, APROVADA, REPROVADA, EM_EXECUCAO, FINALIZADA
  - Relacionamento com Cliente e Veículo
  - Cálculo de valor total (materiais + serviços)
  - Validação de transições de estado

- **Material/Material.php**
  - Nome, descrição, valor unitário
  - Validação de valor positivo

- **Servico/Servico.php**
  - Nome, descrição, valor unitário
  - Validação de valor positivo

- **Usuario/Usuario.php**
  - Email único
  - Senha hash (bcrypt)
  - Tipos: ATENDENTE, MECANICO, GESTOR

**Interfaces (Contracts):**
- **Cliente/RepositorioInterface.php**
- **Veiculo/RepositorioInterface.php**
- **Ordem/RepositorioInterface.php**
- **Material/RepositorioInterface.php**
- **Servico/RepositorioInterface.php**
- **Usuario/RepositorioInterface.php**

**Mappers:**
- **Cliente/Mapper.php** - Converte array ↔ Entity
- **Veiculo/Mapper.php**
- **Ordem/Mapper.php**
- **Material/Mapper.php**
- **Servico/Mapper.php**
- **Usuario/Mapper.php**

**Exemplo - Ordem Entity:**
```php
namespace App\Domain\Entity\Ordem;

class Ordem
{
    private string $uuid;
    private string $clienteUuid;
    private string $veiculoUuid;
    private string $status;  // CRIADA, AGUARDANDO_APROVACAO, etc.
    private float $valorTotal;
    private array $materiais;
    private array $servicos;

    public function aprovar(): void
    {
        if ($this->status !== 'AGUARDANDO_APROVACAO') {
            throw new \DomainException('Ordem deve estar aguardando aprovação');
        }
        $this->status = 'APROVADA';
    }

    public function calcularValorTotal(): float
    {
        $totalMateriais = array_sum(array_map(
            fn($m) => $m['quantidade'] * $m['valor'],
            $this->materiais
        ));

        $totalServicos = array_sum(array_map(
            fn($s) => $s['quantidade'] * $s['valor'],
            $this->servicos
        ));

        return $totalMateriais + $totalServicos;
    }
}
```

---

#### 1.2 Domain/UseCase
**Responsabilidade:** Orquestrar regras de negócio (casos de uso)

**Padrão:** Um Use Case por operação CRUD + operações específicas de negócio

**Estrutura por Entidade:**
```
UseCase/
├── Cliente/
│   ├── CreateUseCase.php
│   ├── ReadUseCase.php
│   ├── UpdateUseCase.php
│   └── DeleteUseCase.php
├── Veiculo/
│   ├── CreateUseCase.php
│   ├── ReadUseCase.php
│   ├── UpdateUseCase.php
│   └── DeleteUseCase.php
├── Ordem/
│   ├── CreateUseCase.php
│   ├── ReadUseCase.php
│   ├── UpdateUseCase.php
│   ├── DeleteUseCase.php
│   ├── AprovarUseCase.php
│   ├── ReprovarUseCase.php
│   ├── AdicionarMaterialUseCase.php
│   └── AdicionarServicoUseCase.php
├── Material/
│   ├── CreateUseCase.php
│   ├── ReadUseCase.php
│   ├── UpdateUseCase.php
│   └── DeleteUseCase.php
├── Servico/
│   ├── CreateUseCase.php
│   ├── ReadUseCase.php
│   ├── UpdateUseCase.php
│   └── DeleteUseCase.php
└── Usuario/
    ├── CreateUseCase.php
    ├── ReadUseCase.php
    ├── UpdateUseCase.php
    ├── DeleteUseCase.php
    └── AuthenticateUseCase.php
```

**Exemplo - CreateUseCase (Ordem):**
```php
namespace App\Domain\UseCase\Ordem;

class CreateUseCase
{
    public function __construct(
        private RepositorioInterface $repositorio
    ) {}

    public function execute(array $input): Ordem
    {
        // Validação de regras de negócio
        if (empty($input['cliente_uuid'])) {
            throw new \InvalidArgumentException('Cliente obrigatório');
        }

        if (empty($input['veiculo_uuid'])) {
            throw new \InvalidArgumentException('Veículo obrigatório');
        }

        // Criação da entidade
        $ordem = new Ordem(
            uuid: Uuid::generate(),
            clienteUuid: $input['cliente_uuid'],
            veiculoUuid: $input['veiculo_uuid'],
            status: 'CRIADA',
            valorTotal: 0.0,
            materiais: [],
            servicos: []
        );

        // Persistência via repositório (interface)
        return $this->repositorio->criar($ordem);
    }
}
```

**Exemplo - AprovarUseCase (Ordem):**
```php
namespace App\Domain\UseCase\Ordem;

class AprovarUseCase
{
    public function __construct(
        private RepositorioInterface $repositorio
    ) {}

    public function execute(string $uuid): Ordem
    {
        $ordem = $this->repositorio->buscarPorUuid($uuid);

        if (!$ordem) {
            throw new \DomainException('Ordem não encontrada');
        }

        // Lógica de negócio na entidade
        $ordem->aprovar();

        return $this->repositorio->atualizar($ordem);
    }
}
```

---

### CAMADA 2: Infrastructure (Implementações Técnicas)

#### 2.1 Infrastructure/Controller
**Responsabilidade:** Receber requisições HTTP, delegar para Use Cases, retornar respostas

**Componentes:**
- **Cliente.php** - CRUD de clientes
- **Veiculo.php** - CRUD de veículos
- **Ordem.php** - CRUD de ordens + aprovação/reprovação
- **Material.php** - CRUD de materiais
- **Servico.php** - CRUD de serviços
- **Usuario.php** - CRUD de usuários
- **Auth.php** - Autenticação (delegada para Lambda)
- **Ping.php** - Health check

**Exemplo - OrdemController:**
```php
namespace App\Infrastructure\Controller;

class Ordem extends Controller
{
    public function __construct(
        private CreateUseCase $createUseCase,
        private ReadUseCase $readUseCase,
        private AprovarUseCase $aprovarUseCase,
        private OrdemPresenter $presenter
    ) {}

    public function create(Request $request): JsonResponse
    {
        try {
            $ordem = $this->createUseCase->execute(
                $request->all()
            );

            return $this->presenter->success($ordem, 201);
        } catch (\Exception $e) {
            return $this->presenter->error($e->getMessage(), 400);
        }
    }

    public function aprovar(string $uuid): JsonResponse
    {
        try {
            $ordem = $this->aprovarUseCase->execute($uuid);
            return $this->presenter->success($ordem);
        } catch (\DomainException $e) {
            return $this->presenter->error($e->getMessage(), 422);
        }
    }
}
```

---

#### 2.2 Infrastructure/Repositories
**Responsabilidade:** Implementar interfaces de repositório usando Eloquent ORM

**Componentes:**
- **ClienteRepository.php** - Implementa `Domain\Entity\Cliente\RepositorioInterface`
- **VeiculoRepository.php**
- **OrdemRepository.php**
- **MaterialRepository.php**
- **ServicoRepository.php**
- **UsuarioRepository.php**

**Padrão:** Converte Model (Eloquent) ↔ Entity (Domain) via Mappers

**Exemplo - ClienteRepository:**
```php
namespace App\Infrastructure\Repositories;

class ClienteRepository implements RepositorioInterface
{
    public function listar(): Collection
    {
        $models = ClienteModel::all();

        return $models->map(function ($model) {
            return Mapper::toEntity($model->toArray());
        });
    }

    public function buscarPorUuid(string $uuid): ?Cliente
    {
        $model = ClienteModel::where('uuid', $uuid)->first();

        return $model
            ? Mapper::toEntity($model->toArray())
            : null;
    }

    public function criar(Cliente $cliente): Cliente
    {
        $data = Mapper::toArray($cliente);

        $model = ClienteModel::create($data);

        return Mapper::toEntity($model->toArray());
    }

    public function atualizar(Cliente $cliente): Cliente
    {
        $model = ClienteModel::where('uuid', $cliente->getUuid())
            ->firstOrFail();

        $model->update(Mapper::toArray($cliente));

        return Mapper::toEntity($model->fresh()->toArray());
    }

    public function deletar(string $uuid): bool
    {
        return ClienteModel::where('uuid', $uuid)->delete() > 0;
    }
}
```

---

#### 2.3 Infrastructure/Presenter
**Responsabilidade:** Formatar respostas JSON

**Componentes:**
- **ClientePresenter.php**
- **VeiculoPresenter.php**
- **OrdemPresenter.php**
- **MaterialPresenter.php**
- **ServicoPresenter.php**
- **UsuarioPresenter.php**

**Exemplo - OrdemPresenter:**
```php
namespace App\Infrastructure\Presenter;

class OrdemPresenter
{
    public function success($data, int $statusCode = 200): JsonResponse
    {
        return response()->json([
            'success' => true,
            'data' => $this->format($data),
        ], $statusCode);
    }

    public function error(string $message, int $statusCode = 400): JsonResponse
    {
        return response()->json([
            'success' => false,
            'error' => $message,
        ], $statusCode);
    }

    private function format($ordem): array
    {
        if ($ordem instanceof Collection) {
            return $ordem->map(fn($o) => $this->formatSingle($o))->toArray();
        }

        return $this->formatSingle($ordem);
    }

    private function formatSingle(Ordem $ordem): array
    {
        return [
            'uuid' => $ordem->getUuid(),
            'cliente_uuid' => $ordem->getClienteUuid(),
            'veiculo_uuid' => $ordem->getVeiculoUuid(),
            'status' => $ordem->getStatus(),
            'valor_total' => $ordem->getValorTotal(),
            'created_at' => $ordem->getCreatedAt(),
        ];
    }
}
```

---

#### 2.4 Infrastructure/Service
**Responsabilidade:** Serviços de infraestrutura (logging, integrações, etc.)

**Componentes:**
- **BusinessEventLogger.php** (Trait)
  - Logs estruturados de eventos de negócio
  - Correlação via correlation_id
  - Integração com Datadog

**Exemplo - BusinessEventLogger:**
```php
namespace App\Infrastructure\Service;

trait BusinessEventLogger
{
    protected function logBusinessEvent(string $event, array $data): void
    {
        \Log::channel('datadog')->info($event, [
            'event_type' => $event,
            'timestamp' => now()->toIso8601String(),
            'correlation_id' => request()->header('x-correlation-id') ?? Uuid::generate(),
            'user_id' => auth()->id() ?? 'guest',
            'data' => $data,
        ]);
    }
}
```

**Uso no Controller:**
```php
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
            'valor_total' => $ordem->getValorTotal(),
        ]);

        return $this->presenter->success($ordem, 201);
    }
}
```

---

#### 2.5 Infrastructure/Dto
**Responsabilidade:** Data Transfer Objects (comunicação entre camadas)

**Componentes:**
- **ClienteDto.php**
- **VeiculoDto.php**
- **OrdemDto.php**
- etc.

---

#### 2.6 Infrastructure/Gateway
**Responsabilidade:** Integrações com sistemas externos (futuro)

**Componentes (Planejados):**
- **PaymentGateway.php** - Integração com gateway de pagamento
- **EmailGateway.php** - Envio de emails
- **SmsGateway.php** - Envio de SMS

---

### CAMADA 3: Http (Apresentação)

#### 3.1 Http/Middleware
**Responsabilidade:** Interceptar requisições antes dos controllers

**Componentes:**
- **JsonWebTokenMiddleware.php**
  - Validação de JWT (delegada para Lambda via API Gateway)
  - Extração de claims do token
  - Injeção de usuário autenticado

- **DocumentoObrigatorioMiddleware.php**
  - Validação de CPF em endpoints específicos
  - Verifica formato e existência no banco

**Exemplo - DocumentoObrigatorioMiddleware:**
```php
namespace App\Http\Middleware;

class DocumentoObrigatorioMiddleware
{
    public function handle(Request $request, Closure $next): Response
    {
        $cpf = $request->input('cpf');

        if (empty($cpf)) {
            return response()->json([
                'error' => 'CPF obrigatório'
            ], 422);
        }

        // Validação de formato
        if (!$this->validarFormatoCpf($cpf)) {
            return response()->json([
                'error' => 'CPF inválido'
            ], 422);
        }

        return $next($request);
    }

    private function validarFormatoCpf(string $cpf): bool
    {
        // Validação de dígitos verificadores
        $cpf = preg_replace('/[^0-9]/', '', $cpf);

        if (strlen($cpf) !== 11) {
            return false;
        }

        // Algoritmo de validação de CPF
        // ...

        return true;
    }
}
```

---

#### 3.2 Http/Routes
**Responsabilidade:** Definir rotas da API

**Arquivos:**
- **api.php** - Rotas principais (ping, auth)
- **cliente.php** - CRUD clientes
- **veiculo.php** - CRUD veículos
- **ordem.php** - CRUD ordens + aprovação/reprovação
- **material.php** - CRUD materiais
- **servico.php** - CRUD serviços
- **usuario.php** - CRUD usuários

**Exemplo - routes/ordem.php:**
```php
Route::prefix('ordem')->group(function () {
    Route::get('/', [Ordem::class, 'index']);
    Route::post('/', [Ordem::class, 'create']);
    Route::get('/{uuid}', [Ordem::class, 'show']);
    Route::put('/{uuid}', [Ordem::class, 'update']);
    Route::delete('/{uuid}', [Ordem::class, 'delete']);

    // Operações específicas de negócio
    Route::put('/{uuid}/aprovar', [Ordem::class, 'aprovar']);
    Route::put('/{uuid}/reprovar', [Ordem::class, 'reprovar']);
    Route::post('/ordem-material/adiciona-material', [Ordem::class, 'adicionarMaterial']);
    Route::post('/ordem-servico/adiciona-servico', [Ordem::class, 'adicionarServico']);
});
```

---

### CAMADA 4: Models (Eloquent ORM - Camada Externa)

**Responsabilidade:** Mapeamento objeto-relacional (ORM)

**Componentes:**
- **ClienteModel.php** - Tabela `clientes`
- **VeiculoModel.php** - Tabela `veiculos`
- **OrdemModel.php** - Tabela `ordens`
- **MaterialModel.php** - Tabela `materiais`
- **ServicoModel.php** - Tabela `servicos`
- **UsuarioModel.php** - Tabela `usuarios`
- **OrdemMaterialModel.php** - Tabela pivot `ordem_material`
- **OrdemServicoModel.php** - Tabela pivot `ordem_servico`

**Exemplo - OrdemModel:**
```php
namespace App\Models;

class OrdemModel extends Model
{
    protected $table = 'ordens';
    protected $primaryKey = 'uuid';
    public $incrementing = false;
    protected $keyType = 'string';

    protected $fillable = [
        'uuid',
        'cliente_uuid',
        'veiculo_uuid',
        'status',
        'valor_total',
    ];

    // Relacionamentos
    public function cliente()
    {
        return $this->belongsTo(ClienteModel::class, 'cliente_uuid', 'uuid');
    }

    public function veiculo()
    {
        return $this->belongsTo(VeiculoModel::class, 'veiculo_uuid', 'uuid');
    }

    public function materiais()
    {
        return $this->belongsToMany(
            MaterialModel::class,
            'ordem_material',
            'ordem_uuid',
            'material_uuid'
        )->withPivot('quantidade', 'valor');
    }

    public function servicos()
    {
        return $this->belongsToMany(
            ServicoModel::class,
            'ordem_servico',
            'ordem_uuid',
            'servico_uuid'
        )->withPivot('quantidade', 'valor');
    }
}
```

---

## Diagrama de Componentes (Descrição Textual)

```
┌───────────────────────────────────────────────────────────────────┐
│                        HTTP LAYER (Apresentação)                  │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌─────────────────┐          ┌──────────────────────────────┐  │
│  │ Routes          │          │ Middleware                   │  │
│  │                 │          │                              │  │
│  │ • api.php       │          │ • JsonWebTokenMiddleware     │  │
│  │ • cliente.php   │────┬────▶│ • DocumentoObrigatorio       │  │
│  │ • veiculo.php   │    │     │   Middleware                 │  │
│  │ • ordem.php     │    │     └──────────────────────────────┘  │
│  │ • material.php  │    │                                        │
│  │ • servico.php   │    │                                        │
│  │ • usuario.php   │    │                                        │
│  └─────────────────┘    │                                        │
│                         ▼                                        │
└─────────────────────────┼────────────────────────────────────────┘
                          │
                          ▼
┌───────────────────────────────────────────────────────────────────┐
│                 INFRASTRUCTURE LAYER (Implementações)             │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Controllers                                              │   │
│  │                                                          │   │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐           │   │
│  │ │ Cliente    │ │ Veiculo    │ │ Ordem      │ ...       │   │
│  │ │ Controller │ │ Controller │ │ Controller │           │   │
│  │ └──────┬─────┘ └──────┬─────┘ └──────┬─────┘           │   │
│  │        │              │              │                  │   │
│  │        ▼              ▼              ▼                  │   │
│  └────────┼──────────────┼──────────────┼──────────────────┘   │
│           │              │              │                      │
│           │              │              │ ◄─────────┐          │
│           │              │              │           │          │
│  ┌────────▼──────────────▼──────────────▼──────┐    │          │
│  │ Use Cases (injetados via DI)               │    │          │
│  │                                             │    │          │
│  │ • CreateUseCase                             │    │          │
│  │ • ReadUseCase                               │    │          │
│  │ • UpdateUseCase                             │────┘          │
│  │ • DeleteUseCase                             │               │
│  │ • AprovarUseCase (Ordem)                    │               │
│  │ • AuthenticateUseCase (Usuario)             │               │
│  └─────────────────────────────────────────────┘               │
│                         │                                       │
│                         │                                       │
│  ┌──────────────────────▼─────────────────────────────┐        │
│  │ Repositories (implementações)                      │        │
│  │                                                    │        │
│  │ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐  │        │
│  │ │ Cliente     │ │ Veiculo     │ │ Ordem       │  │        │
│  │ │ Repository  │ │ Repository  │ │ Repository  │ ...        │
│  │ └──────┬──────┘ └──────┬──────┘ └──────┬──────┘  │        │
│  │        │               │               │          │        │
│  └────────┼───────────────┼───────────────┼──────────┘        │
│           │               │               │                   │
│           ▼               ▼               ▼                   │
│  ┌─────────────────────────────────────────────────────────┐  │
│  │ Eloquent Models (ORM)                                   │  │
│  │                                                         │  │
│  │ • ClienteModel     • VeiculoModel    • OrdemModel      │  │
│  │ • MaterialModel    • ServicoModel    • UsuarioModel    │  │
│  └────────┬────────────────────────────────────────────────┘  │
│           │                                                   │
│           │                                                   │
│  ┌────────▼────────────────────────────────────────┐         │
│  │ Presenters                                      │         │
│  │                                                 │         │
│  │ • ClientePresenter                              │         │
│  │ • VeiculoPresenter                              │         │
│  │ • OrdemPresenter                                │         │
│  │ • success(data, statusCode)                     │         │
│  │ • error(message, statusCode)                    │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
│  ┌──────────────────────────────────────────────────────┐    │
│  │ Service                                              │    │
│  │                                                      │    │
│  │ • BusinessEventLogger (Trait)                        │    │
│  │   - logBusinessEvent(event, data)                    │    │
│  │   - Datadog integration                              │    │
│  └──────────────────────────────────────────────────────┘    │
└───────────────────────────┼───────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────────┐
│                    DOMAIN LAYER (Núcleo de Negócio)               │
├───────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Entities (Objetos de Domínio)                           │   │
│  │                                                          │   │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐           │   │
│  │ │ Cliente    │ │ Veiculo    │ │ Ordem      │           │   │
│  │ │            │ │            │ │            │           │   │
│  │ │ • uuid     │ │ • uuid     │ │ • uuid     │  ...      │   │
│  │ │ • cpf      │ │ • placa    │ │ • status   │           │   │
│  │ │ • nome     │ │ • marca    │ │ • aprovar()│           │   │
│  │ │ • validar()│ │ • validar()│ │ • calcular()│          │   │
│  │ └────────────┘ └────────────┘ └────────────┘           │   │
│  │                                                          │   │
│  │ ┌────────────┐ ┌────────────┐ ┌────────────┐           │   │
│  │ │ Material   │ │ Servico    │ │ Usuario    │           │   │
│  │ │            │ │            │ │            │           │   │
│  │ │ • uuid     │ │ • uuid     │ │ • uuid     │           │   │
│  │ │ • valor    │ │ • valor    │ │ • hashSenha│           │   │
│  │ └────────────┘ └────────────┘ └────────────┘           │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Repository Interfaces (Contracts)                        │   │
│  │                                                          │   │
│  │ • Cliente/RepositorioInterface                           │   │
│  │ • Veiculo/RepositorioInterface                           │   │
│  │ • Ordem/RepositorioInterface                             │   │
│  │ • Material/RepositorioInterface                          │   │
│  │ • Servico/RepositorioInterface                           │   │
│  │ • Usuario/RepositorioInterface                           │   │
│  │                                                          │   │
│  │ Métodos padrão:                                          │   │
│  │   - listar(): Collection                                 │   │
│  │   - buscarPorUuid(string): ?Entity                       │   │
│  │   - criar(Entity): Entity                                │   │
│  │   - atualizar(Entity): Entity                            │   │
│  │   - deletar(string): bool                                │   │
│  └──────────────────────────────────────────────────────────┘   │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ Mappers (Entity ↔ Array)                                 │   │
│  │                                                          │   │
│  │ • Cliente/Mapper::toEntity(array): Cliente               │   │
│  │ • Cliente/Mapper::toArray(Cliente): array                │   │
│  │                                                          │   │
│  │ (idem para Veiculo, Ordem, Material, Servico, Usuario)  │   │
│  └──────────────────────────────────────────────────────────┘   │
└───────────────────────────────────────────────────────────────────┘
```

## Fluxo de Dados Completo

### Exemplo: Criar Ordem de Serviço

```
1. Cliente (HTTP POST) → Nginx → PHP-FPM

2. Routes (routes/ordem.php)
   POST /ordem → Ordem::create

3. Middleware Pipeline
   JsonWebTokenMiddleware → DocumentoObrigatorioMiddleware

4. Controller (Infrastructure/Controller/Ordem.php)
   public function create(Request $request)
   {
       // Delega para Use Case
       $ordem = $this->createUseCase->execute($request->all());

       // Log evento de negócio
       $this->logBusinessEvent('ordem.criada', [...]);

       // Retorna via Presenter
       return $this->presenter->success($ordem, 201);
   }

5. Use Case (Domain/UseCase/Ordem/CreateUseCase.php)
   public function execute(array $input): Ordem
   {
       // Validações de negócio
       // Cria entidade Ordem
       // Delega persistência para repositório
       return $this->repositorio->criar($ordem);
   }

6. Repository (Infrastructure/Repositories/OrdemRepository.php)
   public function criar(Ordem $ordem): Ordem
   {
       // Converte Entity → Array (via Mapper)
       $data = Mapper::toArray($ordem);

       // Persiste via Eloquent Model
       $model = OrdemModel::create($data);

       // Converte Model → Entity (via Mapper)
       return Mapper::toEntity($model->toArray());
   }

7. Eloquent Model (Models/OrdemModel.php)
   OrdemModel::create([...]) → INSERT INTO ordens (...)

8. PostgreSQL
   Executa INSERT e retorna dados

9. Retorno ao Cliente
   Controller → Presenter → JSON Response
   {
       "success": true,
       "data": {
           "uuid": "ordem-456",
           "status": "CRIADA",
           "valor_total": 0
       }
   }

10. Log Assíncrono
    BusinessEventLogger → Datadog Agent → Datadog SaaS
```

## Princípios de Design

**SOLID:**
- **S** - Single Responsibility: Cada Use Case tem uma única responsabilidade
- **O** - Open/Closed: Extensível via novos Use Cases sem modificar existentes
- **L** - Liskov Substitution: Repositories implementam interfaces
- **I** - Interface Segregation: Interfaces específicas por entidade
- **D** - Dependency Inversion: Controllers dependem de abstrações (Use Cases, Repositórios)

**Object Calisthenics:**
- 1 nível de indentação por método
- Sem else (early return)
- Encapsulamento de primitivos
- Coleções de primeira classe
- 1 ponto por linha

## Testes

**Estrutura:**
```
tests/
├── Unit/
│   ├── Domain/
│   │   ├── Entity/
│   │   │   ├── ClienteTest.php
│   │   │   ├── VeiculoTest.php
│   │   │   └── OrdemTest.php
│   │   └── UseCase/
│   │       ├── Cliente/
│   │       │   ├── CreateUseCaseTest.php
│   │       │   └── ReadUseCaseTest.php
│   │       └── Ordem/
│   │           ├── CreateUseCaseTest.php
│   │           └── AprovarUseCaseTest.php
└── Feature/
    ├── ClienteControllerTest.php
    ├── VeiculoControllerTest.php
    └── OrdemControllerTest.php
```

**Cobertura Esperada:**
- Domain: >90% (regras de negócio críticas)
- Infrastructure: >70%
- Http: >60%

## Referências

- [C4 Model - Components](https://c4model.com/#ComponentDiagram)
- [Clean Architecture (Robert C. Martin)](https://blog.cleancoder.com/uncle-bob/2012/08/13/the-clean-architecture.html)
- [ADR-002: Clean Architecture no Laravel](../adrs/ADR-002-clean-architecture.md)
- [Laravel Documentation](https://laravel.com/docs/12.x)

## Palavras-Chave

`C4 Model` `Component Diagram` `Clean Architecture` `Domain-Driven Design` `Repository Pattern` `Use Case Pattern` `SOLID` `Laravel` `PHP`
