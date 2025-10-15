// Modelo do card de status:
import 'package:flutter/material.dart';

class DashboardCard extends StatelessWidget {
  final bool isDesktop;
  final String title;
  final String value;
  final IconData icon;
  final Color iconBackgroundColor;

  const DashboardCard({
    super.key,
    required this.isDesktop,
    required this.title,
    required this.value,
    required this.icon,
    required this.iconBackgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final titleFontSize = isDesktop ? 20.0 : 16.0;
    final valueFontSize = isDesktop ? 32.0 : 28.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        // CORRIGIDO: Voltando para a cor clara que você escolheu
        color: const Color.fromARGB(209, 255, 255, 255),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  // CORRIGIDO: Texto escuro para contrastar com o fundo claro
                  color: const Color.fromARGB(255, 32, 32, 32),
                  fontWeight: FontWeight.bold,
                  fontSize: titleFontSize,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(
                  // CORRIGIDO: Texto escuro
                  color: const Color.fromARGB(255, 32, 32, 32),
                  fontWeight: FontWeight.bold,
                  fontSize: valueFontSize,
                ),
              ),
            ],
          ),
          Positioned(
            top: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBackgroundColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ],
      ),
    );
  }
}