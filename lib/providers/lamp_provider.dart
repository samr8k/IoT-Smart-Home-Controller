import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lamp_state.dart';
import '../models/lamp_pattern.dart';
import '../services/lamp_api_service.dart';
import '../services/storage_service.dart';
import 'device_provider.dart';

/// Lamp state notifier for a specific device
class LampStateNotifier extends StateNotifier<LampState?> {
  final String ipAddress;
  final StorageService _storage;
  late final LampApiService _apiService;
  bool _isInitialized = false;

  LampStateNotifier({required this.ipAddress, required StorageService storage})
    : _storage = storage,
      super(null) {
    _apiService = LampApiService(ipAddress);
  }

  /// Initialize by authenticating and fetching current state from device
  Future<void> initialize() async {
    // If already initialized and state is valid, don't re-init
    if (_isInitialized && state != null) return;

    _isInitialized = true; // Set guard immediately.

    try {
      debugPrint('LampProvider: Initializing for $ipAddress with 10s timeout');
      await _doInitialize().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('LampProvider: Error or timeout during init: $e');
      // Errors are caught, and the final check below will handle setting a
      // default state if necessary.
    }

    // After attempting initialization, if state is still null, create a default.
    // This covers timeouts, API errors, or cases where the notifier was unmounted
    // during the async `_doInitialize` call.
    if (mounted && state == null) {
      debugPrint(
        'LampProvider: State was null after init attempt, creating default state.',
      );
      state = LampState(
        isOn: false,
        brightness: 100,
        customColors: await _loadCustomColors(),
      );
    }
  }

  Future<void> _doInitialize() async {
    debugPrint('LampProvider: Authenticating and fetching status...');

    // First, try to authenticate with stored password
    final savedPassword = await _storage.getDevicePassword(ipAddress);
    if (savedPassword != null && savedPassword.isNotEmpty) {
      debugPrint('LampProvider: Found saved password, authenticating...');
      await _apiService.authenticate(savedPassword);
    } else {
      // Try default password
      debugPrint('LampProvider: No saved password, trying default...');
      await _apiService.authenticate('x');
    }

    // Now fetch status
    final status = await _apiService.getStatus();
    debugPrint('LampProvider: Status response: $status');

    if (mounted) {
      if (status != null && status['success'] == true) {
        final firmwareBrightness = status['brightness'] ?? 255;
        final appBrightness = (firmwareBrightness * 100 / 255).round();

        state = LampState(
          isOn: status['isOn'] ?? status['is_on'] ?? false,
          brightness: appBrightness,
          readingWarmth: status['readingWarmth'] ?? 50,
          currentPattern: _parsePattern(
            status['pattern'] ?? status['currentPattern'],
          ),
          currentColor: _parseColor(status['color'] ?? status['customColor']),
          customColors: await _loadCustomColors(),
          networkInfo: _parseNetworkInfo(status['network']),
          gyroState: _parseGyroState(status['gyro']),
        );
        debugPrint('LampProvider: Initialized successfully');
      } else {
        // Initialize with defaults if status fetch failed
        debugPrint('LampProvider: Status fetch failed, using defaults');
        state = LampState(
          isOn: false,
          brightness: 100,
          customColors: await _loadCustomColors(),
        );
      }
    }
  }

  /// Re-authenticate with a new password
  Future<bool> authenticate(String password) async {
    final success = await _apiService.authenticate(password);
    if (success) {
      // Save password for future use
      await _storage.setDevicePassword(ipAddress, password);
      // Refresh state after auth
      await _refreshStatus();
    }
    return success;
  }

  /// Refresh status from device
  Future<void> _refreshStatus() async {
    try {
      final status = await _apiService.getStatus();
      if (status != null && status['success'] == true) {
        // Convert firmware brightness (0-255) to app brightness (0-100)
        final firmwareBrightness = status['brightness'] ?? 255;
        final appBrightness = (firmwareBrightness * 100 / 255).round();

        state = state?.copyWith(
          isOn: status['isOn'] ?? status['is_on'] ?? state?.isOn ?? false,
          brightness: appBrightness,
          readingWarmth: status['readingWarmth'] ?? state?.readingWarmth ?? 50,
          currentPattern: _parsePattern(
            status['pattern'] ?? status['currentPattern'],
          ),
          gyroState: _parseGyroState(status['gyro']),
        );
      }
    } catch (e) {
      debugPrint('LampProvider: Error refreshing status: $e');
    }
  }

  /// Set power on/off
  Future<bool> setPower(bool on) async {
    // Optimistic update
    if (state != null) {
      state = state!.copyWith(isOn: on);
    }

    final success = await _apiService.setPower(on);
    if (!success && state != null) {
      // Revert on failure
      state = state!.copyWith(isOn: !on);
    }
    return success;
  }

  /// Set brightness (0-100, converted to 0-255 for firmware)
  Future<bool> setBrightness(int brightness) async {
    // Optimistic update
    if (state != null) {
      state = state!.copyWith(brightness: brightness);
    }

    // Convert 0-100 to 0-255 for firmware
    final firmwareBrightness = (brightness * 255 / 100).round();
    return await _apiService.setBrightness(firmwareBrightness);
  }

