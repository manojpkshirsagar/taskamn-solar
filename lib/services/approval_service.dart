import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'storage_service.dart';
import 'sync_service.dart';
import 'connectivity_service.dart';
import 'supabase_service.dart';
import 'logger_service.dart';
import '../models/pending_approval.dart';
import '../models/employee.dart';
import '../models/customer.dart';
import '../models/task.dart';
import '../models/payment.dart';

/// ApprovalService handles the full employee-change → admin-approval workflow.
///
/// Flow:
///   Employee saves → submitForApproval() → PendingApproval stored locally + queued for sync
///   Admin reviews → approveRequest() / rejectRequest() → real Supabase tables updated
class ApprovalService extends ChangeNotifier {
  static final ApprovalService instance = ApprovalService._internal();
  ApprovalService._internal();

  int get pendingApprovalCount => StorageService.getPendingApprovalCount();

  // -------------------------------------------------------------------------
  // Employee: Submit a change for approval
  // -------------------------------------------------------------------------

  /// Saves a change to the pending_approvals queue (locally + synced to cloud).
  /// Returns the created [PendingApproval] item.
  Future<PendingApproval> submitForApproval({
    required String moduleName,
    required String recordId,
    required String employeeId,
    String? customerId,
    required String actionType,
    Map<String, dynamic>? oldData,
    required Map<String, dynamic> newData,
  }) async {
    const uuid = Uuid();
    final approval = PendingApproval(
      id: uuid.v4(),
      moduleName: moduleName,
      recordId: recordId,
      employeeId: employeeId,
      customerId: customerId,
      actionType: actionType,
      oldData: oldData,
      newData: newData,
      status: 'Pending',
      createdAt: DateTime.now(),
    );

    // 1. Save locally
    await StorageService.savePendingApproval(approval);

    // 2. Enqueue for cloud sync (approval record itself)
    await SyncService.instance.enqueue(
      moduleName: 'pending_approvals',
      recordId: approval.id,
      actionType: 'CREATE',
      dataJson: approval.toJson(),
      employeeId: employeeId,
    );

    // 3. If online, sync immediately
    if (ConnectivityService.instance.isOnline && !SupabaseService.instance.isMockMode) {
      SyncService.instance.syncAll();
    }

    notifyListeners();
    return approval;
  }

  // -------------------------------------------------------------------------
  // Admin: Approve a request
  // -------------------------------------------------------------------------

  Future<bool> approveRequest(String approvalId, Employee admin) async {
    final approvals = StorageService.getPendingApprovals();
    final idx = approvals.indexWhere((a) => a.id == approvalId);
    if (idx < 0) return false;

    final approval = approvals[idx];

    try {
      // 1. Apply the change to the real Supabase table
      if (!SupabaseService.instance.isMockMode) {
        final tableName = _tableNameForModule(approval.moduleName);
        final client = Supabase.instance.client;

        switch (approval.actionType) {
          case 'CREATE':
          case 'UPDATE':
            await client.from(tableName).upsert(approval.newData);
            break;
          case 'DELETE':
            final id = approval.newData['id'] ?? approval.recordId;
            await client.from(tableName).delete().eq('id', id);
            break;
        }

        // 2. Update the approval record in Supabase
        await client.from('pending_approvals').update({
          'status': 'Approved',
          'approved_by': admin.id,
          'approved_at': DateTime.now().toIso8601String(),
        }).eq('id', approvalId);
      }

      // 3. Apply change locally too (so employee sees approved state)
      await _applyChangeLocally(approval);

      // 4. Update local approval status
      await StorageService.updateApprovalStatus(
        approvalId,
        'Approved',
        approvedBy: admin.id,
        approvedAt: DateTime.now(),
      );

      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('[ApprovalService] approveRequest error: $e');
      LoggerService.logError('ApprovalService', 'approveRequest', e, stack);
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Admin: Reject a request
  // -------------------------------------------------------------------------

  Future<bool> rejectRequest(
    String approvalId,
    Employee admin,
    String reason,
  ) async {
    try {
      // 1. Update locally
      await StorageService.updateApprovalStatus(
        approvalId,
        'Rejected',
        rejectionReason: reason,
        approvedBy: admin.id,
        approvedAt: DateTime.now(),
      );

      // 2. Update Supabase if online
      if (!SupabaseService.instance.isMockMode) {
        await Supabase.instance.client.from('pending_approvals').update({
          'status': 'Rejected',
          'rejection_reason': reason,
          'approved_by': admin.id,
          'approved_at': DateTime.now().toIso8601String(),
        }).eq('id', approvalId);
      }

      notifyListeners();
      return true;
    } catch (e, stack) {
      debugPrint('[ApprovalService] rejectRequest error: $e');
      LoggerService.logError('ApprovalService', 'rejectRequest', e, stack);
      return false;
    }
  }

  // -------------------------------------------------------------------------
  // Helpers
  // -------------------------------------------------------------------------

  List<PendingApproval> getAdminPendingApprovals() {
    final approvals = StorageService.getPendingApprovalsByStatus('Pending');
    _enrichWithNames(approvals);
    return approvals;
  }

  List<PendingApproval> getMyApprovals(String employeeId) {
    final approvals = StorageService.getApprovalsByEmployee(employeeId);
    _enrichWithNames(approvals);
    return approvals;
  }

  void _enrichWithNames(List<PendingApproval> approvals) {
    final employees = StorageService.getEmployees();
    final customers = StorageService.getCustomers();
    for (final a in approvals) {
      try {
        a.employeeName = employees
            .firstWhere((e) => e.id == a.employeeId,
                orElse: () => Employee(
                    id: '', name: 'Unknown', mobileNumber: '', designation: '', role: ''))
            .name;
        if (a.customerId != null) {
          final matchedCustomers = customers.where((c) => c.id == a.customerId).toList();
          a.customerName = matchedCustomers.isNotEmpty ? matchedCustomers.first.name : 'Unknown';
        }
      } catch (_) {
        // Silently skip enrichment failures
      }
    }
  }

  /// Apply the approved change to the local cache so employees see it immediately.
  Future<void> _applyChangeLocally(PendingApproval approval) async {
    try {
      switch (approval.moduleName) {
        case 'customers':
          if (approval.actionType == 'DELETE') {
            await StorageService.deleteCustomer(approval.recordId);
          } else {
            final customer = Customer.fromJson(approval.newData);
            await StorageService.saveCustomer(customer);
          }
          break;
        case 'tasks':
          if (approval.actionType == 'DELETE') {
            // No delete method for tasks in StorageService currently — skip
          } else {
            final task = Task.fromJson(approval.newData);
            await StorageService.saveTask(task);
          }
          break;
        case 'payments':
          if (approval.actionType == 'DELETE') {
            await StorageService.deletePayment(approval.recordId);
          } else {
            final payment = Payment.fromJson(approval.newData);
            await StorageService.savePayment(payment);
          }
          break;
        default:
          // For other modules, the data is applied via Supabase fetch on next refresh
          break;
      }
    } catch (e) {
      debugPrint('[ApprovalService] _applyChangeLocally error: $e');
    }
  }

  String _tableNameForModule(String moduleName) {
    switch (moduleName) {
      case 'customers':        return 'customers';
      case 'tasks':            return 'tasks';
      case 'loans':            return 'loans';
      case 'service_requests': return 'service_requests';
      case 'installation_photos': return 'installation_photos';
      case 'customer_labels':  return 'customer_labels';
      case 'payments':         return 'payments';
      default:                 return moduleName;
    }
  }
}
