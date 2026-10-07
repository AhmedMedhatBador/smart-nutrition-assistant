import 'package:flutter/material.dart';

class BackgroundWidget extends StatelessWidget {
  final Widget child;
  final bool showShapes;

  const BackgroundWidget({
    super.key,
    required this.child,
    this.showShapes = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final circle1 = isDark ? const Color(0xFF0D9488) : const Color(0xFF0D9488);
    final circle2 = isDark ? const Color(0xFF1E293B) : const Color(0xFFE8D5B7);

    return Stack(
      children: [
        Container(color: bg),
        if (showShapes) ...[
          Positioned(
            top: -80, right: -80,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circle1.withOpacity(isDark ? 0.12 : 0.06),
              ),
            ),
          ),
          Positioned(
            top: -40, right: -40,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circle1.withOpacity(isDark ? 0.08 : 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circle2.withOpacity(isDark ? 0.15 : 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -50, left: -30,
            child: Container(
              width: 180, height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: circle1.withOpacity(isDark ? 0.08 : 0.04),
              ),
            ),
          ),
        ],
        child,
      ],
    );
  }
}