  /// Set pattern using pattern index
  Future<bool> setPattern(LampPattern pattern) async {
    // Optimistic update
    if (state != null) {
      state = state!.copyWith(currentPattern: pattern);
    }

    // Send pattern index to firmware (not string id)
    return await _apiService.setPattern(pattern.index);
  }

  /// Set custom color
  Future<bool> setCustomColor(CustomColor color) async {
    // Add to saved colors if not exists
    final colors = List<CustomColor>.from(state?.customColors ?? []);
    if (!colors.any((c) => c.color.toARGB32() == color.color.toARGB32())) {
      colors.add(color);
      await _saveCustomColors(colors);
    }

    // Update state
    if (state != null) {
      state = state!.copyWith(
        currentColor: color.color,
        currentPattern: null,
        customColors: colors,
      );
    }

    // Extract RGB values - Color.r/g/b are already 0-255 integers
    final int r = color.color.red;
    final int g = color.color.green;
    final int b = color.color.blue;

    debugPrint('LampProvider: setCustomColor RGB($r, $g, $b)');

    // Send to device
    return await _apiService.setCustomColor(r, g, b);
  }

  /// Set color from color wheel
  Future<bool> setColorWheel(Color color) async {
    // Optimistic update
    if (state != null) {
      state = state!.copyWith(currentColor: color, currentPattern: null);
    }

    // Extract RGB values - Color.red/green/blue are already 0-255 integers
    final int r = color.red;
    final int g = color.green;
    final int b = color.blue;

    debugPrint(
      'LampProvider: setColorWheel RGB($r, $g, $b) from color: $color',
    );

    return await _apiService.setCustomColor(r, g, b);
  }

