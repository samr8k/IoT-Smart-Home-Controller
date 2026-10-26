import 'package:flutter/material.dart';

/// Enum representing different types of IoT devices supported by the app
enum DeviceType {
  lamp('smart_lamp', 'Smart Lamp', Icons.lightbulb, Colors.amber),
  lock('smart_lock', 'Smart Lock', Icons.lock, Colors.blue),
  fan('smart_fan', 'Smart Fan', Icons.air, Colors.cyan),
  thermostat('thermostat', 'Thermostat', Icons.thermostat, Colors.orange),
  switch_('smart_switch', 'Smart Switch', Icons.power, Colors.green),
  sensor('sensor', 'Sensor', Icons.sensors, Colors.purple),
  unknown('unknown', 'Unknown Device', Icons.device_unknown, Colors.grey);

  final String id;
  final String displayName;
  final IconData icon;
  final Color color;

  const DeviceType(this.id, this.displayName, this.icon, this.color);

  /// Get DeviceType from string ID
  static DeviceType fromId(String id) {
    return DeviceType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => DeviceType.unknown,
    );
  }

  /// Get DeviceType from string name
  static DeviceType fromString(String name) {
    final lowered = name.toLowerCase();
    if (lowered.contains('lamp') || lowered.contains('light')) {
      return DeviceType.lamp;
    }
    if (lowered.contains('lock') || lowered.contains('rfid')) {
      return DeviceType.lock;
    }
    if (lowered.contains('fan')) {
      return DeviceType.fan;
    }
    if (lowered.contains('thermostat') || lowered.contains('temp')) {
      return DeviceType.thermostat;
    }
    if (lowered.contains('switch')) {
      return DeviceType.switch_;
    }
    if (lowered.contains('sensor')) {
      return DeviceType.sensor;
    }
    return DeviceType.unknown;
  }

  /// Get the mDNS service type for discovery
  String get mdnsServiceType {
    switch (this) {
      case DeviceType.lamp:
        return '_iot-lamp._tcp';
      case DeviceType.lock:
        return '_iot-lock._tcp';
      case DeviceType.fan:
        return '_iot-fan._tcp';
      case DeviceType.thermostat:
        return '_iot-thermostat._tcp';
      case DeviceType.switch_:
        return '_iot-switch._tcp';
      case DeviceType.sensor:
        return '_iot-sensor._tcp';
      default:
        return '_iot-device._tcp';
    }
  }
}
