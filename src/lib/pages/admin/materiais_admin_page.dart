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
        // Assuming your base URL is correctly defined elsewhere
        Uri.parse('$apiBaseUrl/locais'),
        headers: {'Authorization': 'Bearer $token'},
      );

      // --- DEBUG AQUI ---
      print('Status Code GET /locais: ${response.statusCode}');
      // --- FIM DEBUG ---

      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body)['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _locais = jsonList.map((j) => LocalFisico.fromJson(j as Map<String, dynamic>)).toList();
          });
        }
      } 
      // ... (Error handling omitted for brevity) ...
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
  Future<void> _addNewMaterial(Map<String, dynamic> data) async {
    // 1. Obter o token (NECESSÁRIO PARA O POST)
    final token = Provider.of<AuthStore>(context, listen: false).token;
    if (token == null) return;

    try {
      final response = await http.post(
        Uri.parse('$apiBaseUrl/materiais'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'cod_sap': data['cod_sap'],
          'descricao': data['descricao'],
          'apelido': data['apelido'],
          'categoria': data['categoria'],
          'unidade': data['unidade'],
          'ativo': data['ativo'],
          'quantidade_inicial': data['quantidade_inicial'],
          'local_id': data['local_id'],
          'lote': data['lote'],
        })
      );

      if (response.statusCode == 201) {
        _showSnackBar(
          "Material '${data['descricao']}' cadastrado com sucesso!",
          isError: false,
        );
        _fetchMateriais(); // Atualiza a lista
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha ao cadastrar material");
      }
    } catch (e) {
      _showSnackBar(
        "Erro: ${e.toString().replaceAll("Exception: ", "")}",
        isError: true,
      );
    }
  }

