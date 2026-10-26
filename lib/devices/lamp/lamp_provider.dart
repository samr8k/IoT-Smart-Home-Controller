import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/storage_service.dart';
import '../../providers/device_provider.dart';
import 'lamp_models.dart';
import 'lamp_api_service.dart';

/// Lamp state notifier for a specific device
class LampStateNotifier extends StateNotifier<LampState?> {
  final String ipAddress;
  final StorageService _storage;
  late final LampApiService _apiService;

  LampStateNotifier({required this.ipAddress, required StorageService storage})
    : _storage = storage,
      super(null) {
    _apiService = LampApiService(ipAddress);
  }

  /// Initialize by authenticating and fetching current state from device
  Future<void> initialize() async {
    debugPrint('LampProvider: Initializing for $ipAddress');

    // First test connectivity
    debugPrint('LampProvider: Testing connection...');
    final connected = await _apiService.testConnection();
    if (!connected) {
      debugPrint('LampProvider: Device not reachable at $ipAddress');
      state = LampState(
        isOn: false,
        brightness: 100,
        customColors: await _loadCustomColors(),
      );
      return;
    }

    try {
      // First authenticate with stored or default password
      final savedPassword = await _storage.getDevicePassword(ipAddress);
      final password = (savedPassword != null && savedPassword.isNotEmpty)
          ? savedPassword
          : 'x'; // Default password

      debugPrint('LampProvider: Authenticating...');
      final authSuccess = await _apiService.authenticate(password);
      debugPrint('LampProvider: Auth result: $authSuccess');

      if (!authSuccess) {
        debugPrint('LampProvider: Auth failed, using defaults');
        state = LampState(
          isOn: false,
          brightness: 100,
          customColors: await _loadCustomColors(),
        );
        return;
      }

      // Now fetch status (requires auth)
      debugPrint('LampProvider: Fetching status...');
      final status = await _apiService.getStatus();
      debugPrint('LampProvider: Status response: $status');

      if (status != null && status['success'] == true) {
        // Firmware sends brightness as 0-255, convert to 0-100 for UI
        final firmwareBrightness = status['brightness'] ?? 255;
        final uiBrightness = (firmwareBrightness * 100 / 255).round();

        // Parse gyro state if available
        GyroState? gyroState;
        if (status['gyro'] != null) {
          final gyro = status['gyro'] as Map<String, dynamic>;
          gyroState = GyroState(
            enabled: gyro['enabled'] ?? false,
            available: gyro['available'] ?? false,
            pattern: gyro['pattern'] ?? 0,
            patternName: gyro['patternName'] ?? '',
            pitch: (gyro['pitch'] ?? 0).toDouble(),
            roll: (gyro['roll'] ?? 0).toDouble(),
            accX: (gyro['accX'] ?? 0).toDouble(),
            accY: (gyro['accY'] ?? 0).toDouble(),
            accZ: (gyro['accZ'] ?? 0).toDouble(),
            gesture: gyro['gesture'] ?? 'none',
            isShaking: gyro['isShaking'] ?? false,
            isTilted: gyro['isTilted'] ?? false,
            isFlipped: gyro['isFlipped'] ?? false,
            tiltDirection: gyro['tiltDirection'] ?? 0,
          );
        }

        state = LampState(
          isOn: status['isOn'] ?? status['is_on'] ?? false,
          brightness: uiBrightness,
          currentPattern: _parsePattern(
            status['currentPattern'] ?? status['pattern'],
          ),
          currentColor: _parseColor(status['customColor'] ?? status['color']),
          customColors: await _loadCustomColors(),
          networkInfo: _parseNetworkInfo(status['network']),
          gyroState: gyroState,
        );
        debugPrint(
          'LampProvider: Initialized successfully - isOn: ${state?.isOn}, brightness: ${state?.brightness}',
        );
      } else {
        debugPrint('LampProvider: Status fetch failed or returned failure');
        state = LampState(
          isOn: false,
          brightness: 100,
          customColors: await _loadCustomColors(),
        );
      }
    } catch (e) {
      debugPrint('LampProvider: Error during init: $e');
      // Initialize with defaults if device unreachable
      state = LampState(
        isOn: false,
        brightness: 100,
        customColors: await _loadCustomColors(),
      );
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

  /// Set brightness (0-100 in UI, converted to 0-255 for firmware)
  Future<bool> setBrightness(int brightness) async {
    // Optimistic update
    if (state != null) {
      state = state!.copyWith(brightness: brightness);
    }

    // Convert 0-100 to 0-255 for firmware
    final firmwareBrightness = (brightness * 255 / 100).round();
    return await _apiService.setBrightness(firmwareBrightness);
  }

  /// Set pattern
  Future<bool> setPattern(LampPattern pattern) async {
    // Optimistic update
    if (state != null) {
      state = state!.copyWith(currentPattern: pattern);
    }

    // Send pattern index to firmware (firmware expects integer index 0-14)
    final index = LampPattern.defaultPatterns.indexOf(pattern);
    debugPrint('LampProvider: Setting pattern index: $index (${pattern.name})');
    return await _apiService.setPattern(index >= 0 ? index : 0);
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
        currentPattern: LampPattern.getById('custom'),
        customColors: colors,
      );
    }

    // Send to device - color.r/g/b are already 0-255 in modern Flutter
    return await _apiService.setColor(
      color.color.red,
      color.color.green,
      color.color.blue,
    );
  }

