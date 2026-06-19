import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/task.dart';
import '../../models/customer.dart';
import '../../models/employee.dart';

class TaskFormScreen extends StatefulWidget {
  final Customer? preselectedCustomer;

  const TaskFormScreen({super.key, this.preselectedCustomer});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  String _selectedTaskType = 'Site Survey';
  String? _selectedEmployeeId;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 1));
  String _selectedPriority = 'Medium';
  final _remarksController = TextEditingController();

  List<Customer> _customers = [];
  List<Employee> _employees = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _taskTypes = [
    'Site Survey', 'Quotation Follow-up', 'Installation', 
    'Net Meter Application', 'Inspection', 'Subsidy Documents', 
    'Payment Collection', 'Service Visit'
  ];

  final List<String> _priorities = ['Low', 'Medium', 'High'];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedCustomer != null) {
      _selectedCustomerId = widget.preselectedCustomer!.id;
    }
    _loadRelations();
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadRelations() async {
    final customers = await SupabaseService.instance.fetchCustomers();
    final employees = await SupabaseService.instance.fetchEmployees();
    if (mounted) {
      setState(() {
        _customers = customers;
        _employees = employees.where((e) => e.role == 'employee').toList();
        if (_selectedCustomerId == null && _customers.isNotEmpty) {
          _selectedCustomerId = _customers.first.id;
        }
        if (_employees.isNotEmpty) {
          _selectedEmployeeId = _employees.first.id;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) return;

    setState(() => _isSaving = true);

    final task = Task(
      id: const Uuid().v4(),
      customerId: _selectedCustomerId!,
      taskType: _selectedTaskType,
      assignedEmployeeId: _selectedEmployeeId,
      dueDate: _dueDate,
      priority: _selectedPriority,
      remarks: _remarksController.text.trim(),
      status: 'Pending',
      createdAt: DateTime.now(),
    );

    await SupabaseService.instance.upsertTask(task);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task created successfully!'), backgroundColor: AppColors.completedColor),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('create_task')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Customer Dropdown
                    if (widget.preselectedCustomer != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: InputDecorator(
                          decoration: InputDecoration(labelText: translator.translate('customer_name')),
                          child: Text(widget.preselectedCustomer!.name, style: const TextStyle(fontSize: 16)),
                        ),
                      )
                    else
                      DropdownButtonFormField<String>(
                        value: _selectedCustomerId,
                        decoration: InputDecoration(labelText: translator.translate('customer_name')),
                        items: _customers.map((c) {
                          return DropdownMenuItem(value: c.id, child: Text(c.name));
                        }).toList(),
                        onChanged: (val) => setState(() => _selectedCustomerId = val),
                        validator: (val) => val == null ? 'Please select a customer' : null,
                      ),
                    const SizedBox(height: 16),

                    // Task Type Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedTaskType,
                      decoration: InputDecoration(labelText: translator.translate('task_type')),
                      items: _taskTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(translator.translate('task_${type.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}')),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedTaskType = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Assignee Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedEmployeeId,
                      decoration: InputDecoration(labelText: translator.translate('assigned_employee')),
                      items: _employees.map((emp) {
                        return DropdownMenuItem(value: emp.id, child: Text(emp.name));
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedEmployeeId = val),
                    ),
                    const SizedBox(height: 16),

                    // Due Date Picker
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: InputDecoration(labelText: translator.translate('due_date')),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('${_dueDate.day}/${_dueDate.month}/${_dueDate.year}', style: const TextStyle(fontSize: 16)),
                            const Icon(Icons.calendar_today, color: AppColors.primarySolarOrange),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Priority Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedPriority,
                      decoration: InputDecoration(labelText: translator.translate('priority')),
                      items: _priorities.map((prio) {
                        return DropdownMenuItem(
                          value: prio,
                          child: Text(translator.translate('priority_${prio.toLowerCase()}')),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedPriority = val);
                      },
                    ),
                    const SizedBox(height: 16),

                    // Remarks TextField
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: translator.translate('remarks')),
                    ),
                    const SizedBox(height: 32),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveTask,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(translator.translate('create_task')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