void _showAddMaterialDialog() {
    if (_isLoadingLocais) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aguarde, carregando locais disponíveis...')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return _AddMaterialDialog(
          // TODO: parâmetro categorias
          categories: _categories.where((c) => c != 'Todas as Categorias').toList(),
          locaisDisponiveis: _locais, // <-- PASSANDO LOCAIS
          onMaterialAdded: (data) async {
            await _addNewMaterial(data);
            Navigator.of(context).pop();
            _fetchMateriais();
          },
        );
      },
    );
  }

  void _removeMaterial(MaterialItem material) async {
    // Mostra o dialog de confirmação
    final bool? confirmed = await _showDeleteConfirmDialog(material);

    // Se o usuário confirmou (true) e o widget ainda está "montado" (na tela)
    if (confirmed == true && mounted) {
      // Chama a função que executa a exclusão
      await _performDelete(material);
    }
  }

  /// 2. Executa a chamada de API DELETE
  Future<void> _performDelete(MaterialItem material) async {
    // Pega o token de autenticação
    final auth = context.read<AuthStore>();
    final token = auth.token;
    if (token == null) {
      _showSnackBar("Erro: Usuário não autenticado.", isError: true);
      return;
    }

    // O backend espera um 'id' (int), mas o modelo 'Instrument' tem 'id' (String).
    // Precisamos converter.
    final int codSap = material.codigoSap;

    // Prepara a chamada de API
    final uri = Uri.parse("$apiBaseUrl/materiais"); // Rota do backend

    try {
      final response = await http.delete(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
        // O backend (index.dart) espera o ID no corpo da requisição
        body: json.encode({'cod_sap': codSap}),
      );

      // 204 (No Content) é a resposta padrão de sucesso para DELETE
      if (response.statusCode == 204 || response.statusCode == 200) {
        _showSnackBar(
          "Instrumento '${material.descricao}' removido com sucesso!",
          isError: false,
        );
        _fetchMateriais(); // Atualiza a lista de instrumentos
      } else {
        // Trata erros (como 404 - Não encontrado, 500 - Erro de servidor)
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha ao remover instrumento");
      }
    } catch (e) {
      // Trata erros de conexão ou outros
      _showSnackBar(
        "Erro: ${e.toString().replaceAll("Exception: ", "")}",
        isError: true,
      );
    }
  }

  Future<bool?> _showDeleteConfirmDialog(MaterialItem material) {
    const Color primaryColor = Color(0xFF080023); // Cor do tema escuro

    return showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: primaryColor,
          title: const Text(
            'Confirmar Exclusão',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            "Tem certeza que deseja remover o instrumento:\n\n'${material.descricao}' (Patrimônio: ${material.codigoSap})?\n\nEsta ação não pode ser desfeita.",
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(false), // Retorna 'false'
              child: const Text(
                'Cancelar',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(context).pop(true), // Retorna 'true'
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade800, // Cor de perigo
                foregroundColor: Colors.white,
              ),
              child: const Text('Excluir'),
            ),
          ],
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
                    onPressed: _exportarPDF,
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
                  'Redes',
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

  // botão exportar
  Future<void> _exportarPDF() async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            pw.Center(
              child: pw.Text(
                'Relatório de Materiais',
                style: pw.TextStyle(
                  fontSize: 20,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Cód. SAP', 'Nome', 'Categoria', 'Unidade', 'Status'],
              data: _materiais.map((m) {
                return [
                  m.codigoSap.toString(),
                  m.descricao,
                  m.categoria ?? '-',
                  m.unidade ?? '-',
                  m.status,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.grey300,
              ),
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'materiais.pdf');
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
              child: TableActionsMenu(
                onEditPressed: () => {},
                onRemovePressed: () => {_removeMaterial(item)},
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
  // NOVA ASSINATURA: Agora recebe os locais e um callback que aceita o Mapa de dados
  final List<String> categories;
  final List<LocalFisico> locaisDisponiveis;
  final void Function(Map<String, dynamic>) onMaterialAdded;

  const _AddMaterialDialog({
    required this.categories,
    required this.locaisDisponiveis, 
    required this.onMaterialAdded,
  });

  @override
  State<_AddMaterialDialog> createState() => _AddMaterialDialogState();
}

class _AddMaterialDialogState extends State<_AddMaterialDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _codSapController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _apelidoController = TextEditingController();
  final TextEditingController _unidadeController = TextEditingController();
  // NOVOS CONTROLADORES PARA ESTOQUE
  final TextEditingController _quantidadeController = TextEditingController();
  final TextEditingController _loteController = TextEditingController();
  
  LocalFisico? _selectedLocal;
  String? _error; // Para exibir erros de validação de estoque
  String? _selectedCategoria; 
  bool _isSaving = false;
  bool _ativo = true; 

  @override
  void initState() {
    super.initState();
    _selectedCategoria = widget.categories.isNotEmpty ? widget.categories.first : null;

    if (widget.categories.isEmpty) {
      _selectedCategoria = widget.categories.first;
    }
    
    // Inicia com o primeiro local disponível (para estoque inicial)
    if (widget.locaisDisponiveis.isNotEmpty) {
      _selectedLocal = widget.locaisDisponiveis.first;
    }
  }

  @override
  void dispose() {
    _codSapController.dispose();
    _descricaoController.dispose();
    _apelidoController.dispose();
    _unidadeController.dispose();
    // DISPOSE DOS NOVOS CONTROLADORES
    _quantidadeController.dispose();
    _loteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // 1. VALIDAÇÃO DOS CAMPOS DE TEXTO E DROPDOWN
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (widget.locaisDisponiveis.isEmpty) {
      setState(() {
        _error = 'Nenhum local de estoque encontrado. Cadastre um local primeiro.';
        _isSaving = false;
      });
      return;
    }
    
    // 2. VALIDAÇÃO DOS NOVOS CAMPOS DE ESTOQUE
    final quantidade = num.tryParse(_quantidadeController.text.trim());

    if (quantidade == null || quantidade <= 0) {
      setState(() {
        _error = 'Quantidade Inicial deve ser um número positivo.';
        _isSaving = false;
      });
      return;
    }
    if (_selectedLocal == null) {
      setState(() {
        _error = 'Um Local de Estoque deve ser selecionado.';
        _isSaving = false;
      });
      return;
    }
    
    // Limpa erro anterior e inicia o estado de salvamento
    setState(() {
      _error = null;
      _isSaving = true;
    });

    // 3. PREPARAÇÃO DE DADOS E CHAMADA DE API
    
    final finalLote = _loteController.text.trim().isEmpty ? null : _loteController.text.trim();
    
    // CHAMA O CALLBACK COM TODOS OS DADOS (8 PARÂMETROS)
    widget.onMaterialAdded({
      'cod_sap': int.parse(_codSapController.text.trim()),
      'descricao': _descricaoController.text.trim(),
      'apelido': _apelidoController.text.trim(),
      'categoria': _selectedCategoria,
      'unidade': _unidadeController.text.trim(),
      'ativo': _ativo,
      // NOVOS PARÂMETROS DE ESTOQUE:
      'quantidade_inicial': quantidade,
      'local_id': _selectedLocal!.id,
      'lote': finalLote,
    });
    
    // O Navigator.pop() e o _isSaving=false serão tratados na função _addNewMaterial 
    // no parent widget (MateriaisAdminPage), após a chamada da API.
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
              // CÓDIGO SAP, DESCRIÇÃO, APELIDO, CATEGORIA, UNIDADE
              // (Mantido igual)
              TextFormField(
                controller: _codSapController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  label: 'Cód. SAP *',
                  icon: Icons.qr_code,
                ),
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
              TextFormField(
                controller: _descricaoController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'Descrição *',
                  icon: Icons.description,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A descrição é obrigatória';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _apelidoController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'Apelido',
                  icon: Icons.label_outline,
                ),
              ),
              const SizedBox(height: 16),
              _buildDropdown(
                value: _selectedCategoria,
                hint: 'Selecione uma categoria',
                items: widget.categories,
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedCategoria = newValue;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _unidadeController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'Unidade (ex: PC, M, KG)',
                  icon: Icons.straighten,
                ),
              ),
              
              const SizedBox(height: 24),
              // --- SEÇÃO DE ESTOQUE INICIAL ---
              const Divider(color: Colors.white30, thickness: 1),
              const SizedBox(height: 16),
              const Text(
                'ESTOQUE INICIAL (Obrigatório)',
                style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 16),

              // 1. CAMPO QUANTIDADE INICIAL
              TextFormField(
                controller: _quantidadeController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  label: 'Quantidade Inicial *',
                  icon: Icons.numbers,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Obrigatório.';
                  if (num.tryParse(value.trim()) == null || (num.tryParse(value.trim()) ?? 0) <= 0) return 'Deve ser um número positivo.';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // 2. CAMPO LOCAL DE ESTOQUE
              _buildDropdown(
                label: 'Local de Estoque *',
                icon: Icons.place,
                value: _selectedLocal?.nome,
                hint: 'Local de estoque',
                items: widget.locaisDisponiveis.map((l) => l.nome).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedLocal = widget.locaisDisponiveis.firstWhere((l) => l.nome == newValue);
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // 3. CAMPO LOTE (Opcional)
              TextFormField(
                controller: _loteController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'Lote (Opcional)',
                  icon: Icons.bookmark_border,
                ),
              ),
              
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Salvar'),
        ),
      ],
    );
  }
  
  // Funções Helpers (Mantidas iguais para o resto do arquivo)
  Widget _buildDropdown({
    required String? value,
    required hint,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    String label = '',
    IconData? icon,
  }) {
    const Color inputFillColor = Color.fromARGB(255, 30, 24, 53);
    const Color borderColor = Colors.white30;
    const Color hintColor = Colors.white60;
    
    // Usando um Container com Row para simular o prefixIcon do InputDecoration
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) Text(label, style: const TextStyle(color: hintColor, fontSize: 12)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: inputFillColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              if (icon != null) Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: Icon(icon, color: hintColor, size: 20),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    isExpanded: true,
                    hint: Text(hint, style: const TextStyle(color: hintColor)),
                    dropdownColor: const Color(0xFF080023), 
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
              ),
            ],
          ),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({
    required String label,
    required IconData icon,
  }) {
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
