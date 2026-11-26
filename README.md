# Estudo de Caso — Indústria Beleza Ltda

---

## 1. Levantamento de Entidades e Relacionamentos (MER — texto)

| Entidade | Descrição | Atributos principais |
|---|---|---|
| **Região** | Área de venda dividida pelo mercado consumidor | codigo (PK), nome |
| **Ponto Estratégico** | Local de entrega dentro de uma região | codigo (PK), nome, regiao_codigo (FK) |
| **Vendedor** | Responsável por cobrir uma região e vender produtos | codigo (PK), nome, cpf, telefone, regiao_codigo (FK) |
| **Veículo** | Veículo da frota própria | codigo (PK), placa, modelo, ano |
| **Alocação Veículo/Dia** | Registro diário de qual vendedor está responsável por qual veículo | data, veiculo_codigo (FK), vendedor_codigo (FK) |
| **Produto** | Item da tabela de produtos | codigo (PK), nome, preco, ativo |
| **Cliente** | Cliente identificado na nota fiscal | codigo (PK), nome, cpf_cnpj |
| **Nota Fiscal** | Comprovante de venda | numero (PK), data, vendedor_codigo (FK), cliente_codigo (FK) |
| **Item Nota Fiscal** | Produto, quantidade e preço praticado em cada nota | nota_fiscal_numero (PK, FK), produto_codigo (PK, FK), quantidade, preco_unitario |

### Relacionamentos (cardinalidades)

- **Região (1) — (N) Ponto Estratégico**: uma região tem vários pontos; um ponto pertence a uma única região (regiões não compartilham pontos).
- **Região (1) — (N) Vendedor**: uma região pode ser coberta por vários vendedores; cada vendedor cobre exatamente uma região.
- **Vendedor (1) — (N) Alocação Veículo/Dia** e **Veículo (1) — (N) Alocação Veículo/Dia**: a cada dia, um veículo fica sob responsabilidade de um vendedor (histórico diário — chave composta data + veículo).
- **Vendedor (1) — (N) Nota Fiscal**: um vendedor emite várias notas fiscais.
- **Cliente (1) — (N) Nota Fiscal**: um cliente pode aparecer em várias notas.
- **Nota Fiscal (1) — (N) Item Nota Fiscal (N) — (1) Produto**: relacionamento N:N entre Nota Fiscal e Produto, resolvido pela entidade associativa Item Nota Fiscal, com quantidade e preço unitário registrado na venda.

---

## 2. DER (Diagrama Entidade-Relacionamento) — Mermaid

```mermaid
erDiagram
    REGIAO ||--o{ PONTO_ESTRATEGICO : "possui"
    REGIAO ||--o{ VENDEDOR : "e coberta por"
    VENDEDOR ||--o{ ALOCACAO_VEICULO : "responde por"
    VEICULO ||--o{ ALOCACAO_VEICULO : "e alocado em"
    VENDEDOR ||--o{ NOTA_FISCAL : "emite"
    CLIENTE ||--o{ NOTA_FISCAL : "consta em"
    NOTA_FISCAL ||--o{ ITEM_NOTA_FISCAL : "contem"
    PRODUTO ||--o{ ITEM_NOTA_FISCAL : "e vendido em"

    REGIAO {
        string codigo PK
        string nome
    }
    PONTO_ESTRATEGICO {
        string codigo PK
        string nome
        string regiao_codigo FK
    }
    VENDEDOR {
        string codigo PK
        string nome
        string cpf
        string telefone
        string regiao_codigo FK
    }
    VEICULO {
        string codigo PK
        string placa
        string modelo
        int ano
    }
    ALOCACAO_VEICULO {
        date data PK
        string veiculo_codigo PK_FK
        string vendedor_codigo FK
    }
    PRODUTO {
        string codigo PK
        string nome
        decimal preco
        bit ativo
    }
    CLIENTE {
        string codigo PK
        string nome
        string cpf_cnpj
    }
    NOTA_FISCAL {
        int numero PK
        date data
        string vendedor_codigo FK
        string cliente_codigo FK
    }
    ITEM_NOTA_FISCAL {
        int nota_fiscal_numero PK_FK
        string produto_codigo PK_FK
        int quantidade
        decimal preco_unitario
    }
```

---

## 3. Modelo Lógico Relacional

```
Regiao(codigo PK, nome)

PontoEstrategico(codigo PK, nome, regiao_codigo FK -> Regiao.codigo)

Vendedor(codigo PK, nome, cpf, telefone, regiao_codigo FK -> Regiao.codigo)

Veiculo(codigo PK, placa, modelo, ano)

AlocacaoVeiculo(data PK, veiculo_codigo PK FK -> Veiculo.codigo,
                 vendedor_codigo FK -> Vendedor.codigo)

Produto(codigo PK, nome, preco, ativo)

Cliente(codigo PK, nome, cpf_cnpj)

NotaFiscal(numero PK, data, vendedor_codigo FK -> Vendedor.codigo,
           cliente_codigo FK -> Cliente.codigo)

ItemNotaFiscal(nota_fiscal_numero PK FK -> NotaFiscal.numero,
               produto_codigo PK FK -> Produto.codigo,
               quantidade, preco_unitario)
```

Todas as tabelas estão na 3ª Forma Normal (3FN): não há dependências transitivas, e as chaves compostas (AlocacaoVeiculo, ItemNotaFiscal) resolvem os relacionamentos N:N/históricos sem redundância. O `preco_unitario` em `ItemNotaFiscal` registra o preço no momento da venda, sem depender de alterações futuras no preço atual do produto. O script também impede a inclusão de produtos inativos nos itens de notas fiscais e valida que `quantidade > 0` e `preco_unitario >= 0`.

