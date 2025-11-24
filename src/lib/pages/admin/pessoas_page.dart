import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';
import 'package:src/widgets/admin/home_admin/update_status_bar.dart';
import '../../widgets/admin/home_admin/admin_drawer.dart';
import '../../widgets/admin/materiais_admin/filter_bar.dart';
import 'animated_network_background.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

// =============== MODELOS ===============

class Pessoas {
  final int id;
  final String nome;
  final String email;
  final String funcao;
  final bool ativo;

  Pessoas({
    required this.id,
    required this.nome,
    required this.email,
    required this.funcao,
    required this.ativo,
  });

  factory Pessoas.fromJson(Map<String, dynamic> json) {
    return Pessoas(
      id: json['id_usuario'] ?? 0,
      nome: json['nome'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      funcao: json['funcao'] ?? 'tecnico',
      ativo: json['ativo'] ?? true,
    );
  }
}

class PessoasPage extends StatefulWidget {
  const PessoasPage({super.key});

  @override
  State<PessoasPage> createState() => PessoasPageState();
}

class PessoasPageState extends State<PessoasPage> {
  late DateTime _lastUpdated;
  String _selectedPerfil = 'Todos os Perfis';
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  bool _isLoading = true;
  String? _errorMessage;
  List<Pessoas> _pessoas = [];

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    _fetchPessoas();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ---------- Chamada API ----------
  Future<void> _fetchPessoas() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    const String baseUrl = "http://localhost:8080";

    final queryParams = <String, String>{
      "limit": "20",
      "page": "1",
    };

    final searchQuery = _searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      queryParams['q'] = searchQuery;
    }

    if (_selectedPerfil != "Todos os Perfis") {
      // Mapeia o nome visual para o valor da API
      if (_selectedPerfil == 'Administrador') {
        queryParams["funcao"] = "admin";
      } else if (_selectedPerfil == 'Técnico' || _selectedPerfil == 'Tecnico') {
        queryParams["funcao"] = "tecnico";
      } else {
        queryParams["funcao"] = _selectedPerfil; // Fallback
      }
    }

