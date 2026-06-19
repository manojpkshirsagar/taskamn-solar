import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../services/sync_service.dart';
import '../services/connectivity_service.dart';

/// Wraps a screen body and intercepts the back button when there are
/// unsynced changes pending. Shows a dialog with Sync Now / Exit Anyway / Cancel.
class UnsyncedExitGuard extends StatelessWidget {
  final Widget child;
  const UnsyncedExitGuard({super.key, required this.child});

  Future<bool> _onWillPop(BuildContext context) async {
    final pendingCount = StorageService.getPendingSyncCount();
    if (pendingCount == 0) return true;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.sync_problem,
                  color: Colors.orange.shade700, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Unsynced Changes',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: Text(
          'You have $pendingCount unsynced change${pendingCount > 1 ? 's' : ''}.\n\n'
          'These will be uploaded to the server next time you are online.',
          style: const TextStyle(fontSize: 14),
        ),
        actionsPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'exit'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.red),
            ),
            child: const Text('Exit Anyway',
                style: TextStyle(color: Colors.red)),
          ),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context, 'sync'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
            ),
            icon: const Icon(Icons.sync, color: Colors.white, size: 16),
            label: const Text('Sync Now',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (result == 'exit') return true;
    if (result == 'sync') {
      if (ConnectivityService.instance.isOnline) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Syncing...'),
              duration: Duration(seconds: 2),
            ),
          );
        }
        await SyncService.instance.syncAll();
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No internet. Changes will sync when online.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldPop = await _onWillPop(context);
        if (shouldPop && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: child,
    );
  }
}
