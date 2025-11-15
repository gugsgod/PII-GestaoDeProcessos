import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';
import 'package:intl/intl.dart'; // Para formatar datas
import 'dart:convert';
import 'package:http/http.dart' as http;
// A linha abaixo é desnecessária, já que o fetch é local
// import 'package:src/services/instrumentos_api.dart'; 
import '../admin/animated_network_background.dart';
import '../../widgets/tecnico/home_tecnico/tecnico_drawer.dart';
import 'dart:async'; // Para TimeoutException
import 'dart:io'; // Para SocketException

// ===================================================================
// ==================== MODELOS DE DADOS =============================
// ===================================================================

// Enum para controlar o seletor
enum CatalogoTipo { instrumentos, materiais }

// Modelo de dados para /instrumentos (baseado na imagem)
class InstrumentoCatalogo {
  final String id;
  final String nome;
  final String patrimonio;
  final String local;
  final DateTime proximaCalibracao;
  final bool disponivel; // 'status' no seu modelo antigo

  InstrumentoCatalogo({
    required this.id,
    required this.nome,
    required this.patrimonio,
    required this.local,
    required this.proximaCalibracao,
    required this.disponivel,
  });

  bool get calibracaoVencida => proximaCalibracao.isBefore(DateTime.now());

  factory InstrumentoCatalogo.fromJson(Map<String, dynamic> json) {
    return InstrumentoCatalogo(
      id: json['id']?.toString() ?? 'N/A',
      nome: json['descricao'] ?? 'N/A', // Usando 'descricao' como 'nome'
      patrimonio: json['patrimonio']?.toString() ?? 'N/A',
      local: json['local_atual_id']?.toString() ?? 'BASE 01', // Mock se nulo
      proximaCalibracao: DateTime.tryParse(json['proxima_calibracao_em'] ?? '') ?? DateTime.now(),
      disponivel: (json['status']?.toString() ?? 'inativo') == 'ativo',
    );
  }
}

// Modelo de dados para /materiais (baseado na imagem)
class MaterialCatalogo {
  final int id;
  final String nome;
  final int matId; // cod_sap
  final String categoria;
  final bool disponivel; // 'ativo' no seu modelo antigo

  MaterialCatalogo({
    required this.id,
    required this.nome,
    required this.matId,
    required this.categoria,
    required this.disponivel,
  });

  factory MaterialCatalogo.fromJson(Map<String, dynamic> json) {
    return MaterialCatalogo(
      id: json['id'] ?? 0,
      nome: json['descricao'] ?? 'N/A',
      matId: json['cod_sap'] ?? 0,
      categoria: json['categoria'] ?? 'N/A',
      disponivel: json['ativo'] ?? false,
    );
  }
}


// ===================================================================
// ==================== WIDGET PRINCIPAL =============================
// ===================================================================

class Catalogo extends StatefulWidget {
  const Catalogo({Key? key}) : super(key: key);

  @override
  State<Catalogo> createState() => _CatalogoState();
}

class _CatalogoState extends State<Catalogo> {
  // --- Controle de Estado ---
  CatalogoTipo _tipoSelecionado = CatalogoTipo.instrumentos;
  final TextEditingController _searchController = TextEditingController();
  
  // --- Controle da API ---
  late Future<void> _loadFuture;
  bool _isFutureInitialized = false; // Flag de controle
  bool _isLoading = true; // Controla o loading inicial
  String? _catalogoError;
  
