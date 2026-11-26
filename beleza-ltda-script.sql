-- Cria o banco utilizado no estudo de caso.
CREATE DATABASE BelezaLtda;
GO

-- Define o banco de dados ativo para os comandos seguintes.
USE BelezaLtda;
GO

-- Guarda os codigos e nomes das regioes de venda.
CREATE TABLE Regiao (
    codigo VARCHAR(10) NOT NULL, -- Codigo que identifica a regiao sem repetir.
    nome VARCHAR(100) NOT NULL, -- Nome legivel da regiao de venda.

    CONSTRAINT PK_Regiao
        PRIMARY KEY (codigo) -- Garante que cada regiao tenha um codigo unico.
);
GO


-- Registra os pontos estrategicos pertencentes a cada regiao.
CREATE TABLE PontoEstrategico (
    codigo VARCHAR(10) NOT NULL, -- Identificador unico do ponto estrategico.
    nome VARCHAR(100) NOT NULL, -- Nome ou descricao do ponto de entrega.
    regiao_codigo VARCHAR(10) NOT NULL, -- Regiao onde o ponto esta localizado.

    CONSTRAINT PK_PontoEstrategico
        PRIMARY KEY (codigo), -- Identifica cada ponto estrategico.

    CONSTRAINT FK_PontoEstrategico_Regiao
        FOREIGN KEY (regiao_codigo) -- Liga o ponto a uma regiao cadastrada.
        REFERENCES Regiao(codigo) -- Impede associar o ponto a regiao inexistente.
);
GO


-- Registra os vendedores e a regiao que cada um atende.
CREATE TABLE Vendedor (
    codigo VARCHAR(10) NOT NULL, -- Identificador interno do vendedor.
    nome VARCHAR(100) NOT NULL, -- Nome completo do vendedor.
    cpf VARCHAR(14) NOT NULL, -- CPF armazenado com ou sem formatacao.
    telefone VARCHAR(20) NULL, -- Telefone opcional para contato.
    regiao_codigo VARCHAR(10) NOT NULL, -- Regiao pela qual o vendedor responde.

    CONSTRAINT PK_Vendedor
        PRIMARY KEY (codigo), -- Garante um codigo diferente para cada vendedor.

    CONSTRAINT FK_Vendedor_Regiao
        FOREIGN KEY (regiao_codigo) -- Define a regiao atendida pelo vendedor.
        REFERENCES Regiao(codigo) -- Exige que a regiao ja esteja cadastrada.
);
GO


-- Mantem os dados de identificacao dos veiculos da frota.
CREATE TABLE Veiculo (
    codigo VARCHAR(10) NOT NULL, -- Identificador interno do veiculo.
    placa VARCHAR(8) NOT NULL, -- Placa usada para identificar o veiculo na frota.
    modelo VARCHAR(50) NOT NULL, -- Modelo ou tipo do veiculo.
    ano INT NOT NULL, -- Ano de fabricacao do veiculo.

    CONSTRAINT PK_Veiculo
        PRIMARY KEY (codigo) -- Cada veiculo possui um codigo unico.
);
GO


-- Historico diario de utilizacao dos veiculos.
-- A chave composta impede duas alocacoes do mesmo veiculo na mesma data.
CREATE TABLE AlocacaoVeiculo (
    data DATE NOT NULL, -- Dia em que ocorreu a utilizacao do veiculo.
    veiculo_codigo VARCHAR(10) NOT NULL, -- Veiculo usado nessa alocacao.
    vendedor_codigo VARCHAR(10) NOT NULL, -- Vendedor responsavel pelo veiculo.

    CONSTRAINT PK_AlocacaoVeiculo
        PRIMARY KEY (data, veiculo_codigo), -- Evita alocar o mesmo veiculo duas vezes no mesmo dia.

    CONSTRAINT FK_Alocacao_Veiculo
        FOREIGN KEY (veiculo_codigo) -- Associa a alocacao a um veiculo.
        REFERENCES Veiculo(codigo), -- So permite veiculos cadastrados.

    CONSTRAINT FK_Alocacao_Vendedor
        FOREIGN KEY (vendedor_codigo) -- Associa a alocacao ao vendedor responsavel.
        REFERENCES Vendedor(codigo) -- So permite vendedores cadastrados.
);
GO


