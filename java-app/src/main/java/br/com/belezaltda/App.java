package br.com.belezaltda;

import java.awt.BorderLayout;
import java.awt.Color;
import java.awt.Component;
import java.awt.Dimension;
import java.awt.Font;
import java.awt.GridLayout;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;
import javax.swing.BorderFactory;
import javax.swing.JButton;
import javax.swing.JFrame;
import javax.swing.JLabel;
import javax.swing.JOptionPane;
import javax.swing.JPanel;
import javax.swing.JPasswordField;
import javax.swing.JScrollPane;
import javax.swing.JTable;
import javax.swing.JTextField;
import javax.swing.SwingConstants;
import javax.swing.SwingUtilities;
import javax.swing.SwingWorker;
import javax.swing.table.DefaultTableModel;

public final class App {
    private static final String DEFAULT_URL =
            "jdbc:sqlserver://localhost;instanceName=SQLEXPRESS;databaseName=BelezaLtda;"
                    + "encrypt=true;trustServerCertificate=true";
    private static final Color NAV_BACKGROUND = new Color(28, 43, 68);
    private static final Color NAV_BUTTON = new Color(42, 60, 88);
    private static final Color NAV_SELECTED = new Color(55, 112, 190);
    private static final Color PAGE_BACKGROUND = new Color(245, 247, 250);
    private static final Color TEXT_COLOR = new Color(36, 48, 65);
    private static final Color MUTED_COLOR = new Color(104, 117, 135);
    private static final Font UI_FONT = new Font("Segoe UI", Font.PLAIN, 14);

    private enum Report {
        PONTOS('A', "Pontos estratégicos por região",
                "SELECT r.nome AS regiao, p.nome AS ponto_estrategico "
                        + "FROM Regiao r "
                        + "INNER JOIN PontoEstrategico p ON p.regiao_codigo = r.codigo "
                        + "ORDER BY r.nome, p.nome", null),
        REGIOES('B', "Regiões cadastradas",
                "SELECT nome FROM Regiao ORDER BY nome", null),
        VEICULOS('C', "Veículos utilizados no último mês",
                "SELECT ve.nome AS vendedor, vc.modelo AS veiculo, vc.placa, av.data "
                        + "FROM AlocacaoVeiculo av "
                        + "INNER JOIN Vendedor ve ON ve.codigo = av.vendedor_codigo "
                        + "INNER JOIN Veiculo vc ON vc.codigo = av.veiculo_codigo "
                        + "WHERE av.data >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)) "
                        + "AND av.data < DATEADD(DAY, 1, CAST(GETDATE() AS DATE)) "
                        + "ORDER BY ve.nome, av.data", null),
        VENDEDORES_REGIAO('D', "Vendedores responsáveis por região",
                "SELECT r.nome AS regiao, ve.nome AS vendedor "
                        + "FROM Regiao r "
                        + "INNER JOIN Vendedor ve ON ve.regiao_codigo = r.codigo "
                        + "ORDER BY r.nome, ve.nome", null),
        PRODUTOS_VENDEDOR('E', "Produtos vendidos por vendedor",
                "SELECT DISTINCT pr.nome AS produto "
                        + "FROM ItemNotaFiscal it "
                        + "INNER JOIN NotaFiscal nf ON nf.numero = it.nota_fiscal_numero "
                        + "INNER JOIN Produto pr ON pr.codigo = it.produto_codigo "
                        + "WHERE nf.vendedor_codigo = ? "
                        + "ORDER BY pr.nome", "Código do vendedor"),
        VENDEDORES_PRODUTO('F', "Vendedores que venderam um produto",
                "SELECT DISTINCT ve.nome AS vendedor "
                        + "FROM ItemNotaFiscal it "
                        + "INNER JOIN NotaFiscal nf ON nf.numero = it.nota_fiscal_numero "
                        + "INNER JOIN Vendedor ve ON ve.codigo = nf.vendedor_codigo "
                        + "WHERE it.produto_codigo = ? "
                        + "ORDER BY ve.nome", "Código do produto"),
        PRODUTOS_NAO_VENDIDOS('G', "Produtos ainda não vendidos",
                "SELECT pr.codigo, pr.nome, pr.ativo "
                        + "FROM Produto pr "
                        + "WHERE NOT EXISTS ("
                        + "SELECT 1 FROM ItemNotaFiscal it "
                        + "WHERE it.produto_codigo = pr.codigo"
                        + ") "
                        + "ORDER BY pr.nome", null),
        HISTORICO_VEICULO('H', "Histórico de utilização de veículo",
                "SELECT av.data, ve.nome AS vendedor "
                        + "FROM AlocacaoVeiculo av "
                        + "INNER JOIN Vendedor ve ON ve.codigo = av.vendedor_codigo "
                        + "WHERE av.veiculo_codigo = ? "
                        + "ORDER BY av.data", "Código do veículo"),
        ITENS_NOTA('I', "Quantidade de unidades por nota fiscal",
                "SELECT nf.numero AS nota_fiscal, SUM(it.quantidade) AS total_itens "
                        + "FROM NotaFiscal nf "
                        + "INNER JOIN ItemNotaFiscal it "
                        + "ON it.nota_fiscal_numero = nf.numero "
                        + "GROUP BY nf.numero "
                        + "ORDER BY nf.numero", null);