---

## 4. Script SQL

O arquivo principal [beleza-ltda-script.sql](./beleza-ltda-script.sql) contém:
1. Criação do banco e das tabelas (DDL), incluindo chaves, validações e relacionamentos.
2. Dados de exemplo (DML), com alocações recentes para que a consulta do último mês retorne resultados.
3. As 9 consultas (A a I) pedidas no enunciado, prontas para rodar no SQL Server Management Studio (SSMS), com comentários explicando sua finalidade.

Execute o script no SQL Server Management Studio. A consulta C usa uma janela móvel de um mês até a data atual; a consulta I soma as unidades dos itens de cada nota fiscal.

---

## 5. Instalação e execução do sistema

O projeto inclui um aplicativo desktop em Java Swing conectado ao SQL Server por JDBC. A interface executa as consultas A a I; E, F e H pedem um código de vendedor, produto ou veículo. Os resultados aparecem em uma tabela.

### Requisitos

- SQL Server Express (ou outra edição do SQL Server) e SQL Server Management Studio (SSMS).
- JDK 11 ou superior e Apache NetBeans. Maven é usado para resolver o driver JDBC; o NetBeans pode gerenciá-lo pelo `pom.xml`.

### Passo 1 — Instalar e iniciar o SQL Server

O XAMPP não é necessário. Instale o mecanismo do SQL Server e o SSMS. O serviço do SQL Server precisa estar em execução; o SSMS pode ser fechado depois da configuração.

Se estiver usando uma instância nomeada, como `SQLEXPRESS`, abra o **SQL Server Configuration Manager**:

1. Abra **Configuração de Rede do SQL Server > Protocolos para `<nome-da-instância>`** e habilite **TCP/IP**.
2. Em **Serviços do SQL Server**, inicie **SQL Server Browser**.
3. Reinicie o serviço **SQL Server (`<nome-da-instância>`)**.

Os nomes da instância e do computador dependem da instalação. `SQLEXPRESS` é apenas um exemplo.

### Passo 2 — Criar e preencher o banco

1. Abra o SSMS e conecte ao servidor. Para a primeira configuração, **Autenticação do Windows** costuma ser a opção mais simples.
2. Abra [beleza-ltda-script.sql](./beleza-ltda-script.sql) e execute com **F5**.
3. O script cria o banco `BelezaLtda`, as tabelas e os dados de exemplo.

Execute o script uma vez em uma instalação nova. Se `BelezaLtda` já existir e contiver dados, não o execute novamente: ele começa com `CREATE DATABASE`.

### Passo 3 — Criar o login usado pelo Java

O aplicativo consulta dados, então basta conceder permissão de leitura:

1. No SSMS, clique com o botão direito no servidor > **Propriedades > Segurança** e selecione **Modo de Autenticação do SQL Server e do Windows**. Se já estiver selecionado, não altere.
2. Se alterou o modo, reinicie o serviço do SQL Server.
3. Em **Segurança > Logons > Novo Logon**, crie um login usando **Autenticação SQL do Server**, por exemplo `beleza_app`, e defina uma senha.
4. Em **Mapeamento de Usuário**, selecione `BelezaLtda` e marque a função `db_datareader`.
5. Desmarque **O usuário deve alterar a senha no próximo logon** e confirme.

Não grave a senha no código nem a publique no repositório. Cada pessoa/instância pode usar seu próprio login.

### Passo 4 — Abrir e executar no NetBeans

1. No NetBeans, escolha **Arquivo > Abrir Projeto** e selecione a pasta `java-app` (a que contém `pom.xml`).
2. Aguarde o NetBeans carregar as dependências Maven.
3. Clique com o botão direito no projeto > **Limpar e Construir**; depois escolha **Executar**. Se pedir a classe principal, use `br.com.belezaltda.App`.
4. Na janela do sistema, clique **Configurar conexão** e informe usuário, senha e URL JDBC.

Exemplo para SQL Server Express local:

```text
jdbc:sqlserver://localhost;instanceName=SQLEXPRESS;databaseName=BelezaLtda;encrypt=true;trustServerCertificate=true
```

Troque `localhost` e `SQLEXPRESS` pelos dados do servidor/instância usados nesse computador. Para uma instância configurada em uma porta fixa, a URL pode usar `jdbc:sqlserver://<servidor>:<porta>;databaseName=BelezaLtda;...`. A URL é configurável; não precisa ser igual em todos os computadores.

Quando o status indicar **Conectado ao banco BelezaLtda**, escolha uma consulta e clique **Executar consulta**. Também é possível executar pelo Maven em um terminal aberto na pasta `java-app` com `mvn clean compile exec:java`.

### Solução de problemas

- **Conexão recusada na porta 1433:** confira a URL; para uma instância nomeada, use `instanceName` em vez de presumir a porta 1433.
- **Timeout ao localizar uma instância nomeada / UDP 1434:** inicie **SQL Server Browser**.
- **Servidor não escuta em TCP/IP:** habilite TCP/IP em **Protocolos para `<nome-da-instância>`** e reinicie o serviço SQL Server.
- **Falha de logon:** confira usuário e senha, confirme o modo de autenticação misto e a permissão `db_datareader`.

`trustServerCertificate=true` é apropriado para desenvolvimento local
