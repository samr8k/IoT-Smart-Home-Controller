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

  /// Default patterns matching ESP32 firmware exactly
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

  /// Gyro patterns matching firmware
  static const List<LampPattern> gyroPatterns = [
    LampPattern(
      index: 0,
      id: 'gyro_fluid_tilt',
      name: 'Fluid Tilt',
      description: 'Water-like fluid movement with tilt',
      icon: Icons.water_drop,
      colors: [Colors.blue, Colors.cyan, Colors.teal],
      isAnimated: true,
    ),
    LampPattern(
      index: 1,
      id: 'gyro_wave',
      name: 'Gyro Wave',
      description: 'LEDs wave in tilt direction',
      icon: Icons.waves,
      colors: [Colors.cyan, Colors.blue],
      isAnimated: true,
    ),
    LampPattern(
      index: 2,
      id: 'shake_sparkle',
      name: 'Shake Sparkle',
      description: 'Sparkle effect when shaking',
      icon: Icons.auto_awesome,
      colors: [Colors.white, Colors.yellow],
      isAnimated: true,
    ),
    LampPattern(
      index: 3,
      id: 'flip_toggle',
      name: 'Flip Toggle',
      description: 'Flip lamp to toggle on/off',
      icon: Icons.flip,
      colors: [Colors.white],
      isAnimated: false,
    ),
    LampPattern(
      index: 4,
      id: 'motion_rainbow',
      name: 'Motion Rainbow',
      description: 'Rainbow follows motion',
      icon: Icons.motion_photos_on,
      colors: [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
      ],
      isAnimated: true,
    ),
    LampPattern(
      index: 5,
      id: 'tilt_brightness',
      name: 'Tilt Brightness',
      description: 'Brightness changes with tilt',
      icon: Icons.brightness_6,
      colors: [Colors.white],
      isAnimated: true,
    ),
    LampPattern(
      index: 6,
      id: 'shake_random',
      name: 'Shake Random',
      description: 'Shake to randomize color',
      icon: Icons.shuffle,
      colors: [Colors.red, Colors.green, Colors.blue, Colors.yellow],
      isAnimated: true,
    ),
    LampPattern(
      index: 7,
      id: 'gyro_fire',
      name: 'Gyro Fire',
      description: 'Fire intensity based on motion',
      icon: Icons.local_fire_department,
      colors: [Colors.red, Colors.orange, Colors.yellow],
      isAnimated: true,
    ),
    LampPattern(
      index: 8,
      id: 'gyro_rainbow',
      name: 'Gyro Rainbow',
      description: 'Color based on tilt direction',
      icon: Icons.colorize,
      colors: [
        Colors.red,
        Colors.orange,
        Colors.yellow,
        Colors.green,
        Colors.blue,
      ],
      isAnimated: true,
    ),
    LampPattern(
      index: 9,
      id: 'shake_color',
      name: 'Shake Color',
      description: 'Shake to change color',
      icon: Icons.vibration,
      colors: [Colors.purple, Colors.pink, Colors.orange],
      isAnimated: true,
    ),
  ];

  static LampPattern? getById(String id) {
    try {
      return defaultPatterns.firstWhere((p) => p.id == id);
    } catch (e) {
      return null;
    }
  }

  static LampPattern? getByIndex(int index) {
    if (index >= 0 && index < defaultPatterns.length) {
      return defaultPatterns[index];
    }
    return null;
  }

  static LampPattern? getGyroByIndex(int index) {
    if (index >= 0 && index < gyroPatterns.length) {
      return gyroPatterns[index];
    }
    return null;
  }
}
