// lib/widgets/admin/home_admin/recent_movements.dart

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:marquee/marquee.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:src/auth/auth_store.dart';

// ==================== MODELOS LOCAIS ==================== //

class _MaterialInfo {
  final String? codSap;
  final String? descricao;
  final String? unidade;

  _MaterialInfo({this.codSap, this.descricao, this.unidade});

  factory _MaterialInfo.fromJson(Map<String, dynamic> json) {
    return _MaterialInfo(
      codSap: json['cod_sap']?.toString(),
      descricao: json['descricao']?.toString(),
      unidade: json['unidade']?.toString(),
    );
  }
}

class _Movimentacao {
  final String operacao; // 'entrada' | 'saida' | 'transferencia'
  final String titulo; // descrição do material
  final String tag; // cod_sap
  final String usuarioLabel; // texto para exibir usuário/responsável
  final String horarioLabel; // texto formatado de data/hora
  final String quantidadeLabel; // ex: "10 UN"

  _Movimentacao({
    required this.operacao,
    required this.titulo,
    required this.tag,
    required this.usuarioLabel,
    required this.horarioLabel,
    required this.quantidadeLabel,
  });

  factory _Movimentacao.fromJson(Map<String, dynamic> json) {
    final material =
        _MaterialInfo.fromJson(json['material'] as Map<String, dynamic>);
    
    // 1. Data e Hora
    final createdAtUtc = DateTime.tryParse(json['created_at'] as String? ?? '');
    final createdAt = createdAtUtc?.toLocal();
    final dtLabel = createdAt != null
        ? '${createdAt.day.toString().padLeft(2, '0')}/'
            '${createdAt.month.toString().padLeft(2, '0')} '
            '${createdAt.hour.toString().padLeft(2, '0')}:'
            '${createdAt.minute.toString().padLeft(2, '0')}'
        : '';

    // 2. Quantidade
    final qtd = (json['quantidade'] as num?)?.toDouble() ?? 0;
    final unidade = material.unidade ?? 'UN';

    // 3. Lógica do Usuário (CORRIGIDO AQUI)
    final respNome = json['responsavel_nome'] as String?;
    final respId = json['responsavel_id'];
    
    String userLabel = 'Desconhecido';

    if (respNome != null && respNome.isNotEmpty) {
      // Pega apenas o primeiro nome para não ocupar muito espaço no card
      userLabel = respNome.split(' ').first;
    } else if (respId != null) {
      userLabel = 'Resp. #$respId';
    }

    return _Movimentacao(
      operacao: (json['operacao'] as String?) ?? 'entrada',
      titulo: material.descricao ?? 'Material',
      tag: (material.codSap ?? '').isEmpty
          ? 'SEM CÓDIGO'
          : material.codSap.toString(),
      usuarioLabel: userLabel, // Passa o nome formatado
      horarioLabel: dtLabel,
      quantidadeLabel: '${qtd.toStringAsFixed(0)} $unidade',
    );
  }
}

// ==================== WIDGET PRINCIPAL ==================== //

class RecentMovements extends StatefulWidget {
  final ScrollController scrollController;
  final bool isDesktop;

  const RecentMovements({
    super.key,
    required this.scrollController,
    required this.isDesktop,
  });

  @override
  State<RecentMovements> createState() => _RecentMovementsState();
}

class _RecentMovementsState extends State<RecentMovements> {
  static const String _apiHost = 'http://localhost:8080';

  Future<List<_Movimentacao>>? _future;

