import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';
import 'package:src/services/instrumentos_api.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/admin/home_admin/admin_drawer.dart';
import '../../widgets/admin/home_admin/update_status_bar.dart';
import '../../widgets/admin/materiais_admin/table_actions_menu.dart';
import 'animated_network_background.dart';
import 'dart:async';
import 'dart:convert';

// Enum para o status do instrumento
enum InstrumentStatus { ativo, inativo }

// Modelo de dados
class Instrument {
  final String id;
  final String patrimonio;
  final String descricao;
  final String categoria;
  final InstrumentStatus status;
  final String localAtual;
  final String responsavelAtual;
  final DateTime proximaCalibracaoEm;
  final bool ativo;
  final DateTime createdAt;
  final DateTime updatedAt;

  Instrument({
    required this.id,
    required this.patrimonio,
    this.descricao = 'N/A',
    this.categoria = 'N/A',
    required this.status,
    this.localAtual = 'N/A',
    this.responsavelAtual = 'N/A',
    DateTime? proximaCalibracaoEm,
    this.ativo = true,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) : proximaCalibracaoEm = proximaCalibracaoEm ?? DateTime.now(),
       createdAt = createdAt ?? DateTime.now(),
       updatedAt = updatedAt ?? DateTime.now();

  factory Instrument.fromJson(Map<String, dynamic> map) {
    DateTime _parseDate(dynamic dateString, {required DateTime fallback}) {
      if (dateString is String) {
        return DateTime.tryParse(dateString) ?? fallback;
      }
      return fallback;
    }

    final String statusString = map['status']?.toString() ?? 'inativo';

    // Mapeia os status do backend para o enum do frontend
    final InstrumentStatus statusEnum;
    if (statusString == 'ativo' || statusString == 'disponivel') {
      statusEnum = InstrumentStatus.ativo;
    } else {
      statusEnum = InstrumentStatus.inativo;
    }

    return Instrument(
      id: map['id']?.toString() ?? 'N/A',
      patrimonio: map['patrimonio']?.toString() ?? 'N/A',
      descricao: map['descricao']?.toString() ?? 'N/A',
      categoria: map['categoria']?.toString() ?? 'N/A',
      status: statusEnum, // <-- USA A VARIÁVEL CORRIGIDA
      localAtual: map['local_atual_id']?.toString() ?? 'N/A',
      responsavelAtual: map['responsavel_atual_id']?.toString() ?? 'N/A',
      proximaCalibracaoEm: _parseDate(
        map['proxima_calibracao_em'],
        fallback: DateTime.now(),
      ),
      ativo: map['ativo'] as bool? ?? false,
      createdAt: _parseDate(map['created_at'], fallback: DateTime.now()),
      updatedAt: _parseDate(map['updated_at'], fallback: DateTime.now()),
    );
  }
}

class InstrumentosAdminPage extends StatefulWidget {
  const InstrumentosAdminPage({super.key});

  @override
  State<InstrumentosAdminPage> createState() => _InstrumentosAdminPageState();
}

class _InstrumentosAdminPageState extends State<InstrumentosAdminPage> {
  late DateTime _lastUpdated;
  final ScrollController _scrollController = ScrollController();

  bool _isLoading = true;
  String? _errorMessage;
  List<Instrument> _instruments = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // 1. Mostra o loading e limpa erros antigos
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 2. FORÇA o Flutter a redesenhar a tela AGORA
    // Isso garante que o spinner apareça antes da chamada da API
    await Future.delayed(Duration.zero);

