// Barra com a data e o botão

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class UpdateStatusBar extends StatelessWidget {
  final bool isDesktop;
  final DateTime lastUpdated;
  final VoidCallback onUpdate;

  const UpdateStatusBar({
    super.key,
    required this.isDesktop,
    required this.lastUpdated,
    required this.onUpdate,
  });

  String _formatDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy, HH:mm').format(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    return isDesktop ? _buildDesktopLayout() : _buildMobileLayout();
  }

  Widget _buildDesktopLayout() {
    return Row(
      children: [
        const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
        const SizedBox(width: 8),
        Text(
          'Atualizado em ${_formatDateTime(lastUpdated)}',
          style: const TextStyle(color: Colors.white70),
        ),
        const Spacer(),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade400.withOpacity(0.5),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          onPressed: onUpdate,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Atualizar página'),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today, color: Colors.white70, size: 16),
            const SizedBox(width: 8),
            Text(
              'Atualizado em ${_formatDateTime(lastUpdated)}',
              style: const TextStyle(color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo.shade400.withOpacity(0.5),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: onUpdate,
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Atualizar página'),
          ),
        ),
      ],
    );
  }
}