import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:src/pages/instrumentos_admin_page.dart';
import '../widgets/admin/home_admin/admin_drawer.dart';
import 'animated_network_background.dart';
import '../widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/materiais_admin/filter_bar.dart';
import '../auth/auth_store.dart';

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
  late DateTime _lastUpdated;
  String _selectedCategory = 'Todas as Categorias';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<MaterialItem> _materiais = [];

    final List<String> _categories = [
    'Todas as Categorias',
    'Cabos',
    'Relés',
    'Conectores',
    'EPIs',
    'Ferramentas',
    'Peças',
  ];

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

  Future<void> _fetchMateriais() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    const String baseUrl = "http://localhost:8080";

    final queryParams = <String, String>{"limit": "100", "page": "1"};

    final searchQuery = _searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      queryParams['q'] = searchQuery;
    }

    if (_selectedCategory != "Todas as Categorias") {
      queryParams["categoria"] = _selectedCategory;
    }

    final uri = Uri.parse(
      "$baseUrl/materiais",
    ).replace(queryParameters: queryParams);

    try {
      final response = await http.get(
        uri,
        headers: {"Accept": "application/json"},
      );

      if (response.statusCode == 200) {
        final decodedBody = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> data = decodedBody["data"];
        _materiais = data.map((json) => MaterialItem.fromJson(json)).toList();
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(
          "Falha ao carregar materiais: ${response.statusCode} - ${errorBody["error"]}",
        );
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

  // ---- Chama a API ----
  Future<bool> _addNewMaterial(
    int codSap,
    String descricao,
    String? apelido,
    String? categoria,
    String? unidade,
  ) async {
    // 1. Obter o token (NECESSÁRIO PARA O POST)
    final auth = context.read<AuthStore>();
    final token = auth.token;
    if (token == null || !auth.isAuthenticated) {
      _showSnackBar("Erro: Você não está autenticado.", isError: true);
      return false;
    }

    const String baseUrl = "http://localhost:8080";
    final uri = Uri.parse("$baseUrl/materiais");

    try {
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token", // <- Token de Admin é crucial
        },
        body: json.encode({
          "cod_sap": codSap,
          "descricao": descricao,
          "apelido": (apelido == null || apelido.isEmpty) ? null : apelido,
          "categoria": (categoria == null || categoria.isEmpty)
              ? null
              : categoria,
          "unidade": (unidade == null || unidade.isEmpty) ? null : unidade,
        }),
      );

      if (response.statusCode == 201) {
        _showSnackBar(
          "Material '$descricao' cadastrado com sucesso!",
          isError: false,
        );
        _fetchMateriais(); // Atualiza a lista
        return true;
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha ao cadastrar material");
      }
    } catch (e) {
      _showSnackBar(
        "Erro: ${e.toString().replaceAll("Exception: ", "")}",
        isError: true,
      );
      return false;
    }
  }

  void _showAddMaterialDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AddMaterialDialog(
          // Passa as categorias (sem "Todas") para o dropdown
          categories: _categories.where((c) => c != 'Todas as Categorias').toList(),
          onSave: (codSap, descricao, apelido, categoria, unidade) async {
            // Chama a nova função de API
            return await _addNewMaterial(codSap, descricao, apelido, categoria, unidade);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: () {
                      // TODO: Criar lógica ao clicar em exportar.
                    },
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
                    onPressed: _showAddMaterialDialog,
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
              FilterBar(
                searchController: _searchController,
                selectedCategory: _selectedCategory,
                onCategoryChanged: (newValue) {
                  setState(() {
                    _selectedCategory = newValue!;
                    _fetchMateriais();
                  });
                },
                onSearchChanged: (query) => _fetchMateriais(),
                categories: [
                  'Todas as Categorias',
                  'Cabos',
                  'Relés',
                  'Conectores',
                  'EPIs',
                  'Ferramentas',
                  'Peças',
                ],
                searchHint: 'Buscar por nome ou código...',
              ),
              const SizedBox(height: 24),
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

  void _showSnackBar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red.shade800 : Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(24),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_isLoading) {
      return const SizedBox(
        height: 500,
        child: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF080023)),
          ),
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
                child: Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black87, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _fetchMateriais,
                child: const Text("Tentar Novamente"),
              ),
            ],
          ),
        ),
      );
    }

    if (_materiais.isEmpty) {
      return const SizedBox(
        height: 500,
        child: Center(
          child: Text(
            "Nenhum material encontrado",
            style: TextStyle(color: Colors.black54, fontSize: 18),
          ),
        ),
      );
    }

    return Column(
      children: [
        _buildTableHeader(),
        const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
        SizedBox(
          height: 500,
          child: Scrollbar(
            controller: _scrollController,
            thumbVisibility: true,
            interactive: true,
            child: ListView.separated(
              controller: _scrollController,
              padding: EdgeInsets.zero,
              itemCount: _materiais.length,
              separatorBuilder: (context, index) => const Divider(
                color: Color.fromARGB(59, 102, 102, 102),
                height: 1,
                indent: 16,
                endIndent: 16,
              ),
              itemBuilder: (context, index) =>
                  _buildMaterialRow(_materiais[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black54,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Cód. SAP', style: headerStyle)),
          Expanded(flex: 4, child: Text('Nome', style: headerStyle)),
          Expanded(flex: 3, child: Text('Categoria', style: headerStyle)),
          Expanded(flex: 3, child: Text('Unidade', style: headerStyle)),
          Expanded(flex: 2, child: Text('Status', style: headerStyle)),
          SizedBox(
            width: 56,
            child: Center(child: Text('Ações', style: headerStyle)),
          ),
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
          Expanded(
            flex: 2,
            child: Text(item.codigoSap.toString(), style: cellStyle),
          ),
          Expanded(
            flex: 4,
            child: Text(
              item.descricao,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: _buildChip(
              item.categoria ?? '-',
              Colors.grey.shade300,
              Colors.black54,
            ),
          ),
          Expanded(flex: 3, child: Text(item.unidade ?? '-', style: cellStyle)),
          Expanded(flex: 2, child: _buildStatusChip(item.status)),
          SizedBox(
            width: 56,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.black54),
                onPressed: () {},
              ),
            ),
          ),
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
    final backgroundColor = isAtivo
        ? Colors.green.shade100
        : Colors.red.shade100;
    final textColor = isAtivo ? Colors.green.shade800 : Colors.red.shade800;

    return _buildChip(status, backgroundColor, textColor);
  }
}

class _AddMaterialDialog extends StatefulWidget {
  final Future<bool> Function(
    int codSap,
    String descricao,
    String? apelido,
    String? categoria,
    String? unidade,
  ) onSave;
  final List<String> categories; // Recebe a lista de categorias

  const _AddMaterialDialog({required this.onSave, required this.categories});

  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codSapController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _apelidoController = TextEditingController();
  final TextEditingController _unidadeController = TextEditingController();
  String? _selectedCategoria; // Categoria agora é opcional

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Inicia com a primeira categoria da lista (ou null se vazia)
    _selectedCategoria = widget.categories.isNotEmpty ? widget.categories.first : null;
  }

  @override
  void dispose() {
    _codSapController.dispose();
    _descricaoController.dispose();
    _apelidoController.dispose();
    _unidadeController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() { _isSaving = true; });

    // O validador já garantiu que isso é um int
    final int codSap = int.parse(_codSapController.text.trim());

    final bool success = await widget.onSave(
      codSap,
      _descricaoController.text.trim(),
      _apelidoController.text.trim(),
      _selectedCategoria,
      _unidadeController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).pop();
    } else {
      setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);

    return AlertDialog(
      backgroundColor: primaryColor,
      title: const Text(
        'Adicionar Novo Material',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Cód. SAP (Obrigatório)
              TextFormField(
                controller: _codSapController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(label: 'Cód. SAP *', icon: Icons.qr_code),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O Cód. SAP é obrigatório';
                  }
                  if (int.tryParse(value.trim()) == null) {
                    return 'Deve ser um número válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Descrição (Obrigatório)
              TextFormField(
                controller: _descricaoController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(label: 'Descrição *', icon: Icons.description),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A descrição é obrigatória';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              // Apelido (Opcional)
              TextFormField(
                controller: _apelidoController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(label: 'Apelido', icon: Icons.label_outline),
              ),
              const SizedBox(height: 16),
              // Categoria (Opcional - Dropdown)
              _buildDropdown(
                value: _selectedCategoria,
                hint: 'Selecione uma categoria',
                items: widget.categories,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() { _selectedCategoria = newValue; });
                  }
                },
              ),
              const SizedBox(height: 16),
              // Unidade (Opcional)
              TextFormField(
                controller: _unidadeController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(label: 'Unidade (ex: PC, M, KG)', icon: Icons.straighten),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  // Helper para o Dropdown (estilo dark)
  Widget _buildDropdown({
    required String? value,
    required String hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    const Color inputFillColor = Color.fromARGB(255, 30, 24, 53);
    const Color borderColor = Colors.white30;
    const Color hintColor = Colors.white60;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: inputFillColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          hint: Text(hint, style: const TextStyle(color: hintColor)),
          dropdownColor: const Color(0xFF080023), // Fundo do menu
          icon: const Icon(Icons.arrow_drop_down, color: hintColor),
          style: const TextStyle(color: Colors.white, fontSize: 16),
          onChanged: onChanged,
          items: items.map<DropdownMenuItem<String>>((String displayValue) {
            return DropdownMenuItem<String>(
              value: displayValue,
              child: Text(displayValue),
            );
          }).toList(),
        ),
      ),
    );
  }

  // Helper para estilizar os campos de texto (copiado dos outros popups)
  InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
    const Color inputFillColor = Color.fromARGB(255, 30, 24, 53);
    const Color borderColor = Colors.white30;
    const Color hintColor = Colors.white60;

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: hintColor),
      hintStyle: const TextStyle(color: hintColor),
      prefixIcon: Icon(icon, color: hintColor, size: 20),
      filled: true,
      fillColor: inputFillColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
      ),
    );
  }
}
