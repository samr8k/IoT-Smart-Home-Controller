import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/network_service.dart';

class WifiInfoCard extends StatelessWidget {
  final AsyncValue<WifiInfo?> wifiInfo;

  const WifiInfoCard({super.key, required this.wifiInfo});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: wifiInfo.when(
          data: (info) => _buildContent(context, info),
          loading: () => _buildLoading(context),
          error: (e, _) => _buildError(context, e),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, WifiInfo? info) {
    if (info == null) {
      return _buildNotConnected(context);
    }

    return Row(
      children: [
        // WiFi icon with signal indicator
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.wifi, color: Colors.green, size: 32),
        ),
        const SizedBox(width: 16),

        // WiFi info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                info.ssid ?? 'Connected WiFi',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.computer, size: 14, color: Colors.grey.shade400),
                  const SizedBox(width: 4),
                  Text(
                    info.ipAddress ?? 'No IP',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Connected badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withAlpha(26),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 16, color: Colors.green),
              SizedBox(width: 4),
              Text(
                'Connected',
                style: TextStyle(
                  color: Colors.green,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNotConnected(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.orange.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.wifi_off, color: Colors.orange, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Not Connected',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Connect to WiFi to discover devices',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade400),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.grey.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          'Checking network...',
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, Object error) {
    return Row(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: Colors.red.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.error_outline, color: Colors.red, size: 32),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Network Error',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                error.toString(),
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.red.shade300),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
