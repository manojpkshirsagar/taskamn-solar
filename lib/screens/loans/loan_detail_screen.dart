import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/loan.dart';
import '../../models/loan_task.dart';
import '../../models/customer.dart';
import 'loan_form_screen.dart';

class LoanDetailScreen extends StatefulWidget {
  final Loan loan;
  final Customer customer;

  const LoanDetailScreen({super.key, required this.loan, required this.customer});

  @override
  State<LoanDetailScreen> createState() => _LoanDetailScreenState();
}

class _LoanDetailScreenState extends State<LoanDetailScreen> {
  late Loan _loan;
  List<LoanTask> _loanTasks = [];
  bool _isLoading = true;
  bool _isSaving = false;

  final List<String> _loanStatuses = [
    'Loan Application',
    'File Print',
    'File at Office',
    'File at Bank',
    'Bank Issue',
    'Bank Visit At Home',
    'Approved',
  ];

  @override
  void initState() {
    super.initState();
    _loan = widget.loan;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    final updatedLoan = await SupabaseService.instance.fetchLoanById(_loan.id);
    final tasks = await SupabaseService.instance.fetchLoanTasks(_loan.id);
    if (mounted) {
      setState(() {
        if (updatedLoan != null) {
          _loan = updatedLoan;
        }
        _loanTasks = tasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTask(LoanTask task) async {
    final updated = task.copyWith(
      isCompleted: !task.isCompleted,
      completedAt: !task.isCompleted ? DateTime.now() : null,
    );
    await SupabaseService.instance.upsertLoanTask(updated);
    _loadDetails();
  }

  Future<void> _updateLoanStatus(String newStatus) async {
    if (newStatus == 'Bank Issue') {
      await _handleBankIssuePrompt(newStatus);
      return;
    }
    await _saveLoanStatus(newStatus, _loan.remarks);
  }

  Future<void> _saveLoanStatus(String newStatus, String? newRemarks) async {
    setState(() => _isSaving = true);
    final updated = Loan(
      id: _loan.id,
      customerId: _loan.customerId,
      loanAmount: _loan.loanAmount,
      bankName: _loan.bankName,
      branch: _loan.branch,
      status: newStatus,
      assignedEmployeeId: _loan.assignedEmployeeId,
      remarks: newRemarks,
      createdAt: _loan.createdAt,
      loanCode: _loan.loanCode,
    );
    final updatedLoan = await SupabaseService.instance.upsertLoan(updated);
    setState(() {
      _loan = updatedLoan;
      _isSaving = false;
    });
  }

  Future<void> _handleBankIssuePrompt(String newStatus) async {
    final issueController = TextEditingController(text: _loan.remarks ?? '');
    
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.comment_bank, color: AppColors.primarySolarOrange),
            SizedBox(width: 10),
            Text('Bank Issue / Remark', style: TextStyle(fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Is there any issue with the bank? Or any remarks?', style: TextStyle(fontSize: 14)),
            const SizedBox(height: 16),
            TextField(
              controller: issueController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Write the issue or remarks here...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop('Cancel'),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop('Save'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primarySolarOrange,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Save Status'),
          ),
        ],
      ),
    );

    if (choice == 'Save') {
      final newRemarks = issueController.text.trim().isNotEmpty 
          ? issueController.text.trim() 
          : _loan.remarks;
      await _saveLoanStatus(newStatus, newRemarks);
    }
  }

  Future<void> _markComplete() async {
    await _updateLoanStatus('Completed');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Loan marked as completed!'), backgroundColor: AppColors.completedColor),
      );
    }
  }

  void _callCustomer() {
    _launchUrl('tel:${widget.customer.mobileNumber}');
  }

  void _whatsAppCustomer() {
    final phone = widget.customer.mobileNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final whatsappPhone = phone.startsWith('91') ? phone : '91$phone';
    _launchUrl('https://wa.me/$whatsappPhone');
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        debugPrint('Could not launch $url');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open: $url'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint('Could not launch $url: $e');
    }
  }

  String _getLoanTaskTranslationKey(String taskType) {
    return 'loan_task_${taskType.toLowerCase().replaceAll(' ', '_').replaceAll('-', '_')}';
  }

