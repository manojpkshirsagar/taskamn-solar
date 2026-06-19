import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/loan.dart';
import '../../models/customer.dart';

class LoanFormScreen extends StatefulWidget {
  final Customer? preselectedCustomer;
  final Loan? loan;

  const LoanFormScreen({super.key, this.preselectedCustomer, this.loan});

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  final _formKey = GlobalKey<FormState>();

  String? _selectedCustomerId;
  final _bankController = TextEditingController(text: 'SBI');
  final _loanAmountController = TextEditingController();
  final _branchController = TextEditingController();
  final _remarksController = TextEditingController();

  List<Customer> _customers = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final l = widget.loan;
    if (l != null) {
      _selectedCustomerId = l.customerId;
      _bankController.text = l.bankName;
      _loanAmountController.text = l.loanAmount.toStringAsFixed(0);
      _branchController.text = l.branch ?? '';
      _remarksController.text = l.remarks ?? '';
    } else if (widget.preselectedCustomer != null) {
      _selectedCustomerId = widget.preselectedCustomer!.id;
    }
    _loadCustomers();
  }

  @override
  void dispose() {
    _bankController.dispose();
    _loanAmountController.dispose();
    _branchController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final customers = await SupabaseService.instance.fetchCustomers();
    final loans = await SupabaseService.instance.fetchLoans();
    final loanedCustomerIds = loans.map((l) => l.customerId).toSet();

    final filtered = customers.where((c) {
      if (widget.preselectedCustomer?.id == c.id) return true;
      if (widget.loan?.customerId == c.id) return true;
      return !loanedCustomerIds.contains(c.id);
    }).toList();

    if (mounted) {
      setState(() {
        _customers = filtered;
        if (_selectedCustomerId == null && _customers.isNotEmpty) {
          _selectedCustomerId = _customers.first.id;
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _saveLoan() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCustomerId == null) return;

    setState(() => _isSaving = true);
    final isEdit = widget.loan != null;

    final loan = Loan(
      id: widget.loan?.id ?? const Uuid().v4(),
      customerId: _selectedCustomerId!,
      loanAmount: double.tryParse(_loanAmountController.text.trim()) ?? 0,
      bankName: _bankController.text.trim(),
      branch: _branchController.text.trim().isNotEmpty
          ? _branchController.text.trim()
          : null,
      status: widget.loan?.status ?? 'Loan Application',
      remarks: _remarksController.text.trim().isNotEmpty
          ? _remarksController.text.trim()
          : null,
      createdAt: widget.loan?.createdAt ?? DateTime.now(),
      assignedEmployeeId: widget.loan?.assignedEmployeeId,
    );

    if (isEdit) {
      await SupabaseService.instance.upsertLoan(loan);
    } else {
      await SupabaseService.instance.createLoanWithAutoTasks(loan);
    }

    setState(() => _isSaving = false);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEdit ? 'Loan updated successfully!' : 'Loan created with auto-generated tasks!'),
          backgroundColor: AppColors.completedColor,
        ),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final isEdit = widget.loan != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Loan' : translator.translate('create_loan')),
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

                    // Bank Name Field (Manual entry)
                    TextFormField(
                      controller: _bankController,
                      decoration: InputDecoration(
                        labelText: translator.translate('bank_name'),
                        prefixIcon: const Icon(Icons.account_balance),
                      ),
                      validator: (val) => val == null || val.trim().isEmpty ? 'Please enter bank name' : null,
                    ),
                    const SizedBox(height: 16),

                    // Loan Amount
                    TextFormField(
                      controller: _loanAmountController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: translator.translate('loan_amount'),
                        prefixIcon: const Icon(Icons.currency_rupee),
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) return 'Please enter loan amount';
                        if (double.tryParse(val) == null) return 'Invalid amount';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Branch Input
                    TextFormField(
                      controller: _branchController,
                      decoration: InputDecoration(
                        labelText: translator.translate('branch'),
                        hintText: 'e.g. Main Branch',
                        prefixIcon: const Icon(Icons.location_city),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Remarks
                    TextFormField(
                      controller: _remarksController,
                      maxLines: 3,
                      decoration: InputDecoration(labelText: translator.translate('remarks')),
                    ),
                    const SizedBox(height: 24),

                    // Auto-tasks info
                    if (!isEdit)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.progressColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.progressColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppColors.progressColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                '8 checklist tasks will be auto-generated:\nCollect Aadhaar, PAN, Light Bill, Passbook, Loan Application, Bank Follow-up, Approval & Disbursement Follow-up.',
                                style: TextStyle(fontSize: 12, color: AppColors.progressColor.withOpacity(0.9)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (!isEdit) const SizedBox(height: 24),

                    ElevatedButton(
                      onPressed: _isSaving ? null : _saveLoan,
                      child: _isSaving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : Text(isEdit ? 'Save Changes' : translator.translate('create_loan')),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