    final uri = Uri.parse("$baseUrl/usuarios").replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: {"Accept": "application/json"});

      if (response.statusCode == 200) {
        final decodedBody = json.decode(utf8.decode(response.bodyBytes));
        final List<dynamic> data = decodedBody["data"];
        _pessoas = data.map((json) => Pessoas.fromJson(json)).toList();
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception("Falha ao carregar pessoas: ${response.statusCode} - ${errorBody["error"]}");
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

  // ---------- API: ADICIONAR NOVA PESSOA (POST) ----------
  Future<bool> _addNewUser(Map<String, dynamic> data) async {
    return _sendRequest('POST', data);
  }

  // ---------- API: EDITAR (PATCH) ----------
  Future<bool> _editUser(int id, Map<String, dynamic> data) async {
    data['id_usuario'] = id;
    return _sendRequest('PATCH', data);
  }

  // ---------- API: REMOVER (DELETE/SOFT) ----------
  Future<void>  _removeUser(Pessoas pessoa) async {
    final confirm = await _showDeleteConfirmDialog(pessoa);
    if (confirm != true) return;

    // Reutiliza a lógica de envio com método DELETE
    final success = await _sendRequest('DELETE', {'id_usuario': pessoa.id});
    if (success) {
      _showSnackBar("Usuário desativado com sucesso!", isError: false);
      _fetchPessoas();
    }
  }

  Future<bool> _sendRequest(String method, Map<String, dynamic> data) async {
    const baseUrl = "http://localhost:8080";
    final uri = Uri.parse("$baseUrl/usuarios");
    final token = context.read<AuthStore>().token;

    try {
      final request = http.Request(method, uri);
      request.headers.addAll({
        "Content-Type": "application/json", 
        "Authorization": "Bearer $token"
      });
      request.body = json.encode(data);

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return true;
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha na operação");
      }
    } catch (e) {
      _showSnackBar("Erro: $e", isError: true);
      return false;
    }
  }

  void _showUserDialog({Pessoas? pessoa}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AddOrEditUserDialog(
          userToEdit: pessoa,
          onSave: (data) async {
            bool success;
            if (pessoa == null) {
              success = await _addNewUser(data);
              if (success) _showSnackBar("Usuário criado!", isError: false);
            } else {
              success = await _editUser(pessoa.id, data);
              if (success) _showSnackBar("Usuário atualizado!", isError: false);
            }
            
            if (success) {
               if (mounted) Navigator.of(context).pop();
               _fetchPessoas();
            }
          },
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirmDialog(Pessoas pessoa) {
    const Color primaryColor = Color(0xFF080023);
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: primaryColor,
        title: const Text('Confirmar Desativação', style: TextStyle(color: Colors.white)),
        content: Text("Deseja desativar o acesso de '${pessoa.nome}'?", style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text('Desativar')),
        ],
      ),
    );
  }

  void _onSearchChanged(String query) {
    _fetchPessoas();
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
            pw.Center(
              child: pw.Text(
                'Relatório de Pessoas',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Nome', 'Email', 'Perfil'],
              data: _pessoas.map((p) {
                // Capitaliza a função para ficar bonito no PDF (ex: tecnico -> Técnico)
                final funcao = p.funcao.isNotEmpty 
                    ? '${p.funcao[0].toUpperCase()}${p.funcao.substring(1)}' 
                    : 'N/A';
                
                return [
                  p.nome,
                  p.email,
                  funcao,
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              border: pw.TableBorder.all(width: 0.5, color: PdfColors.grey),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.center,
              },
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'pessoas.pdf');
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
          'Pessoas',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [Padding(padding: const EdgeInsets.only(right: 20.0), child: Image.asset('assets/images/logo_metroSP.png', height: 50))],
      ),
      drawer: const AdminDrawer(primaryColor: Color(0xFF080023), secondaryColor: Color.fromARGB(255, 0, 14, 92)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UpdateStatusBar(isDesktop: isDesktop, lastUpdated: _lastUpdated, onUpdate: _fetchPessoas),
              const SizedBox(height: 24),
              const Text('Gestão de Pessoas', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Gerencie os técnicos e usuários do sistema.', style: TextStyle(color: Colors.white70, fontSize: 16)),
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
                    onPressed: _showUserDialog,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Adicionar Novo Usuário'),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // ===== Filtro =====
              FilterBar(
                searchController: _searchController,
                selectedCategory: _selectedPerfil,
                onCategoryChanged: (newValue) {
                  setState(() {
                    _selectedPerfil = newValue!;
                    _fetchPessoas();
                  });
                },
                onSearchChanged: (query) => _fetchPessoas(),
                categories: [
                  'Todos os Perfis',
                  'Técnico',
                  'Administrador',
                ],
                searchHint: 'Buscar por nome ou matrícula...',
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
      return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Color(0xFF3B82F6))));
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text('Erro ao carregar dados: $_errorMessage', style: const TextStyle(color: Colors.red, fontSize: 16), textAlign: TextAlign.center),
        ),
      );
    }

    if (_pessoas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('Nenhum usuário encontrado.', style: TextStyle(color: Colors.black54, fontSize: 16)),
        ),
      );
    }

    return Column(
      children: [
        _buildTableHeader(),
        const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
        ListView.separated(
          controller: _scrollController,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          itemCount: _pessoas.length,
          separatorBuilder: (context, index) => const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
          itemBuilder: (context, index) => _buildPessoaRow(_pessoas[index]),
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
          Expanded(flex: 3, child: Text('Nome', style: headerStyle)),
          Expanded(flex: 3, child: Text('Email', style: headerStyle)),
          Expanded(flex: 2, child: Text('Perfil', style: headerStyle)),
          Expanded(flex: 2, child: Text('Base', style: headerStyle)),
          SizedBox(width: 56, child: Center(child: Text('Ações', style: headerStyle))),
        ],
      ),
    );
  }

  Widget _buildPessoaRow(Pessoas item) {
    const cellStyle = TextStyle(color: Colors.black87);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(flex: 3, child: Text(item.nome, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
          Expanded(flex: 3, child: Text(item.email, style: cellStyle, overflow: TextOverflow.ellipsis)),
          Expanded(flex: 2, child: _buildPerfilChip(item.funcao)),
          Expanded(flex: 2, child: Text('BASE01', style: cellStyle)),
          SizedBox(
            width: 56,
            child: Center(
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                onSelected: (val) {
                  if (val == 'edit') _showUserDialog(pessoa: item);
                  if (val == 'remove') _removeUser(item);
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text("Editar")])),
                  const PopupMenuItem(value: 'remove', child: Row(children: [Icon(Icons.block, color: Colors.red), SizedBox(width: 8), Text("Desativar")])),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPerfilChip(String funcao) {
    Color backgroundColor;
    Color textColor;
    String funcaoNormalizada = funcao.toLowerCase();

    if (funcaoNormalizada == 'administrador' || funcaoNormalizada == 'admin') {
      backgroundColor = const Color(0xFFF3E8FF);
      textColor = const Color(0xFF9333EA);
    } else if (funcaoNormalizada == 'técnico' || funcaoNormalizada == 'tecnico') {
      backgroundColor = const Color(0xFFE0E7FF);
      textColor = const Color(0xFF4F46E5);
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade800;
    }

    final displayFuncao = funcao.isNotEmpty ? '${funcao[0].toUpperCase()}${funcao.substring(1)}' : 'N/A';

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(12)),
        child: Text(displayFuncao, style: TextStyle(color: textColor, fontWeight: FontWeight.w500, fontSize: 13)),
      ),
    );
  }
}

