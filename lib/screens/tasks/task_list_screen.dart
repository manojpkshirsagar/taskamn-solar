import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/task.dart';
import '../../models/customer.dart';
import 'task_form_screen.dart';
import 'task_detail_screen.dart';

class TaskListScreen extends StatefulWidget {
  final String? initialStatusFilter;

  const TaskListScreen({super.key, this.initialStatusFilter});

  @override
  State<TaskListScreen> createState() => _TaskListScreenState();
}

class _TaskListScreenState extends State<TaskListScreen> {
  List<Task> _tasks = [];
  List<Customer> _customers = [];
  bool _isLoading = true;
  String _selectedStatusFilter = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      _selectedStatusFilter = widget.initialStatusFilter!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      SupabaseService.instance.fetchTasks(),
      SupabaseService.instance.fetchCustomers(),
    ]);
    final tasks = results[0] as List<Task>;
    final customers = results[1] as List<Customer>;
    if (mounted) {
      setState(() {
        _tasks = tasks;
        _customers = customers;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final user = SupabaseService.instance.cachedUser;
    final isAdmin = user?.role == 'admin';

    // Filter tasks based on role and active selection
    var filtered = _tasks;
    if (!isAdmin && user != null) {
      filtered = filtered.where((t) => t.assignedEmployeeId == user.id).toList();
    }

    if (_selectedStatusFilter != 'All') {
      filtered = filtered.where((t) => t.status == _selectedStatusFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((t) {
        final customer = _customers.firstWhere(
          (c) => c.id == t.customerId,
          orElse: () => Customer(
            id: '', name: 'Unknown Customer', mobileNumber: '', emailAddress: '', address: '', solarCapacity: 0, stage: 'Lead', installationStage: 1,
          ),
        );
        final query = _searchQuery.toLowerCase();
        return customer.name.toLowerCase().contains(query) ||
               t.taskType.toLowerCase().contains(query) ||
               t.status.toLowerCase().contains(query);
      }).toList();
    }



    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('tab_tasks')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search Tasks...',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),

          // Stat Cards Horizontally Scrollable
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              children: [
                _buildStatCard(
                  title: 'Total',
                  value: _tasks.length.toString(),
                  icon: Icons.assignment,
                  color: AppColors.primarySolarOrange,
                  isSelected: _selectedStatusFilter == 'All',
                  onTap: () => setState(() {
                    _selectedStatusFilter = 'All';
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('status_pending'),
                  value: _tasks.where((t) => t.status == 'Pending').length.toString(),
                  icon: Icons.hourglass_empty,
                  color: AppColors.pendingColor,
                  isSelected: _selectedStatusFilter == 'Pending',
                  onTap: () => setState(() {
                    _selectedStatusFilter = 'Pending';
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('status_in_progress'),
                  value: _tasks.where((t) => t.status == 'In Progress').length.toString(),
                  icon: Icons.rotate_right,
                  color: AppColors.progressColor,
                  isSelected: _selectedStatusFilter == 'In Progress',
                  onTap: () => setState(() {
                    _selectedStatusFilter = 'In Progress';
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('status_completed'),
                  value: _tasks.where((t) => t.status == 'Completed').length.toString(),
                  icon: Icons.check_circle_outline,
                  color: AppColors.completedColor,
                  isSelected: _selectedStatusFilter == 'Completed',
                  onTap: () => setState(() {
                    _selectedStatusFilter = 'Completed';
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('status_hold'),
                  value: _tasks.where((t) => t.status == 'Hold').length.toString(),
                  icon: Icons.pause_circle_outline,
                  color: AppColors.holdColor,
                  isSelected: _selectedStatusFilter == 'Hold',
                  onTap: () => setState(() {
                    _selectedStatusFilter = 'Hold';
                  }),
                ),
              ].map((card) => Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: SizedBox(width: 110, child: card),
              )).toList(),
            ),
          ),
          const Divider(),

          // Tasks List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? const Center(child: Text('No tasks found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, idx) {
                          final task = filtered[idx];
                          final customer = _customers.firstWhere(
                            (c) => c.id == task.customerId,
                            orElse: () => Customer(
                              id: '', name: 'Unknown Customer', mobileNumber: '', emailAddress: '', address: '', solarCapacity: 0, stage: 'Lead', installationStage: 1,
                            ),
                          );

                          return Card(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => TaskDetailScreen(task: task, customer: customer),
                                  ),
                                ).then((_) => _loadData());
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          customer.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        _buildStatusBadge(translator, task.status),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, size: 14, color: AppColors.textLightGray),
                                        const SizedBox(width: 4),
                                        Text(customer.address.isEmpty ? 'N/A' : customer.address, style: const TextStyle(color: AppColors.textLightGray)),
                                        const Spacer(),
                                        const Icon(Icons.calendar_today, size: 14, color: AppColors.textLightGray),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${task.dueDate.day}/${task.dueDate.month}/${task.dueDate.year}',
                                          style: const TextStyle(color: AppColors.textLightGray, fontSize: 12),
                                        ),
                                      ],
                                    ),
                                    const Divider(height: 16),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            if (task.taskCode != null) ...[
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: Colors.blue.withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  task.taskCode!,
                                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                            ],
                                            Text(
                                              translator.translate('task_${task.taskType.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}'),
                                              style: const TextStyle(
                                                color: AppColors.primarySolarOrange,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                        _buildPriorityBadge(translator, task.priority),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              heroTag: 'task_list_fab',
              backgroundColor: AppColors.primarySolarOrange,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const TaskFormScreen()),
                ).then((_) => _loadData());
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildStatusBadge(TranslationProvider translator, String status) {
    Color color = AppColors.pendingColor;
    if (status == 'Completed') color = AppColors.completedColor;
    if (status == 'In Progress') color = AppColors.progressColor;
    if (status == 'Hold') color = AppColors.holdColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        translator.translate('status_${status.toLowerCase().replaceAll(' ', '_')}'),
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildPriorityBadge(TranslationProvider translator, String priority) {
    Color color = AppColors.priorityLow;
    if (priority == 'Medium') color = AppColors.priorityMedium;
    if (priority == 'High') color = AppColors.priorityHigh;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        translator.translate('priority_${priority.toLowerCase()}'),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: isSelected ? 3.0 : 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : AppColors.borderGray,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textLightGray),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