  /// Set color from color wheel
  Future<bool> setColorWheel(Color color) async {
    // Optimistic update
    if (state != null) {
      state = state!.copyWith(
        currentColor: color,
        currentPattern: LampPattern.getById('custom'),
      );
    }

    // color.red/green/blue are already 0-255 in modern Flutter
    return await _apiService.setColor(color.red, color.green, color.blue);
  }

  /// Delete a saved custom color
  Future<void> deleteCustomColor(CustomColor colorToDelete) async {
    final colors = List<CustomColor>.from(state?.customColors ?? []);
    colors.removeWhere(
      (c) => c.color.toARGB32() == colorToDelete.color.toARGB32(),
    );
    await _saveCustomColors(colors);

    if (state != null) {
      state = state!.copyWith(customColors: colors);
    }
  }

  /// Set gyro mode enabled/disabled
  Future<bool> setGyroEnabled(bool enabled) async {
    final result = await _apiService.setGyro(enabled: enabled);
    if (result != null && result['success'] == true) {
      if (state != null) {
        final newGyroState =
            state!.gyroState?.copyWith(enabled: enabled) ??
            GyroState(enabled: enabled);
        state = state!.copyWith(gyroState: newGyroState);
      }
      return true;
    }
    return false;
  }

  /// Set gyro pattern
  Future<bool> setGyroPattern(int pattern) async {
    final result = await _apiService.setGyro(pattern: pattern);
    if (result != null && result['success'] == true) {
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

  /// Get pattern-specific configuration
  Future<Map<String, dynamic>?> getPatternConfig([int? patternIndex]) async {
    return await _apiService.getPatternConfig(patternIndex);
  }

  /// Set pattern-specific configuration
  Future<bool> setPatternConfig(
    int patternIndex,
    Map<String, dynamic> config,
  ) async {
    return await _apiService.setPatternConfig(patternIndex, config);
  }

  /// Refresh gyro status from device
  Future<void> refreshGyroStatus() async {
    final gyroStatus = await _apiService.getGyroStatus();
    if (gyroStatus != null && state != null) {
      state = state!.copyWith(
        gyroState: GyroState(
          enabled: gyroStatus['gyroEnabled'] ?? gyroStatus['enabled'] ?? false,
          available:
              gyroStatus['mpuAvailable'] ?? gyroStatus['available'] ?? false,
          pattern: gyroStatus['gyroPattern'] ?? gyroStatus['pattern'] ?? 0,
          patternName:
              gyroStatus['gyroPatternName'] ?? gyroStatus['patternName'] ?? '',
          pitch: (gyroStatus['pitch'] ?? gyroStatus['sensor']?['pitch'] ?? 0)
              .toDouble(),
          roll: (gyroStatus['roll'] ?? gyroStatus['sensor']?['roll'] ?? 0)
              .toDouble(),
          accX: (gyroStatus['accX'] ?? gyroStatus['sensor']?['accX'] ?? 0)
              .toDouble(),
          accY: (gyroStatus['accY'] ?? gyroStatus['sensor']?['accY'] ?? 0)
              .toDouble(),
          accZ: (gyroStatus['accZ'] ?? gyroStatus['sensor']?['accZ'] ?? 0)
              .toDouble(),
          gesture:
              gyroStatus['gesture']?['current'] ??
              gyroStatus['currentGesture'] ??
              'none',
          isShaking:
              gyroStatus['gesture']?['isShaking'] ??
              gyroStatus['isShaking'] ??
              false,
          isTilted:
              gyroStatus['gesture']?['isTilted'] ??
              gyroStatus['isTilted'] ??
              false,
          isFlipped:
              gyroStatus['gesture']?['isFlipped'] ??
              gyroStatus['isFlipped'] ??
              false,
          tiltDirection:
              gyroStatus['gesture']?['tiltDirection'] ??
              gyroStatus['tiltDirection'] ??
              0,
        ),
      );
    }
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
      return LampPattern.getById(patternData);
    }
    if (patternData is int) {
      return LampPattern.getByIndex(patternData);
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
  LampNetworkInfo? _parseNetworkInfo(dynamic networkData) {
    if (networkData == null) return null;
    if (networkData is Map) {
      return LampNetworkInfo(
        ssid: networkData['ssid'] ?? '',
        ipAddress: networkData['ip'] ?? ipAddress,
        rssi: networkData['rssi'] ?? 0,
      );
    }
    return null;
  }

  @override
  void dispose() {
    _apiService.dispose();
    super.dispose();
  }
}

/// Lamp state provider factory - keyed by IP address
final lampStateProvider =
    StateNotifierProvider.family<LampStateNotifier, LampState?, String>((
      ref,
      ipAddress,
    ) {
      final storage = ref.watch(storageServiceProvider);
      return LampStateNotifier(ipAddress: ipAddress, storage: storage);
    });

/// Available patterns provider
final lampPatternsProvider = Provider<List<LampPattern>>((ref) {
  return LampPattern.defaultPatterns;
});
