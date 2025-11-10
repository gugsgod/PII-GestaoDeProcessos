// lib/pages/home_admin.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:src/auth/auth_store.dart';
import '../widgets/admin/home_admin/admin_drawer.dart';
import '../widgets/admin/home_admin/dashboard_card.dart';
import '../widgets/admin/home_admin/recent_movements.dart';
import '../widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/home_admin/quick_actions.dart';
import 'animated_network_background.dart';

const String apiBaseUrl = 'http://localhost:8080';

// ================= MODEL Movimentacao p/ lista recente =================

class Movimentacao {
  final String type; // entrada / saida / transferencia
  final String title; // descrição do material
  final String tag; // cod_sap
  final String user; // exibe id do usuário
  final String time; // string formatada
  final String amount; // ex: "10 UN"

  Movimentacao({
    required this.type,
    required this.title,
    required this.tag,
    required this.user,
    required this.time,
    required this.amount,
  });

  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    final material = (json['material'] as Map?) ?? {};

    // Data/hora
    String formattedTime = '—';
    final createdRaw = json['created_at'];
    if (createdRaw is String) {
      try {
        final dt = DateTime.parse(createdRaw);
        formattedTime = DateFormat('dd/MM HH:mm').format(dt);
      } catch (_) {}
    }

    final operacao = (json['operacao'] ?? '').toString();
    final qtd = (json['quantidade'] as num?)?.toDouble() ?? 0;
    final un = (material['unidade'] ?? '').toString();

    final isInt = qtd == qtd.roundToDouble();
    final qtdStr = isInt ? qtd.toStringAsFixed(0) : qtd.toStringAsFixed(2);

    return Movimentacao(
      type: operacao,
      title: (material['descricao'] ?? 'Material desconhecido').toString(),
      tag: (material['cod_sap'] ?? 'N/A').toString(),
      user: 'Usuário #${json['responsavel_id']?.toString() ?? '—'}',
      time: formattedTime,
      amount: '$qtdStr $un',
    );
  }
}