        private final char letter;
        private final String title;
        private final String sql;
        private final String parameterLabel;

        Report(char letter, String title, String sql, String parameterLabel) {
            this.letter = letter;
            this.title = title;
            this.sql = sql;
            this.parameterLabel = parameterLabel;
        }
    }

    private final JFrame frame = new JFrame("Indústria Beleza Ltda. — Sistema de Vendas");
    private final JLabel pageTitle = new JLabel();
    private final JLabel filterLabel = new JLabel();
    private final JLabel statusLabel = new JLabel("Aguardando conexão...");
    private final JTextField filterField = new JTextField(22);
    private final JButton executeButton = new JButton("Executar consulta");
    private final JButton connectionButton = new JButton("Configurar conexão");
    private final JTable resultsTable = new JTable();
    private final List<JButton> reportButtons = new ArrayList<>();
    private String databaseUrl = environmentOrDefault("DB_URL", DEFAULT_URL);
    private String databaseUser = environmentValue("DB_USER");
    private char[] databasePassword = environmentPassword();
    private Report selectedReport = Report.PONTOS;

    private App() {
        configureFrame();
        selectReport(Report.PONTOS);
        frame.setVisible(true);
        testConnection();
    }

    public static void main(String[] args) {
        SwingUtilities.invokeLater(App::new);
    }

    private void configureFrame() {
        frame.setDefaultCloseOperation(JFrame.EXIT_ON_CLOSE);
        frame.setMinimumSize(new Dimension(900, 600));
        frame.setSize(1120, 720);
        frame.setLocationRelativeTo(null);
        frame.setLayout(new BorderLayout());
        frame.add(createSidebar(), BorderLayout.WEST);
        frame.add(createWorkspace(), BorderLayout.CENTER);
    }

    private JPanel createSidebar() {
        JPanel sidebar = new JPanel();
        sidebar.setBackground(NAV_BACKGROUND);
        sidebar.setPreferredSize(new Dimension(270, 0));
        sidebar.setBorder(BorderFactory.createEmptyBorder(24, 16, 20, 16));
        sidebar.setLayout(new javax.swing.BoxLayout(sidebar, javax.swing.BoxLayout.Y_AXIS));

        JLabel brand = new JLabel("BELEZA LTDA.");
        brand.setForeground(Color.WHITE);
        brand.setFont(new Font("Segoe UI", Font.BOLD, 21));
        brand.setBorder(BorderFactory.createEmptyBorder(4, 10, 4, 0));
        sidebar.add(brand);

        JLabel caption = new JLabel("Sistema de vendas");
        caption.setForeground(new Color(190, 202, 219));
        caption.setFont(UI_FONT);
        caption.setBorder(BorderFactory.createEmptyBorder(5, 10, 25, 0));
        sidebar.add(caption);

        for (Report report : Report.values()) {
            JButton button = new JButton(report.letter + "  " + report.title);
            button.setFont(new Font("Segoe UI", Font.PLAIN, 13));
            button.setForeground(Color.WHITE);
            button.setBackground(NAV_BUTTON);
            button.setOpaque(true);
            button.setContentAreaFilled(true);
            button.setBorderPainted(false);
            button.setFocusPainted(false);
            button.setBorder(BorderFactory.createEmptyBorder(11, 12, 11, 8));
            button.setHorizontalAlignment(SwingConstants.LEFT);
            button.setMaximumSize(new Dimension(Integer.MAX_VALUE, 44));
            button.setAlignmentX(Component.LEFT_ALIGNMENT);
            button.addActionListener(event -> selectReport(report));
            reportButtons.add(button);
            sidebar.add(button);
            sidebar.add(javax.swing.Box.createVerticalStrut(7));
        }

        return sidebar;
    }

