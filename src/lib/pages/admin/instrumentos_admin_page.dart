import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../widgets/admin/home_admin/admin_drawer.dart';
import '../../widgets/admin/home_admin/update_status_bar.dart';
import 'animated_network_background.dart';
import 'dart:async';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'dart:convert';

// Enum para o status do instrumento
enum InstrumentStatus { ativo, inativo }

// Modelo para o Dropdown de Locais
class LocalFisico {
  final int id;
  final String nome;
  LocalFisico({required this.id, required this.nome});

  factory LocalFisico.fromJson(Map<String, dynamic> json) {
    return LocalFisico(
      id: json['id'] as int,
      nome: json['nome'] as String,
    );
  }
}

// Modelo de dados do Instrumento
class Instrument {
  final int id;
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

    final InstrumentStatus statusEnum;
    if (statusString == 'ativo' || statusString == 'disponivel') {
      statusEnum = InstrumentStatus.ativo;
    } else {
      statusEnum = InstrumentStatus.inativo;
    }

    return Instrument(
      id: map['id'] as int? ?? 0,
      patrimonio: map['patrimonio']?.toString() ?? 'N/A',
      descricao: map['descricao']?.toString() ?? 'N/A',
      categoria: map['categoria']?.toString() ?? 'N/A',
      status: statusEnum,
      localAtual: map['local_atual_nome']?.toString() ?? 'N/A',
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

  List<LocalFisico> _locais = [];
  bool _isLoadingLocais = true;

  @override
  void initState() {
    super.initState();
    _lastUpdated = DateTime.now();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _fetchLocais();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
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
            pw.Center(child: pw.Text('Relatório de Instrumentos', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              headers: ['Patrimônio', 'Nome', 'Categoria', 'Local', 'Status'],
              data: _filteredInstruments.map((i) => [
                i.patrimonio,
                i.descricao,
                i.categoria,
                i.localAtual,
                i.ativo ? 'Ativo' : 'Inativo',
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

    await Printing.sharePdf(bytes: await pdf.save(), filename: 'instrumentos.pdf');
  }
  
  Future<void> _fetchLocais() async {
    final token = Provider.of<AuthStore>(context, listen: false).token;
    if (token == null) return;

    try {
      final response = await http.get(
        Uri.parse('http://localhost:8080/locais'),
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

  Future<void> _load() async {
    setState(() { _isLoading = true; _errorMessage = null; });
    await Future.delayed(Duration.zero);
    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (token == null || !auth.isAuthenticated) {
      if (!mounted) return;
      setState(() { _isLoading = false; _errorMessage = 'Token de acesso ausente.'; });
      return;
    }

    try {
      // Chama o catálogo sem filtro de ativo para ver TUDO (admin)
      final uri = Uri.parse('http://localhost:8080/instrumentos/catalogo'); 
      final response = await http.get(uri, headers: {'Authorization': 'Bearer $token'});
      
      if (response.statusCode == 200) {
         final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
         setState(() {
            _instruments = data.map((e) => Instrument.fromJson(e)).toList();
            _isLoading = false;
            _lastUpdated = DateTime.now();
         });
      } else {
         throw Exception('Erro ${response.statusCode}');
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString().replaceAll("Exception: ", "");
      });
    }
  }

  // --- CRIAR (POST) ---
  Future<bool> _addNewInstrument(Map<String, dynamic> data) async {
    final auth = context.read<AuthStore>();
    final token = auth.token;
    if (token == null) return false;

    try {
      final response = await http.post(
        Uri.parse("http://localhost:8080/instrumentos"),
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(data),
      );

      if (response.statusCode == 201) {
        _showSnackBar("Instrumento cadastrado com sucesso!", isError: false);
        _load();
        return true;
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? errorBody.toString());
      }
    } catch (e) {
      _showSnackBar("Erro: ${e.toString().replaceAll("Exception: ", "")}", isError: true);
      return false;
    }
  }

  // --- EDITAR (PATCH) ---
  Future<void> _editInstrument(int id, Map<String, dynamic> data) async {
    final auth = context.read<AuthStore>();
    final token = auth.token;
    if (token == null) return;
    
    data['id'] = id; // Garante o ID no corpo

    try {
      final response = await http.patch(
        Uri.parse("http://localhost:8080/instrumentos"), 
        headers: {
          "Content-Type": "application/json",
          "Authorization": "Bearer $token",
        },
        body: json.encode(data),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Instrumento atualizado com sucesso!", isError: false);
        _load();
      } else {
        final errorBody = json.decode(utf8.decode(response.bodyBytes));
        throw Exception(errorBody["error"] ?? "Falha ao atualizar");
      }
    } catch (e) {
      _showSnackBar("Erro ao editar: ${e.toString().replaceAll("Exception: ", "")}", isError: true);
    }
  }

  // --- DIALOG UNIFICADO ---
  void _showInstrumentDialog({Instrument? instrument}) {
    // Se for criação (instrument == null), exige locais carregados
    if (instrument == null && (_isLoadingLocais || _locais.isEmpty)) {
      _showSnackBar(_isLoadingLocais ? 'Carregando locais...' : 'Nenhum local cadastrado!', isError: true);
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return _AddOrEditInstrumentDialog(
          locaisDisponiveis: _locais,
          instrumentParaEditar: instrument, 
          // AQUI ESTÁ A CORREÇÃO: Recebe 'data' (Map)
          onSave: (data) async {
            if (instrument == null) {
              return await _addNewInstrument(data);
            } else {
              await _editInstrument(instrument.id, data);
              return true;
            }
          },
        );
      },
    );
  }

  List<Instrument> get _filteredInstruments {
    if (_searchQuery.isEmpty) return _instruments;
    return _instruments
        .where((i) =>
              i.patrimonio.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              i.descricao.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
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
        title: const Text('Instrumentos', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [Padding(padding: const EdgeInsets.only(right: 20.0), child: Image.asset('assets/images/logo_metroSP.png', height: 50))],
      ),
      drawer: const AdminDrawer(primaryColor: primaryColor, secondaryColor: secondaryColor),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UpdateStatusBar(isDesktop: isDesktop, lastUpdated: _lastUpdated, onUpdate: _load),
              const SizedBox(height: 48),
              const Text("Gestão de Instrumentos", style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text("Controle retiradas, devoluções e calibrações dos instrumentos", style: TextStyle(color: Colors.white70, fontSize: 16)),
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
                    onPressed: () => _showInstrumentDialog(), 
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text("Adicionar Novo Instrumento"),
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), foregroundColor: Colors.white),
                  ), 
                ],
              ),
              const SizedBox(height: 24),
              TextField(
                decoration: InputDecoration(
                  hintText: 'Buscar instrumento...', filled: true, fillColor: Colors.white,
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: _buildDataTable(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDataTable() {
    final filtered = _filteredInstruments;
    if (_isLoading) return const SizedBox(height: 500, child: Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF080023)))));
    if (_errorMessage != null) return SizedBox(height: 500, child: Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.error_outline, color: Colors.red, size: 48), const SizedBox(height: 16), Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black87, fontSize: 16)), const SizedBox(height: 16), ElevatedButton(onPressed: _load, child: const Text("Tentar Novamente"))])));
    if (filtered.isEmpty) return const Padding(padding: EdgeInsets.all(32.0), child: Center(child: Text('Nenhum instrumento encontrado.')));

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
          separatorBuilder: (_, __) => const Divider(color: Color.fromARGB(59, 102, 102, 102), height: 1),
          itemBuilder: (_, i) => _buildInstrumentRow(filtered[i]),
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
          Expanded(flex: 2, child: Text('Patrimônio', style: headerStyle)),
          Expanded(flex: 3, child: Text('Nome', style: headerStyle)), // Aumentado flex
          Expanded(flex: 2, child: Text('Status', style: headerStyle)),
          Expanded(flex: 2, child: Text('Base Atual', style: headerStyle)),
          Expanded(flex: 2, child: Text('Venc. Calibração', style: headerStyle)),
          SizedBox(width: 56, child: Center(child: Text('Ações', style: headerStyle))),
        ],
      ),
    );
  }

  Widget _buildInstrumentRow(Instrument item) {
    // Item inativo fica cinza visualmente na tabela
    final cellStyle = TextStyle(color: item.ativo ? Colors.black87 : Colors.grey); 
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        children: [
          Expanded(flex: 2, child: Text(item.patrimonio, style: cellStyle)),
          Expanded(flex: 3, child: Text(item.descricao, style: cellStyle.copyWith(fontWeight: FontWeight.bold))),
          Expanded(flex: 2, child: _StatusChip(status: item.status, ativo: item.ativo)), // Passamos ativo também
          Expanded(flex: 2, child: Text(item.localAtual, style: cellStyle)),
          Expanded(flex: 2, child: Text(DateFormat('dd/MM/yyyy').format(item.proximaCalibracaoEm), style: cellStyle)),
          SizedBox(
            width: 56,
            child: Center(
              child: PopupMenuButton<String>(
                icon: const Icon(Icons.more_horiz, color: Colors.grey),
                tooltip: 'Ações',
                onSelected: (value) {
                  if (value == 'editar') _showInstrumentDialog(instrument: item);
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'editar',
                    child: Row(children: [Icon(Icons.edit, size: 20, color: Colors.blue), SizedBox(width: 12), Text('Editar')]),
                  ),
                ],
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
  final bool ativo; // NOVO: Para saber se está Inativo no sistema
  
  const _StatusChip({required this.status, required this.ativo});

  @override
  Widget build(BuildContext context) {
    // Se 'ativo' for false, forçamos visual de Inativo
    final isAtivoNoSistema = ativo;
    final isDisponivel = status == InstrumentStatus.ativo;
    
    Color bgColor;
    Color txtColor;
    String text;

    if (!isAtivoNoSistema) {
      bgColor = Colors.grey.shade200;
      txtColor = Colors.grey.shade600;
      text = 'Inativo';
    } else if (isDisponivel) {
      bgColor = Colors.green.shade100;
      txtColor = Colors.green.shade800;
      text = 'Disponível';
    } else {
      bgColor = Colors.orange.shade100;
      txtColor = Colors.orange.shade800;
      text = 'Em Uso';
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
        child: Text(text, style: TextStyle(color: txtColor, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ==========================================================
// ===== _AddOrEditInstrumentDialog (UNIFICADO) =============
// ==========================================================

class _AddOrEditInstrumentDialog extends StatefulWidget {
  final List<LocalFisico> locaisDisponiveis;
  final Instrument? instrumentParaEditar; // Se null = Criação
  
  // CORREÇÃO DA ASSINATURA: Espera um Map, não 6 variáveis soltas
  final Future<bool> Function(Map<String, dynamic>) onSave;

  const _AddOrEditInstrumentDialog({
    required this.locaisDisponiveis, 
    this.instrumentParaEditar,
    required this.onSave,
  });

  @override
  State<_AddOrEditInstrumentDialog> createState() => _AddOrEditInstrumentDialogState();
}

class _AddOrEditInstrumentDialogState extends State<_AddOrEditInstrumentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _patrimonioController = TextEditingController();
  final _descricaoController = TextEditingController();
  final _categoriaController = TextEditingController();
  final _calibracaoController = TextEditingController(); 
  
  LocalFisico? _selectedLocal;
  bool _ativo = true;
  bool _isSaving = false;

  bool get isEditing => widget.instrumentParaEditar != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      final i = widget.instrumentParaEditar!;
      _patrimonioController.text = i.patrimonio;
      _descricaoController.text = i.descricao;
      _categoriaController.text = i.categoria;
      _calibracaoController.text = DateFormat('yyyy-MM-dd').format(i.proximaCalibracaoEm);
      _ativo = i.ativo;
      
      try {
        _selectedLocal = widget.locaisDisponiveis.firstWhere((l) => l.nome == i.localAtual);
      } catch (_) {}
    } else {
      if (widget.locaisDisponiveis.isNotEmpty) _selectedLocal = widget.locaisDisponiveis.first;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Na criação, local é obrigatório. Na edição, é opcional (mantém o atual se não mudar)
    if (!isEditing && _selectedLocal == null) return;

    setState(() => _isSaving = true);

    // MONTA O MAPA DE DADOS
    final data = {
      "patrimonio": _patrimonioController.text.trim(),
      "descricao": _descricaoController.text.trim(),
      "categoria": _categoriaController.text.trim(),
      "proxima_calibracao_em": _calibracaoController.text.trim(),
      "ativo": _ativo,
    };
    
    if (_selectedLocal != null) {
       data["local_atual_id"] = _selectedLocal!.id;
    }

    // ENVIA O MAPA
    final success = await widget.onSave(data);

    if (success && mounted) Navigator.of(context).pop();
    else setState(() => _isSaving = false);
  }

  Future<void> _selectDate() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() => _calibracaoController.text = DateFormat('yyyy-MM-dd').format(picked));
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
      title: Text(isEditing ? 'Editar Instrumento' : 'Adicionar Novo', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField(controller: _patrimonioController, label: 'Patrimônio *', icon: Icons.qr_code),
              const SizedBox(height: 16),
              _buildTextField(controller: _descricaoController, label: 'Descrição *', icon: Icons.edit),
              const SizedBox(height: 16),
              _buildTextField(controller: _categoriaController, label: 'Categoria', icon: Icons.category),
              const SizedBox(height: 16),
              
              // Dropdown Local
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(color: inputFillColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: borderColor)),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<LocalFisico>(
                    value: _selectedLocal,
                    dropdownColor: primaryColor,
                    icon: const Icon(Icons.arrow_drop_down, color: hintColor),
                    style: const TextStyle(color: Colors.white),
                    hint: const Text("Local Atual *", style: TextStyle(color: Colors.white60)),
                    items: widget.locaisDisponiveis.map((l) => DropdownMenuItem(value: l, child: Text(l.nome, overflow: TextOverflow.ellipsis))).toList(),
                    onChanged: (val) => setState(() => _selectedLocal = val),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Data
              TextFormField(
                controller: _calibracaoController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Próxima Calibração', labelStyle: const TextStyle(color: Colors.white60),
                  filled: true, fillColor: inputFillColor,
                  prefixIcon: const Icon(Icons.calendar_today, color: Colors.white60),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
                  suffixIcon: IconButton(icon: const Icon(Icons.calendar_month, color: Colors.white60), onPressed: _selectDate),
                ),
                readOnly: true, onTap: _selectDate,
              ),

              // SWITCH ATIVO (Só na edição)
              if (isEditing) ...[
                const SizedBox(height: 16),
                Row(children: [
                   const Text("Instrumento Ativo?", style: TextStyle(color: Colors.white)),
                   Switch(value: _ativo, onChanged: (v) => setState(() => _ativo = v), activeColor: const Color(0xFF3B82F6)),
                ]),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Cancelar", style: TextStyle(color: Colors.white70))),
        ElevatedButton(onPressed: _isSaving ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6)), child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Salvar", style: TextStyle(color: Colors.white))),
      ],
    );
  }

  InputDecoration _buildInputDecoration({required String label, required IconData icon}) {
    const Color inputFillColor = Color.fromARGB(255, 30, 24, 53);
    const Color borderColor = Colors.white30;
    const Color hintColor = Colors.white60;
    return InputDecoration(
      labelText: label, labelStyle: const TextStyle(color: hintColor),
      prefixIcon: Icon(icon, color: hintColor, size: 20),
      filled: true, fillColor: inputFillColor,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: borderColor)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3B82F6))),
    );
  }
  
  Widget _buildTextField({required TextEditingController controller, required String label, required IconData icon}) {
    return TextFormField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      validator: (v) => (label.contains('*') && (v == null || v.isEmpty)) ? 'Obrigatório' : null,
      decoration: _buildInputDecoration(label: label, icon: icon),
    );
  }
}