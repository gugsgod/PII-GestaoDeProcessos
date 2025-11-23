import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';
import 'package:src/widgets/admin/home_admin/dashboard_card.dart';
import 'package:src/widgets/tecnico/Atividades.dart' show AtividadesRecentes, Atividade;
import 'package:src/widgets/tecnico/home_tecnico/AlertasTecnico.dart';
import '../admin/animated_network_background.dart';
import '../../widgets/tecnico/home_tecnico/tecnico_drawer.dart';
import '../../widgets/admin/home_admin/update_status_bar.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:io';

const String apiBaseUrl = 'http://localhost:8080';


class HomeTecnico extends StatefulWidget {
  const HomeTecnico({Key? key}) : super(key: key);

  @override
  State<HomeTecnico> createState() => _HomeTecnicoState();
}

class _HomeTecnicoState extends State<HomeTecnico> {
  late DateTime _lastUpdated;

  // Métricas
  bool _loadingStats = true;
  int _materiaisEmUso = 0;
  int _instrumentosEmUso = 0;
  int _devolucoesPendentes = 0;
  int _alertasAtivos = 0;

  bool _loadingAtividades = true;
  String? _atividadesError;
  List<Atividade> _atividadesRecentes = [];

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
    // Garante que os dados sejam carregados apenas uma vez
    if (!_initialized) {
      _atualizaDados();
      _initialized = true;
    }
  }

  Future<void> _atualizaDados() async {
    setState(() {
      _loadingStats = true;
      _loadingAtividades = true;
      _atividadesError = null;
      _lastUpdated = DateTime.now();
    });

    final auth = context.read<AuthStore>();
    final token = auth.token;
    if (token == null) {
      setState(() {
        _atividadesError = 'Usuário não autenticado.';
        _loadingStats = false;
        _loadingAtividades = false;
      });
      return;
    }

    // Prepara as duas URIs
    final uriPendentes = Uri.parse('$apiBaseUrl/movimentacoes/pendentes');
    final uriCalibracao = Uri.parse('$apiBaseUrl/instrumentos/catalogo').replace(
      queryParameters: {'vencidos': 'true', 'ativo': 'true'}
    );
    
    final headers = {'Authorization': 'Bearer $token'};

    try {
      // Executa as duas chamadas em paralelo para ser mais rápido
      final responses = await Future.wait([
        http.get(uriPendentes, headers: headers).timeout(const Duration(seconds: 5)),
        http.get(uriCalibracao, headers: headers).timeout(const Duration(seconds: 5)),
      ]);

      final responsePendentes = responses[0];
      final responseCalibracao = responses[1];

      if (!mounted) return;

      // 1. Processa Pendências (Materiais/Instrumentos em uso)
      if (responsePendentes.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(responsePendentes.bodyBytes));
        final atividades = data.map((json) => Atividade.fromJson(json)).toList();
        
        // Guardamos na variável para a lista de baixo
        _atividadesRecentes = atividades; 
        
        // Calculamos estatísticas de uso e atraso de devolução
        _calcularStatsCombinados(atividades, responseCalibracao);
        
      } else {
        throw Exception('Falha ao carregar pendências: ${responsePendentes.statusCode}');
      }

      setState(() {
        _loadingStats = false;
        _loadingAtividades = false;
      });

    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().replaceAll("Exception: ", "");
        setState(() {
          _atividadesError = errorMsg;
          _loadingStats = false;
          _loadingAtividades = false;
        });
      }
    }
  }

  void _calcularStatsCombinados(List<Atividade> atividades, http.Response responseCalibracao) {
    int matCount = 0;
    int instCount = 0;
    int devolucoesAtrasadasCount = 0;
    int calibracaoVencidaCount = 0;

    // 1. Contagem de Pendências (Em uso e Atrasos de Devolução)
    for (var item in atividades) {
      if (item.isInstrumento) {
        instCount++;
      } else {
        matCount++;
      }
      
      if (item.isAtrasado) {
        devolucoesAtrasadasCount++;
      }
    }

    // 2. Contagem de Calibrações Vencidas (Vinda da API)
    if (responseCalibracao.statusCode == 200) {
      final List<dynamic> dataCalib = json.decode(utf8.decode(responseCalibracao.bodyBytes));
      calibracaoVencidaCount = dataCalib.length;
    } else {
      print('Erro ao carregar calibrações para contagem: ${responseCalibracao.statusCode}');
      // Se falhar, assumimos 0 para não quebrar a tela inteira
    }
    
    // Atualiza as variáveis de estado
    _materiaisEmUso = matCount;
    _instrumentosEmUso = instCount;
    _devolucoesPendentes = matCount + instCount;
    
    // SOMA OS DOIS TIPOS DE ALERTA
    _alertasAtivos = devolucoesAtrasadasCount + calibracaoVencidaCount;
  }

  Widget _buildAtividadesSection(bool isDesktop) {
    // (O if _loadingAtividades, if _atividadesError 
    //  foi movido para dentro do widget AtividadesRecentes)
    
    // Agora apenas passamos os dados para o filho
    return AtividadesRecentes(
      scrollController: _scrollController,
      isDesktop: isDesktop,
      // Passando os dados do Pai
      isLoading: _loadingAtividades,
      error: _atividadesError,
      atividades: _atividadesRecentes,
      onReload: _atualizaDados, // Passa a função de recarregar
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    if (!auth.isAuthenticated) {
      Future.microtask(() => Navigator.pushReplacementNamed(context, '/'));
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color.fromARGB(255, 0, 14, 92);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

    return Scaffold(
      backgroundColor: primaryColor,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: secondaryColor,
        elevation: 0,
        flexibleSpace: const AnimatedNetworkBackground(
          numberOfParticles: 30,
          maxDistance: 50.0,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Image.asset('assets/images/logo_metroSP.png', height: 50),
          ),
        ],
      ),
      drawer: const TecnicoDrawer(
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
                onUpdate: _atualizaDados,
              ),
              const SizedBox(height: 48),
              const Text(
                'Painel de Controle',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Visão geral das suas atividades',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 40),
              isDesktop
                  ? _buildDesktopGrid(isDesktop)
                  : _buildMobileList(isDesktop),
              const SizedBox(height: 40),
              _buildAtividadesSection(isDesktop),
              const SizedBox(height: 24),
              AlertasTecnico(
                isDesktop: isDesktop,
                scrollController: ScrollController(),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopGrid(bool isDesktop) {
    String mat = _loadingStats ? '...' : _materiaisEmUso.toString();
    String inst = _loadingStats ? '...' : _instrumentosEmUso.toString();
    String saidas = _loadingStats ? '...' : _devolucoesPendentes.toString();
    String alertas = _loadingStats ? '...' : _alertasAtivos.toString();

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
          title: 'Materiais Ativos:',
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
          title: 'Devoluções Pendentes:',
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
        'Materiais em uso:',
        _loadingStats ? '...' : _materiaisEmUso.toString(),
        Icons.inventory_2_outlined,
        Colors.blue.shade700,
      ),
      (
        'Instrumentos em uso:',
        _loadingStats ? '...' : _instrumentosEmUso.toString(),
        Icons.handyman_outlined,
        Colors.green.shade600,
      ),
      (
        'Devoluções pendentes:',
        _loadingStats ? '...' : _devolucoesPendentes.toString(),
        Icons.outbox_outlined,
        Colors.orange.shade700,
      ),
      (
        'Alertas ativos:',
        _loadingStats ? '...' : _alertasAtivos.toString(),
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
