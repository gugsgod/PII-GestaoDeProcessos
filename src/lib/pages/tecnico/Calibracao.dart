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

const String _apiHost = 'http://localhost:8080';

class _InstrumentoCalibracao {
  final int id;
  final String nome;
  final String patrimonio;
  final String localNome;
  final DateTime proximaCalibracao;
  final String status;

  _InstrumentoCalibracao({
    required this.id,
    required this.nome,
    required this.patrimonio,
    required this.localNome,
    required this.proximaCalibracao,
    required this.status,
  });

  bool get calibracaoVencida => proximaCalibracao.isBefore(DateTime.now());
  bool get isDisponivel => status == 'disponivel';

  // TODO: Ajustar o factory quando a API estiver pronta
  factory _InstrumentoCalibracao.fromJson(Map<String, dynamic> json) {
    return _InstrumentoCalibracao(
      id: json['id'] as int,
      nome: json['descricao'] as String,
      patrimonio: json['patrimonio'] as String,
      localNome: json['local_atual_nome'] ?? 'N/A',
      proximaCalibracao: DateTime.tryParse(json['proxima_calibracao_em'] ?? '') ?? DateTime.now(),
      status: json['status'] as String,
    );
  }
}

class Calibracao extends StatefulWidget {
  const Calibracao({Key? key}) : super(key: key);

  State<Calibracao> createState() => CalibracaoState();
}

class CalibracaoState extends State<Calibracao> {
  
  final TextEditingController _searchController = TextEditingController();

  // --- Controle da API ---
  late Future<void> _loadFuture;
  bool _isLoading = true;
  String? _error;
  List<_InstrumentoCalibracao> _instrumentos = [];
  List<_InstrumentoCalibracao> _instrumentosFiltrados = [];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filtrarDados);
    _loadFuture = _fetchData();
  }

  @override
  void dispose() {
    _searchController.removeListener(_filtrarDados);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() { _isLoading = true; _error = null; });

    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (token == null) {
      setState(() { _isLoading = false; _error = "Token inválido."; });
      return;
    }

    try {
      // Reutilizamos o endpoint do catálogo que já traz o JOIN com locais
      // Filtramos ?ativo=true para trazer apenas instrumentos ativos no sistema
      final uri = Uri.parse('$_apiHost/instrumentos/catalogo').replace(
        queryParameters: {
            'ativo': 'true',
            'vencidos': 'true',
        },
      );
      
      final response = await http.get(
        uri, 
        headers: {'Authorization': 'Bearer $token'}
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        if (mounted) {
          setState(() {
            _instrumentos = data.map((json) => _InstrumentoCalibracao.fromJson(json)).toList();
            // Ordena: Vencidos primeiro
            _instrumentos.sort((a, b) => a.proximaCalibracao.compareTo(b.proximaCalibracao));
          });
        }
      } else {
        throw Exception('Erro ${response.statusCode}: Falha ao buscar instrumentos.');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Falha ao carregar: ${e.toString().replaceAll('Exception: ', '')}";
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _filtrarDados();
        });
      }
    }
  }

  void _reloadData() {
    setState(() {
      _loadFuture = _fetchData();
    });
  }

  // Filtra a lista localmente
  void _filtrarDados() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _instrumentosFiltrados = _instrumentos.where((item) {
        return item.nome.toLowerCase().contains(query) ||
            item.patrimonio.toLowerCase().contains(query);
      }).toList();
    });
  }

  // Abre o modal de atualização
  void _showAtualizarModal(_InstrumentoCalibracao item) {
    showDialog(
      context: context,
      builder: (context) {
        return _ModalAtualizarCalibracao(
          item: item,
          token: context.read<AuthStore>().token!,
          onSuccess: (novaData) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Calibração atualizada com sucesso!'),
                backgroundColor: Colors.green,
              ),
            );
            _reloadData(); // Recarrega a lista do servidor
          },
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF080023);
    const Color secondaryColor = Color.fromARGB(255, 0, 14, 92);
    final isDesktop = MediaQuery.of(context).size.width >= 768;

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
              // Títulos
              const Text(
                'Calibração',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 32,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Atualize a calibração dos instrumentos no sistema.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 24),

              // --- Barra de Pesquisa (IMPLEMENTADA) ---
              _buildSearchBar(),
              const SizedBox(height: 24),

              // --- Conteúdo Principal (Grid) (IMPLEMENTADO) ---
              _buildBodyContent(isDesktop),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: _searchController,
      style: const TextStyle(color: Colors.black), // Texto escuro
      decoration: InputDecoration(
        hintText: 'Buscar por nome ou código...',
        hintStyle: const TextStyle(color: Colors.black54),
        prefixIcon: const Icon(Icons.search, color: Colors.black54),
        filled: true,
        fillColor: Colors.white, // Fundo branco
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  // Constrói o corpo principal (Loading, Erro, ou Grid)
  Widget _buildBodyContent(bool isDesktop) {
    return FutureBuilder(
      future: _loadFuture,
      builder: (context, snapshot) {
        if (_isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
        }

        if (_error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent, fontSize: 16),
              ),
            ),
          );
        }

        if (_instrumentosFiltrados.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 64.0),
              child: Column(
                children: [
                  Icon(Icons.search_off, color: Colors.white30, size: 48),
                  SizedBox(height: 16),
                  Text(
                    "Nenhum instrumento encontrado",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                  ),
                ],
              ),
            ),
          );
        }

        // Constrói a grid
        final int crossAxisCount = isDesktop ? 2 : 1;
        final double childAspectRatio = isDesktop ? 2.8 : 2.5;

        return GridView.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            childAspectRatio: childAspectRatio,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: _instrumentosFiltrados.length,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemBuilder: (context, index) {
            return _CalibracaoCard(
              item: _instrumentosFiltrados[index],
              onAtualizar: () => _showAtualizarModal(_instrumentosFiltrados[index]),
            );
          },
        );
      },
    );
  }
}

