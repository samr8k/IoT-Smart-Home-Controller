import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/iot_device.dart';
import '../models/connection_status.dart';
import '../services/storage_service.dart';
import '../services/network_service.dart';
import '../services/lamp_api_service.dart';

/// Storage service provider
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService();
});

/// Network service provider
final networkServiceProvider = Provider<NetworkService>((ref) {
  final service = NetworkService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// WiFi info stream provider
final wifiInfoProvider = StreamProvider<WifiInfo?>((ref) {
  final networkService = ref.watch(networkServiceProvider);
  return networkService.wifiStream;
});

/// Devices state notifier - returns List<IoTDevice> directly
class DevicesNotifier extends StateNotifier<List<IoTDevice>> {
  final StorageService _storage;
  Timer? _refreshTimer;

  DevicesNotifier(this._storage) : super([]);

  /// Load devices from storage
  Future<void> loadDevices() async {
    try {
      final devices = _storage.getAllDevices();
      state = devices;
    } catch (e) {
      // Keep current state on error
    }
  }

  /// Add a new device
  Future<void> addDevice(IoTDevice device) async {
    await _storage.saveDevice(device);
    await loadDevices();
  }

  /// Remove a device
  Future<void> removeDevice(String id) async {
    await _storage.deleteDevice(id);
    await loadDevices();
  }

  /// Update device name
  Future<void> updateDeviceName(String id, String newName) async {
    final device = state.firstWhere((d) => d.id == id);
    final updated = IoTDevice(
      id: device.id,
      name: newName,
      ipAddress: device.ipAddress,
      deviceType: device.deviceType,
      connectionStatus: device.connectionStatus,
      firmwareVersion: device.firmwareVersion,
      lastSeen: device.lastSeen,
    );
    await _storage.saveDevice(updated);
    await loadDevices();
  }

  /// Update device connection status
  Future<void> updateDeviceStatus(String id, ConnectionStatus status) async {
    final device = state.firstWhere((d) => d.id == id);
    final updated = IoTDevice(
      id: device.id,
      name: device.name,
      ipAddress: device.ipAddress,
      deviceType: device.deviceType,
      connectionStatus: status,
      firmwareVersion: device.firmwareVersion,
      lastSeen: DateTime.now(),
    );
    await _storage.saveDevice(updated);
    await loadDevices();
  }

  /// Refresh all devices - check connectivity
  Future<void> refreshAllDevices() async {
    for (final device in state) {
      try {
        final api = LampApiService(device.ipAddress);
        final info = await api.getDeviceInfo();

        if (info != null) {
          await updateDeviceStatus(device.id, ConnectionStatus.connected);
        } else {
          await updateDeviceStatus(device.id, ConnectionStatus.disconnected);
        }
      } catch (e) {
        await updateDeviceStatus(device.id, ConnectionStatus.disconnected);
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Devices provider
final devicesProvider = StateNotifierProvider<DevicesNotifier, List<IoTDevice>>(
  (ref) {
    final storage = ref.watch(storageServiceProvider);
    return DevicesNotifier(storage);
  },
);

/// Single device provider
final deviceProvider = Provider.family<IoTDevice?, String>((ref, id) {
  final devices = ref.watch(devicesProvider);
  try {
    return devices.firstWhere((d) => d.id == id);
  } catch (e) {
    return null;
  }
});

/// Online devices count
final onlineDevicesCountProvider = Provider<int>((ref) {
  final devices = ref.watch(devicesProvider);
  return devices
      .where((d) => d.connectionStatus == ConnectionStatus.connected)
      .length;
});
