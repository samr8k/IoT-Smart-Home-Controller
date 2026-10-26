import 'package:flutter/material.dart' hide LockState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import '../models/iot_device.dart';
import '../models/lock_state.dart';
import '../models/connection_status.dart';
import '../providers/lock_provider.dart';
import '../widgets/connection_status_indicator.dart';

/// Screen for controlling a Smart Lock device
class LockControlScreen extends ConsumerStatefulWidget {
  final IoTDevice device;

  const LockControlScreen({super.key, required this.device});

  @override
  ConsumerState<LockControlScreen> createState() => _LockControlScreenState();
}

class _LockControlScreenState extends ConsumerState<LockControlScreen> {
  Color? _selectedColor;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    // Initialize the lock provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(lockStateProvider(widget.device.ipAddress).notifier)
          .initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(lockStateProvider(widget.device.ipAddress));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.device.name),
        actions: [
          ConnectionStatusIndicator(
            status: lockState?.isConnected ?? false
                ? ConnectionStatus.connected
                : ConnectionStatus.disconnected,
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: lockState == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await ref
                    .read(lockStateProvider(widget.device.ipAddress).notifier)
                    .refreshStatus();
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Main lock control card
                    _buildLockControlCard(lockState),
                    const SizedBox(height: 16),

                    // LED color control
                    _buildLedColorCard(lockState),
                    const SizedBox(height: 16),

                    // Statistics card
                    _buildStatsCard(lockState),
                    const SizedBox(height: 16),

                    // Recent entries
                    _buildRecentEntriesCard(lockState),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLockControlCard(LockState lockState) {
    final isLocked = lockState.isLocked;

    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Lock icon
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isLocked
                    ? Colors.red.withOpacity(0.1)
                    : Colors.green.withOpacity(0.1),
              ),
              child: Icon(
                isLocked ? Icons.lock : Icons.lock_open,
                size: 80,
                color: isLocked ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 24),

            // Status text
            Text(
              isLocked ? 'LOCKED' : 'UNLOCKED',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: isLocked ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 24),

            // Control buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing || !isLocked
                        ? null
                        : () => _handleUnlock(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.lock_open),
                    label: const Text('Unlock'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isProcessing || isLocked
                        ? null
                        : () => _handleLock(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.lock),
                    label: const Text('Lock'),
                  ),
                ),
              ],
            ),
            if (_isProcessing)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: CircularProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildLedColorCard(LockState lockState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LED Color', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text(
              'Customize the idle LED color',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            Center(
              child: GestureDetector(
                onTap: () => _showColorPicker(lockState),
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _selectedColor ?? lockState.ledColor ?? Colors.blue,
                    border: Border.all(color: Colors.grey, width: 2),
                  ),
                  child: const Icon(
                    Icons.palette,
                    color: Colors.white,
                    size: 40,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                'Tap to change',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard(LockState lockState) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Statistics', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            _buildStatRow(
              icon: Icons.credit_card,
              label: 'Authorized Cards',
              value: lockState.numCards.toString(),
              color: Colors.blue,
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.history,
              label: 'Recent Entries',
              value: lockState.recentEntries.length.toString(),
              color: Colors.orange,
            ),
            const Divider(),
            _buildStatRow(
              icon: Icons.timer,
              label: 'Uptime',
              value: lockState.uptimeDisplay.isNotEmpty
                  ? lockState.uptimeDisplay
                  : 'N/A',
              color: Colors.purple,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentEntriesCard(LockState lockState) {
    if (lockState.recentEntries.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 8),
              Text(
                'No recent entries',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Entries',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  label: const Text('Clear'),
                  onPressed: () => _confirmClearLogs(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: lockState.recentEntries.length.clamp(0, 10),
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final entry = lockState
                    .recentEntries[lockState.recentEntries.length - 1 - index];
                return _buildEntryTile(entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntryTile(LockEntry entry) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: entry.color.withOpacity(0.2),
        child: Icon(entry.icon, color: entry.color),
      ),
      title: Text(
        entry.granted ? 'Access Granted' : 'Access Denied',
        style: TextStyle(fontWeight: FontWeight.bold, color: entry.color),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Card: ${entry.cardUID}'),
          if (entry.remoteIP != null) Text('Remote: ${entry.remoteIP}'),
          Text(
            entry.formattedTime,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
          ),
        ],
      ),
      trailing: Text(
        entry.relativeTime,
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  Future<void> _confirmClearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Logs'),
        content: const Text('Are you sure you want to clear all entry logs?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isProcessing = true);
      try {
        final success = await ref
            .read(lockStateProvider(widget.device.ipAddress).notifier)
            .clearLogs();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(success ? 'Logs cleared' : 'Failed to clear logs'),
              backgroundColor: success ? Colors.green : Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isProcessing = false);
        }
      }
    }
  }

  Future<void> _handleUnlock() async {
    setState(() => _isProcessing = true);
    try {
      final success = await ref
          .read(lockStateProvider(widget.device.ipAddress).notifier)
          .unlock();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success ? 'Unlocked for 5 seconds' : 'Failed to unlock',
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _handleLock() async {
    setState(() => _isProcessing = true);
    try {
      final success = await ref
          .read(lockStateProvider(widget.device.ipAddress).notifier)
          .lock();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Locked' : 'Failed to lock'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _showColorPicker(LockState lockState) async {
    Color pickerColor = _selectedColor ?? lockState.ledColor ?? Colors.blue;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Pick LED Color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: pickerColor,
              onColorChanged: (color) {
                pickerColor = color;
              },
              pickerAreaHeightPercent: 0.8,
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Set Color'),
              onPressed: () async {
                Navigator.of(context).pop();
                setState(() => _selectedColor = pickerColor);

                final success = await ref
                    .read(lockStateProvider(widget.device.ipAddress).notifier)
                    .setLedColor(pickerColor);

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        success
                            ? 'LED color updated'
                            : 'Failed to update color',
                      ),
                      backgroundColor: success ? Colors.green : Colors.red,
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }
}