class _CalibracaoCard extends StatelessWidget {
  final _InstrumentoCalibracao item;
  final VoidCallback onAtualizar;

  const _CalibracaoCard({required this.item, required this.onAtualizar});

  String _formatarData(DateTime data) {
    return DateFormat('dd/MM/yyyy').format(data.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    const Color cardColor = Colors.white; // Fundo branco
    const Color textColor = Colors.black87;
    const Color titleColor = Colors.black;

    final bool vencida = item.calibracaoVencida;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Linha 1: Título e Tags ---
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.construction, // Ícone de instrumento
                color: Colors.green.shade700,
                size: 32,
              ),
              const SizedBox(width: 12),
              // Título e ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nome,
                      style: const TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(
                      item.patrimonio,
                      style: const TextStyle(color: textColor, fontSize: 14),
                    ),
                  ],
                ),
              ),
              // Tags
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (item.isDisponivel)
                    _TagChip(
                      label: "Disponível",
                      backgroundColor: Colors.green.withOpacity(0.2),
                      textColor: Colors.green.shade800,
                    ),
                  if (vencida) ...[
                    const SizedBox(height: 4),
                    _TagChip(
                      label: "Calibração Vencida",
                      backgroundColor: Colors.red.withOpacity(0.2),
                      textColor: Colors.red.shade800,
                    ),
                  ]
                ],
              ),
            ],
          ),
          const Spacer(),
          // --- Linhas de Informação ---
          _InfoLinha(
            icon: Icons.location_on_outlined,
            title: "Local:",
            value: item.localNome,
          ),
          const SizedBox(height: 8),
          _InfoLinha(
            icon: Icons.calendar_today_outlined,
            title: "Calibração:",
            value: _formatarData(item.proximaCalibracao),
            valueColor: vencida ? Colors.red.shade700 : null,
            iconColor: vencida ? Colors.red.shade700 : null,
          ),
          const SizedBox(height: 16),
          // --- Botão Atualizar ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onAtualizar,
              icon: const Icon(Icons.refresh, size: 16, color: Colors.white),
              label: const Text("Atualizar calibração"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}

// 
class _ModalAtualizarCalibracao extends StatefulWidget {
  final _InstrumentoCalibracao item;
  final String token; 
  final Function(DateTime) onSuccess;

  const _ModalAtualizarCalibracao({
    required this.item,
    required this.token,
    required this.onSuccess,
  });

  @override
  State<_ModalAtualizarCalibracao> createState() => _ModalAtualizarCalibracaoState();
}

