import 'package:flutter/material.dart';
import '../core/constants.dart';

class RetroBackground extends StatelessWidget {
  final Widget child;

  const RetroBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF), // White backdrop
      body: Stack(
        children: [
          // Monochromatic stipple hands image covering the entire background of the website
          Positioned.fill(
            child: Image.asset(
              'assets/images/robotic_human_hand.png',
              fit: BoxFit.cover,
              alignment: const Alignment(0.0, 0.7),
            ),
          ),

          // Stark light technical blueprint grid
          Positioned.fill(
            child: CustomPaint(
              painter: GridPatternPainter(
                gridColor: const Color(0x06000000), // Very subtle grid lines running lightly behind the canvas
                spacing: 32.0,
              ),
            ),
          ),

          // Main content layer
          Positioned.fill(
            child: child,
          ),
        ],
      ),
    );
  }
}

class GridPatternPainter extends CustomPainter {
  final Color gridColor;
  final double spacing;

  GridPatternPainter({required this.gridColor, this.spacing = 30.0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = gridColor
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Draw vertical lines
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
