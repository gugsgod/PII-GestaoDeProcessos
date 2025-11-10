import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import 'package:src/auth/auth_store.dart';
import 'animated_network_background.dart';
import 'package:src/widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/home_admin/admin_drawer.dart';

const String apiBaseUrl = 'http://localhost:8080';

// ===================== MODELOS ===================== //

class AlertItem {
  final String tipo; // 'estoque_minimo' ou 'calibracao_vencida'
  final String titulo; // ex: 'Estoque abaixo do mínimo'
  final String descricao; // descrição do item
  final String codigo; // cod_sap ou patrimônio
  final String origem; // local / base / info do instrumento
  final String detalhe; // resumo (ex: 'Saldo 5 de 100', 'Venceu em 10/09/2025')
  final DateTime referencia; // usado para ordenar (mais crítico/recente)
  final Color cor; // cor do badge

  AlertItem({
    required this.tipo,
    required this.titulo,
    required this.descricao,
    required this.codigo,
    required this.origem,
    required this.detalhe,
    required this.referencia,
    required this.cor,
  });
}

// ===================== PÁGINA ===================== //

class HistoricoAdminPage extends StatefulWidget {
  const HistoricoAdminPage({Key? key}) : super(key: key);

  @override
  State<HistoricoAdminPage> createState() => _HistoricoAdminPageState();
}

class _HistoricoAdminPageState extends State<HistoricoAdminPage> {
  late DateTime _lastUpdated;
  final ScrollController _scrollController = ScrollController();

  late Future<List<AlertItem>> _alertsFuture;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    _alertsFuture = _loadAlerts();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  // ===================== HELPERS API ===================== //

  Map<String, String> _authHeaders(AuthStore auth) => {
    'Authorization': 'Bearer ${auth.token}',
    'Content-Type': 'application/json',
  };

  Future<List<AlertItem>> _loadAlerts() async {
    final auth = context.read<AuthStore>();

    if (!auth.isAuthenticated || auth.token == null) {
      throw Exception('Sessão expirada. Faça login novamente.');
    }

    final headers = _authHeaders(auth);

    try {
      // 1) Alertas de materiais: /estoque/minimos
      final minimosRes = await http.get(
        Uri.parse('$apiBaseUrl/estoque/minimos?page=1&limit=200'),
        headers: headers,
      );

      if (minimosRes.statusCode != 200) {
        throw Exception(
          'Erro ao carregar alertas de estoque (${minimosRes.statusCode})',
        );
      }

      final minimosJson =
          jsonDecode(utf8.decode(minimosRes.bodyBytes)) as Map<String, dynamic>;
      final minimosData = (minimosJson['data'] as List? ?? []);

      final List<AlertItem> alerts = [];

      for (final item in minimosData) {
        if (item is! Map<String, dynamic>) continue;

        final material = (item['material'] as Map?) ?? {};
        final local = (item['local'] as Map?) ?? {};
        final qtDisp = (item['qt_disp'] as num?)?.toDouble() ?? 0;
        final minimo = (item['minimo'] as num?)?.toDouble() ?? 0;
        final deficit =
            (item['deficit'] as num?)?.toDouble() ?? (minimo - qtDisp);

        alerts.add(
          AlertItem(
            tipo: 'estoque_minimo',
            titulo: 'Estoque abaixo do mínimo',
            descricao: (material['descricao'] ?? 'Material sem descrição')
                .toString(),
            codigo: (material['cod_sap'] ?? '').toString(),
            origem: (local['nome'] ?? 'Local não informado').toString(),
            detalhe:
                'Saldo ${qtDisp.toStringAsFixed(0)} / Mínimo ${minimo.toStringAsFixed(0)} • Déficit ${deficit.toStringAsFixed(0)}',
            referencia: DateTime.now(), // sem timestamp próprio → usa agora
            cor: Colors.red.shade600,
          ),
        );
      }

      // 2) Alertas de instrumentos: calibração vencida em /instrumentos
      final instRes = await http.get(
        Uri.parse('$apiBaseUrl/instrumentos'),
        headers: headers,
      );

      if (instRes.statusCode == 200) {
        final instList = jsonDecode(utf8.decode(instRes.bodyBytes));
        final now = DateTime.now();

        if (instList is List) {
          for (final raw in instList) {
            if (raw is! Map<String, dynamic>) continue;

            final prox = raw['proxima_calibracao_em'];
            if (prox == null) continue;

            DateTime? due;
            try {
              if (prox is String) {
                due = DateTime.parse(prox);
              }
            } catch (_) {
              due = null;
            }
            if (due == null) continue;

            // VENCIDO: due < now
            if (due.isBefore(now)) {
              alerts.add(
                AlertItem(
                  tipo: 'calibracao_vencida',
                  titulo: 'Calibração vencida',
                  descricao: (raw['descricao'] ?? 'Instrumento sem descrição')
                      .toString(),
                  codigo: (raw['patrimonio'] ?? '').toString(),
                  origem:
                      'Instrumento • ${(raw['categoria'] ?? '').toString()}',
                  detalhe: 'Vencido em ${DateFormat('dd/MM/yyyy').format(due)}',
                  referencia: due,
                  cor: Colors.orange.shade700,
                ),
              );
            }
          }
        }
      } else {
        // Se der erro aqui, só loga, não quebra a página inteira
        print(
          'Erro ao carregar instrumentos para alertas (${instRes.statusCode})',
        );
      }

      // Ordena: primeiro os mais críticos/vencidos (referência mais antiga),
      // depois os mais recentes
      alerts.sort((a, b) => a.referencia.compareTo(b.referencia));

      return alerts;
    } on SocketException {
      throw Exception('Sem conexão com o servidor.');
    } catch (e) {
      print('Erro ao carregar alertas: $e');
      rethrow;
    }
  }

  void _atualizarDados() {
    setState(() {
      _lastUpdated = DateTime.now();
      _alertsFuture = _loadAlerts();
    });
  }

  // ===================== BUILD ===================== //

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
          maxDistance: 50,
        ),
        title: const Text(
          'Histórico de Alertas',
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
              const SizedBox(height: 32),
              const Text(
                'Histórico de Alertas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Monitoramento de estoque abaixo do mínimo e calibrações vencidas.',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildAlertsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ===================== LISTA DE ALERTAS ===================== //

  Widget _buildAlertsList() {
    return FutureBuilder<List<AlertItem>>(
      future: _alertsFuture,
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
            child: Column(
              children: [
                Text(
                  'Erro ao carregar alertas:\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _atualizarDados,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          );
        }

        final alerts = snapshot.data ?? [];

        if (alerts.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24.0),
            child: Center(
              child: Text(
                'Nenhum alerta ativo no momento.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          );
        }

        return Column(
          children: [
            _buildHeader(alerts.length),
            const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
            SizedBox(
              height: 600,
              child: ListView.separated(
                controller: _scrollController,
                padding: const EdgeInsets.all(16.0),
                itemCount: alerts.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildAlertCard(alerts[index]),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHeader(int count) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 14.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Alertas Ativos',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
              fontSize: 18,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertCard(AlertItem a) {
    final icon = a.tipo == 'estoque_minimo'
        ? Icons.inventory_2_rounded
        : Icons.build_circle_rounded;

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(color: a.cor.withOpacity(0.4), width: 1),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: a.cor.withOpacity(0.12),
            child: Icon(icon, color: a.cor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.titulo,
                  style: TextStyle(
                    color: a.cor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.descricao,
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Código: ${a.codigo}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  a.origem,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  a.detalhe,
                  style: const TextStyle(color: Colors.black87, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
