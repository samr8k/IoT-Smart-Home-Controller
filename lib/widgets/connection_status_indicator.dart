import 'package:flutter/material.dart';
import '../models/connection_status.dart';

class ConnectionStatusIndicator extends StatelessWidget {
  final ConnectionStatus status;
  final bool showLabel;
  final double size;

  const ConnectionStatusIndicator({
    super.key,
    required this.status,
    this.showLabel = false,
    this.size = 12,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = _getStatusInfo();

    if (showLabel) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withAlpha(26),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status == ConnectionStatus.connecting)
              SizedBox(
                width: size,
                height: size,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else
              Icon(icon, size: size + 4, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    // Just the dot indicator
    if (status == ConnectionStatus.connecting) {
      return SizedBox(
        width: size,
        height: size,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      );
    }

    return Container(
      width: size,
      height: size,
      margin: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withAlpha(128),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  (Color, IconData, String) _getStatusInfo() {
    switch (status) {
      case ConnectionStatus.connected:
        return (Colors.green, Icons.check_circle, 'Connected');
      case ConnectionStatus.connecting:
        return (Colors.orange, Icons.sync, 'Connecting');
      case ConnectionStatus.disconnected:
        return (Colors.grey, Icons.cancel, 'Disconnected');
      case ConnectionStatus.error:
        return (Colors.red, Icons.error, 'Error');
    }
  }
}