    // 3. Pega o token
    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (token == null || !auth.isAuthenticated) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Token de acesso ausente ou inválido.';
      });
      return;
    }

    // 4. AGORA tenta a API (depois que o loading já está na tela)
    try {
      final data = await fetchInstrumentos(
        token,
      ); // (A api já tem timeout e no-cache)
      if (!mounted) return;
      setState(() {
        _instruments = data.map((e) => Instrument.fromJson(e)).toList();
        _isLoading = false;
        _lastUpdated = DateTime.now(); // Atualiza a hora
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll(
          "Exception: ",
          "",
        ); // Mostra o erro da API
      });
    }
  }

  Future<bool> _addNewInstrument({
    required String patrimonio,
    required String descricao,
    String? categoria,
    int? localId,
    String? proximaCalibracao,
  }) async {
    final auth = context.read<AuthStore>();
    final token = auth.token;
    if (token == null) {
      _showSnackBar("Erro: Usuário não autenticado.", isError: true);
      return false;
    }

    // Assume que a API está rodando localmente
    const String baseUrl = "http://localhost:8080";
    // O backend `index.dart` está na rota /instrumentos (assumindo)
    final uri = Uri.parse("$baseUrl/instrumentos");

    try {
      final response = await http.post(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token", // Envia o token
        },
        body: json.encode({
          "patrimonio": patrimonio,
          "descricao": descricao,
          "categoria": categoria,
          "local_atual_id": localId,
          "proxima_calibracao_em": proximaCalibracao,
        }),
      );

      // 201 = Criado com sucesso
      if (response.statusCode == 201) {
        _showSnackBar(
          "Instrumento '$patrimonio' cadastrado com sucesso!",
          isError: false,
        );
        _load(); // Atualiza a lista
        return true;
      } else {
        // Erro do servidor (ex: patrimônio duplicado, validação)
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        // O backend retorna 'Erro: Patrimônio "X" já cadastrado.'
        throw Exception(errorBody["error"] ?? errorBody.toString());
      }
    } catch (e) {
      // Erro de conexão ou outro
      _showSnackBar(
        "Erro: ${e.toString().replaceAll("Exception: ", "")}",
        isError: true,
      );
      return false;
    }
  }

  void _showAddInstrumentDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // Passa a função de salvar para o dialog
        return _AddInstrumentDialog(
          onSave:
              (
                String patrimonio,
                String descricao,
                String? categoria,
                int? localId,
                String? proximaCalibracao,
              ) async {
                // Chama a nova função de API
                return await _addNewInstrument(
                  patrimonio: patrimonio,
                  descricao: descricao,
                  categoria: categoria,
                  localId: localId,
                  proximaCalibracao: proximaCalibracao,
                );
              },
        );
      },
    );
  }

  List<Instrument> get _filteredInstruments {
    if (_searchQuery.isEmpty) return _instruments;
    return _instruments
        .where(
          (i) =>
              i.patrimonio.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              i.id.toLowerCase().contains(_searchQuery.toLowerCase()),
        )
        .toList();
  }

  /// Placeholder para a lógica de edição
  void _editInstrumento(Instrument instrumento) {
    // TODO: Implementar lógica de edição
    // 1. Abrir um Dialog (talvez reutilizar o _AddUserDialog em modo de edição)
    // 2. Passar os dados da 'pessoa' para o dialog
    // 3. Chamar a API de UPDATE (PUT /usuarios/{id})
    _showSnackBar(
      "Ação 'Editar' para ${instrumento.descricao}",
      isError: false,
    );
  }

  /// Placeholder para a lógica de remoção
  void _removeInstrumento(Instrument instrumento) async {
    // Mostra o dialog de confirmação
    final bool? confirmed = await _showDeleteConfirmDialog(instrumento);

    // Se o usuário confirmou (true) e o widget ainda está "montado" (na tela)
    if (confirmed == true && mounted) {
      // Chama a função que executa a exclusão
      await _performDelete(instrumento);
    }
  }

  /// 2. Executa a chamada de API DELETE
  Future<void> _performDelete(Instrument instrumento) async {
    // Pega o token de autenticação
    final auth = context.read<AuthStore>();
    final token = auth.token;
    if (token == null) {
      _showSnackBar("Erro: Usuário não autenticado.", isError: true);
      return;
    }

    // O backend espera um 'id' (int), mas o modelo 'Instrument' tem 'id' (String).
    // Precisamos converter.
    final String? patrimonio = instrumento.patrimonio;
    if (patrimonio == null) {
      _showSnackBar("Erro: ID inválido para exclusão.", isError: true);
      return;
    }

    // Prepara a chamada de API
    const String baseUrl = "http://localhost:8080";
    final uri = Uri.parse("$baseUrl/instrumentos"); // Rota do backend

    try {
      final response = await http.delete(
        uri,
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token",
        },
        // O backend (index.dart) espera o ID no corpo da requisição
        body: json.encode({'patrimonio': patrimonio}),
      );

      // 204 (No Content) é a resposta padrão de sucesso para DELETE
      if (response.statusCode == 204 || response.statusCode == 200) {
        _showSnackBar(
          "Instrumento '${instrumento.descricao}' removido com sucesso!",
          isError: false,
        );
        _load(); // Atualiza a lista de instrumentos
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

  Future<bool?> _showDeleteConfirmDialog(Instrument instrumento) {
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
            "Tem certeza que deseja remover o instrumento:\n\n'${instrumento.descricao}' (Patrimônio: ${instrumento.patrimonio})?\n\nEsta ação não pode ser desfeita.",
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
          'Instrumentos',
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
      drawer: AdminDrawer(
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
                onUpdate: _load,
              ),
              const SizedBox(height: 48),
              const Text(
                "Gestão de Instrumentos",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "Controle retiradas, devoluções e calibrações dos instrumentos",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),

              // Botão "Adicionar Novo Instrumento"
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton.icon(
                    onPressed: _showAddInstrumentDialog,
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Adicionar Novo Instrumento"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3B82F6),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Barra de pesquisa
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar instrumento...',
                  filled: true,
                  fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onChanged: (value) {
                  setState(() => _searchQuery = value);
                },
              ),

              const SizedBox(height: 24),

              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.white,
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
    final filtered = _filteredInstruments;

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
                onPressed: _load,
                child: const Text("Tentar Novamente"),
              ),
            ],
          ),
        ),
      );
    }

    if (filtered.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(32.0),
        child: Center(child: Text('Nenhum instrumento encontrado.')),
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
          itemCount: filtered.length,
          separatorBuilder: (_, __) => const Divider(
            color: Color.fromARGB(59, 102, 102, 102),
            height: 1,
          ),
          itemBuilder: (_, i) => _buildInstrumentRow(filtered[i]),
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
          Expanded(flex: 2, child: Text('Patrimônio', style: headerStyle)),
          Expanded(flex: 2, child: Text('Nome', style: headerStyle)),
          Expanded(flex: 2, child: Text('Status', style: headerStyle)),
          Expanded(flex: 2, child: Text('Base Atual', style: headerStyle)),
          Expanded(
            flex: 2,
            child: Text('Venc. Calibração', style: headerStyle),
          ),
          SizedBox(
            width: 56,
            child: Center(child: Text('Ações', style: headerStyle)),
          ),
        ],
      ),
    );
  }

  Widget _buildInstrumentRow(Instrument item) {
    const cellStyle = TextStyle(color: Colors.black87);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.patrimonio, style: cellStyle)),
          Expanded(
            flex: 2,
            child: Text(
              item.descricao,
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(flex: 2, child: _StatusChip(status: item.status)),
          Expanded(flex: 2, child: Text(item.localAtual)),
          Expanded(
            flex: 2,
            child: Text(
              // formata DateTime para string legível
              DateFormat('dd/MM/yyyy').format(item.proximaCalibracaoEm),
            ),
          ),
          SizedBox(
            width: 56,
            child: Center(
              child: TableActionsMenu(
                onEditPressed: () {
                  _editInstrumento(item);
                },
                onRemovePressed: () {
                  _removeInstrumento(item);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final InstrumentStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isAtivo = status == InstrumentStatus.ativo;
    final backgroundColor = isAtivo
        ? Colors.green.shade100
        : Colors.red.shade100;
    final textColor = isAtivo ? Colors.green.shade800 : Colors.red.shade800;
    final text = isAtivo ? 'Ativo' : 'Inativo';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: textColor,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class _AddInstrumentDialog extends StatefulWidget {
  // Callback que chama a função de salvar da classe pai
  final Future<bool> Function(
    String patrimonio,
    String descricao,
    String? categoria,
    int? localId,
    String? proximaCalibracao,
  )
  onSave;

  const _AddInstrumentDialog({required this.onSave});

  @override
  State<_AddInstrumentDialog> createState() => _AddInstrumentDialogState();
}

class _AddInstrumentDialogState extends State<_AddInstrumentDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _patrimonioController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _categoriaController = TextEditingController();
  final TextEditingController _localIdController = TextEditingController();
  final TextEditingController _calibracaoController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _patrimonioController.dispose();
    _descricaoController.dispose();
    _categoriaController.dispose();
    _localIdController.dispose();
    _calibracaoController.dispose();
    super.dispose();
  }

  // Tenta salvar o instrumento
  Future<void> _saveInstrument() async {
    // Valida o formulário
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    // Converte os valores
    final String patrimonio = _patrimonioController.text.trim();
    final String descricao = _descricaoController.text.trim();
    final String? categoria = _categoriaController.text.trim().isEmpty
        ? null
        : _categoriaController.text.trim();
    final int? localId = int.tryParse(_localIdController.text.trim());
    final String? calibracao = _calibracaoController.text.trim().isEmpty
        ? null
        : _calibracaoController.text.trim();

    // Chama a função de salvar (que é o _addNewInstrument da InstrumentosAdminPage)
    final bool success = await widget.onSave(
      patrimonio,
      descricao,
      categoria,
      localId,
      calibracao,
    );

    if (success && mounted) {
      // Se salvou com sucesso, fecha o dialog
      Navigator.of(context).pop();
    } else {
      // Se falhou, apenas para de carregar (o snackbar de erro já foi mostrado)
      setState(() {
        _isSaving = false;
      });
    }
  }

  // Mostra o seletor de data
  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );

    if (picked != null) {
      // Formata a data como YYYY-MM-DD (ISO String)
      String formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      setState(() {
        _calibracaoController.text = formattedDate;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color inputFillColor = Color.fromARGB(
      255,
      30,
      24,
      53,
    ); // Um pouco mais claro que o fundo
    const Color borderColor = Colors.white30;
    const Color hintColor = Colors.white60;

    return AlertDialog(
      backgroundColor: primaryColor,
      title: const Text(
        'Adicionar Novo Instrumento',
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Campo PATRIMÔNIO (Obrigatório)
              TextFormField(
                controller: _patrimonioController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'Patrimônio *',
                  icon: Icons.qr_code,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'O patrimônio é obrigatório';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo DESCRIÇÃO (Obrigatório)
              TextFormField(
                controller: _descricaoController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'Descrição *',
                  icon: Icons.edit,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'A descrição é obrigatória';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo CATEGORIA
              TextFormField(
                controller: _categoriaController,
                style: const TextStyle(color: Colors.white),
                decoration: _buildInputDecoration(
                  label: 'Categoria',
                  icon: Icons.category,
                ),
              ),
              const SizedBox(height: 16),

              // Campo LOCAL ID
              TextFormField(
                controller: _localIdController,
                style: const TextStyle(color: Colors.white),
                keyboardType: TextInputType.number,
                decoration: _buildInputDecoration(
                  label: 'ID do Local',
                  icon: Icons.location_on,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty)
                    return null; // Campo opcional
                  if (int.tryParse(value.trim()) == null) {
                    return 'O ID deve ser um número';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Campo PRÓXIMA CALIBRAÇÃO
              TextFormField(
                controller: _calibracaoController,
                style: const TextStyle(color: Colors.white),
                decoration:
                    _buildInputDecoration(
                      label: 'Próxima Calibração (yyyy-mm-dd)',
                      icon: Icons.calendar_today,
                    ).copyWith(
                      // Adiciona um botão de calendário no final
                      suffixIcon: IconButton(
                        icon: const Icon(
                          Icons.calendar_month_outlined,
                          color: hintColor,
                        ),
                        onPressed: _selectDate,
                      ),
                    ),
                readOnly: true, // Impede digitação manual
                onTap: _selectDate, // Abre o seletor ao tocar
              ),
            ],
          ),
        ),
      ),
      actions: [
        // Botão CANCELAR
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Cancelar',
            style: TextStyle(color: Colors.white70),
          ),
        ),
        // Botão SALVAR
        ElevatedButton(
          onPressed: _isSaving
              ? null
              : _saveInstrument, // Desativa se estiver salvando
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3B82F6),
            foregroundColor: Colors.white,
          ),
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Salvar'),
        ),
      ],
    );
  }

  // Helper para estilizar os campos de texto do formulário
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
        borderSide: const BorderSide(
          color: Color(0xFF3B82F6),
          width: 2,
        ), // Borda azul de destaque
      ),
    );
  }
}
