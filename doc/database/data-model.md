# Modelo de Dados - Oficina SOAT

**Sistema:** Gestão de Ordens de Serviço para Oficinas Mecânicas
**SGBD:** PostgreSQL 17.5
**Data:** 08/01/2025
**Versão:** 1.0

## Visão Geral

O modelo de dados foi projetado para suportar a gestão completa de uma oficina mecânica, abrangendo clientes, veículos, ordens de serviço, materiais e serviços utilizados.

**Princípios de Design:**
- **Normalização:** 3ª Forma Normal (3NF) para evitar redundância
- **UUIDs:** Chaves primárias UUID v4 para segurança e distribuição
- **Timestamps:** Auditoria automática de criação e atualização
- **Relacionamentos:** Foreign keys com ON DELETE para integridade referencial
- **Indexação:** Índices em chaves estrangeiras e campos de busca

## Diagrama ER (Descrição Textual)

```
┌──────────────────┐                ┌──────────────────┐
│    CLIENTES      │                │    VEICULOS      │
├──────────────────┤                ├──────────────────┤
│ uuid (PK)        │                │ uuid (PK)        │
│ cpf (UNIQUE)     │                │ cliente_uuid (FK)│◄───────┐
│ nome             │                │ placa (UNIQUE)   │        │
│ email            │                │ marca            │        │
│ telefone         │                │ modelo           │        │
│ created_at       │                │ ano              │        │
│ updated_at       │                │ created_at       │        │
└────────┬─────────┘                │ updated_at       │        │
         │                          └────────┬─────────┘        │
         │ 1                                 │ 1                │
         │                                   │                  │
         │ Has Many                          │ Has Many         │
         │                                   │                  │
         │                         ┌─────────▼──────────┐       │
         │                         │      ORDENS        │       │
         │                         ├────────────────────┤       │
         │                         │ uuid (PK)          │       │
         └─────────────────────────┤ cliente_uuid (FK)  │───────┘
                                   │ veiculo_uuid (FK)  │───────┘
                                   │ status             │
                                   │ valor_total        │
                                   │ created_at         │
                                   │ updated_at         │
                                   └─────────┬──────────┘
                                             │
                           ┌─────────────────┼─────────────────┐
                           │ Many-to-Many    │ Many-to-Many    │
                           ▼                 ▼                 │
                  ┌────────────────┐  ┌────────────────┐      │
                  │ ORDEM_MATERIAL │  │ ORDEM_SERVICO  │      │
                  ├────────────────┤  ├────────────────┤      │
                  │ id (PK)        │  │ id (PK)        │      │
                  │ ordem_uuid(FK) │  │ ordem_uuid(FK) │      │
                  │ material_uuid  │  │ servico_uuid   │      │
                  │   (FK)         │  │   (FK)         │      │
                  │ quantidade     │  │ quantidade     │      │
                  │ valor          │  │ valor          │      │
                  │ created_at     │  │ created_at     │      │
                  │ updated_at     │  │ updated_at     │      │
                  └────────┬───────┘  └────────┬───────┘      │
                           │                   │               │
                     Many  │                   │ Many          │
                           ▼                   ▼               │
                  ┌────────────────┐  ┌────────────────┐      │
                  │   MATERIAIS    │  │    SERVICOS    │      │
                  ├────────────────┤  ├────────────────┤      │
                  │ uuid (PK)      │  │ uuid (PK)      │      │
                  │ nome           │  │ nome           │      │
                  │ descricao      │  │ descricao      │      │
                  │ valor          │  │ valor          │      │
                  │ created_at     │  │ created_at     │      │
                  │ updated_at     │  │ updated_at     │      │
                  └────────────────┘  └────────────────┘      │
                                                               │
                                   ┌────────────────┐          │
                                   │    USUARIOS    │          │
                                   ├────────────────┤          │
                                   │ uuid (PK)      │          │
                                   │ nome           │          │
                                   │ email (UNIQUE) │          │
                                   │ password       │          │
                                   │ tipo           │          │
                                   │ created_at     │          │
                                   │ updated_at     │          │
                                   └────────────────┘          │
```

