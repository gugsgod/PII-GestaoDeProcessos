// Lista de movimentações:
import 'package:flutter/material.dart';
import '../../../pages/home_admin.dart'; // Importa a classe Movimentacao

class RecentMovements extends StatelessWidget {
  final List<Movimentacao> movimentacoes;
  final ScrollController scrollController;

  const RecentMovements({
    super.key,
    required this.movimentacoes,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.sync_alt, color: Color(0xFF3B82F6), size: 28),
            SizedBox(width: 12),
            Text(
              'Movimentações recentes:',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Container(
          height: 400,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ScrollbarTheme(
            data: ScrollbarThemeData(
              thumbColor: MaterialStateProperty.all(
                Colors.white.withOpacity(0.3),
              ),
              mainAxisMargin: 16.0,
            ),
            child: Scrollbar(
              thumbVisibility: true,
              interactive: true,
              controller: scrollController,
              child: ListView.separated(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: movimentacoes.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = movimentacoes[index];
                  return _buildMovementItem(
                    isEntrada: item.type == 'entrada',
                    title: item.title,
                    tag: item.tag,
                    user: item.user,
                    time: item.time,
                    amount: item.amount,
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Métodos auxiliares:

  // widget auxiliar detalhado para cada item da lista
  Widget _buildMovementItem({
    required bool isEntrada,
    required String title,
    required String tag,
    required String user,
    required String time,
    required String amount,
  }) {
    final icon = isEntrada ? Icons.arrow_downward : Icons.arrow_upward;
    final iconColor = isEntrada ? Colors.green.shade700 : Colors.red.shade700;
    final statusText = isEntrada ? 'Entrada' : 'Saída';
    final statusBgColor = isEntrada
        ? const Color.fromARGB(255, 195, 236, 198)
        : const Color.fromARGB(255, 247, 200, 204);
    final statusTextColor = isEntrada
        ? Colors.green.shade800
        : Colors.red.shade800;
    final userIcon = user == 'admin'
        ? Icons.shield_outlined
        : Icons.engineering_outlined;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color.fromARGB(209, 255, 255, 255),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: iconColor.withOpacity(0.1),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _buildTag(
                      tag,
                      Colors.grey.shade200,
                      const Color.fromARGB(255, 44, 44, 44),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      userIcon,
                      size: 14,
                      color: const Color.fromARGB(255, 44, 44, 44),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '$user · $time',
                      style: TextStyle(
                        color: const Color.fromARGB(255, 44, 44, 44),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildTag(statusText, statusBgColor, statusTextColor),
              const SizedBox(height: 6),
              Text(
                amount,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, Color bgColor, Color textColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
