import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:src/auth/auth_store.dart';
import 'dart:async';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart'; // Para formatar datas
// Constante da API
const String apiBaseUrl = 'http://localhost:8080';

// ==================================================================
// ===== MODELOS AUXILIARES PARA O DROPDOWN =========================
// ==================================================================

class LocalFisico {
  final int id;
  final String nome;
  LocalFisico({required this.id, required this.nome});
  factory LocalFisico.fromJson(Map<String, dynamic> json) => 
      LocalFisico(id: json['id'] as int, nome: json['nome'] as String);
}

class InstrumentoMovimentacao {
  final String id; // ID interno do DB (para retirada)
  final String patrimonio;
  final String nome;
  final String? localNome;
  final String? idMovimentacao; // ID da movimentação (para devolução)

  InstrumentoMovimentacao({
    required this.id, 
    required this.patrimonio, 
    required this.nome, 
    this.localNome, 
    this.idMovimentacao
  });
  
  factory InstrumentoMovimentacao.fromMap(Map<String, dynamic> m) {
    return InstrumentoMovimentacao(
      id: m['id']?.toString() ?? 'N/A',
      patrimonio: m['patrimonio']?.toString() ?? 'N/A',
      nome: m['descricao']?.toString() ?? 'N/A',
      localNome: m['local_atual_nome']?.toString(),
      idMovimentacao: m['idMovimentacao']?.toString(),
    );
  }
}