## Entidades e Tabelas

### 1. CLIENTES

**Descrição:** Armazena informações dos proprietários de veículos que utilizam os serviços da oficina.

**Tabela:** `clientes`

| Coluna | Tipo | Nulo | Default | Constraints | Descrição |
|--------|------|------|---------|-------------|-----------|
| uuid | UUID | NOT NULL | gen_random_uuid() | PRIMARY KEY | Identificador único do cliente |
| cpf | VARCHAR(14) | NOT NULL | - | UNIQUE | CPF formatado (XXX.XXX.XXX-XX) |
| nome | VARCHAR(255) | NOT NULL | - | - | Nome completo do cliente |
| email | VARCHAR(255) | NULL | - | - | Email de contato |
| telefone | VARCHAR(20) | NULL | - | - | Telefone de contato |
| created_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de criação do registro |
| updated_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de última atualização |

**Índices:**
- `PRIMARY KEY (uuid)`
- `UNIQUE INDEX idx_clientes_cpf (cpf)`
- `INDEX idx_clientes_nome (nome)`

**Validações de Negócio:**
- CPF deve ser válido (dígitos verificadores)
- CPF é único no sistema
- Nome é obrigatório (mínimo 3 caracteres)

**Relacionamentos:**
- 1 Cliente → N Veículos (One-to-Many)
- 1 Cliente → N Ordens (One-to-Many)

**Migration Laravel:**
```php
Schema::create('clientes', function (Blueprint $table) {
    $table->uuid('uuid')->primary()->default(DB::raw('gen_random_uuid()'));
    $table->string('cpf', 14)->unique();
    $table->string('nome', 255);
    $table->string('email', 255)->nullable();
    $table->string('telefone', 20)->nullable();
    $table->timestamps();

    $table->index('nome');
});
```

---

### 2. VEICULOS

**Descrição:** Armazena informações dos veículos dos clientes.

**Tabela:** `veiculos`

| Coluna | Tipo | Nulo | Default | Constraints | Descrição |
|--------|------|------|---------|-------------|-----------|
| uuid | UUID | NOT NULL | gen_random_uuid() | PRIMARY KEY | Identificador único do veículo |
| cliente_uuid | UUID | NOT NULL | - | FOREIGN KEY | Referência ao cliente proprietário |
| placa | VARCHAR(8) | NOT NULL | - | UNIQUE | Placa do veículo (ABC-1234) |
| marca | VARCHAR(100) | NOT NULL | - | - | Marca do veículo (Fiat, Ford, etc.) |
| modelo | VARCHAR(100) | NOT NULL | - | - | Modelo do veículo (Uno, Fiesta, etc.) |
| ano | INTEGER | NOT NULL | - | CHECK (ano >= 1900 AND ano <= EXTRACT(YEAR FROM CURRENT_DATE)) | Ano de fabricação |
| created_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de criação do registro |
| updated_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de última atualização |

**Índices:**
- `PRIMARY KEY (uuid)`
- `UNIQUE INDEX idx_veiculos_placa (placa)`
- `INDEX idx_veiculos_cliente (cliente_uuid)`
- `INDEX idx_veiculos_marca_modelo (marca, modelo)`

**Foreign Keys:**
```sql
ALTER TABLE veiculos
ADD CONSTRAINT fk_veiculos_cliente
FOREIGN KEY (cliente_uuid)
REFERENCES clientes(uuid)
ON DELETE CASCADE;
```

**Validações de Negócio:**
- Placa é única no sistema
- Ano deve estar entre 1900 e ano atual
- Marca e modelo são obrigatórios

**Relacionamentos:**
- N Veículos → 1 Cliente (Many-to-One)
- 1 Veículo → N Ordens (One-to-Many)

**Migration Laravel:**
```php
Schema::create('veiculos', function (Blueprint $table) {
    $table->uuid('uuid')->primary()->default(DB::raw('gen_random_uuid()'));
    $table->uuid('cliente_uuid');
    $table->string('placa', 8)->unique();
    $table->string('marca', 100);
    $table->string('modelo', 100);
    $table->integer('ano');
    $table->timestamps();

    $table->foreign('cliente_uuid')
          ->references('uuid')
          ->on('clientes')
          ->onDelete('cascade');

    $table->index('cliente_uuid');
    $table->index(['marca', 'modelo']);
    $table->check('ano >= 1900 AND ano <= EXTRACT(YEAR FROM CURRENT_DATE)');
});
```

