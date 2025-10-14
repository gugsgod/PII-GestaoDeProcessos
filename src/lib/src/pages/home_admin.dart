import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'animated_network_background.dart';

class HomeAdminPage extends StatefulWidget {
  const HomeAdminPage({super.key});

  @override
  State<HomeAdminPage> createState() => _HomeAdminPageState();
}

class _HomeAdminPageState extends State<HomeAdminPage> {
  late DateTime _lastUpdated;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
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

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        // A AppBar continua mais grossa, como você pediu
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
            child: Image.asset('assets/images/logo_metroSP.png', height: 30),
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

      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.calendar_today,
                  color: Colors.white70,
                  size: 16,
                ),
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
                  onPressed: () {
                    setState(() {
                      _lastUpdated = DateTime.now();
                    });
                  },
                  icon: const Icon(Icons.refresh, size: 16),
                  label: const Text('Atualizar página'),
                ),
              ],
            ),

            const SizedBox(height: 100),

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
            const Center(
              child: Text(
                'Os cards e gráficos do dashboard aparecerão aqui.',
                style: TextStyle(color: Colors.white38, fontSize: 18),
              ),
            ),
          ],
        ),
      ),
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
            // ADICIONADO: A borda ("stroke")
            border: Border.all(
              color: pillBorderColor,
              width: 1.5, // Você pode ajustar a espessura aqui
            ),
          ),
          child: Text(
            count.toString(),
            style: TextStyle(
              // MODIFICADO: A cor do texto agora é a mesma da borda
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
