import 'package:flutter/material.dart';
import '../models/iot_device.dart';
import '../models/connection_status.dart';

class DeviceTile extends StatelessWidget {
  final IoTDevice device;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const DeviceTile({
    super.key,
    required this.device,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final isConnected = device.connectionStatus == ConnectionStatus.connected;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Background gradient
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      device.deviceType.color.withAlpha(26),
                      device.deviceType.color.withAlpha(51),
                    ],
                  ),
                ),
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: device.deviceType.color.withAlpha(51),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          device.deviceType.icon,
                          color: device.deviceType.color,
                          size: 28,
                        ),
                      ),
                      _buildStatusIndicator(context),
                    ],
                  ),

                  const Spacer(),

                  // Device name
                  Text(
                    device.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 4),

                  // Device type
                  Text(
                    device.deviceType.displayName,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                  ),

                  const SizedBox(height: 8),

                  // IP Address
                  Row(
                    children: [
                      Icon(
                        Icons.wifi,
                        size: 14,
                        color: isConnected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          device.ipAddress,
                          style: Theme.of(
                            context,
                          ).textTheme.bodySmall?.copyWith(color: Colors.grey),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Connecting overlay
            if (device.connectionStatus == ConnectionStatus.connecting)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withAlpha(102),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context) {
    Color color;
    IconData icon;

    switch (device.connectionStatus) {
      case ConnectionStatus.connected:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case ConnectionStatus.connecting:
        color = Colors.orange;
        icon = Icons.sync;
        break;
      case ConnectionStatus.disconnected:
        color = Colors.red;
        icon = Icons.cancel;
        break;
      case ConnectionStatus.error:
        color = Colors.red;
        icon = Icons.error;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: color.withAlpha(51),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, size: 20, color: color),
    );
  }
}