---

### 3. ORDENS

**Descrição:** Armazena as ordens de serviço criadas para atendimento de clientes.

**Tabela:** `ordens`

| Coluna | Tipo | Nulo | Default | Constraints | Descrição |
|--------|------|------|---------|-------------|-----------|
| uuid | UUID | NOT NULL | gen_random_uuid() | PRIMARY KEY | Identificador único da ordem |
| cliente_uuid | UUID | NOT NULL | - | FOREIGN KEY | Referência ao cliente |
| veiculo_uuid | UUID | NOT NULL | - | FOREIGN KEY | Referência ao veículo |
| status | VARCHAR(50) | NOT NULL | 'CRIADA' | CHECK (status IN (...)) | Estado atual da ordem |
| valor_total | DECIMAL(10,2) | NOT NULL | 0.00 | CHECK (valor_total >= 0) | Valor total (materiais + serviços) |
| created_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de criação do registro |
| updated_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de última atualização |

**Estados Possíveis (status):**
- `CRIADA` - Ordem criada, aguardando materiais/serviços
- `AGUARDANDO_APROVACAO` - Orçamento enviado ao cliente
- `APROVADA` - Cliente aprovou o orçamento
- `REPROVADA` - Cliente reprovou o orçamento
- `EM_EXECUCAO` - Serviços sendo executados
- `FINALIZADA` - Ordem concluída

**Índices:**
- `PRIMARY KEY (uuid)`
- `INDEX idx_ordens_cliente (cliente_uuid)`
- `INDEX idx_ordens_veiculo (veiculo_uuid)`
- `INDEX idx_ordens_status (status)`
- `INDEX idx_ordens_created_at (created_at DESC)`

**Foreign Keys:**
```sql
ALTER TABLE ordens
ADD CONSTRAINT fk_ordens_cliente
FOREIGN KEY (cliente_uuid)
REFERENCES clientes(uuid)
ON DELETE RESTRICT;

ALTER TABLE ordens
ADD CONSTRAINT fk_ordens_veiculo
FOREIGN KEY (veiculo_uuid)
REFERENCES veiculos(uuid)
ON DELETE RESTRICT;
```

**Validações de Negócio:**
- Cliente e veículo são obrigatórios
- Veículo deve pertencer ao cliente informado
- Valor total não pode ser negativo
- Transições de estado devem seguir fluxo:
  - CRIADA → AGUARDANDO_APROVACAO
  - AGUARDANDO_APROVACAO → APROVADA ou REPROVADA
  - APROVADA → EM_EXECUCAO
  - EM_EXECUCAO → FINALIZADA

**Relacionamentos:**
- N Ordens → 1 Cliente (Many-to-One)
- N Ordens → 1 Veículo (Many-to-One)
- N Ordens ↔ N Materiais (Many-to-Many via ordem_material)
- N Ordens ↔ N Serviços (Many-to-Many via ordem_servico)

**Migration Laravel:**
```php
Schema::create('ordens', function (Blueprint $table) {
    $table->uuid('uuid')->primary()->default(DB::raw('gen_random_uuid()'));
    $table->uuid('cliente_uuid');
    $table->uuid('veiculo_uuid');
    $table->string('status', 50)->default('CRIADA');
    $table->decimal('valor_total', 10, 2)->default(0.00);
    $table->timestamps();

    $table->foreign('cliente_uuid')
          ->references('uuid')
          ->on('clientes')
          ->onDelete('restrict');

    $table->foreign('veiculo_uuid')
          ->references('uuid')
          ->on('veiculos')
          ->onDelete('restrict');

    $table->index('cliente_uuid');
    $table->index('veiculo_uuid');
    $table->index('status');
    $table->index('created_at');

    $table->check("status IN ('CRIADA', 'AGUARDANDO_APROVACAO', 'APROVADA', 'REPROVADA', 'EM_EXECUCAO', 'FINALIZADA')");
    $table->check('valor_total >= 0');
});
```

