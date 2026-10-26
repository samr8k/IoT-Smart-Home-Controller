import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/lamp_provider.dart';

class ReadingWarmthScreen extends ConsumerWidget {
  final String deviceIp;
  const ReadingWarmthScreen({super.key, required this.deviceIp});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(lampStateProvider(deviceIp));
    final notifier = ref.read(lampStateProvider(deviceIp).notifier);

    final isOn = state?.isOn ?? false;
    final warmth = state?.readingWarmth ?? 50;

    return Scaffold(
      appBar: AppBar(title: const Text('Reading Warmth')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.wb_incandescent, size: 28),
                const SizedBox(width: 12),
                Text('Warmth', style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                Text(
                  '$warmth%',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 20),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 18,
                ),
                child: Column(
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.ac_unit, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(child: Text('Cool White')),
                        SizedBox(width: 8),
                        Icon(Icons.whatshot, color: Colors.orange),
                        SizedBox(width: 8),
                        Text('Warm Yellow'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 8,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 12,
                        ),
                        overlayShape: const RoundSliderOverlayShape(
                          overlayRadius: 18,
                        ),
                        thumbColor: Colors.orangeAccent,
                        activeTrackColor: Colors.orangeAccent,
                        inactiveTrackColor: Colors.orangeAccent.withAlpha(80),
                        valueIndicatorTextStyle: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                      child: Slider(
                        value: warmth.toDouble(),
                        min: 0,
                        max: 100,
                        divisions: 100,
                        label: '$warmth%',
                        onChanged: isOn
                            ? (v) => notifier.setReadingWarmth(v.round())
                            : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Done'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (!isOn)
              Text(
                'Lamp is off — turn the lamp on to adjust warmth.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
          ],
        ),
      ),
    );
  }
}
