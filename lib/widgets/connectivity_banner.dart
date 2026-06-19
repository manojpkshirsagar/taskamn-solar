import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/connectivity_service.dart';
import '../services/sync_service.dart';

/// A pill-shaped indicator shown in the AppBar showing 🟢/🔴 network status
/// and a badge for pending sync count. Tapping opens the sync queue screen.
class ConnectivityBanner extends StatelessWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ConnectivityService, SyncService>(
      builder: (context, conn, sync, _) {
        final isOnline = conn.isOnline;
        final pendingCount = sync.pendingSyncCount;
        final isSyncing = sync.isSyncing;

        return GestureDetector(
          onTap: () {
            Navigator.of(context).pushNamed('/sync-queue');
          },
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: isOnline
                  ? Colors.green.withOpacity(0.12)
                  : Colors.red.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isOnline ? Colors.green : Colors.red,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (isSyncing)
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: CircularProgressIndicator(
                      strokeWidth: 1.5,
                      color: Colors.orange[700],
                    ),
                  )
                else
                  Icon(
                    isOnline ? Icons.wifi : Icons.wifi_off,
                    size: 13,
                    color: isOnline ? Colors.green[700] : Colors.red[700],
                  ),
                const SizedBox(width: 4),
                Text(
                  isSyncing
                      ? 'Syncing...'
                      : isOnline
                          ? 'Online'
                          : 'Offline',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isSyncing
                        ? Colors.orange[800]
                        : isOnline
                            ? Colors.green[800]
                            : Colors.red[800],
                  ),
                ),
                if (pendingCount > 0 && !isSyncing) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$pendingCount',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Larger banner shown below the AppBar when offline — more visible for users
class OfflineBannerStrip extends StatelessWidget {
  const OfflineBannerStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConnectivityService>(
      builder: (context, conn, _) {
        if (conn.isOnline) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: const Color(0xFFD32F2F),
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white, size: 14),
              const SizedBox(width: 6),
              const Text(
                '🔴 Offline Mode — Changes saved locally',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