---

### 4. MATERIAIS

**Descrição:** Catálogo de peças e materiais utilizados nos serviços.

**Tabela:** `materiais`

| Coluna | Tipo | Nulo | Default | Constraints | Descrição |
|--------|------|------|---------|-------------|-----------|
| uuid | UUID | NOT NULL | gen_random_uuid() | PRIMARY KEY | Identificador único do material |
| nome | VARCHAR(255) | NOT NULL | - | - | Nome do material (ex: Pastilha de Freio) |
| descricao | TEXT | NULL | - | - | Descrição detalhada |
| valor | DECIMAL(10,2) | NOT NULL | - | CHECK (valor > 0) | Valor unitário |
| created_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de criação do registro |
| updated_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de última atualização |

**Índices:**
- `PRIMARY KEY (uuid)`
- `INDEX idx_materiais_nome (nome)`

**Validações de Negócio:**
- Nome é obrigatório
- Valor deve ser positivo (> 0)

**Relacionamentos:**
- N Materiais ↔ N Ordens (Many-to-Many via ordem_material)

**Migration Laravel:**
```php
Schema::create('materiais', function (Blueprint $table) {
    $table->uuid('uuid')->primary()->default(DB::raw('gen_random_uuid()'));
    $table->string('nome', 255);
    $table->text('descricao')->nullable();
    $table->decimal('valor', 10, 2);
    $table->timestamps();

    $table->index('nome');
    $table->check('valor > 0');
});
```

---

### 5. SERVICOS

**Descrição:** Catálogo de serviços oferecidos pela oficina.

**Tabela:** `servicos`

| Coluna | Tipo | Nulo | Default | Constraints | Descrição |
|--------|------|------|---------|-------------|-----------|
| uuid | UUID | NOT NULL | gen_random_uuid() | PRIMARY KEY | Identificador único do serviço |
| nome | VARCHAR(255) | NOT NULL | - | - | Nome do serviço (ex: Troca de Óleo) |
| descricao | TEXT | NULL | - | - | Descrição detalhada |
| valor | DECIMAL(10,2) | NOT NULL | - | CHECK (valor > 0) | Valor do serviço (mão de obra) |
| created_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de criação do registro |
| updated_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de última atualização |

**Índices:**
- `PRIMARY KEY (uuid)`
- `INDEX idx_servicos_nome (nome)`

**Validações de Negócio:**
- Nome é obrigatório
- Valor deve ser positivo (> 0)

**Relacionamentos:**
- N Serviços ↔ N Ordens (Many-to-Many via ordem_servico)

**Migration Laravel:**
```php
Schema::create('servicos', function (Blueprint $table) {
    $table->uuid('uuid')->primary()->default(DB::raw('gen_random_uuid()'));
    $table->string('nome', 255);
    $table->text('descricao')->nullable();
    $table->decimal('valor', 10, 2);
    $table->timestamps();

    $table->index('nome');
    $table->check('valor > 0');
});
```

---

### 6. ORDEM_MATERIAL (Tabela Pivot)

**Descrição:** Relacionamento N:N entre Ordens e Materiais (materiais utilizados em cada ordem).

**Tabela:** `ordem_material`

| Coluna | Tipo | Nulo | Default | Constraints | Descrição |
|--------|------|------|---------|-------------|-----------|
| id | BIGINT | NOT NULL | AUTO_INCREMENT | PRIMARY KEY | ID sequencial |
| ordem_uuid | UUID | NOT NULL | - | FOREIGN KEY | Referência à ordem |
| material_uuid | UUID | NOT NULL | - | FOREIGN KEY | Referência ao material |
| quantidade | INTEGER | NOT NULL | - | CHECK (quantidade > 0) | Quantidade utilizada |
| valor | DECIMAL(10,2) | NOT NULL | - | CHECK (valor > 0) | Valor unitário (snapshot) |
| created_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de criação do registro |
| updated_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de última atualização |

