import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/translation_provider.dart';
import '../services/supabase_service.dart';
import '../services/approval_service.dart';
import '../services/sync_service.dart';
import '../constants/colors.dart';
import '../models/customer.dart';
import '../models/label.dart';
import '../models/customer_label.dart';
import '../models/task.dart';
import '../models/loan.dart';
import 'customers/customer_list_screen.dart';
import 'tasks/task_list_screen.dart';
import 'loans/loan_dashboard_screen.dart';
import 'approvals/pending_approvals_screen.dart';
import 'approvals/my_approvals_screen.dart';
import 'sync/sync_queue_screen.dart';
import '../widgets/connectivity_banner.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _isLoading = true;
  List<Customer> _customers = [];
  List<Label> _labels = [];
  List<CustomerLabel> _customerLabels = [];
  List<Task> _tasks = [];
  List<Loan> _loans = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        SupabaseService.instance.fetchCustomers(),
        SupabaseService.instance.fetchLabels(),
        SupabaseService.instance.fetchAllCustomerLabels(),
        SupabaseService.instance.fetchTasks(),
        SupabaseService.instance.fetchLoans(),
      ]);

      final customers = results[0] as List<Customer>;
      final lbs = results[1] as List<Label>;
      final clbs = results[2] as List<CustomerLabel>;
      final tasksData = results[3] as List<Task>;
      final loansData = results[4] as List<Loan>;

      if (mounted) {
        setState(() {
          _customers = customers;
          _labels = lbs;
          _customerLabels = clbs;
          _tasks = tasksData;
          _loans = loansData;
          _isLoading = false;
        });
      }
    } catch (e, stack) {
      debugPrint("Dashboard load data error: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final currentUser = SupabaseService.instance.cachedUser;
    final isAdmin = currentUser?.role == 'admin';

    // Calculations
    final int totalCustomersCount = _customers.length;
    final int totalLeadsCount = _customers.where((c) => c.stage == 'Lead').length;
    final int pendingTasksCount = _tasks.where((t) => t.status == 'Pending').length;
    final int installationPendingCount = _customers.where((c) => c.stage == 'Installation').length;

    // Use Label for Net Meter Pending and Subsidy Pending as per prompt
    final netMeterPendingLabel = _labels.firstWhere(
      (l) => l.labelName == 'Net Meter Pending',
      orElse: () => Label(id: '', categoryId: '', labelName: ''),
    );
    final int netMeterPendingCount = _customerLabels.where((cl) => cl.labelId == netMeterPendingLabel.id).length;

    final subsidyPendingLabel = _labels.firstWhere(
      (l) => l.labelName == 'Subsidy Pending',
      orElse: () => Label(id: '', categoryId: '', labelName: ''),
    );
    final int subsidyPendingCount = _customerLabels.where((cl) => cl.labelId == subsidyPendingLabel.id).length;

    // Use actual Loan data for Loan Pending (status != Approved implies Pending)
    final int loanPendingCount = _loans.where((l) => l.status != 'Approved').length;

    // Payment Pending Labels
    final paymentPendingCount = _customerLabels.where((cl) {
      final lbl = _labels.firstWhere(
        (l) => l.id == cl.labelId,
        orElse: () => Label(id: '', categoryId: '', labelName: ''),
      );
      return lbl.labelName == 'Advance Pending' ||
          lbl.labelName == 'Material Payment Pending' ||
          lbl.labelName == 'Final Payment Pending';
    }).length;

    final int completedProjectsCount = _customers.where((c) => c.stage == 'Completed').length;

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('tab_dashboard')),
        actions: [
          const ConnectivityBanner(),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.maxWidth;
                  // Calculate columns based on width
                  final int crossAxisCount = width > 900 ? 4 : (width > 600 ? 3 : 2);
                  // Adjust card aspect ratio to ensure cards aren't overly tall or short
                  final double childAspectRatio = width > 900 ? 1.7 : (width > 600 ? 1.5 : 1.35);

                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const SizedBox(height: 8),
                            _buildUserHeader(translator),
                            const SizedBox(height: 24),
                            
                            // Main Grid
                            GridView.count(
                              crossAxisCount: crossAxisCount,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: childAspectRatio,
                              children: [
                                _buildStatCard(
                                  title: 'Total Customers',
                                  value: totalCustomersCount.toString(),
                                  icon: Icons.people,
                                  color: AppColors.primarySolarOrange,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const CustomerListScreen(initialStageFilter: 'All')
                                    ));
                                  },
                                ),
                                _buildStatCard(
                                  title: 'Total Leads',
                                  value: totalLeadsCount.toString(),
                                  icon: Icons.contact_page,
                                  color: Colors.blueGrey,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const CustomerListScreen(initialStageFilter: 'Lead')
                                    ));
                                  },
                                ),
                                _buildStatCard(
                                  title: 'Pending Tasks',
                                  value: pendingTasksCount.toString(),
                                  icon: Icons.assignment,
                                  color: AppColors.pendingColor,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const TaskListScreen(initialStatusFilter: 'Pending')
                                    ));
                                  },
                                ),
                                _buildStatCard(
                                  title: 'Installation Pending',
                                  value: installationPendingCount.toString(),
                                  icon: Icons.build,
                                  color: AppColors.progressColor,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const CustomerListScreen(initialStageFilter: 'Installation')
                                    ));
                                  },
                                ),
                                _buildStatCard(
                                  title: 'Net Meter Pending',
                                  value: netMeterPendingCount.toString(),
                                  icon: Icons.electric_meter,
                                  color: Colors.purple,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const CustomerListScreen(initialLabelFilter: 'Net Meter Pending')
                                    ));
                                  },
                                ),
                                _buildStatCard(
                                  title: 'Subsidy Pending',
                                  value: subsidyPendingCount.toString(),
                                  icon: Icons.currency_rupee,
                                  color: Colors.teal,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const CustomerListScreen(initialLabelFilter: 'Subsidy Pending')
                                    ));
                                  },
                                ),
                                _buildStatCard(
                                  title: 'Loan Pending',
                                  value: loanPendingCount.toString(),
                                  icon: Icons.account_balance,
                                  color: Colors.indigo,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const LoanDashboardScreen(initialStatusFilter: 'Pending')
                                    ));
                                  },
                                ),
                                _buildStatCard(
                                  title: 'Payment Pending',
                                  value: paymentPendingCount.toString(),
                                  icon: Icons.payment,
                                  color: Colors.red,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const CustomerListScreen(initialPaymentPending: true)
                                    ));
                                  },
                                ),
                                _buildStatCard(
                                  title: 'Completed Projects',
                                  value: completedProjectsCount.toString(),
                                  icon: Icons.check_circle,
                                  color: AppColors.completedColor,
                                  onTap: () {
                                    Navigator.push(context, MaterialPageRoute(
                                      builder: (_) => const CustomerListScreen(initialStageFilter: 'Completed')
                                    ));
                                  },
                                ),

                                // --- Role-Aware: Approval & Sync Cards ---
                                if (isAdmin) ..._buildAdminApprovalCards(context)
                                else ..._buildEmployeeApprovalCards(context),
                              ],
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildUserHeader(TranslationProvider translator) {
    final user = SupabaseService.instance.cachedUser;
    final name = user?.name ?? 'Solar User';
    final role = user?.role == 'admin' ? translator.translate('role_admin') : translator.translate('role_employee');
    final designation = user?.designation ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderGray),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.primarySolarOrange.withOpacity(0.1),
            radius: 28,
            child: const Icon(Icons.person, color: AppColors.primarySolarOrange, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Namaskar, $name!',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDarkGray),
                ),
                Text(
                  '$role | $designation',
                  style: const TextStyle(color: AppColors.textLightGray, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 1.5,
      shadowColor: Colors.black.withOpacity(0.1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.borderGray, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textDarkGray,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textLightGray,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Role-aware Approval & Sync stat cards
  // -------------------------------------------------------------------------

  List<Widget> _buildAdminApprovalCards(BuildContext context) {
    final pendingApprovals = ApprovalService.instance.pendingApprovalCount;
    final pendingSync = SyncService.instance.pendingSyncCount;
    return [
      _buildStatCard(
        title: 'Pending Approvals',
        value: pendingApprovals.toString(),
        icon: Icons.pending_actions,
        color: Colors.deepOrange,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => const PendingApprovalsScreen()));
        },
      ),
      _buildStatCard(
        title: 'Pending Sync',
        value: pendingSync.toString(),
        icon: Icons.cloud_sync,
        color: Colors.blueGrey,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SyncQueueScreen()));
        },
      ),
    ];
  }

  List<Widget> _buildEmployeeApprovalCards(BuildContext context) {
    final currentUser = SupabaseService.instance.cachedUser;
    final myApprovals = currentUser != null
        ? ApprovalService.instance.getMyApprovals(currentUser.id)
        : <dynamic>[];
    final myPending = myApprovals.where((a) => a.status == 'Pending').length;
    final myApproved = myApprovals.where((a) => a.status == 'Approved').length;
    final myRejected = myApprovals.where((a) => a.status == 'Rejected').length;
    final pendingSync = SyncService.instance.pendingSyncCount;
    return [
      _buildStatCard(
        title: 'My Pending Approvals',
        value: myPending.toString(),
        icon: Icons.hourglass_empty,
        color: Colors.orange,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => const MyApprovalsScreen()));
        },
      ),
      _buildStatCard(
        title: 'My Approved',
        value: myApproved.toString(),
        icon: Icons.check_circle_outline,
        color: Colors.green,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => const MyApprovalsScreen()));
        },
      ),
      _buildStatCard(
        title: 'My Rejected',
        value: myRejected.toString(),
        icon: Icons.cancel_outlined,
        color: Colors.red,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => const MyApprovalsScreen()));
        },
      ),
      _buildStatCard(
        title: 'Pending Sync',
        value: pendingSync.toString(),
        icon: Icons.cloud_sync,
        color: Colors.blueGrey,
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
              builder: (_) => const SyncQueueScreen()));
        },
      ),
    ];
  }
}