  /// Load custom colors from storage
  Future<List<CustomColor>> _loadCustomColors() async {
    try {
      final data = await _storage.getCustomColors(ipAddress);
      return data
          .map(
            (item) => CustomColor(
              color: Color(item['color'] as int),
              name: item['name'] as String? ?? '',
            ),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  /// Save custom colors to storage
  Future<void> _saveCustomColors(List<CustomColor> colors) async {
    try {
      final data = colors
          .map((c) => {'color': c.color.toARGB32(), 'name': c.name})
          .toList();
      await _storage.saveCustomColors(ipAddress, data);
    } catch (e) {
      // Ignore storage errors
    }
  }

  /// Parse pattern from API response
  LampPattern? _parsePattern(dynamic patternData) {
    if (patternData == null) return null;
    if (patternData is String) {
      return LampPattern.defaultPatterns.cast<LampPattern?>().firstWhere(
        (p) => p?.id == patternData,
        orElse: () => null,
      );
    }
    if (patternData is int) {
      final patterns = LampPattern.defaultPatterns;
      if (patternData >= 0 && patternData < patterns.length) {
        return patterns[patternData];
      }
    }
    return null;
  }

  /// Parse color from API response
  Color? _parseColor(dynamic colorData) {
    if (colorData == null) return null;
    if (colorData is Map) {
      return Color.fromARGB(
        255,
        colorData['r'] ?? 255,
        colorData['g'] ?? 255,
        colorData['b'] ?? 255,
      );
    }
    return null;
  }

  /// Parse network info from API response
  NetworkInfo? _parseNetworkInfo(dynamic networkData) {
    if (networkData == null) return null;
    if (networkData is Map) {
      return NetworkInfo(
        ssid: networkData['ssid'] ?? '',
        ipAddress: networkData['ip'] ?? ipAddress,
        rssi: networkData['rssi'] ?? 0,
      );
    }
    return null;
  }

  /// Parse gyro state from API response
  GyroState? _parseGyroState(dynamic gyroData) {
    if (gyroData == null) return null;
    if (gyroData is Map<String, dynamic>) {
      return GyroState.fromJson(gyroData);
    }
    return null;
  }

  /// Set gyro mode enabled/disabled
  Future<bool> setGyroEnabled(bool enabled) async {
    debugPrint('LampProvider: Setting gyro enabled=$enabled');
    final result = await _apiService.setGyro(enabled: enabled);
    debugPrint('LampProvider: setGyro result: $result');

    if (result != null && result['success'] == true) {
      // Update state
      if (state != null) {
        final newGyroState =
            state!.gyroState?.copyWith(
              enabled: enabled,
              available:
                  result['mpuAvailable'] ??
                  state!.gyroState?.available ??
                  false,
            ) ??
            GyroState(
              enabled: enabled,
              available: result['mpuAvailable'] ?? false,
            );
        state = state!.copyWith(gyroState: newGyroState);
        debugPrint('LampProvider: Gyro state updated - enabled=$enabled');
      }
      return true;
    }
    debugPrint('LampProvider: setGyro failed');
    return false;
  }

  /// Set gyro pattern
  Future<bool> setGyroPattern(int pattern) async {
    final result = await _apiService.setGyro(pattern: pattern);
    if (result != null && result['success'] == true) {
      // Update state
      if (state != null) {
        final patternName = result['gyroPatternName'] ?? '';
        final newGyroState =
            state!.gyroState?.copyWith(
              pattern: pattern,
              patternName: patternName,
            ) ??
            GyroState(pattern: pattern, patternName: patternName);
        state = state!.copyWith(gyroState: newGyroState);
      }
      return true;
    }
    return false;
  }

  /// Set reading light warmth (0-100)
  Future<bool> setReadingWarmth(int warmth) async {
    // Optimistic update
    if (state != null) {
      state = state!.copyWith(readingWarmth: warmth);
    }

    final success = await _apiService.setReadingWarmth(warmth);
    if (!success && state != null) {
      // Revert on failure - would need to refresh from device
      await _refreshStatus();
    }
    return success;
  }

  /// Refresh gyro status from device
  Future<void> refreshGyroStatus() async {
    try {
      final gyroStatus = await _apiService.getGyroStatus();
      debugPrint('LampProvider: refreshGyroStatus result: $gyroStatus');

      if (gyroStatus != null && state != null) {
        state = state!.copyWith(
          gyroState: GyroState(
            enabled: gyroStatus['gyroEnabled'] ?? false,
            available: gyroStatus['mpuAvailable'] ?? false,
            pattern: gyroStatus['gyroPattern'] ?? 0,
            patternName: gyroStatus['gyroPatternName'] ?? '',
            pitch: (gyroStatus['sensor']?['pitch'] ?? 0).toDouble(),
            roll: (gyroStatus['sensor']?['roll'] ?? 0).toDouble(),
            accX: (gyroStatus['sensor']?['accX'] ?? 0).toDouble(),
            accY: (gyroStatus['sensor']?['accY'] ?? 0).toDouble(),
            accZ: (gyroStatus['sensor']?['accZ'] ?? 0).toDouble(),
            gesture: gyroStatus['gesture']?['current'] ?? 'none',
            isShaking: gyroStatus['gesture']?['isShaking'] ?? false,
            isTilted: gyroStatus['gesture']?['isTilted'] ?? false,
            isFlipped: gyroStatus['gesture']?['isFlipped'] ?? false,
            tiltDirection: gyroStatus['gesture']?['tiltDirection'] ?? 0,
          ),
        );
      }
    } catch (e) {
      debugPrint('LampProvider: Error refreshing gyro status: $e');
    }
  }

  /// Calibrate gyro
  Future<bool> calibrateGyro(String step) async {
    return await _apiService.calibrateGyro(step);
  }

  // ==================== Pattern Configuration Methods ====================

  /// Get pattern configuration from device
  Future<Map<String, dynamic>?> getPatternConfig([int? patternIndex]) async {
    return await _apiService.getPatternConfig(patternIndex);
  }

  /// Set pattern configuration
  Future<bool> setPatternConfig(
    int patternIndex,
    Map<String, dynamic> config,
  ) async {
    debugPrint(
      'LampProvider: Setting pattern config for pattern $patternIndex: $config',
    );
    final success = await _apiService.setPatternConfig(patternIndex, config);
    if (success) {
      // Pattern may have changed, refresh status
      await _refreshStatus();
    }
    return success;
  }

  /// Set Aurora Borealis configuration (Pattern 13)
  Future<bool> setAuroraConfig({
    int? speed,
    int? brightness,
    int? complexity,
    int? paletteIndex,
    bool? shimmer,
    int? waveDensity,
  }) async {
    return await _apiService.setAuroraConfig(
      speed: speed,
      brightness: brightness,
      complexity: complexity,
      paletteIndex: paletteIndex,
      shimmer: shimmer,
      waveDensity: waveDensity,
    );
  }

  /// Set Night Reading configuration (Pattern 0)
  Future<bool> setNightReadingConfig({
    int? warmth,
    int? yellowness,
    int? brightness,
  }) async {
    return await _apiService.setNightReadingConfig(
      warmth: warmth,
      yellowness: yellowness,
      brightness: brightness,
    );
  }

  /// Set Fire pattern configuration (Pattern 3)
  Future<bool> setFireConfig({
    int? calmness,
    int? intensity,
    int? spread,
  }) async {
    return await _apiService.setFireConfig(
      calmness: calmness,
      intensity: intensity,
      spread: spread,
    );
  }

  /// Set Rainbow pattern configuration (Pattern 2)
  Future<bool> setRainbowConfig({int? speed, bool? reverse}) async {
    return await _apiService.setRainbowConfig(speed: speed, reverse: reverse);
  }
}

/// Lamp state provider factory - keyed by IP address
final lampStateProvider = StateNotifierProvider.autoDispose
    .family<LampStateNotifier, LampState?, String>((ref, ipAddress) {
      final storage = ref.watch(storageServiceProvider);
      return LampStateNotifier(ipAddress: ipAddress, storage: storage);
    });

/// Available patterns provider
final lampPatternsProvider = Provider<List<LampPattern>>((ref) {
  return LampPattern.defaultPatterns;
});
