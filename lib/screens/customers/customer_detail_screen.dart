import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path_provider/path_provider.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/customer.dart';
import '../../models/installation_photos.dart';
import '../../models/loan.dart';
import '../../models/label_category.dart';
import '../../models/label.dart';
import '../../models/customer_label.dart';
import '../tasks/task_form_screen.dart';
import '../loans/loan_detail_screen.dart';
import '../loans/loan_form_screen.dart';

class CustomerDetailScreen extends StatefulWidget {
  final Customer customer;

  const CustomerDetailScreen({super.key, required this.customer});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> {
  late Customer _customer;
  bool _isLoading = true;
  InstallationPhotos? _photoRecord;
  Loan? _loan;
  final ImagePicker _picker = ImagePicker();

  List<LabelCategory> _categories = [];
  List<Label> _labels = [];
  List<CustomerLabel> _customerLabels = [];

  // Single source of truth: CRM stages in order (index+1 = installationStage number)
  static const List<String> _stages = [
    'Lead',                       // 1
    'Survey',                     // 2
    'Quotation',                  // 3
    'Quotation Sent',             // 4
    'Customer Confirmed',         // 5
    'PM Surya Ghar Application',  // 6
    'Loan Process',               // 7
    'Approved',                   // 8
    'Material Dispatch',          // 9
    'Installation',               // 10
    'Net Meter',                  // 11
    'RTS',                        // 12
    'Subsidy',                    // 13
    'Completed',                  // 14
    'Cancelled',                  // 15
  ];

  @override
  void initState() {
    super.initState();
    _customer = widget.customer;
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);
    final photoRecord = await SupabaseService.instance.fetchInstallationPhotos(_customer.id);
    final loans = await SupabaseService.instance.fetchLoans();
    final cats = await SupabaseService.instance.fetchLabelCategories();
    final lbs = await SupabaseService.instance.fetchLabels();
    final clbs = await SupabaseService.instance.fetchCustomerLabels(_customer.id);

    Loan? matchedLoan;
    try {
      matchedLoan = loans.firstWhere((l) => l.customerId == _customer.id);
    } catch (_) {
      matchedLoan = null;
    }
    if (mounted) {
      setState(() {
        _photoRecord = photoRecord;
        _loan = matchedLoan;
        _categories = cats;
        _labels = lbs;
        _customerLabels = clbs;
        _isLoading = false;
      });
    }
  }