    private JPanel createWorkspace() {
        JPanel workspace = new JPanel(new BorderLayout(0, 18));
        workspace.setBackground(PAGE_BACKGROUND);
        workspace.setBorder(BorderFactory.createEmptyBorder(24, 28, 20, 28));
        workspace.add(createHeader(), BorderLayout.NORTH);
        workspace.add(createResultsPanel(), BorderLayout.CENTER);
        workspace.add(createStatusPanel(), BorderLayout.SOUTH);
        return workspace;
    }

    private JPanel createHeader() {
        JPanel header = new JPanel(new BorderLayout(0, 16));
        header.setOpaque(false);

        JPanel heading = new JPanel(new BorderLayout());
        heading.setOpaque(false);
        pageTitle.setFont(new Font("Segoe UI", Font.BOLD, 25));
        pageTitle.setForeground(TEXT_COLOR);
        heading.add(pageTitle, BorderLayout.CENTER);
        connectionButton.setFont(UI_FONT);
        connectionButton.addActionListener(event -> configureConnection());
        heading.add(connectionButton, BorderLayout.EAST);
        header.add(heading, BorderLayout.NORTH);

        JPanel controls = new JPanel(new BorderLayout(14, 0));
        controls.setBackground(Color.WHITE);
        controls.setBorder(BorderFactory.createCompoundBorder(
                BorderFactory.createLineBorder(new Color(224, 229, 236)),
                BorderFactory.createEmptyBorder(14, 16, 14, 16)));

        JPanel filterPanel = new JPanel(new BorderLayout(12, 0));
        filterPanel.setOpaque(false);
        filterLabel.setFont(new Font("Segoe UI", Font.BOLD, 12));
        filterLabel.setForeground(MUTED_COLOR);
        filterField.setFont(UI_FONT);
        filterField.setPreferredSize(new Dimension(280, 34));
        filterPanel.add(filterLabel, BorderLayout.WEST);
        filterPanel.add(filterField, BorderLayout.CENTER);
        controls.add(filterPanel, BorderLayout.CENTER);

        executeButton.setFont(new Font("Segoe UI", Font.BOLD, 13));
        executeButton.setForeground(Color.WHITE);
        executeButton.setBackground(NAV_SELECTED);
        executeButton.setOpaque(true);
        executeButton.setContentAreaFilled(true);
        executeButton.setBorderPainted(false);
        executeButton.setFocusPainted(false);
        executeButton.setPreferredSize(new Dimension(170, 42));
        executeButton.setBorder(BorderFactory.createEmptyBorder(10, 18, 10, 18));
        executeButton.addActionListener(event -> executeReport());
        controls.add(executeButton, BorderLayout.EAST);
        connectionButton.setForeground(TEXT_COLOR);
        connectionButton.setBackground(new Color(225, 233, 244));
        connectionButton.setOpaque(true);
        connectionButton.setContentAreaFilled(true);
        connectionButton.setBorderPainted(false);
        connectionButton.setFocusPainted(false);
        connectionButton.setPreferredSize(new Dimension(170, 36));
        header.add(controls, BorderLayout.CENTER);
        return header;
    }

