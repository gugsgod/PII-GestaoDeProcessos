import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
// import 'package:provider/provider.dart'; // <= ADICIONE 
import 'package:src/auth/auth_store.dart';
import '../widgets/admin/home_admin/admin_drawer.dart';
import 'animated_network_background.dart';
import '../widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/materiais_admin/filter_bar.dart';


class MaterialItem {
  final int id;
  final int codigoSap;
  final String descricao;
  final String? apelido;
  final String? categoria;
  final String? unidade;
  final bool ativo;

  MaterialItem({
    required this.id,
    required this.codigoSap,
    required this.descricao,
    this.apelido,
    this.categoria,
    this.unidade,
    required this.ativo,
  });

  factory MaterialItem.fromJson(Map<String, dynamic> json) {
    return MaterialItem(
      id: json['id'] ?? 0,
      codigoSap: json['cod_sap'] ?? 0,
      descricao: json['descricao'] ?? 'N/A',
      apelido: json['apelido'],
      categoria: json['categoria'],
      unidade: json['unidade'],
      ativo: json['ativo'] ?? false,
    );
  }

  String get status => ativo ? "Ativo" : "Inativo";
}



class MateriaisAdminPage extends StatefulWidget {
  const MateriaisAdminPage({super.key});

  @override
  State<MateriaisAdminPage> createState() => _MateriaisAdminPageState();
}

class _MateriaisAdminPageState extends State<MateriaisAdminPage> {
  // Removido: AuthStore local e _loaded
  late DateTime _lastUpdated;
  String _selectedCategory = 'Todas as Categorias';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  // Estados para controlar o carregamento e erros da API
  bool _isLoading = true;
  String? _errorMessage;
  List<MaterialItem> _materiais = [];

  // Estados para controlar o carregamento e erros da API
  bool _isLoading = true;
  String? _erroMessage;
  List<MaterialItem> _materiais = [];


  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    _fetchMateriais();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // void _atualizarDados() {
  //   setState(() {
  //     _lastUpdated = DateTime.now();
  //     // TODO: carregar dados da API
  //   });

  Future<void> _fetchMateriais() async{
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // ################ PONTO DE INTEGRAÇÃO ##################
    const String baseUrl =  "http://localhost:8080";

    final queryParams = <String, String>{
      "limit": "100",
      "page": "1",
    };

    final searchQuery = _searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      queryParams['q'] = searchQuery;
    }

    if (_selectedCategory != "Todas as Categorias") {
      queryParams["categoria"] = _selectedCategory;
    }

    final uri = Uri.parse("$baseUrl/materiais").replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: {"Accept": "application/json"});

      if (response.statusCode == 200) {
        final decodedBody = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> data = decodedBody["data"];
        _materiais = data.map((json) => MaterialItem.fromJson(json)).toList();

      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception("Falha ao carregar materiais: ${response.statusCode} - ${errorBody["error"]}");
      }

    } catch (e) {
      _errorMessage = "Erro ao conectar com o servidor: ${e.toString()}";

    } finally {
      setState(() {
        _isLoading = false;
        _lastUpdated = DateTime.now();
      });
    }
  }

  void _onSearchChanged(String query) {
    _fetchMateriais();
  }

  @override
  Widget build(BuildContext context) {
    // Lê AuthStore centralizado
    // final auth = context.watch<AuthStore>();
    // if (!auth.isAuthenticated) {
    //   Future.microtask(() => Navigator.pushReplacementNamed(context, '/login'));
    //   return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // }

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
          'Materiais',
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

      // Drawer lê o AuthStore via Provider internamente
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
                onUpdate: _fetchMateriais,
              ),
              const SizedBox(height: 24),

              const Text(
                'Gestão de Materiais',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cadastre, edite e controle os materiais de consumo e giro',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),

              const SizedBox(height: 24),

              // Barra de ações
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.upload_file, color: Colors.white70),
                    label: const Text(
                      'Exportar',
                      style: TextStyle(color: Colors.white),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white30),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Criar Novo Material'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Filtros
              FilterBar(
                searchController: _searchController,
                selectedCategory: _selectedCategory,
                onCategoryChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                    _fetchMateriais();
                  });
                },
                onSearchChanged: _onSearchChanged,
              ),

              const SizedBox(height: 24),

              // Tabela
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(209, 255, 255, 255),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: _buildDataTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_isLoading) {
      return const SizedBox(
        height: 500,
        child: Center(
          child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF080023))),
        ),
      );
    }

    if (_errorMessage != null) {
      return SizedBox(
        height: 500,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 16)),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: _fetchMateriais, child: const Text("Tentar Novamente"))
            ],
          ),
        ),
      );
    }

    if (_materiais.isEmpty) {
      return const SizedBox(
        height: 500,
        child: Center(
          child: Text("Nemnhum material encontrado", style: TextStyle(color: Colors.black54, fontSize: 18)),
        ),
      );
    }

    return Column(
      children: [
        _buildTableHeader(),
        const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
        SizedBox(
          height: 500,
          child: ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: WidgetStateProperty.all(const Color.fromARGB(255, 44, 44, 44)),
              mainAxisMargin: 8.0,
            ),
            child: Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: Scrollbar(
                controller: _scrollController,
                thumbVisibility: true,
                interactive: true,
                child: ListView.separated(
                  controller: _scrollController,
                  padding: EdgeInsets.zero,
                  itemCount: _materiais.length,
                  separatorBuilder: (context, index) => const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) => _buildMaterialRow(_materiais[index]),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Cabeçalho da Tabela
  Widget _buildTableHeader() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.black54);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Cód. SAP', style: headerStyle)),
          Expanded(flex: 4, child: Text('Nome', style: headerStyle)),
          Expanded(flex: 3, child: Text('Categoria', style: headerStyle)),
          Expanded(flex: 3, child: Text('Unidade', style: headerStyle)),
          Expanded(flex: 2, child: Text('Status', style: headerStyle)),
          // Apenas a coluna de Ações continua centralizada
          SizedBox(width: 56, child: Center(child: Text('Ações', style: headerStyle))),
        ],
      ),
    );
  }

  Widget _buildMaterialRow(MaterialItem item) {
    const cellStyle = TextStyle(color: Colors.black87);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.codigoSap.toString(), style: cellStyle)),
          Expanded(flex: 4, child: Text(item.descricao, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold))),
          Expanded(flex: 3, child: _buildChip(item.categoria ?? '-', Colors.grey.shade300, Colors.black54)),
          Expanded(flex: 3, child: Text(item.unidade ?? '-', style: cellStyle)),
          Expanded(flex: 2, child: _buildStatusChip(item.status)),
          // coluna de ações centralizada
          SizedBox(width: 56, child: Center(child: IconButton(icon: const Icon(Icons.more_horiz, color: Colors.black54), onPressed: () {}))),
        ],
      ),
    );
  }
  
  Widget _buildChip(String label, Color color, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final bool isAtivo = status == 'Ativo';
    final backgroundColor = isAtivo ? Colors.green.shade100 : Colors.red.shade100;
    final textColor = isAtivo ? Colors.green.shade800 : Colors.red.shade800;
    
    return _buildChip(status, backgroundColor, textColor);
  }
}
