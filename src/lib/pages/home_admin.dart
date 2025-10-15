import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'animated_network_background.dart';
import 'dart:math';

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
  final ScrollController _scrollController = ScrollController();
  late DateTime _lastUpdated;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy, HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color.fromARGB(
      255,
      0,
      14,
      92,
    ); // Cor do menu e appbar

    // Define se a tela é larga o suficiente para 2 colunas
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
      drawer: Drawer(
        backgroundColor: secondaryColor,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  UserAccountsDrawerHeader(
                    decoration: const BoxDecoration(
                      color: Color.fromARGB(255, 0, 5, 31),
                    ),
                    accountName: const Text(
                      'Rosana dos Santos',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    accountEmail: const Text('Administrador'),
                    currentAccountPicture: const CircleAvatar(
                      backgroundColor: Colors.deepPurple,
                      child: Text(
                        'R',
                        style: TextStyle(fontSize: 24.0, color: Colors.white),
                      ),
                    ),
                  ),
                  _buildSectionTitle('NAVEGAÇÃO'),
                  _buildDrawerItem(
                    icon: Icons.inventory_2_outlined,
                    text: 'Materiais',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    icon: Icons.build_outlined,
                    text: 'Instrumentos',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    icon: Icons.history_outlined,
                    text: 'Histórico de Alertas',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    icon: Icons.people_outline,
                    text: 'Pessoas',
                    onTap: () {},
                  ),
                  _buildDrawerItem(
                    icon: Icons.sync_alt_outlined,
                    text: 'Movimentações',
                    onTap: () {},
                  ),

                  // ESPAÇAMENTO E TÍTULO DA SEÇÃO STATUS RÁPIDO
                  const SizedBox(height: 24),
                  _buildStatusItem(
                    dotColor: Colors.yellow.shade700,
                    text: 'Alertas ativos',
                    count: 10,
                    pillColor: const Color(0xFF5A5A5A),
                    pillBorderColor: const Color(0xFFA3A13C), // Borda Amarela
                  ),
                  _buildStatusItem(
                    dotColor: Colors.green.shade600,
                    text: 'Instrumentos ativos',
                    count: 356,
                    pillColor: const Color(0xFF0B4F3E),
                    pillBorderColor: const Color(0xFF22C55E), // Borda Verde
                  ),
                  _buildStatusItem(
                    dotColor: Colors.green.shade600,
                    text: 'Materiais ativos',
                    count: 501,
                    pillColor: const Color(0xFF0B4F3E),
                    pillBorderColor: const Color(0xFF22C55E), // Borda Verde
                  ),
                ],
              ),
            ),

            const Divider(color: Colors.white24, height: 1),
            _buildDrawerItem(
              icon: Icons.logout,
              text: 'Sair',
              onTap: () {
                Navigator.pushReplacementNamed(context, '/');
              },
            ),
          ],
        ),
      ),

      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              isDesktop ? _buildDesktopUpdateBar() : _buildMobileUpdateBar(),

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

              // Movimentações recentes
              Container(
                height: 400,
                decoration: BoxDecoration(
                  // Cor de fundo
                  color: Colors.white.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ScrollbarTheme(
                  data: ScrollbarThemeData(
                    // A cor é definida aqui, dentro do 'data'
                    thumbColor: MaterialStateProperty.all(
                      Colors.white.withOpacity(0.3),
                    ),
                      mainAxisMargin: 16.0, 
                  ),
                  child: Padding(
                    padding: const EdgeInsets.only(
                      right: 8.0, // margem da direita da scrollbar
                    ), 
                    child: Scrollbar(
                      thumbVisibility: true,
                      interactive: true,
                      controller: _scrollController,
                      child: ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: 15,
                        separatorBuilder: (context, index) =>
                            const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final items = [
                            {
                              'type': 'saida',
                              'title': 'Cabo Ethernet Cat6',
                              'tag': 'MAT001',
                              'user': 'técnico',
                              'time': '26/08 13:42',
                              'amount': '200 un',
                            },
                            {
                              'type': 'saida',
                              'title': 'Relé de Proteção 24V',
                              'tag': 'MAT002',
                              'user': 'admin',
                              'time': '26/08 17:42',
                              'amount': '5 un',
                            },
                            {
                              'type': 'entrada',
                              'title': 'Luva de Segurança Isolante',
                              'tag': 'MAT004',
                              'user': 'técnico',
                              'time': '27/08 17:42',
                              'amount': '10 un',
                            },
                            {
                              'type': 'saida',
                              'title': 'Fusível 10A',
                              'tag': 'MAT006',
                              'user': 'técnico',
                              'time': '27/08 17:42',
                              'amount': '15 un',
                            },
                            {
                              'type': 'entrada',
                              'title': 'Conector DB9 Macho',
                              'tag': 'MAT003',
                              'user': 'admin',
                              'time': '27/08 17:42',
                              'amount': '25 un',
                            },
                            {
                              'type': 'saida',
                              'title': 'Parafusadeira Elétrica',
                              'tag': 'FER012',
                              'user': 'técnico',
                              'time': '28/08 08:00',
                              'amount': '1 un',
                            },
                            {
                              'type': 'entrada',
                              'title': 'Óculos de Proteção',
                              'tag': 'EPI005',
                              'user': 'admin',
                              'time': '28/08 09:30',
                              'amount': '50 un',
                            },
                            {
                              'type': 'saida',
                              'title': 'Multímetro Digital',
                              'tag': 'FER007',
                              'user': 'técnico',
                              'time': '28/08 11:10',
                              'amount': '1 un',
                            },
                            {
                              'type': 'saida',
                              'title': 'Cabo Ethernet Cat6',
                              'tag': 'MAT001',
                              'user': 'técnico',
                              'time': '26/08 13:42',
                              'amount': '200 un',
                            },
                            {
                              'type': 'saida',
                              'title': 'Relé de Proteção 24V',
                              'tag': 'MAT002',
                              'user': 'admin',
                              'time': '26/08 17:42',
                              'amount': '5 un',
                            },
                            {
                              'type': 'entrada',
                              'title': 'Luva de Segurança Isolante',
                              'tag': 'MAT004',
                              'user': 'técnico',
                              'time': '27/08 17:42',
                              'amount': '10 un',
                            },
                            {
                              'type': 'saida',
                              'title': 'Fusível 10A',
                              'tag': 'MAT006',
                              'user': 'técnico',
                              'time': '27/08 17:42',
                              'amount': '15 un',
                            },
                            {
                              'type': 'entrada',
                              'title': 'Conector DB9 Macho',
                              'tag': 'MAT003',
                              'user': 'admin',
                              'time': '27/08 17:42',
                              'amount': '25 un',
                            },
                            {
                              'type': 'saida',
                              'title': 'Parafusadeira Elétrica',
                              'tag': 'FER012',
                              'user': 'técnico',
                              'time': '28/08 08:00',
                              'amount': '1 un',
                            },
                            {
                              'type': 'entrada',
                              'title': 'Óculos de Proteção',
                              'tag': 'EPI005',
                              'user': 'admin',
                              'time': '28/08 09:30',
                              'amount': '50 un',
                            },
                          ];
                          final item = items[index];

                          return _buildMovementItem(
                            isEntrada: item['type'] == 'entrada',
                            title: item['title']!,
                            tag: item['tag']!,
                            user: item['user']!,
                            time: item['time']!,
                            amount: item['amount']!,
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // NOVO WIDGET AUXILIAR DETALHADO PARA CADA ITEM DA LISTA
  Widget _buildMovementItem({
    required bool isEntrada,
    required String title,
    required String tag,
    required String user,
    required String time,
    required String amount,
  }) {
    final icon = isEntrada ? Icons.arrow_downward : Icons.arrow_upward;
    final iconColor = isEntrada ? Colors.green.shade700 : Colors.red.shade700;
    final statusText = isEntrada ? 'Entrada' : 'Saída';
    final statusBgColor = isEntrada
        ? const Color.fromARGB(255, 195, 236, 198)
        : const Color.fromARGB(255, 247, 200, 204);
    final statusTextColor = isEntrada
        ? Colors.green.shade800
        : Colors.red.shade800;
    final userIcon = user == 'admin'
        ? Icons.shield_outlined
        : Icons.engineering_outlined;

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
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
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
                    Icon(
                      userIcon,
                      size: 14,
                      color: const Color.fromARGB(255, 44, 44, 44),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$user · $time',
                      style: TextStyle(
                        color: const Color.fromARGB(255, 44, 44, 44),
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
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // NOVO WIDGET AUXILIAR PARA AS TAGS/CHIPS
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

  // Grade para o desktop
  Widget _buildDesktopGrid(bool isDesktop) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 50,
      mainAxisSpacing: 30,
      childAspectRatio: 5.5,
      children: [
        _buildDashboardCard(
          isDesktop: isDesktop,
          title: 'Total de Materiais:',
          value: '10.167',
          icon: Icons.inventory_2_outlined,
          iconBackgroundColor: Colors.blue.shade700,
        ),
        _buildDashboardCard(
          isDesktop: isDesktop,
          title: 'Instrumentos Ativos:',
          value: '70',
          icon: Icons.handyman_outlined,
          iconBackgroundColor: Colors.green.shade600,
        ),
        _buildDashboardCard(
          isDesktop: isDesktop,
          title: 'Retiradas:',
          value: '2',
          icon: Icons.outbox_outlined,
          iconBackgroundColor: Colors.orange.shade700,
        ),
        _buildDashboardCard(
          isDesktop: isDesktop,
          title: 'Alertas Ativos:',
          value: '5',
          icon: Icons.warning_amber_rounded,
          iconBackgroundColor: Colors.red.shade600,
        ),
      ],
    );
  }

  // Lista vertical para o mobile
  Widget _buildMobileList(bool isDesktop) {
    // ListView.separated para adicionar espaçamento entre os cards automaticamente
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: 20),
      itemBuilder: (context, index) {
        if (index == 0)
          return _buildDashboardCard(
            isDesktop: isDesktop,
            title: 'Total de Materiais:',
            value: '10.167',
            icon: Icons.inventory_2_outlined,
            iconBackgroundColor: Colors.blue.shade700,
          );
        if (index == 1)
          return _buildDashboardCard(
            isDesktop: isDesktop,
            title: 'Instrumentos Ativos:',
            value: '70',
            icon: Icons.handyman_outlined,
            iconBackgroundColor: Colors.green.shade600,
          );
        if (index == 2)
          return _buildDashboardCard(
            isDesktop: isDesktop,
            title: 'Retiradas:',
            value: '2',
            icon: Icons.outbox_outlined,
            iconBackgroundColor: Colors.orange.shade700,
          );
        return _buildDashboardCard(
          isDesktop: isDesktop,
          title: 'Alertas Ativos:',
          value: '5',
          icon: Icons.warning_amber_rounded,
          iconBackgroundColor: Colors.red.shade600,
        );
      },
    );
  }

  Widget _buildDashboardCard({
    required bool isDesktop,
    required String title,
    required String value,
    required IconData icon,
    required Color iconBackgroundColor,
  }) {
    // Diminuindo os tamanhos das fontes
    final titleFontSize = isDesktop ? 20.0 : 16.0;
    final valueFontSize = isDesktop ? 32.0 : 28.0;

    return Container(
      // cards lá de cima
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Color.fromARGB(209, 255, 255, 255),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: const Color.fromARGB(255, 32, 32, 32),
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  color: const Color.fromARGB(255, 32, 32, 32),
                  fontWeight: FontWeight.bold,
                  fontSize: valueFontSize,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopUpdateBar() {
    return Row(
      children: [
        const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(
          'Atualizado em ${_formatDateTime(_lastUpdated)}',
          style: const TextStyle(color: Colors.white70),
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade400.withOpacity(0.5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          onPressed: () => setState(() => _lastUpdated = DateTime.now()),
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Atualizar página'),
        ),
      ],
    );
  }

  // Barra de atualização para telas estreitas (Mobile)
  Widget _buildMobileUpdateBar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              'Atualizado em ${_formatDateTime(_lastUpdated)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Para o botão ocupar a largura toda no mobile
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade400.withOpacity(0.5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => setState(() => _lastUpdated = DateTime.now()),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Atualizar página'),
          ),
        ),
      ],
    );
  }

  // Widget auxiliar para os títulos das seções (NAVEGAÇÃO, STATUS RÁPIDO)
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Text(
        title,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: Colors.white70),
      title: Text(text, style: const TextStyle(color: Colors.white)),
      onTap: onTap,
    );
  }
}

// WIDGET AUXILIAR PARA OS ITENS DE STATUS
Widget _buildStatusItem({
  required Color dotColor,
  required String text,
  required int count,
  required Color pillColor,
  required Color pillBorderColor,
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: pillColor,
            borderRadius: BorderRadius.circular(12),
            // A borda ("stroke") dos balões
            border: Border.all(color: pillBorderColor, width: 1.5),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              color: pillBorderColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ),
      ],
    ),
  );
}
