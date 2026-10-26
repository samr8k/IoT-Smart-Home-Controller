import 'device_type.dart';

/// Model for discovered devices during network scan
class DiscoveredDevice {
  final String id;
  final String name;
  final DeviceType deviceType;
  final String ipAddress;
  final int port;
  final String? firmwareVersion;
  final Map<String, String>? txtRecords;
  final DateTime discoveredAt;
  final bool requiresPassword;

  const DiscoveredDevice({
    required this.id,
    required this.name,
    required this.deviceType,
    required this.ipAddress,
    this.port = 80,
    this.firmwareVersion,
    this.txtRecords,
    required this.discoveredAt,
    this.requiresPassword = false,
  });

  factory DiscoveredDevice.fromMdns({
    required String serviceName,
    required String host,
    required int port,
    Map<String, String>? txtRecords,
  }) {
    return DiscoveredDevice(
      id: txtRecords?['id'] ?? serviceName,
      name: serviceName
          .replaceAll('._iot-lamp._tcp', '')
          .replaceAll('.local', ''),
      deviceType: DeviceType.fromString(txtRecords?['type'] ?? 'lamp'),
      ipAddress: host,
      port: port,
      firmwareVersion: txtRecords?['version'],
      txtRecords: txtRecords,
      discoveredAt: DateTime.now(),
      requiresPassword: txtRecords?['password'] == 'true',
    );
  }

  factory DiscoveredDevice.fromManualEntry({
    required String ipAddress,
    required String deviceType,
    int port = 80,
    String? deviceId,
    String? name,
    String? firmwareVersion,
  }) {
    return DiscoveredDevice(
      id: deviceId ?? 'manual_${ipAddress.replaceAll('.', '_')}',
      name: name ?? 'Device at $ipAddress',
      deviceType: DeviceType.fromString(deviceType),
      ipAddress: ipAddress,
      port: port,
      firmwareVersion: firmwareVersion,
      discoveredAt: DateTime.now(),
      requiresPassword: true, // Smart lamps require password
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'deviceType': deviceType.name,
      'ipAddress': ipAddress,
      'port': port,
      'firmwareVersion': firmwareVersion,
      'txtRecords': txtRecords,
      'discoveredAt': discoveredAt.toIso8601String(),
      'requiresPassword': requiresPassword,
    };
  }

  @override
  String toString() {
    return 'DiscoveredDevice(id: $id, name: $name, ip: $ipAddress, type: $deviceType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DiscoveredDevice &&
        other.ipAddress == ipAddress &&
        other.port == port;
  }

  @override
  int get hashCode => ipAddress.hashCode ^ port.hashCode;
}
