import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';
import 'package:src/pages/admin/animated_network_background.dart';
import 'package:src/widgets/tecnico/home_tecnico/tecnico_drawer.dart';

// ==========================================================
// ===== MODELOS DE DADOS ===================================
// ==========================================================

// Modelo auxiliar para o Dropdown de locais (Copiado de Atividades.dart)
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

class _HistoricoItem {
  final String idMovimentacao;
  final String nome;
  final String idMaterial; 
  final String? categoria; 
  final String statusTag; 
  final bool isInstrumento;

  // Campos de Informação
  final String destino;
  final String finalidade;
  final DateTime dataRetirada;
  final DateTime previsaoDevolucao;
  final DateTime? dataDevolucaoReal;
  
  // NOVOS CAMPOS (Necessários para Devolução)
  final double quantidadePendente;
  final String? lote;

  _HistoricoItem({
    required this.idMovimentacao,
    required this.nome,
    required this.idMaterial,
    this.categoria,
    required this.statusTag,
    required this.isInstrumento,
    required this.destino,
    required this.finalidade,
    required this.dataRetirada,
    required this.previsaoDevolucao,
    this.dataDevolucaoReal,
    required this.quantidadePendente,
    this.lote,
  });

  bool get emUso => dataDevolucaoReal == null;
}

// ==========================================================
// ===== TELA PRINCIPAL =====================================
// ==========================================================

enum HistoricoTab { emUso, historico }

class HistoricoUso extends StatefulWidget {
  const HistoricoUso({Key? key}) : super(key: key);

  @override
  State<HistoricoUso> createState() => HistoricoUsoState();
}

class HistoricoUsoState extends State<HistoricoUso> {
  static const String _apiHost = 'http://localhost:8080';
  
  HistoricoTab _selectedTab = HistoricoTab.emUso;
  late Future<void> _loadFuture;
  bool _isLoading = true;
  String? _error;
  List<_HistoricoItem> _items = [];

  @override
  void initState() {
    super.initState();
    _loadFuture = _fetchData();
  }

