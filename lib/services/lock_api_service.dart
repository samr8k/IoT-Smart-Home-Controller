import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// API service for communicating with Smart Lock devices
class LockApiService {
  final String ipAddress;
  String? _authToken;

  LockApiService(this.ipAddress);

  String get baseUrl => 'http://$ipAddress';

  /// Authenticate with the lock
  Future<bool> authenticate(String password) async {
    _authToken = password;

    // Test authentication by calling a protected endpoint
    try {
      final status = await getStatus();
      return status != null && status['success'] == true;
    } catch (e) {
      debugPrint('Authentication failed: $e');
      return false;
    }
  }

  /// Get lock status and entry logs
  Future<Map<String, dynamic>?> getStatus() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/status'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting status: $e');
    }
    return null;
  }

  /// Get device info (no auth required)
  Future<Map<String, dynamic>?> getInfo() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/info'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error getting info: $e');
    }
    return null;
  }

  /// Unlock the lock remotely
  Future<bool> unlock() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/unlock'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error unlocking: $e');
      return false;
    }
  }

  /// Lock the lock remotely (force close)
  Future<bool> lock() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/lock'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error locking: $e');
      return false;
    }
  }

  /// Set LED color
  Future<bool> setLedColor(int r, int g, int b) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/led-color'),
            headers: {
              'Authorization': 'Bearer $_authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'r': r, 'g': g, 'b': b}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error setting LED color: $e');
      return false;
    }
  }

  /// Add authorized card
  Future<bool> addCard(String uid) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/add-card'),
            headers: {
              'Authorization': 'Bearer $_authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'uid': uid}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error adding card: $e');
      return false;
    }
  }

  /// Remove authorized card
  Future<bool> removeCard(String uid) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/remove-card'),
            headers: {
              'Authorization': 'Bearer $_authToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'uid': uid}),
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error removing card: $e');
      return false;
    }
  }

  /// List authorized cards
  Future<Map<String, dynamic>?> listCards() async {
    try {
      final response = await http
          .get(
            Uri.parse('$baseUrl/api/cards'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
    } catch (e) {
      debugPrint('Error listing cards: $e');
    }
    return null;
  }

  /// Clear entry logs
  Future<bool> clearLogs() async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/logs/clear'),
            headers: {'Authorization': 'Bearer $_authToken'},
          )
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error clearing logs: $e');
      return false;
    }
  }

  /// Get export URL for logs
  String getExportUrl(String format) {
    return '$baseUrl/api/logs/$format'; // format: 'csv' or 'pdf'
  }
}
