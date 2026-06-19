import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/approval_service.dart';
import '../../services/connectivity_service.dart';
import '../../constants/colors.dart';
import '../../models/customer.dart';

class CustomerFormScreen extends StatefulWidget {
  final Customer? customer;

  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _nameController;
  late TextEditingController _mobileController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;
  late TextEditingController _consumerNumberController;
  late TextEditingController _solarCapacityController;
  
  String _selectedStage = 'Lead';
  bool _isSaving = false;

  final List<String> _stages = [
    'Lead',
    'Survey',
    'Quotation',
    'Quotation Sent',
    'Customer Confirmed',
    'PM Surya Ghar Application',
    'Loan Process',
    'Approved',
    'Material Dispatch',
    'Installation',
    'Net Meter',
    'RTS',
    'Subsidy',
    'Completed',
    'Cancelled'
  ];

  @override
  void initState() {
    super.initState();
    final c = widget.customer;
    _nameController = TextEditingController(text: c?.name ?? '');
    _mobileController = TextEditingController(text: c?.mobileNumber ?? '');
    _emailController = TextEditingController(text: c?.emailAddress ?? '');
    _addressController = TextEditingController(text: c?.address ?? '');
    _consumerNumberController = TextEditingController(text: c?.consumerNumber ?? '');
    _solarCapacityController = TextEditingController(text: c?.solarCapacity.toString() ?? '0.0');
    _selectedStage = c?.stage ?? 'Lead';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _consumerNumberController.dispose();
    _solarCapacityController.dispose();
    super.dispose();
  }

  Future<void> _saveForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    final isEdit = widget.customer != null;
    final currentUser = SupabaseService.instance.cachedUser;
    final isAdmin = currentUser?.role == 'admin';

    final customer = Customer(
      id: widget.customer?.id ?? const Uuid().v4(),
      name: _nameController.text.trim(),
      mobileNumber: _mobileController.text.trim(),
      emailAddress: _emailController.text.trim(),
      address: _addressController.text.trim(),
      consumerNumber: _consumerNumberController.text.trim().isEmpty ? null : _consumerNumberController.text.trim(),
      solarCapacity: double.tryParse(_solarCapacityController.text) ?? 0.0,
      stage: _selectedStage,
      installationStage: widget.customer != null && widget.customer!.stage == _selectedStage
          ? widget.customer!.installationStage
          : _getDefaultInstallationStage(_selectedStage),
      paymentMode: widget.customer?.paymentMode ?? 'Not Selected',
      createdAt: widget.customer?.createdAt ?? DateTime.now(),
    );

    if (isAdmin) {
      // Admin: write directly to live data
      await SupabaseService.instance.upsertCustomer(customer);
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit ? 'Customer updated successfully' : 'Customer created successfully'),
            backgroundColor: AppColors.completedColor,
          ),
        );
        Navigator.of(context).pop();
      }
    } else {
      // Employee: route through approval workflow
      final oldData = widget.customer?.toJson();
      await ApprovalService.instance.submitForApproval(
        moduleName: 'customers',
        recordId: customer.id,
        employeeId: currentUser!.id,
        customerId: customer.id,
        actionType: isEdit ? 'UPDATE' : 'CREATE',
        oldData: oldData,
        newData: customer.toJson(),
      );
      setState(() => _isSaving = false);
      if (mounted) {
        final isOnline = ConnectivityService.instance.isOnline;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.pending_actions, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    isOnline
                        ? 'Submitted for Admin Approval'
                        : '💾 Saved Offline — Pending Approval',
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.orange.shade700,
            duration: const Duration(seconds: 3),
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  int _getDefaultInstallationStage(String stage) {
    switch (stage) {
      case 'Lead':
        return 1;
      case 'Quotation Sent':
        return 2;
      case 'Customer Confirmed':
        return 3;
      case 'PM Surya Ghar Application':
        return 4;
      case 'Installation':
        return 6;
      case 'RTS':
        return 9;
      case 'Subsidy':
        return 10;
      case 'Completed':
        return 10;
      default:
        return 1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final isEdit = widget.customer != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? translator.translate('edit_customer') : translator.translate('add_customer')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: translator.translate('customer_name')),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter customer name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(labelText: translator.translate('mobile_number')),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter mobile number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: translator.translate('email')),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(labelText: translator.translate('address')),
                validator: (val) => val == null || val.trim().isEmpty ? 'Please enter address' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _consumerNumberController,
                decoration: InputDecoration(labelText: translator.translate('consumer_number')),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _solarCapacityController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: translator.translate('solar_capacity')),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedStage,
                decoration: InputDecoration(labelText: translator.translate('customer_stage')),
                items: (() {
                  final stagesList = List<String>.from(_stages);
                  if (!stagesList.contains(_selectedStage)) {
                    stagesList.add(_selectedStage);
                  }
                  return stagesList.map((stage) {
                    return DropdownMenuItem(
                      value: stage,
                      child: Text(translator.translate('stage_${stage.toLowerCase().replaceAll(' ', '_')}') ?? stage),
                    );
                  }).toList();
                })(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStage = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _isSaving ? null : _saveForm,
                child: _isSaving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                      )
                    : Text(translator.translate('save')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