    private JPanel createResultsPanel() {
        JPanel panel = new JPanel(new BorderLayout());
        panel.setBackground(Color.WHITE);
        panel.setBorder(BorderFactory.createLineBorder(new Color(224, 229, 236)));

        resultsTable.setFont(UI_FONT);
        resultsTable.setRowHeight(29);
        resultsTable.setFillsViewportHeight(true);
        resultsTable.setAutoCreateRowSorter(true);
        resultsTable.setGridColor(new Color(233, 237, 242));
        resultsTable.getTableHeader().setFont(new Font("Segoe UI", Font.BOLD, 13));
        resultsTable.getTableHeader().setBackground(new Color(239, 243, 248));
        resultsTable.setModel(messageModel("Selecione uma consulta e clique em Executar."));

        JScrollPane scrollPane = new JScrollPane(resultsTable);
        scrollPane.setBorder(BorderFactory.createEmptyBorder());
        panel.add(scrollPane, BorderLayout.CENTER);
        return panel;
    }

    private JPanel createStatusPanel() {
        JPanel panel = new JPanel(new BorderLayout());
        panel.setOpaque(false);
        statusLabel.setFont(new Font("Segoe UI", Font.PLAIN, 12));
        statusLabel.setForeground(MUTED_COLOR);
        panel.add(statusLabel, BorderLayout.WEST);
        return panel;
    }

    private void selectReport(Report report) {
        selectedReport = report;
        pageTitle.setText(report.letter + " — " + report.title);
        boolean needsParameter = report.parameterLabel != null;
        filterLabel.setText(needsParameter ? report.parameterLabel : "Esta consulta não usa filtro");
        filterField.setEnabled(needsParameter);
        filterField.setVisible(needsParameter);
        filterField.setText("");

        for (int i = 0; i < reportButtons.size(); i++) {
            JButton button = reportButtons.get(i);
            Report buttonReport = Report.values()[i];
            button.setBackground(buttonReport == report ? NAV_SELECTED : NAV_BUTTON);
        }
        frame.revalidate();
        frame.repaint();
    }

    private void executeReport() {
        Report report = selectedReport;
        String parameter = null;
        if (report.parameterLabel != null) {
            parameter = filterField.getText().trim();
            if (parameter.isEmpty()) {
                JOptionPane.showMessageDialog(
                        frame, "Informe " + report.parameterLabel.toLowerCase() + ".",
                        "Campo obrigatório", JOptionPane.WARNING_MESSAGE);
                filterField.requestFocusInWindow();
                return;
            }
        }

        final String queryParameter = parameter;
        setBusy(true);
        statusLabel.setText("Executando consulta " + report.letter + "...");

        new SwingWorker<DefaultTableModel, Void>() {
            @Override
            protected DefaultTableModel doInBackground() throws Exception {
                return loadReport(report, queryParameter);
            }

            @Override
            protected void done() {
                try {
                    DefaultTableModel model = get();
                    resultsTable.setModel(model);
                    resultsTable.setAutoCreateRowSorter(true);
                    statusLabel.setText("Consulta " + report.letter + " concluída.");
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                    showFailure(exception);
                } catch (java.util.concurrent.ExecutionException exception) {
                    showFailure(exception.getCause());
                } finally {
                    setBusy(false);
                }
            }
        }.execute();
    }

    private DefaultTableModel loadReport(Report report, String parameter) throws SQLException {
        try (Connection connection = openConnection();
             PreparedStatement statement = connection.prepareStatement(report.sql)) {
            if (parameter != null) {
                statement.setString(1, parameter);
            }

            try (ResultSet results = statement.executeQuery()) {
                ResultSetMetaData metadata = results.getMetaData();
                DefaultTableModel model = new DefaultTableModel() {
                    @Override
                    public boolean isCellEditable(int row, int column) {
                        return false;
                    }
                };

                int columnCount = metadata.getColumnCount();
                for (int i = 1; i <= columnCount; i++) {
                    model.addColumn(metadata.getColumnLabel(i));
                }

                while (results.next()) {
                    Object[] row = new Object[columnCount];
                    for (int i = 1; i <= columnCount; i++) {
                        row[i - 1] = results.getObject(i);
                    }
                    model.addRow(row);
                }

                if (model.getRowCount() == 0) {
                    return messageModel("A consulta não retornou resultados.");
                }
                return model;
            }
        }
    }

