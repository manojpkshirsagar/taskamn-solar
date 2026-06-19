import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/sync_service.dart';
import '../../services/connectivity_service.dart';
import '../../services/storage_service.dart';
import '../../models/sync_queue_item.dart';
import '../../constants/colors.dart';

class SyncQueueScreen extends StatefulWidget {
  const SyncQueueScreen({super.key});

  @override
  State<SyncQueueScreen> createState() => _SyncQueueScreenState();
}

class _SyncQueueScreenState extends State<SyncQueueScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  List<SyncQueueItem> _itemsByStatus(String status) {
    return StorageService.getSyncQueue()
        .where((i) => i.syncStatus == status)
        .toList();
  }

  List<SyncQueueItem> _pendingItems() {
    return StorageService.getSyncQueue()
        .where((i) => i.syncStatus == 'Pending' || i.syncStatus == 'Failed')
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<SyncService, ConnectivityService>(
      builder: (context, sync, conn, _) {
        final pending = _pendingItems();
        final success = _itemsByStatus('Success');
        final failed = _itemsByStatus('Failed');

        return Scaffold(
          appBar: AppBar(
            title: const Text('Sync Queue'),
            backgroundColor: AppColors.primarySolarOrange,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Pending (${pending.length})'),
                Tab(text: 'Failed (${failed.length})'),
                Tab(text: 'Success (${success.length})'),
              ],
            ),
          ),
          body: Column(
            children: [
              // Status bar
              if (sync.isSyncing || sync.syncStatusMessage.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  color: sync.isSyncing
                      ? Colors.orange.shade50
                      : sync.syncStatusMessage.contains('complete')
                          ? Colors.green.shade50
                          : Colors.grey.shade100,
                  child: Row(
                    children: [
                      if (sync.isSyncing)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        Icon(
                          sync.syncStatusMessage.contains('complete')
                              ? Icons.check_circle
                              : Icons.info_outline,
                          size: 16,
                          color: sync.syncStatusMessage.contains('complete')
                              ? Colors.green
                              : Colors.grey,
                        ),
                      const SizedBox(width: 8),
                      Text(
                        sync.syncStatusMessage,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _SyncItemList(items: pending, emptyLabel: 'No pending items'),
                    _SyncItemList(items: failed, emptyLabel: 'No failed items', showError: true),
                    _SyncItemList(items: success, emptyLabel: 'No synced items yet'),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: pending.isNotEmpty
              ? FloatingActionButton.extended(
                  onPressed: sync.isSyncing
                      ? null
                      : () async {
                          if (!conn.isOnline) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('No internet connection'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }
                          await sync.syncAll();
                          setState(() {});
                        },
                  backgroundColor: sync.isSyncing
                      ? Colors.grey
                      : AppColors.primarySolarOrange,
                  icon: sync.isSyncing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.sync, color: Colors.white),
                  label: Text(
                    sync.isSyncing ? 'Syncing...' : 'Sync Now',
                    style: const TextStyle(color: Colors.white),
                  ),
                )
              : null,
        );
      },
    );
  }
}

class _SyncItemList extends StatelessWidget {
  final List<SyncQueueItem> items;
  final String emptyLabel;
  final bool showError;

  const _SyncItemList({
    required this.items,
    required this.emptyLabel,
    this.showError = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline,
                size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(emptyLabel,
                style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _SyncItemCard(item: items[i], showError: showError),
    );
  }
}

class _SyncItemCard extends StatelessWidget {
  final SyncQueueItem item;
  final bool showError;
  const _SyncItemCard({required this.item, required this.showError});

  Color _statusColor(String status) {
    switch (status) {
      case 'Pending':   return Colors.orange;
      case 'Syncing':   return Colors.blue;
      case 'Success':   return Colors.green;
      case 'Failed':    return Colors.red;
      default:          return Colors.grey;
    }
  }

  IconData _actionIcon(String action) {
    switch (action) {
      case 'CREATE': return Icons.add_circle_outline;
      case 'UPDATE': return Icons.edit_outlined;
      case 'DELETE': return Icons.delete_outline;
      default:       return Icons.sync;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.syncStatus);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withOpacity(0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 4,
            offset: const Offset(0, 2),
          )
        ],
      ),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: statusColor.withOpacity(0.12),
          child: Icon(_actionIcon(item.actionType),
              color: statusColor, size: 20),
        ),
        title: Text(
          '${item.moduleName.replaceAll('_', ' ').toUpperCase()}',
          style: const TextStyle(
              fontWeight: FontWeight.w600, fontSize: 13),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${item.actionType}  ·  ${item.recordId.length > 12 ? item.recordId.substring(0, 12) + "..." : item.recordId}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
            if (showError && item.errorMessage != null) ...[
              const SizedBox(height: 3),
              Text(
                item.errorMessage!,
                style: const TextStyle(color: Colors.red, fontSize: 11),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                item.syncStatus,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(item.createdAt),
              style: TextStyle(color: Colors.grey.shade400, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
