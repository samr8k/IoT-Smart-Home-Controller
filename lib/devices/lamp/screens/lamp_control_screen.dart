import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../../../models/iot_device.dart';
import '../../../models/lamp_pattern.dart' as app_pattern;
import '../../../providers/device_provider.dart';
import '../../../screens/pattern_control_screen.dart';
import '../../../widgets/brightness_slider.dart';
import '../../../widgets/connection_status_indicator.dart';
import '../../../widgets/pattern_card.dart';
import '../lamp_models.dart';
import '../lamp_provider.dart';

class LampControlScreen extends ConsumerStatefulWidget {
  final IoTDevice device;

  const LampControlScreen({super.key, required this.device});

  @override
  ConsumerState<LampControlScreen> createState() => _LampControlScreenState();
}

class _LampControlScreenState extends ConsumerState<LampControlScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Initialize lamp state
    Future.microtask(() {
      ref
          .read(lampStateProvider(widget.device.ipAddress).notifier)
          .initialize();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lampState = ref.watch(lampStateProvider(widget.device.ipAddress));
    final device = ref
        .watch(devicesProvider)
        .firstWhere(
          (d) => d.id == widget.device.id,
          orElse: () => widget.device,
        );

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
    return Container(
      padding: const EdgeInsets.all(16),
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
        children: [
          // Power Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state.isOn
                          ? _getDisplayColor(state).withAlpha(51)
                          : Colors.grey.withAlpha(51),
                      boxShadow: state.isOn
                          ? [
                              BoxShadow(
                                color: _getDisplayColor(state).withAlpha(102),
                                blurRadius: 20,
                                spreadRadius: 5,
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      Icons.lightbulb,
                      size: 32,
                      color: state.isOn ? _getDisplayColor(state) : Colors.grey,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.isOn ? 'ON' : 'OFF',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        state.currentPattern?.name ?? 'Custom Color',
                        style: Theme.of(
                          context,
                        ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
              Transform.scale(
                scale: 1.3,
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

          const SizedBox(height: 16),

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

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.1,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: patterns.length,
      itemBuilder: (context, index) {
        final pattern = patterns[index];
        final isSelected = state.currentPattern?.id == pattern.id && state.isOn;

        // Convert to app_pattern.LampPattern for PatternControlScreen
        final appPattern = app_pattern.LampPattern.getByIndex(pattern.index);

        return PatternCard(
          pattern:
              appPattern ??
              app_pattern.LampPattern(
                index: pattern.index,
                id: pattern.id,
                name: pattern.name,
                description: pattern.description,
                icon: pattern.icon,
                colors: pattern.colors,
                isAnimated: pattern.isAnimated,
              ),
          isSelected: isSelected,
          isLampOn: state.isOn,
          onTap: () {
            // Navigate to pattern control screen for configuration
            if (appPattern != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => PatternControlScreen(
                    deviceIp: widget.device.ipAddress,
                    pattern: appPattern,
                  ),
                ),
              );
            }
          },
          onToggle: () {
            // Toggle this pattern on/off
            if (isSelected) {
              // If this pattern is active, turn lamp off
              ref
                  .read(lampStateProvider(widget.device.ipAddress).notifier)
                  .setPower(false);
            } else {
              // Activate this pattern and turn lamp on
              ref
                  .read(lampStateProvider(widget.device.ipAddress).notifier)
                  .setPattern(pattern);
              if (!state.isOn) {
                ref
                    .read(lampStateProvider(widget.device.ipAddress).notifier)
                    .setPower(true);
              }
            }
          },
        );
      },
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
                      ref
                          .read(
                            lampStateProvider(widget.device.ipAddress).notifier,
                          )
                          .setColorWheel(color);
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
    final gyroPatterns = GyroPattern.patterns;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Gyro Enable/Disable Card
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
                          color: gyroState?.enabled == true
                              ? Colors.green
                              : Colors.grey,
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Motion Control',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              gyroState?.available == true
                                  ? 'Gyroscope available'
                                  : 'Gyroscope not detected',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: gyroState?.enabled ?? false,
                      onChanged: (gyroState?.available ?? false)
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
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Gyro Patterns
        Text(
          'Motion Patterns',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1.5,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: gyroPatterns.length,
          itemBuilder: (context, index) {
            final pattern = gyroPatterns[index];
            final isSelected = gyroState?.pattern == pattern.index;

            return GestureDetector(
              onTap: (gyroState?.enabled ?? false)
                  ? () {
                      ref
                          .read(
                            lampStateProvider(widget.device.ipAddress).notifier,
                          )
                          .setGyroPattern(pattern.index);
                    }
                  : null,
              child: Card(
                color: isSelected
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        pattern.icon,
                        size: 28,
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : (gyroState?.enabled ?? false)
                            ? null
                            : Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pattern.name,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: (gyroState?.enabled ?? false)
                              ? null
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),

        const SizedBox(height: 24),

        // Sensor Data
        if (gyroState?.enabled == true && gyroState?.available == true) ...[
          Text(
            'Sensor Data',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildInfoRow(
                    'Pitch',
                    '${gyroState!.pitch.toStringAsFixed(1)}°',
                  ),
                  _buildInfoRow(
                    'Roll',
                    '${gyroState.roll.toStringAsFixed(1)}°',
                  ),
                  _buildInfoRow('Tilt Direction', gyroState.tiltDirectionName),
                  const Divider(),
                  _buildInfoRow('Gesture', gyroState.gesture),
                  _buildInfoRow('Shaking', gyroState.isShaking ? 'Yes' : 'No'),
                  _buildInfoRow('Tilted', gyroState.isTilted ? 'Yes' : 'No'),
                  _buildInfoRow('Flipped', gyroState.isFlipped ? 'Yes' : 'No'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () {
              ref
                  .read(lampStateProvider(widget.device.ipAddress).notifier)
                  .refreshGyroStatus();
            },
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh Sensor Data'),
          ),
        ],
      ],
    );
  }

  Widget _buildSettingsTab(BuildContext context, LampState state) {
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
                if (state.networkInfo != null) ...[
                  _buildInfoRow('SSID', state.networkInfo!.ssid),
                  _buildInfoRow('IP Address', state.networkInfo!.ipAddress),
                  _buildInfoRow('Signal', '${state.networkInfo!.rssi} dBm'),
                ] else ...[
                  _buildInfoRow('IP Address', widget.device.ipAddress),
                  const Text('Additional network info unavailable'),
                ],
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Device Actions
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

  bool _colorEquals(Color a, Color b) {
    return a.toARGB32() == b.toARGB32();
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
              ref
                  .read(lampStateProvider(widget.device.ipAddress).notifier)
                  .deleteCustomColor(color);
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
              Navigator.pop(context);
            },
            child: const Text('Change'),
          ),
        ],
      ),
    );
  }
}
