import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../widgets/admin/home_admin/admin_drawer.dart';
import 'animated_network_background.dart';
import '../../widgets/admin/home_admin/update_status_bar.dart';
import '../../widgets/admin/materiais_admin/filter_bar.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../auth/auth_store.dart';
import '../../widgets/admin/materiais_admin/table_actions_menu.dart';

final String apiBaseUrl = "http://localhost:8080";

class LocalFisico {
  final int id;
  final String nome;
  final String? contexto;

  LocalFisico({
    required this.id,
    required this.nome,
    this.contexto,
  });

  factory LocalFisico.fromJson(Map<String, dynamic> json) {
    return LocalFisico(
      id: json['id'] as int,
      nome: json['nome'] as String,
      contexto: json['contexto'] as String?,
    );
  }

  @override
  String toString() {
    return '$nome (${contexto?.toUpperCase() ?? 'N/D'})';
  }
}

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
    'Redes',
    'Conectores',
    'EPIs',
    'Ferramentas',
    'Peças',
  ];

  List<LocalFisico> _locais = [];
  bool _isLoadingLocais = true;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    _fetchMateriais();
    _fetchLocais();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLocais() async {
    final token = Provider.of<AuthStore>(context, listen: false).token;
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$apiBaseUrl/locais'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body)['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _locais = jsonList.map((j) => LocalFisico.fromJson(j as Map<String, dynamic>)).toList();
          });
        }
      } 
    } catch (e) {
      print('Erro de rede ao buscar locais: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingLocais = false;
        });
      }
    }
  }

  Future<void> _fetchMateriais() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final queryParams = <String, String>{"limit": "100", "page": "1"};

    final searchQuery = _searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      queryParams['q'] = searchQuery;
    }

    if (_selectedCategory != "Todas as Categorias") {
      queryParams["categoria"] = _selectedCategory;
    }

    final uri = Uri.parse("$apiBaseUrl/materiais").replace(queryParameters: queryParams);

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

  // ---- API POST (CRIAR) ----
  Future<void> _addNewMaterial(Map<String, dynamic> data) async {
    final token = Provider.of<AuthStore>(context, listen: false).token;
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/materiais'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data)
      );

      if (response.statusCode == 201) {
        _showSnackBar("Material cadastrado com sucesso!", isError: false);
        _fetchMateriais(); 
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha ao cadastrar material");
      }
    } catch (e) {
      _showSnackBar("Erro: ${e.toString().replaceAll("Exception: ", "")}", isError: true);
    }
  }

  // ---- API PATCH (EDITAR) ----
  Future<void> _editMaterial(int id, Map<String, dynamic> data) async {
    final token = Provider.of<AuthStore>(context, listen: false).token;
    if (token == null) return;

    try {
      // Garante que o ID está no corpo
      data['id'] = id;
      
      final response = await http.patch(
        Uri.parse('$apiBaseUrl/materiais'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data)
      );

      if (response.statusCode == 200) {
        _showSnackBar("Material atualizado com sucesso!", isError: false);
        _fetchMateriais(); 
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha ao atualizar material");
      }
    } catch (e) {
      _showSnackBar("Erro ao editar: ${e.toString().replaceAll("Exception: ", "")}", isError: true);
    }
  }

  Future<void> _performStockAdjustment(int materialId, Map<String, dynamic> data) async {
    final token = Provider.of<AuthStore>(context, listen: false).token;
    if (token == null) return;

    // Prepara o corpo
    data['material_id'] = materialId;

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/movimentacoes/ajuste'), // Endpoint novo
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Estoque ajustado com sucesso!", isError: false);
      } else {
        final err = jsonDecode(utf8.decode(response.bodyBytes));
        throw Exception(err['error'] ?? 'Falha no ajuste');
      }
    } catch (e) {
      _showSnackBar("Erro no ajuste: $e", isError: true);
    }
  }

  // ---- ABERTURA DO DIALOG (CRIAR OU EDITAR) ----
  void _showMaterialDialog({MaterialItem? material}) {
    // Se for criação, precisamos dos locais. Se for edição, não necessariamente (só se formos editar estoque, mas aqui editamos cadastro)
    // Por segurança, barramos se locais não carregaram e é criação.
    if (material == null && (_isLoadingLocais || _locais.isEmpty)) {
      _showSnackBar(_isLoadingLocais ? "Carregando locais..." : "Nenhum local cadastrado!", isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return _AddOrEditMaterialDialog(
          // Passa categorias filtradas (sem 'Todas')
          categories: _categories.where((c) => c != 'Todas as Categorias').toList(),
          locaisDisponiveis: _locais,
          materialParaEditar: material, // NULL = CRIAÇÃO, OBJETO = EDIÇÃO
          onSave: (data) async {
            if (material == null) {
              await _addNewMaterial(data);
            } else {
              await _editMaterial(material.id, data);
            }
            if (mounted) Navigator.of(context).pop();
          },
        );
      },
    );
  }

  void _showStockAdjustmentDialog(MaterialItem material) {
    if (_isLoadingLocais || _locais.isEmpty) {
      _showSnackBar("Carregando locais...", isError: true);
      return;
    }
    showDialog(
      context: context,
      builder: (context) => _AjusteEstoqueDialog(
        material: material,
        locaisDisponiveis: _locais,
        onSave: (data) async {
          await _performStockAdjustment(material.id, data);
          if (mounted) Navigator.of(context).pop();
        },
      ),
    );
  }

  // ---- API DELETE (REMOVER/DESATIVAR) ----
  void _removeMaterial(MaterialItem material) async {
    final bool? confirmed = await _showDeleteConfirmDialog(material);
    if (confirmed == true && mounted) {
      await _performDelete(material);
    }
  }

  Future<void> _performDelete(MaterialItem material) async {
    final token = Provider.of<AuthStore>(context, listen: false).token;
    if (token == null) {
      _showSnackBar("Erro: Usuário não autenticado.", isError: true);
      return;
    }

    final int codSap = material.codigoSap;
    final uri = Uri.parse("$apiBaseUrl/materiais"); 

    try {
      final response = await http.delete(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode({'cod_sap': codSap}),
      );

      if (response.statusCode == 204 || response.statusCode == 200) {
        _showSnackBar("Material '${material.descricao}' removido com sucesso!", isError: false);
        _fetchMateriais();
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha ao remover material");
      }
    } catch (e) {
      _showSnackBar("Erro: ${e.toString().replaceAll("Exception: ", "")}", isError: true);
    }
  }

  Future<bool?> _showDeleteConfirmDialog(MaterialItem material) {
    const Color primaryColor = Color(0xFF080023);

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: primaryColor,
          title: const Text('Confirmar Exclusão', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            "Tem certeza que deseja remover o material:\n\n'${material.descricao}' (SAP: ${material.codigoSap})?\n\nEsta ação o marcará como inativo.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white,
              ),
              child: const Text('Excluir'),
            ),
          ],
        );
      },
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

  Future<void> _exportarPDF() async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.nunitoExtraLight();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) {
          return [
            pw.Center(child: pw.Text('Relatório de Materiais', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Cód. SAP', 'Nome', 'Categoria', 'Unidade', 'Status'],
              data: _materiais.map((m) => [
                m.codigoSap.toString(),
                m.descricao,
                m.categoria ?? '-',
                m.unidade ?? '-',
                m.status,
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'materiais.pdf');
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
        flexibleSpace: const AnimatedNetworkBackground(numberOfParticles: 35, maxDistance: 50.0),
        title: const Text('Materiais', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Padding(padding: const EdgeInsets.only(right: 20.0), child: Image.asset('assets/images/logo_metroSP.png', height: 50)),
        ],
      ),
      drawer: const AdminDrawer(primaryColor: Color(0xFF080023), secondaryColor: Color.fromARGB(255, 0, 14, 92)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UpdateStatusBar(isDesktop: isDesktop, lastUpdated: _lastUpdated, onUpdate: _fetchMateriais),
              const SizedBox(height: 24),
              const Text('Gestão de Materiais', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Cadastre, edite e controle os materiais de consumo e giro', style: TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: _exportarPDF,
                    icon: const Icon(Icons.upload_file, color: Colors.white70),
                    label: const Text('Exportar', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: () => _showMaterialDialog(), // Abre modo CRIAÇÃO
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Criar Novo Material'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
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
                  'Todas as Categorias', 'Cabos', 'Relés', 'Redes', 'Conectores', 'EPIs', 'Ferramentas', 'Peças',
                ],
                searchHint: 'Buscar por nome ou código...',
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(color: const Color.fromARGB(209, 255, 255, 255), borderRadius: BorderRadius.circular(16)),
                child: _buildDataTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    if (_isLoading) return const SizedBox(height: 500, child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF080023)))));
    if (_errorMessage != null) return SizedBox(height: 500, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, color: Colors.red, size: 48), const SizedBox(height: 16), Text(_errorMessage!, style: const TextStyle(color: Colors.black87, fontSize: 16)), const SizedBox(height: 16), ElevatedButton(onPressed: _fetchMateriais, child: const Text("Tentar Novamente"))])));
    if (_materiais.isEmpty) return const SizedBox(height: 500, child: Center(child: Text("Nenhum material encontrado", style: TextStyle(color: Colors.black54, fontSize: 18))));

    return Column(
      children: [
        _buildTableHeader(),
        const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
        // Usamos um container com altura limitada ou shrinkwrap se não houver Expanded pai
        // Aqui o container pai já tem width infinito.
        ListView.separated(
          controller: _scrollController,
          shrinkWrap: true, // Importante dentro de SingleChildScrollView
          physics: const NeverScrollableScrollPhysics(), // Scroll da página cuida disso
          padding: EdgeInsets.zero,
          itemCount: _materiais.length,
          separatorBuilder: (context, index) => const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1, indent: 16, endIndent: 16),
          itemBuilder: (context, index) => _buildMaterialRow(_materiais[index]),
        ),
      ],
    );
  }

  Widget _buildTableHeader() {
    const headerStyle = TextStyle(fontWeight: FontWeight.bold, color: Colors.black54);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: const Row(
        children: [
          Expanded(flex: 2, child: Text('Cód. SAP', style: headerStyle)),
          Expanded(flex: 4, child: Text('Nome', style: headerStyle)),
          Expanded(flex: 3, child: Text('Categoria', style: headerStyle)),
          Expanded(flex: 2, child: Text('Unidade', style: headerStyle)),
          Expanded(flex: 2, child: Text('Status', style: headerStyle)),
          SizedBox(width: 56, child: Center(child: Text('Ações', style: headerStyle))),
        ],
      ),
    );
  }

  Widget _buildMaterialRow(MaterialItem item) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Expanded(flex: 2, child: Text(item.codigoSap.toString())),
        Expanded(flex: 4, child: Text(item.descricao)),
        Expanded(flex: 3, child: Text(item.categoria ?? '-')), // Simplificado style
        Expanded(flex: 2, child: Text(item.unidade ?? '-')),
        Expanded(flex: 2, child: Text(item.status)),
        SizedBox(
          width: 56,
          child: Center(
            child: TableActionsMenu(
              onEditPressed: () => _showMaterialDialog(material: item),
              onRemovePressed: () => _removeMaterial(item),
              // A mágica acontece aqui: passamos a função opcional
              onAdjustStockPressed: () => _showStockAdjustmentDialog(item), 
            ),
          ),
        ),
      ]),
    );
  }

  Widget _buildChip(String label, Color color, Color textColor) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
        child: Text(label, style: TextStyle(color: textColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    final bool isAtivo = status == 'Ativo';
    return _buildChip(status, isAtivo ? Colors.green.shade100 : Colors.red.shade100, isAtivo ? Colors.green.shade800 : Colors.red.shade800);
  }
}