  @override
  void initState() {
    super.initState();
    // espera o primeiro build para garantir acesso ao Provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregar();
    });
  }

  void _carregar() {
    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (token == null || !auth.isAuthenticated) {
      setState(() {
        _future = Future.error(
          'missing/invalid token (faça login novamente para ver as movimentações).',
        );
      });
      return;
    }

    setState(() {
      _future = _fetchRecent(token);
    });
  }

  Future<List<_Movimentacao>> _fetchRecent(String token) async {
    // pega só as últimas 10
    final url = Uri.parse('$_apiHost/movimentacoes?page=1&limit=10');

    final res = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    final body = utf8.decode(res.bodyBytes);

    if (res.statusCode == 200) {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final list = (decoded['data'] as List)
          .map((e) => _Movimentacao.fromJson(e as Map<String, dynamic>))
          .toList();
      return list;
    }

    if (res.statusCode == 401) {
      throw Exception('missing/invalid token');
    }

    throw Exception('Erro ${res.statusCode}: $body');
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.sync_alt, color: Color(0xFF3B82F6), size: 28),
            SizedBox(width: 12),
            Text(
              'Movimentações recentes:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: FutureBuilder<List<_Movimentacao>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _future == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Erro ao carregar movimentações: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final movimentos = snapshot.data ?? [];

              if (movimentos.isEmpty) {
                return const Center(
                  child: Text(
                    'Nenhuma movimentação recente.',
                    style: TextStyle(color: Colors.white70),
                  ),
                );
              }

              return ScrollbarTheme(
                data: ScrollbarThemeData(
                  thumbColor: MaterialStateProperty.all(
                    Colors.white.withOpacity(0.3),
                  ),
                  mainAxisMargin: 16.0,
                ),
                child: Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: Scrollbar(
                    thumbVisibility: true,
                    interactive: true,
                    controller: widget.scrollController,
                    child: ListView.separated(
                      controller: widget.scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: movimentos.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = movimentos[index];
                        // final isEntrada = item.operacao == 'entrada';
                        return _buildMovementItem(
                          isDesktop: widget.isDesktop,
                          operacaoRaw: item.operacao,
                          title: item.titulo,
                          tag: item.tag,
                          user: item.usuarioLabel,
                          time: item.horarioLabel,
                          amount: item.quantidadeLabel,
                        );
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ==================== ITEM ==================== //

  Widget _buildMovementItem({
    required bool isDesktop,
    required String operacaoRaw,
    required String title,
    required String tag,
    required String user,
    required String time,
    required String amount,
  }) {
    final op = operacaoRaw.toLowerCase();
    
    IconData icon;
    Color iconColor;
    String statusText;
    Color statusBgColor;
    Color statusTextColor;

    // Lógica de Cores Unificada
    if (op == 'entrada' || op == 'devolucao') {
       icon = Icons.arrow_downward;
       iconColor = Colors.green.shade700;
       statusText = op == 'devolucao' ? 'Devolução' : 'Entrada';
       statusBgColor = const Color.fromARGB(255, 195, 236, 198);
       statusTextColor = Colors.green.shade800;
    } else if (op == 'saida' || op == 'retirada' || op == 'consumo') {
       icon = Icons.arrow_upward;
       iconColor = Colors.red.shade700;
       statusText = op == 'retirada' ? 'Retirada' : 'Saída';
       statusBgColor = const Color.fromARGB(255, 247, 200, 204);
       statusTextColor = Colors.red.shade800;
    } else {
       icon = Icons.swap_horiz;
       iconColor = Colors.blue.shade700;
       statusText = 'Transf.';
       statusBgColor = Colors.blue.shade100;
       statusTextColor = Colors.blue.shade800;
    }
    Widget titleWidget = isDesktop
        ? Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Colors.black87,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          )
        : SizedBox(
            height: 20,
            child: Marquee(
              text: title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.black87,
              ),
              blankSpace: 50.0,
              velocity: 30.0,
              pauseAfterRound: const Duration(seconds: 2),
            ),
          );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(209, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: titleWidget),
                    const SizedBox(width: 8),
                    _buildTag(
                      tag,
                      Colors.grey.shade200,
                      const Color.fromARGB(255, 44, 44, 44),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.engineering_outlined,
                      size: 14,
                      color: Color.fromARGB(255, 44, 44, 44),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$user · $time',
                      style: const TextStyle(
                        color: Color.fromARGB(255, 44, 44, 44),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTag(statusText, statusBgColor, statusTextColor),
              const SizedBox(height: 6),
              Text(
                amount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
