import 'dart:async';
import 'dart:convert';
import 'dart:io'; // Necessário para SocketException

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:src/auth/auth_store.dart';

// NOVO MODELO PARA LOCAIS (Para o Dropdown)
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

// ... (Restante do arquivo)

// (NOTA: O seu modelo _Atividade já estava 99% correto,
// só adicionei 'idMovimentacao' para o futuro botão de "Devolver")
class Atividade {
  final String idMovimentacao; 
  final String nomeMaterial;
  final String idMaterial; 
  final String? lote; 
  final double quantidadePendente;
  final String localizacao;
  final DateTime dataRetirada;
  final DateTime dataDevolucao;

  Atividade({
    required this.idMovimentacao,
    required this.nomeMaterial,
    required this.idMaterial,
    this.lote,
    required this.quantidadePendente,
    required this.localizacao,
    required this.dataRetirada,
    required this.dataDevolucao,
  });

  bool get isAtrasado => dataDevolucao.isBefore(DateTime.now());
  bool get isInstrumento => !idMaterial.startsWith('MAT');

  factory Atividade.fromJson(Map<String, dynamic> json) {
    DateTime _tryParseDate(String? dateString) {
      if (dateString == null) return DateTime.now();
      return DateTime.tryParse(dateString) ?? DateTime.now();
    }

    return Atividade(
      idMovimentacao: json['idMovimentacao']?.toString() ?? 'N/A',
      nomeMaterial: json['nomeMaterial']?.toString() ?? 'Item desconhecido',
      idMaterial: json['idMaterial']?.toString() ?? 'N/A',
      lote: json['lote'] as String?, // <-- MAPEAMENTO ADICIONADO
      // Garante que a quantidade seja lida como double
      quantidadePendente: (json['quantidade_pendente'] as num?)?.toDouble() ?? 0.0,
      localizacao: json['localizacao']?.toString() ?? 'Base 01',
      dataRetirada: _tryParseDate(json['dataRetirada']),
      dataDevolucao: _tryParseDate(json['dataDevolucao']),
    );
  }
}

class AtividadesRecentes extends StatefulWidget {
  final ScrollController scrollController;
  final bool isDesktop;
  
  // NOVOS PARÂMETROS
  final bool isLoading;
  final String? error;
  final List<Atividade> atividades;
  final VoidCallback onReload; // Função para recarregar

  const AtividadesRecentes({
    super.key,
    required this.scrollController,
    required this.isDesktop,
    // NOVOS
    required this.isLoading,
    this.error,
    required this.atividades,
    required this.onReload,
  });

  @override
  State<AtividadesRecentes> createState() => _AtividadesRecentesState();
}

class _AtividadesRecentesState extends State<AtividadesRecentes> {
  // O seu _apiHost estava faltando, adicionei
  void _onDevolucaoSuccess() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Devolução registrada com sucesso!'),
        backgroundColor: Colors.green,
      ),
    );
    // Chama a função de recarregar do PAI
    widget.onReload();
  }
  
  void _handleDevolucao(Atividade item) {
    final auth = context.read<AuthStore>();
    final token = auth.token;
    if (token == null) return;

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
          child: _buildContent(),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (widget.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }

    // 2. ERRO (UI MELHORADA - IGUAL ALERTAS)
    if (widget.error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline, 
                color: Colors.redAccent, 
                size: 48
              ),
              const SizedBox(height: 16),
              Text(
                widget.error!.replaceAll("Exception: ", ""), // Limpa a msg
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.redAccent, 
                  fontSize: 16,
                  fontWeight: FontWeight.w500
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: widget.onReload, // Botão de Tentar Novamente
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white
                ),
                child: const Text("Tentar Novamente"),
              )
            ],
          ),
        ),
      );
    }

    final atividades = widget.atividades;

    // 3. LISTA VAZIA
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
              child: Icon(Icons.check_circle_outline, color: Colors.green.shade300, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              "Tudo em ordem!",
              style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Você não possui instrumentos ou materiais pendentes.",
              style: TextStyle(color: Colors.blueGrey, fontSize: 15),
              textAlign: TextAlign.center,
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
        return _AtividadeCard(
          atividade: atividades[index], 
          onDevolver: _handleDevolucao // Passa o handler de devolução
        );
      },
    );
  }
}

