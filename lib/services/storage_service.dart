import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:crypto/crypto.dart';
import '../models/iot_device.dart';

/// Service for local storage of devices and settings
class StorageService {
  static const String _devicesBoxName = 'devices';
  static const String _settingsBoxName = 'settings';

  Box<IoTDevice>? _devicesBox;
  Box<dynamic>? _settingsBox;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _initialized = false;

  /// Initialize Hive and open boxes
  Future<void> init() async {
    if (_initialized) return;

    // Open boxes (adapters should already be registered in main)
    _devicesBox = Hive.box<IoTDevice>(_devicesBoxName);
    _settingsBox = await Hive.openBox(_settingsBoxName);

    _initialized = true;
  }

  // ==================== DEVICE OPERATIONS ====================

  /// Get all saved devices
  List<IoTDevice> getAllDevices() {
    return _devicesBox?.values.toList() ?? [];
  }

  /// Get device by ID
  IoTDevice? getDevice(String id) {
    return _devicesBox?.get(id);
  }

  /// Save or update device
  Future<void> saveDevice(IoTDevice device) async {
    await _devicesBox?.put(device.id, device);
  }

  /// Delete device
  Future<void> deleteDevice(String id) async {
    await _devicesBox?.delete(id);
    await deleteDevicePassword(id);
  }

  // ==================== SECURE PASSWORD STORAGE ====================

  /// Store device password securely
  Future<void> setDevicePassword(String ipAddress, String password) async {
    await _secureStorage.write(key: 'pwd_$ipAddress', value: password);
  }

  /// Get stored password for device
  Future<String?> getDevicePassword(String ipAddress) async {
    return await _secureStorage.read(key: 'pwd_$ipAddress');
  }

  /// Delete device password
  Future<void> deleteDevicePassword(String id) async {
    await _secureStorage.delete(key: 'pwd_$id');
  }

  /// Hash password using SHA256
  String hashPassword(String password) {
    final bytes = utf8.encode(password);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // ==================== SETTINGS OPERATIONS ====================

  /// Get setting value
  T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox?.get(key, defaultValue: defaultValue) as T?;
  }

  /// Save setting value
  Future<void> saveSetting<T>(String key, T value) async {
    await _settingsBox?.put(key, value);
  }

  // ==================== CUSTOM COLORS STORAGE ====================

  /// Get custom colors for a device
  Future<List<Map<String, dynamic>>> getCustomColors(String ipAddress) async {
    final data = _settingsBox?.get('colors_$ipAddress');
    if (data != null && data is List) {
      return data.cast<Map<String, dynamic>>();
    }
    return [];
  }

  /// Save custom colors for a device
  Future<void> saveCustomColors(
    String ipAddress,
    List<Map<String, dynamic>> colors,
  ) async {
    await _settingsBox?.put('colors_$ipAddress', colors);
  }

  // ==================== CLEANUP ====================

  /// Clear all data
  Future<void> clearAll() async {
    await _devicesBox?.clear();
    await _settingsBox?.clear();
    await _secureStorage.deleteAll();
  }

  /// Close boxes
  Future<void> close() async {
    await _devicesBox?.close();
    await _settingsBox?.close();
  }
}
