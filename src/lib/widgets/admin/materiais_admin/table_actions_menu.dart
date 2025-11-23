import 'package:flutter/material.dart';

/// Um menu de ações padrão para linhas de tabela.
/// Suporta Editar, Remover e opcionalmente Ajustar Estoque.
class TableActionsMenu extends StatelessWidget {
  final VoidCallback onEditPressed;
  final VoidCallback onRemovePressed;
  final VoidCallback? onAdjustStockPressed; // Novo parâmetro opcional

  const TableActionsMenu({
    super.key,
    required this.onEditPressed,
    required this.onRemovePressed,
    this.onAdjustStockPressed,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          onEditPressed();
        } else if (value == 'remove') {
          onRemovePressed();
        } else if (value == 'ajuste' && onAdjustStockPressed != null) {
          onAdjustStockPressed!();
        }
      },
      icon: const Icon(Icons.more_horiz, color: Colors.black54),
      tooltip: 'Mais ações',
      itemBuilder: (BuildContext context) {
        final List<PopupMenuEntry<String>> items = [];

        // 1. Opção Editar
        items.add(
          const PopupMenuItem<String>(
            value: 'edit',
            child: Row(
              children: [
                Icon(Icons.edit, color: Color(0xFF1565C0), size: 20), // Blue 800
                SizedBox(width: 12),
                Text('Editar'),
              ],
            ),
          ),
        );

        // 2. Opção Ajustar Estoque (Condicional)
        if (onAdjustStockPressed != null) {
          items.add(
            const PopupMenuItem<String>(
              value: 'ajuste',
              child: Row(
                children: [
                  Icon(Icons.inventory, color: Colors.orange, size: 20),
                  SizedBox(width: 12),
                  Text('Ajustar Estoque'),
                ],
              ),
            ),
          );
        }

        // 3. Opção Remover
        items.add(
          const PopupMenuItem<String>(
            value: 'remove',
            child: Row(
              children: [
                Icon(Icons.delete_outline, color: Color(0xFFC62828), size: 20), // Red 800
                SizedBox(width: 12),
                Text(
                  'Remover', // Na prática é Desativar
                  style: TextStyle(color: Color(0xFFC62828)),
                ),
              ],
            ),
          ),
        );

        return items;
      },
    );
  }
}