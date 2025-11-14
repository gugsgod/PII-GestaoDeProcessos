import 'package:flutter/material.dart';
import 'package:src/widgets/admin/home_admin/update_status_bar.dart';
import '../../widgets/admin/home_admin/admin_drawer.dart';
import '../../widgets/admin/materiais_admin/filter_bar.dart';
import 'animated_network_background.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

// =============== MODELOS ===============

class Pessoas {
  final int id;
  final String nome;
  final String email;
  final String funcao;
  final String? hash;

  Pessoas({
    required this.id,
    required this.nome,
    required this.email,
    required this.funcao,
    this.hash,
  });

  factory Pessoas.fromJson(Map<String, dynamic> json) {
    return Pessoas(
      id: json['id_usuario'] ?? 0,
      nome: json['nome'] ?? 'N/A',
      email: json['email'] ?? 'N/A',
      funcao: json['funcao'] ?? 'N/A',
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
      queryParams["funcao"] = _selectedPerfil;
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
  Future<bool> _addNewUser(String nome, String email, String senha, String funcao) async {
    const baseUrl = "http://localhost:8080";
    final uri = Uri.parse("$baseUrl/usuarios");

    try {
      final response = await http.post(
        uri,
        headers: {"Content-Type": "application/json", "Accept": "application/json"},
        body: json.encode({"nome": nome, "email": email, "senha": senha, "funcao": funcao}),
      );

      if (response.statusCode == 201) {
        _showSnackBar("Usuário '$nome' cadastrado com sucesso!", isError: false);
        _fetchPessoas();
        return true;
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha ao cadastrar usuário");
      }
    } catch (e) {
      _showSnackBar("Erro: ${e.toString().replaceAll("Exception: ", "")}", isError: true);
      return false;
    }
  }

  void _onSearchChanged(String query) {
    _fetchPessoas();
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
                    onPressed: () {},
                    icon: const Icon(Icons.upload_file, color: Colors.white70),
                    label: const Text('Exportar', style: TextStyle(color: Colors.white)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white30)),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _showAddUserDialog,
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
                  'Tecnico',
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

  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AddUserDialog(
          onSave: (nome, email, senha, funcao) async {
            return await _addNewUser(nome, email, senha, funcao);
          },
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
class _AddUserDialog extends StatefulWidget {
  final Future<bool> Function(String nome, String email, String senha, String funcaoApi) onSave;
  const _AddUserDialog({required this.onSave});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _senhaController = TextEditingController();

  final Map<String, String> _funcoesMap = {'Técnico': 'Tecnico', 'Administrador': 'admin'};
  late String _selectedFuncaoDisplay;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedFuncaoDisplay = _funcoesMap.keys.first;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final funcaoApiValue = _funcoesMap[_selectedFuncaoDisplay]!;

    final success = await widget.onSave(
      _nomeController.text.trim(),
      _emailController.text.trim(),
      _senhaController.text.trim(),
      funcaoApiValue,
    );

    if (success && mounted) {
      Navigator.of(context).pop();
    } else {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color inputFillColor = Color.fromARGB(255, 30, 24, 53);
    const Color borderColor = Colors.white30;
    const Color hintColor = Colors.white60;

    return AlertDialog(
      backgroundColor: primaryColor,
      title: const Text('Adicionar Novo Usuário', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nomeController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(label: 'Nome', icon: Icons.person),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'O nome é obrigatório' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(label: 'Email', icon: Icons.email),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'O email é obrigatório';
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) return 'Insira um email válido';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _senhaController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: _buildInputDecoration(label: 'Senha', icon: Icons.lock),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'A senha é obrigatória';
                  if (value.length < 8) return 'A senha deve ter no mínimo 8 caracteres';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(color: inputFillColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFuncaoDisplay,
                    isExpanded: true,
                    dropdownColor: primaryColor,
                    icon: const Icon(Icons.arrow_drop_down, color: hintColor),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    onChanged: (newValue) {
                      if (newValue != null) setState(() => _selectedFuncaoDisplay = newValue);
                    },
                    items: _funcoesMap.keys.map((displayValue) => DropdownMenuItem<String>(value: displayValue, child: Text(displayValue))).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar', style: TextStyle(color: Colors.white70))),
        ElevatedButton(
          onPressed: _isSaving ? null : _saveUser,
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
          child: _isSaving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('Salvar'),
        ),
      ],
    );
  }

  InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
    const Color inputFillColor = Color.fromARGB(255, 30, 24, 53);
    const Color borderColor = Colors.white30;
    const Color hintColor = Colors.white60;

    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white70),
      prefixIcon: Icon(icon, color: hintColor),
      filled: true,
      fillColor: inputFillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: borderColor)),
    );
  }
}
