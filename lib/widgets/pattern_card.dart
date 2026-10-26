import 'dart:math';
import 'package:flutter/material.dart';
import '../models/lamp_pattern.dart';

class PatternCard extends StatefulWidget {
  final LampPattern pattern;
  final bool isSelected;
  final bool isLampOn;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onToggle; // New: callback for on/off toggle
  final Widget? footer; // Optional footer content (e.g., warmth controller)

  const PatternCard({
    super.key,
    required this.pattern,
    this.isSelected = false,
    this.isLampOn = true,
    this.onTap,
    this.onLongPress,
    this.onToggle,
    this.footer,
  });

  @override
  State<PatternCard> createState() => _PatternCardState();
}

class _PatternCardState extends State<PatternCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAnimatedPreview =
        widget.pattern.id == 'night_reading' ||
        widget.pattern.id == 'yellow_night';

    // Special styling for Aurora Borealis pattern
    final isAurora = widget.pattern.id == 'aurora';

    return GestureDetector(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: widget.isSelected
              ? Border.all(
                  color: isAurora
                      ? Colors.purpleAccent
                      : Theme.of(context).primaryColor,
                  width: 3,
                )
              : (isAurora
                    ? Border.all(color: Colors.purple.withAlpha(100), width: 1)
                    : null),
          boxShadow: widget.isSelected
              ? [
                  BoxShadow(
                    color: isAurora
                        ? Colors.purpleAccent.withAlpha(100)
                        : Theme.of(context).primaryColor.withAlpha(51),
                    blurRadius: isAurora ? 16 : 12,
                    spreadRadius: isAurora ? 4 : 2,
                  ),
                ]
              : (isAurora
                    ? [
                        BoxShadow(
                          color: Colors.purple.withAlpha(40),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : null),
        ),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Pattern preview background (with optional animation overlay)
              Positioned.fill(
                child: isAnimatedPreview
                    ? AnimatedBuilder(
                        animation: _ctrl,
                        builder: (context, _) => Stack(
                          fit: StackFit.expand,
                          children: [
                            _buildPatternPreview(widget.pattern),
                            CustomPaint(
                              painter: _WavePainter(
                                phase: _ctrl.value * 2 * pi,
                                color: Colors.white.withOpacity(0.05),
                                amplitude: 8,
                                frequency: 1.6,
                              ),
                            ),
                            CustomPaint(
                              painter: _WavePainter(
                                phase: _ctrl.value * 2 * pi + 1.2,
                                color: Colors.white.withOpacity(0.03),
                                amplitude: 5,
                                frequency: 2.0,
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildPatternPreview(widget.pattern),
              ),

              // Overlay gradient
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withAlpha(179)],
                    ),
                  ),
                ),
              ),

              // Content
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          widget.pattern.icon,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            widget.pattern.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (widget.pattern.description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        widget.pattern.description,
                        style: TextStyle(
                          color: Colors.white.withAlpha(179),
                          fontSize: 10,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],

                    // Optional footer content (compact controls)
                    if (widget.footer != null) ...[
                      const SizedBox(height: 8),
                      widget.footer!,
                    ],
                  ],
                ),
              ),

              // On/Off Toggle Button (top-right)
              if (widget.onToggle != null)
                Positioned(
                  top: 6,
                  right: 6,
                  child: GestureDetector(
                    onTap: () {
                      // Prevent event bubbling to card tap
                      widget.onToggle?.call();
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: widget.isSelected
                            ? Colors.green.withAlpha(220)
                            : Colors.black.withAlpha(150),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.isSelected
                              ? Colors.greenAccent
                              : Colors.white.withAlpha(100),
                          width: 2,
                        ),
                        boxShadow: widget.isSelected
                            ? [
                                BoxShadow(
                                  color: Colors.greenAccent.withAlpha(100),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Icon(
                        widget.isSelected
                            ? Icons.power_settings_new
                            : Icons.power_off,
                        color: widget.isSelected
                            ? Colors.white
                            : Colors.white70,
                        size: 20,
                      ),
                    ),
                  ),
                ),

              // Selected checkmark (moved to top-left when toggle present)
              if (widget.isSelected && widget.onToggle == null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),

              // Navigation hint icon (bottom-right)
              if (widget.onTap != null && widget.onToggle != null)
                Positioned(
                  bottom: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.black.withAlpha(120),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Icon(
                      Icons.tune,
                      color: Colors.white70,
                      size: 14,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatternPreview(LampPattern pattern) {
    if (pattern.colors.isEmpty) {
      return Container(color: Colors.grey.shade800);
    }

    if (pattern.colors.length == 1) {
      return Container(color: pattern.colors.first);
    }

    // Multi-color gradient preview
    switch (pattern.id) {
      case 'rainbow':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.red,
                Colors.orange,
                Colors.yellow,
                Colors.green,
                Colors.blue,
                Colors.purple,
              ],
            ),
          ),
        );

      case 'fire':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color(0xFF8B2500), // deep ember / burgundy
                Color(0xFFD45500), // warm burnt orange
                Color(0xFFE8A317), // amber gold
                Color(0xFFFAD961), // soft warm gold
              ],
              stops: [0.0, 0.35, 0.7, 1.0],
            ),
          ),
        );

      case 'ocean':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.cyan, Colors.teal],
            ),
          ),
        );

      case 'forest':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.green, Colors.lightGreen, Colors.teal],
            ),
          ),
        );

      case 'sunset':
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFA630), // warm golden orange
                Color(0xFFFF6B6B), // coral / pink
                Color(0xFF9B3A86), // magenta
                Color(0xFF36183A), // deep purple / dusk
              ],
              stops: [0.0, 0.45, 0.75, 1.0],
            ),
          ),
        );

      case 'aurora':
        // Stunning Aurora Borealis preview with shimmer effect
        return AnimatedBuilder(
          animation: _ctrl,
          builder: (context, _) => Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(
                    const Color(0xFF004D40), // Deep teal
                    const Color(0xFF1A237E), // Deep indigo
                    (_ctrl.value + 0.2) % 1.0,
                  )!,
                  Color.lerp(
                    const Color(0xFF00695C), // Teal
                    const Color(0xFF4A148C), // Purple
                    (_ctrl.value + 0.5) % 1.0,
                  )!,
                  Color.lerp(
                    const Color(0xFF00BFA5), // Bright teal
                    const Color(0xFF7C4DFF), // Bright purple
                    _ctrl.value,
                  )!,
                  Color.lerp(
                    const Color(0xFF64FFDA), // Cyan accent
                    const Color(0xFFE040FB), // Pink accent
                    (_ctrl.value + 0.7) % 1.0,
                  )!,
                ],
                stops: const [0.0, 0.35, 0.65, 1.0],
              ),
            ),
            child: Stack(
              children: [
                // Shimmer overlay
                CustomPaint(
                  size: Size.infinite,
                  painter: _AuroraShimmerPainter(phase: _ctrl.value * 2 * pi),
                ),
              ],
            ),
          ),
        );

      default:
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: pattern.colors),
          ),
        );
    }
  }
}