-- Mantem o catalogo e indica quais produtos estao ativos para venda.
CREATE TABLE Produto (
    codigo VARCHAR(10) NOT NULL, -- Identificador do produto no catalogo.
    nome VARCHAR(100) NOT NULL, -- Nome comercial do produto.
    preco DECIMAL(10,2) NOT NULL, -- Preco atual, com duas casas decimais.
    ativo BIT NOT NULL DEFAULT 1, -- 1 indica ativo; novos produtos ficam ativos por padrao.

    CONSTRAINT PK_Produto
        PRIMARY KEY (codigo) -- Evita cadastrar o mesmo codigo de produto mais de uma vez.
);
GO


-- Identifica os clientes que aparecem nas notas fiscais.
CREATE TABLE Cliente (
    codigo VARCHAR(10) NOT NULL, -- Identificador interno do cliente.
    nome VARCHAR(100) NOT NULL, -- Nome da pessoa ou razao social.
    cpf_cnpj VARCHAR(18) NOT NULL, -- Documento do cliente, podendo ser CPF ou CNPJ.

    CONSTRAINT PK_Cliente
        PRIMARY KEY (codigo) -- Cada cliente e identificado por um codigo unico.
);
GO


-- Cada nota identifica o vendedor responsavel e o cliente atendido.
CREATE TABLE NotaFiscal (
    numero INT NOT NULL, -- Numero que identifica a nota fiscal.
    data DATE NOT NULL, -- Data de emissao da nota.
    vendedor_codigo VARCHAR(10) NOT NULL, -- Vendedor responsavel pela venda.
    cliente_codigo VARCHAR(10) NOT NULL, -- Cliente que recebeu a nota.

    CONSTRAINT PK_NotaFiscal
        PRIMARY KEY (numero), -- Impede notas fiscais com numero repetido.

    CONSTRAINT FK_NotaFiscal_Vendedor
        FOREIGN KEY (vendedor_codigo) -- Relaciona a nota ao vendedor.
        REFERENCES Vendedor(codigo), -- Exige que o vendedor exista no cadastro.

    CONSTRAINT FK_NotaFiscal_Cliente
        FOREIGN KEY (cliente_codigo) -- Relaciona a nota ao cliente.
        REFERENCES Cliente(codigo) -- Exige que o cliente exista no cadastro.
);
GO


-- Associa produtos as notas e preserva quantidade e preco praticado.
CREATE TABLE ItemNotaFiscal (
    nota_fiscal_numero INT NOT NULL, -- Nota fiscal a que o item pertence.
    produto_codigo VARCHAR(10) NOT NULL, -- Produto vendido nessa linha da nota.
    quantidade INT NOT NULL, -- Numero de unidades vendidas.
    preco_unitario DECIMAL(10,2) NOT NULL, -- Preco por unidade no momento da venda.

    CONSTRAINT PK_ItemNotaFiscal
        PRIMARY KEY (nota_fiscal_numero, produto_codigo), -- Um produto aparece uma vez por nota.

    CONSTRAINT CK_ItemNotaFiscal_Quantidade
        CHECK (quantidade > 0), -- Nao aceita itens sem unidades vendidas.

    CONSTRAINT CK_ItemNotaFiscal_Preco
        CHECK (preco_unitario >= 0), -- Nao aceita preco unitario negativo.

    CONSTRAINT FK_Item_NotaFiscal
        FOREIGN KEY (nota_fiscal_numero) -- Liga a linha a sua nota fiscal.
        REFERENCES NotaFiscal(numero), -- So aceita notas fiscais cadastradas.

    CONSTRAINT FK_Item_Produto
        FOREIGN KEY (produto_codigo) -- Liga a linha ao produto vendido.
        REFERENCES Produto(codigo) -- So aceita produtos cadastrados.
);
GO


-- Impede a inclusão ou alteração de itens com produtos inativos.
CREATE TRIGGER TR_ItemNotaFiscal_ProdutoAtivo
ON ItemNotaFiscal
AFTER INSERT, UPDATE
AS
BEGIN
    -- Evita que mensagens de contagem de linhas interfiram no retorno do comando.
    SET NOCOUNT ON;

    -- A tabela inserted contem os itens incluidos ou alterados nesta operacao.
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN Produto p
            ON p.codigo = i.produto_codigo
        WHERE p.ativo = 0
    )
    BEGIN
        -- Cancela a operacao se algum item se referir a um produto inativo.
        THROW 50001, 'Nao e permitido vender produtos inativos.', 1;
    END;
END;
GO


