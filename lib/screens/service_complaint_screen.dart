import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../l10n/translation_provider.dart';
import '../services/supabase_service.dart';
import '../constants/colors.dart';
import '../models/customer.dart';
import '../models/service_request.dart';

class ServiceComplaintScreen extends StatefulWidget {
  final Customer customer;

  const ServiceComplaintScreen({super.key, required this.customer});

  @override
  State<ServiceComplaintScreen> createState() => _ServiceComplaintScreenState();
}

class _ServiceComplaintScreenState extends State<ServiceComplaintScreen> {
  final _formKey = GlobalKey<FormState>();
  final _complaintTypeController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  File? _selectedPhoto;
  bool _isLoading = false;
  List<ServiceRequest> _existingComplaints = [];

  @override
  void initState() {
    super.initState();
    _loadComplaints();
  }

  @override
  void dispose() {
    _complaintTypeController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadComplaints() async {
    final all = await SupabaseService.instance.fetchServiceRequests();
    if (mounted) {
      setState(() {
        _existingComplaints = all.where((r) => r.customerId == widget.customer.id).toList();
      });
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (pickedFile != null) {
      setState(() {
        _selectedPhoto = File(pickedFile.path);
      });
    }
  }

  Future<void> _submitComplaint() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final String complaintId = const Uuid().v4();
    String? photoUrl;

    if (_selectedPhoto != null) {
      photoUrl = await SupabaseService.instance.uploadPhoto(widget.customer.id, _selectedPhoto!, 'complaint');
    }

    final complaint = ServiceRequest(
      id: complaintId,
      customerId: widget.customer.id,
      mobileNumber: widget.customer.mobileNumber,
      complaintType: _complaintTypeController.text.trim(),
      description: _descriptionController.text.trim(),
      photoUrl: photoUrl,
      status: 'Open',
      createdAt: DateTime.now(),
    );

    await SupabaseService.instance.upsertServiceRequest(complaint);
    
    _complaintTypeController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedPhoto = null;
      _isLoading = false;
    });

    await _loadComplaints();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Complaint filed successfully!'), backgroundColor: AppColors.completedColor),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('service')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Complaint Form
            Card(
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        translator.translate('create_complaint'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDarkGray),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _complaintTypeController,
                        decoration: InputDecoration(
                          labelText: translator.translate('complaint_type'),
                          hintText: 'e.g., Inverter Issue, Cable damage',
                        ),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter complaint type' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: InputDecoration(labelText: translator.translate('description')),
                        validator: (val) => val == null || val.trim().isEmpty ? 'Please enter description' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Camera attachment
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedPhoto != null ? 'Photo Attached' : 'Attach Spot Photo',
                              style: TextStyle(
                                color: _selectedPhoto != null ? AppColors.completedColor : AppColors.textLightGray,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.surfaceGray,
                              foregroundColor: AppColors.textDarkGray,
                            ),
                            onPressed: _pickPhoto,
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Camera'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitComplaint,
                        child: _isLoading
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : Text(translator.translate('create_complaint')),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Existing complaints for this customer
            const Text(
              'Complaint History',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDarkGray),
            ),
            const SizedBox(height: 12),
            if (_existingComplaints.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: Text('No complaints registered.'),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _existingComplaints.length,
                itemBuilder: (ctx, idx) {
                  final complaint = _existingComplaints[idx];
                  return Card(
                    child: ListTile(
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(complaint.complaintType, style: const TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          if (complaint.serviceRequestCode != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.blue.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                complaint.serviceRequestCode!,
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(complaint.description),
                          const SizedBox(height: 4),
                          Text('Mobile: ${complaint.mobileNumber}', style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                      trailing: _buildStatusChip(translator, complaint.status),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(TranslationProvider translator, String status) {
    Color color = AppColors.pendingColor;
    if (status == 'Resolved' || status == 'Closed') color = AppColors.completedColor;
    if (status == 'Assigned') color = AppColors.progressColor;

    return Chip(
      backgroundColor: color.withOpacity(0.15),
      label: Text(
        translator.translate(status.toLowerCase()),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}
