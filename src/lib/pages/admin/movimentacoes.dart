// lib/pages/movimentacoes.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:src/auth/auth_store.dart';
import 'package:src/widgets/admin/home_admin/update_status_bar.dart';
import '../../widgets/admin/home_admin/admin_drawer.dart';
import 'animated_network_background.dart';

// ==================== MODELOS ==================== //

class MaterialInfo {
  final String? codSap;
  final String? descricao;
  final String? unidade;

  MaterialInfo({this.codSap, this.descricao, this.unidade});

  factory MaterialInfo.fromJson(Map<String, dynamic> json) {
    return MaterialInfo(
      codSap: json['cod_sap']?.toString(),
      descricao: json['descricao']?.toString(),
      unidade: json['unidade']?.toString(),
    );
  }
}

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
      quantidade: (json['quantidade'] as num?)?.toDouble(),
      responsavelId: json['responsavel_id'] as int?,
      observacao: json['observacao'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      material: MaterialInfo.fromJson(
        json['material'] as Map<String, dynamic>,
      ),
    );
  }
}

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
    final list = (json['data'] as List)
        .map((item) => Movimentacao.fromJson(item as Map<String, dynamic>))
        .toList();

    return MovimentacaoResponse(
      page: json['page'] as int,
      limit: json['limit'] as int,
      total: json['total'] as int,
      data: list,
    );
  }
}

// ==================== PÁGINA PRINCIPAL ==================== //

class MovimentacoesRecentesPage extends StatefulWidget {
  const MovimentacoesRecentesPage({Key? key}) : super(key: key);

  @override
  State<MovimentacoesRecentesPage> createState() =>
      _MovimentacoesRecentesPageState();
}

class _MovimentacoesRecentesPageState
    extends State<MovimentacoesRecentesPage> {
  late DateTime _lastUpdated;
  Future<List<Movimentacao>>? _movimentacoesFuture;

  final ScrollController _scrollController = ScrollController();

  static const String _apiHost = 'http://localhost:8080'; // mesmo do backend

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();

    // Espera o primeiro build para ter acesso ao Provider com segurança
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregarMovimentacoes();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ==================== API ==================== //

  Future<List<Movimentacao>> _fetchHistorico({
    required String token,
    int page = 1,
    int limit = 20,
  }) async {
    final url = Uri.parse('$_apiHost/movimentacoes?page=$page&limit=$limit');

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
      final resp = MovimentacaoResponse.fromJson(decoded);
      return resp.data;
    }

    if (res.statusCode == 401) {
      throw Exception('missing/invalid token');
    }

    throw Exception('Erro ${res.statusCode}: $body');
  }

  void _carregarMovimentacoes() {
    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (token == null || !auth.isAuthenticated) {
      setState(() {
        _movimentacoesFuture =
            Future.error('missing/invalid token (faça login novamente).');
      });
      return;
    }

    setState(() {
      _movimentacoesFuture = _fetchHistorico(token: token);
      _lastUpdated = DateTime.now();
    });
  }

  void _atualizarDados() {
    _carregarMovimentacoes();
  }

  // ==================== BUILD ==================== //

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color(0xFF000E5C);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: secondaryColor,
        elevation: 0,
        flexibleSpace: const AnimatedNetworkBackground(
          numberOfParticles: 35,
          maxDistance: 50,
        ),
        title: const Text(
          'Movimentações Recentes',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Image.asset(
              'assets/images/logo_metroSP.png',
              height: 50,
            ),
          ),
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
              const SizedBox(height: 32),
              const Text(
                'Movimentações Recentes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Visão geral das movimentações do sistema',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildMovimentacoesList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== LISTA DE MOVIMENTAÇÕES ==================== //

  Widget _buildMovimentacoesList() {
    if (_movimentacoesFuture == null) {
      // ainda carregando primeira vez
      return const Padding(
        padding: EdgeInsets.all(48.0),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return FutureBuilder<List<Movimentacao>>(
      future: _movimentacoesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(48.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'Erro: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'Nenhuma movimentação encontrada.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }

        final movimentacoes = snapshot.data!;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          child: Column(
            children: [
              _buildHeader(movimentacoes.length),
              const SizedBox(height: 8),
              SizedBox(
                height: 500,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: movimentacoes.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _buildMovimentacaoCard(movimentacoes[index]),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Movimentações Recentes',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 18,
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                count.toString(),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMovimentacaoCard(Movimentacao item) {
    IconData icon;
    Color iconColor;
    String statusText;

    switch (item.operacao) {
      case 'entrada':
        icon = Icons.arrow_downward_rounded;
        iconColor = Colors.green.shade600;
        statusText = 'Entrada';
        break;
      case 'saida':
        icon = Icons.arrow_upward_rounded;
        iconColor = Colors.red.shade600;
        statusText = 'Saída';
        break;
      default:
        icon = Icons.swap_horiz_rounded;
        iconColor = Colors.blue.shade600;
        statusText = 'Transferência';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: iconColor.withOpacity(0.15),
              child: Icon(icon, color: iconColor),
            ),
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
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Técnico • ',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        DateFormat('dd/MM/yyyy, HH:mm').format(item.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: iconColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${item.quantidade?.toStringAsFixed(0) ?? '0'} '
                  '${item.material.unidade ?? 'un'}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
