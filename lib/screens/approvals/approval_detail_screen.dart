import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/approval_service.dart';
import '../../services/supabase_service.dart';
import '../../models/pending_approval.dart';
import '../../constants/colors.dart';

/// Admin detail view: shows old vs new data diff and approve/reject buttons.
class ApprovalDetailScreen extends StatelessWidget {
  final PendingApproval approval;
  const ApprovalDetailScreen({super.key, required this.approval});

  @override
  Widget build(BuildContext context) {
    final admin = SupabaseService.instance.cachedUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Change Request'),
        backgroundColor: AppColors.primarySolarOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header info
            _InfoCard(approval: approval),
            const SizedBox(height: 16),

            // Old vs New data
            if (approval.oldData != null) ...[
              _SectionHeader('Old Data', Colors.red.shade700),
              const SizedBox(height: 8),
              _DataTable(data: approval.oldData!, highlight: false),
              const SizedBox(height: 16),
            ],
            _SectionHeader('New Data (Requested Change)', Colors.green.shade700),
            const SizedBox(height: 8),
            _DataTable(
              data: approval.newData,
              oldData: approval.oldData,
              highlight: true,
            ),
            const SizedBox(height: 24),

            // Action buttons
            if (approval.status == 'Pending' && admin != null) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showRejectDialog(context, admin),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text('Reject',
                          style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.red),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveRequest(context, admin),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text('Approve',
                          style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else ...[
              // Already processed
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: approval.status == 'Approved'
                      ? Colors.green.shade50
                      : Colors.red.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: approval.status == 'Approved'
                        ? Colors.green.shade200
                        : Colors.red.shade200,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      approval.status == 'Approved'
                          ? Icons.check_circle
                          : Icons.cancel,
                      color: approval.status == 'Approved'
                          ? Colors.green
                          : Colors.red,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            approval.status == 'Approved'
                                ? 'Approved'
                                : 'Rejected',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: approval.status == 'Approved'
                                  ? Colors.green
                                  : Colors.red,
                            ),
                          ),
                          if (approval.rejectionReason != null)
                            Text(
                              'Reason: ${approval.rejectionReason}',
                              style: const TextStyle(fontSize: 13),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _approveRequest(BuildContext context, dynamic admin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Approve Change?'),
        content: const Text(
            'This will apply the employee\'s changes to the live data.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Approve', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!context.mounted) return;

    final success = await context
        .read<ApprovalService>()
        .approveRequest(approval.id, admin);

    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(success ? '✓ Change approved and applied' : 'Failed to approve'),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
    if (success) Navigator.of(context).pop();
  }

  void _showRejectDialog(BuildContext context, dynamic admin) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject Change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              decoration: const InputDecoration(
                hintText: 'e.g. Incorrect data, needs review...',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              final reason = ctrl.text.trim();
              if (reason.isEmpty) return;
              Navigator.pop(ctx);
              final success = await context
                  .read<ApprovalService>()
                  .rejectRequest(approval.id, admin, reason);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success ? '✗ Change rejected' : 'Failed to reject'),
                  backgroundColor: success ? Colors.orange : Colors.red,
                ),
              );
              if (success) Navigator.of(context).pop();
            },
            child: const Text('Reject', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final PendingApproval approval;
  const _InfoCard({required this.approval});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Column(
        children: [
          _row('Approval ID', approval.id.substring(0, 8).toUpperCase()),
          _row('Module', approval.moduleName.replaceAll('_', ' ')),
          _row('Action', approval.actionType),
          _row('Employee', approval.employeeName ?? approval.employeeId),
          if (approval.customerName != null)
            _row('Customer', approval.customerName!),
          _row('Status', approval.status),
          _row('Requested', _fmt(approval.createdAt)),
        ],
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(label,
                style: const TextStyle(
                    color: AppColors.textLightGray,
                    fontSize: 12,
                    fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final Color color;
  const _SectionHeader(this.title, this.color);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 4, height: 18, color: color,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: color)),
      ],
    );
  }
}

class _DataTable extends StatelessWidget {
  final Map<String, dynamic> data;
  final Map<String, dynamic>? oldData;
  final bool highlight;

  const _DataTable({
    required this.data,
    this.oldData,
    required this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    final ignoredKeys = {'id', 'created_at', 'updated_at'};
    final entries = data.entries
        .where((e) => !ignoredKeys.contains(e.key))
        .toList();

    if (entries.isEmpty) {
      return const Text('No data', style: TextStyle(color: Colors.grey));
    }

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: entries.asMap().entries.map((me) {
          final e = me.value;
          final idx = me.key;
          final isLast = idx == entries.length - 1;
          final changed = highlight &&
              oldData != null &&
              oldData!.containsKey(e.key) &&
              oldData![e.key].toString() != e.value.toString();

          return Container(
            decoration: BoxDecoration(
              color: changed ? Colors.green.shade50 : Colors.white,
              borderRadius: BorderRadius.vertical(
                top: idx == 0 ? const Radius.circular(10) : Radius.zero,
                bottom: isLast ? const Radius.circular(10) : Radius.zero,
              ),
              border: isLast
                  ? null
                  : Border(
                      bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 110,
                  child: Text(
                    e.key.replaceAll('_', ' '),
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Expanded(
                  child: Row(
                    children: [
                      Flexible(
                        child: Text(
                          e.value?.toString() ?? '—',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: changed
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: changed
                                ? Colors.green.shade700
                                : Colors.black87,
                          ),
                        ),
                      ),
                      if (changed)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(Icons.arrow_forward,
                              size: 12, color: Colors.green),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
