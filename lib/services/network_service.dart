import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:network_info_plus/network_info_plus.dart';

/// WiFi information model
class WifiInfo {
  final String? ssid;
  final String? bssid;
  final String? ipAddress;
  final bool isConnected;
  final int? signalStrength;

  const WifiInfo({
    this.ssid,
    this.bssid,
    this.ipAddress,
    this.isConnected = false,
    this.signalStrength,
  });

  factory WifiInfo.disconnected() {
    return const WifiInfo(isConnected: false);
  }
}

/// Service for monitoring network connectivity and WiFi information
class NetworkService {
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfo();

  StreamController<WifiInfo>? _wifiStreamController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  WifiInfo _currentWifiInfo = WifiInfo.disconnected();

  /// Current WiFi info
  WifiInfo get currentWifiInfo => _currentWifiInfo;

  /// Stream of WiFi info updates
  Stream<WifiInfo> get wifiStream {
    _wifiStreamController ??= StreamController<WifiInfo>.broadcast();
    _startListening();
    return _wifiStreamController!.stream;
  }

  /// Start listening for connectivity changes
  void _startListening() {
    _connectivitySubscription?.cancel();
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (results) => _updateWifiInfo(),
    );
    // Initial update
    _updateWifiInfo();
  }

  /// Update WiFi information
  Future<void> _updateWifiInfo() async {
    try {
      final results = await _connectivity.checkConnectivity();
      final isWifiConnected = results.contains(ConnectivityResult.wifi);

      if (isWifiConnected) {
        final ssid = await _networkInfo.getWifiName();
        final bssid = await _networkInfo.getWifiBSSID();
        final ipAddress = await _networkInfo.getWifiIP();

        _currentWifiInfo = WifiInfo(
          ssid: ssid?.replaceAll('"', ''),
          bssid: bssid,
          ipAddress: ipAddress,
          isConnected: true,
        );
      } else {
        _currentWifiInfo = WifiInfo.disconnected();
      }

      _wifiStreamController?.add(_currentWifiInfo);
    } catch (e) {
      debugPrint('Error getting WiFi info: $e');
      _currentWifiInfo = WifiInfo.disconnected();
      _wifiStreamController?.add(_currentWifiInfo);
    }
  }

  /// Manually refresh WiFi info
  Future<WifiInfo> refreshWifiInfo() async {
    await _updateWifiInfo();
    return _currentWifiInfo;
  }

  /// Check if connected to WiFi
  Future<bool> isConnectedToWifi() async {
    final results = await _connectivity.checkConnectivity();
    return results.contains(ConnectivityResult.wifi);
  }

  /// Check if connected to any network
  Future<bool> hasNetworkConnection() async {
    final results = await _connectivity.checkConnectivity();
    return !results.contains(ConnectivityResult.none);
  }

  /// Dispose resources
  void dispose() {
    _connectivitySubscription?.cancel();
    _wifiStreamController?.close();
    _wifiStreamController = null;
  }
}
