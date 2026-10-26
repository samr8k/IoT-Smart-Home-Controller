import 'package:flutter/material.dart';

/// Model representing a lamp lighting pattern
class LampPattern {
  final int index; // Firmware pattern index
  final String id;
  final String name;
  final String description;
  final IconData icon;
  final List<Color> colors;
  final bool isAnimated;

  const LampPattern({
    required this.index,
    required this.id,
    required this.name,
    this.description = '',
    this.icon = Icons.lightbulb,
    this.colors = const [Colors.white],
    this.isAnimated = false,
  });

  /// Default patterns matching ESP32 firmware exactly (26 patterns)
  static const List<LampPattern> defaultPatterns = [
    LampPattern(
      index: 0,
      id: 'yellow_night',
      name: 'Night Reading',
      description: 'Warm light with adjustable warmth and yellowness',
      icon: Icons.menu_book,
      colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
      isAnimated: false,
    ),
    LampPattern(
      index: 1,
      id: 'ocean',
      name: 'Blue Oceanic',
      description: 'Calming ocean blue waves',
      icon: Icons.waves,
      colors: [Colors.blue, Colors.cyan, Colors.teal],
      isAnimated: true,
    ),
    LampPattern(
      index: 2,
      id: 'rainbow',
      name: 'Rainbow Spiral',
      description: 'Colorful rainbow spiral effect',
      icon: Icons.auto_awesome,
      colors: [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
        Colors.purple,
      ],
      isAnimated: true,
    ),
    LampPattern(
      index: 3,
      id: 'fire',
      name: 'Fire Effect',
      description: 'Realistic flames with adjustable calmness',
      icon: Icons.local_fire_department,
      colors: [Colors.red, Colors.orange, Colors.yellow],
      isAnimated: true,
    ),
    LampPattern(
      index: 4,
      id: 'starry',
      name: 'Starry Night',
      description: 'Twinkling stars in the night sky',
      icon: Icons.star,
      colors: [Colors.white, Colors.yellow, Color(0xFF1a237e)],
      isAnimated: true,
    ),
    LampPattern(
      index: 5,
      id: 'breathing',
      name: 'Breathing White',
      description: 'Gentle pulsing white light',
      icon: Icons.air,
      colors: [Colors.white],
      isAnimated: true,
    ),
    LampPattern(
      index: 6,
      id: 'color_cycle',
      name: 'Color Cycle',
      description: 'Smooth color transitions',
      icon: Icons.palette,
      colors: [Colors.red, Colors.green, Colors.blue],
      isAnimated: true,
    ),
    LampPattern(
      index: 7,
      id: 'spiral_chase',
      name: 'Spiral Chase',
      description: 'LED chase around the spiral',
      icon: Icons.rotate_right,
      colors: [Colors.cyan, Colors.blue],
      isAnimated: true,
    ),
    LampPattern(
      index: 8,
      id: 'sunset',
      name: 'Sunset Gradient',
      description: 'Beautiful sunset colors',
      icon: Icons.wb_twilight,
      colors: [Colors.orange, Colors.pink, Colors.purple],
      isAnimated: false,
    ),
    LampPattern(
      index: 9,
      id: 'pulse',
      name: 'Pulse From Center',
      description: 'Waves radiating from center',
      icon: Icons.radar,
      colors: [Colors.purple, Colors.blue],
      isAnimated: true,
    ),
    LampPattern(
      index: 10,
      id: 'snowflake',
      name: 'Snowflake',
      description: 'Cool white twinkling like snow',
      icon: Icons.ac_unit,
      colors: [Colors.white, Color(0xFFE0F7FA)],
      isAnimated: true,
    ),
    LampPattern(
      index: 11,
      id: 'night_light',
      name: 'Night Light',
      description: 'Dim warm amber for sleeping',
      icon: Icons.nightlight_round,
      colors: [Color(0xFF4A2800), Color(0xFF2D1800)],
      isAnimated: true,
    ),
    LampPattern(
      index: 12,
      id: 'candle',
      name: 'Candle Flicker',
      description: 'Realistic candle flame',
      icon: Icons.local_fire_department,
      colors: [Color(0xFFFF6B00), Color(0xFFFFAA00)],
      isAnimated: true,
    ),
    LampPattern(
      index: 13,
      id: 'aurora',
      name: 'Aurora Borealis',
      description: 'Northern lights effect',
      icon: Icons.landscape,
      colors: [Colors.green, Colors.cyan, Colors.purple],
      isAnimated: true,
    ),
    LampPattern(
      index: 14,
      id: 'ocean_waves',
      name: 'Ocean Waves',
      description: 'Very relaxing ocean waves',
      icon: Icons.water,
      colors: [Color(0xFF0077B6), Color(0xFF00B4D8), Color(0xFF90E0EF)],
      isAnimated: true,
    ),
    LampPattern(
      index: 15,
      id: 'sunset_fade',
      name: 'Sunset Fade',
      description: 'Beautiful evening sunset transition',
      icon: Icons.wb_sunny,
      colors: [Color(0xFFFF6B35), Color(0xFFF7931E), Color(0xFFFFD23F)],
      isAnimated: true,
    ),
    LampPattern(
      index: 16,
      id: 'meteor_shower',
      name: 'Meteor Shower',
      description: 'Exciting and dynamic meteors',
      icon: Icons.rocket_launch,
      colors: [Colors.white, Colors.yellow, Color(0xFF1a237e)],
      isAnimated: true,
    ),
    LampPattern(
      index: 17,
      id: 'lightning_storm',
      name: 'Lightning Storm',
      description: 'Dramatic lightning flashes',
      icon: Icons.flash_on,
      colors: [Colors.white, Color(0xFF4A5568), Color(0xFF2D3748)],
      isAnimated: true,
    ),
    LampPattern(
      index: 18,
      id: 'ripple',
      name: 'Ripple',
      description: 'Circular waves from center',
      icon: Icons.adjust,
      colors: [Colors.blue, Colors.purple, Colors.cyan],
      isAnimated: true,
    ),
    LampPattern(
      index: 19,
      id: 'kaleidoscope',
      name: 'Kaleidoscope',
      description: 'Symmetrical color patterns',
      icon: Icons.blur_circular,
      colors: [Colors.pink, Colors.purple, Colors.blue, Colors.cyan],
      isAnimated: true,
    ),
    LampPattern(
      index: 20,
      id: 'dna_helix',
      name: 'DNA Helix',
      description: 'Two intertwined spirals',
      icon: Icons.science,
      colors: [Color(0xFF00D4FF), Color(0xFFFF69B4)],
      isAnimated: true,
    ),
    LampPattern(
      index: 21,
      id: 'forest_breeze',
      name: 'Forest Breeze',
      description: 'Green tones with gentle movement',
      icon: Icons.forest,
      colors: [Color(0xFF228B22), Color(0xFF32CD32), Color(0xFF90EE90)],
      isAnimated: true,
    ),
    LampPattern(
      index: 22,
      id: 'firefly_glow',
      name: 'Firefly Glow',
      description: 'Gentle fireflies in the night',
      icon: Icons.blur_on,
      colors: [Color(0xFF9ACD32), Color(0xFFADFF2F)],
      isAnimated: true,
    ),
    LampPattern(
      index: 23,
      id: 'dreamy_clouds',
      name: 'Dreamy Clouds',
      description: 'Soft cloud movement',
      icon: Icons.cloud,
      colors: [Colors.white, Color(0xFFB0C4DE), Color(0xFFE6E6FA)],
      isAnimated: true,
    ),
    LampPattern(
      index: 24,
      id: 'lava_lamp',
      name: 'Lava Lamp',
      description: 'Slow-moving blobs of warm colors',
      icon: Icons.water_drop,
      colors: [Color(0xFFFF4500), Color(0xFFFF6347), Color(0xFFFFD700)],
      isAnimated: true,
    ),
    LampPattern(
      index: 25,
      id: 'custom',
      name: 'Custom Color',
      description: 'Your custom color selection',
      icon: Icons.color_lens,
      colors: [Colors.white],
      isAnimated: false,
    ),
  ];

