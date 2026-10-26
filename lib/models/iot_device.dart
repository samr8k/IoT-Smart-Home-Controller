import 'package:hive/hive.dart';
import 'device_type.dart';
import 'connection_status.dart';

/// Base model for all IoT devices
@HiveType(typeId: 0)
class IoTDevice extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String name;

  @HiveField(2)
  final String ipAddress;

  @HiveField(3)
  final DeviceType deviceType;

  @HiveField(4)
  final ConnectionStatus connectionStatus;

  @HiveField(5)
  final String? firmwareVersion;

  @HiveField(6)
  final DateTime? lastSeen;

  IoTDevice({
    required this.id,
    required this.name,
    required this.ipAddress,
    required this.deviceType,
    required this.connectionStatus,
    this.firmwareVersion,
    this.lastSeen,
  });

  IoTDevice copyWith({
    String? id,
    String? name,
    String? ipAddress,
    DeviceType? deviceType,
    ConnectionStatus? connectionStatus,
    String? firmwareVersion,
    DateTime? lastSeen,
  }) {
    return IoTDevice(
      id: id ?? this.id,
      name: name ?? this.name,
      ipAddress: ipAddress ?? this.ipAddress,
      deviceType: deviceType ?? this.deviceType,
      connectionStatus: connectionStatus ?? this.connectionStatus,
      firmwareVersion: firmwareVersion ?? this.firmwareVersion,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }

  @override
  String toString() {
    return 'IoTDevice(id: $id, name: $name, ip: $ipAddress, type: ${deviceType.name})';
  }
}

/// Manual Hive adapter for IoTDevice
class IoTDeviceAdapter extends TypeAdapter<IoTDevice> {
  @override
  final int typeId = 0;

  @override
  IoTDevice read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return IoTDevice(
      id: fields[0] as String,
      name: fields[1] as String,
      ipAddress: fields[2] as String,
      deviceType: DeviceType.fromString(fields[3] as String? ?? 'lamp'),
      connectionStatus: ConnectionStatus.fromString(
        fields[4] as String? ?? 'disconnected',
      ),
      firmwareVersion: fields[5] as String?,
      lastSeen: fields[6] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, IoTDevice obj) {
    writer
      ..writeByte(7)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.ipAddress)
      ..writeByte(3)
      ..write(obj.deviceType.name)
      ..writeByte(4)
      ..write(obj.connectionStatus.name)
      ..writeByte(5)
      ..write(obj.firmwareVersion)
      ..writeByte(6)
      ..write(obj.lastSeen);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IoTDeviceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
