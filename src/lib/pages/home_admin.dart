import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart'; // <= ADICIONE
import 'package:src/auth/auth_store.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// Import dos widgets que tem nessa página
import '../widgets/admin/home_admin/admin_drawer.dart';
import '../widgets/admin/home_admin/dashboard_card.dart';
import '../widgets/admin/home_admin/recent_movements.dart';
import '../widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/home_admin/quick_actions.dart';
import 'animated_network_background.dart';

const String ApiBaseUrl = 'http://localhost:8000';

class Movimentacao {
  final String type;
  final String title;
  final String tag;
  final String user;
  final String time;
  final String amount;

  Movimentacao({
    required this.type,
    required this.title,
    required this.tag,
    required this.user,
    required this.time,
    required this.amount,
  });

  // Factory constructor para criar a partir do JSON do backend
  factory Movimentacao.fromJson(Map<String, dynamic> json) {
    // Pega o objeto 'material' aninhado
    final material = json['material'] as Map<String, dynamic>? ?? {};

    // Formata a data
    String formattedTime = 'Data inválida';
    try {
      final dt = DateTime.parse(json['created_at'] as String);
      formattedTime = DateFormat('dd/MM HH:mm').format(dt);
    } catch (e) {
      // Ignora erro de parsing, 'Data inválida' será usada
    }

    return Movimentacao(
      type: json['operacao']?.toString() ?? 'desconhecido',
      title: material['descricao']?.toString() ?? 'Material desconhecido',
      tag: material['cod_sap']?.toString() ?? 'N/A',
      // Backend retorna 'responsavel_id', não o nome.
      user: 'Usuário #${json['responsavel_id']?.toString() ?? '??'}',
      time: formattedTime,
      amount:
          '${json['quantidade']?.toString() ?? '0'} ${material['unidade']?.toString() ?? ''}',
    );
  }
}

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});

  @override
  State<HomeAdminPage> createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  // Removido: AuthStore local e _loaded
  late DateTime _lastUpdated;
  final ScrollController _scrollController = ScrollController();
  List<Movimentacao> _movimentacoes = [];
  bool _isLoading = true;
  String? _errorMessage;
  bool _didFetchData = false;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didFetchData) {
      _didFetchData = true;
      _fetchMovimentacoes();
    }
  }

  // MÉTODO PARA BUSCAR DADOS DO BACKEND
  Future<void> _fetchMovimentacoes() async {
    // Se não estiver montado, não faz nada
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final auth = context.read<AuthStore>();
      if (auth.token == null) {
        throw Exception('Token de autenticação não encontrado.');
      }

      // Usando o endpoint de listagem (index.dart)
      // Vamos buscar apenas as 10 mais recentes
      final url = Uri.parse('$ApiBaseUrl/movimentacoes?limit=10');

      final response = await http
          .get(
            url,
            headers: {
              'Authorization': 'Bearer ${auth.token}',
              'Content-Type': 'application/json',
            },
          )
          .timeout(const Duration(seconds: 10));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final jsonBody = json.decode(response.body);
        final dataList = jsonBody['data'] as List;
        final movements = dataList
            .map((item) => Movimentacao.fromJson(item as Map<String, dynamic>))
            .toList();

        setState(() {
          _movimentacoes = movements;
          _lastUpdated = DateTime.now();
          _isLoading = false;
        });
      } else if (response.statusCode == 401) {
        // Token expirado ou inválido
        setState(() {
          _errorMessage = 'Sessão expirada. Faça login novamente.';
          _isLoading = false;
        });
        // Desloga o usuário
        auth.logout();
      } else {
        // Outros erros HTTP
        throw Exception('Falha ao carregar dados: ${response.statusCode}');
      }
    } on TimeoutException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Tempo de conexão esgotado. Tente novamente.';
        _isLoading = false;
      });
    } on SocketException {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Sem conexão com a rede ou servidor offline.';
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _atualizarDados() {
    setState(() {
      _lastUpdated = DateTime.now();
      _movimentacoes.shuffle(Random());
      _fetchMovimentacoes();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Lê AuthStore centralizado
    final auth = context.watch<AuthStore>();

    // Se não autenticado, redireciona
    if (!auth.isAuthenticated) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color.fromARGB(255, 0, 14, 92);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    return Scaffold(
      // Titulo
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

      // Drawer agora lê o AuthStore via Provider internamente (sem passar auth)
      drawer: const AdminDrawer(
        primaryColor: Color(0xFF080023),
        secondaryColor: Color.fromARGB(255, 0, 14, 92),
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
              RecentMovements(
                scrollController: _scrollController,
                isDesktop: isDesktop,
              ),
              const SizedBox(height: 40),
              const QuickActions(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMovimentacoesSection(bool isDesktop) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Erro ao carregar movimentações:\n$_errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchMovimentacoes,
              child: const Text('Tentar Novamente'),
            ),
          ],
        ),
      );
    }

    return RecentMovements(
      scrollController: _scrollController,
      isDesktop: isDesktop,
    );
  }

  // Layouts
  Widget _buildDesktopGrid(bool isDesktop) {
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
          value: '10.167',
          icon: Icons.inventory_2_outlined,
          iconBackgroundColor: Colors.blue.shade700,
        ),
        DashboardCard(
          isDesktop: isDesktop,
          title: 'Instrumentos Ativos:',
          value: '70',
          icon: Icons.handyman_outlined,
          iconBackgroundColor: Colors.green.shade600,
        ),
        DashboardCard(
          isDesktop: isDesktop,
          title: 'Retiradas:',
          value: '2',
          icon: Icons.outbox_outlined,
          iconBackgroundColor: Colors.orange.shade700,
        ),
        DashboardCard(
          isDesktop: isDesktop,
          title: 'Alertas Ativos:',
          value: '5',
          icon: Icons.warning_amber_rounded,
          iconBackgroundColor: Colors.red.shade600,
        ),
      ],
    );
  }

  Widget _buildMobileList(bool isDesktop) {
    final cardData = [
      {
        'title': 'Total de Materiais:',
        'value': '10.167',
        'icon': Icons.inventory_2_outlined,
        'color': Colors.blue.shade700,
      },
      {
        'title': 'Instrumentos Ativos:',
        'value': '70',
        'icon': Icons.handyman_outlined,
        'color': Colors.green.shade600,
      },
      {
        'title': 'Retiradas:',
        'value': '2',
        'icon': Icons.outbox_outlined,
        'color': Colors.orange.shade700,
      },
      {
        'title': 'Alertas Ativos:',
        'value': '5',
        'icon': Icons.warning_amber_rounded,
        'color': Colors.red.shade600,
      },
    ];

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cardData.length,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        final data = cardData[index];
        return DashboardCard(
          isDesktop: isDesktop,
          title: data['title'] as String,
          value: data['value'] as String,
          icon: data['icon'] as IconData,
          iconBackgroundColor: data['color'] as Color,
        );
      },
    );
  }
}