  // ================== LÓGICA DE DADOS ==================

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });

    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (token == null) {
      setState(() { _isLoading = false; _error = "Usuário não autenticado."; });
      return;
    }

    try {
      List<_HistoricoItem> fetchedItems = [];

      if (_selectedTab == HistoricoTab.emUso) {
        fetchedItems = await _fetchEmUso(token!);
      } else {
        fetchedItems = await _fetchHistoricoPassado(token!);
      }

      if (mounted) {
        setState(() {
          _items = fetchedItems;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erro ao carregar: ${e.toString().replaceAll('Exception: ', '')}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<List<_HistoricoItem>> _fetchEmUso(String token) async {
    final uri = Uri.parse('$_apiHost/movimentacoes/pendentes');
    final headers = {'Authorization': 'Bearer $token'};

    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      
      return data.map((json) {
        final idMov = json['idMovimentacao'].toString();
        final isInst = idMov.startsWith('inst');
        // Parse seguro da quantidade
        final qtdPendente = (json['quantidade_pendente'] as num?)?.toDouble() ?? 0.0;

        String statusDisplay = 'Em Uso';
        if (!isInst && qtdPendente > 0) {
          statusDisplay = 'Em Uso ($qtdPendente)';
        }

        return _HistoricoItem(
          idMovimentacao: idMov,
          nome: json['nomeMaterial'] ?? 'Item',
          idMaterial: json['idMaterial'] ?? '',
          categoria: isInst ? 'Instrumento' : 'Material',
          statusTag: statusDisplay,
          isInstrumento: isInst,
          destino: json['localizacao'] ?? 'N/A',
          finalidade: 'Uso em serviço', // Placeholder (endpoint não retorna ainda)
          dataRetirada: DateTime.tryParse(json['dataRetirada'] ?? '') ?? DateTime.now(),
          previsaoDevolucao: DateTime.tryParse(json['dataDevolucao'] ?? '') ?? DateTime.now(),
          dataDevolucaoReal: null,
          // Novos campos mapeados
          quantidadePendente: qtdPendente,
          lote: json['lote'] as String?,
        );
      }).toList();
    } else {
      throw Exception('Falha na API (${response.statusCode})');
    }
  }

  Future<List<_HistoricoItem>> _fetchHistoricoPassado(String token) async {
    final uri = Uri.parse('$_apiHost/movimentacoes/historico');
    final headers = {'Authorization': 'Bearer $token'};

    final response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 10));

    if (response.statusCode == 200) {
      final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
      
      return data.map((json) {
        // Mapeamento simples, pois o backend já manda formatado
        return _HistoricoItem(
          idMovimentacao: json['idMovimentacao'],
          nome: json['nomeMaterial'] ?? 'Item',
          idMaterial: json['idMaterial'] ?? '',
          categoria: json['categoria'],
          statusTag: json['statusTag'] ?? 'Devolvido',
          isInstrumento: json['isInstrumento'] ?? false,
          destino: json['localizacao'] ?? 'N/A',
          finalidade: 'Histórico de uso',
          dataRetirada: DateTime.tryParse(json['dataRetirada'] ?? '') ?? DateTime.now(),
          previsaoDevolucao: DateTime.tryParse(json['previsaoDevolucao'] ?? '') ?? DateTime.now(),
          dataDevolucaoReal: DateTime.tryParse(json['dataDevolucaoReal'] ?? '') ?? DateTime.now(),
          quantidadePendente: 0, // Item devolvido
        );
      }).toList();
    } else {
      throw Exception('Falha na API Histórico (${response.statusCode})');
    }
  }

  // ================== LÓGICA DE DEVOLUÇÃO ==================

  void _handleDevolucao(_HistoricoItem item) {
    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (token == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro: Token de autenticação ausente.')),
      );
      return;
    }

    if (item.isInstrumento) {
      showDialog(
        context: context,
        builder: (_) => _ModalDevolverInstrumento(
          item: item,
          token: token,
          onSuccess: _onDevolucaoSuccess,
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => _ModalDevolverMaterial(
          item: item,
          token: token,
          onSuccess: _onDevolucaoSuccess,
        ),
      );
    }
  }

  void _onDevolucaoSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Devolução registrada com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
    // Recarrega a lista
    _fetchData();
  }

  void _onToggleChanged(HistoricoTab tab) {
    if (_selectedTab != tab) {
      setState(() {
        _selectedTab = tab;
      });
      _fetchData();
    }
  }

  // ================== UI BUILD ==================

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color.fromARGB(255, 0, 14, 92);

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
            child: Image.asset('assets/images/logo_metroSP.png', height: 50),
          ),
        ],
      ),
      drawer: const TecnicoDrawer(primaryColor: primaryColor, secondaryColor: secondaryColor),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Histórico de Uso',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 32),
              ),
              const SizedBox(height: 8),
              const Text(
                'Histórico completo de retiradas e devoluções',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 24),
              _buildToggleButtons(),
              const SizedBox(height: 24),
              _buildBodyContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToggleButtons() {
    bool isEmUso = _selectedTab == HistoricoTab.emUso;
    bool isHistorico = _selectedTab == HistoricoTab.historico;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _buildToggleItem("Em uso", isEmUso, () => _onToggleChanged(HistoricoTab.emUso)),
          _buildToggleItem("Histórico", isHistorico, () => _onToggleChanged(HistoricoTab.historico)),
        ],
      ),
    );
  }

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

  Widget _buildBodyContent() {
    return FutureBuilder(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (_isLoading) {
          return const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator(color: Colors.white)));
        }
        if (_error != null) {
          return Center(child: Padding(padding: const EdgeInsets.all(32.0), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))));
        }
        if (_items.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64.0),
              child: Column(
                children: [
                  Icon(Icons.search_off, color: Colors.white30, size: 48),
                  SizedBox(height: 16),
                  Text("Nenhum item encontrado", style: TextStyle(color: Colors.white70, fontSize: 16)),
                ],
              ),
            ),
          );
        }

        return ListView.separated(
          itemCount: _items.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          separatorBuilder: (context, index) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _HistoricoCard(
              item: _items[index],
              // Passa a função de devolução que abre o modal
              onDevolver: () => _handleDevolucao(_items[index]),
            );
          },
        );
      },
    );
  }
}

// ==========================================================
// ===== CARD DO HISTÓRICO ==================================
// ==========================================================
class _HistoricoCard extends StatelessWidget {
  final _HistoricoItem item;
  final VoidCallback onDevolver;

  const _HistoricoCard({required this.item, required this.onDevolver});