-- Insere tres regioes de venda usadas como dados de exemplo.
INSERT INTO Regiao (codigo, nome) VALUES
('R01', 'Zona Norte'), -- Primeira regiao da base de exemplo.
('R02', 'Zona Sul'), -- Segunda regiao da base de exemplo.
('R03', 'Zona Leste'); -- Terceira regiao da base de exemplo.
GO


-- Insere pontos estrategicos e informa a regiao de cada um.
INSERT INTO PontoEstrategico (codigo, nome, regiao_codigo) VALUES
('P01', 'Shopping Norte', 'R01'), -- Ponto localizado na Zona Norte.
('P02', 'Terminal Rodoviario', 'R01'), -- Outro ponto da Zona Norte.
('P03', 'Avenida Central', 'R02'), -- Ponto localizado na Zona Sul.
('P04', 'Praca da Se', 'R02'), -- Outro ponto da Zona Sul.
('P05', 'Mercado Leste', 'R03'); -- Ponto localizado na Zona Leste.
GO


-- Cadastra vendedores e associa cada um a uma regiao atendida.
INSERT INTO Vendedor
    (codigo, nome, cpf, telefone, regiao_codigo)
VALUES
    ('V01', 'Carlos Souza', '111.111.111-11', '(11) 91111-1111', 'R01'), -- Vendedor da Zona Norte.
    ('V02', 'Ana Ferreira', '222.222.222-22', '(11) 92222-2222', 'R01'), -- Segunda vendedora da Zona Norte.
    ('V03', 'Bruno Lima', '333.333.333-33', '(11) 93333-3333', 'R02'), -- Vendedor da Zona Sul.
    ('V04', 'Diana Alves', '444.444.444-44', '(11) 94444-4444', 'R03'); -- Vendedora da Zona Leste.
GO


-- Cadastra veiculos que poderao ser alocados aos vendedores.
INSERT INTO Veiculo
    (codigo, placa, modelo, ano)
VALUES
    ('VE01', 'ABC1D23', 'Fiat Fiorino', 2022), -- Primeiro veiculo da frota.
    ('VE02', 'XYZ4E56', 'Renault Kangoo', 2021), -- Segundo veiculo da frota.
    ('VE03', 'JKL7F89', 'Fiat Fiorino', 2023); -- Terceiro veiculo da frota.
GO


-- Cria um historico de alocacoes em datas recentes e anteriores.
-- DATEADD calcula as datas em relacao ao dia em que o script for executado.
INSERT INTO AlocacaoVeiculo
    (data, veiculo_codigo, vendedor_codigo)
VALUES
    (DATEADD(DAY, -10, CAST(GETDATE() AS DATE)), 'VE01', 'V01'), -- VE01 usado por V01 ha dez dias.
    (DATEADD(DAY, -5, CAST(GETDATE() AS DATE)), 'VE01', 'V01'), -- Nova utilizacao de VE01 por V01.
    (DATEADD(DAY, -10, CAST(GETDATE() AS DATE)), 'VE02', 'V03'), -- VE02 usado por V03 ha dez dias.
    (DATEADD(DAY, -2, CAST(GETDATE() AS DATE)), 'VE03', 'V04'), -- VE03 usado por V04 ha dois dias.
    (DATEADD(MONTH, -2, CAST(GETDATE() AS DATE)), 'VE01', 'V02'), -- Registro historico de dois meses atras.
    (DATEADD(MONTH, -2, CAST(GETDATE() AS DATE)), 'VE02', 'V03'), -- Outro registro de dois meses atras.
    (DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)), 'VE03', 'V04'); -- Registro historico de um mes atras.
GO


-- Cadastra produtos ativos e um produto descontinuado para testes.
INSERT INTO Produto
    (codigo, nome, preco, ativo)
VALUES
    ('PR01', 'Shampoo Hidratante', 25.90, 1), -- Produto ativo.
    ('PR02', 'Condicionador', 23.50, 1), -- Produto ativo.
    ('PR03', 'Creme para Pentear', 18.00, 1), -- Produto ativo.
    ('PR04', 'Perfume Floral', 89.90, 1), -- Produto ativo.
    ('PR05', 'Sabonete Liquido', 15.00, 1), -- Produto ativo.
    ('PR06', 'Linha Descontinuada', 10.00, 0); -- Produto inativo, usado para validar a regra do trigger.
GO


-- Cadastra clientes pessoa fisica e pessoa juridica.
INSERT INTO Cliente
    (codigo, nome, cpf_cnpj)