class _AtividadeCard extends StatelessWidget {
  final Atividade atividade;
  final void Function(Atividade item) onDevolver;

  const _AtividadeCard({
    required this.atividade,
    required this.onDevolver,
  });

  String _formatarData(DateTime data) {
    // Correção de fuso horário
    final localData = data.toLocal(); 
    return DateFormat('dd/MM/yyyy \'às\' HH:mm').format(localData);
  }

  @override
  Widget build(BuildContext context) {
    // ... (Lógica de cores, isAtrasado, etc.) ...
    final bool isAtrasado = atividade.isAtrasado;
    final bool isInstrumento = atividade.isInstrumento;
    final String buttonText =
        isInstrumento ? 'Devolver Instrumento' : 'Devolver Material';
    
    // Define a cor do card (vermelho se atrasado)
    final Color cardColor = isAtrasado
        ? const Color(0xFFFFF1F2) // Um vermelho bem claro (Tailwind red-50)
        : Colors.white; // Branco sólido
    
    // Define a cor da borda (vermelha se atrasado)
    final Color borderColor = isAtrasado
        ? Colors.red.shade400.withOpacity(0.7)
        : Colors.transparent;
        
    // Define a cor do texto de devolução (vermelho se atrasado)
    final Color devolucaoColor = isAtrasado
        ? Colors.red.shade600 // Vermelho mais escuro para texto
        : Colors.black54;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: 1.5), // Borda
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Linha 1: Título e Tags ---
          Row(
            children: [
              Text(
                atividade.nomeMaterial,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              _TagChip(
                label: atividade.idMaterial,
                backgroundColor: Colors.black.withOpacity(0.1),
                textColor: Colors.black,
              ),
              // ADICIONADO: Tag de Lote (se existir)
              if (atividade.lote != null && atividade.lote!.isNotEmpty) ...[
                const SizedBox(width: 4),
                _TagChip(
                  label: "Lote: ${atividade.lote!}",
                  backgroundColor: Colors.teal.withOpacity(0.2),
                  textColor: Colors.teal.shade100,
                ),
              ],
              const Spacer(),
              if (isAtrasado)
                const _TagChip(
                  label: "Atrasado",
                  backgroundColor: Color(0xFFFEE2E2),
                  textColor: Color(0xFFB91C1C),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // --- Linha 2: Quantidade Pendente (se não for instrumento) ---
          if (!isInstrumento)
            _InfoLinha(
              icon: Icons.inventory_2_outlined,
              title: "Pendente:",
              value: "${atividade.quantidadePendente} ${atividade.idMaterial}", // Ex: "10.0 PC"
              valueColor: Colors.black,
            ),
          if (!isInstrumento) const SizedBox(height: 8),
          
          // --- Linha 3: Localização ---
          _InfoLinha(
            icon: Icons.location_on_outlined,
            title: "Local:",
            value: atividade.localizacao,
            valueColor: Colors.black,
          ),
          const SizedBox(height: 8),
          // --- Linha 4: Retirado em ---
          _InfoLinha(
            icon: Icons.calendar_today_outlined,
            title: "Retirado em:",
            value: _formatarData(atividade.dataRetirada),
          ),
          const SizedBox(height: 8),
          // --- Linha 5: Previsão de Devolução ---
          _InfoLinha(
            icon: Icons.schedule,
            title: "Previsão de devolução:",
            value: _formatarData(atividade.dataDevolucao),
            iconColor: devolucaoColor,
            valueColor: devolucaoColor,
          ),
          const SizedBox(height: 16),
          // --- Linha 6: Botão Devolver ---
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => onDevolver(atividade),
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
    const Color defaultColor = Colors.black; // Cor padrão
    
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
  final Atividade atividade;
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
  bool _isLoadingLocais = true; // NOVO: Controle de loading de locais
  String? _error;
  
  // NOVOS ESTADOS PARA LOCAL
  LocalFisico? _selectedDestinoLocal;
  List<LocalFisico> _locais = [];

  @override
  void initState() {
    super.initState();
    _fetchLocais();
  }

  // MÉTODO COPIADO DO MODAL DE MATERIAL PARA BUSCAR LOCAIS
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
            if (_locais.isNotEmpty) {
              _selectedDestinoLocal = _locais.first; // Pré-seleciona o primeiro
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
        'idMovimentacao': widget.atividade.idMovimentacao,
        // NOVO CAMPO SENDO ENVIADO
        'destino_local_id': _selectedDestinoLocal!.id, 
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
            Text('Instrumento: ${widget.atividade.nomeMaterial} (${widget.atividade.idMaterial})'),
            const SizedBox(height: 16),
            
            if (_isLoadingLocais) 
              const Center(child: CircularProgressIndicator()) 
            else ...[
              // DROPDOWN DE LOCAL DE DESTINO
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
                hint: const Text('Selecione o local para guardar'),
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
          // Desabilitado se estiver carregando ou sem local selecionado
          onPressed: (_isLoading || _isLoadingLocais || _selectedDestinoLocal == null) ? null : _submit,
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
  final Atividade atividade;
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
  bool _isLoadingLocais = true;
  String? _error;
  
  final TextEditingController _qtController = TextEditingController(); // Inicia vazio
  LocalFisico? _selectedDestinoLocal;
  List<LocalFisico> _locais = [];
  
  @override
  void initState() {
    super.initState();
    // Inicia o campo com a quantidade total pendente
    _qtController.text = widget.atividade.quantidadePendente.toString();
    _fetchLocais();
  }

  Future<void> _fetchLocais() async {
    // ... (lógica de fetch locais continua a mesma) ...
    final uri = Uri.parse('$_apiHost/locais');
    final headers = {'Authorization': 'Bearer ${widget.token}'};

    try {
      final response = await http.get(uri, headers: headers);
      if (response.statusCode == 200) {
        final List<dynamic> jsonList = jsonDecode(response.body)['data'] as List<dynamic>;
        if (mounted) {
          setState(() {
            _locais = jsonList.map((j) => LocalFisico.fromJson(j as Map<String, dynamic>)).toList();
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
    setState(() { _isLoading = true; _error = null; });

    final double? quantidade = double.tryParse(_qtController.text);
    
    // Validação
    if (quantidade == null || quantidade <= 0) {
      setState(() { _error = 'Quantidade inválida.'; _isLoading = false; });
      return;
    }
    // Validação de saldo (Frontend)
    if (quantidade > widget.atividade.quantidadePendente) {
      setState(() { _error = 'Não pode devolver mais do que o pendente (${widget.atividade.quantidadePendente}).'; _isLoading = false; });
      return;
    }
    if (_selectedDestinoLocal == null) {
      setState(() { _error = 'Selecione o local de destino.'; _isLoading = false; });
      return;
    }

    try {
      // CORPO DO JSON ATUALIZADO
      final body = json.encode({
        'idMovimentacao': widget.atividade.idMovimentacao,
        'quantidade': quantidade,
        'destino_local_id': _selectedDestinoLocal!.id,
        'lote': widget.atividade.lote, // <-- ENVIA O LOTE (pode ser null)
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
            // Exibe o saldo pendente atual
            Text(
              'Pendente: ${widget.atividade.quantidadePendente} (Lote: ${widget.atividade.lote ?? "N/A"})',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            
            if (_isLoadingLocais) 
              const Center(child: CircularProgressIndicator()) 
            else ...[
              // ... (Campo de Quantidade) ...
              TextField(
                controller: _qtController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Quantidade a devolver',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              // ... (Dropdown de Local de Destino) ...
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
                hint: const Text('Selecione o local de destino'),
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
              : const Text('Confirmar'),
        ),
      ],
    );
  }
}