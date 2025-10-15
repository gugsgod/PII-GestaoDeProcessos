// admin_drawer.dart
import 'package:flutter/material.dart';
import 'package:src/auth/auth_store.dart';
import 'package:src/services/capitalize.dart';

class AdminDrawer extends StatelessWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final AuthStore auth; // << receber o store com as claims

  const AdminDrawer({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    required this.auth,
  });

  String _initial(String? name) {
    final n = (name ?? '').trim();
    return n.isNotEmpty ? n[0].toUpperCase() : 'U';
  }

  @override
  Widget build(BuildContext context) {
    final displayName = auth.name ?? 'Usuário';
    final displayRole = auth.role == 'admin' ? 'Administrador' : 'Membro';

    return Drawer(
      backgroundColor: secondaryColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: BoxDecoration(color: primaryColor),
                  accountName: Text(
                    displayName.capitalize(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                  accountEmail: Text(displayRole),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.deepPurple,
                    child: Text(
                      _initial(displayName),
                      style: const TextStyle(
                        fontSize: 24.0,
                        color: Colors.white,
                      ),
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
                const SizedBox(height: 24),
                _buildSectionTitle('STATUS RÁPIDO'),
                _buildStatusItem(
                  dotColor: Colors.yellow.shade700,
                  text: 'Alertas ativos',
                  count: 10,
                  pillColor: const Color(0xFF5A5A5A),
                  pillBorderColor: const Color(0xFFA3A13C),
                ),
                _buildStatusItem(
                  dotColor: Colors.green.shade600,
                  text: 'Instrumentos ativos',
                  count: 356,
                  pillColor: const Color(0xFF0B4F3E),
                  pillBorderColor: const Color(0xFF22C55E),
                ),
                _buildStatusItem(
                  dotColor: Colors.green.shade600,
                  text: 'Materiais ativos',
                  count: 501,
                  pillColor: const Color(0xFF0B4F3E),
                  pillBorderColor: const Color(0xFF22C55E),
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          _buildDrawerItem(
            icon: Icons.logout,
            text: 'Sair',
            onTap: () async {
              await auth.logout(); // limpa token/claims
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
    );
  }

  // Helpers
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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

  Widget _buildStatusItem({
    required Color dotColor,
    required String text,
    required int count,
    required Color pillColor,
    required Color pillBorderColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: pillColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pillBorderColor, width: 1.5),
            ),
            child: Text(
              '$count',
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
}