  String _formatarData(DateTime data) {
    return DateFormat('dd/MM/yyyy \'às\' HH:mm').format(data.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    const Color cardColor = Color(0xFFE0E0E0);
    const Color textColor = Colors.black87;
    const Color titleColor = Colors.black;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                item.isInstrumento ? Icons.construction : Icons.inventory_2_outlined,
                color: item.isInstrumento ? Colors.green.shade700 : Colors.blue.shade700,
                size: 32,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.nome, style: const TextStyle(color: titleColor, fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(item.idMaterial, style: const TextStyle(color: textColor, fontSize: 14)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.categoria != null) ...[
                    _TagChip(
                      label: item.categoria!,
                      backgroundColor: Colors.black.withOpacity(0.1),
                      textColor: Colors.black54,
                    ),
                    const SizedBox(height: 4),
                  ],
                  _TagChip(
                    label: item.statusTag,
                    backgroundColor: item.emUso ? Colors.yellow.shade700.withOpacity(0.3) : Colors.green.withOpacity(0.2),
                    textColor: item.emUso ? Colors.yellow.shade900 : Colors.green.shade800,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoLinha(icon: Icons.location_on_outlined, title: "Destino:", value: item.destino),
          const SizedBox(height: 8),
          _InfoLinha(
            icon: Icons.schedule_outlined,
            title: "Previsão:",
            value: _formatarData(item.previsaoDevolucao),
            valueColor: (item.emUso && item.previsaoDevolucao.isBefore(DateTime.now())) ? Colors.red.shade700 : null,
          ),
          const SizedBox(height: 8),
          _InfoLinha(icon: Icons.article_outlined, title: "Finalidade:", value: item.finalidade),
          const SizedBox(height: 8),
          _InfoLinha(icon: Icons.calendar_today_outlined, title: "Retirado em:", value: _formatarData(item.dataRetirada)),
          
          if (!item.emUso && item.dataDevolucaoReal != null) ...[
            const SizedBox(height: 8),
            _InfoLinha(
              icon: Icons.check_circle_outline,
              title: "Devolvido em:",
              value: _formatarData(item.dataDevolucaoReal!),
              iconColor: Colors.green.shade700,
              valueColor: Colors.green.shade800,
            ),
          ],
          
          if (item.emUso) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onDevolver,
                icon: const Icon(Icons.arrow_downward, size: 16, color: Colors.white),
                label: Text(item.isInstrumento ? "Devolver Instrumento" : "Devolver Material"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            )
          ]
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  const _TagChip({required this.label, required this.backgroundColor, required this.textColor});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(6)),
      child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)),
    );
  }
}

class _InfoLinha extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;
  final Color? valueColor;
  const _InfoLinha({required this.icon, required this.title, required this.value, this.iconColor, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? Colors.black54, size: 16),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(color: Colors.black54)),
        const SizedBox(width: 4),
        Expanded(child: Text(value, style: TextStyle(color: valueColor ?? Colors.black87, fontWeight: FontWeight.bold))),
      ],
    );
  }
}

// ==========================================================
// ===== MODALS (PORTADOS DE ATIVIDADES.DART) ===============
// ==========================================================

class _ModalDevolverInstrumento extends StatefulWidget {
  final _HistoricoItem item; 
  final String token;
  final VoidCallback onSuccess;

  const _ModalDevolverInstrumento({
    required this.item,
    required this.token,
    required this.onSuccess,
  });

  @override
  State<_ModalDevolverInstrumento> createState() => _ModalDevolverInstrumentoState();
}

class _ModalDevolverInstrumentoState extends State<_ModalDevolverInstrumento> {
  static const String _apiHost = 'http://localhost:8080';
  bool _isLoading = false;
  bool _isLoadingLocais = true; // Controle de carregamento
  String? _error;
  
  // Variáveis para o Local de Destino
  LocalFisico? _selectedDestinoLocal;
  List<LocalFisico> _locais = [];

  @override
  void initState() {
    super.initState();
    _fetchLocais();
  }

  Future<void> _fetchLocais() async {
    final uri = Uri.parse('$_apiHost/locais');
    final headers = {'Authorization': 'Bearer ${widget.token}'};

    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body)['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _locais = jsonList.map((j) => LocalFisico.fromJson(j as Map<String, dynamic>)).toList();
            // Opcional: Pré-selecionar o primeiro
            if (_locais.isNotEmpty) {
              _selectedDestinoLocal = _locais.first;
            }
          });
        }
      } else {
        _error = 'Falha ao carregar locais: ${response.statusCode}';
      }
    } catch (e) {
      _error = 'Erro de rede: $e';
    } finally {
      if (mounted) setState(() => _isLoadingLocais = false);
    }
  }

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    if (_selectedDestinoLocal == null) {
      setState(() { _error = 'Selecione o local de destino.'; _isLoading = false; });
      return;
    }

    try {
      final body = json.encode({
        'idMovimentacao': widget.item.idMovimentacao,
        'destino_local_id': _selectedDestinoLocal!.id, // <-- AGORA ENVIA O DESTINO
      });

      final response = await http.post(
        Uri.parse('$_apiHost/movimentacoes/devolucao'),
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
          _error = errorData['error'] ?? 'Falha ao devolver o instrumento.';
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
    return AlertDialog(
      title: const Text('Confirmar Devolução'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Instrumento: ${widget.item.nome} (${widget.item.idMaterial})'),
            const SizedBox(height: 16),
            
            if (_isLoadingLocais) 
              const Center(child: CircularProgressIndicator()) 
            else ...[
              DropdownButtonFormField<LocalFisico>(
                value: _selectedDestinoLocal,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Local de Destino',
                  border: OutlineInputBorder(),
                ),
                items: _locais.map((local) {
                  return DropdownMenuItem(
                    value: local,
                    child: Text(local.nome),
                  );
                }).toList(),
                onChanged: (local) {
                  setState(() {
                    _selectedDestinoLocal = local;
                  });
                },
                hint: const Text('Selecione onde guardar'),
              ),
            ],
            
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: (_isLoading || _isLoadingLocais || _selectedDestinoLocal == null) ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Devolver'),
        ),
      ],
    );
  }
}