  // --- Listas de Dados ---
  List<InstrumentoCatalogo> _instrumentos = [];
  List<MaterialCatalogo> _materiais = [];
  List<InstrumentoCatalogo> _instrumentosFiltrados = [];
  List<MaterialCatalogo> _materiaisFiltrados = [];
  
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarDados);
    // NÃO inicialize o _loadFuture aqui, pois ele depende do context.
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Este método roda DEPOIS do initState e tem acesso ao context.
    // Usamos a flag para garantir que a API só seja chamada uma vez.
    if (!_isFutureInitialized) {
      _loadFuture = _fetchCatalogo();
      _isFutureInitialized = true;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarDados);
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ================== LÓGICA DE DADOS (API E FILTRO) ==================

  // Busca AMBAS as listas da API em paralelo
  Future<void> _fetchCatalogo() async {
    
    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (mounted) {
      setState(() {
        _isLoading = true;
        _catalogoError = null;
      });
    }

    if (token == null || !auth.isAuthenticated) {
      // Isso não deve acontecer por causa do guardião no build,
      // mas é uma boa prática.
      if (mounted) {
        setState(() {
          _catalogoError = 'Token de acesso ausente ou inválido.';
          _isLoading = false;
        });
      }
      return;
    }

    const String baseUrl = 'http://localhost:8080';
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'Cache-Control': 'no-cache, no-store, must-revalidate',
    };

    try {
      // Executa as duas chamadas de API em paralelo
      final responses = await Future.wait([
        http.get(Uri.parse('$baseUrl/instrumentos'), headers: headers).timeout(const Duration(seconds: 5)),
        http.get(Uri.parse('$baseUrl/materiais'), headers: headers).timeout(const Duration(seconds: 5)),
      ]);

      // Processa resposta de Instrumentos
      if (responses[0].statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(responses[0].bodyBytes));
        _instrumentos = data.map((json) => InstrumentoCatalogo.fromJson(json)).toList();
      } else {
        // Joga um erro específico para ser pego abaixo
        throw Exception('Falha ao carregar instrumentos: ${responses[0].statusCode}');
      }

      // Processa resposta de Materiais
      if (responses[1].statusCode == 200) {
        // A rota de materiais é paginada, a de instrumentos não.
        final Map<String, dynamic> decoded = json.decode(utf8.decode(responses[1].bodyBytes));
        final List<dynamic> data = decoded['data'] ?? [];
        _materiais = data.map((json) => MaterialCatalogo.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar materiais: ${responses[1].statusCode}');
      }

    } on TimeoutException {
      if (mounted) {
        setState(() => _catalogoError = 'Servidor não respondeu a tempo (Timeout).');
      }
    } on SocketException {
      if (mounted) {
        setState(() => _catalogoError = 'Falha ao conectar. Verifique a rede ou o servidor.');
      }
    } on http.ClientException catch (e) {
      if (mounted) {
        // Este é o erro que você está vendo (ClientFailed to fetch)
        setState(() => _catalogoError = 'Erro de conexão (CORS ou DNS): ${e.message}');
      }
    } catch (e) {
      // Pega qualquer outro erro (como os 'throw Exception' acima)
      if (mounted) {
        setState(() {
          _catalogoError = e.toString().replaceAll("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _filtrarDados(); // Aplica o filtro inicial (mesmo vazio)
        });
      }
    }
  }

  // Filtra as listas em memória com base na busca
  void _filtrarDados() {
    final query = _searchController.text.toLowerCase();
    
    // Filtra instrumentos
    _instrumentosFiltrados = _instrumentos.where((item) {
      return item.nome.toLowerCase().contains(query) ||
             item.patrimonio.toLowerCase().contains(query);
    }).toList();

    // Filtra materiais
    _materiaisFiltrados = _materiais.where((item) {
      return item.nome.toLowerCase().contains(query) ||
             item.matId.toString().toLowerCase().contains(query);
    }).toList();
    
    // Atualiza a UI
    setState(() {});
  }

  // Chamado quando o toggle (Instrumentos/Materiais) é clicado
  void _onToggleChanged(CatalogoTipo tipo) {
    setState(() {
      _tipoSelecionado = tipo;
      _filtrarDados(); // Re-filtra a lista correta
    });
  }


  // ================== WIDGETS DE CONSTRUÇÃO (UI) ==================

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthStore>();

    // Guardião de autenticação
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
        flexibleSpace: const AnimatedNetworkBackground(numberOfParticles: 30, maxDistance: 50.0),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0),
            child: Image.asset('assets/images/logo_metroSP.png', height: 50,),
          ),
        ],
      ),
      drawer: const TecnicoDrawer(primaryColor: primaryColor, secondaryColor: secondaryColor),
      body: SingleChildScrollView(
        controller: _scrollController,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Títulos
              const Text(
                'Catálogo',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Busque e retire materiais e instrumentos disponíveis.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),

              // --- Barra de Pesquisa (IMPLEMENTADA) ---
              _buildSearchBar(),
              const SizedBox(height: 16),

              // --- Botões de Toggle (IMPLEMENTADO) ---
              _buildToggleButtons(),
              const SizedBox(height: 24),

              // --- Conteúdo Principal (Grid) (IMPLEMENTADO) ---
              _buildBodyContent(isDesktop),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  // Constrói a Barra de Pesquisa
  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        hintText: 'Buscar por nome ou código...',
        hintStyle: const TextStyle(color: Colors.white54),
        prefixIcon: const Icon(Icons.search, color: Colors.white54),
        filled: true,
        fillColor: Colors.white.withOpacity(0.1),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Constrói os botões de toggle (Instrumentos / Materiais)
  Widget _buildToggleButtons() {
    bool isInstrumentos = _tipoSelecionado == CatalogoTipo.instrumentos;
    bool isMateriais = _tipoSelecionado == CatalogoTipo.materiais;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleItem("Instrumentos", isInstrumentos, () => _onToggleChanged(CatalogoTipo.instrumentos)),
          _buildToggleItem("Materiais", isMateriais, () => _onToggleChanged(CatalogoTipo.materiais)),
        ],
      ),
    );
  }

  // Item individual do toggle
  Widget _buildToggleItem(String titulo, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Center(
            child: Text(
              titulo,
              style: TextStyle(
                color: isSelected ? const Color(0xFF080023) : Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Constrói o corpo principal (Loading, Erro, ou Grid)
  Widget _buildBodyContent(bool isDesktop) {
    return FutureBuilder(
      future: _loadFuture,
      builder: (context, snapshot) {
        
        // snapshot.connectionState == ConnectionState.waiting é mais
        // confiável que o _isLoading para o FutureBuilder
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        // 2. Estado de Erro (pode vir do snapshot ou do _catalogoError)
        if (_catalogoError != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                "Erro ao carregar catálogo:\n$_catalogoError",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
          );
        }
        
        if (snapshot.hasError) {
           return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                "Erro no Future: ${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
          );
        }

        // 3. Estado de Sucesso (mostra a grid)
        return _buildGrid(isDesktop);
      },
    );
  }

  // Constrói a Grid responsiva
  Widget _buildGrid(bool isDesktop) {
    final int crossAxisCount = isDesktop ? 2 : 1;
    // Ajusta a proporção do card para desktop vs mobile
    final double childAspectRatio = isDesktop ? 2.6 : 2.4; 

    // Define qual lista e qual card builder usar
    final bool isInstrumentos = _tipoSelecionado == CatalogoTipo.instrumentos;
    final int itemCount = isInstrumentos ? _instrumentosFiltrados.length : _materiaisFiltrados.length;
    final List<dynamic> items = isInstrumentos ? _instrumentosFiltrados : _materiaisFiltrados;

    if (items.isEmpty) {
      return _buildListaVazia();
    }

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: childAspectRatio,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: itemCount,
      shrinkWrap: true, // Essencial dentro de um SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(), // Desativa o scroll da grid
      itemBuilder: (context, index) {
        if (isInstrumentos) {
          return _buildInstrumentoCard(_instrumentosFiltrados[index]);
        } else {
          return _buildMaterialCard(_materiaisFiltrados[index]);
        }
      },
    );
  }

  // UI de Lista Vazia
  Widget _buildListaVazia() {
    // Se ainda estiver carregando (mesmo que o futuro tenha terminado), não mostre "vazio"
    if (_isLoading) {
       return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
    }
    
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 64.0),
        child: Column(
          children: [
            Icon(Icons.search_off, color: Colors.white30, size: 48),
            SizedBox(height: 16),
            Text(
              "Nenhum item encontrado",
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  // ================== WIDGETS DOS CARDS ==================

  // Constrói o Card de Instrumento (baseado na image_c1764b.png)
  Widget _buildInstrumentoCard(InstrumentoCatalogo item) {
    final bool vencida = item.calibracaoVencida;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1: Ícone, Título, ID, Tags
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone
              const Icon(Icons.construction, color: Colors.green, size: 32),
              const SizedBox(width: 12),
              // Título e ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(item.patrimonio, style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              // Tags
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TagChip(
                    label: "Disponível",
                    backgroundColor: Colors.green.withOpacity(0.2),
                    textColor: Colors.green.shade300,
                  ),
                  if (vencida) ...[
                    const SizedBox(height: 4),
                    _TagChip(
                      label: "Calibração Vencida",
                      backgroundColor: Colors.red.withOpacity(0.2),
                      textColor: Colors.red.shade300,
                    ),
                  ]
                ],
              ),
            ],
          ),
          const Spacer(), // Ocupa o espaço
          // Linha 2: Local
          _InfoLinha(
            icon: Icons.location_on_outlined,
            title: "Local:",
            value: item.local,
            valueColor: Colors.white,
          ),
          // Linha 3: Calibração
          _InfoLinha(
            icon: Icons.calendar_today_outlined,
            title: "Calibração:",
            value: DateFormat('dd/MM/yyyy').format(item.proximaCalibracao),
            iconColor: vencida ? Colors.red.shade300 : Colors.white70,
            valueColor: vencida ? Colors.red.shade300 : Colors.white70,
          ),
          const SizedBox(height: 16),
          // Linha 4: Botão
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () { /* TODO: Lógica de Retirada */ },
              icon: const Icon(Icons.upload, size: 16, color: Colors.white),
              label: const Text("Retirar Instrumento"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Constrói o Card de Material (baseado na image_c17684.png)
  Widget _buildMaterialCard(MaterialCatalogo item) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Linha 1: Ícone, Título, ID, Tags
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone
              const Icon(Icons.inventory_2_outlined, color: Color(0xFF3B82F6), size: 32),
              const SizedBox(width: 12),
              // Título e ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nome, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                    Text("MAT${item.matId}", style: const TextStyle(color: Colors.white70, fontSize: 14)),
                  ],
                ),
              ),
              // Tags
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _TagChip( // Tag de Categoria (azul)
                    label: item.categoria,
                    backgroundColor: const Color(0xFF3B82F6).withOpacity(0.3),
                    textColor: const Color(0xFF93C5FD),
                  ),
                  const SizedBox(height: 4),
                   _TagChip( // Tag de Disponível (verde)
                    label: "Disponível",
                    backgroundColor: Colors.green.withOpacity(0.2),
                    textColor: Colors.green.shade300,
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          // Linha 2: Observação
          const _InfoLinha(
            icon: Icons.info_outline,
            title: "OBS:",
            value: "Retire os materiais na base mais próxima.",
          ),
          const SizedBox(height: 16),
          // Linha 3: Botão
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () { /* TODO: Lógica de Retirada */ },
              icon: const Icon(Icons.upload, size: 16, color: Colors.white),
              label: const Text("Retirar Material"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ===================================================================
// ==================== WIDGETS HELPERS ==============================
// ===================================================================

// --- WIDGET HELPER PARA AS TAGS (Disponível, Atrasado, etc) ---
class _TagChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _TagChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

// --- WIDGET HELPER PARA AS LINHAS DE INFO (Icon + Título + Valor) ---
class _InfoLinha extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;
  final Color? valueColor;

  const _InfoLinha({
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    const Color defaultColor = Colors.white70; // Cor padrão
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? defaultColor, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(color: defaultColor),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? defaultColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}