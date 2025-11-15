import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Necessário para SocketException

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';

// (NOTA: O seu modelo _Atividade já estava 99% correto,
// só adicionei 'idMovimentacao' para o futuro botão de "Devolver")
class _Atividade {
  final String idMovimentacao; // Ex: 'inst-123' ou 'mat-456'
  final String nomeMaterial;
  final String idMaterial; // Ex: 'INST001' ou 'MAT12345'
  final bool status;
  final String localizacao;
  final DateTime dataRetirada;
  final DateTime dataDevolucao;

  _Atividade({
    required this.idMovimentacao,
    required this.nomeMaterial,
    required this.idMaterial,
    required this.status,
    required this.localizacao,
    required this.dataRetirada,
    required this.dataDevolucao,
  });

  bool get isAtrasado => dataDevolucao.isBefore(DateTime.now());
  // Identifica se é instrumento (não começa com 'MAT')
  bool get isInstrumento => !idMaterial.startsWith('MAT');

  factory _Atividade.fromJson(Map<String, dynamic> json) {
    // Helper para parsear datas de forma segura
    DateTime _tryParseDate(String? dateString) {
      if (dateString == null) return DateTime.now(); // Fallback
      return DateTime.tryParse(dateString) ?? DateTime.now(); // Fallback
    }

    return _Atividade(
      // Adicionado:
      idMovimentacao: json['idMovimentacao']?.toString() ?? 'N/A',
      // Seus campos:
      nomeMaterial: json['nomeMaterial']?.toString() ?? 'Item desconhecido',
      idMaterial: json['idMaterial']?.toString() ?? 'N/A',
      status: json['status'] == true, // O SQL sempre manda 'true'
      localizacao: json['localizacao']?.toString() ?? 'Base 01',
      dataRetirada: _tryParseDate(json['dataRetirada']),
      dataDevolucao: _tryParseDate(json['dataDevolucao']),
    );
  }
}

class AtividadesRecentes extends StatefulWidget {
  final ScrollController scrollController;
  final bool isDesktop;

  const AtividadesRecentes({
    super.key,
    required this.scrollController,
    required this.isDesktop,
  });

  @override
  State<AtividadesRecentes> createState() => _AtividadesRecentesState();
}

class _AtividadesRecentesState extends State<AtividadesRecentes> {
  // O seu _apiHost estava faltando, adicionei
  static const String _apiHost = 'http://localhost:8080';