    private void testConnection() {
        if (!ensureConnectionSettings()) {
            statusLabel.setText("Configure os dados para conectar ao SQL Server.");
            return;
        }

        setBusy(true);
        statusLabel.setText("Testando conexão com o SQL Server...");

        new SwingWorker<Void, Void>() {
            @Override
            protected Void doInBackground() throws Exception {
                try (Connection connection = openConnection()) {
                    return null;
                }
            }

            @Override
            protected void done() {
                try {
                    get();
                    statusLabel.setText("Conectado ao banco BelezaLtda.");
                } catch (InterruptedException exception) {
                    Thread.currentThread().interrupt();
                    showFailure(exception);
                } catch (java.util.concurrent.ExecutionException exception) {
                    showFailure(exception.getCause());
                } finally {
                    setBusy(false);
                }
            }
        }.execute();
    }

    private void configureConnection() {
        if (showConnectionSettings()) {
            testConnection();
        }
    }

    private void setBusy(boolean busy) {
        executeButton.setEnabled(!busy);
        connectionButton.setEnabled(!busy);
        filterField.setEnabled(!busy && selectedReport.parameterLabel != null);
        for (JButton button : reportButtons) {
            button.setEnabled(!busy);
        }
    }

    private void showFailure(Throwable error) {
        String message = error.getMessage();
        if (message == null || message.trim().isEmpty()) {
            message = error.getClass().getSimpleName();
        }
        statusLabel.setText("Falha: " + message);
        JOptionPane.showMessageDialog(frame, message, "Erro no sistema", JOptionPane.ERROR_MESSAGE);
    }

    private static DefaultTableModel messageModel(String message) {
        DefaultTableModel model = new DefaultTableModel(
                new Object[] {"Resultado"}, 0) {
            @Override
            public boolean isCellEditable(int row, int column) {
                return false;
            }
        };
        model.addRow(new Object[] {message});
        return model;
    }

    private Connection openConnection() throws SQLException {
        return DriverManager.getConnection(databaseUrl, databaseUser, new String(databasePassword));
    }

    private static String environmentOrDefault(String name, String defaultValue) {
        String value = environmentValue(name);
        return value == null || value.trim().isEmpty() ? defaultValue : value.trim();
    }

    private static String environmentValue(String name) {
        return System.getenv(name);
    }

    private static char[] environmentPassword() {
        String password = environmentValue("DB_PASSWORD");
        return password == null ? new char[0] : password.toCharArray();
    }

    private boolean ensureConnectionSettings() {
        if (databaseUser != null && !databaseUser.trim().isEmpty()
                && databasePassword.length > 0) {
            return true;
        }

        return showConnectionSettings();
    }

    private boolean showConnectionSettings() {
        JTextField urlField = new JTextField(databaseUrl, 34);
        JTextField userField = new JTextField(databaseUser == null ? "" : databaseUser, 24);
        JPasswordField passwordField = new JPasswordField(24);
        JPanel panel = new JPanel(new GridLayout(0, 1, 0, 6));
        panel.add(new JLabel("URL JDBC do SQL Server:"));
        panel.add(urlField);
        panel.add(new JLabel("Usuário:"));
        panel.add(userField);
        panel.add(new JLabel("Senha:"));
        panel.add(passwordField);

        int choice = JOptionPane.showConfirmDialog(
                frame, panel, "Configurar conexão com o banco",
                JOptionPane.OK_CANCEL_OPTION, JOptionPane.PLAIN_MESSAGE);
        if (choice != JOptionPane.OK_OPTION) {
            return false;
        }

        String user = userField.getText().trim();
        char[] password = passwordField.getPassword();
        if (urlField.getText().trim().isEmpty() || user.isEmpty() || password.length == 0) {
            JOptionPane.showMessageDialog(
                    frame, "Informe a URL, o usuário e a senha.",
                    "Dados obrigatórios", JOptionPane.WARNING_MESSAGE);
            return false;
        }

        databaseUrl = urlField.getText().trim();
        databaseUser = user;
        databasePassword = password;
        return true;
    }

}
