import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/lock_state.dart';
import '../services/lock_api_service.dart';
import '../services/storage_service.dart';
import 'device_provider.dart';

/// Lock state notifier for a specific device
class LockStateNotifier extends StateNotifier<LockState?> {
  final String ipAddress;
  final StorageService _storage;
  late final LockApiService _apiService;
  bool _isInitialized = false;
  Timer? _refreshTimer;

  LockStateNotifier({required this.ipAddress, required StorageService storage})
    : _storage = storage,
      super(null) {
    _apiService = LockApiService(ipAddress);
  }

  /// Initialize by authenticating and fetching current state from device
  Future<void> initialize() async {
    if (_isInitialized && state != null) return;

    _isInitialized = true;

    try {
      debugPrint('LockProvider: Initializing for $ipAddress with 10s timeout');
      await _doInitialize().timeout(const Duration(seconds: 10));
    } catch (e) {
      debugPrint('LockProvider: Error or timeout during init: $e');
    }

    if (mounted && state == null) {
      debugPrint(
        'LockProvider: State was null after init attempt, creating default state.',
      );
      state = const LockState(isLocked: true, isConnected: false);
    }
  }

  Future<void> _doInitialize() async {
    debugPrint('LockProvider: Authenticating and fetching status...');

    // First, try to authenticate with stored password
    final savedPassword = await _storage.getDevicePassword(ipAddress);
    if (savedPassword != null && savedPassword.isNotEmpty) {
      debugPrint('LockProvider: Found saved password, authenticating...');
      await _apiService.authenticate(savedPassword);
    } else {
      // Try default password
      debugPrint('LockProvider: No saved password, trying default...');
      await _apiService.authenticate('x');
    }

    // Now fetch status
    await refreshStatus();
  }

  /// Refresh status from device
  Future<void> refreshStatus() async {
    if (!mounted) return;

    try {
      final status = await _apiService.getStatus();
      debugPrint('LockProvider: Status response: $status');

      if (mounted && status != null && status['success'] == true) {
        final entries = <LockEntry>[];
        if (status['logs'] != null) {
          for (final log in status['logs']) {
            entries.add(LockEntry.fromJson(log));
          }
        }

        final uptimeStr = status['uptime'] ?? '';
        final uptimeSeconds = _parseUptimeSeconds(uptimeStr);
        final fetchedAt = DateTime.now();

        state = LockState(
          isLocked: status['locked'] ?? true,
          isConnected: true,
          numCards: status['numCards'] ?? 0,
          recentEntries: entries,
          uptime: uptimeStr,
          uptimeSeconds: uptimeSeconds,
          uptimeFetchedAt: fetchedAt,
        );
        debugPrint('LockProvider: Status updated successfully');
      } else {
        if (mounted && state != null) {
          state = state!.copyWith(isConnected: false);
        }
      }
    } catch (e) {
      debugPrint('LockProvider: Error refreshing status: $e');
      if (mounted && state != null) {
        state = state!.copyWith(isConnected: false);
      }
    }
  }

  int _parseUptimeSeconds(String uptime) {
    // Expected format: "Xd HH:MM:SS"; fall back to 0 on parse errors.
    try {
      if (uptime.isEmpty) return 0;
      final parts = uptime.split(' ');
      if (parts.length != 2) return 0;
      final days = int.tryParse(parts[0].replaceAll('d', '')) ?? 0;
      final hms = parts[1].split(':');
      if (hms.length != 3) return 0;
      final hours = int.tryParse(hms[0]) ?? 0;
      final minutes = int.tryParse(hms[1]) ?? 0;
      final seconds = int.tryParse(hms[2]) ?? 0;
      return days * 86400 + hours * 3600 + minutes * 60 + seconds;
    } catch (_) {
      return 0;
    }
  }

  /// Start periodic refresh (every 5 seconds)
  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => refreshStatus(),
    );
  }

  /// Unlock the lock
  Future<bool> unlock() async {
    try {
      final success = await _apiService.unlock();
      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
        await refreshStatus();
      }
      return success;
    } catch (e) {
      debugPrint('Error unlocking: $e');
      return false;
    }
  }

  /// Lock the lock
  Future<bool> lock() async {
    try {
      final success = await _apiService.lock();
      if (success) {
        await Future.delayed(const Duration(milliseconds: 500));
        await refreshStatus();
      }
      return success;
    } catch (e) {
      debugPrint('Error locking: $e');
      return false;
    }
  }

  /// Set LED color
  Future<bool> setLedColor(Color color) async {
    try {
      final success = await _apiService.setLedColor(
        color.red,
        color.green,
        color.blue,
      );
      if (success && mounted) {
        state = state!.copyWith(ledColor: color);
      }
      return success;
    } catch (e) {
      debugPrint('Error setting LED color: $e');
      return false;
    }
  }

  /// Add authorized card
  Future<bool> addCard(String uid) async {
    try {
      final success = await _apiService.addCard(uid);
      if (success) {
        await refreshStatus();
      }
      return success;
    } catch (e) {
      debugPrint('Error adding card: $e');
      return false;
    }
  }

  /// Remove authorized card
  Future<bool> removeCard(String uid) async {
    try {
      final success = await _apiService.removeCard(uid);
      if (success) {
        await refreshStatus();
      }
      return success;
    } catch (e) {
      debugPrint('Error removing card: $e');
      return false;
    }
  }

  /// Clear entry logs
  Future<bool> clearLogs() async {
    try {
      final success = await _apiService.clearLogs();
      if (success) {
        await refreshStatus();
      }
      return success;
    } catch (e) {
      debugPrint('Error clearing logs: $e');
      return false;
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }
}

/// Provider for a specific lock device
final lockStateProvider =
    StateNotifierProvider.family<LockStateNotifier, LockState?, String>((
      ref,
      ipAddress,
    ) {
      final storage = ref.watch(storageServiceProvider);
      return LockStateNotifier(ipAddress: ipAddress, storage: storage);
    });
