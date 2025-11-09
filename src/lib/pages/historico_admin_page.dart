import 'package:flutter/material.dart';
import 'package:src/widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/home_admin/admin_drawer.dart';
import 'animated_network_background.dart';
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Modelo para o objeto "material" aninhado
class MaterialInfo {
  final String? codSap;
  final String? descricao;
  final String? unidade;

  MaterialInfo({this.codSap, this.descricao, this.unidade});

  factory MaterialInfo.fromJson(Map<String, dynamic> json) {
    return MaterialInfo(
      codSap: json['cod_sap'] as String?,
      descricao: json['descricao'] as String?,
      unidade: json['unidade'] as String?,
    );
  }
}

// Modelo principal da movimentação
class Movimentacao {
  final int id;
  final String? operacao;
  final int materialId;
  final int? origemLocalId;
  final int? destinoLocalId;
  final String? lote;
  final double? quantidade;
  final int? responsavelId;
  final String? observacao;
  final DateTime createdAt;
  final MaterialInfo material;

  Movimentacao({
    required this.id,
    this.operacao,
    required this.materialId,
    this.origemLocalId,
    this.destinoLocalId,
    this.lote,
    this.quantidade,
    this.responsavelId,
    this.observacao,
    required this.createdAt,
    required this.material,
  });

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    return Movimentacao(
      id: json['id'] as int,
      operacao: json['operacao'] as String?,
      materialId: json['material_id'] as int,
      origemLocalId: json['origem_local_id'] as int?,
      destinoLocalId: json['destino_local_id'] as int?,
      lote: json['lote'] as String?,
      quantidade: json['quantidade'] as double?,
      responsavelId: json['responsavel_id'] as int?,
      observacao: json['observacao'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      material: MaterialInfo.fromJson(json['material'] as Map<String, dynamic>),
    );
  }
}

// Classe para encapsular a resposta paginada da API
class MovimentacaoResponse {
  final int page;
  final int limit;
  final int total;
  final List<Movimentacao> data;

  MovimentacaoResponse({
    required this.page,
    required this.limit,
    required this.total,
    required this.data,
  });

  factory MovimentacaoResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> dataList = json['data'] as List;
    final List<Movimentacao> movimentacoes =
        dataList.map((item) => Movimentacao.fromJson(item)).toList();

    return MovimentacaoResponse(
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
      data: movimentacoes,
    );
  }
}

// -----------------------------------------------------------------
// Widget da Página
// -----------------------------------------------------------------

class HistoricoAdminPage extends StatefulWidget {
  const HistoricoAdminPage({Key? key}) : super(key: key);

  @override
  _HistoricoAdminPageState createState() => _HistoricoAdminPageState();
}

class _HistoricoAdminPageState extends State<HistoricoAdminPage> {
  late DateTime _lastUpdated;
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Future para os dados (usado pelo FutureBuilder)
  late Future<List<Movimentacao>> _movimentacoesFuture;
  
  // A instância do MovimentacaoService foi removida.

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    // Inicia a busca dos dados chamando a função local
    _movimentacoesFuture = fetchHistorico();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // -----------------------------------------------------------------
  // Lógica de API 
  // -----------------------------------------------------------------

  Future<String?> _getAuthToken() async {
    final token = dotenv.env['JWT_SECRET'];

    if (token == null || token.isEmpty) {
      print("ERRO CRITICO: Variavel nao encontrada no .env");
      return null;
    }

    return token;
  }

