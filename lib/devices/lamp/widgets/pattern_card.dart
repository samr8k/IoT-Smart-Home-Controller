import 'package:flutter/material.dart';
import '../lamp_models.dart';

/// Card widget for displaying a lamp pattern option
class PatternCard extends StatelessWidget {
  final LampPattern pattern;
  final bool isSelected;
  final VoidCallback? onTap;

  const PatternCard({
    super.key,
    required this.pattern,
    this.isSelected = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final previewColor = pattern.colors.isNotEmpty
        ? pattern.colors.first
        : Colors.white;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Theme.of(context).primaryColor.withAlpha(26)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? Theme.of(context).primaryColor
                : Colors.transparent,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? previewColor.withAlpha(51)
                  : Colors.black.withAlpha(13),
              blurRadius: isSelected ? 12 : 4,
              spreadRadius: isSelected ? 2 : 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pattern icon with color preview
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: pattern.colors.length > 1
                      ? LinearGradient(
                          colors: pattern.colors.take(3).toList(),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: pattern.colors.length == 1 ? previewColor : null,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  pattern.icon,
                  color: previewColor.computeLuminance() > 0.5
                      ? Colors.black54
                      : Colors.white,
                  size: 24,
                ),
              ),

              const SizedBox(height: 8),

              // Pattern name
              Text(
                pattern.name,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),

              // Animated indicator
              if (pattern.isAnimated)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.motion_photos_on,
                        size: 12,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        'Animated',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade500,
                          fontSize: 10,
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
