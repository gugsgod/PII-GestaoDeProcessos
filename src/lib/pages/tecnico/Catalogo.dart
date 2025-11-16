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

class InstrumentoCatalogo {
  final String id;
  final String nome;
  final String patrimonio;
  final String local;
  final DateTime proximaCalibracao;
  final bool disponivel;

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
    final String statusString = json['status']?.toString() ?? 'inativo';
    final bool isAtivo = json['ativo'] as bool? ?? false;

    return InstrumentoCatalogo(
      id: json['id']?.toString() ?? 'N/A',
      nome: json['descricao'] ?? 'N/A',
      patrimonio: json['patrimonio']?.toString() ?? 'N/A',
      // Usando o campo de nome do local que o backend agora envia
      local: json['local_atual_nome']?.toString() ?? 'N/A', 
      proximaCalibracao: DateTime.tryParse(json['proxima_calibracao_em'] ?? '') ?? DateTime.now(),
      
      // CORREÇÃO: Está disponível SOMENTE SE (ativo == true) E (status == 'disponivel')
      disponivel: (isAtivo && statusString == 'disponivel'), 
    );
  }
}

class MaterialCatalogo {
  final int id;
  final String nome;
  final int matId; // cod_sap
  final String categoria;
  final bool disponivel;

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
      // ==========================================================
      // ===== CORREÇÃO AQUI ======================================
      // ==========================================================
      
      // 1. Criamos a URI de Instrumentos COM o filtro ?ativo=true
      // (O seu arquivo estava chamando '/instrumentos' sem filtro)
      final instrumentosUri = Uri.parse('$baseUrl/instrumentos').replace(
        queryParameters: {'ativo': 'true'},
      );
      
      // 2. Criamos a URI de Materiais COM o filtro ?ativo=true
      // (O seu arquivo estava chamando '/materiais' sem filtro)
      final materiaisUri = Uri.parse('$baseUrl/materiais').replace(
        queryParameters: {'limit': '100'}, // Remove 'ativo': 'true'
      );
      // ==========================================================


      // Executa as duas chamadas de API em paralelo
      final responses = await Future.wait([
        http.get(instrumentosUri, headers: headers).timeout(const Duration(seconds: 5)), // <-- URI CORRIGIDA
        http.get(materiaisUri, headers: headers).timeout(const Duration(seconds: 5)),    // <-- URI CORRIGIDA
      ]);

      // Processa resposta de Instrumentos
      if (responses[0].statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(responses[0].bodyBytes));
        _instrumentos = data.map((json) => InstrumentoCatalogo.fromJson(json)).toList();
      } else {
        throw Exception('Falha ao carregar instrumentos: ${responses[0].statusCode}');
      }

      // Processa resposta de Materiais
      if (responses[1].statusCode == 200) {
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
        setState(() => _catalogoError = 'Erro de conexão (CORS ou DNS): ${e.message}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _catalogoError = e.toString().replaceAll("Exception: ", "");
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _filtrarDados(); 
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

  void _abrirModalRetirada(BuildContext context, dynamic item) {
  final auth = context.read<AuthStore>();
  final token = auth.token;

  if (token == null || !auth.isAuthenticated) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Erro de autenticação. Faça login novamente.')),
    );
    return;
  }
  
  // Decide qual modal mostrar
  if (item is InstrumentoCatalogo) {
    showDialog(
      context: context,
      builder: (_) => _ModalRetirarInstrumento(
        item: item,
        token: token,
        onSuccess: _onRetiradaSuccess, // Callback para atualizar a UI
      ),
    );
  } else if (item is MaterialCatalogo) {
    showDialog(
      context: context,
      builder: (_) => _ModalRetirarMaterial(
        item: item,
        token: token,
        onSuccess: _onRetiradaSuccess, // Callback para atualizar a UI
      ),
    );
  }
}

