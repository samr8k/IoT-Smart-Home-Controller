import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discovered_device.dart';
import '../models/device_type.dart';
import '../models/connection_status.dart';
import '../models/iot_device.dart';
import '../providers/device_provider.dart';
import '../services/discovery_service.dart';
import '../services/lamp_api_service.dart';
import '../services/lock_api_service.dart';

/// Provider for discovered devices during scanning
final discoveredDevicesProvider = StateProvider<List<DiscoveredDevice>>(
  (ref) => [],
);

/// Provider for scanning state
final isScanningProvider = StateProvider<bool>((ref) => false);

class DiscoveryScreen extends ConsumerStatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  ConsumerState<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends ConsumerState<DiscoveryScreen>
    with SingleTickerProviderStateMixin {
  final _discoveryService = DiscoveryService();
  final _manualIpController = TextEditingController();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();

    // Start scanning when screen opens
    Future.microtask(() => _startScan());
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _manualIpController.dispose();
    _discoveryService.stopDiscovery();
    super.dispose();
  }

  Future<void> _startScan() async {
    ref.read(isScanningProvider.notifier).state = true;
    ref.read(discoveredDevicesProvider.notifier).state = [];

    await _discoveryService.startDiscovery(
      onDeviceFound: (device) {
        final devices = ref.read(discoveredDevicesProvider);
        // Check if device already exists
        if (!devices.any((d) => d.ipAddress == device.ipAddress)) {
          ref.read(discoveredDevicesProvider.notifier).state = [
            ...devices,
            device,
          ];
        }
      },
    );

    // Stop after 10 seconds
    await Future.delayed(const Duration(seconds: 10));
    _discoveryService.stopDiscovery();
    ref.read(isScanningProvider.notifier).state = false;
  }

  @override
  Widget build(BuildContext context) {
    final discoveredDevices = ref.watch(discoveredDevicesProvider);
    final isScanning = ref.watch(isScanningProvider);
    final existingDevices = ref.watch(devicesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover Devices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Manual IP',
            onPressed: () => _showManualIpDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Scanning indicator
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: isScanning ? 80 : 0,
            child: isScanning
                ? _buildScanningIndicator()
                : const SizedBox.shrink(),
          ),

          // Results
          Expanded(
            child: discoveredDevices.isEmpty
                ? _buildEmptyState(context, isScanning)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: discoveredDevices.length,
                    itemBuilder: (context, index) {
                      final device = discoveredDevices[index];
                      final isAlreadyAdded = existingDevices.any(
                        (d) => d.ipAddress == device.ipAddress,
                      );
                      return _buildDeviceCard(context, device, isAlreadyAdded);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: isScanning ? null : _startScan,
        child: isScanning
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.refresh),
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Theme.of(context).primaryColor.withAlpha(
                    (50 + (100 * _pulseController.value)).toInt(),
                  ),
                ),
                child: Icon(
                  Icons.wifi_find,
                  color: Theme.of(context).primaryColor,
                ),
              );
            },
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Scanning for devices...',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Text(
                  'Looking for IoT devices on your network',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isScanning) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            isScanning ? Icons.radar : Icons.search_off,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            isScanning ? 'Scanning...' : 'No devices found',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 8),
          Text(
            isScanning
                ? 'This may take a few seconds'
                : 'Make sure your devices are powered on\nand connected to the same WiFi network',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade500),
          ),
          if (!isScanning) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => _showManualIpDialog(context),
              icon: const Icon(Icons.edit),
              label: const Text('Enter IP Manually'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDeviceCard(
    BuildContext context,
    DiscoveredDevice device,
    bool isAlreadyAdded,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: device.deviceType.color.withAlpha(51),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(device.deviceType.icon, color: device.deviceType.color),
        ),
        title: Text(device.name),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(device.ipAddress),
            if (device.firmwareVersion != null)
              Text(
                'Firmware: ${device.firmwareVersion}',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
          ],
        ),
        trailing: isAlreadyAdded
            ? Chip(
                label: const Text('Added'),
                backgroundColor: Colors.green.withAlpha(51),
                labelStyle: const TextStyle(color: Colors.green),
              )
            : ElevatedButton(
                onPressed: () => _addDevice(context, device),
                child: const Text('Add'),
              ),
        onTap: isAlreadyAdded ? null : () => _addDevice(context, device),
      ),
    );
  }

  Future<void> _addDevice(BuildContext context, DiscoveredDevice device) async {
    // Check if device requires password
    if (device.requiresPassword) {
      final password = await _showPasswordDialog(context, device);
      if (password == null) return;

      // Verify password
      bool isValid = false;
      if (device.deviceType == DeviceType.lock) {
        final api = LockApiService(device.ipAddress);
        isValid = await api.authenticate(password);
      } else {
        final api = LampApiService(device.ipAddress);
        isValid = await api.verifyPassword(password);
      }

      if (!isValid) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Incorrect password'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Store password
      final storage = ref.read(storageServiceProvider);
      await storage.setDevicePassword(device.ipAddress, password);
    }

    // Create and add device
    final newDevice = IoTDevice(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: device.name,
      ipAddress: device.ipAddress,
      deviceType: device.deviceType,
      connectionStatus: ConnectionStatus.connected,
      firmwareVersion: device.firmwareVersion,
      lastSeen: DateTime.now(),
    );

    ref.read(devicesProvider.notifier).addDevice(newDevice);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${device.name} added successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<String?> _showPasswordDialog(
    BuildContext context,
    DiscoveredDevice device,
  ) async {
    final controller = TextEditingController();
    bool obscureText = true;

    return showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Device Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Enter the password for ${device.name}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                obscureText: obscureText,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: IconButton(
                    icon: Icon(
                      obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: () => setState(() => obscureText = !obscureText),
                  ),
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
              onPressed: () => Navigator.pop(context, controller.text),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }

  void _showManualIpDialog(BuildContext context) {
    _manualIpController.clear();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Manual IP Entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter the IP address of your IoT device'),
            const SizedBox(height: 16),
            TextField(
              controller: _manualIpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'IP Address',
                hintText: '192.168.1.100',
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
            onPressed: () => _connectManualIp(context),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectManualIp(BuildContext context) async {
    final ip = _manualIpController.text.trim();
    if (ip.isEmpty) return;

    Navigator.pop(context);

    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 16),
            Text('Connecting to $ip...'),
          ],
        ),
        duration: const Duration(seconds: 10),
      ),
    );

    // Try to connect
    final api = LampApiService(ip);
    final info = await api.getDeviceInfo();

    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    if (info != null) {
      final discovered = DiscoveredDevice(
        id: info['id'] ?? 'manual_${ip.replaceAll('.', '_')}',
        name: info['name'] ?? 'Smart Lamp',
        ipAddress: ip,
        deviceType: DeviceType.fromString(info['type'] ?? 'smart_lamp'),
        firmwareVersion:
            info['version'], // Firmware uses 'version' not 'firmware'
        requiresPassword:
            info['requiresAuth'] == true, // Firmware uses 'requiresAuth'
        discoveredAt: DateTime.now(),
      );

      final devices = ref.read(discoveredDevicesProvider);
      if (!devices.any((d) => d.ipAddress == ip)) {
        ref.read(discoveredDevicesProvider.notifier).state = [
          ...devices,
          discovered,
        ];
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Found ${discovered.name}!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not connect to $ip'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
