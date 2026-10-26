import 'dart:ui';
import 'lamp_pattern.dart';

/// Model representing the current state of a smart lamp
class LampState {
  final bool isOn;
  final int brightness;
  final int readingWarmth;
  final LampPattern? currentPattern;
  final Color? currentColor;
  final List<CustomColor> customColors;
  final NetworkInfo? networkInfo;
  final GyroState? gyroState;

  const LampState({
    required this.isOn,
    required this.brightness,
    this.readingWarmth = 50,
    this.currentPattern,
    this.currentColor,
    this.customColors = const [],
    this.networkInfo,
    this.gyroState,
  });

  LampState copyWith({
    bool? isOn,
    int? brightness,
    int? readingWarmth,
    LampPattern? currentPattern,
    Color? currentColor,
    List<CustomColor>? customColors,
    NetworkInfo? networkInfo,
    GyroState? gyroState,
  }) {
    return LampState(
      isOn: isOn ?? this.isOn,
      brightness: brightness ?? this.brightness,
      readingWarmth: readingWarmth ?? this.readingWarmth,
      currentPattern: currentPattern ?? this.currentPattern,
      currentColor: currentColor ?? this.currentColor,
      customColors: customColors ?? this.customColors,
      networkInfo: networkInfo ?? this.networkInfo,
      gyroState: gyroState ?? this.gyroState,
    );
  }
}

/// Gyroscope/motion sensor state
class GyroState {
  final bool enabled;
  final bool available;
  final int pattern;
  final String patternName;
  final double pitch;
  final double roll;
  final double accX;
  final double accY;
  final double accZ;
  final String gesture;
  final bool isShaking;
  final bool isTilted;
  final bool isFlipped;
  final int tiltDirection;

  const GyroState({
    this.enabled = false,
    this.available = false,
    this.pattern = 0,
    this.patternName = '',
    this.pitch = 0,
    this.roll = 0,
    this.accX = 0,
    this.accY = 0,
    this.accZ = 0,
    this.gesture = 'none',
    this.isShaking = false,
    this.isTilted = false,
    this.isFlipped = false,
    this.tiltDirection = 0,
  });

  GyroState copyWith({
    bool? enabled,
    bool? available,
    int? pattern,
    String? patternName,
    double? pitch,
    double? roll,
    double? accX,
    double? accY,
    double? accZ,
    String? gesture,
    bool? isShaking,
    bool? isTilted,
    bool? isFlipped,
    int? tiltDirection,
  }) {
    return GyroState(
      enabled: enabled ?? this.enabled,
      available: available ?? this.available,
      pattern: pattern ?? this.pattern,
      patternName: patternName ?? this.patternName,
      pitch: pitch ?? this.pitch,
      roll: roll ?? this.roll,
      accX: accX ?? this.accX,
      accY: accY ?? this.accY,
      accZ: accZ ?? this.accZ,
      gesture: gesture ?? this.gesture,
      isShaking: isShaking ?? this.isShaking,
      isTilted: isTilted ?? this.isTilted,
      isFlipped: isFlipped ?? this.isFlipped,
      tiltDirection: tiltDirection ?? this.tiltDirection,
    );
  }

  /// Get tilt direction as string
  String get tiltDirectionName {
    switch (tiltDirection) {
      case 1:
        return 'Left';
      case 2:
        return 'Right';
      case 3:
        return 'Forward';
      case 4:
        return 'Back';
      default:
        return 'None';
    }
  }

  /// Factory to create from API response
  factory GyroState.fromJson(Map<String, dynamic> json) {
    return GyroState(
      enabled: json['enabled'] ?? false,
      available: json['available'] ?? false,
      pattern: json['pattern'] ?? 0,
      patternName: json['patternName'] ?? '',
      pitch: (json['pitch'] ?? 0).toDouble(),
      roll: (json['roll'] ?? 0).toDouble(),
      accX: (json['accX'] ?? 0).toDouble(),
      accY: (json['accY'] ?? 0).toDouble(),
      accZ: (json['accZ'] ?? 0).toDouble(),
      gesture: json['gesture'] ?? 'none',
      isShaking: json['isShaking'] ?? false,
      isTilted: json['isTilted'] ?? false,
      isFlipped: json['isFlipped'] ?? false,
      tiltDirection: json['tiltDirection'] ?? 0,
    );
  }
}

/// Gyro pattern model
class GyroPattern {
  final int id;
  final String name;
  final String description;
  final String icon;

  const GyroPattern({
    required this.id,
    required this.name,
    this.description = '',
    this.icon = 'sensors',
  });

  /// Default gyro patterns matching ESP32 firmware
  static const List<GyroPattern> defaultPatterns = [
    GyroPattern(
      id: 0,
      name: 'Fluid Tilt',
      description: 'Water-like fluid movement with tilt',
      icon: 'water_drop',
    ),
    GyroPattern(
      id: 1,
      name: 'Wave',
      description: 'LEDs wave in tilt direction',
      icon: 'waves',
    ),
    GyroPattern(
      id: 2,
      name: 'Shake Sparkle',
      description: 'Sparkle effect when shaking',
      icon: 'auto_awesome',
    ),
    GyroPattern(
      id: 3,
      name: 'Flip Toggle',
      description: 'Flip lamp to change color',
      icon: 'flip',
    ),
    GyroPattern(
      id: 4,
      name: 'Motion Rainbow',
      description: 'Rainbow follows motion',
      icon: 'motion_photos_on',
    ),
    GyroPattern(
      id: 5,
      name: 'Tilt Brightness',
      description: 'Brightness changes with tilt',
      icon: 'brightness_high',
    ),
    GyroPattern(
      id: 6,
      name: 'Shake Random',
      description: 'Shake to randomize color',
      icon: 'shuffle',
    ),
    GyroPattern(
      id: 7,
      name: 'Gyro Fire',
      description: 'Fire intensity based on motion',
      icon: 'local_fire_department',
    ),
  ];
}

/// Custom color with optional name
class CustomColor {
  final Color color;
  final String name;

  const CustomColor({required this.color, this.name = ''});

  CustomColor copyWith({Color? color, String? name}) {
    return CustomColor(color: color ?? this.color, name: name ?? this.name);
  }
}

/// Network information
class NetworkInfo {
  final String ssid;
  final String ipAddress;
  final int rssi;

  const NetworkInfo({
    required this.ssid,
    required this.ipAddress,
    required this.rssi,
  });

  /// Get signal strength description
  String get signalStrength {
    if (rssi >= -50) return 'Excellent';
    if (rssi >= -60) return 'Good';
    if (rssi >= -70) return 'Fair';
    return 'Weak';
  }
}