  /// Busca o histórico de movimentações na API.
  Future<List<Movimentacao>> fetchHistorico({
    int? materialId,
    int? localId,
    String? operacao,
    String? lote,
    int page = 1,
    int limit = 20, // Padrão de 20 itens por página
  }) async {
    final token = await _getAuthToken();

    if (token == null) {
      print("fetchHistorico falhou: Token nulo, usuário não autenticado.");
      throw Exception('Usuario não autenticado (token nulo).');
    }
    const String apiHost = 'http://localhost:8080';

    // Constrói os parâmetros de query
    final queryParams = <String, String>{
      'page': page.toString(),
      'limit': limit.toString(),
      if (materialId != null) 'material_id': materialId.toString(),
      if (localId != null) 'local_id': localId.toString(),
      if (operacao != null && operacao.isNotEmpty) 'operacao': operacao,
      if (lote != null && lote.isNotEmpty) 'lote': lote,
    };

    final url = Uri.parse('$apiHost/movimentacoes').replace(
      queryParameters: queryParams.isEmpty ? null : queryParams,
    );

    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        // Decodifica o corpo da resposta
        final Map<String, dynamic> jsonResponse = 
            jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        
        // Usa o modelo MovimentacaoResponse para parsear
        final movimentacaoResponse = MovimentacaoResponse.fromJson(jsonResponse);
        
        // Retorna apenas a lista de dados
        return movimentacaoResponse.data;
      } else {
        // Tratar outros status codes (401, 403, 500, etc.)
        throw Exception('Falha ao carregar movimentações: ${response.statusCode}');
      }
    } catch (e) {
      // Tratar erros de conexão, timeout, etc.
      print('Erro na API fetchHistorico: $e');
      throw Exception('Falha ao conectar ao servidor: $e');
    }
  }

  // -----------------------------------------------------------------
  // Métodos do Widget
  // -----------------------------------------------------------------

  void _atualizarDados() {
    setState(() {
      _lastUpdated = DateTime.now();
      // Atualiza o future para buscar novos dados
      _movimentacoesFuture = fetchHistorico();
    });
  }

  void _onSearchChanged(String query) {
    print("Buscando por: $query");
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023); //cor de fundo
    const Color secondaryColor = Color.fromARGB(255,0,14,92); 
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: secondaryColor,
        elevation: 0,
        flexibleSpace:
            const AnimatedNetworkBackground(numberOfParticles: 35, maxDistance: 50),
        title: const Text("Histórico de Movimentações", // Título atualizado
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Image.asset('assets/images/logo_metroSP.png', height: 50),
          )
        ],
      ),
      drawer: AdminDrawer(
        primaryColor: primaryColor,
        secondaryColor: secondaryColor,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UpdateStatusBar(
                isDesktop: isDesktop,
                lastUpdated: _lastUpdated,
                onUpdate: _atualizarDados,
              ),
              const SizedBox(height: 48),
              const Text(
                "Histórico de Alertas", 
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Visão geral das entradas, saídas e transferências", 
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Color.fromARGB(209, 255, 255, 255),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildMovimentacoesList(), // Chama o FutureBuilder
              )
            ],
          ),
        ),
      ),
    );
  }

  // ------------------- Widgets da Tabela de Histórico ------------------ //

  /// Constrói a lista usando um FutureBuilder
  Widget _buildMovimentacoesList() {
    return FutureBuilder<List<Movimentacao>>(
      future: _movimentacoesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(48.0),
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Text(
                'Erro ao buscar dados: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: Text(
                'Nenhuma movimentação encontrada.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }

        // Dados carregados com sucesso
        final movimentacoes = snapshot.data!;

        return Column(
          children: [
            _buildTableHeader(movimentacoes.length),
            const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
            SizedBox(
              height: 600, // Altura fixa para a lista rolável
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: movimentacoes.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildMovimentacaoRow(movimentacoes[index]);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  /// Constrói o cabeçalho da tabela.
  Widget _buildTableHeader(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Últimas Movimentações',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 18,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Constrói uma única linha da tabela de movimentações.
  Widget _buildMovimentacaoRow(Movimentacao item) {
    // Define ícone e cor com base na operação
    final IconData icon;
    final Color iconColor;
    final String operacaoLabel;

    switch (item.operacao) {
      case 'entrada':
        icon = Icons.arrow_downward_rounded;
        iconColor = Colors.green.shade700;
        operacaoLabel = 'Entrada';
        break;
      case 'saida':
        icon = Icons.arrow_upward_rounded;
        iconColor = Colors.red.shade700;
        operacaoLabel = 'Saída';
        break;
      case 'transferencia':
        icon = Icons.swap_horiz_rounded;
        iconColor = Colors.blue.shade700;
        operacaoLabel = 'Transferência';
        break;
      default:
        icon = Icons.help_outline_rounded;
        iconColor = Colors.grey.shade700;
        operacaoLabel = item.operacao ?? 'Desconhecida';
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 28),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.material.descricao ?? 'Material Desconhecido',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 4),
                // Mostra origem e destino
                if (item.operacao == 'entrada')
                  Text(
                    'Destino ID: ${item.destinoLocalId ?? 'N/A'}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                if (item.operacao == 'saida')
                  Text(
                    'Origem ID: ${item.origemLocalId ?? 'N/A'}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                if (item.operacao == 'transferencia')
                  Text(
                    'De ID: ${item.origemLocalId ?? 'N/A'} -> Para ID: ${item.destinoLocalId ?? 'N/A'}',
                    style: const TextStyle(color: Colors.black54, fontSize: 13),
                  ),
                const SizedBox(height: 4),
                // Mostra tags (Lote, Responsável)
                Wrap(
                  spacing: 8.0,
                  runSpacing: 4.0,
                  children: [
                    _MovTag(label: operacaoLabel, color: iconColor),
                    if (item.lote != null) _MovTag(label: 'Lote: ${item.lote}'),
                    if (item.responsavelId != null)
                      _MovTag(label: 'Por ID: ${item.responsavelId}'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Mostra Quantidade e Data
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Qtd: ${item.quantidade ?? 0}',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 4),
              Text(
                DateFormat('dd/MM/yy HH:mm').format(item.createdAt.toLocal()),
                style: const TextStyle(color: Colors.black54, fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Widget para a tag de informação.
class _MovTag extends StatelessWidget {
  final String label;
  final Color? color;

  const _MovTag({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final bgColor = color?.withOpacity(0.1) ?? Colors.grey.shade200;
    final textColor = color ?? Colors.grey.shade700;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

