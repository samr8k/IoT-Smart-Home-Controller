import 'package:flutter/material.dart';

/// Represents the state of a Smart Lock
@immutable
class LockState {
  final bool isLocked;
  final bool isConnected;
  final Color? ledColor;
  final int numCards;
  final List<LockEntry> recentEntries;
  final String uptime; // raw string from device (e.g., "0d 00:11:58")
  final int uptimeSeconds; // parsed seconds snapshot at fetch time
  final DateTime? uptimeFetchedAt; // when uptimeSeconds was recorded

  const LockState({
    required this.isLocked,
    this.isConnected = false,
    this.ledColor,
    this.numCards = 0,
    this.recentEntries = const [],
    this.uptime = '',
    this.uptimeSeconds = 0,
    this.uptimeFetchedAt,
  });

  LockState copyWith({
    bool? isLocked,
    bool? isConnected,
    Color? ledColor,
    int? numCards,
    List<LockEntry>? recentEntries,
    String? uptime,
    int? uptimeSeconds,
    DateTime? uptimeFetchedAt,
  }) {
    return LockState(
      isLocked: isLocked ?? this.isLocked,
      isConnected: isConnected ?? this.isConnected,
      ledColor: ledColor ?? this.ledColor,
      numCards: numCards ?? this.numCards,
      recentEntries: recentEntries ?? this.recentEntries,
      uptime: uptime ?? this.uptime,
      uptimeSeconds: uptimeSeconds ?? this.uptimeSeconds,
      uptimeFetchedAt: uptimeFetchedAt ?? this.uptimeFetchedAt,
    );
  }

  /// Calculated uptime shown to the user without extra device calls.
  String get uptimeDisplay {
    int seconds = uptimeSeconds;
    if (uptimeFetchedAt != null && isConnected) {
      final elapsed = DateTime.now().difference(uptimeFetchedAt!).inSeconds;
      if (elapsed > 0) seconds += elapsed;
    }
    return _formatDuration(seconds);
  }

  String _formatDuration(int totalSeconds) {
    final days = totalSeconds ~/ 86400;
    totalSeconds %= 86400;
    final hours = totalSeconds ~/ 3600;
    totalSeconds %= 3600;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${days}d ${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }
}

/// Represents a lock entry/access log
@immutable
class LockEntry {
  final int timestamp;
  final String cardUID;
  final bool granted;
  final String? remoteIP;

  const LockEntry({
    required this.timestamp,
    required this.cardUID,
    required this.granted,
    this.remoteIP,
  });

  factory LockEntry.fromJson(Map<String, dynamic> json) {
    // Firmware sends seconds (epoch), Dart uses milliseconds
    final rawTimestamp = json['timestamp'] ?? 0;
    final timestampMillis = rawTimestamp < 10000000000
        ? rawTimestamp * 1000
        : rawTimestamp;

    return LockEntry(
      timestamp: timestampMillis,
      cardUID: json['cardUID'] ?? '',
      granted: json['granted'] ?? false,
      remoteIP: json['remoteIP'],
    );
  }

  /// Format timestamp to relative time
  String get relativeTime {
    final now = DateTime.now().millisecondsSinceEpoch;
    final diff = now - timestamp;

    if (diff < 60000) {
      return 'Just now';
    } else if (diff < 3600000) {
      final mins = (diff / 60000).floor();
      return '$mins min${mins > 1 ? 's' : ''} ago';
    } else if (diff < 86400000) {
      final hours = (diff / 3600000).floor();
      return '$hours hour${hours > 1 ? 's' : ''} ago';
    } else {
      final days = (diff / 86400000).floor();
      return '$days day${days > 1 ? 's' : ''} ago';
    }
  }

  /// Format timestamp to absolute date time
  String get formattedTime {
    final dt = DateTime.fromMillisecondsSinceEpoch(timestamp);
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  IconData get icon => granted ? Icons.check_circle : Icons.cancel;
  Color get color => granted ? Colors.green : Colors.red;
}
