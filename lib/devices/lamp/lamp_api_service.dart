import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service for communicating with IoT lamp devices via REST API
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

  /// Base URL for API calls
  String get baseUrl => 'http://$ipAddress';

  /// Test connectivity to device
  Future<bool> testConnection() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/info'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('LampAPI: Connection test failed: $e');
      return false;
    }
  }

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

      debugPrint('LampAPI: Response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('LampAPI: GET error: $e');
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

      debugPrint('LampAPI: Response ${response.statusCode}: ${response.body}');

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint('LampAPI: POST error: $e');
      return null;
    }
  }

  /// Authenticate with device password
  Future<bool> authenticate(String password) async {
    try {
      debugPrint('LampAPI: Authenticating with password...');
      final response = await _client
          .post(
            Uri.parse('$baseUrl/api/auth'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'password': password}),
          )
          .timeout(timeout);

      debugPrint(
        'LampAPI: Auth response ${response.statusCode}: ${response.body}',
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        if (data['success'] == true && data['token'] != null) {
          _authToken = data['token'] as String;
          debugPrint('LampAPI: Auth successful, token received');
          return true;
        }
      }
      debugPrint('LampAPI: Auth failed');
      return false;
    } catch (e) {
      debugPrint('LampAPI: Auth error: $e');
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

  /// Get device info
  Future<Map<String, dynamic>?> getDeviceInfo() async {
    return await _get('/api/info');
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

  /// Set lamp pattern by ID or index
  Future<bool> setPattern(dynamic patternIdOrIndex) async {
    final result = await _post('/api/pattern', {'pattern': patternIdOrIndex});
    return result != null && result['success'] == true;
  }

  /// Set lamp brightness (0-100 or 0-255)
  Future<bool> setBrightness(int brightness) async {
    final result = await _post('/api/brightness', {'brightness': brightness});
    return result != null && result['success'] == true;
  }

  /// Set custom RGB color
  Future<bool> setColor(int r, int g, int b) async {
    final result = await _post('/api/color', {'r': r, 'g': g, 'b': b});
    return result != null && result['success'] == true;
  }

  /// Set color via HSV color wheel
  Future<bool> setColorWheel(int hue, int saturation, int value) async {
    final result = await _post('/api/colorwheel', {
      'h': hue,
      's': saturation,
      'v': value,
    });
    return result != null && result['success'] == true;
  }

  /// Get available patterns from device
  Future<List<Map<String, dynamic>>?> getPatterns() async {
    final result = await _get('/api/patterns');
    if (result != null && result['patterns'] is List) {
      return (result['patterns'] as List).cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// Scan available WiFi networks
  Future<List<Map<String, dynamic>>?> scanWiFiNetworks() async {
    final result = await _get('/api/wifi/scan');
    if (result != null && result['networks'] is List) {
      return (result['networks'] as List).cast<Map<String, dynamic>>();
    }
    return null;
  }

  /// Configure WiFi credentials
  Future<bool> setWiFiCredentials(String ssid, String password) async {
    final result = await _post('/api/wifi', {
      'ssid': ssid,
      'password': password,
    });
    return result != null && result['success'] == true;
  }

  /// Restart the device
  Future<bool> restart() async {
    final result = await _post('/api/restart', {});
    return result != null;
  }

  /// Set gyro mode enabled/disabled
  Future<Map<String, dynamic>?> setGyro({bool? enabled, int? pattern}) async {
    final body = <String, dynamic>{};
    if (enabled != null) body['enabled'] = enabled;
    if (pattern != null) body['pattern'] = pattern;
    return await _post('/api/gyro', body);
  }

  /// Get gyro status
  Future<Map<String, dynamic>?> getGyroStatus() async {
    return await _get('/api/gyro');
  }

  /// Set reading light warmth (0-100)
  Future<bool> setReadingWarmth(int warmth) async {
    final result = await _post('/api/reading-warmth', {'warmth': warmth});
    return result != null && result['success'] == true;
  }

  /// Get pattern-specific configuration
  Future<Map<String, dynamic>?> getPatternConfig([int? patternIndex]) async {
    final endpoint = patternIndex != null
        ? '/api/pattern-config?pattern=$patternIndex'
        : '/api/pattern-config';
    return await _get(endpoint);
  }

  /// Set pattern-specific configuration
  Future<bool> setPatternConfig(
    int patternIndex,
    Map<String, dynamic> config,
  ) async {
    final body = <String, dynamic>{'pattern': patternIndex, ...config};
    debugPrint('LampAPI: Setting pattern config: $body');
    final result = await _post('/api/pattern-config', body);
    return result != null && result['success'] == true;
  }

  /// Check if device is reachable
  Future<bool> ping() async {
    try {
      final response = await _client
          .get(Uri.parse('$baseUrl/'))
          .timeout(const Duration(seconds: 2));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Dispose resources
  void dispose() {
    _client.close();
  }
}