// ==================================================================
// ===== WIDGET PRINCIPAL: QUICK ACTIONS ============================
// ==================================================================

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

  void _showMovimentacaoDialog(BuildContext context, {bool isInstrumento = false}) {
    showDialog(
      context: context,
      builder: (context) => _MovimentacaoDialog(isInstrumento: isInstrumento),
    );
  }

  Future<void> _gerarRelatorioCompleto(BuildContext context) async {
    final token = context.read<AuthStore>().token;
    if (token == null) return;

    // 1. Mostra Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final headers = {'Authorization': 'Bearer $token'};

      // 2. Busca TODOS os dados em paralelo (Limitados para não travar em produção grande)
      final responses = await Future.wait([
        http.get(Uri.parse('$apiBaseUrl/materiais?limit=200&ativo=true'), headers: headers), // [0]
        http.get(Uri.parse('$apiBaseUrl/instrumentos?ativo=true'), headers: headers),        // [1]
        http.get(Uri.parse('$apiBaseUrl/usuarios?limit=200'), headers: headers),             // [2]
        http.get(Uri.parse('$apiBaseUrl/movimentacoes?limit=100'), headers: headers),        // [3]
      ]);

      // Fecha o loading
      if (context.mounted) Navigator.pop(context);

      // Verifica erros básicos
      if (responses.any((r) => r.statusCode != 200)) {
        throw Exception('Falha ao obter dados do servidor.');
      }

      // Decodifica dados
      final materiais = jsonDecode(utf8.decode(responses[0].bodyBytes))['data'] as List;
      final decodedInstrumentos = jsonDecode(utf8.decode(responses[1].bodyBytes));
      final List listaInstrumentos = decodedInstrumentos is Map
          ? List.from(decodedInstrumentos['data'] ?? [])
          : List.from(decodedInstrumentos ?? []);
      
      final usuarios = jsonDecode(utf8.decode(responses[2].bodyBytes))['data'] as List;
      final movimentacoes = jsonDecode(utf8.decode(responses[3].bodyBytes))['data'] as List;

      // 3. Gera o PDF
      final pdf = pw.Document();
      final font = await PdfGoogleFonts.nunitoExtraLight();
      final fontBold = await PdfGoogleFonts.nunitoExtraBold();

      // Helper para cabeçalho de seção
      pw.Widget _buildHeader(String text) {
        return pw.Header(
          level: 0,
          child: pw.Text(text, style: pw.TextStyle(font: fontBold, fontSize: 18)),
        );
      }

      // Adiciona Página Principal
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: fontBold),
          build: (pw.Context context) => [
            pw.Center(
              child: pw.Text('Relatório Geral do Sistema', style: pw.TextStyle(font: fontBold, fontSize: 24)),
            ),
            pw.Center(
              child: pw.Text('Gerado em: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            ),
            pw.SizedBox(height: 20),

            // --- MATERIAIS ---
            _buildHeader('Materiais Ativos (${materiais.length})'),
            pw.Table.fromTextArray(
              headers: ['Cód. SAP', 'Descrição', 'Categoria', 'Unidade'],
              data: materiais.map((m) => [
                m['cod_sap'].toString(),
                m['descricao']?.toString() ?? '',
                m['categoria']?.toString() ?? '-',
                m['unidade']?.toString() ?? '-',
              ]).toList(),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: null,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft},
            ),
            pw.SizedBox(height: 20),

            // --- INSTRUMENTOS ---
            _buildHeader('Instrumentos (${listaInstrumentos.length})'),
            pw.Table.fromTextArray(
              headers: ['Patrimônio', 'Nome', 'Status', 'Local Atual'],
              data: listaInstrumentos.map((i) => [
                i['patrimonio']?.toString() ?? '',
                i['descricao']?.toString() ?? '',
                i['status']?.toString() ?? '',
                i['local_atual_nome']?.toString() ?? 'N/A',
              ]).toList(),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: null,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 20),

            // --- USUÁRIOS ---
            _buildHeader('Pessoas Cadastradas (${usuarios.length})'),
            pw.Table.fromTextArray(
              headers: ['Nome', 'Email', 'Perfil'],
              data: usuarios.map((u) => [
                u['nome']?.toString() ?? '',
                u['email']?.toString() ?? '',
                u['funcao']?.toString() ?? '',
              ]).toList(),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 9),
              border: null,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
            pw.SizedBox(height: 20),

            // --- MOVIMENTAÇÕES RECENTES ---
            _buildHeader('Últimas Movimentações (Top 100)'),
            pw.Table.fromTextArray(
              headers: ['Data', 'Operação', 'Item', 'Qtd', 'Resp.'],
              data: movimentacoes.map((mov) {
                final date = DateTime.tryParse(mov['created_at'] ?? '');
                final dateStr = date != null ? DateFormat('dd/MM HH:mm').format(date) : '-';
                final itemDesc = mov['material']?['descricao'] ?? 'Inst. ID ${mov['material_id']}'; // Fallback simples
                
                return [
                  dateStr,
                  mov['operacao']?.toString().toUpperCase() ?? '',
                  itemDesc,
                  mov['quantidade']?.toString() ?? '1',
                  mov['responsavel_id']?.toString() ?? '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(font: fontBold, fontSize: 10),
              cellStyle: const pw.TextStyle(fontSize: 8), // Fonte menor para caber
              border: null,
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ),
      );

      // 4. Compartilha/Abre o PDF
      await Printing.sharePdf(bytes: await pdf.save(), filename: 'relatorio_geral.pdf');

    } catch (e) {
      if (context.mounted) {
        // Se o loading ainda estiver aberto por algum erro, fecha
        // (O try/catch e o pop acima devem garantir, mas segurança extra)
        // Navigator.pop(context); 
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao gerar relatório: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ações Rápidas:',
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              // 1. Botão NOVA MOVIMENTAÇÃO (Materiais)
              HoverableButton(
                icon: Icons.swap_horiz,
                iconColor: Colors.blue.shade700,
                title: 'Nova Movimentação',
                subtitle: 'Retirar ou Devolver Material',
                onTap: () => _showMovimentacaoDialog(context, isInstrumento: false),
              ),
              const SizedBox(height: 12),
              
              // 2. Botão RETIRAR INSTRUMENTO (Instrumentos)
              HoverableButton(
                icon: Icons.handyman_outlined,
                iconColor: Colors.green.shade600,
                title: 'Retirar Instrumento',
                subtitle: 'Controle e Devolução de Instrumentos',
                onTap: () => _showMovimentacaoDialog(context, isInstrumento: true), 
              ),
              const SizedBox(height: 12),
              
              // 3. Botão RELATÓRIO (Placeholder)
              HoverableButton(
                icon: Icons.download_outlined,
                iconColor: Colors.purple.shade600,
                title: 'Relatório Rápido',
                subtitle: 'Gerar Relatório Geral',
                onTap: () => _gerarRelatorioCompleto(context), // <-- CHAMADA DA FUNÇÃO
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ==================================================================
// ===== POPUP DE MOVIMENTAÇÃO (UNIFICADO) ==========================
// ==================================================================

class _MovimentacaoDialog extends StatefulWidget {
  final bool isInstrumento;

  const _MovimentacaoDialog({required this.isInstrumento});

  @override
  State<_MovimentacaoDialog> createState() => _MovimentacaoDialogState();
}

class _MovimentacaoDialogState extends State<_MovimentacaoDialog> {
  // Toggle e Status
  bool _isRetirada = true; // true = Retirada, false = Devolução
  bool _isLoading = false;
  bool _isLoadingData = false;
  String? _error;

  // Listas de Dados
  List<dynamic> _items = []; // InstrumentoMovimentacao ou MaterialItem (Map)
  List<LocalFisico> _locais = [];

  // Seleções
  dynamic _selectedItem; 
  LocalFisico? _selectedLocal;
  final TextEditingController _qtController = TextEditingController(text: '1');

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  // Lógica de Busca de Dados (Inteligente)
  Future<void> _fetchInitialData() async {
    setState(() { 
      _isLoadingData = true; 
      _error = null; 
      _items = [];
      _locais = [];
      _selectedItem = null;
      _selectedLocal = null;
    });

    final token = context.read<AuthStore>().token;
    if (token == null) return;

    try {
      final headers = {'Authorization': 'Bearer $token'};
      
      // 1. Sempre busca os locais (necessário para origem ou destino)
      final resLocais = await http.get(Uri.parse('$apiBaseUrl/locais'), headers: headers);
      final locaisData = jsonDecode(utf8.decode(resLocais.bodyBytes))['data'] as List;

      // 2. Busca de Itens (Depende do que estamos movendo e da operação)
      dynamic itemsData = [];
      
      if (widget.isInstrumento) {
        // --- LÓGICA DE INSTRUMENTOS ---
        if (_isRetirada) {
          // Retirada: Busca no Catálogo (apenas ativos e disponíveis)
          // Usamos ?ativo=true e ?status=disponivel (implícito na lógica do backend admin ou filtrado aqui)
          // NOTA: O endpoint admin retorna tudo. Filtramos aqui se necessário.
          final resInst = await http.get(Uri.parse('$apiBaseUrl/instrumentos'), headers: headers);
          final allInst = jsonDecode(utf8.decode(resInst.bodyBytes)) as List;
          
          // Filtra apenas os disponíveis
          itemsData = allInst
              .where((i) => i['status'] == 'disponivel' && i['ativo'] == true)
              .map((j) => InstrumentoMovimentacao.fromMap(j))
              .toList();
        } else {
          // Devolução: Busca nas Pendências do Usuário
          final resPend = await http.get(Uri.parse('$apiBaseUrl/movimentacoes/pendentes'), headers: headers);
          final allPendencias = jsonDecode(utf8.decode(resPend.bodyBytes)) as List;
          
          // Filtra apenas instrumentos (inst-)
          itemsData = allPendencias
              .where((item) => (item['idMovimentacao'] as String).startsWith('inst-'))
              .map((j) => InstrumentoMovimentacao.fromMap(j)) // Usa o mapper
              .toList();
        }
      } else {
        // --- LÓGICA DE MATERIAIS ---
        if (_isRetirada) {
          // Retirada: Catálogo de Materiais
          final resMat = await http.get(Uri.parse('$apiBaseUrl/materiais?limit=100&ativo=true'), headers: headers);
          itemsData = jsonDecode(utf8.decode(resMat.bodyBytes))['data'];
        } else {
          // Devolução: Pendências de Materiais
          final resPend = await http.get(Uri.parse('$apiBaseUrl/movimentacoes/pendentes'), headers: headers);
          itemsData = jsonDecode(utf8.decode(resPend.bodyBytes))
              .where((item) => (item['idMovimentacao'] as String).startsWith('mat-'))
              .toList();
        }
      }

      if (mounted) {
        setState(() {
          _locais = locaisData.map((j) => LocalFisico.fromJson(j)).toList();
          _items = itemsData;
          _isLoadingData = false;
          
          // Pré-seleções inteligentes
          if (_locais.isNotEmpty) {
             _selectedLocal = _locais.first;
          }
          
          if (_items.isNotEmpty) {
             _selectedItem = _items.first;
             
             // Se for Material e Devolução, preenche a quantidade pendente
             if (!widget.isInstrumento && !_isRetirada) {
               _qtController.text = (_selectedItem['quantidade_pendente'] ?? 1).toString();
             } 
             // Se for Instrumento e Devolução, quantidade é sempre 1
             else if (widget.isInstrumento) {
               _qtController.text = "1";
             }
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Erro ao carregar dados: $e');
    }
  }

  // --- Lógica de Submissão ---
  Future<void> _submit() async {
    setState(() { _isLoading = true; _error = null; });

    final token = context.read<AuthStore>().token;
    final double? qtd = double.tryParse(_qtController.text);

    if (qtd == null || qtd <= 0) {
       setState(() { _error = 'Quantidade inválida'; _isLoading = false; });
       return;
    }
    if (_selectedItem == null) {
       setState(() { _error = 'Nenhum item selecionado'; _isLoading = false; });
       return;
    }
    if (_selectedLocal == null) {
       setState(() { _error = 'Local é obrigatório'; _isLoading = false; });
       return;
    }

    try {
      final headers = { 'Content-Type': 'application/json', 'Authorization': 'Bearer $token' };
      http.Response response;

      // Corpo base da requisição
      final Map<String, dynamic> bodyData = {
        'quantidade': qtd,
      };

      // Lógica Específica por Tipo
      if (widget.isInstrumento) {
        final inst = _selectedItem as InstrumentoMovimentacao;
        
        if (_isRetirada) {
          // RETIRADA INSTRUMENTO: ID, Local (Origem), Previsão
          bodyData['instrumento_id'] = int.tryParse(inst.id); // ID numérico do DB
          bodyData['local_id'] = _selectedLocal!.id; // Origem obrigatória
          bodyData['previsao_devolucao'] = DateTime.now().add(const Duration(days: 30)).toIso8601String(); // Default
          
          response = await http.post(Uri.parse('$apiBaseUrl/movimentacoes/saida'), headers: headers, body: jsonEncode(bodyData));
        } else {
          // DEVOLUÇÃO INSTRUMENTO: ID Movimentação, Local (Destino)
          bodyData['idMovimentacao'] = inst.idMovimentacao; // Ex: 'inst-23'
          bodyData['destino_local_id'] = _selectedLocal!.id; // Destino obrigatório
          
          response = await http.post(Uri.parse('$apiBaseUrl/movimentacoes/devolucao'), headers: headers, body: jsonEncode(bodyData));
        }
      } else {
        // Lógica de Materiais
        if (_isRetirada) {
          // RETIRADA MATERIAL
          bodyData['material_id'] = _selectedItem['id'];
          bodyData['local_id'] = _selectedLocal!.id;
          bodyData['lote'] = null; // Admin não seleciona lote por padrão
          bodyData['previsao_devolucao'] = DateTime.now().add(const Duration(days: 7)).toIso8601String();
          
          response = await http.post(Uri.parse('$apiBaseUrl/movimentacoes/saida'), headers: headers, body: jsonEncode(bodyData));
        } else {
          // DEVOLUÇÃO MATERIAL
          bodyData['idMovimentacao'] = _selectedItem['idMovimentacao'];
          bodyData['destino_local_id'] = _selectedLocal!.id;
          bodyData['lote'] = _selectedItem['lote'];
          
          response = await http.post(Uri.parse('$apiBaseUrl/movimentacoes/devolucao'), headers: headers, body: jsonEncode(bodyData));
        }
      }

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_isRetirada ? 'Retirada realizada com sucesso!' : 'Devolução realizada com sucesso!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        final errData = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() {
          _error = errData['error'] ?? 'Falha na operação (Erro ${response.statusCode})';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = 'Erro de conexão: $e'; _isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Cores do tema Admin
    const primaryColor = Color(0xFF080023);
    const secondaryColor = Color.fromARGB(255, 30, 24, 53);
    
    final String titulo = widget.isInstrumento ? 'Instrumento' : 'Material';

    return AlertDialog(
      backgroundColor: primaryColor,
      title: Row(
        children: [
          Icon(_isRetirada ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.white),
          const SizedBox(width: 12),
          Text(
            _isRetirada ? 'Retirar $titulo' : 'Devolver $titulo',
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ],
      ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // --- Toggle de Operação ---
              Container(
                decoration: BoxDecoration(
                  color: secondaryColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () { setState(() { _isRetirada = true; }); _fetchInitialData(); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _isRetirada ? Colors.blue.shade700 : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(left: Radius.circular(7)),
                          ),
                          child: const Center(child: Text("Retirar", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () { setState(() { _isRetirada = false; }); _fetchInitialData(); },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: !_isRetirada ? Colors.green.shade700 : Colors.transparent,
                            borderRadius: const BorderRadius.horizontal(right: Radius.circular(7)),
                          ),
                          child: const Center(child: Text("Devolver", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              if (_isLoadingData)
                const Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(color: Colors.white),
                )
              else ...[
                // 1. SELETOR DE ITEM
                if (_items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      _isRetirada 
                        ? "Nenhum $titulo disponível para retirada." 
                        : "Você não possui $titulo pendente para devolver.", 
                      style: const TextStyle(color: Colors.orange),
                      textAlign: TextAlign.center,
                    ),
                  )
                else
                  DropdownButtonFormField<dynamic>(
                    value: _selectedItem,
                    isExpanded: true,
                    dropdownColor: secondaryColor,
                    decoration: _inputDecoration('Selecione o $titulo'),
                    items: _items.map((item) {
                      String label;
                      // Lógica de exibição do Dropdown
                      if (widget.isInstrumento) {
                        final inst = item as InstrumentoMovimentacao;
                        label = "${inst.nome} - ${inst.patrimonio}";
                        if (_isRetirada && inst.localNome != null) {
                           label += " (${inst.localNome})";
                        }
                      } else {
                        // Material
                        final nome = _isRetirada ? item['descricao'] : item['nomeMaterial'];
                        final codigo = _isRetirada ? "MAT${item['cod_sap']}" : item['idMaterial'];
                        label = "$nome - $codigo";
                        if (!_isRetirada) label += " (Pend: ${item['quantidade_pendente']})";
                      }
                      
                      return DropdownMenuItem(
                        value: item,
                        child: Text(label, 
                          style: const TextStyle(color: Colors.white),
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedItem = val;
                        // Atualiza quantidade automaticamente para devolução
                        if (!widget.isInstrumento && !_isRetirada) {
                           _qtController.text = val['quantidade_pendente'].toString();
                        }
                      });
                    },
                  ),
                const SizedBox(height: 16),

                // 2. SELETOR DE LOCAL
                DropdownButtonFormField<LocalFisico>(
                  value: _selectedLocal,
                  isExpanded: true,
                  dropdownColor: secondaryColor,
                  decoration: _inputDecoration(
                    _isRetirada 
                      ? 'Local de Origem (Onde está?)' 
                      : 'Local de Destino (Onde guardar?)'
                  ),
                  items: _locais.map((l) {
                    return DropdownMenuItem(
                      value: l,
                      child: Text(l.nome, style: const TextStyle(color: Colors.white)),
                    );
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedLocal = val),
                ),
                const SizedBox(height: 16),

                // 3. QUANTIDADE (Desabilitado para instrumentos)
                TextField(
                  controller: _qtController,
                  enabled: !widget.isInstrumento, // Instrumento é sempre 1
                  style: TextStyle(color: widget.isInstrumento ? Colors.white54 : Colors.white),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: _inputDecoration('Quantidade'),
                ),
              ],

              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.redAccent), textAlign: TextAlign.center),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar', style: TextStyle(color: Colors.white70)),
        ),
        ElevatedButton(
          onPressed: (_isLoading || _isLoadingData || _items.isEmpty) ? null : _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: _isRetirada ? Colors.blue.shade700 : Colors.green.shade700,
            foregroundColor: Colors.white,
          ),
          child: _isLoading 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            : Text(_isRetirada ? 'Confirmar Retirada' : 'Confirmar Devolução'),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.white60),
      filled: true,
      fillColor: const Color.fromARGB(255, 30, 24, 53),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white30),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.white30),
      ),
    );
  }
}

class HoverableButton extends StatefulWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const HoverableButton({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  State<HoverableButton> createState() => _HoverableButtonState();
}

class _HoverableButtonState extends State<HoverableButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const cardColor = Color.fromARGB(209, 255, 255, 255);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          transform: Matrix4.identity()..scale(_isHovered ? 1.005 : 1.0),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (_isHovered)
                BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 15, spreadRadius: 2)
              else
                BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: widget.iconColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(widget.icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(widget.subtitle, style: const TextStyle(color: Colors.black87, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}