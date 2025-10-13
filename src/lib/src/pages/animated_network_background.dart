import 'dart:math';
import 'package:flutter/material.dart';

class Particle {
  Offset position;
  Offset velocity;
  final Color color;
  final double radius;

  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    this.radius = 2.0,
  });

  void update(Size bounds) {
    position += velocity;

    // Faz a partícula "quicar" nas bordas da tela
    if (position.dx < 0 || position.dx > bounds.width) {
      velocity = Offset(-velocity.dx, velocity.dy);
    }
    if (position.dy < 0 || position.dy > bounds.height) {
      velocity = Offset(velocity.dx, -velocity.dy);
    }
  }
}

class AnimatedNetworkBackground extends StatefulWidget {
  const AnimatedNetworkBackground({super.key});

  @override
  State<AnimatedNetworkBackground> createState() =>
      _AnimatedNetworkBackgroundState();
}

class _AnimatedNetworkBackgroundState extends State<AnimatedNetworkBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<Particle> _particles = [];
  final Random _random = Random();
  final int _numberOfParticles = 170;
  final double _maxDistance = 120.0;
  
  bool _particlesInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);

        // Criamos as partículas aqui
        if (!_particlesInitialized) {
          for (int i = 0; i < _numberOfParticles; i++) {
            _particles.add(
              Particle(
                position: Offset(
                  _random.nextDouble() * size.width,
                  _random.nextDouble() * size.height,
                ),
                velocity: Offset(
                  (_random.nextDouble() * 2 - 1) * 0.2,
                  (_random.nextDouble() * 2 - 1) * 0.2,
                ),
                color: Colors.white.withOpacity(0.7),
              ),
            );
          }
          _particlesInitialized = true;
        }

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            for (var particle in _particles) {
              particle.update(size);
            }
            return CustomPaint(
              painter: _NetworkPainter(
                particles: _particles,
                maxDistance: _maxDistance,
              ),
              child: const SizedBox.expand(),
            );
          },
        );
      },
    );
  }
}

class _NetworkPainter extends CustomPainter {
  final List<Particle> particles;
  final double maxDistance;

  _NetworkPainter({required this.particles, required this.maxDistance});

  @override
  void paint(Canvas canvas, Size size) {
    final dotPaint = Paint()..style = PaintingStyle.fill;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.5;

    for (int i = 0; i < particles.length; i++) {
      final p1 = particles[i];
      // Desenha o ponto
      canvas.drawCircle(p1.position, p1.radius, dotPaint..color = p1.color);

      // Desenha as linhas para outros pontos próximos
      for (int j = i + 1; j < particles.length; j++) {
        final p2 = particles[j];
        final distance = (p1.position - p2.position).distance;

        if (distance < maxDistance) {
          final opacity = 1.0 - (distance / maxDistance);
          linePaint.color = Colors.white.withOpacity(opacity * 0.5);
          canvas.drawLine(p1.position, p2.position, linePaint);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Repinta a cada frame para a animação funcionar
  }
}