  static LampPattern? getById(String id) {
    try {
      return defaultPatterns.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Get pattern by index (for firmware compatibility)
  static LampPattern? getByIndex(int index) {
    if (index >= 0 && index < defaultPatterns.length) {
      return defaultPatterns[index];
    }
    return null;
  }
}

/// Model representing the current state of a smart lamp
class LampState {
  final bool isOn;
  final int brightness;
  final int readingWarmth;
  final LampPattern? currentPattern;
  final Color? currentColor;
  final List<CustomColor> customColors;
  final LampNetworkInfo? networkInfo;
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
    LampNetworkInfo? networkInfo,
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

/// Custom color with optional name
class CustomColor {
  final Color color;
  final String name;

  const CustomColor({required this.color, this.name = ''});

  CustomColor copyWith({Color? color, String? name}) {
    return CustomColor(color: color ?? this.color, name: name ?? this.name);
  }
}

/// Network information for lamp
class LampNetworkInfo {
  final String ssid;
  final String ipAddress;
  final int rssi;

  const LampNetworkInfo({
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

/// Gyro/motion sensor state
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
}

/// Gyro pattern definitions matching firmware (10 patterns)
class GyroPattern {
  final int index;
  final String id;
  final String name;
  final String description;
  final IconData icon;

  const GyroPattern({
    required this.index,
    required this.id,
    required this.name,
    this.description = '',
    this.icon = Icons.sensors,
  });

  static const List<GyroPattern> patterns = [
    GyroPattern(
      index: 0,
      id: 'fluid_tilt',
      name: 'Fluid Tilt',
      description: 'Water-like fluid movement with tilt',
      icon: Icons.water_drop,
    ),
    GyroPattern(
      index: 1,
      id: 'gyro_wave',
      name: 'Gyro Wave',
      description: 'LEDs wave in tilt direction',
      icon: Icons.waves,
    ),
    GyroPattern(
      index: 2,
      id: 'shake_sparkle',
      name: 'Shake Sparkle',
      description: 'Dramatic sparkle bursts when shaking',
      icon: Icons.auto_awesome,
    ),
    GyroPattern(
      index: 3,
      id: 'flip_toggle',
      name: 'Flip Toggle',
      description: 'Flip lamp to toggle on/off',
      icon: Icons.flip,
    ),
    GyroPattern(
      index: 4,
      id: 'motion_rainbow',
      name: 'Motion Rainbow',
      description: 'Rainbow follows motion',
      icon: Icons.motion_photos_on,
    ),
    GyroPattern(
      index: 5,
      id: 'tilt_brightness',
      name: 'Tilt Brightness',
      description: 'Brightness changes with tilt',
      icon: Icons.brightness_6,
    ),
    GyroPattern(
      index: 6,
      id: 'shake_random',
      name: 'Shake Random',
      description: 'Dramatic flash and color change on shake',
      icon: Icons.shuffle,
    ),
    GyroPattern(
      index: 7,
      id: 'gyro_fire',
      name: 'Gyro Fire',
      description: 'Fire intensity based on motion',
      icon: Icons.local_fire_department,
    ),
    GyroPattern(
      index: 8,
      id: 'gyro_rainbow',
      name: 'Gyro Rainbow',
      description: 'Color based on tilt direction',
      icon: Icons.colorize,
    ),
    GyroPattern(
      index: 9,
      id: 'shake_color',
      name: 'Shake Color',
      description: 'Shake to change color',
      icon: Icons.vibration,
    ),
  ];

  static GyroPattern? getByIndex(int index) {
    if (index >= 0 && index < patterns.length) {
      return patterns[index];
    }
    return null;
  }
}
