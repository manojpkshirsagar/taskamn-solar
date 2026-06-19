import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/approval_service.dart';
import '../../services/supabase_service.dart';
import '../../models/pending_approval.dart';
import '../../constants/colors.dart';
import 'approval_detail_screen.dart';

/// Employee view: shows their own submission history across 3 tabs.
class MyApprovalsScreen extends StatefulWidget {
  const MyApprovalsScreen({super.key});

  @override
  State<MyApprovalsScreen> createState() => _MyApprovalsScreenState();
}

class _MyApprovalsScreenState extends State<MyApprovalsScreen>
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

  @override
  Widget build(BuildContext context) {
    final user = SupabaseService.instance.cachedUser;
    if (user == null) {
      return const Scaffold(
          body: Center(child: Text('Not logged in')));
    }

    return Consumer<ApprovalService>(
      builder: (context, svc, _) {
        final all = svc.getMyApprovals(user.id);
        final pending = all.where((a) => a.status == 'Pending').toList();
        final approved = all.where((a) => a.status == 'Approved').toList();
        final rejected = all.where((a) => a.status == 'Rejected').toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Submissions'),
            backgroundColor: AppColors.primarySolarOrange,
            foregroundColor: Colors.white,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              tabs: [
                Tab(text: 'Pending (${pending.length})'),
                Tab(text: 'Approved (${approved.length})'),
                Tab(text: 'Rejected (${rejected.length})'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _ApprovalList(
                  items: pending,
                  emptyLabel: 'No pending submissions',
                  emptyIcon: Icons.hourglass_empty),
              _ApprovalList(
                  items: approved,
                  emptyLabel: 'No approved changes yet',
                  emptyIcon: Icons.check_circle_outline),
              _ApprovalList(
                  items: rejected,
                  emptyLabel: 'No rejected changes',
                  emptyIcon: Icons.cancel_outlined,
                  showReason: true),
            ],
          ),
        );
      },
    );
  }
}

class _ApprovalList extends StatelessWidget {
  final List<PendingApproval> items;
  final String emptyLabel;
  final IconData emptyIcon;
  final bool showReason;

  const _ApprovalList({
    required this.items,
    required this.emptyLabel,
    required this.emptyIcon,
    this.showReason = false,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(emptyIcon, size: 64, color: Colors.grey.shade300),
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
      itemBuilder: (_, i) => _MyApprovalCard(
        approval: items[i],
        showReason: showReason,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ApprovalDetailScreen(approval: items[i]),
            ),
          );
        },
      ),
    );
  }
}

class _MyApprovalCard extends StatelessWidget {
  final PendingApproval approval;
  final bool showReason;
  final VoidCallback onTap;

  const _MyApprovalCard({
    required this.approval,
    required this.showReason,
    required this.onTap,
  });

  Color _statusColor(String s) {
    switch (s) {
      case 'Pending':  return Colors.orange;
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      default:         return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(approval.status);
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      approval.moduleName.replaceAll('_', ' ').toUpperCase(),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      approval.status,
                      style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${approval.actionType}  ·  ${_fmt(approval.createdAt)}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              if (approval.customerName != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Customer: ${approval.customerName}',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ],
              if (showReason && approval.rejectionReason != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    '❌ Rejected: ${approval.rejectionReason}',
                    style: TextStyle(
                        color: Colors.red.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _fmt(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
