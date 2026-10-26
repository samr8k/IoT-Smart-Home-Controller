import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/iot_device.dart';
import '../models/lamp_pattern.dart';
import '../models/lamp_state.dart';
import '../services/network_service.dart';
import '../providers/lamp_provider.dart';
import '../providers/device_provider.dart';
import '../widgets/pattern_card.dart';
import '../widgets/brightness_slider.dart';
import 'reading_warmth_screen.dart';
import 'pattern_control_screen.dart';
import '../widgets/connection_status_indicator.dart';

class LampControlScreen extends ConsumerStatefulWidget {
  final IoTDevice device;

  const LampControlScreen({super.key, required this.device});

  @override
  ConsumerState<LampControlScreen> createState() => _LampControlScreenState();
}

class _LampControlScreenState extends ConsumerState<LampControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Timer? _gyroTimer;
  Timer? _colorDebounceTimer;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);

    // Initialize lamp state
    Future.microtask(() {
      ref
          .read(lampStateProvider(widget.device.ipAddress).notifier)
          .initialize();
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _stopGyroTimer();
    _colorDebounceTimer?.cancel();
    super.dispose();
  }

  void _onTabChanged() {
    final lampState = ref.read(lampStateProvider(widget.device.ipAddress));
    if (_tabController.index == 3 && lampState?.gyroState?.enabled == true) {
      _startGyroTimer();
    } else {
      _stopGyroTimer();
    }
  }

  void _startGyroTimer() {
    _stopGyroTimer(); // Ensure no duplicate timers
    _gyroTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      ref
          .read(lampStateProvider(widget.device.ipAddress).notifier)
          .refreshGyroStatus();
    });
  }

  void _stopGyroTimer() {
    _gyroTimer?.cancel();
    _gyroTimer = null;
  }

  @override
  Widget build(BuildContext context) {
    final lampState = ref.watch(lampStateProvider(widget.device.ipAddress));
    final wifiInfoAsync = ref.watch(wifiInfoProvider);
    final device = ref
        .watch(devicesProvider)
        .firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => widget.device,
        );

    // Manage gyro timer based on tab and gyro state
    if (_tabController.index == 3 &&
        lampState?.gyroState?.enabled == true &&
        _gyroTimer == null) {
      _startGyroTimer();
    } else if (!(_tabController.index == 3 &&
            lampState?.gyroState?.enabled == true) &&
        _gyroTimer != null) {
      _stopGyroTimer();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(device.name),
        actions: [
          ConnectionStatusIndicator(status: device.connectionStatus),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showDeviceInfo(context, device, lampState),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.auto_awesome), text: 'Patterns'),
            Tab(icon: Icon(Icons.palette), text: 'Colors'),
            Tab(icon: Icon(Icons.sensors), text: 'Gyro'),
            Tab(icon: Icon(Icons.tune), text: 'Settings'),
          ],
        ),
      ),
      body: lampState == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Power & Brightness Header
                _buildPowerBrightnessSection(context, lampState),

                // Tab Content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildPatternsTab(context, lampState),
                      _buildColorsTab(context, lampState),
                      _buildGyroTab(context, lampState),
                      _buildSettingsTab(context, lampState),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildPowerBrightnessSection(BuildContext context, LampState state) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final iconSize = isLandscape ? 40.0 : 60.0;
    final iconSizeInner = isLandscape ? 24.0 : 32.0;
    final verticalPadding = isLandscape ? 8.0 : 16.0;
    final horizontalPadding = isLandscape ? 12.0 : 16.0;
    final spacing = isLandscape ? 8.0 : 16.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Power Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: iconSize,
                    height: iconSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isOn
                          ? _getDisplayColor(state).withAlpha(51)
                          : Colors.grey.withAlpha(51),
                      boxShadow: state.isOn
                          ? [
                              BoxShadow(
                                color: _getDisplayColor(state).withAlpha(102),
                                blurRadius: isLandscape ? 15 : 20,
                                spreadRadius: isLandscape ? 3 : 5,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      size: iconSizeInner,
                      color: state.isOn ? _getDisplayColor(state) : Colors.grey,
                    ),
                  ),
                  SizedBox(width: spacing),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        state.isOn ? 'ON' : 'OFF',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: isLandscape ? 18 : null,
                        ),
                      ),
                      Text(
                        _getModeName(state),
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.grey,
                          fontSize: isLandscape ? 12 : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Transform.scale(
                scale: isLandscape ? 1.0 : 1.3,
                child: Switch(
                  value: state.isOn,
                  onChanged: (value) {
                    ref
                        .read(
                          lampStateProvider(widget.device.ipAddress).notifier,
                        )
                        .setPower(value);
                  },
                ),
              ),
            ],
          ),

          SizedBox(height: spacing),

          // Brightness Slider
          BrightnessSlider(
            brightness: state.brightness,
            enabled: state.isOn,
            onChanged: (value) {
              ref
                  .read(lampStateProvider(widget.device.ipAddress).notifier)
                  .setBrightness(value);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPatternsTab(BuildContext context, LampState state) {
    final patterns = LampPattern.defaultPatterns;

    return Column(
      children: [
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.3,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: patterns.length,
            itemBuilder: (context, index) {
              final pattern = patterns[index];
              final isSelected = state.currentPattern?.id == pattern.id;

              return Stack(
                children: [
                  PatternCard(
                    pattern: pattern,
                    isSelected: isSelected,
                    isLampOn: state.isOn,
                    // Tap anywhere on tile (excluding on/off button) navigates to control page
                    onTap: state.isOn
                        ? () {
                            _navigateToPatternControl(context, pattern);
                          }
                        : null,
                    // On/off toggle button activates/deactivates the pattern
                    onToggle: state.isOn
                        ? () {
                            if (isSelected) {
                              // Turn off - you might want to switch to a default pattern
                              // or just keep current pattern but turn lamp off
                              // For now, we'll just keep the pattern selected
                            } else {
                              // Activate this pattern
                              ref
                                  .read(
                                    lampStateProvider(
                                      widget.device.ipAddress,
                                    ).notifier,
                                  )
                                  .setPattern(pattern);
                            }
                          }
                        : null,
                    onLongPress:
                        (pattern.id == 'yellow_night' ||
                                pattern.id == 'night_reading') &&
                            state.isOn
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => ReadingWarmthScreen(
                                  deviceIp: widget.device.ipAddress,
                                ),
                              ),
                            );
                          }
                        : null,
                    footer:
                        (pattern.id == 'yellow_night' ||
                            pattern.id == 'night_reading')
                        ? _buildInlineWarmthControl(context, state)
                        : null,
                  ),

                  if ((pattern.id == 'yellow_night' ||
                          pattern.id == 'night_reading') &&
                      isSelected)
                    Positioned(
                      top: 48, // Below the on/off toggle
                      right: 8,
                      child: Material(
                        color: Colors.transparent,
                        child: IconButton(
                          icon: const Icon(Icons.wb_incandescent),
                          color: Colors.white70,
                          tooltip: 'Adjust Warmth',
                          onPressed: state.isOn
                              ? () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => ReadingWarmthScreen(
                                        deviceIp: widget.device.ipAddress,
                                      ),
                                    ),
                                  );
                                }
                              : null,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
        // Show warmth controls when reading pattern is selected
        if (state.currentPattern?.index == 0)
          _buildReadingWarmthControls(context, state),
      ],
    );
  }

  /// Navigate to pattern-specific control screen
  void _navigateToPatternControl(BuildContext context, LampPattern pattern) {
    // Special handling for certain patterns
    if (pattern.id == 'yellow_night' || pattern.id == 'night_reading') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) =>
              ReadingWarmthScreen(deviceIp: widget.device.ipAddress),
        ),
      );
    } else {
      // Navigate to generic pattern control screen
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PatternControlScreen(
            deviceIp: widget.device.ipAddress,
            pattern: pattern,
          ),
        ),
      );
    }
  }

  Widget _buildReadingWarmthControls(BuildContext context, LampState state) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.wb_incandescent,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Reading Light Warmth',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.ac_unit, color: Colors.blue),
              Expanded(
                child: Slider(
                  value: state.readingWarmth.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '${state.readingWarmth}%',
                  onChanged: state.isOn
                      ? (value) {
                          ref
                              .read(
                                lampStateProvider(
                                  widget.device.ipAddress,
                                ).notifier,
                              )
                              .setReadingWarmth(value.round());
                        }
                      : null,
                ),
              ),
              const Icon(Icons.whatshot, color: Colors.orange),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cool White',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.blue),
              ),
              Text(
                'Warm Yellow',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.orange),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineWarmthControl(BuildContext context, LampState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.ac_unit, size: 14, color: Colors.blueAccent),
          const SizedBox(width: 6),
          Expanded(
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 8,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
                thumbColor: Colors.orangeAccent,
                activeTrackColor: Colors.orangeAccent,
                inactiveTrackColor: Colors.orangeAccent.withAlpha(80),
                valueIndicatorTextStyle: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                ),
              ),
              child: SizedBox(
                height: 40,
                child: Slider(
                  value: state.readingWarmth.toDouble(),
                  min: 0,
                  max: 100,
                  divisions: 100,
                  label: '${state.readingWarmth}%',
                  onChanged: state.isOn
                      ? (value) {
                          // Optimistic update via provider
                          ref
                              .read(
                                lampStateProvider(
                                  widget.device.ipAddress,
                                ).notifier,
                              )
                              .setReadingWarmth(value.round());
                        }
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),
          const Icon(Icons.whatshot, size: 14, color: Colors.orangeAccent),
        ],
      ),
    );
  }

  Widget _buildColorsTab(BuildContext context, LampState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Quick Colors
          Text(
            'Quick Colors',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildQuickColors(context, state),

          const SizedBox(height: 24),

          // Custom Colors
          Text(
            'Saved Colors',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildCustomColors(context, state),

          const SizedBox(height: 24),

          // Color Picker
          Text(
            'Color Wheel',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildColorPicker(context, state),
        ],
      ),
    );
  }

  Widget _buildQuickColors(BuildContext context, LampState state) {
    final quickColors = [
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
      Colors.cyan,
      Colors.blue,
      Colors.purple,
      Colors.pink,
      Colors.white,
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: quickColors.map((color) {
        final isSelected = _colorEquals(color, _getDisplayColor(state));
        return GestureDetector(
          onTap: state.isOn
              ? () {
                  ref
                      .read(lampStateProvider(widget.device.ipAddress).notifier)
                      .setColorWheel(color);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(color: Colors.white, width: 3)
                  : null,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(128),
                  blurRadius: isSelected ? 12 : 4,
                  spreadRadius: isSelected ? 2 : 0,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCustomColors(BuildContext context, LampState state) {
    final customColors = state.customColors;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ...customColors.map((custom) {
          return GestureDetector(
            onTap: state.isOn
                ? () {
                    ref
                        .read(
                          lampStateProvider(widget.device.ipAddress).notifier,
                        )
                        .setCustomColor(custom);
                  }
                : null,
            onLongPress: () => _showDeleteColorDialog(context, custom),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: custom.color,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: custom.color.withAlpha(128), blurRadius: 4),
                ],
              ),
              child: custom.name.isNotEmpty
                  ? Center(
                      child: Text(
                        custom.name[0].toUpperCase(),
                        style: TextStyle(
                          color: custom.color.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  : null,
            ),
          );
        }),
        // Add new color button
        GestureDetector(
          onTap: () => _showSaveColorDialog(context, state),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.grey,
                width: 2,
                style: BorderStyle.solid,
              ),
            ),
            child: const Icon(Icons.add, color: Colors.grey),
          ),
        ),
      ],
    );
  }

  Widget _buildColorPicker(BuildContext context, LampState state) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ColorPicker(
              pickerColor: _getDisplayColor(state),
              onColorChanged: state.isOn
                  ? (color) {
                      // Debounce color changes to avoid flooding the device
                      if (_colorDebounceTimer?.isActive ?? false) {
                        _colorDebounceTimer!.cancel();
                      }
                      _colorDebounceTimer = Timer(
                        const Duration(milliseconds: 200),
                        () {
                          ref
                              .read(
                                lampStateProvider(
                                  widget.device.ipAddress,
                                ).notifier,
                              )
                              .setColorWheel(color);
                        },
                      );
                    }
                  : (_) {},
              enableAlpha: false,
              hexInputBar: true,
              labelTypes: const [],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGyroTab(BuildContext context, LampState state) {
    final gyroState = state.gyroState;
    final isGyroAvailable = gyroState?.available ?? false;
    final isGyroEnabled = gyroState?.enabled ?? false;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gyro Enable Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.sensors,
                            color: isGyroEnabled
                                ? Theme.of(context).colorScheme.primary
                                : Colors.grey,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Gyro Mode',
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                isGyroAvailable
                                    ? (isGyroEnabled
                                          ? 'Motion control active'
                                          : 'MPU6050 ready')
                                    : 'MPU6050 not detected',
                                style: TextStyle(
                                  color: isGyroAvailable
                                      ? Colors.green
                                      : Colors.orange,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Switch(
                        value: isGyroEnabled,
                        onChanged: isGyroAvailable && state.isOn
                            ? (value) {
                                ref
                                    .read(
                                      lampStateProvider(
                                        widget.device.ipAddress,
                                      ).notifier,
                                    )
                                    .setGyroEnabled(value);
                              }
                            : null,
                      ),
                    ],
                  ),
                  if (!isGyroAvailable) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withAlpha(30),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.orange),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'MPU6050 sensor not detected. Please check hardware connections.',
                              style: TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Calibration Button - always visible
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.build_circle_outlined),
              label: const Text('Calibrate Sensor'),
              onPressed: () => _showCalibrationDialog(context),
            ),
          ),

          if (isGyroAvailable) ...[
            const SizedBox(height: 16),

            // Sensor Data Display
            if (isGyroEnabled) ...[
              _buildSensorDataCard(context, gyroState!),
              const SizedBox(height: 16),
            ],

            // Gyro Patterns
            Text(
              'Motion Patterns',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _buildGyroPatternGrid(context, state),
          ],
        ],
      ),
    );
  }

  void _showCalibrationDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          _CalibrationDialog(deviceIp: widget.device.ipAddress),
    );
  }

  Widget _buildSensorDataCard(BuildContext context, GyroState gyroState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Sensor Data',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    ref
                        .read(
                          lampStateProvider(widget.device.ipAddress).notifier,
                        )
                        .refreshGyroStatus();
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Orientation
            Row(
              children: [
                Expanded(
                  child: _buildSensorValue(
                    context,
                    'Pitch',
                    '${gyroState.pitch.toStringAsFixed(1)}°',
                    Icons.screen_rotation,
                  ),
                ),
                Expanded(
                  child: _buildSensorValue(
                    context,
                    'Roll',
                    '${gyroState.roll.toStringAsFixed(1)}°',
                    Icons.rotate_90_degrees_ccw,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Gesture Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getGestureColor(gyroState.gesture).withAlpha(30),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildGestureIndicator(
                    'Gesture',
                    gyroState.gesture.toUpperCase(),
                    _getGestureColor(gyroState.gesture),
                  ),
                  _buildGestureIndicator(
                    'Tilt',
                    gyroState.tiltDirectionName,
                    gyroState.isTilted ? Colors.blue : Colors.grey,
                  ),
                  _buildGestureIndicator(
                    'Shake',
                    gyroState.isShaking ? 'YES' : 'NO',
                    gyroState.isShaking ? Colors.orange : Colors.grey,
                  ),
                  _buildGestureIndicator(
                    'Flip',
                    gyroState.isFlipped ? 'YES' : 'NO',
                    gyroState.isFlipped ? Colors.purple : Colors.grey,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSensorValue(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, size: 20, color: Colors.grey),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildGestureIndicator(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: color,
            fontSize: 12,
          ),
        ),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 10)),
      ],
    );
  }

  Color _getGestureColor(String gesture) {
    switch (gesture) {
      case 'shake':
        return Colors.orange;
      case 'flip':
        return Colors.purple;
      case 'tilt_left':
      case 'tilt_right':
      case 'tilt_forward':
      case 'tilt_back':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  Widget _buildGyroPatternGrid(BuildContext context, LampState state) {
    final patterns = GyroPattern.defaultPatterns;
    final currentPattern = state.gyroState?.pattern ?? 0;
    final isEnabled = state.gyroState?.enabled ?? false;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: patterns.length,
      itemBuilder: (context, index) {
        final pattern = patterns[index];
        final isSelected = currentPattern == pattern.id;

        return GestureDetector(
          onTap: isEnabled && state.isOn
              ? () {
                  ref
                      .read(lampStateProvider(widget.device.ipAddress).notifier)
                      .setGyroPattern(pattern.id);
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? Theme.of(context).colorScheme.primary.withAlpha(30)
                  : Theme.of(context).cardColor,
              border: Border.all(
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey.withAlpha(50),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    _getPatternIcon(pattern.icon),
                    size: 28,
                    color: isSelected
                        ? Theme.of(context).colorScheme.primary
                        : (isEnabled ? Colors.grey.shade700 : Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    pattern.name,
                    style: TextStyle(
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isEnabled ? null : Colors.grey,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    pattern.description,
                    style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  IconData _getPatternIcon(String iconName) {
    switch (iconName) {
      case 'palette':
        return Icons.palette;
      case 'waves':
        return Icons.waves;
      case 'auto_awesome':
        return Icons.auto_awesome;
      case 'flip':
        return Icons.flip;
      case 'motion_photos_on':
        return Icons.motion_photos_on;
      case 'brightness_high':
        return Icons.brightness_high;
      case 'shuffle':
        return Icons.shuffle;
      case 'local_fire_department':
        return Icons.local_fire_department;
      default:
        return Icons.sensors;
    }
  }

  Widget _buildSettingsTab(BuildContext context, LampState state) {
    final wifiInfoAsync = ref.watch(wifiInfoProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Network Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Network',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                ..._buildNetworkInfoRows(state, wifiInfoAsync),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Device Controls
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.refresh),
                title: const Text('Refresh State'),
                subtitle: const Text('Sync with device'),
                onTap: () {
                  ref
                      .read(lampStateProvider(widget.device.ipAddress).notifier)
                      .initialize();
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: const Text('Restart Device'),
                subtitle: const Text('Reboot the lamp'),
                onTap: () => _confirmRestart(context),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(
                  Icons.wifi_protected_setup,
                  color: Colors.orange.shade700,
                ),
                title: const Text('WiFi Setup Mode'),
                subtitle: const Text('Re-configure WiFi'),
                onTap: () => _confirmWifiSetup(context),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Password
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Change Password'),
            subtitle: const Text('Update device password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showChangePasswordDialog(context),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(value),
        ],
      ),
    );
  }

  Color _getDisplayColor(LampState state) {
    if (state.currentPattern != null &&
        state.currentPattern!.colors.isNotEmpty) {
      return state.currentPattern!.colors.first;
    }
    return state.currentColor ?? Colors.white;
  }

  /// Get display name for current mode (Gyro or Pattern)
  String _getModeName(LampState state) {
    // If gyro is enabled, show gyro mode/pattern name
    if (state.gyroState?.enabled == true) {
      final gyroPatternName = state.gyroState?.patternName;
      if (gyroPatternName != null && gyroPatternName.isNotEmpty) {
        return 'Gyro: $gyroPatternName';
      }
      return 'Gyro Mode';
    }
    // Otherwise show current pattern name
    return state.currentPattern?.name ?? 'Solid Color';
  }

  bool _colorEquals(Color a, Color b) {
    return a.toARGB32() == b.toARGB32();
  }

  List<Widget> _buildNetworkInfoRows(
    LampState state,
    AsyncValue<WifiInfo?> wifiInfoAsync,
  ) {
    final deviceNet = state.networkInfo;
    final phoneWifi = wifiInfoAsync.asData?.value;

    final ssid = deviceNet?.ssid ?? phoneWifi?.ssid;
    final ip = deviceNet?.ipAddress ?? phoneWifi?.ipAddress;
    final rssi = deviceNet?.rssi;

    if (ssid == null && ip == null && rssi == null) {
      return const [Text('Network info unavailable')];
    }

    return [
      if (ssid != null) _buildInfoRow('SSID', ssid),
      if (ip != null) _buildInfoRow('IP Address', ip),
      if (rssi != null) _buildInfoRow('Signal', '$rssi dBm'),
      if (deviceNet == null && phoneWifi != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Using phone WiFi info',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey),
          ),
        ),
    ];
  }

  void _showDeviceInfo(
    BuildContext context,
    IoTDevice device,
    LampState? state,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Device Info'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Name', device.name),
            _buildInfoRow('IP', device.ipAddress),
            _buildInfoRow('Type', device.deviceType.displayName),
            if (device.firmwareVersion != null)
              _buildInfoRow('Firmware', device.firmwareVersion!),
            _buildInfoRow('Status', device.connectionStatus.name),
            if (device.lastSeen != null)
              _buildInfoRow('Last Seen', _formatDateTime(device.lastSeen!)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    return '${dt.month}/${dt.day} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
  }

  void _showSaveColorDialog(BuildContext context, LampState state) {
    final nameController = TextEditingController();
    Color selectedColor = _getDisplayColor(state);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Save Color'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: selectedColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: selectedColor.withAlpha(128),
                      blurRadius: 12,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Color Name (optional)',
                  hintText: 'e.g. "Sunset"',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final custom = CustomColor(
                  color: selectedColor,
                  name: nameController.text,
                );
                ref
                    .read(lampStateProvider(widget.device.ipAddress).notifier)
                    .setCustomColor(custom);
                Navigator.pop(context);
              },
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteColorDialog(BuildContext context, CustomColor color) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Color'),
        content: Text(
          'Delete "${color.name.isNotEmpty ? color.name : "this color"}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              // TODO: Implement delete color
              Navigator.pop(context);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _confirmRestart(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restart Device'),
        content: const Text('Are you sure you want to restart the lamp?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // TODO: Call restart API
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Restarting device...')),
              );
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  void _confirmWifiSetup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('WiFi Setup Mode'),
        content: const Text(
          'This will put the lamp into WiFi setup mode. '
          'You will need to reconnect to the lamp\'s access point to configure a new network.\n\n'
          'Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () {
              Navigator.pop(context);
              // TODO: Call WiFi setup API
            },
            child: const Text('Continue'),
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Change Password'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current Password'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: newController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New Password'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Confirm Password'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (newController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Passwords do not match'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              // TODO: Call change password API
              Navigator.pop(context);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}

class _CalibrationDialog extends ConsumerStatefulWidget {
  final String deviceIp;

  const _CalibrationDialog({required this.deviceIp});

  @override
  ConsumerState<_CalibrationDialog> createState() => _CalibrationDialogState();
}

class _CalibrationDialogState extends ConsumerState<_CalibrationDialog> {
  int _currentStep = 0;
  bool _isLoading = false;
  String? _error;

  final List<Map<String, String>> _steps = [
    {
      'id': 'center',
      'title': 'Step 1: Center',
      'instruction':
          'Place the lamp on a flat, level surface in its normal upright position.',
    },
    {
      'id': 'left',
      'title': 'Step 2: Left',
      'instruction':
          'Tilt the lamp 90 degrees to the LEFT (so it lies on its side).',
    },
    {
      'id': 'right',
      'title': 'Step 3: Right',
      'instruction': 'Tilt the lamp 90 degrees to the RIGHT.',
    },
    {
      'id': 'front',
      'title': 'Step 4: Front',
      'instruction': 'Tilt the lamp 90 degrees FORWARD (face down).',
    },
    {
      'id': 'back',
      'title': 'Step 5: Back',
      'instruction': 'Tilt the lamp 90 degrees BACKWARD (face up).',
    },
    {
      'id': 'save',
      'title': 'Step 6: Save',
      'instruction': 'Calibration data collected. Click Save to apply changes.',
    },
  ];

  Future<void> _performStep() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final stepId = _steps[_currentStep]['id']!;
      final success = await ref
          .read(lampStateProvider(widget.deviceIp).notifier)
          .calibrateGyro(stepId);

      if (success) {
        if (_currentStep < _steps.length - 1) {
          setState(() {
            _currentStep++;
          });
        } else {
          // Finished
          if (mounted) {
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Calibration completed successfully'),
              ),
            );
          }
        }
      } else {
        setState(() {
          _error = 'Failed to capture calibration data. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];
    final isLastStep = _currentStep == _steps.length - 1;

    return AlertDialog(
      title: Text(step['title']!),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else ...[
            Text(step['instruction']!),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _performStep,
          child: Text(isLastStep ? 'Save' : 'Next'),
        ),
      ],
    );
  }
}
