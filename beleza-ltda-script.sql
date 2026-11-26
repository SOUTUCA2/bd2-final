-- Cria o banco utilizado no estudo de caso.
CREATE DATABASE BelezaLtda;
GO

-- Define o banco de dados ativo para os comandos seguintes.
USE BelezaLtda;
GO

-- Guarda os codigos e nomes das regioes de venda.
CREATE TABLE Regiao (
    codigo VARCHAR(10) NOT NULL,
    nome VARCHAR(100) NOT NULL,

    CONSTRAINT PK_Regiao
        PRIMARY KEY (codigo)
);
GO


-- Registra os pontos estrategicos pertencentes a cada regiao.
CREATE TABLE PontoEstrategico (
    codigo VARCHAR(10) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    regiao_codigo VARCHAR(10) NOT NULL,

    CONSTRAINT PK_PontoEstrategico
        PRIMARY KEY (codigo),

    CONSTRAINT FK_PontoEstrategico_Regiao
        FOREIGN KEY (regiao_codigo)
        REFERENCES Regiao(codigo)
);
GO


-- Registra os vendedores e a regiao que cada um atende.
CREATE TABLE Vendedor (
    codigo VARCHAR(10) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    cpf VARCHAR(14) NOT NULL,
    telefone VARCHAR(20) NULL,
    regiao_codigo VARCHAR(10) NOT NULL,

    CONSTRAINT PK_Vendedor
        PRIMARY KEY (codigo),

    CONSTRAINT FK_Vendedor_Regiao
        FOREIGN KEY (regiao_codigo)
        REFERENCES Regiao(codigo)
);
GO


-- Mantem os dados de identificacao dos veiculos da frota.
CREATE TABLE Veiculo (
    codigo VARCHAR(10) NOT NULL,
    placa VARCHAR(8) NOT NULL,
    modelo VARCHAR(50) NOT NULL,
    ano INT NOT NULL,

    CONSTRAINT PK_Veiculo
        PRIMARY KEY (codigo)
);
GO


-- Historico diario de utilizacao dos veiculos.
-- A chave composta impede duas alocacoes do mesmo veiculo na mesma data.
CREATE TABLE AlocacaoVeiculo (
    data DATE NOT NULL,
    veiculo_codigo VARCHAR(10) NOT NULL,
    vendedor_codigo VARCHAR(10) NOT NULL,

    CONSTRAINT PK_AlocacaoVeiculo
        PRIMARY KEY (data, veiculo_codigo),

    CONSTRAINT FK_Alocacao_Veiculo
        FOREIGN KEY (veiculo_codigo)
        REFERENCES Veiculo(codigo),

    CONSTRAINT FK_Alocacao_Vendedor
        FOREIGN KEY (vendedor_codigo)
        REFERENCES Vendedor(codigo)
);
GO


-- Mantem o catalogo e indica quais produtos estao ativos para venda.
CREATE TABLE Produto (
    codigo VARCHAR(10) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    preco DECIMAL(10,2) NOT NULL,
    ativo BIT NOT NULL DEFAULT 1,

    CONSTRAINT PK_Produto
        PRIMARY KEY (codigo)
);
GO


-- Identifica os clientes que aparecem nas notas fiscais.
CREATE TABLE Cliente (
    codigo VARCHAR(10) NOT NULL,
    nome VARCHAR(100) NOT NULL,
    cpf_cnpj VARCHAR(18) NOT NULL,

    CONSTRAINT PK_Cliente
        PRIMARY KEY (codigo)
);
GO


-- Cada nota identifica o vendedor responsavel e o cliente atendido.
CREATE TABLE NotaFiscal (
    numero INT NOT NULL,
    data DATE NOT NULL,
    vendedor_codigo VARCHAR(10) NOT NULL,
    cliente_codigo VARCHAR(10) NOT NULL,

    CONSTRAINT PK_NotaFiscal
        PRIMARY KEY (numero),

    CONSTRAINT FK_NotaFiscal_Vendedor
        FOREIGN KEY (vendedor_codigo)
        REFERENCES Vendedor(codigo),

    CONSTRAINT FK_NotaFiscal_Cliente
        FOREIGN KEY (cliente_codigo)
        REFERENCES Cliente(codigo)
);
GO