// ==================================================================
// ===== DIALOG UNIFICADO (CRIAÇÃO E EDIÇÃO) ========================
// ==================================================================

class _AddOrEditMaterialDialog extends StatefulWidget {
  final List<String> categories;
  final List<LocalFisico> locaisDisponiveis;
  final MaterialItem? materialParaEditar; // Se null = Criação
  final void Function(Map<String, dynamic>) onSave;

  const _AddOrEditMaterialDialog({
    required this.categories,
    required this.locaisDisponiveis,
    this.materialParaEditar,
    required this.onSave,
  });

  @override
  State<_AddOrEditMaterialDialog> createState() => _AddOrEditMaterialDialogState();
}

class _AddOrEditMaterialDialogState extends State<_AddOrEditMaterialDialog> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _codSapController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _apelidoController = TextEditingController();
  final _unidadeController = TextEditingController();
  final _quantidadeController = TextEditingController(); // Só para criação
  final _loteController = TextEditingController();       // Só para criação

  LocalFisico? _selectedLocal;
  String? _selectedCategoria;
  bool _isSaving = false;
  bool _ativo = true; 
  String? _error;

  bool get isEditing => widget.materialParaEditar != null;

  @override
  void initState() {
    super.initState();
    
    // Inicializa campos
    if (isEditing) {
      final m = widget.materialParaEditar!;
      _codSapController.text = m.codigoSap.toString();
      _descricaoController.text = m.descricao;
      _apelidoController.text = m.apelido ?? '';
      _unidadeController.text = m.unidade ?? '';
      _selectedCategoria = m.categoria;
      _ativo = m.ativo;
    } else {
      // Criação: defaults
      if (widget.categories.isNotEmpty) _selectedCategoria = widget.categories.first;
      if (widget.locaisDisponiveis.isNotEmpty) _selectedLocal = widget.locaisDisponiveis.first;
    }
    
    // Garante categoria válida (se a lista mudou ou é inválida)
    if (_selectedCategoria != null && !widget.categories.contains(_selectedCategoria)) {
        // Se não estiver na lista, ou deixa null ou seleciona o primeiro
        if (widget.categories.isNotEmpty) _selectedCategoria = widget.categories.first;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validações extras apenas para criação (Estoque Inicial)
    if (!isEditing) {
       final qtd = num.tryParse(_quantidadeController.text.trim());
       if (qtd == null || qtd <= 0) {
         setState(() => _error = 'Quantidade inicial obrigatória e positiva.');
         return;
       }
       if (_selectedLocal == null) {
         setState(() => _error = 'Local obrigatório para estoque inicial.');
         return;
       }
    }

    setState(() { _isSaving = true; _error = null; });

    // Monta o mapa de dados
    final data = {
      'cod_sap': int.tryParse(_codSapController.text.trim()),
      'descricao': _descricaoController.text.trim(),
      'apelido': _apelidoController.text.trim(),
      'categoria': _selectedCategoria,
      'unidade': _unidadeController.text.trim(),
      'ativo': _ativo,
    };

    // Se for criação, adiciona dados de estoque
    if (!isEditing) {
      data['quantidade_inicial'] = num.parse(_quantidadeController.text.trim());
      data['local_id'] = _selectedLocal!.id;
      data['lote'] = _loteController.text.trim().isEmpty ? null : _loteController.text.trim();
    }

     widget.onSave(data);
    
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF080023);
    const inputFill = Color.fromARGB(255, 30, 24, 53);

    return AlertDialog(
      backgroundColor: primaryColor,
      title: Text(isEditing ? 'Editar Material' : 'Adicionar Novo Material', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller: _codSapController, label: 'Cód. SAP *', icon: Icons.qr_code, isNumber: true),
              const SizedBox(height: 16),
              _buildTextField(controller: _descricaoController, label: 'Descrição *', icon: Icons.description),
              const SizedBox(height: 16),
              _buildTextField(controller: _apelidoController, label: 'Apelido', icon: Icons.label),
              const SizedBox(height: 16),
              // DROPDOWN DE CATEGORIA
              _buildDropdown(
                value: _selectedCategoria,
                items: widget.categories,
                hint: 'Categoria',
                onChanged: (v) => setState(() => _selectedCategoria = v),
                label: 'Categoria',
                icon: Icons.category
              ),
              const SizedBox(height: 16),
              _buildTextField(controller: _unidadeController, label: 'Unidade', icon: Icons.straighten),
              
              // SWITCH DE ATIVO/INATIVO (Só na edição)
              if (isEditing) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white30)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Material Ativo?", style: TextStyle(color: Colors.white)),
                      Switch(
                        value: _ativo, 
                        onChanged: (v) => setState(() => _ativo = v), 
                        activeColor: const Color(0xFF3B82F6)
                      ),
                    ],
                  ),
                ),
              ],

              // CAMPOS DE ESTOQUE (SÓ NA CRIAÇÃO)
              if (!isEditing) ...[
                const SizedBox(height: 24),
                const Divider(color: Colors.white24),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8.0),
                  child: Text("Estoque Inicial", style: TextStyle(color: Color(0xFF3B82F6), fontWeight: FontWeight.bold)),
                ),
                _buildTextField(controller: _quantidadeController, label: 'Quantidade *', icon: Icons.numbers, isNumber: true),
                const SizedBox(height: 16),
                // Dropdown de Local
                _buildDropdown(
                  value: _selectedLocal?.nome,
                  items: widget.locaisDisponiveis.map((l) => l.nome).toList(),
                  hint: 'Local de Estoque',
                  label: 'Local *',
                  icon: Icons.place,
                  onChanged: (val) {
                    setState(() {
                       // Assumindo nomes únicos para simplificar o dropdown por string
                       try {
                         _selectedLocal = widget.locaisDisponiveis.firstWhere((l) => l.nome == val);
                       } catch (_) {}
                    });
                  },
                ),
                const SizedBox(height: 16),
                _buildTextField(controller: _loteController, label: 'Lote (Opcional)', icon: Icons.bookmark_border),
              ],

              if (_error != null) Padding(padding: const EdgeInsets.only(top: 16), child: Text(_error!, style: const TextStyle(color: Colors.red))),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.white70))),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
          child: _isSaving ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text("Salvar"),
        ),
      ],
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon, bool isNumber = false}) {
    return TextFormField(
      controller: controller,
      keyboardType: isNumber ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      validator: (v) => (label.contains('*') && (v == null || v.trim().isEmpty)) ? 'Obrigatório' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white60),
        filled: true, fillColor: const Color.fromARGB(255, 30, 24, 53),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white30)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.white30)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value, 
    required List<String> items, 
    required String hint, 
    required ValueChanged<String?> onChanged,
    String label = '',
    IconData? icon,
  }) {
     const Color inputFillColor = Color.fromARGB(255, 30, 24, 53);
     const Color borderColor = Colors.white30;
     const Color hintColor = Colors.white60;

     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         if (label.isNotEmpty) ...[
            // Label simulado se desejar, ou deixe o hint cuidar
         ],
         Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(color: inputFillColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
            child: Row(
              children: [
                if (icon != null) ...[
                   Icon(icon, color: hintColor),
                   const SizedBox(width: 12),
                ],
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: value,
                      isExpanded: true,
                      dropdownColor: const Color(0xFF080023),
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white60),
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      hint: Text(hint, style: const TextStyle(color: Colors.white60)),
                      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
                      onChanged: onChanged,
                    ),
                  ),
                ),
              ],
            ),
         ),
       ],
     );
  }
}