class _ModalDevolverMaterial extends StatefulWidget {
  final _HistoricoItem item; // Adaptado
  final String token;
  final VoidCallback onSuccess;

  const _ModalDevolverMaterial({required this.item, required this.token, required this.onSuccess});

  @override
  State<_ModalDevolverMaterial> createState() => _ModalDevolverMaterialState();
}

class _ModalDevolverMaterialState extends State<_ModalDevolverMaterial> {
  static const String _apiHost = 'http://localhost:8080';
  bool _isLoading = false;
  bool _isLoadingLocais = true;
  String? _error;
  final TextEditingController _qtController = TextEditingController();
  LocalFisico? _selectedDestinoLocal;
  List<LocalFisico> _locais = [];

  @override
  void initState() {
    super.initState();
    _qtController.text = widget.item.quantidadePendente.toString();
    _fetchLocais();
  }

  Future<void> _fetchLocais() async {
    final uri = Uri.parse('$_apiHost/locais');
    final headers = {'Authorization': 'Bearer ${widget.token}'};
    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body)['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _locais = jsonList.map((j) => LocalFisico.fromJson(j as Map<String, dynamic>)).toList();
            if (_locais.isNotEmpty) _selectedDestinoLocal = _locais.first;
          });
        }
      }
    } catch (e) { /* log error */ } finally {
      if (mounted) setState(() => _isLoadingLocais = false);
    }
  }

  Future<void> _submit() async {
    setState(() { _isLoading = true; _error = null; });
    final double? quantidade = double.tryParse(_qtController.text);
    
    if (quantidade == null || quantidade <= 0) {
      setState(() { _error = 'Quantidade inválida.'; _isLoading = false; });
      return;
    }
    if (quantidade > widget.item.quantidadePendente) {
      setState(() { _error = 'Não pode devolver mais do que o pendente.'; _isLoading = false; });
      return;
    }
    if (_selectedDestinoLocal == null) {
      setState(() { _error = 'Selecione o local.'; _isLoading = false; });
      return;
    }

    try {
      final body = json.encode({
        'idMovimentacao': widget.item.idMovimentacao,
        'quantidade': quantidade,
        'destino_local_id': _selectedDestinoLocal!.id,
        'lote': widget.item.lote,
      });
      final response = await http.post(
        Uri.parse('$_apiHost/movimentacoes/devolucao'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer ${widget.token}'},
        body: body,
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        Navigator.of(context).pop();
        widget.onSuccess();
      } else {
        final Map<String, dynamic> errorData = json.decode(response.body);
        setState(() { _error = errorData['error'] ?? 'Falha.'; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro de conexão: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Devolver ${widget.item.nome}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Pendente: ${widget.item.quantidadePendente} (Lote: ${widget.item.lote ?? "N/A"})', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (_isLoadingLocais) const Center(child: CircularProgressIndicator()) else ...[
              TextField(
                controller: _qtController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Quantidade', border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<LocalFisico>(
                value: _selectedDestinoLocal,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Local de Destino', border: OutlineInputBorder()),
                items: _locais.map((l) => DropdownMenuItem(value: l, child: Text(l.nome))).toList(),
                onChanged: (l) => setState(() => _selectedDestinoLocal = l),
                hint: const Text('Selecione...'),
              ),
            ],
            if (_error != null) ...[const SizedBox(height: 16), Text(_error!, style: const TextStyle(color: Colors.red))],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton(onPressed: (_isLoading || _isLoadingLocais || _selectedDestinoLocal == null) ? null : _submit, child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Confirmar')),
      ],
    );
  }
}