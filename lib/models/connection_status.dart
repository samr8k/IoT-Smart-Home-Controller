/// Enum representing device connection status
enum ConnectionStatus {
  connected('connected', 'Connected'),
  disconnected('disconnected', 'Disconnected'),
  connecting('connecting', 'Connecting...'),
  error('error', 'Error');

  final String id;
  final String displayName;

  const ConnectionStatus(this.id, this.displayName);

  static ConnectionStatus fromId(String id) {
    return ConnectionStatus.values.firstWhere(
      (status) => status.id == id,
      orElse: () => ConnectionStatus.disconnected,
    );
  }

  static ConnectionStatus fromString(String name) {
    final lowered = name.toLowerCase();
    if (lowered.contains('connected') && !lowered.contains('dis')) {
      return ConnectionStatus.connected;
    }
    if (lowered.contains('connecting')) {
      return ConnectionStatus.connecting;
    }
    if (lowered.contains('error')) {
      return ConnectionStatus.error;
    }
    return ConnectionStatus.disconnected;
  }
}