// Callback para recarregar os dados após uma retirada
void _onRetiradaSuccess() {
  // Mostra feedback
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Item retirado com sucesso!'),
      backgroundColor: Colors.green,
    ),
  );
  
  // Recarrega o catálogo para refletir o novo status (item indisponível)
  setState(() {
    // Reinicia o future para forçar a chamada de API
    _isFutureInitialized = false; 
  });
  // Chama o didChangeDependencies "manualmente"
  didChangeDependencies();
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

    final bool isDisponivel = item.disponivel; 

    return Opacity(
      // Se não estiver disponível, deixa o card semi-transparente
      opacity: isDisponivel ? 1.0 : 0.5, 
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(209, 255, 255, 255),
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
                Icon(
                  Icons.construction, 
                  color: isDisponivel ? Colors.green : Colors.grey, // Cor muda com status
                  size: 32
                ),
                const SizedBox(width: 12),
                // Título e ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nome, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text(item.patrimonio, style: const TextStyle(color: Colors.black, fontSize: 14)),
                    ],
                  ),
                ),
                // Tags (AGORA SÃO CONDICIONAIS)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isDisponivel)
                      _TagChip(
                        label: "Disponível",
                        backgroundColor: Colors.green.withOpacity(0.2),
                        textColor: Colors.green,
                      )
                    else
                      _TagChip(
                        label: "Indisponível",
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        textColor: Colors.grey.shade700,
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
              iconColor: Colors.black,
              title: "Local:",
              value: item.local,
              valueColor: Colors.black,
            ),
            // Linha 3: Calibração
            _InfoLinha(
              icon: Icons.calendar_today_outlined,
              title: "Calibração:",
              value: DateFormat('dd/MM/yyyy').format(item.proximaCalibracao),
              iconColor: vencida ? Colors.red.shade300 : Colors.black,
              valueColor: vencida ? Colors.red.shade300 : Colors.black,
            ),
            const SizedBox(height: 16),
            // Linha 4: Botão (AGORA CONDICIONAL)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Desabilita o botão se não estiver disponível
                onPressed: isDisponivel ? () {
                  _abrirModalRetirada(context, item);
                } : null, 
                icon: Icon(Icons.upload, size: 16, color: Colors.white),
                label: Text(isDisponivel ? "Retirar Instrumento" : "Indisponível"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDisponivel ? Colors.green.shade600 : Colors.grey.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Constrói o Card de Material (baseado na image_c17684.png)
  Widget _buildMaterialCard(MaterialCatalogo item) {
    final bool isDisponivel = item.disponivel;
    return Opacity(
      // Se não estiver disponível (inativo), deixa o card semi-transparente
      opacity: isDisponivel ? 1.0 : 0.5,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color.fromARGB(209, 255, 255, 255),
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
                Icon(
                  Icons.inventory_2_outlined, 
                  color: isDisponivel ? const Color(0xFF3B82F6) : Colors.grey, // Cor muda com status
                  size: 32
                ),
                const SizedBox(width: 12),
                // Título e ID
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item.nome, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 16)),
                      Text("MAT${item.matId}", style: const TextStyle(color: Colors.black, fontSize: 14)),
                    ],
                  ),
                ),
                // Tags
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _TagChip( // Tag de Categoria (sempre visível)
                      label: item.categoria,
                      backgroundColor: const Color(0xFF3B82F6).withOpacity(0.3),
                      textColor: Colors.blue,
                    ),
                    const SizedBox(height: 4),
                    // Tag de Status (CONDICIONAL)
                    if (isDisponivel)
                      _TagChip( 
                        label: "Disponível",
                        backgroundColor: Colors.green.withOpacity(0.2),
                        textColor: Colors.green,
                      )
                    else
                       _TagChip(
                        label: "Inativo",
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        textColor: Colors.grey.shade700,
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
            // Linha 3: Botão (CONDICIONAL)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                // Desabilita o botão se não estiver disponível
                onPressed: isDisponivel ? () {
                  _abrirModalRetirada(context, item);
                } : null,
                icon: const Icon(Icons.upload, size: 16, color: Colors.white),
                label: Text(isDisponivel ? "Retirar Material" : "Inativo"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDisponivel ? Colors.green.shade600 : Colors.grey.shade600,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
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
    const Color defaultColor = Colors.black; // Cor padrão
    
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

class _ModalRetirarInstrumento extends StatefulWidget {
  final InstrumentoCatalogo item;
  final String token;
  final VoidCallback onSuccess;

  const _ModalRetirarInstrumento({
    required this.item,
    required this.token,
    required this.onSuccess,
  });

  @override
  State<_ModalRetirarInstrumento> createState() =>
      _ModalRetirarInstrumentoState();
}

class _ModalRetirarInstrumentoState extends State<_ModalRetirarInstrumento> {
  DateTime _previsaoDevolucao = DateTime.now().add(const Duration(days: 1));
  bool _isLoading = false;
  String? _error;

  // Função que faz o POST
  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final body = json.encode({
        // O backend espera o ID do instrumento
        'instrumento_id': widget.item.id,
        // O backend espera a data no formato ISO 8601
        'previsao_devolucao': _previsaoDevolucao.toIso8601String(),
      });

      final response = await http.post(
        Uri.parse('http://localhost:8080/movimentacoes/saida'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop(); // Fecha o modal
        widget.onSuccess(); // Chama o callback
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        setState(() {
          _error = errorData['error'] ?? 'Falha ao retirar o item.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro de conexão: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Simples "Date Picker" (pode ser melhorado)
    // Para um app real, use um pacote como `showDatePicker`
    final TextEditingController dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy HH:mm').format(_previsaoDevolucao),
    );

    return AlertDialog(
      title: Text('Retirar ${widget.item.nome}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Patrimônio: ${widget.item.patrimonio}'),
          const SizedBox(height: 16),
          TextField(
            controller: dateController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Previsão de Devolução',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            onTap: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _previsaoDevolucao,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date == null) return;
              
              if (!mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_previsaoDevolucao),
              );
              if (time == null) return;

              setState(() {
                _previsaoDevolucao = DateTime(
                  date.year, date.month, date.day,
                  time.hour, time.minute,
                );
              });
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirmar Retirada'),
        ),
      ],
    );
  }
}

class _MaterialSaldo {
  final int localId;
  final String localNome;
  final double qtDisp;
  final String? lote;

  _MaterialSaldo({
    required this.localId,
    required this.localNome,
    required this.qtDisp,
    this.lote,
  });

  factory _MaterialSaldo.fromJson(Map<String, dynamic> json) {
    return _MaterialSaldo(
      localId: json['local']['id'],
      localNome: json['local']['nome'] ?? 'Local desconhecido',
      qtDisp: (json['qt_disp'] as num).toDouble(),
      lote: json['lote'],
    );
  }
}


class _ModalRetirarMaterial extends StatefulWidget {
  final MaterialCatalogo item;
  final String token;
  final VoidCallback onSuccess;

  const _ModalRetirarMaterial({
    required this.item,
    required this.token,
    required this.onSuccess,
  });

  @override
  State<_ModalRetirarMaterial> createState() => _ModalRetirarMaterialState();
}

class _ModalRetirarMaterialState extends State<_ModalRetirarMaterial> {
  // Estado da UI
  bool _isLoadingSaldos = true;
  bool _isSubmitting = false;
  String? _error;

  // Dados do formulário
  final TextEditingController _qtController = TextEditingController(text: '1');
  DateTime _previsaoDevolucao = DateTime.now().add(const Duration(days: 1));
  _MaterialSaldo? _saldoSelecionado;
  
  // Lista de locais disponíveis
  List<_MaterialSaldo> _saldos = [];
  
  @override
  void initState() {
    super.initState();
    _fetchSaldos();
  }

  // PASSO 1: Buscar os locais onde este material existe
  Future<void> _fetchSaldos() async {
    setState(() { _isLoadingSaldos = true; _error = null; });
    try {
      final response = await http.get(
        // Usamos o endpoint que você já tem
        Uri.parse('http://localhost:8080/materiais/${widget.item.id}/saldos'),
        headers: { 'Authorization': 'Bearer ${widget.token}' },
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> saldosData = data['saldos'] ?? [];
        
        _saldos = saldosData
            .map((json) => _MaterialSaldo.fromJson(json))
            .where((s) => s.qtDisp > 0) // Só mostrar locais com estoque
            .toList();

        if (_saldos.isNotEmpty) {
          _saldoSelecionado = _saldos.first; // Pré-seleciona o primeiro
        } else {
          _error = 'Este material não tem estoque em nenhum local.';
        }

      } else {
        _error = 'Falha ao buscar locais de estoque.';
      }
    } catch (e) {
      if (mounted) _error = 'Erro de conexão: ${e.toString()}';
    } finally {
      if (mounted) setState(() { _isLoadingSaldos = false; });
    }
  }

  // PASSO 2: Enviar a retirada (POST)
  Future<void> _submit() async {
    setState(() { _isSubmitting = true; _error = null; });

    final double? quantidade = double.tryParse(_qtController.text);

    // Validação
    if (quantidade == null || quantidade <= 0) {
      setState(() { _error = 'Quantidade inválida.'; _isSubmitting = false; });
      return;
    }
    if (_saldoSelecionado == null) {
      setState(() { _error = 'Selecione um local de origem.'; _isSubmitting = false; });
      return;
    }
    if (quantidade > _saldoSelecionado!.qtDisp) {
      setState(() { _error = 'Quantidade indisponível. Máx: ${_saldoSelecionado!.qtDisp}'; _isSubmitting = false; });
      return;
    }

    try {
      final body = json.encode({
        'material_id': widget.item.id,
        'local_id': _saldoSelecionado!.localId,
        'lote': _saldoSelecionado!.lote, // Envia o lote (se houver)
        'quantidade': quantidade,
        'previsao_devolucao': _previsaoDevolucao.toIso8601String(),
      });

      final response = await http.post(
        Uri.parse('http://localhost:8080/movimentacoes/saida'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        body: body,
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        widget.onSuccess();
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        setState(() {
          _error = errorData['error'] ?? 'Falha ao retirar o item.';
          _isSubmitting = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro de conexão: ${e.toString()}';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Retirar ${widget.item.nome}'),
      content: _buildForm(),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          // Desabilitado se estiver buscando saldos OU se não tiver saldos
          onPressed: (_isSubmitting || _isLoadingSaldos || _saldos.isEmpty) ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirmar Retirada'),
        ),
      ],
    );
  }

  // Constrói o formulário
  Widget _buildForm() {
    if (_isLoadingSaldos) {
      return const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text('Buscando locais com estoque...'),
        ],
      );
    }
    
    // (Pode ser melhorado para um DatePicker igual ao do instrumento)
     final TextEditingController dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy HH:mm').format(_previsaoDevolucao),
    );

    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('MAT${widget.item.matId}'),
          const SizedBox(height: 16),
          // 1. Dropdown de Locais
          DropdownButtonFormField<_MaterialSaldo>(
            value: _saldoSelecionado,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Local de Origem',
              border: OutlineInputBorder(),
            ),
            items: _saldos.map((saldo) {
              return DropdownMenuItem(
                value: saldo,
                // Mostra Local, Lote e Quantidade
                child: Text(
                  '${saldo.localNome} (Disponível: ${saldo.qtDisp})',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (saldo) {
              setState(() {
                _saldoSelecionado = saldo;
              });
            },
          ),
          const SizedBox(height: 16),
          // 2. Campo de Quantidade
          TextField(
            controller: _qtController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Quantidade a retirar',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
           // 3. Campo de Data
           TextField(
            controller: dateController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'Previsão de Devolução',
              border: OutlineInputBorder(),
              suffixIcon: Icon(Icons.calendar_today),
            ),
            onTap: () async {
               final date = await showDatePicker(
                context: context,
                initialDate: _previsaoDevolucao,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 365)),
              );
              if (date == null) return;
              
              if (!mounted) return;
              final time = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(_previsaoDevolucao),
              );
              if (time == null) return;

              setState(() {
                _previsaoDevolucao = DateTime(
                  date.year, date.month, date.day,
                  time.hour, time.minute,
                );
              });
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
          ],
        ],
      ),
    );
  }
}