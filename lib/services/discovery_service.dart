import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../models/models.dart';

/// Service for discovering IoT devices on the local network
class DiscoveryService {
  final List<DiscoveredDevice> _discoveredDevices = [];
  bool _isScanning = false;
  Function(DiscoveredDevice)? _onDeviceFound;

  /// List of currently discovered devices
  List<DiscoveredDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  /// Whether currently scanning
  bool get isScanning => _isScanning;

  /// Start scanning for IoT devices
  Future<void> startDiscovery({
    required Function(DiscoveredDevice) onDeviceFound,
  }) async {
    if (_isScanning) return;

    _isScanning = true;
    _discoveredDevices.clear();
    _onDeviceFound = onDeviceFound;

    try {
      // Try mDNS discovery first
      await _scanMdns();

      // Also do IP range scan for devices that don't advertise via mDNS
      await _scanIpRange();
    } catch (e) {
      debugPrint('Discovery error: $e');
    }
  }

  /// Scan for devices via mDNS
  Future<void> _scanMdns() async {
    // mDNS implementation placeholder
    // The nsd package requires platform-specific setup
    // For simplicity, we rely on IP scanning
  }

  /// Scan IP range for devices
  Future<void> _scanIpRange() async {
    // Get local IP to determine subnet
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );

    for (final interface in interfaces) {
      for (final addr in interface.addresses) {
        if (!addr.isLoopback) {
          final subnet = addr.address.substring(
            0,
            addr.address.lastIndexOf('.'),
          );
          await _scanSubnet(subnet);
        }
      }
    }
  }

  /// Scan a subnet for devices
  Future<void> _scanSubnet(String subnet) async {
    final futures = <Future<void>>[];

    for (int i = 1; i < 255; i++) {
      final ip = '$subnet.$i';
      futures.add(_checkDevice(ip));
    }

    // Run in batches to avoid overwhelming the network
    for (int i = 0; i < futures.length; i += 25) {
      final batch = futures.skip(i).take(25);
      await Future.wait(batch);
      if (!_isScanning) break;
    }
  }

  /// Check if an IP has an IoT device
  Future<void> _checkDevice(String ip) async {
    if (!_isScanning) return;

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout =
            const Duration(milliseconds: 2000) // Increased from 800ms
        ..idleTimeout = const Duration(milliseconds: 2000);

      debugPrint('Checking device at: $ip');

      final request = await client.getUrl(Uri.parse('http://$ip/info'));
      request.headers.add('Accept', 'application/json');

      final response = await request.close();

      debugPrint('Response from $ip: ${response.statusCode}');

      if (response.statusCode == 200) {
        // Parse the response to get device info
        final responseBody = await response.transform(utf8.decoder).join();
        debugPrint('Response body from $ip: $responseBody');

        Map<String, dynamic>? deviceInfo;
        String deviceType = 'smart_lamp';
        String? deviceId;
        String? deviceName;
        String? firmwareVersion;

        try {
          deviceInfo = jsonDecode(responseBody) as Map<String, dynamic>;
          deviceType = deviceInfo['type'] ?? 'smart_lamp';
          deviceId = deviceInfo['id'];
          deviceName = deviceInfo['name'];
          firmwareVersion = deviceInfo['version'];
          debugPrint(
            'Parsed device info: type=$deviceType, id=$deviceId, name=$deviceName',
          );
        } catch (e) {
          // JSON parsing failed, use defaults
          debugPrint('JSON parsing error for $ip: $e');
        }

        // Device responded - add it
        final device = DiscoveredDevice.fromManualEntry(
          ipAddress: ip,
          deviceType: deviceType,
          port: 80,
          deviceId: deviceId,
          name: deviceName,
          firmwareVersion: firmwareVersion,
        );

        _handleDeviceFound(device);
      }
      client.close();
    } catch (e) {
      // Device not found at this IP
      debugPrint('Error checking $ip: $e');
    } finally {
      client?.close(force: true);
    }
  }

  /// Handle found device
  void _handleDeviceFound(DiscoveredDevice device) {
    // Avoid duplicates
    if (!_discoveredDevices.any((d) => d.ipAddress == device.ipAddress)) {
      _discoveredDevices.add(device);
      _onDeviceFound?.call(device);
    }
  }

  /// Stop scanning
  void stopDiscovery() {
    _isScanning = false;
  }

  /// Add device manually by IP address
  Future<DiscoveredDevice?> addDeviceManually(
    String ipAddress, {
    int port = 80,
    String deviceType = 'smart_lamp',
  }) async {
    final device = DiscoveredDevice.fromManualEntry(
      ipAddress: ipAddress,
      deviceType: deviceType,
      port: port,
    );

    if (!_discoveredDevices.any((d) => d.ipAddress == ipAddress)) {
      _discoveredDevices.add(device);
      _onDeviceFound?.call(device);
    }

    return device;
  }

  /// Clear discovered devices
  void clearDevices() {
    _discoveredDevices.clear();
  }
}

/// Simplified discovery service that works with manual IP entry
/// This is a fallback when mDNS is not available
class SimpleDiscoveryService {
  final List<DiscoveredDevice> _discoveredDevices = [];
  final _streamController =
      StreamController<List<DiscoveredDevice>>.broadcast();

  Stream<List<DiscoveredDevice>> get devicesStream => _streamController.stream;
  List<DiscoveredDevice> get discoveredDevices =>
      List.unmodifiable(_discoveredDevices);

  /// Add device by IP address after verification
  void addDevice(DiscoveredDevice device) {
    if (!_discoveredDevices.any((d) => d.ipAddress == device.ipAddress)) {
      _discoveredDevices.add(device);
      _streamController.add(List.unmodifiable(_discoveredDevices));
    }
  }

  /// Remove device
  void removeDevice(String ipAddress) {
    _discoveredDevices.removeWhere((d) => d.ipAddress == ipAddress);
    _streamController.add(List.unmodifiable(_discoveredDevices));
  }

  /// Clear all devices
  void clear() {
    _discoveredDevices.clear();
    _streamController.add(List.unmodifiable(_discoveredDevices));
  }

  void dispose() {
    _streamController.close();
  }
}

// Placeholder for nsd package classes if not available
class Discovery {
  static Future<Discovery> get instance async => Discovery._();
  Discovery._();

  Future<void> start(String serviceType) async {}
  Future<void> stop() async {}
  void addServiceListener(void Function(Service, ServiceStatus) listener) {}
}

class Service {
  final String? name;
  final String? host;
  final int? port;
  final Map<String, String>? txt;

  Service({this.name, this.host, this.port, this.txt});
}

enum ServiceStatus { found, lost }