class _ModalAtualizarCalibracaoState extends State<_ModalAtualizarCalibracao> {
  static const String _apiHost = 'http://localhost:8080';
  DateTime _novaData = DateTime.now().add(const Duration(days: 365));
  bool _ciente = false;
  bool _isLoading = false;
  String? _error;
  late TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: DateFormat('dd/MM/yyyy').format(_novaData));
  }

  @override
  void dispose() {
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selecionarData(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _novaData,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != _novaData) {
      setState(() {
        _novaData = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(_novaData);
      });
    }
  }

  Future<void> _submit() async {
    if (!_ciente) {
      setState(() {
        _error = "Você deve estar ciente da alteração.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Prepara os dados para o Backend
      // Usamos o endpoint raiz /instrumentos com o método PATCH
      final uri = Uri.parse('$_apiHost/instrumentos'); 
      final body = json.encode({
        'id': widget.item.id, // ID do instrumento
        'proxima_calibracao_em': _novaData.toIso8601String(),
      });

      final response = await http.patch(
        uri,
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: body,
      );

      if (response.statusCode == 200) {
        // Sucesso!
        widget.onSuccess(_novaData); // Fecha o modal e avisa a tela pai
      } else {
        // Tratamento de erro
        String msgErro = 'Falha ao atualizar';
        try {
          final errData = json.decode(utf8.decode(response.bodyBytes));
          msgErro = errData['body'] ?? errData['error'] ?? response.body;
        } catch (_) {
          msgErro = response.body;
        }
        
        if (mounted) {
          setState(() {
            _error = "Erro ${response.statusCode}: $msgErro";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Erro de conexão: $e";
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Atualizar ${widget.item.nome}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _InfoLinha(icon: Icons.tag, title: "Patrimônio:", value: widget.item.patrimonio),
            const SizedBox(height: 8),
            _InfoLinha(icon: Icons.location_on_outlined, title: "Local:", value: widget.item.localNome),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 16),
            const Text("Nova data de vencimento:", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _dateController,
              readOnly: true,
              decoration: const InputDecoration(labelText: 'Data', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
              onTap: () => _selecionarData(context),
            ),
            const SizedBox(height: 16),
            CheckboxListTile(
              title: const Text("Estou ciente que após a atualização, apenas um administrador pode alterar a data antes do vencimento.", style: TextStyle(fontSize: 12)),
              value: _ciente,
              onChanged: (val) => setState(() => _ciente = val ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            if (_error != null) Padding(padding: const EdgeInsets.only(top: 16.0), child: Text(_error!, style: const TextStyle(color: Colors.red))),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _isLoading ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        ElevatedButton.icon(onPressed: (_isLoading || !_ciente) ? null : _submit, icon: const Icon(Icons.refresh), label: const Text('Atualizar'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white)),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label; final Color backgroundColor; final Color textColor;
  const _TagChip({required this.label, required this.backgroundColor, required this.textColor});
  @override
  Widget build(BuildContext context) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: backgroundColor, borderRadius: BorderRadius.circular(6)), child: Text(label, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 11)));
  }
}

class _InfoLinha extends StatelessWidget {
  final IconData icon; final String title; final String value; final Color? iconColor; final Color? valueColor;
  const _InfoLinha({required this.icon, required this.title, required this.value, this.iconColor, this.valueColor});
  @override
  Widget build(BuildContext context) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: iconColor ?? Colors.black54, size: 16), const SizedBox(width: 8), Text(title, style: const TextStyle(color: Colors.black54)), const SizedBox(width: 4), Expanded(child: Text(value, style: TextStyle(color: valueColor ?? Colors.black87, fontWeight: FontWeight.bold)))]);
  }
}

// ==========================================================
// ===== DADOS MOCKADOS (PARA PREPARAÇÃO) ===================
// ==========================================================
List<_InstrumentoCalibracao> _getMockData() {
  return [
    _InstrumentoCalibracao(
      id: 1,
      nome: 'Osciloscópio Tektronix',
      patrimonio: 'INST0113',
      localNome: 'BASE 01',
      proximaCalibracao: DateTime.now().subtract(const Duration(days: 10)), // Vencido
      status: 'disponivel',
    ),
    _InstrumentoCalibracao(
      id: 2,
      nome: 'Analisador de Energia',
      patrimonio: 'INST0112',
      localNome: 'BASE 01',
      proximaCalibracao: DateTime.now().add(const Duration(days: 90)), // OK
      status: 'disponivel',
    ),
    _InstrumentoCalibracao(
      id: 3,
      nome: 'Megôhmetro 5kV',
      patrimonio: 'INST007',
      localNome: 'Em uso', // Mock de item em uso
      proximaCalibracao: DateTime.now().add(const Duration(days: 30)), // OK
      status: 'em_uso',
    ),
    _InstrumentoCalibracao(
      id: 4,
      nome: 'Detector de Gás Portátil',
      patrimonio: 'INST004',
      localNome: 'BASE 02',
      proximaCalibracao: DateTime.now().add(const Duration(days: 120)), // OK
      status: 'disponivel',
    ),
  ];
}