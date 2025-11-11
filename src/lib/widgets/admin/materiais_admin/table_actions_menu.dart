import 'package:flutter/material.dart';

/// Um menu de ações padrão para linhas de tabela, com opções de Editar e Remover.
class TableActionsMenu extends StatelessWidget {
  final VoidCallback onEditPressed;
  final VoidCallback onRemovePressed;

  const TableActionsMenu({
    super.key,
    required this.onEditPressed,
    required this.onRemovePressed,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'edit') {
          onEditPressed();
        } else if (value == 'remove') {
          onRemovePressed();
        }
      },
      icon: const Icon(Icons.more_horiz, color: Colors.black54),
      tooltip: 'Mais ações',
      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
        // Opção Editar
        PopupMenuItem<String>(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, color: Colors.blue.shade800, size: 20),
              const SizedBox(width: 12),
              const Text('Editar'),
            ],
          ),
        ),
        // Opção Remover
        PopupMenuItem<String>(
          value: 'remove',
          child: Row(
            children: [
              Icon(Icons.delete_outline, color: Colors.red.shade800, size: 20),
              const SizedBox(width: 12),
              Text(
                'Remover',
                style: TextStyle(color: Colors.red.shade800),
              ),
            ],
          ),
        ),
      ],
    );
  }
}