VALUES
    ('C01', 'Mariana Costa', '555.555.555-55'), -- Cliente pessoa fisica.
    ('C02', 'Loja Bela Flor', '12.345.678/0001-90'), -- Cliente pessoa juridica.
    ('C03', 'Roberto Nunes', '666.666.666-66'); -- Outro cliente pessoa fisica.
GO


-- Registra notas fiscais de exemplo, com vendedor e cliente responsaveis.
INSERT INTO NotaFiscal
    (numero, data, vendedor_codigo, cliente_codigo)
VALUES
    (1001, '2026-09-01', 'V01', 'C01'), -- Nota do vendedor V01 para o cliente C01.
    (1002, '2026-09-02', 'V03', 'C02'), -- Nota do vendedor V03 para o cliente C02.
    (1003, '2026-09-05', 'V04', 'C03'), -- Nota do vendedor V04 para o cliente C03.
    (1004, '2026-09-10', 'V01', 'C02'); -- Outra nota emitida pelo vendedor V01.
GO


-- Registra os produtos, quantidades e precos praticados em cada nota.
INSERT INTO ItemNotaFiscal
    (nota_fiscal_numero, produto_codigo, quantidade, preco_unitario)
VALUES
    (1001, 'PR01', 3, 25.90), -- Tres unidades de PR01 na nota 1001.
    (1001, 'PR02', 2, 23.50), -- Duas unidades de PR02 na nota 1001.
    (1002, 'PR04', 1, 89.90), -- Uma unidade de PR04 na nota 1002.
    (1002, 'PR05', 5, 15.00), -- Cinco unidades de PR05 na nota 1002.
    (1003, 'PR01', 1, 25.90), -- Uma unidade de PR01 na nota 1003.
    (1004, 'PR03', 4, 18.00), -- Quatro unidades de PR03 na nota 1004.
    (1004, 'PR04', 2, 89.90); -- Duas unidades de PR04 na nota 1004.
GO


-- A) Listar todos os pontos estrategicos de cada regiao.
-- Junta as regioes com seus respectivos pontos estrategicos.

SELECT
    r.nome AS regiao, -- Exibe o nome da regiao.
    p.nome AS ponto_estrategico -- Exibe o ponto associado a ela.
FROM Regiao r -- Usa a regiao como tabela principal.
INNER JOIN PontoEstrategico p -- Acrescenta os pontos estrategicos cadastrados.
    ON p.regiao_codigo = r.codigo -- Relaciona cada ponto a sua regiao.
ORDER BY
    r.nome, -- Ordena primeiro pelo nome da regiao.
    p.nome; -- Depois ordena pelo nome do ponto.
GO


-- B) Listar os nomes das regioes cadastradas.
-- Mostra as regioes em ordem alfabetica.

SELECT nome -- Retorna apenas os nomes das regioes.
FROM Regiao -- Consulta o cadastro de regioes.
ORDER BY nome; -- Apresenta os resultados em ordem alfabetica.
GO


-- C) Listar os vendedores e os veiculos utilizados no ultimo mes.
-- Junta vendedores e veiculos e filtra as alocacoes do ultimo mes.

SELECT
    ve.nome AS vendedor, -- Identifica quem utilizou o veiculo.
    vc.modelo AS veiculo, -- Informa o modelo utilizado.
    vc.placa, -- Exibe a placa do veiculo.
    av.data -- Exibe a data da alocacao.
FROM AlocacaoVeiculo av -- Parte do historico de utilizacao.
INNER JOIN Vendedor ve -- Busca os dados do vendedor associado.
    ON ve.codigo = av.vendedor_codigo -- Liga a alocacao ao vendedor.
INNER JOIN Veiculo vc -- Busca os dados do veiculo associado.
    ON vc.codigo = av.veiculo_codigo -- Liga a alocacao ao veiculo.
WHERE av.data >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)) -- Inclui datas a partir de um mes atras.
  AND av.data < DATEADD(DAY, 1, CAST(GETDATE() AS DATE)) -- Inclui o dia atual e exclui datas futuras.
ORDER BY
    ve.nome, -- Agrupa visualmente os registros por vendedor.
    av.data; -- Ordena as alocacoes de cada vendedor por data.
GO


-- D) Listar os vendedores responsaveis por cada regiao.
-- Mostra as regioes e os vendedores associados a elas.

SELECT
    r.nome AS regiao, -- Exibe a regiao atendida.
    ve.nome AS vendedor -- Exibe o vendedor responsavel.