  String _getLoanStatusTranslationKey(String status) {
    return 'loan_status_${status.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll('-', '_').replaceAll('__', '_')}';
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final completedCount = _loanTasks.where((t) => t.isCompleted).length;
    final totalCount = _loanTasks.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('loan_details')),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Loan',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => LoanFormScreen(
                    preselectedCustomer: widget.customer,
                    loan: _loan,
                  ),
                ),
              ).then((_) {
                _loadDetails();
              });
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Customer & Loan Info Card
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
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.textDarkGray),
                                ),
                              ),
                              if (_loan.loanCode != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    _loan.loanCode!,
                                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          _buildInfoRow(Icons.location_city, translator.translate('branch'), _loan.branch ?? 'N/A'),
                          _buildInfoRow(Icons.currency_rupee, translator.translate('loan_amount'), '\u20b9${_loan.loanAmount.toStringAsFixed(0)}'),
                          _buildInfoRow(Icons.account_balance, translator.translate('bank_name'), _loan.bankName),
                          const Divider(height: 20),
                          // Status Dropdown
                          Row(
                            children: [
                              Text(
                                '${translator.translate('loan_status')}: ',
                                style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textLightGray),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButton<String>(
                                  value: _loan.status,
                                  isExpanded: true,
                                  underline: const SizedBox(),
                                  onChanged: _isSaving ? null : (val) {
                                    if (val != null) _updateLoanStatus(val);
                                  },
                                  items: _loanStatuses.map((status) {
                                    return DropdownMenuItem(
                                      value: status,
                                      child: Text(
                                        translator.translate(_getLoanStatusTranslationKey(status)),
                                        style: const TextStyle(fontWeight: FontWeight.bold),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLoanTracker(translator),
                  const SizedBox(height: 20),

                  // Checklist Progress
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
                              Text(
                                translator.translate('loan_checklist'),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDarkGray),
                              ),
                              Text(
                                '$completedCount/$totalCount',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primarySolarOrange),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (totalCount > 0)
                            LinearProgressIndicator(
                              value: totalCount > 0 ? completedCount / totalCount : 0,
                              backgroundColor: AppColors.borderGray,
                              color: AppColors.completedColor,
                              minHeight: 6,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          const SizedBox(height: 12),

                          // Task List
                          ..._loanTasks.map((task) {
                            return InkWell(
                              onTap: () => _toggleTask(task),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8.0),
                                child: Row(
                                  children: [
                                    Icon(
                                      task.isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                                      color: task.isCompleted ? AppColors.completedColor : AppColors.textLightGray,
                                      size: 24,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        translator.translate(_getLoanTaskTranslationKey(task.taskType)),
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                          color: task.isCompleted ? AppColors.textLightGray : AppColors.textDarkGray,
                                          decoration: task.isCompleted ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    if (task.isCompleted)
                                      const Icon(Icons.done, color: AppColors.completedColor, size: 18),
                                  ],
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Action Buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.progressColor,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _callCustomer,
                          icon: const Icon(Icons.call, size: 18),
                          label: Text(translator.translate('call_customer'), style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366), // WhatsApp green
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          onPressed: _whatsAppCustomer,
                          icon: const Icon(Icons.message, size: 18),
                          label: Text(translator.translate('whatsapp'), style: const TextStyle(fontSize: 13)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.completedColor,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _loan.status == 'Completed' ? null : _markComplete,
                    icon: const Icon(Icons.check_circle),
                    label: Text(translator.translate('mark_complete')),
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.primarySolarOrange),
          const SizedBox(width: 12),
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textLightGray)),
          Expanded(child: Text(value, style: const TextStyle(color: AppColors.textDarkGray, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }

  Widget _buildLoanTracker(TranslationProvider translator) {
    final int currentStep = (_loanStatuses.indexOf(_loan.status) + 1).clamp(1, 7);
    
    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.track_changes, color: AppColors.primarySolarOrange, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Loan Journey',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDarkGray),
                    ),
                  ],
                ),
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: currentStep > 1 
                          ? () => _updateLoanStatus(_loanStatuses[currentStep - 2]) 
                          : null,
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: currentStep < 7 
                          ? () => _updateLoanStatus(_loanStatuses[currentStep]) 
                          : null,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Active spotlight card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primarySolarOrange.withOpacity(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primarySolarOrange.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primarySolarOrange,
                    child: Text(
                      currentStep.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'CURRENT ACTIVE STAGE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primarySolarOrange,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          translator.translate(_getLoanStatusTranslationKey(_loan.status)),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDarkGray,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.progressColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      'In Progress',
                      style: TextStyle(color: AppColors.progressColor, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Overall Progress Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Progress Tracker', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLightGray)),
                Text(
                  '${((currentStep / 7) * 100).toStringAsFixed(0)}% Completed',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primarySolarOrange),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: currentStep / 7,
              backgroundColor: AppColors.borderGray,
              color: AppColors.primarySolarOrange,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 20),

            // Premium Horizontal Stepper List
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: 7,
                itemBuilder: (ctx, idx) {
                  final stepNum = idx + 1;
                  final statusName = _loanStatuses[idx];
                  final isCompleted = stepNum < currentStep;
                  final isActive = stepNum == currentStep;
                  
                  Color cardBg = AppColors.surfaceGray;
                  Color borderColor = AppColors.borderGray;
                  Color contentColor = AppColors.textLightGray;
                  IconData stateIcon = Icons.lock_outline;
                  
                  if (isCompleted) {
                    cardBg = Colors.green.withOpacity(0.08);
                    borderColor = Colors.green.withOpacity(0.3);
                    contentColor = Colors.green;
                    stateIcon = Icons.check_circle;
                  } else if (isActive) {
                    cardBg = AppColors.primarySolarOrange.withOpacity(0.12);
                    borderColor = AppColors.primarySolarOrange;
                    contentColor = AppColors.primarySolarOrange;
                    stateIcon = Icons.play_circle_filled;
                  }

                  return GestureDetector(
                    onTap: () => _updateLoanStatus(statusName),
                    child: Container(
                      margin: const EdgeInsets.only(right: 12),
                      width: 140,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: borderColor, width: isActive ? 2 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Stage $stepNum',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: contentColor,
                                ),
                              ),
                              Icon(stateIcon, size: 16, color: contentColor),
                            ],
                          ),
                          Text(
                            translator.translate(_getLoanStatusTranslationKey(statusName)),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isActive || isCompleted ? FontWeight.bold : FontWeight.normal,
                              color: isActive || isCompleted ? AppColors.textDarkGray : AppColors.textLightGray,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