**Índices:**
- `PRIMARY KEY (id)`
- `UNIQUE INDEX idx_ordem_material_unique (ordem_uuid, material_uuid)`
- `INDEX idx_ordem_material_ordem (ordem_uuid)`
- `INDEX idx_ordem_material_material (material_uuid)`

**Foreign Keys:**
```sql
ALTER TABLE ordem_material
ADD CONSTRAINT fk_ordem_material_ordem
FOREIGN KEY (ordem_uuid)
REFERENCES ordens(uuid)
ON DELETE CASCADE;

ALTER TABLE ordem_material
ADD CONSTRAINT fk_ordem_material_material
FOREIGN KEY (material_uuid)
REFERENCES materiais(uuid)
ON DELETE RESTRICT;
```

**Validações de Negócio:**
- Quantidade deve ser positiva (> 0)
- Valor é snapshot do valor do material no momento da adição (histórico de preços)
- Não permitir duplicação (ordem + material devem ser únicos)

**Migration Laravel:**
```php
Schema::create('ordem_material', function (Blueprint $table) {
    $table->id();
    $table->uuid('ordem_uuid');
    $table->uuid('material_uuid');
    $table->integer('quantidade');
    $table->decimal('valor', 10, 2);
    $table->timestamps();

    $table->foreign('ordem_uuid')
          ->references('uuid')
          ->on('ordens')
          ->onDelete('cascade');

    $table->foreign('material_uuid')
          ->references('uuid')
          ->on('materiais')
          ->onDelete('restrict');

    $table->unique(['ordem_uuid', 'material_uuid']);
    $table->index('ordem_uuid');
    $table->index('material_uuid');

    $table->check('quantidade > 0');
    $table->check('valor > 0');
});
```

---

### 7. ORDEM_SERVICO (Tabela Pivot)

**Descrição:** Relacionamento N:N entre Ordens e Serviços (serviços executados em cada ordem).

**Tabela:** `ordem_servico`

| Coluna | Tipo | Nulo | Default | Constraints | Descrição |
|--------|------|------|---------|-------------|-----------|
| id | BIGINT | NOT NULL | AUTO_INCREMENT | PRIMARY KEY | ID sequencial |
| ordem_uuid | UUID | NOT NULL | - | FOREIGN KEY | Referência à ordem |
| servico_uuid | UUID | NOT NULL | - | FOREIGN KEY | Referência ao serviço |
| quantidade | INTEGER | NOT NULL | - | CHECK (quantidade > 0) | Quantidade executada |
| valor | DECIMAL(10,2) | NOT NULL | - | CHECK (valor > 0) | Valor unitário (snapshot) |
| created_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de criação do registro |
| updated_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de última atualização |

**Índices:**
- `PRIMARY KEY (id)`
- `UNIQUE INDEX idx_ordem_servico_unique (ordem_uuid, servico_uuid)`
- `INDEX idx_ordem_servico_ordem (ordem_uuid)`
- `INDEX idx_ordem_servico_servico (servico_uuid)`

**Foreign Keys:**
```sql
ALTER TABLE ordem_servico
ADD CONSTRAINT fk_ordem_servico_ordem
FOREIGN KEY (ordem_uuid)
REFERENCES ordens(uuid)
ON DELETE CASCADE;

ALTER TABLE ordem_servico
ADD CONSTRAINT fk_ordem_servico_servico
FOREIGN KEY (servico_uuid)
REFERENCES servicos(uuid)
ON DELETE RESTRICT;
```

**Validações de Negócio:**
- Quantidade deve ser positiva (> 0)
- Valor é snapshot do valor do serviço no momento da adição
- Não permitir duplicação (ordem + serviço devem ser únicos)