  Future<bool> _canTransitionToStage(String newStage) async {
    final newIndex = _stages.indexOf(newStage);
    final installationIndex = _stages.indexOf('Installation');
    if (newIndex >= installationIndex) {
      if (_customer.paymentMode == 'Not Selected') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a Payment Mode (Cash/Loan) first.'),
            backgroundColor: AppColors.pendingColor,
          ),
        );
        return false;
      }
      if (_customer.paymentMode == 'Loan') {
        if (_loan == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No loan record found. Please create a loan for this customer first.'),
              backgroundColor: AppColors.pendingColor,
            ),
          );
          return false;
        }
        final isLoanValid = _loan!.status == 'Approval' || 
                            _loan!.status == 'Completed' ||
                            _loan!.status == 'Approved' ||
                            _loan!.status == 'Loan Approved' ||
                            _loan!.status == 'Loan Disbursed';
        if (!isLoanValid) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Loan must be Approved or Disbursed (Current status: ${_loan!.status}).'),
              backgroundColor: AppColors.pendingColor,
            ),
          );
          return false;
        }
      }
    }
    return true;
  }

  Future<void> _updateStage(String newStage) async {
    if (!await _canTransitionToStage(newStage)) return;

    // Map stage name to step number using the single STAGES list
    final stepNum = _stages.indexOf(newStage) + 1;
    final defaultStep = stepNum > 0 ? stepNum : 1;

    // Special: PM Surya Ghar Application requires Cash or Loan selection
    if (newStage == 'PM Surya Ghar Application') {
      await _handlePMSuryaGharTransition(defaultStep);
      return;
    }

    final updated = Customer(
      id: _customer.id,
      name: _customer.name,
      mobileNumber: _customer.mobileNumber,
      emailAddress: _customer.emailAddress,
      address: _customer.address,
      consumerNumber: _customer.consumerNumber,
      solarCapacity: _customer.solarCapacity,
      stage: newStage,
      installationStage: defaultStep,
      paymentMode: _customer.paymentMode,
      createdAt: _customer.createdAt,
      customerCode: _customer.customerCode,
      leadCode: _customer.leadCode,
      installationCode: _customer.installationCode,
      netMeterCode: _customer.netMeterCode,
      subsidyCode: _customer.subsidyCode,
      quotationCode: _customer.quotationCode,
      paymentCode: _customer.paymentCode,
    );
    final finalCust = await SupabaseService.instance.upsertCustomer(updated);
    setState(() {
      _customer = finalCust;
    });
  }

  /// Shows a Cash / Loan Application dialog when moving to PM Surya Ghar Application.
  /// Saves the payment mode and navigates to the Loan form if Loan is selected.
  Future<void> _handlePMSuryaGharTransition(int stepNum) async {
    if (!mounted) return;

    final choice = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.solar_power, color: AppColors.primarySolarOrange, size: 28),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'PM Surya Ghar Application',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'How will this customer pay for the solar system?',
              style: TextStyle(color: Colors.black54, fontSize: 14),
            ),
            const SizedBox(height: 20),
            // Cash Option
            InkWell(
              onTap: () => Navigator.of(ctx).pop('Cash'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green.shade200, width: 1.5),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.green,
                      child: Icon(Icons.payments_rounded, color: Colors.white, size: 22),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Cash Payment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.green)),
                          SizedBox(height: 2),
                          Text('Customer will pay in cash', style: TextStyle(color: Colors.black45, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.green),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Loan Option
            InkWell(
              onTap: () => Navigator.of(ctx).pop('Loan'),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.indigo.shade200, width: 1.5),
                ),
                child: const Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.indigo,
                      child: Icon(Icons.account_balance_rounded, color: Colors.white, size: 22),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Loan Application', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.indigo)),
                          SizedBox(height: 2),
                          Text('Create a bank loan application', style: TextStyle(color: Colors.black45, fontSize: 12)),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 14, color: Colors.indigo),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (choice == null || !mounted) return; // User cancelled

    // Save stage + payment mode
    final updated = Customer(
      id: _customer.id,
      name: _customer.name,
      mobileNumber: _customer.mobileNumber,
      emailAddress: _customer.emailAddress,
      address: _customer.address,
      consumerNumber: _customer.consumerNumber,
      solarCapacity: _customer.solarCapacity,
      stage: 'PM Surya Ghar Application',
      installationStage: stepNum,
      paymentMode: choice,
      createdAt: _customer.createdAt,
      customerCode: _customer.customerCode,
      leadCode: _customer.leadCode,
      installationCode: _customer.installationCode,
      netMeterCode: _customer.netMeterCode,
      subsidyCode: _customer.subsidyCode,
      quotationCode: _customer.quotationCode,
      paymentCode: _customer.paymentCode,
    );
    final finalCust = await SupabaseService.instance.upsertCustomer(updated);
    if (!mounted) return;
    setState(() {
      _customer = finalCust;
    });

    // If Loan — go directly to loan form / existing loan screen
    if (choice == 'Loan' && mounted) {
      if (_loan != null) {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoanDetailScreen(loan: _loan!, customer: _customer)),
        ).then((_) => _loadDetails());
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => LoanFormScreen(preselectedCustomer: _customer)),
        ).then((_) => _loadDetails());
      }
    } else if (choice == 'Cash' && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Payment mode set to Cash. Stage updated to PM Surya Ghar Application.'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _updatePaymentMode(String newMode) async {
    final updated = Customer(
      id: _customer.id,
      name: _customer.name,
      mobileNumber: _customer.mobileNumber,
      emailAddress: _customer.emailAddress,
      address: _customer.address,
      consumerNumber: _customer.consumerNumber,
      solarCapacity: _customer.solarCapacity,
      stage: _customer.stage,
      installationStage: _customer.installationStage,
      paymentMode: newMode,
      createdAt: _customer.createdAt,
      customerCode: _customer.customerCode,
      leadCode: _customer.leadCode,
      installationCode: _customer.installationCode,
      netMeterCode: _customer.netMeterCode,
      subsidyCode: _customer.subsidyCode,
      quotationCode: _customer.quotationCode,
      paymentCode: _customer.paymentCode,
    );
    final finalCust = await SupabaseService.instance.upsertCustomer(updated);
    setState(() {
      _customer = finalCust;
    });

    if (newMode == 'Loan' && mounted) {
      if (_loan != null) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoanDetailScreen(loan: _loan!, customer: _customer),
          ),
        ).then((_) => _loadDetails());
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => LoanFormScreen(preselectedCustomer: _customer),
          ),
        ).then((_) => _loadDetails());
      }
    }
  }

  Future<void> _updateInstallationStep(int step) async {
    // Map step number to stage using the single STAGES list
    if (step < 1 || step > _stages.length) return;
    final mappedStage = _stages[step - 1];

    if (!await _canTransitionToStage(mappedStage)) return;

    // Special: PM Surya Ghar Application requires Cash or Loan selection
    if (mappedStage == 'PM Surya Ghar Application') {
      await _handlePMSuryaGharTransition(step);
      return;
    }

    final updated = Customer(
      id: _customer.id,
      name: _customer.name,
      mobileNumber: _customer.mobileNumber,
      emailAddress: _customer.emailAddress,
      address: _customer.address,
      consumerNumber: _customer.consumerNumber,
      solarCapacity: _customer.solarCapacity,
      stage: mappedStage,
      installationStage: step,
      paymentMode: _customer.paymentMode,
      createdAt: _customer.createdAt,
      customerCode: _customer.customerCode,
      leadCode: _customer.leadCode,
      installationCode: _customer.installationCode,
      netMeterCode: _customer.netMeterCode,
      subsidyCode: _customer.subsidyCode,
      quotationCode: _customer.quotationCode,
      paymentCode: _customer.paymentCode,
    );
    final finalCust = await SupabaseService.instance.upsertCustomer(updated);
    setState(() {
      _customer = finalCust;
    });
  }

  Future<void> _pickAndUploadPhoto(String type) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Photo Source'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ImageSource.camera),
            child: const Text('Camera'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(ImageSource.gallery),
            child: const Text('Gallery'),
          ),
        ],
      ),
    );

    if (source == null) return;

    final pickedFile = await _picker.pickImage(source: source, imageQuality: 70);
    if (pickedFile == null) return;

    setState(() => _isLoading = true);

    final file = File(pickedFile.path);
    final url = await SupabaseService.instance.uploadPhoto(_customer.id, file, type);

    if (url != null) {
      final updatedRecord = InstallationPhotos(
        id: _photoRecord?.id ?? _customer.id,
        customerId: _customer.id,
        roofPhotoUrl: type == 'roof' ? url : _photoRecord?.roofPhotoUrl,
        installationPhotoUrl: type == 'installation' ? url : _photoRecord?.installationPhotoUrl,
        inverterPhotoUrl: type == 'inverter' ? url : _photoRecord?.inverterPhotoUrl,
        meterPhotoUrl: type == 'meter' ? url : _photoRecord?.meterPhotoUrl,
        customerSignatureUrl: _photoRecord?.customerSignatureUrl,
        updatedAt: DateTime.now(),
      );

      await SupabaseService.instance.savePhotos(updatedRecord);
      setState(() {
        _photoRecord = updatedRecord;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo uploaded successfully!'), backgroundColor: AppColors.completedColor),
        );
      }
    }
    setState(() => _isLoading = false);
  }

  Future<void> _captureSignature() async {
    final bytes = await showDialog<List<Offset>>(
      context: context,
      builder: (ctx) => const SignatureDialog(),
    );

    if (bytes == null || bytes.isEmpty) return;

    setState(() => _isLoading = true);

    // Render offsets to a file
    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, 300, 150));
      final paint = Paint()
        ..color = Colors.black
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 4.0;
      
      canvas.drawRect(const Rect.fromLTWH(0, 0, 300, 150), Paint()..color = Colors.white);
      for (int i = 0; i < bytes.length - 1; i++) {
        if (bytes[i] != Offset.infinite && bytes[i + 1] != Offset.infinite) {
          canvas.drawLine(bytes[i], bytes[i + 1], paint);
        }
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(300, 150);
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
      
      if (pngBytes != null) {
        final dir = await getApplicationDocumentsDirectory();
        final file = File('${dir.path}/sig_${_customer.id}.png');
        await file.writeAsBytes(pngBytes.buffer.asUint8List());

        final url = await SupabaseService.instance.uploadPhoto(_customer.id, file, 'signature');
        if (url != null) {
          final updatedRecord = InstallationPhotos(
            id: _photoRecord?.id ?? _customer.id,
            customerId: _customer.id,
            roofPhotoUrl: _photoRecord?.roofPhotoUrl,
            installationPhotoUrl: _photoRecord?.installationPhotoUrl,
            inverterPhotoUrl: _photoRecord?.inverterPhotoUrl,
            meterPhotoUrl: _photoRecord?.meterPhotoUrl,
            customerSignatureUrl: url,
            updatedAt: DateTime.now(),
          );

          await SupabaseService.instance.savePhotos(updatedRecord);
          setState(() {
            _photoRecord = updatedRecord;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Signature saved successfully!'), backgroundColor: AppColors.completedColor),
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Signature render error: $e");
    }
    setState(() => _isLoading = false);
  }

  void _confirmDeleteCustomer(BuildContext context, TranslationProvider translator) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Delete Customer?'),
          content: Text('Are you sure you want to delete ${_customer.name}? This action is permanent and will delete all associated loans, tasks, and files.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(translator.translate('cancel')),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () async {
                Navigator.of(ctx).pop();
                setState(() => _isLoading = true);
                try {
                  await SupabaseService.instance.deleteCustomer(_customer.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Customer ${_customer.name} deleted successfully.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                    Navigator.of(context).pop(true);
                  }
                } catch (e) {
                  if (mounted) {
                    setState(() => _isLoading = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to delete customer: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 5),
                      ),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final user = SupabaseService.instance.cachedUser;
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('customer_details')),
        actions: [
          if (isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.task),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => TaskFormScreen(preselectedCustomer: _customer)),
                );
              },
            ),
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _confirmDeleteCustomer(context, translator),
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 850),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileCard(translator),
                      const SizedBox(height: 20),
                      _buildInstallationTracker(translator),
                      if (_customer.paymentMode != 'Cash') ...[
                        const SizedBox(height: 20),
                        _buildLoanInfoSection(translator),
                      ],
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  Color _getLoanStatusColor(String status) {
    switch (status) {
      case 'File Print':
      case 'File at Office':
        return AppColors.loanDocPending;
      case 'File at Bank':
        return AppColors.loanBankVerification;
      case 'Bank Issue or Approved':
      case 'Approved / Reject-Reapplied':
        return AppColors.loanApproved;
      case 'Approved':
        return AppColors.loanDisbursed;
      default:
        return AppColors.primarySolarOrange;
    }
  }

  Widget _buildLoanInfoSection(TranslationProvider translator) {
    if (_customer.paymentMode == 'Cash') {
      return const SizedBox.shrink(); // Hide the loan section completely for Cash customers
    }
    final user = SupabaseService.instance.cachedUser;
    final isAdmin = user?.role == 'admin';

    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.account_balance, color: AppColors.primarySolarOrange, size: 24),
                const SizedBox(width: 8),
                Text(
                  translator.translate('loan_details'),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDarkGray),
                ),
              ],
            ),
            const Divider(),
            if (_loan != null) ...[
              _buildInfoRow(Icons.account_balance, translator.translate('bank_name'), _loan!.bankName),
              _buildInfoRow(Icons.currency_rupee, translator.translate('loan_amount'), '\u20b9${_loan!.loanAmount.toStringAsFixed(0)}'),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    const Icon(Icons.info, size: 18, color: AppColors.primarySolarOrange),
                    const SizedBox(width: 12),
                    Text('${translator.translate('loan_status')}: ', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textLightGray)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getLoanStatusColor(_loan!.status).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        translator.translate('loan_status_${_loan!.status.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll('-', '_').replaceAll('__', '_')}'),
                        style: TextStyle(
                          color: _getLoanStatusColor(_loan!.status),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primarySolarOrange),
                  icon: const Icon(Icons.list_alt, color: Colors.white),
                  label: Text(translator.translate('loan_checklist'), style: const TextStyle(color: Colors.white)),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LoanDetailScreen(loan: _loan!, customer: _customer),
                      ),
                    ).then((_) => _loadDetails());
                  },
                ),
              ),
            ] else ...[
              const Text(
                'No active loan details found for this customer.',
                style: TextStyle(color: AppColors.textLightGray, fontStyle: FontStyle.italic),
              ),
              if (isAdmin) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.progressColor),
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: Text(translator.translate('create_loan'), style: const TextStyle(color: Colors.white)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => LoanFormScreen(preselectedCustomer: _customer),
                        ),
                      ).then((_) => _loadDetails());
                    },
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildProfileCard(TranslationProvider translator) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hero Header Section with Gradient
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primarySolarOrange, Color(0xFFFF9E3D)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Text(
                        _customer.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Elegant Dropdown for Stage — constrained so it never squeezes the name
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 160),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            isExpanded: true,
                            dropdownColor: AppColors.primarySolarOrange,
                            value: _customer.stage,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            onChanged: (val) {
                              if (val != null) {
                                _updateStage(val);
                              }
                            },
                            items: (() {
                              final stagesList = List<String>.from(_stages);
                              if (!stagesList.contains(_customer.stage)) {
                                stagesList.add(_customer.stage);
                              }
                              return stagesList.map((stage) {
                                return DropdownMenuItem(
                                  value: stage,
                                  child: Text(
                                    translator.translate('stage_${stage.toLowerCase().replaceAll(' ', '_')}') ?? stage,
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList();
                            })(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.email, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _customer.emailAddress.isEmpty ? 'No Email' : _customer.emailAddress,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.white70),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _customer.address.isEmpty ? 'No Address' : _customer.address,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Details Body
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quick Call Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone, size: 20, color: AppColors.primarySolarOrange),
                        const SizedBox(width: 10),
                        Text(
                          _customer.mobileNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDarkGray,
                          ),
                        ),
                      ],
                    ),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.progressColor,
                        foregroundColor: Colors.white,
                      ),
                      icon: const Icon(Icons.phone),
                      onPressed: () => _launchUrl('tel:${_customer.mobileNumber}'),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Project Identifiers Row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Project Identifiers',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLightGray),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (_customer.customerCode != null)
                            _buildIdBadge('Customer ID', _customer.customerCode!, Colors.blue),
                          if (_customer.leadCode != null)
                            _buildIdBadge('Lead ID', _customer.leadCode!, Colors.orange),
                          if (_customer.quotationCode != null)
                            _buildIdBadge('Quotation ID', _customer.quotationCode!, Colors.deepOrange),
                          if (_customer.installationCode != null)
                            _buildIdBadge('Install ID', _customer.installationCode!, Colors.green),
                          if (_customer.netMeterCode != null)
                            _buildIdBadge('Net Meter ID', _customer.netMeterCode!, Colors.purple),
                          if (_customer.subsidyCode != null)
                            _buildIdBadge('Subsidy ID', _customer.subsidyCode!, Colors.teal),
                          if (_customer.paymentCode != null)
                            _buildIdBadge('Payment ID', _customer.paymentCode!, Colors.green.shade800),
                        ],
                      ),
                    ],
                  ),
                ),
                const Divider(height: 24),

                // Solar Capacity Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.solar_power, size: 20, color: AppColors.primarySolarOrange),
                        SizedBox(width: 10),
                        Text(
                          'Solar Capacity',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDarkGray),
                        ),
                      ],
                    ),
                    Text(
                      '${_customer.solarCapacity} kW',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primarySolarOrange),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Payment Mode Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.payment, size: 20, color: AppColors.primarySolarOrange),
                        SizedBox(width: 10),
                        Text(
                          'Payment Mode',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textDarkGray,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceGray,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderGray),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _customer.paymentMode,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primarySolarOrange),
                          style: const TextStyle(
                            color: AppColors.textDarkGray,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                          onChanged: (val) {
                            if (val != null) {
                              _updatePaymentMode(val);
                            }
                          },
                          items: const [
                            DropdownMenuItem(value: 'Not Selected', child: Text('Not Selected')),
                            DropdownMenuItem(value: 'Cash', child: Text('Cash')),
                            DropdownMenuItem(value: 'Loan', child: Text('Loan')),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),
                const Text(
                  'Labels',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDarkGray),
                ),
                const SizedBox(height: 8),
                _buildLabelsChipsSection(translator),
                const Divider(height: 24),
                const Text(
                  'Quick Actions',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDarkGray),
                ),
                const SizedBox(height: 12),
                _buildQuickActionsGrid(translator),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdBadge(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color.withOpacity(0.9)),
          ),
        ],
      ),
    );
  }

  Widget _buildLabelsChipsSection(TranslationProvider translator) {
    if (_customerLabels.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8.0),
        child: Text(
          'No labels attached.',
          style: TextStyle(color: AppColors.textLightGray, fontStyle: FontStyle.italic),
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _customerLabels.map((cl) {
        final label = _labels.firstWhere(
          (l) => l.id == cl.labelId,
          orElse: () => Label(id: '', categoryId: '', labelName: cl.labelId),
        );
        if (label.id.isEmpty) return const SizedBox.shrink();

        final cat = _categories.firstWhere(
          (c) => c.id == label.categoryId,
          orElse: () => LabelCategory(id: '', categoryName: ''),
        );

        Color chipColor = AppColors.primarySolarOrange;
        if (cat.categoryName == 'Installation') {
          chipColor = Colors.orange;
        } else if (cat.categoryName == 'Documentation') {
          chipColor = Colors.blue;
        } else if (cat.categoryName == 'Net Meter') {
          chipColor = Colors.purple;
        } else if (cat.categoryName == 'Subsidy') {
          chipColor = Colors.teal;
        } else if (cat.categoryName == 'Loan') {
          chipColor = Colors.indigo;
        } else if (cat.categoryName == 'Payment') {
          chipColor = Colors.green;
        } else if (cat.categoryName == 'Service') {
          chipColor = Colors.red;
        }

        return Chip(
          label: Text(
            label.labelName,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          backgroundColor: chipColor,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        );
      }).toList(),
    );
  }

  Widget _buildQuickActionsGrid(TranslationProvider translator) {
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: [
        _buildActionButton(
          icon: Icons.label,
          label: 'Add Label',
          color: Colors.blue,
          onTap: _showAddLabelsDialog,
        ),
        _buildActionButton(
          icon: Icons.add_task,
          label: 'Create Task',
          color: Colors.green,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => TaskFormScreen(preselectedCustomer: _customer)),
            ).then((_) => _loadDetails());
          },
        ),
        _buildActionButton(
          icon: Icons.add_a_photo,
          label: 'Upload Photo',
          color: Colors.orange,
          onTap: () => _pickAndUploadPhoto('installation'),
        ),
        _buildActionButton(
          icon: Icons.account_balance,
          label: 'Add Loan',
          color: Colors.indigo,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => LoanFormScreen(preselectedCustomer: _customer)),
            ).then((_) => _loadDetails());
          },
        ),
        _buildActionButton(
          icon: Icons.payment,
          label: 'Add Payment',
          color: Colors.teal,
          onTap: _showAddPaymentDialog,
        ),
        _buildActionButton(
          icon: Icons.swap_horiz,
          label: 'Update Stage',
          color: Colors.red,
          onTap: _showUpdateStageDialog,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.1),
        foregroundColor: color,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      ),
      onPressed: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showAddLabelsDialog() {
    final activeLabels = _labels.where((l) => l.isActive).toList();
    final selectedIds = _customerLabels.map((cl) => cl.labelId).toList();
    String searchQuery = '';

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final filteredLabels = searchQuery.isEmpty
                ? activeLabels
                : activeLabels
                    .where((l) => l.labelName
                        .toLowerCase()
                        .contains(searchQuery.toLowerCase()))
                    .toList();

            return AlertDialog(
              title: const Text('Add / Remove Labels'),
              content: SizedBox(
                width: double.maxFinite,
                height: 450,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search Labels',
                        prefixIcon: Icon(Icons.search),
                        contentPadding: EdgeInsets.symmetric(vertical: 0),
                      ),
                      onChanged: (val) {
                        setDialogState(() {
                          searchQuery = val;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: ListView.builder(
                        itemCount: _categories.length,
                        itemBuilder: (context, catIdx) {
                          final category = _categories[catIdx];
                          final categoryLabels = filteredLabels
                              .where((l) => l.categoryId == category.id)
                              .toList();

                          if (categoryLabels.isEmpty) return const SizedBox.shrink();

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                child: Text(
                                  category.categoryName.toUpperCase(),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primarySolarOrange,
                                      fontSize: 12),
                                ),
                              ),
                              ...categoryLabels.map((label) {
                                final isChecked = selectedIds.contains(label.id);
                                return CheckboxListTile(
                                  title: Text(label.labelName),
                                  value: isChecked,
                                  onChanged: (val) {
                                    setDialogState(() {
                                      if (val == true) {
                                        selectedIds.add(label.id);
                                      } else {
                                        selectedIds.remove(label.id);
                                      }
                                    });
                                  },
                                );
                              }),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primarySolarOrange,
                      foregroundColor: Colors.white),
                  onPressed: () async {
                    await SupabaseService.instance
                        .assignLabelsToCustomer(_customer.id, selectedIds);
                    if (context.mounted) Navigator.pop(context);
                    _loadDetails();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddNoteDialog() {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Note / Remark'),
          content: TextField(
            controller: noteController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Enter your note here...',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primarySolarOrange, foregroundColor: Colors.white),
              onPressed: () async {
                if (noteController.text.trim().isEmpty) return;
                final noteText = noteController.text.trim();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Note added: "$noteText"'), backgroundColor: AppColors.completedColor),
                );
                Navigator.pop(context);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _showAddPaymentDialog() {
    final amountController = TextEditingController();
    String selectedStage = 'Advance Pending';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Payment Log'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedStage,
                decoration: const InputDecoration(labelText: 'Payment Stage'),
                items: const [
                  DropdownMenuItem(value: 'Advance Pending', child: Text('Advance Payment')),
                  DropdownMenuItem(value: 'Material Payment Pending', child: Text('Material Payment')),
                  DropdownMenuItem(value: 'Final Payment Pending', child: Text('Final Payment')),
                ],
                onChanged: (val) {
                  if (val != null) selectedStage = val;
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Amount (Rs.)',
                  hintText: 'Enter amount',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.primarySolarOrange, foregroundColor: Colors.white),
              onPressed: () {
                final amount = amountController.text.trim();
                if (amount.isEmpty) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Payment of Rs. $amount logged for $selectedStage'), backgroundColor: AppColors.completedColor),
                );
                Navigator.pop(context);
              },
              child: const Text('Log Payment'),
            ),
          ],
        );
      },
    );
  }

  void _showUpdateStageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select Stage'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: _stages.length,
              itemBuilder: (context, idx) {
                final stage = _stages[idx];
                return ListTile(
                  title: Text(stage),
                  onTap: () {
                    _updateStage(stage);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildInstallationTracker(TranslationProvider translator) {
    final int totalSteps = _stages.length; // 15
    final int currentStep = _customer.installationStage.clamp(1, totalSteps);
    final String currentStage = _stages[currentStep - 1];
    final bool isCancelled = currentStage == 'Cancelled';
    final bool isCompleted = currentStage == 'Completed';
    
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
                    Icon(Icons.rocket_launch, color: AppColors.primarySolarOrange, size: 24),
                    SizedBox(width: 10),
                    Text(
                      'Installation Journey',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDarkGray),
                    ),
                  ],
                ),
                // Forward/Backward navigation
                Row(
                  children: [
                    IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: currentStep > 1 && !isCompleted && !isCancelled
                          ? () => _updateInstallationStep(currentStep - 1)
                          : null,
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: currentStep < totalSteps && !isCompleted && !isCancelled
                          ? () => _updateInstallationStep(currentStep + 1)
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
                color: isCancelled
                    ? Colors.red.withValues(alpha: 0.08)
                    : isCompleted
                        ? Colors.green.withValues(alpha: 0.08)
                        : AppColors.primarySolarOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isCancelled
                      ? Colors.red.withValues(alpha: 0.25)
                      : isCompleted
                          ? Colors.green.withValues(alpha: 0.25)
                          : AppColors.primarySolarOrange.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: isCancelled
                        ? Colors.red
                        : isCompleted
                            ? Colors.green
                            : AppColors.primarySolarOrange,
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
                        Text(
                          'CURRENT STAGE ($currentStep / $totalSteps)',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: isCancelled
                                ? Colors.red
                                : isCompleted
                                    ? Colors.green
                                    : AppColors.primarySolarOrange,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          translator.translate('step_$currentStep'),
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
                      color: isCancelled
                          ? Colors.red.withValues(alpha: 0.12)
                          : isCompleted
                              ? Colors.green.withValues(alpha: 0.12)
                              : AppColors.progressColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      isCancelled ? 'Cancelled' : isCompleted ? 'Completed' : 'In Progress',
                      style: TextStyle(
                        color: isCancelled
                            ? Colors.red
                            : isCompleted
                                ? Colors.green
                                : AppColors.progressColor,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
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
                  isCancelled
                      ? 'Cancelled'
                      : '${((currentStep / (totalSteps - 1)) * 100).clamp(0, 100).toStringAsFixed(0)}% Completed',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isCancelled ? Colors.red : AppColors.primarySolarOrange,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(
              value: isCancelled ? 1.0 : (currentStep - 1) / (totalSteps - 2),
              backgroundColor: AppColors.borderGray,
              color: isCancelled ? Colors.red : AppColors.primarySolarOrange,
              minHeight: 8,
              borderRadius: BorderRadius.circular(4),
            ),
            const SizedBox(height: 20),

            // Horizontal Stepper — one card per stage
            SizedBox(
              height: 90,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: totalSteps,
                itemBuilder: (ctx, idx) {
                  final stepNum = idx + 1;
                  final isDone = stepNum < currentStep;
                  final isActive = stepNum == currentStep;
                  final isCancelledStep = _stages[idx] == 'Cancelled';
                  
                  Color cardBg = AppColors.surfaceGray;
                  Color borderColor = AppColors.borderGray;
                  Color contentColor = AppColors.textLightGray;
                  IconData stateIcon = Icons.lock_outline;
                  
                  if (isCancelledStep && isActive) {
                    cardBg = Colors.red.withValues(alpha: 0.08);
                    borderColor = Colors.red;
                    contentColor = Colors.red;
                    stateIcon = Icons.cancel;
                  } else if (isDone) {
                    cardBg = Colors.green.withValues(alpha: 0.08);
                    borderColor = Colors.green.withValues(alpha: 0.3);
                    contentColor = Colors.green;
                    stateIcon = Icons.check_circle;
                  } else if (isActive) {
                    cardBg = AppColors.primarySolarOrange.withValues(alpha: 0.12);
                    borderColor = AppColors.primarySolarOrange;
                    contentColor = AppColors.primarySolarOrange;
                    stateIcon = Icons.play_circle_filled;
                  }

                  return GestureDetector(
                    onTap: () => _updateInstallationStep(stepNum),
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 120,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(14),
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
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: contentColor,
                                ),
                              ),
                              Icon(stateIcon, size: 14, color: contentColor),
                            ],
                          ),
                          Text(
                            translator.translate('step_$stepNum'),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: isActive || isDone ? FontWeight.bold : FontWeight.normal,
                              color: isActive || isDone ? AppColors.textDarkGray : AppColors.textLightGray,
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
}

// Canvas Painting Dialog for Signature drawing
class SignatureDialog extends StatefulWidget {
  const SignatureDialog({super.key});

  @override
  State<SignatureDialog> createState() => _SignatureDialogState();
}

class _SignatureDialogState extends State<SignatureDialog> {
  final List<Offset> _points = [];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Draw Customer Signature'),
      content: Container(
        width: 300,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.borderGray, width: 2),
        ),
        child: GestureDetector(
          onPanUpdate: (details) {
            RenderBox referenceBox = context.findRenderObject() as RenderBox;
            Offset localPosition = referenceBox.globalToLocal(details.globalPosition);
            // Adjust offsets relative to dialog content
            setState(() {
              _points.add(localPosition - const Offset(24, 60)); // Offset alignment adjustment
            });
          },
          onPanEnd: (details) => _points.add(Offset.infinite),
          child: CustomPaint(
            painter: SignaturePainter(points: _points),
            size: Size.infinite,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            setState(() {
              _points.clear();
            });
          },
          child: const Text('Clear'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(_points),
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset> points;
  SignaturePainter({required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4.0;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != Offset.infinite && points[i + 1] != Offset.infinite) {
        canvas.drawLine(points[i], points[i + 1], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => true;
}
