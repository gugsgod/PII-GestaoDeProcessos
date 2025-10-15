import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart'; // <= ADICIONE
import 'package:src/auth/auth_store.dart';

// Import dos widgets que tem nessa página
import '../widgets/admin/home_admin/admin_drawer.dart';
import '../widgets/admin/home_admin/dashboard_card.dart';
import '../widgets/admin/home_admin/recent_movements.dart';
import '../widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/home_admin/quick_actions.dart';
import 'animated_network_background.dart';

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
  late List<Movimentacao> _movimentacoes;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    _carregarDadosIniciais();
  }

  void _carregarDadosIniciais() {
    _movimentacoes = [
      Movimentacao(
        type: 'saida',
        title: 'Cabo Ethernet Cat6',
        tag: 'MAT001',
        user: 'técnico',
        time: '26/08 13:42',
        amount: '200 un',
      ),
      Movimentacao(
        type: 'saida',
        title: 'Relé de Proteção 24V',
        tag: 'MAT002',
        user: 'admin',
        time: '26/08 17:42',
        amount: '5 un',
      ),
      Movimentacao(
        type: 'entrada',
        title: 'Luva de Segurança Isolante',
        tag: 'MAT004',
        user: 'técnico',
        time: '27/08 17:42',
        amount: '10 un',
      ),
      Movimentacao(
        type: 'saida',
        title: 'Fusível 10A',
        tag: 'MAT006',
        user: 'técnico',
        time: '27/08 17:42',
        amount: '15 un',
      ),
      Movimentacao(
        type: 'saida',
        title: 'Fusível 10A',
        tag: 'MAT006',
        user: 'técnico',
        time: '27/08 17:42',
        amount: '15 un',
      ),
      Movimentacao(
        type: 'saida',
        title: 'Fusível 10A',
        tag: 'MAT006',
        user: 'técnico',
        time: '27/08 17:42',
        amount: '15 un',
      ),
    ];
  }

  void _atualizarDados() {
    setState(() {
      _lastUpdated = DateTime.now();
      _movimentacoes.shuffle(Random());
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
                movimentacoes: _movimentacoes,
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
