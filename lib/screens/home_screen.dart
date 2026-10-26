import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/device_provider.dart';
import '../providers/theme_provider.dart';
import '../models/iot_device.dart';
import '../models/device_type.dart';
import '../models/connection_status.dart';
import '../widgets/device_tile.dart';
import '../widgets/wifi_info_card.dart';
import '../devices/lamp/lamp.dart';
import 'discovery_screen.dart';
import 'lock_control_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  void initState() {
    super.initState();
    // Load devices when screen initializes
    Future.microtask(() {
      ref.read(devicesProvider.notifier).loadDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final devices = ref.watch(devicesProvider);
    final wifiInfo = ref.watch(wifiInfoProvider);
    final themeMode = ref.watch(themeModeProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('IoT Controller'),
        actions: [
          // Theme toggle
          IconButton(
            icon: Icon(
              themeMode == ThemeMode.dark ? Icons.light_mode : Icons.dark_mode,
            ),
            onPressed: () {
              ref
                  .read(themeModeProvider.notifier)
                  .state = themeMode == ThemeMode.dark
                  ? ThemeMode.light
                  : ThemeMode.dark;
            },
          ),
          // Settings
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => _showSettings(context),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await ref.read(devicesProvider.notifier).refreshAllDevices();
        },
        child: CustomScrollView(
          slivers: [
            // WiFi Info Card
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: WifiInfoCard(wifiInfo: wifiInfo),
              ),
            ),

            // Devices Section Header
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Devices',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${devices.length} device${devices.length == 1 ? '' : 's'}',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            // Devices Grid
            devices.isEmpty
                ? SliverFillRemaining(child: _buildEmptyState(context))
                : SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.85,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        final device = devices[index];
                        return DeviceTile(
                          device: device,
                          onTap: () => _navigateToDevice(context, device),
                          onLongPress: () =>
                              _showDeviceOptions(context, device),
                        );
                      }, childCount: devices.length),
                    ),
                  ),

            // Bottom spacing
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _navigateToDiscovery(context),
        icon: const Icon(Icons.add),
        label: const Text('Add Device'),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.devices_other, size: 80, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No devices yet',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the button below to add your first device',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navigateToDiscovery(context),
            icon: const Icon(Icons.search),
            label: const Text('Discover Devices'),
          ),
        ],
      ),
    );
  }

  void _navigateToDiscovery(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const DiscoveryScreen()),
    );
  }

  void _navigateToDevice(BuildContext context, IoTDevice device) {
    if (device.deviceType == DeviceType.lamp) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LampControlScreen(device: device),
        ),
      );
    } else if (device.deviceType == DeviceType.lock) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LockControlScreen(device: device),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${device.deviceType.displayName} control coming soon!',
          ),
        ),
      );
    }
  }

  void _showDeviceOptions(BuildContext context, IoTDevice device) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Name'),
              onTap: () {
                Navigator.pop(context);
                _showEditNameDialog(context, device);
              },
            ),
            ListTile(
              leading: const Icon(Icons.refresh),
              title: const Text('Reconnect'),
              onTap: () {
                Navigator.pop(context);
                ref
                    .read(devicesProvider.notifier)
                    .updateDeviceStatus(device.id, ConnectionStatus.connecting);
                // Try to reconnect
                Future.delayed(const Duration(seconds: 2), () {
                  ref.read(devicesProvider.notifier).refreshAllDevices();
                });
              },
            ),
            ListTile(
              leading: Icon(Icons.delete, color: Colors.red.shade400),
              title: Text(
                'Remove Device',
                style: TextStyle(color: Colors.red.shade400),
              ),
              onTap: () {
                Navigator.pop(context);
                _showRemoveConfirmation(context, device);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNameDialog(BuildContext context, IoTDevice device) {
    final controller = TextEditingController(text: device.name);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Device Name'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Device Name'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref
                    .read(devicesProvider.notifier)
                    .updateDeviceName(device.id, controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context, IoTDevice device) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Device'),
        content: Text(
          'Are you sure you want to remove "${device.name}"?\n\n'
          'You can add it again later from the discovery screen.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              ref.read(devicesProvider.notifier).removeDevice(device.id);
              Navigator.pop(context);
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('About'),
              onTap: () {
                Navigator.pop(context);
                showAboutDialog(
                  context: context,
                  applicationName: 'IoT Device Controller',
                  applicationVersion: '1.0.0',
                  applicationLegalese: '© 2024 IoT Controller',
                  children: [
                    const SizedBox(height: 16),
                    const Text(
                      'A universal IoT device controller app for managing '
                      'smart home devices.',
                    ),
                  ],
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bug_report),
              title: const Text('Debug Info'),
              onTap: () {
                Navigator.pop(context);
                _showDebugInfo(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showDebugInfo(BuildContext context) {
    final devices = ref.read(devicesProvider);
    final wifiInfo = ref.read(wifiInfoProvider);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              wifiInfo.when(
                data: (info) => Text(
                  'WiFi: ${info?.ssid ?? 'Not connected'}\n'
                  'IP: ${info?.ipAddress ?? 'N/A'}',
                ),
                loading: () => const Text('Loading WiFi info...'),
                error: (e, _) => Text('WiFi Error: $e'),
              ),
              const SizedBox(height: 16),
              Text('Devices: ${devices.length}'),
              ...devices.map(
                (d) => Text(
                  '• ${d.name} (${d.ipAddress}) - ${d.connectionStatus.name}',
                ),
              ),
            ],
          ),
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
}