// ================= PÁGINA =================

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});

  @override
  State<HomeAdminPage> createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  late DateTime _lastUpdated;

  // métricas do dashboard
  bool _loadingStats = true;
  int _totalMateriais = 0;
  int _totalInstrumentosAtivos = 0;
  int _totalSaidas = 0;
  int _totalAlertas = 0; // calculado dinamicamente

  // movimentações recentes
  bool _loadingMovs = true;
  String? _movsError;
  List<Movimentacao> _movimentacoes = [];

  final ScrollController _scrollController = ScrollController();
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      _loadDashboardData();
      _fetchMovimentacoes();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ================= HELPERS =================

  Map<String, String> _authHeaders(AuthStore auth) => {
    'Authorization': 'Bearer ${auth.token}',
    'Content-Type': 'application/json',
  };

  // ================= CHAMADAS DE API (MÉTRICAS) =================

  Future<void> _loadDashboardData() async {
    final auth = context.read<AuthStore>();
    if (auth.token == null) {
      setState(() => _loadingStats = false);
      return;
    }

    setState(() => _loadingStats = true);

    try {
      final headers = _authHeaders(auth);

      // 1) Total de materiais (usa 'total' da listagem paginada)
      final resMat = await http.get(
        Uri.parse('$apiBaseUrl/materiais?page=1&limit=1'),
        headers: headers,
      );
      if (resMat.statusCode != 200) {
        throw Exception('Erro ao buscar materiais: ${resMat.statusCode}');
      }
      final matJson =
          jsonDecode(utf8.decode(resMat.bodyBytes)) as Map<String, dynamic>;
      final totalMateriais = (matJson['total'] ?? 0) as int;

      // 2) Instrumentos ativos + calibração vencida
      final resInst = await http.get(
        Uri.parse('$apiBaseUrl/instrumentos'),
        headers: headers,
      );
      if (resInst.statusCode != 200) {
        throw Exception('Erro ao buscar instrumentos: ${resInst.statusCode}');
      }
      final instList = jsonDecode(utf8.decode(resInst.bodyBytes));

      int ativos = 0;
      int calibVencida = 0;
      if (instList is List) {
        final now = DateTime.now();
        for (final raw in instList) {
          if (raw is! Map) continue;

          final statusStr = raw['status']?.toString().toLowerCase() ?? '';
          final ativoFlag = raw['ativo'] == true;

          final isAtivo =
              ativoFlag || statusStr == 'ativo' || statusStr == 'em_uso';

          if (isAtivo) {
            ativos++;
          }

          final calRaw = raw['proxima_calibracao_em'];
          if (calRaw is String && calRaw.isNotEmpty) {
            try {
              final dt = DateTime.parse(calRaw);
              if (!dt.isAfter(now)) {
                // já venceu ou vence hoje
                calibVencida++;
              }
            } catch (_) {}
          }
        }
      }

      // 3) Total de saídas (retiradas)
      final resSaidas = await http.get(
        Uri.parse('$apiBaseUrl/movimentacoes?operacao=saida&page=1&limit=1'),
        headers: headers,
      );
      if (resSaidas.statusCode != 200) {
        throw Exception('Erro ao buscar retiradas: ${resSaidas.statusCode}');
      }
      final saidasJson =
          jsonDecode(utf8.decode(resSaidas.bodyBytes)) as Map<String, dynamic>;
      final totalSaidas = (saidasJson['total'] ?? 0) as int;

      // 4) Materiais abaixo do mínimo (/estoque/minimos)
      final resMin = await http.get(
        Uri.parse('$apiBaseUrl/estoque/minimos?page=1&limit=1'),
        headers: headers,
      );
      int abaixoMinimo = 0;
      if (resMin.statusCode == 200) {
        final minJson =
            jsonDecode(utf8.decode(resMin.bodyBytes)) as Map<String, dynamic>;
        abaixoMinimo = (minJson['total'] ?? 0) as int;
      }

      // Alertas = materiais abaixo do mínimo + instrumentos com calibração vencida
      final totalAlertas = abaixoMinimo + calibVencida;

      if (!mounted) return;
      setState(() {
        _totalMateriais = totalMateriais;
        _totalInstrumentosAtivos = ativos;
        _totalSaidas = totalSaidas;
        _totalAlertas = totalAlertas;
        _lastUpdated = DateTime.now();
        _loadingStats = false;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() => _loadingStats = false);
    } catch (e) {
      if (!mounted) return;
      print('Erro ao carregar métricas do dashboard: $e');
      setState(() => _loadingStats = false);
    }
  }

  // ================= CHAMADAS DE API (MOVIMENTAÇÕES) =================

  Future<void> _fetchMovimentacoes() async {
    final auth = context.read<AuthStore>();
    if (auth.token == null) {
      setState(() {
        _loadingMovs = false;
        _movsError = 'Token não encontrado. Faça login novamente.';
      });
      return;
    }

    setState(() {
      _loadingMovs = true;
      _movsError = null;
    });

    try {
      final headers = _authHeaders(auth);
      final res = await http.get(
        Uri.parse('$apiBaseUrl/movimentacoes?page=1&limit=10'),
        headers: headers,
      );

      if (res.statusCode == 200) {
        final body =
            jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
        final list = (body['data'] as List? ?? [])
            .map((e) => Movimentacao.fromJson(e as Map<String, dynamic>))
            .toList();

        if (!mounted) return;
        setState(() {
          _movimentacoes = list;
          _loadingMovs = false;
          _lastUpdated = DateTime.now();
        });
      } else if (res.statusCode == 401) {
        if (!mounted) return;
        setState(() {
          _movsError = 'Sessão expirada. Faça login novamente.';
          _loadingMovs = false;
        });
        auth.logout();
      } else {
        throw Exception('Status ${res.statusCode}');
      }
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _movsError = 'Sem conexão com o servidor.';
        _loadingMovs = false;
      });
    } catch (e) {
      if (!mounted) return;
      print('Erro ao buscar movimentações: $e');
      setState(() {
        _movsError = 'Erro ao carregar movimentações.';
        _loadingMovs = false;
      });
    }
  }

  void _atualizarDados() {
    _loadDashboardData();
    _fetchMovimentacoes();
  }

  // ================= BUILD =================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    if (!auth.isAuthenticated) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color.fromARGB(255, 0, 14, 92);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: secondaryColor,
        elevation: 0,
        flexibleSpace: const AnimatedNetworkBackground(
          numberOfParticles: 35,
          maxDistance: 50.0,
        ),
        title: const Text(
          'Dashboard',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Image.asset('assets/images/logo_metroSP.png', height: 50),
          ),
        ],
      ),
      drawer: const AdminDrawer(
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
                'Dashboard Operacional',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Visão geral do sistema de controle de estoque',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 40),
              isDesktop
                  ? _buildDesktopGrid(isDesktop)
                  : _buildMobileList(isDesktop),
              const SizedBox(height: 40),
              _buildMovimentacoesSection(isDesktop),
              const SizedBox(height: 40),
              const QuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  // ================= SEÇÕES =================

  Widget _buildMovimentacoesSection(bool isDesktop) {
    if (_loadingMovs) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_movsError != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Movimentações recentes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(_movsError!, style: const TextStyle(color: Colors.redAccent)),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _fetchMovimentacoes,
            child: const Text('Tentar novamente'),
          ),
        ],
      );
    }

    if (_movimentacoes.isEmpty) {
      return const Text(
        'Sem movimentações recentes.',
        style: TextStyle(color: Colors.white70),
      );
    }

    return RecentMovements(
      scrollController: _scrollController,
      isDesktop: isDesktop,
    );
  }

  Widget _buildDesktopGrid(bool isDesktop) {
    String mat = _loadingStats ? '...' : _totalMateriais.toString();
    String inst = _loadingStats ? '...' : _totalInstrumentosAtivos.toString();
    String saidas = _loadingStats ? '...' : _totalSaidas.toString();
    String alertas = _loadingStats ? '...' : _totalAlertas.toString();

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 50,
      mainAxisSpacing: 30,
      childAspectRatio: 5.5,
      children: [
        DashboardCard(
          isDesktop: isDesktop,
          title: 'Total de Materiais:',
          value: mat,
          icon: Icons.inventory_2_outlined,
          iconBackgroundColor: Colors.blue.shade700,
        ),
        DashboardCard(
          isDesktop: isDesktop,
          title: 'Instrumentos Ativos:',
          value: inst,
          icon: Icons.handyman_outlined,
          iconBackgroundColor: Colors.green.shade600,
        ),
        DashboardCard(
          isDesktop: isDesktop,
          title: 'Retiradas (saídas):',
          value: saidas,
          icon: Icons.outbox_outlined,
          iconBackgroundColor: Colors.orange.shade700,
        ),
        DashboardCard(
          isDesktop: isDesktop,
          title: 'Alertas Ativos:',
          value: alertas,
          icon: Icons.warning_amber_rounded,
          iconBackgroundColor: Colors.red.shade600,
        ),
      ],
    );
  }

  Widget _buildMobileList(bool isDesktop) {
    final items = [
      (
        'Total de Materiais:',
        _loadingStats ? '...' : _totalMateriais.toString(),
        Icons.inventory_2_outlined,
        Colors.blue.shade700,
      ),
      (
        'Instrumentos Ativos:',
        _loadingStats ? '...' : _totalInstrumentosAtivos.toString(),
        Icons.handyman_outlined,
        Colors.green.shade600,
      ),
      (
        'Retiradas (saídas):',
        _loadingStats ? '...' : _totalSaidas.toString(),
        Icons.outbox_outlined,
        Colors.orange.shade700,
      ),
      (
        'Alertas Ativos:',
        _loadingStats ? '...' : _totalAlertas.toString(),
        Icons.warning_amber_rounded,
        Colors.red.shade600,
      ),
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final (title, value, icon, color) = items[index];
        return DashboardCard(
          isDesktop: isDesktop,
          title: title,
          value: value,
          icon: icon,
          iconBackgroundColor: color,
        );
      },
    );
  }
}
