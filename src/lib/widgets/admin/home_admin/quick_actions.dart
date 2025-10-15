import 'package:flutter/material.dart';

class QuickActions extends StatelessWidget {
  const QuickActions({super.key});

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
              // chamada do widget do botão
              HoverableButton(
                icon: Icons.add,
                iconColor: Colors.blue.shade700,
                title: 'Nova Movimentação',
                subtitle: 'Registrar entrada/saída',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              HoverableButton(
                icon: Icons.handyman_outlined,
                iconColor: Colors.green.shade600,
                title: 'Retirar Instrumento',
                subtitle: 'Controle de Instrumentos',
                onTap: () {},
              ),
              const SizedBox(height: 12),
              HoverableButton(
                icon: Icons.download_outlined,
                iconColor: Colors.purple.shade600,
                title: 'Relatório Rápido',
                subtitle: 'Gerar Relatório',
                onTap: () {},
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Widget do botão que reage ao hover com animações
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
  // Variável para controlar se o mouse está no botão
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    const cardColor = Color.fromARGB(209, 255, 255, 255);

    // O MouseRegion detecta a entrada e saída do cursor do mouse
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
          transformAlignment: FractionalOffset.center,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              if (_isHovered)
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 15,
                  spreadRadius: 2,
                )
              else
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
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
                    Text(
                      widget.title,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
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