  Future<List<_Atividade>>? _future;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _carregar();
    });
  }

  // A sua função _carregar já estava correta
  void _carregar() {
    final auth = context.read<AuthStore>();
    final token = auth.token;

    if (token == null || !auth.isAuthenticated) {
      setState(() {
        _future = Future.error(
          'Token ausente (faça login novamente).',
        );
      });
      return;
    }

    setState(() {
      _future = _fetchRecent(token);
    });
  }

  // ==========================================================
  // ============= ATUALIZAÇÃO PRINCIPAL AQUI =================
  // ==========================================================
  Future<List<_Atividade>> _fetchRecent(String token) async {
    // 1. Define a URL e os Headers
    final uri = Uri.parse('$_apiHost/movimentacoes/pendentes');
    final headers = {
      'Authorization': 'Bearer $token',
    };

    try {
      // 2. Faz a chamada GET
      final response = await http.get(uri, headers: headers)
          .timeout(const Duration(seconds: 5));

      if (!mounted) return [];

      // 3. Processa a resposta
      if (response.statusCode == 200) {
        // Usa utf8.decode para evitar problemas com acentuação
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        
        // 4. Converte o JSON para a lista de Atividades
        return data.map((json) => _Atividade.fromJson(json)).toList();
      } else {
        // Erro do servidor
        throw Exception('Falha ao carregar pendências: ${response.statusCode}');
      }
    } on TimeoutException {
      throw Exception('Servidor não respondeu (Timeout).');
    } on SocketException {
      throw Exception('Não foi possível conectar ao servidor.');
    } catch (e) {
      // Re-joga o erro para o FutureBuilder pegar
      throw Exception('Erro: ${e.toString().replaceAll("Exception: ", "")}');
    }
  }
  // ==========================================================
  // =================== FIM DA ATUALIZAÇÃO =====================
  // ==========================================================

  void _handleDevolucao(_Atividade item) {
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
          atividade: item,
          token: token,
          onSuccess: _onDevolucaoSuccess,
        ),
      );
    } else {
      showDialog(
        context: context,
        builder: (_) => _ModalDevolverMaterial(
          atividade: item,
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
    // Recarrega a lista para remover o item devolvido
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.schedule_outlined, color: Colors.white),
            SizedBox(width: 8),
            Text(
              'Minhas atividades',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: const Color.fromARGB(209, 255, 255, 255),
            borderRadius: BorderRadius.circular(16),
          ),
          child: FutureBuilder<List<_Atividade>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting ||
                  _future == null) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                );
              }

              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'Erro ao carregar atividades: ${snapshot.error}',
                      style: const TextStyle(color: Colors.redAccent),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final atividades = snapshot.data ?? [];

              if (atividades.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.check_circle_outline, // Ícone de "tudo certo"
                          color: Colors.green.shade300,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        "Tudo em ordem!",
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 18,
                          fontWeight: FontWeight.bold
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Você não possui instrumentos ou materiais pendentes.",
                        style: TextStyle(
                          color: Colors.blueGrey,
                          fontSize: 15,
                        ),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.visible,
                      ),
                    ],
                  ),
                );
              }
              return ListView.separated(
                controller: widget.scrollController,
                padding: const EdgeInsets.all(12),
                itemCount: atividades.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _AtividadeCard(atividade:  atividades[index], onDevolver: _handleDevolucao);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AtividadeCard extends StatelessWidget {
  final _Atividade atividade;
  final void Function(_Atividade item) onDevolver; // <--- NOVO CALLBACK

  const _AtividadeCard({
    required this.atividade,
    required this.onDevolver, // <--- NOVO
  });

  String _formatarData(DateTime data) {
    final localData = data.toLocal();
    return DateFormat('dd/MM/yyyy \'às\' HH:mm').format(localData);
  }

  @override
  Widget build(BuildContext context) {
    // ... (Lógica de cores e texto) ...
    final bool isAtrasado = atividade.isAtrasado;
    final bool isInstrumento = atividade.isInstrumento;
    final String buttonText =
        isInstrumento ? 'Devolver Instrumento' : 'Devolver Material';
    
    // Define a cor do card (vermelho se atrasado)
    final Color cardColor = isAtrasado
        ? Colors.red.withOpacity(0.08)
        : Colors.white.withOpacity(0.1);
    
    // Define a cor da borda (vermelha se atrasado)
    final Color borderColor = isAtrasado
        ? Colors.red.shade400.withOpacity(0.7)
        : Colors.transparent;
        
    // Define a cor do texto de devolução (vermelho se atrasado)
    final Color devolucaoColor = isAtrasado
        ? Colors.red.shade300
        : Colors.white70;


    return Container(
      // ... (Estilo do Container) ...
       padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5), // Borda
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ... (Conteúdo do Card - Linhas 1 a 4) ...
           Row(
            children: [
              Text(
                atividade.nomeMaterial,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              // ... (Tags de ID e Atrasado) ...
               _TagChip(
                label: atividade.idMaterial,
                backgroundColor: Colors.white.withOpacity(0.2),
                textColor: Colors.white,
              ),
              const Spacer(),
              if (isAtrasado)
                const _TagChip(
                  label: "Atrasado",
                  backgroundColor: Color(0xFFFEE2E2), // Fundo do chip "Atrasado"
                  textColor: Color(0xFFB91C1C), // Texto do chip "Atrasado"
                ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoLinha(
            icon: Icons.location_on_outlined,
            title: "Local:", 
            value: atividade.localizacao,
            valueColor: Colors.white, 
          ),
          const SizedBox(height: 8),
          _InfoLinha(
            icon: Icons.calendar_today_outlined,
            title: "Retirado em:",
            value: _formatarData(atividade.dataRetirada),
          ),
          const SizedBox(height: 8),
          _InfoLinha(
            icon: Icons.schedule,
            title: "Previsão de devolução:",
            value: _formatarData(atividade.dataDevolucao),
            iconColor: devolucaoColor,
            valueColor: devolucaoColor, 
          ),
          const SizedBox(height: 16),
          // --- Linha 5: Botão Devolver (Corrigido) ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onDevolver(atividade), // <--- CHAMANDO O CALLBACK
              icon: const Icon(Icons.arrow_downward, size: 16),
              label: Text(buttonText),
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

// --- WIDGET HELPER PARA AS TAGS (MAT001, Atrasado) ---
class _TagChip extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _TagChip({
    required this.label,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.bold,
          fontSize: 11,
        ),
      ),
    );
  }
}

// --- WIDGET HELPER PARA AS LINHAS DE INFO (Icon + Título + Valor) ---
class _InfoLinha extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color? iconColor;
  final Color? valueColor;

  const _InfoLinha({
    required this.icon,
    required this.title,
    required this.value,
    this.iconColor,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    const Color defaultColor = Colors.white70; // Cor padrão
    
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor ?? defaultColor, size: 16),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(color: defaultColor),
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? defaultColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

// ===================================================================
// ==================== NOVOS MODALS (PARA DEVOLUÇÃO) ================
// ===================================================================
// NOTE: Esses modals são simplificados para fins de demonstração
// e assumem que o local de destino do instrumento será NULO no banco.

// --- MODAL DEVOLVER INSTRUMENTO (Ação Direta) ---
class _ModalDevolverInstrumento extends StatefulWidget {
  final _Atividade atividade;
  final String token;
  final VoidCallback onSuccess;

  const _ModalDevolverInstrumento({
    required this.atividade,
    required this.token,
    required this.onSuccess,
  });

  @override
  State<_ModalDevolverInstrumento> createState() =>
      _ModalDevolverInstrumentoState();
}

class _ModalDevolverInstrumentoState extends State<_ModalDevolverInstrumento> {
  static const String _apiHost = 'http://localhost:8080';
  bool _isLoading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await http.post(
        Uri.parse('$_apiHost/movimentacoes/devolucao'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.token}',
        },
        // Envia o ID composto (inst-ID)
        body: json.encode({'idMovimentacao': widget.atividade.idMovimentacao}),
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
      content: Text(
        'Você confirma a devolução do instrumento ${widget.atividade.nomeMaterial} (${widget.atividade.idMaterial})?',
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Devolver'),
        ),
      ],
    );
  }
}

// --- MODAL DEVOLVER MATERIAL (Requer Quantidade e Local de Destino) ---
class _ModalDevolverMaterial extends StatefulWidget {
  final _Atividade atividade;
  final String token;
  final VoidCallback onSuccess;

  const _ModalDevolverMaterial({
    required this.atividade,
    required this.token,
    required this.onSuccess,
  });

  @override
  State<_ModalDevolverMaterial> createState() => _ModalDevolverMaterialState();
}

class _ModalDevolverMaterialState extends State<_ModalDevolverMaterial> {
  static const String _apiHost = 'http://localhost:8080';
  bool _isLoading = false;
  String? _error;
  
  // Dados de formulário (Mocked: A devolução de material precisa de um dropdown de locais)
  final TextEditingController _qtController = TextEditingController(text: '1');
  int? _destinoLocalId = 1; // MOCK: Local 1 (deve vir de um Dropdown/API)


  Future<void> _submit() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final double? quantidade = double.tryParse(_qtController.text);
    
    if (quantidade == null || quantidade <= 0) {
      setState(() { _error = 'Quantidade inválida.'; _isLoading = false; });
      return;
    }
    if (_destinoLocalId == null) {
      setState(() { _error = 'Selecione o local de destino.'; _isLoading = false; });
      return;
    }

    try {
      final body = json.encode({
        'idMovimentacao': widget.atividade.idMovimentacao,
        'quantidade': quantidade,
        'destino_local_id': _destinoLocalId,
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
          _error = errorData['error'] ?? 'Falha ao devolver o material.';
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
      title: Text('Devolver ${widget.atividade.nomeMaterial}'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Informe a quantidade e o local de destino:'),
            const SizedBox(height: 16),
            TextField(
              controller: _qtController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantidade a devolver',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            // NOTE: Na vida real, este seria um Dropdown populado por API
            Text('Local de Destino (MOCK): Base ID $_destinoLocalId'), 
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
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}