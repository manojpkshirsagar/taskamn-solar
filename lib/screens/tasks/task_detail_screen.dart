import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/task.dart';
import '../../models/customer.dart';
import '../customers/customer_detail_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  final Customer customer;

  const TaskDetailScreen({super.key, required this.task, required this.customer});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late String _selectedStatus;
  final _remarksController = TextEditingController();
  bool _isSaving = false;

  final List<String> _statuses = ['Pending', 'In Progress', 'Completed', 'Hold'];

  @override
  void initState() {
    super.initState();
    _selectedStatus = widget.task.status;
    _remarksController.text = widget.task.remarks ?? '';
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _updateTask() async {
    setState(() => _isSaving = true);

    final updated = Task(
      id: widget.task.id,
      customerId: widget.task.customerId,
      taskType: widget.task.taskType,
      assignedEmployeeId: widget.task.assignedEmployeeId,
      dueDate: widget.task.dueDate,
      priority: widget.task.priority,
      remarks: _remarksController.text.trim(),
      status: _selectedStatus,
      createdAt: widget.task.createdAt,
      taskCode: widget.task.taskCode,
    );

    await SupabaseService.instance.upsertTask(updated);
    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Task updated successfully!'), backgroundColor: AppColors.completedColor),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('task_details')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Customer Context Card
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            widget.customer.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (widget.task.taskCode != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              widget.task.taskCode!,
                              style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.customer.address.isEmpty ? 'No Address' : widget.customer.address,
                      style: const TextStyle(color: AppColors.textLightGray),
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          translator.translate('task_${widget.task.taskType.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}'),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarySolarOrange,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Priority: ${translator.translate('priority_${widget.task.priority.toLowerCase()}')}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Due Date: ${widget.task.dueDate.day}/${widget.task.dueDate.month}/${widget.task.dueDate.year}',
                      style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textLightGray),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Edit Section Card
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: InputDecoration(labelText: translator.translate('update_status')),
                      items: _statuses.map((status) {
                        return DropdownMenuItem(
                          value: status,
                          child: Text(translator.translate('status_${status.toLowerCase().replaceAll(' ', '_')}')),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedStatus = val;
                          });
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 4,
                      decoration: InputDecoration(
                        labelText: translator.translate('remarks'),
                        hintText: translator.translate('add_remarks'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: _isSaving ? null : _updateTask,
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : Text(translator.translate('save')),
            ),
            const SizedBox(height: 16),

            // Link to customer details
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => CustomerDetailScreen(customer: widget.customer),
                  ),
                );
              },
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Go to Customer Details / Track Installation'),
            ),
          ],
        ),
      ),
    );
  }
}
