import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import 'package:src/auth/auth_store.dart';
import 'package:src/services/capitalize.dart';

import 'dart:async';



const String apiBaseUrl = 'http://localhost:8080';

class TecnicoDrawer extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;

  const TecnicoDrawer({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  State<TecnicoDrawer> createState() => _TecnicoDrawerState();
}

class _QuickStatus {
  final int alertas;
  final int instrumentosEmUso;
  final int materiaisEmUso;

  const _QuickStatus({
    required this.alertas,
    required this.instrumentosEmUso,
    required this.materiaisEmUso,
  });
}

class _TecnicoDrawerState extends State<TecnicoDrawer> {
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
      final auth = context.read<AuthStore>();
      _statusFuture = _fetchQuickStatus(auth);
      _initialized = true;
    }
  }

  Future<_QuickStatus?> _fetchQuickStatus(AuthStore auth) async {
    if (!auth.isAuthenticated || auth.token == null) {
      return null;
    }

    final headers = _authHeaders(auth);

    try {
      // Executa as duas chamadas em paralelo
      final responses = await Future.wait([
        // 1. Pendências (Materiais/Instrumentos em uso + Devoluções atrasadas)
        http.get(
          Uri.parse('$apiBaseUrl/movimentacoes/pendentes'), 
          headers: headers
        ).timeout(const Duration(seconds: 5)),

        // 2. Calibrações Vencidas (Alertas de sistema)
        http.get(
          Uri.parse('$apiBaseUrl/instrumentos/catalogo').replace(
            queryParameters: {'vencidos': 'true', 'ativo': 'true'}
          ), 
          headers: headers
        ).timeout(const Duration(seconds: 5)),
      ]);

      final responsePendentes = responses[0];
      final responseCalibracao = responses[1];

      // Verifica se ambas tiveram sucesso
      if (responsePendentes.statusCode == 200 && responseCalibracao.statusCode == 200) {
        final List<dynamic> dataPendentes = json.decode(utf8.decode(responsePendentes.bodyBytes));
        final List<dynamic> dataCalibracao = json.decode(utf8.decode(responseCalibracao.bodyBytes));
        
        int matCount = 0;
        int instCount = 0;
        int devolucaoAtrasadaCount = 0;
        
        final agora = DateTime.now();

        // Processa Pendências
        for (var jsonItem in dataPendentes) {
          final isInst = (jsonItem['idMaterial'] as String?)?.startsWith('MAT') == false;
          final previsaoStr = jsonItem['dataDevolucao'] as String?;
          final previsao = DateTime.tryParse(previsaoStr ?? '');
          
          if (isInst) {
            instCount++;
          } else {
            matCount++;
          }
          
          // Conta atraso de devolução
          if (previsao != null && previsao.isBefore(agora)) {
            devolucaoAtrasadaCount++;
          }
        }

        // Processa Calibrações (o tamanho da lista já é a quantidade de vencidos)
        final int calibracaoVencidaCount = dataCalibracao.length;
        
        return _QuickStatus(
          alertas: devolucaoAtrasadaCount + calibracaoVencidaCount, // Soma os dois tipos
          instrumentosEmUso: instCount,
          materiaisEmUso: matCount,
        );

      } else {
        print('Erro QuickStatus drawer (API): ${responsePendentes.statusCode} / ${responseCalibracao.statusCode}');
        return null;
      }
    } catch (e) {
      print('Erro QuickStatus drawer (Catch): ${e.toString()}');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();
    final displayName = (auth.name ?? 'Usuário').capitalize();
    final displayRole = auth.role == 'tecnico' ? 'Técnico' : 'Usuário';

    return Drawer(
      backgroundColor: widget.primaryColor,
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
                    style: const TextStyle(color: Colors.white, fontSize: 18),
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
                _buildSectionTitle('Navegação'),
                _buildDrawerItem(
                  icon: Icons.dashboard_outlined,
                  text: 'Painel de Controle',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/tecnico');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.library_books_outlined,
                  text: 'Catálogo',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/catalogo');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.assignment_outlined,
                  text: 'Histórico de Uso',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/historico-uso');
                  },
                ),
                _buildDrawerItem(
                  icon: Icons.calendar_month_outlined,
                  text: 'Calibração',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.pushReplacementNamed(context, '/calibracao');
                  },
                ),
                const SizedBox(height: 24),
                _buildSectionTitle('STATUS RÁPIDO'),
                FutureBuilder<_QuickStatus?>(
                  future: _statusFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {

                      final data = snapshot.data;
                      final alertas = data?.alertas.toString() ?? '-';
                      final inst = data?.instrumentosEmUso.toString() ?? '-';
                      final mats = data?.materiaisEmUso.toString() ?? '-';

                      return Column(
                        children: [
                          _buildStatusItem(
                            dotColor: Colors.yellow.shade700,
                            text: 'Alertas ativos',
                            value: alertas,
                            pillColor: const Color(0xFF5A5A5A),
                            pillBorderColor: Color(0xFFA3A13C),
                          ),
                          _buildStatusItem(
                            dotColor: Colors.green.shade600,
                            text: 'Instrumentos em uso',
                            value: inst,
                            pillColor: const Color(0xFF0B4F3E),
                            pillBorderColor: Color(0xFF22C55E),
                          ),
                          _buildStatusItem(
                            dotColor: Colors.green.shade600,
                            text: 'Materiais em uso',
                            value: mats,
                            pillColor: const Color(0xFF0B4F3E),
                            pillBorderColor: Color(0xFF22C55E),
                          ),
                        ],
                      );
                    }

                    if (snapshot.hasError) {
                      print('Erro QuickStatus drawer: ${snapshot.error}');
                    }

                    final data = snapshot.data;
                    final alertas = data?.alertas.toString() ?? '-';
                    final inst = data?.instrumentosEmUso.toString() ?? '-';
                    final mats = data?.materiaisEmUso.toString() ?? '-';

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
                          text: 'Instrumentos em uso',
                          value: inst,
                          pillColor: const Color(0xFF0B4F3E),
                          pillBorderColor: const Color(0xFF22C55E),
                        ),
                        _buildStatusItem(
                          dotColor: Colors.green.shade600,
                          text: 'Materiais em uso',
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
          )
        ],
      ),
    );
  }

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
