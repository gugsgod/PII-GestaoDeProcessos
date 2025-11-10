import 'package:flutter/material.dart';
import 'package:src/widgets/admin/home_admin/update_status_bar.dart';
import '../widgets/admin/materiais_admin/filter_bar.dart';
import '../widgets/admin/home_admin/admin_drawer.dart';
import 'animated_network_background.dart';
import 'package:intl/intl.dart';
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
      funcao: json['funcao'] ?? 'N/A'
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
  String _selectedCategory = 'Todas as Categorias';
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

    // Integração
    const String baseUrl = "http://localhost:8080";

    final queryParams = <String, String> {
      "limit": "20",
      "page": "1",
    };

    final searchQuery = _searchController.text.trim();
    if (searchQuery.isNotEmpty) {
      queryParams['q'] = searchQuery;
    }

    if (_selectedCategory != "Todas as Categorias") {
      queryParams["categoria"] = _selectedCategory;
    }

    final uri = Uri.parse("$baseUrl/usuarios").replace(queryParameters: queryParams);

    try {
      final response = await http.get(uri, headers: {
        "Accept": "application/json"
      });

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
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: json.encode({
          "nome": nome,
          "email": email,
          "senha": senha,
          "funcao": funcao,
        }),
      );

      if (response.statusCode == 201) {
        // Sucesso
        _showSnackBar("Usuário '$nome' cadastrado com sucesso!", isError: false);
        _fetchPessoas(); // Atualiza a lista
        return true;
      } else {
        // Erro do servidor (ex: email duplicado, validação)
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha ao cadastrar usuário");
      }
    } catch (e) {
      // Erro de conexão ou outro
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
                onUpdate: _fetchPessoas,
              ),
              const SizedBox(height: 24),

              const Text(
                'Gestão de Pessoas',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Gerencie os técnicos e usuários do sistema.',
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
                    onPressed: _showAddUserDialog,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text('Adicionar Novo Usuário'),
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
                    _fetchPessoas();
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

  // Mostra o popup de adicionar usuário
  void _showAddUserDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AddUserDialog(
          // Passa a função de salvar para o dialog
          onSave: (nome, email, senha, funcao) async {
            return await _addNewUser(nome, email, senha, funcao);
          },
        );
      },
    );
  }

  // Mostra uma notificação
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

  // Construa aqui!
  Widget _buildDataTable() {
    // 1. Lidar com estado de carregamento
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(color: Color(0xFF3B82F6)),
        ),
      );
    }

    // 2. Lidar com estado de erro
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Text(
            'Erro ao carregar dados: $_errorMessage',
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // 3. Lidar com estado vazio
    if (_pessoas.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(
            'Nenhum usuário encontrado.',
            style: TextStyle(color: Colors.black54, fontSize: 16),
          ),
        ),
      );
    }

    // 4. Construir a tabela se houver dados
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
          separatorBuilder: (context, index) => const Divider(
            color: Color.fromARGB(59, 102, 102, 102),
            height: 1,
          ),
          itemBuilder: (context, index) =>
              _buildPessoaRow(_pessoas[index]),
        ),
      ],
    );
  }

  // NOVO WIDGET: Constrói o cabeçalho da tabela (copiado de 'instrumentos')
  Widget _buildTableHeader() {
    const headerStyle = TextStyle(
      fontWeight: FontWeight.bold,
      color: Colors.black54,
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      child: const Row(
        children: [
          // Flex
          Expanded(flex: 3, child: Text('Nome', style: headerStyle)),
          Expanded(flex: 3, child: Text('Email', style: headerStyle)),
          Expanded(flex: 2, child: Text('Perfil', style: headerStyle)),
          Expanded(flex: 2, child: Text('Base', style: headerStyle)),
          // Largura fixa para ações
          SizedBox(
            width: 56,
            child: Center(child: Text('Ações', style: headerStyle)),
          ),
        ],
      ),
    );
  }

  // NOVO WIDGET: Constrói uma linha da tabela (copiado de 'instrumentos')
  Widget _buildPessoaRow(Pessoas item) {
    const cellStyle = TextStyle(color: Colors.black87);
    return Container(
      // Padding da célula
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          // Nome (flex 3)
          Expanded(
            flex: 3,
            child: Text(
              item.nome,
              // Estilo de destaque para a primeira coluna, igual 'instrumentos'
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Email (flex 3)
          Expanded(
            flex: 3,
            child: Text(
              item.email,
              style: cellStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Perfil (flex 2)
          Expanded(
            flex: 2,
            child: _buildPerfilChip(item.funcao)
          ),
          // Base (flex 2)
          Expanded(
            flex: 2,
            child: Text('BASE01', style: cellStyle) // Valor fixo
          ),
          // Ações (largura fixa)
          SizedBox(
            width: 56,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.more_horiz, color: Colors.black54),
                onPressed: () {
                  // TODO: Implementar lógica de ações
                },
              ),
            ),
          ),
        ],
      ),
    );
  }


  // Constrói o chip de "Perfil" (Administrador, Técnico)
  Widget _buildPerfilChip(String funcao) {
    Color backgroundColor;
    Color textColor;

    // Normaliza a string para comparação
    String funcaoNormalizada = funcao.toLowerCase();

    if (funcaoNormalizada == 'administrador' || funcaoNormalizada == 'admin') {
      backgroundColor = const Color(0xFFF3E8FF); // Roxo/rosa claro
      textColor = const Color(0xFF9333EA);     // Roxo escuro
    } else if (funcaoNormalizada == 'técnico' || funcaoNormalizada == 'tecnico') {
      backgroundColor = const Color(0xFFE0E7FF); // Azul claro
      textColor = const Color(0xFF4F46E5);     // Azul escuro
    } else {
      // Um fallback para outras funções
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade800;
    }

    // Capitaliza a primeira letra para exibição
    final String
    displayFuncao = funcao.isNotEmpty
      ? '${funcao[0].toUpperCase()}${funcao.substring(1)}'
      : 'N/A';

    // FIX: Adicionado Align para impedir que o chip estique
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          displayFuncao,
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}


