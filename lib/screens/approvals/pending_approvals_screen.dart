import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/approval_service.dart';
import '../../services/supabase_service.dart';
import '../../models/pending_approval.dart';
import '../../constants/colors.dart';
import 'approval_detail_screen.dart';

/// Admin view: lists all pending approval requests awaiting action.
class PendingApprovalsScreen extends StatefulWidget {
  const PendingApprovalsScreen({super.key});

  @override
  State<PendingApprovalsScreen> createState() => _PendingApprovalsScreenState();
}

class _PendingApprovalsScreenState extends State<PendingApprovalsScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<ApprovalService>(
      builder: (context, svc, _) {
        final approvals = svc.getAdminPendingApprovals();
        return Scaffold(
          appBar: AppBar(
            title: Text('Pending Approvals (${approvals.length})'),
            backgroundColor: AppColors.primarySolarOrange,
            foregroundColor: Colors.white,
          ),
          body: approvals.isEmpty
              ? _buildEmpty()
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: approvals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ApprovalCard(
                    approval: approvals[i],
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ApprovalDetailScreen(
                              approval: approvals[i]),
                        ),
                      );
                      setState(() {});
                    },
                  ),
                ),
        );
      },
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.thumb_up_outlined, size: 72, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text('No Pending Approvals',
              style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Text('All changes are up to date.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade400)),
        ],
      ),
    );
  }
}

class _ApprovalCard extends StatelessWidget {
  final PendingApproval approval;
  final VoidCallback onTap;
  const _ApprovalCard({required this.approval, required this.onTap});

  String _moduleLabel(String m) {
    return m.replaceAll('_', ' ').split(' ').map((w) =>
        w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '').join(' ');
  }

  Color _actionColor(String action) {
    switch (action) {
      case 'CREATE': return Colors.green;
      case 'UPDATE': return Colors.blue;
      case 'DELETE': return Colors.red;
      default:       return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionColor = _actionColor(approval.actionType);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: actionColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  approval.actionType == 'CREATE'
                      ? Icons.add
                      : approval.actionType == 'DELETE'
                          ? Icons.delete_outline
                          : Icons.edit_outlined,
                  color: actionColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _moduleLabel(approval.moduleName),
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: actionColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            approval.actionType,
                            style: TextStyle(
                                color: actionColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'By: ${approval.employeeName ?? approval.employeeId}',
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12),
                    ),
                    if (approval.customerName != null)
                      Text(
                        'Customer: ${approval.customerName}',
                        style: TextStyle(
                            color: Colors.grey.shade600, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Icon(Icons.chevron_right,
                      color: Colors.grey, size: 20),
                  const SizedBox(height: 4),
                  Text(
                    _formatTime(approval.createdAt),
                    style: TextStyle(
                        color: Colors.grey.shade400, fontSize: 10),
                  ),
                ],
              ),
            ],
          ),
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