class _WavePainter extends CustomPainter {
  final double phase;
  final Color color;
  final double amplitude;
  final double frequency;

  _WavePainter({
    required this.phase,
    required this.color,
    this.amplitude = 6.0,
    this.frequency = 1.2,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    final midY = size.height * 0.45;

    path.moveTo(0, size.height);
    path.lineTo(0, midY);

    for (double x = 0; x <= size.width; x += 6) {
      final norm = x / size.width;
      final y = midY + sin(norm * frequency * 2 * pi + phase) * amplitude;
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WavePainter oldDelegate) {
    return oldDelegate.phase != phase || oldDelegate.amplitude != amplitude;
  }
}

/// Custom painter for Aurora Borealis shimmer effect
class _AuroraShimmerPainter extends CustomPainter {
  final double phase;

  _AuroraShimmerPainter({required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw multiple flowing wave lines
    for (int i = 0; i < 4; i++) {
      final path = Path();
      final yOffset = size.height * (0.2 + i * 0.2);
      final phaseOffset = i * 0.8;

      paint.color = Color.fromRGBO(
        100 + (i * 30),
        255 - (i * 30),
        200 + (i * 15),
        0.15 + (sin(phase + phaseOffset) * 0.1),
      );

      path.moveTo(0, yOffset);

      for (double x = 0; x <= size.width; x += 4) {
        final norm = x / size.width;
        final y =
            yOffset +
            sin(norm * 3 * pi + phase + phaseOffset) * 8 +
            sin(norm * 5 * pi - phase * 0.5) * 4;
        path.lineTo(x, y);
      }

      canvas.drawPath(path, paint);
    }

    // Add random sparkle dots
    final random = Random((phase * 100).toInt());
    paint.style = PaintingStyle.fill;
    for (int i = 0; i < 8; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final opacity = 0.2 + random.nextDouble() * 0.3;
      paint.color = Colors.white.withOpacity(opacity);
      canvas.drawCircle(Offset(x, y), 1 + random.nextDouble(), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraShimmerPainter oldDelegate) {
    return oldDelegate.phase != phase;
  }
}