-- Associa produtos as notas e preserva quantidade e preco praticado.
CREATE TABLE ItemNotaFiscal (
    nota_fiscal_numero INT NOT NULL,
    produto_codigo VARCHAR(10) NOT NULL,
    quantidade INT NOT NULL,
    preco_unitario DECIMAL(10,2) NOT NULL,

    CONSTRAINT PK_ItemNotaFiscal
        PRIMARY KEY (nota_fiscal_numero, produto_codigo),

    CONSTRAINT CK_ItemNotaFiscal_Quantidade
        CHECK (quantidade > 0),

    CONSTRAINT CK_ItemNotaFiscal_Preco
        CHECK (preco_unitario >= 0),

    CONSTRAINT FK_Item_NotaFiscal
        FOREIGN KEY (nota_fiscal_numero)
        REFERENCES NotaFiscal(numero),

    CONSTRAINT FK_Item_Produto
        FOREIGN KEY (produto_codigo)
        REFERENCES Produto(codigo)
);
GO


-- Impede a inclusão ou alteração de itens com produtos inativos.
CREATE TRIGGER TR_ItemNotaFiscal_ProdutoAtivo
ON ItemNotaFiscal
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN Produto p
            ON p.codigo = i.produto_codigo
        WHERE p.ativo = 0
    )
    BEGIN
        THROW 50001, 'Nao e permitido vender produtos inativos.', 1;
    END;
END;
GO


-- Regioes
INSERT INTO Regiao (codigo, nome) VALUES
('R01', 'Zona Norte'),
('R02', 'Zona Sul'),
('R03', 'Zona Leste');
GO


-- Pontos estrategicos
INSERT INTO PontoEstrategico (codigo, nome, regiao_codigo) VALUES
('P01', 'Shopping Norte', 'R01'),
('P02', 'Terminal Rodoviario', 'R01'),
('P03', 'Avenida Central', 'R02'),
('P04', 'Praca da Se', 'R02'),
('P05', 'Mercado Leste', 'R03');
GO


-- Vendedores
INSERT INTO Vendedor
    (codigo, nome, cpf, telefone, regiao_codigo)
VALUES
    ('V01', 'Carlos Souza', '111.111.111-11', '(11) 91111-1111', 'R01'),
    ('V02', 'Ana Ferreira', '222.222.222-22', '(11) 92222-2222', 'R01'),
    ('V03', 'Bruno Lima', '333.333.333-33', '(11) 93333-3333', 'R02'),
    ('V04', 'Diana Alves', '444.444.444-44', '(11) 94444-4444', 'R03');
GO


-- Veiculos
INSERT INTO Veiculo
    (codigo, placa, modelo, ano)
VALUES
    ('VE01', 'ABC1D23', 'Fiat Fiorino', 2022),
    ('VE02', 'XYZ4E56', 'Renault Kangoo', 2021),
    ('VE03', 'JKL7F89', 'Fiat Fiorino', 2023);
GO


-- Alocacao diaria de veiculos
INSERT INTO AlocacaoVeiculo
    (data, veiculo_codigo, vendedor_codigo)
VALUES
    (DATEADD(DAY, -10, CAST(GETDATE() AS DATE)), 'VE01', 'V01'),
    (DATEADD(DAY, -5, CAST(GETDATE() AS DATE)), 'VE01', 'V01'),
    (DATEADD(DAY, -10, CAST(GETDATE() AS DATE)), 'VE02', 'V03'),
    (DATEADD(DAY, -2, CAST(GETDATE() AS DATE)), 'VE03', 'V04'),
    (DATEADD(MONTH, -2, CAST(GETDATE() AS DATE)), 'VE01', 'V02'),
    (DATEADD(MONTH, -2, CAST(GETDATE() AS DATE)), 'VE02', 'V03'),
    (DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)), 'VE03', 'V04');
GO


-- Produtos
INSERT INTO Produto
    (codigo, nome, preco, ativo)
VALUES
    ('PR01', 'Shampoo Hidratante', 25.90, 1),
    ('PR02', 'Condicionador', 23.50, 1),
    ('PR03', 'Creme para Pentear', 18.00, 1),
    ('PR04', 'Perfume Floral', 89.90, 1),
    ('PR05', 'Sabonete Liquido', 15.00, 1),
    ('PR06', 'Linha Descontinuada', 10.00, 0);
GO


-- Clientes
INSERT INTO Cliente
    (codigo, nome, cpf_cnpj)
VALUES
    ('C01', 'Mariana Costa', '555.555.555-55'),
    ('C02', 'Loja Bela Flor', '12.345.678/0001-90'),
    ('C03', 'Roberto Nunes', '666.666.666-66');
GO


-- Notas fiscais
INSERT INTO NotaFiscal
    (numero, data, vendedor_codigo, cliente_codigo)
VALUES
    (1001, '2026-09-01', 'V01', 'C01'),
    (1002, '2026-09-02', 'V03', 'C02'),
    (1003, '2026-09-05', 'V04', 'C03'),
    (1004, '2026-09-10', 'V01', 'C02');