FROM Regiao r -- Consulta as regioes cadastradas.
INNER JOIN Vendedor ve -- Junta os vendedores vinculados.
    ON ve.regiao_codigo = r.codigo -- Faz a correspondencia entre vendedor e regiao.
ORDER BY
    r.nome, -- Ordena as regioes.
    ve.nome; -- Ordena os vendedores dentro de cada regiao.
GO


-- E) Listar os produtos vendidos por um determinado vendedor.
-- Altere V01 para consultar outro vendedor.
-- DISTINCT evita que os produtos aparecam repetidos.

SELECT DISTINCT
    pr.nome AS produto, -- Nome do produto vendido pelo vendedor selecionado.
    pr.preco -- Preco atual cadastrado no catalogo.
FROM ItemNotaFiscal it -- Localiza os produtos presentes nas notas.
INNER JOIN NotaFiscal nf -- Recupera o vendedor responsavel por cada nota.
    ON nf.numero = it.nota_fiscal_numero -- Liga cada item a sua nota fiscal.
INNER JOIN Produto pr -- Recupera os dados do produto vendido.
    ON pr.codigo = it.produto_codigo -- Liga cada item ao produto do catalogo.
WHERE nf.vendedor_codigo = 'V01'; -- Troque V01 pelo codigo do vendedor desejado.
GO


-- F) Listar os vendedores que venderam um determinado produto.
-- Altere PR04 para consultar outro produto.
-- DISTINCT evita que os vendedores aparecam repetidos.

SELECT DISTINCT
    ve.nome AS vendedor -- Mostra cada vendedor uma unica vez.
FROM ItemNotaFiscal it -- Localiza notas que contem produtos vendidos.
INNER JOIN NotaFiscal nf -- Recupera os dados da nota correspondente.
    ON nf.numero = it.nota_fiscal_numero -- Liga o item a sua nota fiscal.
INNER JOIN Vendedor ve -- Recupera o nome do vendedor da nota.
    ON ve.codigo = nf.vendedor_codigo -- Liga a nota ao vendedor responsavel.
WHERE it.produto_codigo = 'PR04'; -- Troque PR04 pelo codigo do produto desejado.
GO


-- G) Listar os produtos que ainda nao foram vendidos.
-- NOT EXISTS verifica quais produtos nao aparecem nas notas fiscais.

SELECT
    pr.codigo, -- Codigo que identifica o produto.
    pr.nome, -- Nome do produto nao encontrado nas vendas.
    pr.ativo -- Indica se o produto ainda esta ativo.
FROM Produto pr -- Parte do catalogo completo de produtos.
WHERE NOT EXISTS (
    SELECT 1
    FROM ItemNotaFiscal it -- Verifica os itens das notas fiscais.
    WHERE it.produto_codigo = pr.codigo -- Procura uma venda para o produto atual.
); -- Retorna o produto somente quando nenhuma venda for encontrada.
GO


-- H) Mostrar o historico de utilizacao de um determinado veiculo.
-- Altere VE01 para consultar outro veiculo.

SELECT
    av.data, -- Data em que o veiculo foi utilizado.
    ve.nome AS vendedor -- Vendedor que utilizou o veiculo nesse dia.
FROM AlocacaoVeiculo av -- Consulta os registros de alocacao.
INNER JOIN Vendedor ve -- Busca o nome associado ao codigo do vendedor.
    ON ve.codigo = av.vendedor_codigo -- Relaciona a alocacao ao vendedor.
WHERE av.veiculo_codigo = 'VE01' -- Troque VE01 pelo codigo do veiculo desejado.
ORDER BY av.data; -- Apresenta o historico do mais antigo para o mais recente.
GO


-- I) Mostrar a quantidade de itens de cada nota fiscal.
-- SUM soma as unidades dos itens e GROUP BY separa os resultados por nota.

SELECT
    nf.numero AS nota_fiscal, -- Numero da nota que sera resumida.
    SUM(it.quantidade) AS total_itens -- Soma as unidades de todos os itens da nota.
FROM NotaFiscal nf -- Considera as notas fiscais cadastradas.
INNER JOIN ItemNotaFiscal it -- Acessa os produtos e quantidades de cada nota.
    ON it.nota_fiscal_numero = nf.numero -- Relaciona cada item a sua nota.
GROUP BY nf.numero -- Calcula uma soma separada para cada nota fiscal.
ORDER BY nf.numero; -- Exibe as notas em ordem numerica.
GO
