import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for communicating with IoT lamp devices
class LampApiService {
  final String ipAddress;
  final http.Client _client;
  final Duration timeout;
  String? _authToken;

  LampApiService(
    this.ipAddress, {
    http.Client? client,
    this.timeout = const Duration(seconds: 5),
  }) : _client = client ?? http.Client();

  /// Base URL for API requests
  String get baseUrl => 'http://$ipAddress';

  /// Whether authenticated
  bool get isAuthenticated => _authToken != null;

  /// Headers with auth token if available
  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  /// Make GET request
  Future<Map<String, dynamic>?> _get(String endpoint) async {
    try {
      debugPrint('LampAPI: GET $baseUrl$endpoint');
      final response = await _client
          .get(Uri.parse('$baseUrl$endpoint'), headers: _headers)
          .timeout(timeout);

      debugPrint('LampAPI: Response ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('LampAPI: Error - $e');
      return null;
    }
  }

  /// Make POST request
  Future<Map<String, dynamic>?> _post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      debugPrint('LampAPI: POST $baseUrl$endpoint body: $body');
      final response = await _client
          .post(
            Uri.parse('$baseUrl$endpoint'),
            headers: _headers,
            body: jsonEncode(body),
          )
          .timeout(timeout);

      debugPrint('LampAPI: Response ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('LampAPI: Error - $e');
      return null;
    }
  }

  /// Authenticate with device password
  Future<bool> authenticate(String password) async {
    try {
      debugPrint('LampAPI: Authenticating...');
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'password': password}),
          )
          .timeout(timeout);

      debugPrint(
        'LampAPI: Auth response ${response.statusCode} - ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['token'] != null) {
          _authToken = data['token'] as String;
          debugPrint('LampAPI: Authenticated successfully');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('LampAPI: Auth error - $e');
      return false;
    }
  }

  /// Verify password without storing token
  Future<bool> verifyPassword(String password) async {
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'password': password}),
          )
          .timeout(timeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        return data['success'] == true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  /// Get device info (uses /info endpoint which doesn't require auth)
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    // Try /info first (no auth required), then fall back to /api/info
    var result = await _get('/info');
    if (result == null) {
      result = await _get('/api/info');
    }
    return result;
  }

  /// Get current lamp status
  Future<Map<String, dynamic>?> getStatus() async {
    return await _get('/api/status');
  }

  /// Set lamp power state
  Future<bool> setPower(bool on) async {
    final result = await _post('/api/power', {'on': on});
    return result != null && result['success'] == true;
  }

  /// Set lamp pattern by ID (integer index)
  Future<bool> setPattern(dynamic patternId) async {
    final result = await _post('/api/pattern', {'pattern': patternId});
    return result != null && result['success'] == true;
  }

  /// Set lamp brightness (0-255)
  Future<bool> setBrightness(int brightness) async {
    final result = await _post('/api/brightness', {'brightness': brightness});
    return result != null && result['success'] == true;
  }

  /// Set custom RGB color
  Future<bool> setCustomColor(int r, int g, int b) async {
    final result = await _post('/api/color', {'r': r, 'g': g, 'b': b});
    return result != null && result['success'] == true;
  }

  /// Get available patterns
  Future<List<Map<String, dynamic>>?> getPatterns() async {
    final result = await _get('/api/patterns');
    if (result != null && result['patterns'] is List) {
      return (result['patterns'] as List).cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// Set gyro mode enabled/disabled
  Future<bool> setGyroEnabled(bool enabled) async {
    final result = await _post('/api/gyro', {'enabled': enabled});
    return result != null && result['success'] == true;
  }

  /// Set gyro pattern
  Future<bool> setGyroPattern(int pattern) async {
    final result = await _post('/api/gyro', {'pattern': pattern});
    return result != null && result['success'] == true;
  }

  /// Set both gyro enabled and pattern
  Future<Map<String, dynamic>?> setGyro({bool? enabled, int? pattern}) async {
    final body = <String, dynamic>{};
    if (enabled != null) body['enabled'] = enabled;
    if (pattern != null) body['pattern'] = pattern;
    return await _post('/api/gyro', body);
  }

  /// Get gyro status including sensor data
  Future<Map<String, dynamic>?> getGyroStatus() async {
    return await _get('/api/gyro');
  }

  /// Calibrate gyro
  /// step: 'center', 'left', 'right', 'front', 'back', 'save', 'cancel'
  Future<bool> calibrateGyro(String step) async {
    final result = await _post('/api/gyro/calibrate', {'step': step});
    return result != null && result['success'] == true;
  }

  /// Check if device is reachable
  Future<bool> ping() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/info'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Set reading light warmth (0-100)
  Future<bool> setReadingWarmth(int warmth) async {
    final result = await _post('/api/reading-warmth', {'warmth': warmth});
    return result != null && result['success'] == true;
  }

  /// Get pattern configuration
  Future<Map<String, dynamic>?> getPatternConfig([int? patternIndex]) async {
    final endpoint = patternIndex != null
        ? '/api/pattern-config?pattern=$patternIndex'
        : '/api/pattern-config';
    return await _get(endpoint);
  }

  /// Set pattern configuration
  ///
  /// Example for Aurora Borealis (pattern 3):
  /// ```dart
  /// setPatternConfig(3, {
  ///   'speed': 15,
  ///   'brightness': 220,
  ///   'complexity': 3,
  ///   'paletteIndex': 0,
  ///   'shimmer': true,
  ///   'waveDensity': 50,
  /// });
  /// ```
  Future<bool> setPatternConfig(
    int patternIndex,
    Map<String, dynamic> config,
  ) async {
    final body = <String, dynamic>{'pattern': patternIndex, ...config};
    final result = await _post('/api/pattern-config', body);
    return result != null && result['success'] == true;
  }

  /// Set Aurora Borealis pattern configuration (Pattern 13)
  Future<bool> setAuroraConfig({
    int? speed,
    int? brightness,
    int? complexity,
    int? paletteIndex,
    bool? shimmer,
    int? waveDensity,
  }) async {
    final config = <String, dynamic>{};
    if (speed != null) config['speed'] = speed;
    if (brightness != null) config['brightness'] = brightness;
    if (complexity != null) config['complexity'] = complexity;
    if (paletteIndex != null) config['paletteIndex'] = paletteIndex;
    if (shimmer != null) config['shimmer'] = shimmer;
    if (waveDensity != null) config['waveDensity'] = waveDensity;
    return await setPatternConfig(13, config);
  }

  /// Set Night Reading pattern configuration (Pattern 0)
  Future<bool> setNightReadingConfig({
    int? warmth,
    int? yellowness,
    int? brightness,
  }) async {
    final config = <String, dynamic>{};
    if (warmth != null) config['warmth'] = warmth;
    if (yellowness != null) config['yellowness'] = yellowness;
    if (brightness != null) config['brightness'] = brightness;
    return await setPatternConfig(0, config);
  }

  /// Set Fire pattern configuration (Pattern 3)
  Future<bool> setFireConfig({
    int? calmness,
    int? intensity,
    int? spread,
  }) async {
    final config = <String, dynamic>{};
    if (calmness != null) config['calmness'] = calmness;
    if (intensity != null) config['intensity'] = intensity;
    if (spread != null) config['spread'] = spread;
    return await setPatternConfig(3, config);
  }

  /// Set Rainbow pattern configuration (Pattern 2)
  Future<bool> setRainbowConfig({int? speed, bool? reverse}) async {
    final config = <String, dynamic>{};
    if (speed != null) config['speed'] = speed;
    if (reverse != null) config['reverse'] = reverse;
    return await setPatternConfig(2, config);
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