GO


-- Itens das notas fiscais
INSERT INTO ItemNotaFiscal
    (nota_fiscal_numero, produto_codigo, quantidade, preco_unitario)
VALUES
    (1001, 'PR01', 3, 25.90),
    (1001, 'PR02', 2, 23.50),
    (1002, 'PR04', 1, 89.90),
    (1002, 'PR05', 5, 15.00),
    (1003, 'PR01', 1, 25.90),
    (1004, 'PR03', 4, 18.00),
    (1004, 'PR04', 2, 89.90);
GO


-- A) Listar todos os pontos estrategicos de cada regiao.
-- Junta as regioes com seus respectivos pontos estrategicos.

SELECT
    r.nome AS regiao,
    p.nome AS ponto_estrategico
FROM Regiao r
INNER JOIN PontoEstrategico p
    ON p.regiao_codigo = r.codigo
ORDER BY
    r.nome,
    p.nome;
GO


-- B) Listar os nomes das regioes cadastradas.
-- Mostra as regioes em ordem alfabetica.

SELECT nome
FROM Regiao
ORDER BY nome;
GO


-- C) Listar os vendedores e os veiculos utilizados no ultimo mes.
-- Junta vendedores e veiculos e filtra as alocacoes do ultimo mes.

SELECT
    ve.nome AS vendedor,
    vc.modelo AS veiculo,
    vc.placa,
    av.data
FROM AlocacaoVeiculo av
INNER JOIN Vendedor ve
    ON ve.codigo = av.vendedor_codigo
INNER JOIN Veiculo vc
    ON vc.codigo = av.veiculo_codigo
WHERE av.data >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE))
  AND av.data < DATEADD(DAY, 1, CAST(GETDATE() AS DATE))
ORDER BY
    ve.nome,
    av.data;
GO


-- D) Listar os vendedores responsaveis por cada regiao.
-- Mostra as regioes e os vendedores associados a elas.

SELECT
    r.nome AS regiao,
    ve.nome AS vendedor
FROM Regiao r
INNER JOIN Vendedor ve
    ON ve.regiao_codigo = r.codigo
ORDER BY
    r.nome,
    ve.nome;
GO


-- E) Listar os produtos vendidos por um determinado vendedor.
-- Altere V01 para consultar outro vendedor.
-- DISTINCT evita que os produtos aparecam repetidos.

SELECT DISTINCT
    pr.nome AS produto,
    pr.preco
FROM ItemNotaFiscal it
INNER JOIN NotaFiscal nf
    ON nf.numero = it.nota_fiscal_numero
INNER JOIN Produto pr
    ON pr.codigo = it.produto_codigo
WHERE nf.vendedor_codigo = 'V01';
GO


-- F) Listar os vendedores que venderam um determinado produto.
-- Altere PR04 para consultar outro produto.
-- DISTINCT evita que os vendedores aparecam repetidos.

SELECT DISTINCT
    ve.nome AS vendedor
FROM ItemNotaFiscal it
INNER JOIN NotaFiscal nf
    ON nf.numero = it.nota_fiscal_numero
INNER JOIN Vendedor ve
    ON ve.codigo = nf.vendedor_codigo
WHERE it.produto_codigo = 'PR04';
GO


-- G) Listar os produtos que ainda nao foram vendidos.
-- NOT EXISTS verifica quais produtos nao aparecem nas notas fiscais.

SELECT
    pr.codigo,
    pr.nome,
    pr.ativo
FROM Produto pr
WHERE NOT EXISTS (
    SELECT 1
    FROM ItemNotaFiscal it
    WHERE it.produto_codigo = pr.codigo
);
GO


-- H) Mostrar o historico de utilizacao de um determinado veiculo.
-- Altere VE01 para consultar outro veiculo.

SELECT
    av.data,
    ve.nome AS vendedor
FROM AlocacaoVeiculo av
INNER JOIN Vendedor ve
    ON ve.codigo = av.vendedor_codigo
WHERE av.veiculo_codigo = 'VE01'
ORDER BY av.data;
GO


-- I) Mostrar a quantidade de itens de cada nota fiscal.
-- SUM soma as unidades dos itens e GROUP BY separa os resultados por nota.

SELECT
    nf.numero AS nota_fiscal,
    SUM(it.quantidade) AS total_itens
FROM NotaFiscal nf
INNER JOIN ItemNotaFiscal it
    ON it.nota_fiscal_numero = nf.numero
GROUP BY nf.numero
ORDER BY nf.numero;
GO