**Migration Laravel:**
```php
Schema::create('ordem_servico', function (Blueprint $table) {
    $table->id();
    $table->uuid('ordem_uuid');
    $table->uuid('servico_uuid');
    $table->integer('quantidade');
    $table->decimal('valor', 10, 2);
    $table->timestamps();

    $table->foreign('ordem_uuid')
          ->references('uuid')
          ->on('ordens')
          ->onDelete('cascade');

    $table->foreign('servico_uuid')
          ->references('uuid')
          ->on('servicos')
          ->onDelete('restrict');

    $table->unique(['ordem_uuid', 'servico_uuid']);
    $table->index('ordem_uuid');
    $table->index('servico_uuid');

    $table->check('quantidade > 0');
    $table->check('valor > 0');
});
```

---

### 8. USUARIOS

**Descrição:** Usuários do sistema (atendentes, mecânicos, gestores).

**Tabela:** `usuarios`

| Coluna | Tipo | Nulo | Default | Constraints | Descrição |
|--------|------|------|---------|-------------|-----------|
| uuid | UUID | NOT NULL | gen_random_uuid() | PRIMARY KEY | Identificador único do usuário |
| nome | VARCHAR(255) | NOT NULL | - | - | Nome completo |
| email | VARCHAR(255) | NOT NULL | - | UNIQUE | Email de login |
| password | VARCHAR(255) | NOT NULL | - | - | Senha hash (bcrypt) |
| tipo | VARCHAR(50) | NOT NULL | 'ATENDENTE' | CHECK (tipo IN (...)) | Tipo de usuário |
| created_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de criação do registro |
| updated_at | TIMESTAMP | NOT NULL | CURRENT_TIMESTAMP | - | Data de última atualização |

**Tipos de Usuário:**
- `ATENDENTE` - Cria ordens, cadastra clientes
- `MECANICO` - Executa serviços
- `GESTOR` - Acessa dashboards, relatórios

**Índices:**
- `PRIMARY KEY (uuid)`
- `UNIQUE INDEX idx_usuarios_email (email)`

**Validações de Negócio:**
- Email é único
- Senha deve ter hash bcrypt (Laravel)
- Tipo deve ser um dos valores permitidos

**Migration Laravel:**
```php
Schema::create('usuarios', function (Blueprint $table) {
    $table->uuid('uuid')->primary()->default(DB::raw('gen_random_uuid()'));
    $table->string('nome', 255);
    $table->string('email', 255)->unique();
    $table->string('password', 255);
    $table->string('tipo', 50)->default('ATENDENTE');
    $table->timestamps();

    $table->check("tipo IN ('ATENDENTE', 'MECANICO', 'GESTOR')");
});
```

---

## Relacionamentos Detalhados

### Cardinalidade

```
CLIENTES 1─────N VEICULOS
CLIENTES 1─────N ORDENS
VEICULOS 1─────N ORDENS

ORDENS N───────N MATERIAIS (via ordem_material)
ORDENS N───────N SERVICOS (via ordem_servico)
```

### Regras de Delete

| Entidade Pai | Entidade Filha | ON DELETE | Justificativa |
|--------------|----------------|-----------|---------------|
| CLIENTES | VEICULOS | CASCADE | Se cliente é deletado, veículos também |
| CLIENTES | ORDENS | RESTRICT | Não permitir deletar cliente com ordens |
| VEICULOS | ORDENS | RESTRICT | Não permitir deletar veículo com ordens |
| MATERIAIS | ORDEM_MATERIAL | RESTRICT | Preservar histórico de materiais usados |
| SERVICOS | ORDEM_SERVICO | RESTRICT | Preservar histórico de serviços executados |
| ORDENS | ORDEM_MATERIAL | CASCADE | Se ordem deletada, remover materiais associados |
| ORDENS | ORDEM_SERVICO | CASCADE | Se ordem deletada, remover serviços associados |

## Justificativas de Design

### 1. Por que UUIDs ao invés de IDs Auto-Increment?

**Decisão:** Usar UUID v4 como chave primária

