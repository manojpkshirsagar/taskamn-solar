import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';
import 'connectivity_service.dart';
import 'logger_service.dart';
import '../models/sync_queue_item.dart';
import 'package:uuid/uuid.dart';

/// SyncService manages the local sync queue and uploads pending items to Supabase.
/// It is triggered automatically when connectivity is restored, or manually by the user.
class SyncService extends ChangeNotifier {
  static final SyncService instance = SyncService._internal();
  SyncService._internal();

  bool _isSyncing = false;
  bool get isSyncing => _isSyncing;

  String _syncStatusMessage = '';
  String get syncStatusMessage => _syncStatusMessage;

  int get pendingSyncCount => StorageService.getPendingSyncCount();

  /// Initialize: wire up auto-sync when network returns.
  void init() {
    ConnectivityService.instance.onConnectivityRestored = () {
      syncAll();
    };
  }

  /// Adds a record to the local sync queue.
  Future<SyncQueueItem> enqueue({
    required String moduleName,
    required String recordId,
    required String actionType,
    required Map<String, dynamic> dataJson,
    String? employeeId,
  }) async {
    const uuid = Uuid();
    final item = SyncQueueItem(
      id: uuid.v4(),
      moduleName: moduleName,
      recordId: recordId,
      employeeId: employeeId,
      actionType: actionType,
      dataJson: dataJson,
      syncStatus: 'Pending',
      createdAt: DateTime.now(),
    );
    await StorageService.saveSyncQueueItem(item);
    notifyListeners();
    return item;
  }

  /// Processes all pending/failed items in the sync queue.
  Future<void> syncAll() async {
    if (_isSyncing) return;
    if (!ConnectivityService.instance.isOnline) {
      _syncStatusMessage = 'No internet connection';
      notifyListeners();
      return;
    }

    final pendingItems = StorageService.getPendingSyncItems();
    if (pendingItems.isEmpty) {
      _syncStatusMessage = 'All synced';
      notifyListeners();
      return;
    }

    _isSyncing = true;
    _syncStatusMessage = 'Syncing ${pendingItems.length} item(s)...';
    notifyListeners();

    int successCount = 0;
    int failCount = 0;

    for (final item in pendingItems) {
      await StorageService.updateSyncItemStatus(item.id, 'Syncing');
      notifyListeners();

      try {
        await _uploadItem(item);
        await StorageService.updateSyncItemStatus(item.id, 'Success');
        successCount++;
      } catch (e, stack) {
        debugPrint('[SyncService] Failed to sync ${item.moduleName}/${item.recordId}: $e');
        LoggerService.logError('SyncService', 'syncAll', e, stack);
        await StorageService.updateSyncItemStatus(
          item.id,
          'Failed',
          errorMessage: e.toString(),
        );
        failCount++;
      }
    }

    // Clean up successful entries after a short delay
    await Future.delayed(const Duration(seconds: 2));
    await StorageService.clearSuccessfulSyncItems();

    _isSyncing = false;
    if (failCount == 0) {
      _syncStatusMessage = 'Sync complete ✓';
    } else {
      _syncStatusMessage = 'Sync done: $successCount ok, $failCount failed';
    }
    notifyListeners();

    // Clear message after 4 seconds
    Future.delayed(const Duration(seconds: 4), () {
      _syncStatusMessage = '';
      notifyListeners();
    });
  }

  /// Upload a single sync queue item to Supabase.
  Future<void> _uploadItem(SyncQueueItem item) async {
    final client = Supabase.instance.client;
    final tableName = _tableNameForModule(item.moduleName);

    switch (item.actionType) {
      case 'CREATE':
        await client.from(tableName).upsert(item.dataJson);
        break;
      case 'UPDATE':
        await client.from(tableName).upsert(item.dataJson);
        break;
      case 'DELETE':
        final id = item.dataJson['id'] ?? item.recordId;
        await client.from(tableName).delete().eq('id', id);
        break;
    }
  }

  String _tableNameForModule(String moduleName) {
    switch (moduleName) {
      case 'customers':
        return 'customers';
      case 'tasks':
        return 'tasks';
      case 'loans':
        return 'loans';
      case 'loan_tasks':
        return 'loan_tasks';
      case 'service_requests':
        return 'service_requests';
      case 'installation_photos':
        return 'installation_photos';
      case 'customer_labels':
        return 'customer_labels';
      case 'payments':
        return 'payments';
      case 'pending_approvals':
        return 'pending_approvals';
      default:
        return moduleName;
    }
  }
}
