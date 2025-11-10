// lib/widgets/admin/home_admin/admin_drawer.dart
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:src/auth/auth_store.dart';
import 'package:src/services/capitalize.dart';

const String apiBaseUrl = 'http://localhost:8080';

class AdminDrawer extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const AdminDrawer({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<AdminDrawer> createState() => _AdminDrawerState();
}

class _QuickStatus {
  final int alertas;
  final int instrumentosAtivos;
  final int materiais;

  const _QuickStatus({
    required this.alertas,
    required this.instrumentosAtivos,
    required this.materiais,
  });
}

class _AdminDrawerState extends State<AdminDrawer> {
  late Future<_QuickStatus?> _statusFuture;
  bool _initialized = false;

  String _initial(String? name) {
    final n = (name ?? '').trim();
    return n.isNotEmpty ? n[0].toUpperCase() : 'U';
  }

  Map<String, String> _authHeaders(AuthStore auth) => {
    'Authorization': 'Bearer ${auth.token}',
    'Content-Type': 'application/json',
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final auth = context.read<AuthStore>();
      _statusFuture = _fetchQuickStatus(auth);
    }
  }

  Future<_QuickStatus?> _fetchQuickStatus(AuthStore auth) async {
    if (!auth.isAuthenticated || auth.token == null) return null;

    try {
      final headers = _authHeaders(auth);

      // 1) Materiais (usa total da listagem)
      final resMat = await http.get(
        Uri.parse('$apiBaseUrl/materiais?page=1&limit=1'),
        headers: headers,
      );
      if (resMat.statusCode != 200) {
        throw Exception('materiais: ${resMat.statusCode}');
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
        throw Exception('instrumentos: ${resInst.statusCode}');
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
                calibVencida++;
              }
            } catch (_) {}
          }
        }
      }

      // 3) Materiais abaixo do mínimo
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

      final alertas = abaixoMinimo + calibVencida;

      return _QuickStatus(
        alertas: alertas,
        instrumentosAtivos: ativos,
        materiais: totalMateriais,
      );
    } on SocketException catch (e) {
      print('QuickStatus socket error: $e');
      return null;
    } catch (e) {
      print('QuickStatus error: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final displayName = (auth.name ?? 'Usuário').capitalize();
    final displayRole = auth.role == 'admin' ? 'Administrador' : 'Usuário';

    return Drawer(
      backgroundColor: widget.secondaryColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                UserAccountsDrawerHeader(
                  decoration: BoxDecoration(color: widget.primaryColor),
                  accountName: Text(
                    displayName,
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
                  icon: Icons.dashboard_outlined,
                  text: 'Dashboard Operacional',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/admin');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.inventory_2_outlined,
                  text: 'Materiais',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/materiais');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.build_outlined,
                  text: 'Instrumentos',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/instrumentos');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.history_outlined,
                  text: 'Histórico de Alertas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/historico');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.people_outline,
                  text: 'Pessoas',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/pessoas');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.sync_alt_outlined,
                  text: 'Movimentações',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/movimentacoes');
                  },
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('STATUS RÁPIDO'),
                FutureBuilder<_QuickStatus?>(
                  future: _statusFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      // loading: mostra placeholders
                      return Column(
                        children: [
                          _buildStatusItem(
                            dotColor: Colors.yellow.shade700,
                            text: 'Alertas ativos',
                            value: '...',
                            pillColor: const Color(0xFF5A5A5A),
                            pillBorderColor: const Color(0xFFA3A13C),
                          ),
                          _buildStatusItem(
                            dotColor: Colors.green.shade600,
                            text: 'Instrumentos ativos',
                            value: '...',
                            pillColor: const Color(0xFF0B4F3E),
                            pillBorderColor: const Color(0xFF22C55E),
                          ),
                          _buildStatusItem(
                            dotColor: Colors.green.shade600,
                            text: 'Materiais ativos',
                            value: '...',
                            pillColor: const Color(0xFF0B4F3E),
                            pillBorderColor: const Color(0xFF22C55E),
                          ),
                        ],
                      );
                    }

                    if (snapshot.hasError) {
                      print('Erro QuickStatus drawer: ${snapshot.error}');
                    }

                    final data = snapshot.data;
                    final alertas = data?.alertas.toString() ?? '-';
                    final inst = data?.instrumentosAtivos.toString() ?? '-';
                    final mats = data?.materiais.toString() ?? '-';

                    return Column(
                      children: [
                        _buildStatusItem(
                          dotColor: Colors.yellow.shade700,
                          text: 'Alertas ativos',
                          value: alertas,
                          pillColor: const Color(0xFF5A5A5A),
                          pillBorderColor: const Color(0xFFA3A13C),
                        ),
                        _buildStatusItem(
                          dotColor: Colors.green.shade600,
                          text: 'Instrumentos ativos',
                          value: inst,
                          pillColor: const Color(0xFF0B4F3E),
                          pillBorderColor: const Color(0xFF22C55E),
                        ),
                        _buildStatusItem(
                          dotColor: Colors.green.shade600,
                          text: 'Materiais ativos',
                          value: mats,
                          pillColor: const Color(0xFF0B4F3E),
                          pillBorderColor: const Color(0xFF22C55E),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          _buildDrawerItem(
            icon: Icons.logout,
            text: 'Sair',
            onTap: () async {
              await auth.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/');
              }
            },
          ),
        ],
      ),
    );
  }

  // Helpers UI

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
    required String value,
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
              value,
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