// ===== DIALOG =====
class _AddOrEditUserDialog extends StatefulWidget {
  final Pessoas? userToEdit;
  final Future<void> Function(Map<String, dynamic>) onSave;

  const _AddOrEditUserDialog({this.userToEdit, required this.onSave});

  @override
  State<_AddOrEditUserDialog> createState() => _AddOrEditUserDialogState();
}

class _AddOrEditUserDialogState extends State<_AddOrEditUserDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nomeController = TextEditingController();
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();

  // Mapeamento Visual -> API
  final Map<String, String> _funcoesMap = {'Técnico': 'tecnico', 'Administrador': 'admin'};
  late String _selectedFuncaoDisplay;
  bool _ativo = true;
  bool _isSaving = false;

  bool get isEditing => widget.userToEdit != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final u = widget.userToEdit!;
      _nomeController.text = u.nome;
      _emailController.text = u.email;
      _ativo = u.ativo;
      
      // Tenta encontrar a chave correta para o valor da API
      _selectedFuncaoDisplay = _funcoesMap.keys.firstWhere(
          (k) => _funcoesMap[k] == u.funcao, 
          orElse: () => 'Técnico'
      );
    } else {
      _selectedFuncaoDisplay = 'Técnico';
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    final data = {
      'nome': _nomeController.text.trim(),
      'email': _emailController.text.trim(),
      'funcao': _funcoesMap[_selectedFuncaoDisplay],
      'ativo': _ativo,
    };

    // Senha é opcional na edição
    if (!isEditing || _senhaController.text.isNotEmpty) {
       data['senha'] = _senhaController.text.trim();
    }

    await widget.onSave(data);
    if (mounted) setState(() => _isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF080023);
    const inputFill = Color.fromARGB(255, 30, 24, 53);

    return AlertDialog(
      backgroundColor: primaryColor,
      title: Text(isEditing ? 'Editar Usuário' : 'Novo Usuário', style: const TextStyle(color: Colors.white)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller: _nomeController, label: 'Nome', icon: Icons.person),
              const SizedBox(height: 16),
              _buildTextField(controller: _emailController, label: 'Email', icon: Icons.email),
              const SizedBox(height: 16),
              
              // Senha (Opcional na edição)
              TextFormField(
                controller: _senhaController,
                obscureText: true,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: isEditing ? 'Nova Senha (Opcional)' : 'Senha', 
                  icon: Icons.lock
                ),
                validator: (val) {
                  if (!isEditing && (val == null || val.isEmpty)) return 'Senha obrigatória';
                  if (val != null && val.isNotEmpty && val.length < 6) return 'Mínimo 6 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dropdown Função
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: inputFill, borderRadius: BorderRadius.circular(12)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFuncaoDisplay,
                    dropdownColor: primaryColor,
                    style: const TextStyle(color: Colors.white),
                    icon: const Icon(Icons.arrow_drop_down, color: Colors.white60),
                    items: _funcoesMap.keys.map((k) => DropdownMenuItem(value: k, child: Text(k))).toList(),
                    onChanged: (v) => setState(() => _selectedFuncaoDisplay = v!),
                  ),
                ),
              ),

              // Switch Ativo (Só na edição)
              if (isEditing) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Usuário Ativo?", style: TextStyle(color: Colors.white)),
                    Switch(
                      value: _ativo, 
                      onChanged: (v) => setState(() => _ativo = v), 
                      activeColor: Colors.blue
                    ),
                  ],
                ),
              ]
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancelar", style: TextStyle(color: Colors.white70))),
        ElevatedButton(onPressed: _isSaving ? null : _submit, child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Salvar")),
      ],
    );
  }

  InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
     // ... (Copie seu estilo padrão) ...
     return InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white60),
        prefixIcon: Icon(icon, color: Colors.white60),
        filled: true, fillColor: const Color.fromARGB(255, 30, 24, 53),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
     );
  }
  
  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      decoration: _buildInputDecoration(label: label, icon: icon),
      validator: (v) => (v == null || v.isEmpty) ? 'Obrigatório' : null,
    );
  }
}
