import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/employee.dart';
import '../../models/task.dart';

class EmployeeManageScreen extends StatefulWidget {
  const EmployeeManageScreen({super.key});

  @override
  State<EmployeeManageScreen> createState() => _EmployeeManageScreenState();
}

class _EmployeeManageScreenState extends State<EmployeeManageScreen> {
  List<Employee> _employees = [];
  List<Task> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final employees = await SupabaseService.instance.fetchEmployees();
    final tasks = await SupabaseService.instance.fetchTasks();
    if (mounted) {
      setState(() {
        _employees = employees;
        _tasks = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _showAddEmployeeDialog() async {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final designationController = TextEditingController();
    String selectedRole = 'employee';

    final translator = Provider.of<TranslationProvider>(context, listen: false);

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(translator.translate('add_employee')),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter name' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter mobile number' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: designationController,
                  decoration: const InputDecoration(labelText: 'Designation'),
                  validator: (val) => val == null || val.trim().isEmpty ? 'Please enter designation' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'employee', child: Text('Employee')),
                    DropdownMenuItem(value: 'admin', child: Text('Admin')),
                  ],
                  onChanged: (val) {
                    if (val != null) selectedRole = val;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(translator.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              
              final newEmp = Employee(
                id: const Uuid().v4(),
                name: nameController.text.trim(),
                mobileNumber: mobileController.text.trim(),
                designation: designationController.text.trim(),
                role: selectedRole,
                createdAt: DateTime.now(),
              );
              
              await SupabaseService.instance.addEmployee(newEmp);
              Navigator.of(ctx).pop();
              _loadData();
            },
            child: Text(translator.translate('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('employees')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 80),
              itemCount: _employees.length,
              itemBuilder: (ctx, idx) {
                final emp = _employees[idx];
                
                // Calculate performance metrics
                final empTasks = _tasks.where((t) => t.assignedEmployeeId == emp.id);
                final totalCount = empTasks.length;
                final completedCount = empTasks.where((t) => t.status == 'Completed').length;
                final pendingCount = totalCount - completedCount;

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(emp.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: emp.role == 'admin' ? Colors.red.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                emp.role.toUpperCase(),
                                style: TextStyle(
                                  color: emp.role == 'admin' ? Colors.red : Colors.blue,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Text('${emp.designation} | Mobile: ${emp.mobileNumber}', style: const TextStyle(color: AppColors.textLightGray)),
                        const Divider(height: 20),
                        
                        // Performance Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildPerformanceColumn(translator.translate('total_tasks'), totalCount.toString(), Colors.blue),
                            _buildPerformanceColumn(translator.translate('completed_tasks'), completedCount.toString(), AppColors.completedColor),
                            _buildPerformanceColumn(translator.translate('pending_tasks'), pendingCount.toString(), AppColors.pendingColor),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'employee_manage_fab',
        backgroundColor: AppColors.primarySolarOrange,
        foregroundColor: Colors.white,
        onPressed: _showAddEmployeeDialog,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildPerformanceColumn(String label, String value, Color valueColor) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: valueColor),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textLightGray),
        ),
      ],
    );
  }
}
