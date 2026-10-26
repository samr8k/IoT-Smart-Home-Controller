import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/lamp_pattern.dart';
import '../devices/lamp/lamp_models.dart' as device_models;
import '../devices/lamp/lamp_provider.dart';
import '../devices/lamp/lamp_api_service.dart';

/// Screen for controlling pattern-specific parameters
class PatternControlScreen extends ConsumerStatefulWidget {
  final String deviceIp;
  final LampPattern pattern;

  const PatternControlScreen({
    super.key,
    required this.deviceIp,
    required this.pattern,
  });

  @override
  ConsumerState<PatternControlScreen> createState() =>
      _PatternControlScreenState();
}

class _PatternControlScreenState extends ConsumerState<PatternControlScreen> {
  // Configuration constants
  static const int _kConfigDebounceMs = 300;
  static const int _kPatternActivationDelayMs = 100;

  // Pattern configuration values
  late Map<String, dynamic> _config;
  bool _isLoading = false;
  bool _isActivating = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _config = _getDefaultConfig(widget.pattern.id);
    _loadPatternConfig();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  /// Debounced live update - sends config after user stops adjusting
  void _debouncedSendConfig() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(Duration(milliseconds: _kConfigDebounceMs), () {
      _sendConfigSilent();
    });
  }

  /// Send config without showing snackbar (for live updates)
  Future<void> _sendConfigSilent() async {
    if (!mounted) return;

    try {
      // Always activate the pattern first to ensure it's the current one
      final notifier = ref.read(lampStateProvider(widget.deviceIp).notifier);

      // Get the device-specific pattern by index
      final devicePattern =
          device_models.LampPattern.defaultPatterns[widget.pattern.index];
      await notifier.setPattern(devicePattern);

      // Small delay to ensure pattern is activated before sending config
      await Future.delayed(Duration(milliseconds: _kPatternActivationDelayMs));

      // Then send the configuration
      await _sendConfigToDevice();
    } catch (e) {
      debugPrint('Error sending live config: $e');
    }
  }

  /// Get default configuration for each pattern type
  Map<String, dynamic> _getDefaultConfig(String patternId) {
    switch (patternId) {
      case 'yellow_night':
        return {
          'warmth': 50, // 0-100: cool white to deep orange
          'yellowness': 70, // 0-100: saturation of the color
          'brightness': 80, // 0-100
        };
      case 'fire':
        return {
          'calmness': 50, // 0-100: wild to calm fire
          'intensity': 80, // 0-100
          'spread': 50, // 0-100
        };
      case 'starry':
        return {
          'sparkleRate': 60, // 0-100: how often stars twinkle
          'density': 50, // 0-100: number of visible stars
        };
      case 'rainbow':
        return {
          'speed': 50, // 0-100
          'saturation': 100, // 0-100
          'density': 50, // 0-100
          'direction': 1, // 1 or -1
        };
      case 'candle':
        return {
          'flickerRandomness': 70, // 0-100
          'baseBrightness': 80, // 0-100
          'warmth': 60, // 0-100
        };
      case 'aurora':
        return {
          'speed': 30, // 0-100
          'intensity': 80, // 0-100
          'waveDensity': 50, // 0-100
          'shimmer': true,
          'complexity': 60, // 0-100
          'palette': 0, // 0: Classic, 1: Mystical, 2: Full Spectrum
        };
      case 'ocean':
        return {
          'waveSpeed': 50, // 0-100
          'colorDepth': 70, // 0-100
        };
      case 'breathing':
        return {
          'breathSpeed': 50, // 0-100
          'minBrightness': 20, // 0-100
          'maxBrightness': 100, // 0-100
        };
      case 'color_cycle':
        return {
          'cycleSpeed': 50, // 0-100
        };
      case 'spiral_chase':
        return {
          'chaseSpeed': 60, // 10-100
          'trailLength': 50, // 0-100 (maps to 1-6)
        };
      case 'sunset':
        return {
          'shimmerAmount': 40, // 0-100
          'colorWarmth': 70, // 0-100
        };
      case 'pulse':
        return {
          'pulseSpeed': 50, // 0-100
        };
      case 'snowflake':
        return {
          'sparkleRate': 60, // 0-100
          'coolness': 50, // 0-100
        };
      case 'night_light':
        return {
          'dimLevel': 30, // 0-100
          'warmth': 80, // 0-100
          'breatheAmount': 20, // 0-100
        };
      case 'ocean_waves':
        return {
          'speed': 50, // 0-100
          'depth': 70, // 0-100
          'foam': 30, // 0-100
        };
      case 'sunset_fade':
        return {
          'speed': 40, // 0-100
          'warmth': 60, // 0-100
        };
      case 'meteor_shower':
        return {
          'frequency': 50, // 0-100
          'tailLength': 60, // 0-100
          'brightness': 80, // 0-100
        };
      case 'lightning_storm':
        return {
          'frequency': 40, // 0-100
          'intensity': 90, // 0-100
          'ambientDarkness': 70, // 0-100
        };
      case 'ripple':
        return {
          'speed': 50, // 0-100
          'colorShift': 60, // 0-100
        };
      case 'kaleidoscope':
        return {
          'speed': 40, // 0-100
          'complexity': 60, // 0-100
          'saturation': 80, // 0-100
        };
      case 'dna_helix':
        return {
          'speed': 50, // 0-100
          'separation': 50, // 0-100
        };
      case 'forest_breeze':
        return {
          'swayAmount': 50, // 0-100
          'brightness': 70, // 0-100
        };
      case 'firefly_glow':
        return {
          'density': 50, // 0-100
          'glowSpeed': 40, // 0-100
        };
      case 'dreamy_clouds':
        return {
          'driftSpeed': 30, // 0-100
          'brightness': 70, // 0-100
        };
      case 'lava_lamp':
        return {
          'speed': 30, // 0-100
          'blobSize': 50, // 0-100
        };
      case 'custom':
        return {'red': 255, 'green': 255, 'blue': 255};
      default:
        return {'speed': 50, 'intensity': 80};
    }
  }

  /// Load pattern configuration from device (if available)
  Future<void> _loadPatternConfig() async {
    try {
      final result = await ref
          .read(lampStateProvider(widget.deviceIp).notifier)
          .getPatternConfig(widget.pattern.index);

      if (result != null && result['config'] != null && mounted) {
        final deviceConfig = result['config'] as Map<String, dynamic>;
        setState(() {
          // Map device config to UI config based on pattern type
          switch (widget.pattern.id) {
            case 'fire':
              _config['intensity'] =
                  ((deviceConfig['speed'] ?? 100) / 255 * 100).round();
              _config['flickerSpeed'] =
                  ((deviceConfig['sparking'] ?? 120) / 200 * 100).round();
              _config['flickerAmount'] =
                  ((deviceConfig['cooling'] ?? 55) / 100 * 100).round();
              break;
            case 'rainbow':
              _config['speed'] = ((deviceConfig['speed'] ?? 10) / 50 * 100)
                  .round();
              _config['direction'] = (deviceConfig['reverse'] ?? false)
                  ? -1
                  : 1;
              break;
            case 'candle':
              _config['flickerRandomness'] =
                  ((deviceConfig['flickerRate'] ?? 40) / 100 * 100).round();
              _config['baseBrightness'] =
                  ((deviceConfig['minBrightness'] ?? 100) / 200 * 100).round();
              break;
            case 'aurora':
              _config['speed'] = ((deviceConfig['speed'] ?? 15) / 50 * 100)
                  .round();
              _config['intensity'] =
                  ((deviceConfig['brightness'] ?? 220) / 255 * 100).round();
              _config['waveDensity'] = deviceConfig['waveDensity'] ?? 50;
              _config['shimmer'] = deviceConfig['shimmer'] ?? true;
              _config['complexity'] =
                  ((deviceConfig['complexity'] ?? 3) / 4 * 100).round();
              _config['palette'] = deviceConfig['paletteIndex'] ?? 0;
              break;
            case 'ocean':
              _config['waveSpeed'] = ((deviceConfig['speed'] ?? 20) / 50 * 100)
                  .round();
              _config['colorDepth'] =
                  ((deviceConfig['depth'] ?? 128) / 200 * 100).round();
              break;
            case 'breathing':
              _config['breathSpeed'] =
                  ((deviceConfig['speed'] ?? 30) / 100 * 100).round();
              _config['hue'] = deviceConfig['hue'] ?? 0;
              break;
            case 'color_cycle':
              _config['cycleSpeed'] = ((deviceConfig['speed'] ?? 5) / 20 * 100)
                  .round();
              break;
            case 'pulse':
              _config['pulseSpeed'] =
                  ((deviceConfig['speed'] ?? 60) / 150 * 100).round();
              _config['hue'] = deviceConfig['hue'] ?? 0;
              break;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading pattern config: $e');
    }
  }

  /// Send configuration to device
  Future<void> _sendConfig() async {
    setState(() => _isActivating = true);

    try {
      final apiService = LampApiService(widget.deviceIp);

      // First activate the pattern by index
      await apiService.setPattern(widget.pattern.index);

      // Then send the configuration
      await _sendConfigToDevice();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.pattern.name} activated'),
            duration: const Duration(seconds: 1),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActivating = false);
      }
    }
  }

  /// Core method to send config to device
  Future<void> _sendConfigToDevice() async {
    final notifier = ref.read(lampStateProvider(widget.deviceIp).notifier);

    // Convert UI config to device API config and send based on pattern type
    switch (widget.pattern.id) {
      case 'yellow_night':
        await notifier.setPatternConfig(widget.pattern.index, {
          'warmth': _config['warmth'] as int,
          'yellowness': _config['yellowness'] as int,
          'brightness': ((_config['brightness'] as int) * 255 ~/ 100),
        });
        break;
      case 'fire':
        await notifier.setPatternConfig(widget.pattern.index, {
          'calmness': _config['calmness'] as int,
          'intensity': _config['intensity'] as int,
          'spread': _config['spread'] as int,
        });
        break;
      case 'starry':
        await notifier.setPatternConfig(widget.pattern.index, {
          'sparkleRate': _config['sparkleRate'] as int,
          'density': _config['density'] as int,
        });
        break;
      case 'rainbow':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': (_config['speed'] as int) * 50 ~/ 100,
          'reverse': (_config['direction'] as int) < 0,
        });
        break;
      case 'aurora':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': (_config['speed'] as int) * 50 ~/ 100,
          'brightness': (_config['intensity'] as int) * 255 ~/ 100,
          'waveDensity': _config['waveDensity'] as int,
          'shimmer': _config['shimmer'] as bool,
          'complexity': ((_config['complexity'] as int) * 4 ~/ 100).clamp(1, 4),
          'paletteIndex': _config['palette'] as int,
        });
        break;
      case 'ocean':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': (_config['waveSpeed'] as int) * 50 ~/ 100,
          'depth': (_config['colorDepth'] as int) * 200 ~/ 100,
        });
        break;
      case 'breathing':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': _config['breathSpeed'] as int,
        });
        break;
      case 'color_cycle':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': (_config['cycleSpeed'] as int) * 20 ~/ 100,
        });
        break;
      case 'spiral_chase':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': _config['chaseSpeed'] as int,
          'trailLength': ((_config['trailLength'] as int) * 6 ~/ 100).clamp(
            1,
            6,
          ),
        });
        break;
      case 'sunset':
        await notifier.setPatternConfig(widget.pattern.index, {
          'shimmer': _config['shimmerAmount'] as int,
          'warmth': _config['colorWarmth'] as int,
        });
        break;
      case 'pulse':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': (_config['pulseSpeed'] as int) * 150 ~/ 100,
        });
        break;
      case 'snowflake':
        await notifier.setPatternConfig(widget.pattern.index, {
          'sparkleRate': _config['sparkleRate'] as int,
          'coolness': _config['coolness'] as int,
        });
        break;
      case 'night_light':
        await notifier.setPatternConfig(widget.pattern.index, {
          'dimLevel': _config['dimLevel'] as int,
          'warmth': _config['warmth'] as int,
          'breathe': _config['breatheAmount'] as int,
        });
        break;
      case 'candle':
        await notifier.setPatternConfig(widget.pattern.index, {
          'flickerRate': _config['flickerRandomness'] as int,
          'minBrightness': (_config['baseBrightness'] as int) * 200 ~/ 100,
        });
        break;
      case 'ocean_waves':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': _config['speed'] as int,
          'depth': _config['depth'] as int,
        });
        break;
      case 'sunset_fade':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': _config['speed'] as int,
        });
        break;
      case 'meteor_shower':
        await notifier.setPatternConfig(widget.pattern.index, {
          'frequency': _config['frequency'] as int,
          'tailLength': _config['tailLength'] as int,
        });
        break;
      case 'lightning_storm':
        // Note: Firmware only supports 'intensity' which controls both frequency and brightness
        // Map frequency slider to intensity for backward compatibility
        final combinedIntensity =
            ((_config['frequency'] as int) + (_config['intensity'] as int)) ~/
            2;
        await notifier.setPatternConfig(widget.pattern.index, {
          'intensity': combinedIntensity,
        });
        break;
      case 'ripple':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': _config['speed'] as int,
        });
        break;
      case 'kaleidoscope':
        // Note: Firmware only supports 'speed', not 'complexity'
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': _config['speed'] as int,
          // 'complexity': _config['complexity'] as int,  // Not supported by firmware
        });
        break;
      case 'dna_helix':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': _config['speed'] as int,
        });
        break;
      case 'forest_breeze':
        await notifier.setPatternConfig(widget.pattern.index, {
          'sway': _config['swayAmount'] as int,
        });
        break;
      case 'firefly_glow':
        await notifier.setPatternConfig(widget.pattern.index, {
          'density': _config['density'] as int,
          'speed': _config['glowSpeed'] as int,
        });
        break;
      case 'dreamy_clouds':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': _config['driftSpeed'] as int,
        });
        break;
      case 'lava_lamp':
        await notifier.setPatternConfig(widget.pattern.index, {
          'speed': _config['speed'] as int,
          'blobSize': _config['blobSize'] as int,
        });
        break;
      case 'custom':
        final r = _config['red'] as int;
        final g = _config['green'] as int;
        final b = _config['blue'] as int;
        await notifier.setColorWheel(Color.fromARGB(255, r, g, b));
        break;
      default:
        // For patterns without specific config, just ensure pattern is set
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final lampState = ref.watch(lampStateProvider(widget.deviceIp));
    final isCurrentPattern = lampState?.currentPattern?.id == widget.pattern.id;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.pattern.name),
        actions: [
          TextButton.icon(
            onPressed: _isActivating ? null : _sendConfig,
            icon: _isActivating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Icon(isCurrentPattern ? Icons.check : Icons.play_arrow),
            label: Text(isCurrentPattern ? 'Active' : 'Activate'),
            style: TextButton.styleFrom(
              foregroundColor: isCurrentPattern ? Colors.green : null,
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Active pattern indicator
            if (isCurrentPattern)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'This pattern is active. Changes are applied live.',
                        style: TextStyle(color: Colors.green),
                      ),
                    ),
                  ],
                ),
              ),

            // Pattern preview card
            _buildPatternPreviewCard(context),
            const SizedBox(height: 24),

            // Pattern description
            Text(
              widget.pattern.description,
              style: Theme.of(
                context,
              ).textTheme.bodyLarge?.copyWith(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),

            // Pattern-specific controls
            _buildPatternControls(context),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternPreviewCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Container(
        height: 120,
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.pattern.colors.isNotEmpty
                ? widget.pattern.colors
                : [Colors.grey],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          children: [
            // Overlay gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
                ),
              ),
            ),
            // Pattern info
            Positioned(
              left: 16,
              bottom: 16,
              child: Row(
                children: [
                  Icon(widget.pattern.icon, color: Colors.white, size: 32),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.pattern.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (widget.pattern.isAnimated)
                        const Text(
                          'Animated',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPatternControls(BuildContext context) {
    switch (widget.pattern.id) {
      case 'yellow_night':
        return _buildNightReadingControls(context);
      case 'fire':
        return _buildFireControls(context);
      case 'rainbow':
        return _buildRainbowControls(context);
      case 'candle':
        return _buildCandleControls(context);
      case 'aurora':
        return _buildAuroraControls(context);
      case 'ocean':
        return _buildOceanControls(context);
      case 'starry':
        return _buildStarryControls(context);
      case 'breathing':
        return _buildBreathingControls(context);
      case 'color_cycle':
        return _buildColorCycleControls(context);
      case 'spiral_chase':
        return _buildSpiralChaseControls(context);
      case 'sunset':
        return _buildSunsetControls(context);
      case 'pulse':
        return _buildPulseControls(context);
      case 'snowflake':
        return _buildSnowflakeControls(context);
      case 'night_light':
        return _buildNightLightControls(context);
      case 'ocean_waves':
        return _buildOceanWavesControls(context);
      case 'sunset_fade':
        return _buildSunsetFadeControls(context);
      case 'meteor_shower':
        return _buildMeteorShowerControls(context);
      case 'lightning_storm':
        return _buildLightningStormControls(context);
      case 'ripple':
        return _buildRippleControls(context);
      case 'kaleidoscope':
        return _buildKaleidoscopeControls(context);
      case 'dna_helix':
        return _buildDNAHelixControls(context);
      case 'forest_breeze':
        return _buildForestBreezeControls(context);
      case 'firefly_glow':
        return _buildFireflyGlowControls(context);
      case 'dreamy_clouds':
        return _buildDreamyCloudsControls(context);
      case 'lava_lamp':
        return _buildLavaLampControls(context);
      case 'custom':
        return _buildCustomColorControls(context);
      default:
        return _buildGenericControls(context);
    }
  }

  // ==================== Pattern-Specific Control Builders ====================

  Widget _buildNightReadingControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Night Reading Settings'),
        _buildSliderControl(
          context,
          'Warmth',
          'Cool white to deep orange temperature',
          Icons.wb_sunny,
          _config['warmth']?.toDouble() ?? 50,
          (value) => setState(() => _config['warmth'] = value.round()),
          activeColor: Colors.orange,
        ),
        _buildSliderControl(
          context,
          'Yellowness',
          'Color saturation intensity',
          Icons.palette,
          _config['yellowness']?.toDouble() ?? 70,
          (value) => setState(() => _config['yellowness'] = value.round()),
          activeColor: Colors.amber,
        ),
        _buildSliderControl(
          context,
          'Reading Brightness',
          'Overall light level',
          Icons.brightness_high,
          _config['brightness']?.toDouble() ?? 80,
          (value) => setState(() => _config['brightness'] = value.round()),
          activeColor: Colors.yellow,
        ),
      ],
    );
  }

  Widget _buildFireControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Fire Settings'),
        _buildSliderControl(
          context,
          'Calmness',
          'Wild chaotic fire (0) to calm gentle fire (100)',
          Icons.spa,
          _config['calmness']?.toDouble() ?? 50,
          (value) => setState(() => _config['calmness'] = value.round()),
          activeColor: Colors.deepOrange,
        ),
        _buildSliderControl(
          context,
          'Intensity',
          'Overall heat and brightness of flames',
          Icons.whatshot,
          _config['intensity']?.toDouble() ?? 80,
          (value) => setState(() => _config['intensity'] = value.round()),
          activeColor: Colors.orange,
        ),
        _buildSliderControl(
          context,
          'Flame Spread',
          'How spread out the flames are',
          Icons.expand,
          _config['spread']?.toDouble() ?? 50,
          (value) => setState(() => _config['spread'] = value.round()),
          activeColor: Colors.red,
        ),
      ],
    );
  }

  Widget _buildRainbowControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Rainbow Settings'),
        _buildSliderControl(
          context,
          'Rotation Speed',
          'How fast the rainbow rotates',
          Icons.rotate_right,
          _config['speed']?.toDouble() ?? 50,
          (value) => setState(() => _config['speed'] = value.round()),
          activeColor: Colors.purple,
        ),
        // Note: Saturation and Density removed - not supported by firmware
        // Rainbow pattern uses fixed saturation (255) and density based on LED layout
        const SizedBox(height: 16),
        _buildDirectionToggle(context),
      ],
    );
  }

  Widget _buildCandleControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Candle Settings'),
        _buildSliderControl(
          context,
          'Flicker Randomness',
          'How random the candle flickers',
          Icons.auto_fix_high,
          _config['flickerRandomness']?.toDouble() ?? 70,
          (value) =>
              setState(() => _config['flickerRandomness'] = value.round()),
          activeColor: Colors.orange,
        ),
        _buildSliderControl(
          context,
          'Base Brightness',
          'Overall candle brightness',
          Icons.brightness_high,
          _config['baseBrightness']?.toDouble() ?? 80,
          (value) => setState(() => _config['baseBrightness'] = value.round()),
          activeColor: Colors.amber,
        ),
        // Note: Flame Warmth removed - candle uses fixed warm color palette (orange/yellow)
        // Color is generated procedurally in firmware based on flicker
      ],
    );
  }

  Widget _buildAuroraControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Aurora Borealis Settings'),

        // Palette selection
        _buildPaletteSelector(context),
        const SizedBox(height: 20),

        _buildSliderControl(
          context,
          'Wave Speed',
          'How fast the aurora waves move',
          Icons.waves,
          _config['speed']?.toDouble() ?? 30,
          (value) => setState(() => _config['speed'] = value.round()),
          activeColor: Colors.teal,
        ),
        _buildSliderControl(
          context,
          'Intensity',
          'Brightness and vibrancy of the aurora',
          Icons.brightness_6,
          _config['intensity']?.toDouble() ?? 80,
          (value) => setState(() => _config['intensity'] = value.round()),
          activeColor: Colors.purple,
        ),
        _buildSliderControl(
          context,
          'Wave Density',
          'How many waves are visible',
          Icons.blur_linear,
          _config['waveDensity']?.toDouble() ?? 50,
          (value) => setState(() => _config['waveDensity'] = value.round()),
          activeColor: Colors.cyan,
        ),
        _buildSliderControl(
          context,
          'Complexity',
          'Number of layered wave effects',
          Icons.layers,
          _config['complexity']?.toDouble() ?? 60,
          (value) => setState(() => _config['complexity'] = value.round()),
          activeColor: Colors.indigo,
        ),
        const SizedBox(height: 16),
        _buildSwitchControl(
          context,
          'Shimmer Effect',
          'Add magical sparkle overlay',
          Icons.auto_awesome,
          _config['shimmer'] ?? true,
          (value) => setState(() => _config['shimmer'] = value),
        ),
      ],
    );
  }

  Widget _buildPaletteSelector(BuildContext context) {
    final palettes = [
      {
        'name': 'Classic',
        'colors': [Colors.green, Colors.cyan, Colors.blue],
      },
      {
        'name': 'Mystical',
        'colors': [Colors.purple, Colors.pink, Colors.blue],
      },
      {
        'name': 'Full Spectrum',
        'colors': [Colors.green, Colors.blue, Colors.purple, Colors.pink],
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Color Palette',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(palettes.length, (index) {
            final palette = palettes[index];
            final isSelected = _config['palette'] == index;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: index < palettes.length - 1 ? 8 : 0,
                ),
                child: GestureDetector(
                  onTap: () {
                    setState(() => _config['palette'] = index);
                    _debouncedSendConfig();
                  },
                  child: Container(
                    height: 60,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                        width: isSelected ? 2 : 1,
                      ),
                      gradient: LinearGradient(
                        colors: palette['colors'] as List<Color>,
                      ),
                    ),
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          palette['name'] as String,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildOceanControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Ocean Settings'),
        _buildSliderControl(
          context,
          'Wave Speed',
          'How fast the waves move',
          Icons.waves,
          _config['waveSpeed']?.toDouble() ?? 50,
          (value) => setState(() => _config['waveSpeed'] = value.round()),
          activeColor: Colors.blue,
        ),
        // Note: Wave Height removed - wave amplitude is fixed in firmware
        // Only speed and color depth are configurable
        _buildSliderControl(
          context,
          'Color Depth',
          'Deep blue to light cyan',
          Icons.gradient,
          _config['colorDepth']?.toDouble() ?? 70,
          (value) => setState(() => _config['colorDepth'] = value.round()),
          activeColor: Colors.teal,
        ),
      ],
    );
  }

  Widget _buildStarryControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Starry Night Settings'),
        _buildSliderControl(
          context,
          'Sparkle Rate',
          'How often stars twinkle',
          Icons.auto_awesome,
          _config['sparkleRate']?.toDouble() ?? 60,
          (value) => setState(() => _config['sparkleRate'] = value.round()),
          activeColor: Colors.yellow,
        ),
        _buildSliderControl(
          context,
          'Star Density',
          'Number of visible stars',
          Icons.star,
          _config['density']?.toDouble() ?? 50,
          (value) => setState(() => _config['density'] = value.round()),
          activeColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildBreathingControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Breathing Settings'),
        _buildSliderControl(
          context,
          'Breath Speed',
          'How fast the breathing cycle is',
          Icons.air,
          _config['breathSpeed']?.toDouble() ?? 50,
          (value) => setState(() => _config['breathSpeed'] = value.round()),
          activeColor: Colors.grey,
        ),
        _buildSliderControl(
          context,
          'Minimum Brightness',
          'Dimmest point in the cycle',
          Icons.brightness_low,
          _config['minBrightness']?.toDouble() ?? 20,
          (value) => setState(() => _config['minBrightness'] = value.round()),
          activeColor: Colors.grey.shade400,
        ),
        _buildSliderControl(
          context,
          'Maximum Brightness',
          'Brightest point in the cycle',
          Icons.brightness_high,
          _config['maxBrightness']?.toDouble() ?? 100,
          (value) => setState(() => _config['maxBrightness'] = value.round()),
          activeColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildColorCycleControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Color Cycle Settings'),
        _buildSliderControl(
          context,
          'Cycle Speed',
          'How fast colors change',
          Icons.speed,
          _config['cycleSpeed']?.toDouble() ?? 50,
          (value) => setState(() => _config['cycleSpeed'] = value.round()),
          activeColor: Colors.purple,
        ),
        _buildSliderControl(
          context,
          'Transition Smoothness',
          'How smoothly colors blend',
          Icons.blur_on,
          _config['smoothness']?.toDouble() ?? 80,
          (value) => setState(() => _config['smoothness'] = value.round()),
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildSpiralChaseControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Spiral Chase Settings'),
        _buildSliderControl(
          context,
          'Chase Speed',
          'How fast the light chases (10-100)',
          Icons.speed,
          _config['chaseSpeed']?.toDouble() ?? 60,
          (value) => setState(() => _config['chaseSpeed'] = value.round()),
          min: 10,
          max: 100,
          activeColor: Colors.cyan,
        ),
        _buildSliderControl(
          context,
          'Trail Length',
          'Length of the trailing lights (1-6)',
          Icons.trending_up,
          _config['trailLength']?.toDouble() ?? 50,
          (value) => setState(() => _config['trailLength'] = value.round()),
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildSunsetControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Sunset Settings'),
        _buildSliderControl(
          context,
          'Shimmer Amount',
          'Subtle sparkle effect',
          Icons.auto_awesome,
          _config['shimmerAmount']?.toDouble() ?? 40,
          (value) => setState(() => _config['shimmerAmount'] = value.round()),
          activeColor: Colors.pink,
        ),
        _buildSliderControl(
          context,
          'Color Warmth',
          'Orange to purple gradient',
          Icons.wb_twilight,
          _config['colorWarmth']?.toDouble() ?? 70,
          (value) => setState(() => _config['colorWarmth'] = value.round()),
          activeColor: Colors.orange,
        ),
      ],
    );
  }

  Widget _buildPulseControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Pulse Settings'),
        _buildSliderControl(
          context,
          'Pulse Speed',
          'How fast the pulse radiates',
          Icons.radar,
          _config['pulseSpeed']?.toDouble() ?? 50,
          (value) => setState(() => _config['pulseSpeed'] = value.round()),
          activeColor: Colors.purple,
        ),
        _buildSliderControl(
          context,
          'Wave Width',
          'Width of the pulse wave',
          Icons.waves,
          _config['waveWidth']?.toDouble() ?? 60,
          (value) => setState(() => _config['waveWidth'] = value.round()),
          activeColor: Colors.blue,
        ),
        _buildSliderControl(
          context,
          'Color Shift',
          'How much color changes',
          Icons.palette,
          _config['colorShift']?.toDouble() ?? 30,
          (value) => setState(() => _config['colorShift'] = value.round()),
          activeColor: Colors.indigo,
        ),
      ],
    );
  }

  Widget _buildSnowflakeControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Snowflake Settings'),
        _buildSliderControl(
          context,
          'Sparkle Rate',
          'How often snowflakes appear',
          Icons.ac_unit,
          _config['sparkleRate']?.toDouble() ?? 60,
          (value) => setState(() => _config['sparkleRate'] = value.round()),
          activeColor: Colors.white,
        ),
        _buildSliderControl(
          context,
          'Coolness',
          'Blue tint intensity',
          Icons.thermostat,
          _config['coolness']?.toDouble() ?? 50,
          (value) => setState(() => _config['coolness'] = value.round()),
          activeColor: Colors.lightBlue,
        ),
      ],
    );
  }

  Widget _buildNightLightControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Night Light Settings'),
        _buildSliderControl(
          context,
          'Dim Level',
          'Overall brightness level',
          Icons.brightness_3,
          _config['dimLevel']?.toDouble() ?? 30,
          (value) => setState(() => _config['dimLevel'] = value.round()),
          activeColor: Colors.amber,
        ),
        _buildSliderControl(
          context,
          'Warmth',
          'Color temperature',
          Icons.wb_incandescent,
          _config['warmth']?.toDouble() ?? 80,
          (value) => setState(() => _config['warmth'] = value.round()),
          activeColor: Colors.orange,
        ),
        _buildSliderControl(
          context,
          'Breathe Amount',
          'Subtle breathing effect',
          Icons.air,
          _config['breatheAmount']?.toDouble() ?? 20,
          (value) => setState(() => _config['breatheAmount'] = value.round()),
          activeColor: Colors.brown,
        ),
      ],
    );
  }

  // ==================== NEW PATTERN CONTROLS ====================

  Widget _buildOceanWavesControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Ocean Waves Settings'),
        _buildSliderControl(
          context,
          'Wave Speed',
          'How fast the waves roll',
          Icons.waves,
          _config['speed']?.toDouble() ?? 50,
          (value) => setState(() => _config['speed'] = value.round()),
          activeColor: Colors.blue,
        ),
        _buildSliderControl(
          context,
          'Ocean Depth',
          'Deep ocean blue intensity',
          Icons.water,
          _config['depth']?.toDouble() ?? 70,
          (value) => setState(() => _config['depth'] = value.round()),
          activeColor: Color(0xFF0077B6),
        ),
        _buildSliderControl(
          context,
          'Foam Amount',
          'White foam on wave crests',
          Icons.bubble_chart,
          _config['foam']?.toDouble() ?? 30,
          (value) => setState(() => _config['foam'] = value.round()),
          activeColor: Colors.lightBlue,
        ),
      ],
    );
  }

  Widget _buildSunsetFadeControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Sunset Fade Settings'),
        _buildSliderControl(
          context,
          'Transition Speed',
          'How fast the colors transition',
          Icons.speed,
          _config['speed']?.toDouble() ?? 40,
          (value) => setState(() => _config['speed'] = value.round()),
          activeColor: Colors.orange,
        ),
        _buildSliderControl(
          context,
          'Color Warmth',
          'Orange to purple warmth',
          Icons.wb_twilight,
          _config['warmth']?.toDouble() ?? 60,
          (value) => setState(() => _config['warmth'] = value.round()),
          activeColor: Color(0xFFFF6B35),
        ),
      ],
    );
  }

  Widget _buildMeteorShowerControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Meteor Shower Settings'),
        _buildSliderControl(
          context,
          'Meteor Frequency',
          'How often meteors appear',
          Icons.rocket_launch,
          _config['frequency']?.toDouble() ?? 50,
          (value) => setState(() => _config['frequency'] = value.round()),
          activeColor: Colors.yellow,
        ),
        _buildSliderControl(
          context,
          'Tail Length',
          'Length of the meteor trail',
          Icons.trending_up,
          _config['tailLength']?.toDouble() ?? 60,
          (value) => setState(() => _config['tailLength'] = value.round()),
          activeColor: Colors.white,
        ),
        _buildSliderControl(
          context,
          'Brightness',
          'Overall meteor brightness',
          Icons.brightness_high,
          _config['brightness']?.toDouble() ?? 80,
          (value) => setState(() => _config['brightness'] = value.round()),
          activeColor: Colors.amber,
        ),
      ],
    );
  }

  Widget _buildLightningStormControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Lightning Storm Settings'),
        _buildSliderControl(
          context,
          'Strike Frequency',
          'How often lightning strikes',
          Icons.flash_on,
          _config['frequency']?.toDouble() ?? 40,
          (value) => setState(() => _config['frequency'] = value.round()),
          activeColor: Colors.yellow,
        ),
        _buildSliderControl(
          context,
          'Flash Intensity',
          'Brightness of lightning flashes',
          Icons.wb_sunny,
          _config['intensity']?.toDouble() ?? 90,
          (value) => setState(() => _config['intensity'] = value.round()),
          activeColor: Colors.white,
        ),
        _buildSliderControl(
          context,
          'Ambient Darkness',
          'How dark between flashes',
          Icons.nightlight,
          _config['ambientDarkness']?.toDouble() ?? 70,
          (value) => setState(() => _config['ambientDarkness'] = value.round()),
          activeColor: Color(0xFF2D3748),
        ),
      ],
    );
  }

  Widget _buildRippleControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Ripple Settings'),
        _buildSliderControl(
          context,
          'Ripple Speed',
          'How fast ripples expand',
          Icons.adjust,
          _config['speed']?.toDouble() ?? 50,
          (value) => setState(() => _config['speed'] = value.round()),
          activeColor: Colors.cyan,
        ),
        _buildSliderControl(
          context,
          'Color Shift',
          'How much colors change',
          Icons.palette,
          _config['colorShift']?.toDouble() ?? 60,
          (value) => setState(() => _config['colorShift'] = value.round()),
          activeColor: Colors.purple,
        ),
      ],
    );
  }

  Widget _buildKaleidoscopeControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Kaleidoscope Settings'),
        _buildSliderControl(
          context,
          'Rotation Speed',
          'How fast the pattern rotates',
          Icons.blur_circular,
          _config['speed']?.toDouble() ?? 40,
          (value) => setState(() => _config['speed'] = value.round()),
          activeColor: Colors.pink,
        ),
        _buildSliderControl(
          context,
          'Pattern Complexity',
          'Number of color segments',
          Icons.auto_awesome_mosaic,
          _config['complexity']?.toDouble() ?? 60,
          (value) => setState(() => _config['complexity'] = value.round()),
          activeColor: Colors.purple,
        ),
        _buildSliderControl(
          context,
          'Saturation',
          'Color vibrancy',
          Icons.palette,
          _config['saturation']?.toDouble() ?? 80,
          (value) => setState(() => _config['saturation'] = value.round()),
          activeColor: Colors.blue,
        ),
      ],
    );
  }

  Widget _buildDNAHelixControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'DNA Helix Settings'),
        _buildSliderControl(
          context,
          'Rotation Speed',
          'How fast the helix rotates',
          Icons.science,
          _config['speed']?.toDouble() ?? 50,
          (value) => setState(() => _config['speed'] = value.round()),
          activeColor: Color(0xFF00D4FF),
        ),
        _buildSliderControl(
          context,
          'Strand Separation',
          'Distance between the two strands',
          Icons.compare_arrows,
          _config['separation']?.toDouble() ?? 50,
          (value) => setState(() => _config['separation'] = value.round()),
          activeColor: Color(0xFFFF69B4),
        ),
      ],
    );
  }

  Widget _buildForestBreezeControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Forest Breeze Settings'),
        _buildSliderControl(
          context,
          'Sway Amount',
          'How much the leaves sway',
          Icons.forest,
          _config['swayAmount']?.toDouble() ?? 50,
          (value) => setState(() => _config['swayAmount'] = value.round()),
          activeColor: Color(0xFF228B22),
        ),
        _buildSliderControl(
          context,
          'Brightness',
          'Overall brightness of the foliage',
          Icons.brightness_6,
          _config['brightness']?.toDouble() ?? 70,
          (value) => setState(() => _config['brightness'] = value.round()),
          activeColor: Color(0xFF32CD32),
        ),
      ],
    );
  }

  Widget _buildFireflyGlowControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Firefly Glow Settings'),
        _buildSliderControl(
          context,
          'Firefly Density',
          'Number of fireflies',
          Icons.blur_on,
          _config['density']?.toDouble() ?? 50,
          (value) => setState(() => _config['density'] = value.round()),
          activeColor: Color(0xFF9ACD32),
        ),
        _buildSliderControl(
          context,
          'Glow Speed',
          'How fast fireflies blink',
          Icons.lightbulb,
          _config['glowSpeed']?.toDouble() ?? 40,
          (value) => setState(() => _config['glowSpeed'] = value.round()),
          activeColor: Color(0xFFADFF2F),
        ),
      ],
    );
  }

  Widget _buildDreamyCloudsControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Dreamy Clouds Settings'),
        _buildSliderControl(
          context,
          'Drift Speed',
          'How fast clouds drift',
          Icons.cloud,
          _config['driftSpeed']?.toDouble() ?? 30,
          (value) => setState(() => _config['driftSpeed'] = value.round()),
          activeColor: Color(0xFFB0C4DE),
        ),
        _buildSliderControl(
          context,
          'Brightness',
          'Cloud brightness',
          Icons.brightness_5,
          _config['brightness']?.toDouble() ?? 70,
          (value) => setState(() => _config['brightness'] = value.round()),
          activeColor: Colors.white,
        ),
      ],
    );
  }

  Widget _buildLavaLampControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Lava Lamp Settings'),
        _buildSliderControl(
          context,
          'Flow Speed',
          'How fast the lava moves',
          Icons.water_drop,
          _config['speed']?.toDouble() ?? 30,
          (value) => setState(() => _config['speed'] = value.round()),
          activeColor: Color(0xFFFF4500),
        ),
        _buildSliderControl(
          context,
          'Blob Size',
          'Size of lava blobs',
          Icons.bubble_chart,
          _config['blobSize']?.toDouble() ?? 50,
          (value) => setState(() => _config['blobSize'] = value.round()),
          activeColor: Color(0xFFFFD700),
        ),
      ],
    );
  }

  Widget _buildCustomColorControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Custom Color'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ColorPicker(
              pickerColor: Color.fromRGBO(
                _config['red'] ?? 255,
                _config['green'] ?? 255,
                _config['blue'] ?? 255,
                1,
              ),
              onColorChanged: (color) {
                setState(() {
                  _config['red'] = (color.r * 255).round();
                  _config['green'] = (color.g * 255).round();
                  _config['blue'] = (color.b * 255).round();
                });
                // Send color to device immediately
                ref
                    .read(lampStateProvider(widget.deviceIp).notifier)
                    .setColorWheel(color);
              },
              enableAlpha: false,
              hexInputBar: true,
              labelTypes: const [],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenericControls(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, 'Pattern Settings'),
        _buildSliderControl(
          context,
          'Speed',
          'Animation speed',
          Icons.speed,
          _config['speed']?.toDouble() ?? 50,
          (value) => setState(() => _config['speed'] = value.round()),
          activeColor: Theme.of(context).primaryColor,
        ),
        _buildSliderControl(
          context,
          'Intensity',
          'Effect intensity',
          Icons.brightness_6,
          _config['intensity']?.toDouble() ?? 80,
          (value) => setState(() => _config['intensity'] = value.round()),
          activeColor: Theme.of(context).primaryColor,
        ),
      ],
    );
  }

  // ==================== Reusable Control Widgets ====================

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildSliderControl(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    double value,
    ValueChanged<double> onChanged, {
    Color activeColor = Colors.blue,
    double min = 0,
    double max = 100,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: activeColor),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${value.round()}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: activeColor,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            activeColor: activeColor,
            onChanged: (newValue) {
              onChanged(newValue);
              _debouncedSendConfig(); // Trigger live update
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchControl(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: Switch(
          value: value,
          onChanged: (newValue) {
            onChanged(newValue);
            _debouncedSendConfig(); // Trigger live update
          },
        ),
      ),
    );
  }

  Widget _buildDirectionToggle(BuildContext context) {
    final direction = _config['direction'] ?? 1;
    return Card(
      child: ListTile(
        leading: const Icon(Icons.swap_horiz),
        title: const Text('Direction'),
        subtitle: Text(direction == 1 ? 'Clockwise' : 'Counter-clockwise'),
        trailing: IconButton(
          icon: Icon(
            direction == 1 ? Icons.rotate_right : Icons.rotate_left,
            color: Theme.of(context).primaryColor,
          ),
          onPressed: () {
            setState(() => _config['direction'] = direction == 1 ? -1 : 1);
            _debouncedSendConfig();
          },
        ),
      ),
    );
  }
}