**Justificativa:**
- **Segurança:** IDs sequenciais expõem volume de dados (ordem #1000 = 1000 ordens)
- **Distribuição:** UUIDs permitem geração distribuída sem conflitos
- **API REST:** URLs amigáveis (`/api/clientes/{uuid}` vs `/api/clientes/1`)
- **Integração:** Facilita merge de dados entre ambientes

**Trade-off Aceito:**
- Índices UUID consomem mais espaço (16 bytes vs 8 bytes BIGINT)
- Performance de join levemente inferior (mitigado com índices)

---

### 2. Por que Normalização 3NF?

**Decisão:** Modelo normalizado (3NF)

**Justificativa:**
- **Integridade:** Sem redundância, dados consistentes
- **Manutenção:** Atualizar valor de material em 1 lugar (não em todas as ordens)
- **Histórico:** Snapshot de valores nas tabelas pivot (ordem_material, ordem_servico)

**Exemplo - Snapshot de Valores:**
```sql
-- Material tem valor atual: R$ 50,00
SELECT valor FROM materiais WHERE uuid = 'material-123';
-- valor: 50.00

-- Ordem criada há 6 meses tem snapshot: R$ 45,00
SELECT valor FROM ordem_material WHERE material_uuid = 'material-123';
-- valor: 45.00 (preço na época)
```

---

### 3. Por que Tabelas Pivot ao invés de JSON?

**Decisão:** Tabelas pivot (`ordem_material`, `ordem_servico`) ao invés de colunas JSONB

**Justificativa:**
- **Queries:** JOINs são mais eficientes que queries JSON
- **Constraints:** Foreign keys garantem integridade
- **Indexação:** Índices tradicionais vs GIN/GIST (JSON)
- **ORM:** Eloquent relationships (`belongsToMany`)

**Alternativa Rejeitada:**
```sql
-- Rejeitado: JSON em coluna
CREATE TABLE ordens (
    uuid UUID,
    materiais JSONB  -- [{"uuid": "...", "quantidade": 2, "valor": 50}]
);

-- Problema: Sem foreign key, queries complexas, dificulta agregações
```

---

### 4. Por que Soft Deletes NÃO foi implementado?

**Decisão:** Hard delete (DELETE físico) ao invés de Soft Delete

**Justificativa:**
- **Simplicidade:** Sistema acadêmico, sem requisito de auditoria completa
- **Performance:** Queries mais simples (sem `WHERE deleted_at IS NULL`)
- **LGPD/GDPR:** Hard delete atende "direito ao esquecimento"

**Quando seria necessário:**
- Auditoria legal obrigatória
- Histórico de reversão de operações
- Regulamentações específicas do setor

---

### 5. Por que STATUS como VARCHAR ao invés de ENUM?

**Decisão:** `status VARCHAR(50) CHECK (status IN (...))`

**Justificativa:**
- **Flexibilidade:** Adicionar novos estados sem alterar tipo (ENUM exige ALTER TYPE)
- **Portabilidade:** CHECK funciona em todos SGBDs (ENUM é PostgreSQL-specific)
- **Migrations:** Laravel facilita alteração de CHECKs

**Estados Planejados (Futuro):**
- `CANCELADA` - Ordem cancelada pelo cliente
- `ORCAMENTO_ENVIADO` - Orçamento enviado por email
- `AGUARDANDO_PECAS` - Falta de estoque de materiais

---

## Índices e Performance

### Índices Criados

| Tabela | Índice | Tipo | Justificativa |
|--------|--------|------|---------------|
| clientes | cpf | UNIQUE | Busca por CPF (autenticação) |
| clientes | nome | BTREE | Busca por nome parcial |
| veiculos | placa | UNIQUE | Busca por placa |
| veiculos | cliente_uuid | BTREE | JOIN com clientes |
| ordens | cliente_uuid | BTREE | JOIN com clientes |
| ordens | veiculo_uuid | BTREE | JOIN com veículos |
| ordens | status | BTREE | Filtro por status (dashboard) |
| ordens | created_at | BTREE DESC | Ordenação cronológica |
| ordem_material | (ordem_uuid, material_uuid) | UNIQUE | Evita duplicação |
| ordem_servico | (ordem_uuid, servico_uuid) | UNIQUE | Evita duplicação |

### Queries Otimizadas

**Query 1: Listar ordens de um cliente com veículo**
```sql
SELECT o.*, v.placa, v.modelo, c.nome AS cliente_nome
FROM ordens o
INNER JOIN veiculos v ON o.veiculo_uuid = v.uuid
INNER JOIN clientes c ON o.cliente_uuid = c.uuid
WHERE c.cpf = '123.456.789-00'
ORDER BY o.created_at DESC
LIMIT 10;

-- Usa índices: clientes.cpf, ordens.cliente_uuid, ordens.created_at
```

**Query 2: Calcular valor total de uma ordem**
```sql
SELECT
    o.uuid,
    o.status,
    COALESCE(SUM(om.quantidade * om.valor), 0) +
    COALESCE(SUM(os.quantidade * os.valor), 0) AS valor_total
FROM ordens o
LEFT JOIN ordem_material om ON o.uuid = om.ordem_uuid
LEFT JOIN ordem_servico os ON o.uuid = os.ordem_uuid
WHERE o.uuid = 'ordem-uuid-123'
GROUP BY o.uuid, o.status;

-- Usa índices: ordem_material.ordem_uuid, ordem_servico.ordem_uuid
```

---

## Seeders (Dados Iniciais)

### Usuario Padrão
```php
// database/seeders/UsuarioSeeder.php
DB::table('usuarios')->insert([
    'uuid' => Str::uuid(),
    'nome' => 'Usuario SOAT',
    'email' => 'soat@example.com',
    'password' => Hash::make('padrao'),
    'tipo' => 'GESTOR',
]);
```

### Materiais Exemplo
```php
DB::table('materiais')->insert([
    ['uuid' => Str::uuid(), 'nome' => 'Óleo 5W40', 'valor' => 45.00],
    ['uuid' => Str::uuid(), 'nome' => 'Filtro de Óleo', 'valor' => 25.00],
    ['uuid' => Str::uuid(), 'nome' => 'Pastilha de Freio', 'valor' => 80.00],
]);
```

### Servicos Exemplo
```php
DB::table('servicos')->insert([
    ['uuid' => Str::uuid(), 'nome' => 'Troca de Óleo', 'valor' => 50.00],
    ['uuid' => Str::uuid(), 'nome' => 'Revisão Completa', 'valor' => 150.00],
    ['uuid' => Str::uuid(), 'nome' => 'Troca de Pastilhas', 'valor' => 100.00],
]);
```

---

## Migrações e Versionamento

**Ordem de Execução:**
1. `2024_01_01_000000_create_usuarios_table.php`
2. `2024_01_01_000001_create_clientes_table.php`
3. `2024_01_01_000002_create_veiculos_table.php`
4. `2024_01_01_000003_create_materiais_table.php`
5. `2024_01_01_000004_create_servicos_table.php`
6. `2024_01_01_000005_create_ordens_table.php`
7. `2024_01_01_000006_create_ordem_material_table.php`
8. `2024_01_01_000007_create_ordem_servico_table.php`

**Rollback Seguro:**
```bash
php artisan migrate:rollback --step=1  # Reverte última migration
php artisan migrate:fresh --seed       # Recria DB completo com seeders
```

---

## Backup e Recovery

**Backup Diário (Manual):**
```bash
kubectl exec deployment/lab-soat-postgres -n lab-soat -- \
  pg_dump -U postgres oficina_soat | gzip > backup-$(date +%Y%m%d).sql.gz
```

**Restore:**
```bash
gunzip -c backup-20250108.sql.gz | \
kubectl exec -i deployment/lab-soat-postgres -n lab-soat -- \
  psql -U postgres -d oficina_soat
```

---

## Referências

- [PostgreSQL 17 Documentation](https://www.postgresql.org/docs/17/)
- [Laravel Migrations](https://laravel.com/docs/12.x/migrations)
- [Database Normalization (3NF)](https://en.wikipedia.org/wiki/Third_normal_form)
- [ADR-001: Escolha do PostgreSQL](../adrs/ADR-001-postgresql.md)
- [RFC-002: Database Deployment Strategy](../rfcs/RFC-002-database-deployment-strategy.md)

## Palavras-Chave

`PostgreSQL` `Data Model` `ER Diagram` `Database Design` `Normalization` `3NF` `UUIDs` `Laravel Migrations` `Oficina SOAT`