class _AjusteEstoqueDialog extends StatefulWidget {
  final MaterialItem material;
  final List<LocalFisico> locaisDisponiveis;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _AjusteEstoqueDialog({
    required this.material,
    required this.locaisDisponiveis,
    required this.onSave,
  });

  @override
  State<_AjusteEstoqueDialog> createState() => _AjusteEstoqueDialogState();
}

class _AjusteEstoqueDialogState extends State<_AjusteEstoqueDialog> {
  final _formKey = GlobalKey<FormState>();
  final _quantidadeController = TextEditingController();
  final _motivoController = TextEditingController();
  final _loteController = TextEditingController();
  
  LocalFisico? _selectedLocal;
  String _tipoAjuste = 'adicionar'; // 'adicionar' ou 'remover'
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.locaisDisponiveis.isNotEmpty) _selectedLocal = widget.locaisDisponiveis.first;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    await widget.onSave({
      'local_id': _selectedLocal!.id,
      'quantidade': num.parse(_quantidadeController.text.trim()),
      'tipo': _tipoAjuste,
      'motivo': _motivoController.text.trim(),
      'lote': _loteController.text.trim().isEmpty ? null : _loteController.text.trim(),
    });

    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF080023);
    const inputFill = Color.fromARGB(255, 30, 24, 53);

    return AlertDialog(
      backgroundColor: primaryColor,
      title: Text('Ajustar Estoque: ${widget.material.descricao}', style: const TextStyle(color: Colors.white, fontSize: 16)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Toggle Tipo
              Row(
                children: [
                  Expanded(child: RadioListTile<String>(
                    title: const Text('Adicionar', style: TextStyle(color: Colors.white)),
                    value: 'adicionar', 
                    groupValue: _tipoAjuste, 
                    activeColor: Colors.green,
                    onChanged: (v) => setState(() => _tipoAjuste = v!),
                  )),
                  Expanded(child: RadioListTile<String>(
                    title: const Text('Baixa/Perda', style: TextStyle(color: Colors.white)),
                    value: 'remover', 
                    groupValue: _tipoAjuste, 
                    activeColor: Colors.red,
                    onChanged: (v) => setState(() => _tipoAjuste = v!),
                  )),
                ],
              ),
              const SizedBox(height: 16),

              // Local
              Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white30)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedLocal?.nome,
                      dropdownColor: primaryColor,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.white60),
                      style: const TextStyle(color: Colors.white),
                      hint: const Text("Local *", style: TextStyle(color: Colors.white60)),
                      items: widget.locaisDisponiveis.map((l) => DropdownMenuItem(value: l.nome, child: Text(l.nome))).toList(),
                      onChanged: (val) => setState(() => _selectedLocal = widget.locaisDisponiveis.firstWhere((l) => l.nome == val)),
                    ),
                  ),
              ),
              const SizedBox(height: 16),

              // Quantidade
              TextFormField(
                controller: _quantidadeController,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Quantidade *',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true, fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || num.tryParse(v) == null) ? 'Inválido' : null,
              ),
              const SizedBox(height: 16),
              
              // Lote
              TextFormField(
                controller: _loteController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Lote (Opcional)',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true, fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Motivo
              TextFormField(
                controller: _motivoController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Motivo do Ajuste *',
                  labelStyle: const TextStyle(color: Colors.white60),
                  filled: true, fillColor: inputFill,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório para auditoria' : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.white70))),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          style: ElevatedButton.styleFrom(backgroundColor: _tipoAjuste == 'adicionar' ? Colors.green : Colors.red),
          child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Confirmar Ajuste", style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}