class _AddUserDialog extends StatefulWidget {
  // Callback que chama a função de salvar da classe pai
  // Agora envia o valor da API (ex: "técnico")
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
  
  // FIX: Mapeia o valor de display (chave) para o valor da API (valor)
  final Map<String, String> _funcoesMap = {
    'Técnico': 'técnico',
    'Administrador': 'administrador',
  };
  
  // Armazena o valor de display (o que o usuário vê)
  late String _selectedFuncaoDisplay;
  
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Inicia com o primeiro valor do mapa
    _selectedFuncaoDisplay = _funcoesMap.keys.first;
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _emailController.dispose();
    _senhaController.dispose();
    super.dispose();
  }

  // Tenta salvar o usuário
  Future<void> _saveUser() async {
    // Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() { _isSaving = true; });

    // Pega o valor da API correspondente ao display
    final String funcaoApiValue = _funcoesMap[_selectedFuncaoDisplay]!;

    // Chama a função de salvar (que é o _addNewUser da PessoasPageState)
    final bool success = await widget.onSave(
      _nomeController.text.trim(),
      _emailController.text.trim(),
      _senhaController.text.trim(),
      funcaoApiValue, // Envia o valor correto (ex: "técnico")
    );

    if (success && mounted) {
      // Se salvou com sucesso, fecha o dialog
      Navigator.of(context).pop();
    } else {
      // Se falhou, apenas para de carregar (o snackbar de erro já foi mostrado)
      setState(() { _isSaving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color inputFillColor = Color.fromARGB(255, 30, 24, 53); // Um pouco mais claro que o fundo
    const Color borderColor = Colors.white30;
    const Color hintColor = Colors.white60;

    return AlertDialog(
      backgroundColor: primaryColor,
      title: const Text(
        'Adicionar Novo Usuário',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo NOME
              TextFormField(
                controller: _nomeController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(label: 'Nome', icon: Icons.person),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O nome é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo EMAIL
              TextFormField(
                controller: _emailController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.emailAddress,
                decoration: _buildInputDecoration(label: 'Email', icon: Icons.email),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O email é obrigatório';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Insira um email válido';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo SENHA
              TextFormField(
                controller: _senhaController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: _buildInputDecoration(label: 'Senha', icon: Icons.lock),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'A senha é obrigatória';
                  }
                  if (value.length < 8) {
                    return 'A senha deve ter no mínimo 8 caracteres';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Dropdown FUNÇÃO/PERFIL
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: inputFillColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedFuncaoDisplay, // Usa o valor de display
                    isExpanded: true,
                    dropdownColor: primaryColor, // Fundo do menu
                    icon: const Icon(Icons.arrow_drop_down, color: hintColor),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                    onChanged: (String? newValue) {
                      if (newValue != null) {
                        setState(() { _selectedFuncaoDisplay = newValue; });
                      }
                    },
                    // Mapeia as CHAVES (display) do mapa para os itens
                    items: _funcoesMap.keys.map<DropdownMenuItem<String>>((String displayValue) {
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
      ),
      actions: [
        // Botão CANCELAR
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
        ),
        // Botão SALVAR
        ElevatedButton(
          onPressed: _isSaving ? null : _saveUser, // Desativa se estiver salvando
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

  // Helper para estilizar os campos de texto do formulário
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
      // Borda padrão
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      // Borda habilitada
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: borderColor),
      ),
      // Borda em foco (quando o usuário clica)
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2), // Borda azul de destaque
      ),
    );
  }
}