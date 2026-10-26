import 'package:flutter/material.dart';

class BrightnessSlider extends StatelessWidget {
  final int brightness;
  final bool enabled;
  final ValueChanged<int>? onChanged;

  const BrightnessSlider({
    super.key,
    required this.brightness,
    this.enabled = true,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.brightness_6,
                  size: 20,
                  color: enabled ? null : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  'Brightness',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: enabled ? null : Colors.grey,
                  ),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '$brightness%',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: enabled ? Theme.of(context).primaryColor : Colors.grey,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(
              Icons.brightness_low,
              size: 20,
              color: enabled ? Colors.grey : Colors.grey.shade700,
            ),
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20,
                  ),
                  activeTrackColor: enabled
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  inactiveTrackColor: enabled
                      ? Theme.of(context).primaryColor.withAlpha(51)
                      : Colors.grey.withAlpha(51),
                  thumbColor: enabled
                      ? Theme.of(context).primaryColor
                      : Colors.grey,
                  overlayColor: Theme.of(context).primaryColor.withAlpha(51),
                ),
                child: Slider(
                  value: brightness.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 20,
                  onChanged: enabled && onChanged != null
                      ? (value) => onChanged!(value.round())
                      : null,
                ),
              ),
            ),
            Icon(
              Icons.brightness_high,
              size: 20,
              color: enabled ? Colors.grey : Colors.grey.shade700,
            ),
          ],
        ),

        // Quick brightness buttons
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildQuickButton(context, 25),
            _buildQuickButton(context, 50),
            _buildQuickButton(context, 75),
            _buildQuickButton(context, 100),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickButton(BuildContext context, int value) {
    final isActive = brightness == value;

    return GestureDetector(
      onTap: enabled && onChanged != null ? () => onChanged!(value) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? Theme.of(context).primaryColor
              : Theme.of(context).primaryColor.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          '$value%',
          style: TextStyle(
            color: isActive
                ? Colors.white
                : enabled
                ? Theme.of(context).primaryColor
                : Colors.grey,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
