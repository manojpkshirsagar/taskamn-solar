import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/customer.dart';
import '../models/employee.dart';
import '../models/task.dart';
import '../models/service_request.dart';
import '../models/installation_photos.dart';
import '../models/loan.dart';
import '../models/loan_task.dart';
import '../models/label_category.dart';
import '../models/label.dart';
import '../models/customer_label.dart';
import '../models/import_export_history.dart';
import '../models/sync_queue_item.dart';
import '../models/pending_approval.dart';
import '../models/payment.dart';

class StorageService {
  static const String _keyCustomers = 'siya_solar_customers';
  static const String _keyEmployees = 'siya_solar_employees';
  static const String _keyTasks = 'siya_solar_tasks';
  static const String _keyComplaints = 'siya_solar_complaints';
  static const String _keyPhotos = 'siya_solar_photos';
  static const String _keyCurrentUser = 'siya_solar_current_user';
  static const String _keyLoans = 'siya_solar_loans';
  static const String _keyLoanTasks = 'siya_solar_loan_tasks';
  static const String _keyLabelCategories = 'siya_solar_label_categories';
  static const String _keyLabels = 'siya_solar_labels';
  static const String _keyCustomerLabels = 'siya_solar_customer_labels';
  static const String _keyDeletedCustomers = 'deleted_customers';
  static const String _keyImportHistory = 'siya_solar_import_history';
  static const String _keyExportHistory = 'siya_solar_export_history';
  static const String _keySyncQueue = 'siya_solar_sync_queue';
  static const String _keyPendingApprovals = 'siya_solar_pending_approvals';
  static const String _keyPayments = 'siya_solar_payments';

  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _seedInitialData();
  }

  // Check if initial seeding is needed
  static void _seedInitialData() {
    if (_prefs == null) return;
    
    // Seed default employees if empty
    if (!_prefs!.containsKey(_keyEmployees)) {
      final defaultEmployees = [
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'name': 'Admin User',
          'mobile_number': '9876543210',
          'designation': 'Solar Manager',
          'role': 'admin',
          'employee_code': 'EMP-000001',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': '22222222-2222-2222-2222-222222222222',
          'name': 'Rohan Shinde',
          'mobile_number': '8888888888',
          'designation': 'Field Technician',
          'role': 'employee',
          'employee_code': 'EMP-000002',
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
      _prefs!.setString(_keyEmployees, jsonEncode(defaultEmployees));
    }

    // Seed default customers if empty
    if (!_prefs!.containsKey(_keyCustomers)) {
      final defaultCustomers = [
        {
          'id': 'c1-uuid',
          'name': 'Sanjay Patil',
          'mobile_number': '9422001122',
          'email_address': 'sanjay.patil@example.com',
          'address': '123 Solar Street, Kolhapur',
          'consumer_number': '123456789012',
          'solar_capacity': 5.0,
          'stage': 'Quotation',
          'installation_stage': 2,
          'customer_code': 'CUS-000001',
          'lead_code': 'LED-000001',
          'quotation_code': 'QTN-000001',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'c2-uuid',
          'name': 'Amit Deshmukh',
          'mobile_number': '9890223344',
          'email_address': 'amit.deshmukh@example.com',
          'address': '456 Green Road, Satara',
          'consumer_number': '987654321098',
          'solar_capacity': 8.0,
          'stage': 'Installation',
          'installation_stage': 6,
          'customer_code': 'CUS-000002',
          'lead_code': 'LED-000002',
          'installation_code': 'INS-000001',
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
      _prefs!.setString(_keyCustomers, jsonEncode(defaultCustomers));
    }

    // Seed default tasks if empty
    if (!_prefs!.containsKey(_keyTasks)) {
      final defaultTasks = [
        {
          'id': 't1-uuid',
          'customer_id': 'c1-uuid',
          'task_type': 'Quotation Follow-up',
          'assigned_employee_id': '22222222-2222-2222-2222-222222222222',
          'due_date': DateTime.now().add(const Duration(days: 2)).toIso8601String().split('T')[0],
          'priority': 'Medium',
          'remarks': 'Need to close quotation approval by this weekend.',
          'status': 'Pending',
          'task_code': 'TSK-000001',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 't2-uuid',
          'customer_id': 'c2-uuid',
          'task_type': 'Installation',
          'assigned_employee_id': '22222222-2222-2222-2222-222222222222',
          'due_date': DateTime.now().add(const Duration(days: 1)).toIso8601String().split('T')[0],
          'priority': 'High',
          'remarks': 'Structure material delivered. Start installation.',
          'status': 'In Progress',
          'task_code': 'TSK-000002',
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
      _prefs!.setString(_keyTasks, jsonEncode(defaultTasks));
    }

    // Seed photos placeholder
    if (!_prefs!.containsKey(_keyPhotos)) {
      final defaultPhotos = [
        {
          'id': 'p1-uuid',
          'customer_id': 'c2-uuid',
          'roof_photo_url': null,
          'installation_photo_url': null,
          'inverter_photo_url': null,
          'meter_photo_url': null,
          'customer_signature_url': null,
          'updated_at': DateTime.now().toIso8601String(),
        }
      ];
      _prefs!.setString(_keyPhotos, jsonEncode(defaultPhotos));
    }

    // Seed demo loans if empty
    if (!_prefs!.containsKey(_keyLoans)) {
      final defaultLoans = [
        {
          'id': 'loan1-uuid',
          'customer_id': 'c1-uuid',
          'loan_amount': 100000.0,
          'bank_name': 'SBI',
          'system_capacity': '3 kW',
          'status': 'Loan Application',
          'assigned_employee_id': '22222222-2222-2222-2222-222222222222',
          'remarks': 'Aadhaar and PAN collected, passbook pending.',
          'loan_code': 'LON-000001',
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': 'loan2-uuid',
          'customer_id': 'c2-uuid',
          'loan_amount': 150000.0,
          'bank_name': 'Union Bank',
          'system_capacity': '5 kW',
          'status': 'File at Bank',
          'assigned_employee_id': '22222222-2222-2222-2222-222222222222',
          'remarks': 'All documents submitted. Awaiting bank verification.',
          'loan_code': 'LON-000002',
          'created_at': DateTime.now().toIso8601String(),
        }
      ];
      _prefs!.setString(_keyLoans, jsonEncode(defaultLoans));
    }

    // Seed demo loan tasks if empty
    if (!_prefs!.containsKey(_keyLoanTasks)) {
      final defaultLoanTasks = [
        // Loan 1 tasks
        {'id': 'lt1-1', 'loan_id': 'loan1-uuid', 'task_type': 'Collect Aadhaar', 'is_completed': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt1-2', 'loan_id': 'loan1-uuid', 'task_type': 'Collect PAN', 'is_completed': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt1-3', 'loan_id': 'loan1-uuid', 'task_type': 'Collect Light Bill', 'is_completed': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt1-4', 'loan_id': 'loan1-uuid', 'task_type': 'Collect Passbook', 'is_completed': false, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt1-5', 'loan_id': 'loan1-uuid', 'task_type': 'Loan Application', 'is_completed': false, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt1-6', 'loan_id': 'loan1-uuid', 'task_type': 'Bank Follow-up', 'is_completed': false, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt1-7', 'loan_id': 'loan1-uuid', 'task_type': 'Approval Follow-up', 'is_completed': false, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt1-8', 'loan_id': 'loan1-uuid', 'task_type': 'Disbursement Follow-up', 'is_completed': false, 'created_at': DateTime.now().toIso8601String()},
        // Loan 2 tasks
        {'id': 'lt2-1', 'loan_id': 'loan2-uuid', 'task_type': 'Collect Aadhaar', 'is_completed': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt2-2', 'loan_id': 'loan2-uuid', 'task_type': 'Collect PAN', 'is_completed': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt2-3', 'loan_id': 'loan2-uuid', 'task_type': 'Collect Light Bill', 'is_completed': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt2-4', 'loan_id': 'loan2-uuid', 'task_type': 'Collect Passbook', 'is_completed': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt2-5', 'loan_id': 'loan2-uuid', 'task_type': 'Loan Application', 'is_completed': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt2-6', 'loan_id': 'loan2-uuid', 'task_type': 'Bank Follow-up', 'is_completed': false, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt2-7', 'loan_id': 'loan2-uuid', 'task_type': 'Approval Follow-up', 'is_completed': false, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'lt2-8', 'loan_id': 'loan2-uuid', 'task_type': 'Disbursement Follow-up', 'is_completed': false, 'created_at': DateTime.now().toIso8601String()},
      ];
      _prefs!.setString(_keyLoanTasks, jsonEncode(defaultLoanTasks));
    }

    // Seed default label categories if empty
    if (!_prefs!.containsKey(_keyLabelCategories)) {
      final defaultCategories = [
        {'id': 'c-installation', 'category_name': 'Installation', 'created_at': DateTime.now().toIso8601String()},
        {'id': 'c-documentation', 'category_name': 'Documentation', 'created_at': DateTime.now().toIso8601String()},
        {'id': 'c-netmeter', 'category_name': 'Net Meter', 'created_at': DateTime.now().toIso8601String()},
        {'id': 'c-subsidy', 'category_name': 'Subsidy', 'created_at': DateTime.now().toIso8601String()},
        {'id': 'c-loan', 'category_name': 'Loan', 'created_at': DateTime.now().toIso8601String()},
        {'id': 'c-payment', 'category_name': 'Payment', 'created_at': DateTime.now().toIso8601String()},
        {'id': 'c-service', 'category_name': 'Service', 'created_at': DateTime.now().toIso8601String()}
      ];
      _prefs!.setString(_keyLabelCategories, jsonEncode(defaultCategories));
    }

    // Seed default labels if empty
    if (!_prefs!.containsKey(_keyLabels)) {
      final defaultLabels = [
        {'id': 'l-inst-1', 'category_id': 'c-installation', 'label_name': 'Structure Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-2', 'category_id': 'c-installation', 'label_name': 'Structure Installed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-3', 'category_id': 'c-installation', 'label_name': 'Panel Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-4', 'category_id': 'c-installation', 'label_name': 'Panel Installed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-5', 'category_id': 'c-installation', 'label_name': 'Inverter Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-6', 'category_id': 'c-installation', 'label_name': 'Inverter Installed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-7', 'category_id': 'c-installation', 'label_name': 'Wiring Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-8', 'category_id': 'c-installation', 'label_name': 'Wiring Completed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-9', 'category_id': 'c-installation', 'label_name': 'Earthing Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-10', 'category_id': 'c-installation', 'label_name': 'Earthing Completed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-11', 'category_id': 'c-installation', 'label_name': 'ACDB Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-12', 'category_id': 'c-installation', 'label_name': 'ACDB Installed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-13', 'category_id': 'c-installation', 'label_name': 'DCDB Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-14', 'category_id': 'c-installation', 'label_name': 'DCDB Installed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-15', 'category_id': 'c-installation', 'label_name': 'Testing Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-inst-16', 'category_id': 'c-installation', 'label_name': 'Testing Completed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},

        {'id': 'l-doc-1', 'category_id': 'c-documentation', 'label_name': 'Aadhaar Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-doc-2', 'category_id': 'c-documentation', 'label_name': 'PAN Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-doc-3', 'category_id': 'c-documentation', 'label_name': 'Light Bill Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-doc-4', 'category_id': 'c-documentation', 'label_name': 'Bank Passbook Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-doc-5', 'category_id': 'c-documentation', 'label_name': 'Customer Photo Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-doc-6', 'category_id': 'c-documentation', 'label_name': 'Documents Complete', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},

        {'id': 'l-net-1', 'category_id': 'c-netmeter', 'label_name': 'Net Meter Documents Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-net-2', 'category_id': 'c-netmeter', 'label_name': 'Application Submitted', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-net-3', 'category_id': 'c-netmeter', 'label_name': 'Inspection Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-net-4', 'category_id': 'c-netmeter', 'label_name': 'Meter Installation Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-net-5', 'category_id': 'c-netmeter', 'label_name': 'Net Meter Installed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},

        {'id': 'l-sub-1', 'category_id': 'c-subsidy', 'label_name': 'Subsidy Documents Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-sub-2', 'category_id': 'c-subsidy', 'label_name': 'Subsidy Applied', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-sub-3', 'category_id': 'c-subsidy', 'label_name': 'Verification Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-sub-4', 'category_id': 'c-subsidy', 'label_name': 'Subsidy Received', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},

        {'id': 'l-loan-1', 'category_id': 'c-loan', 'label_name': 'Loan Interested', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-loan-2', 'category_id': 'c-loan', 'label_name': 'Loan Documents Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-loan-3', 'category_id': 'c-loan', 'label_name': 'Documents Submitted', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-loan-4', 'category_id': 'c-loan', 'label_name': 'CIBIL Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-loan-5', 'category_id': 'c-loan', 'label_name': 'Loan Under Process', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-loan-6', 'category_id': 'c-loan', 'label_name': 'Loan Approved', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-loan-7', 'category_id': 'c-loan', 'label_name': 'Loan Rejected', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-loan-8', 'category_id': 'c-loan', 'label_name': 'Loan Disbursed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},

        {'id': 'l-pay-1', 'category_id': 'c-payment', 'label_name': 'Advance Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-pay-2', 'category_id': 'c-payment', 'label_name': 'Advance Received', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-pay-3', 'category_id': 'c-payment', 'label_name': 'Material Payment Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-pay-4', 'category_id': 'c-payment', 'label_name': 'Final Payment Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-pay-5', 'category_id': 'c-payment', 'label_name': 'Payment Complete', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},

        {'id': 'l-srv-1', 'category_id': 'c-service', 'label_name': 'Service Request Open', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-srv-2', 'category_id': 'c-service', 'label_name': 'Technician Assigned', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-srv-3', 'category_id': 'c-service', 'label_name': 'Service Pending', 'is_active': true, 'created_at': DateTime.now().toIso8601String()},
        {'id': 'l-srv-4', 'category_id': 'c-service', 'label_name': 'Service Completed', 'is_active': true, 'created_at': DateTime.now().toIso8601String()}
      ];
      _prefs!.setString(_keyLabels, jsonEncode(defaultLabels));
    }

    // Seed default customer labels mapping if empty
    if (!_prefs!.containsKey(_keyCustomerLabels)) {
      _prefs!.setString(_keyCustomerLabels, jsonEncode([]));
    }
  }

  // --- Auth Session Cache ---
  static Future<void> saveCurrentUser(Employee employee) async {
    await _prefs?.setString(_keyCurrentUser, jsonEncode(employee.toJson()));
  }

  static Employee? getCurrentUser() {
    final raw = _prefs?.getString(_keyCurrentUser);
    if (raw == null) return null;
    try {
      return Employee.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearCurrentUser() async {
    await _prefs?.remove(_keyCurrentUser);
  }

  // --- Customers CRUD ---
  static List<Customer> getCustomers() {
    final raw = _prefs?.getString(_keyCustomers);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => Customer.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Customer> saveCustomer(Customer customer) async {
    final list = getCustomers();
    final index = list.indexWhere((c) => c.id == customer.id);
    
    // Auto-generate codes if they are missing
    String? custCode = customer.customerCode;
    String? leadCode = customer.leadCode;
    String? instCode = customer.installationCode;
    String? qtnCode = customer.quotationCode;
    String? nmtCode = customer.netMeterCode;
    String? subCode = customer.subsidyCode;
    String? payCode = customer.paymentCode;

    if (custCode == null) {
      custCode = 'CUS-${(list.length + 1).toString().padLeft(6, '0')}';
    }
    if (leadCode == null) {
      leadCode = 'LED-${(list.length + 1).toString().padLeft(6, '0')}';
    }
    
    if (customer.stage == 'Quotation' && qtnCode == null) {
      qtnCode = 'QTN-${(list.where((c) => c.quotationCode != null).length + 1).toString().padLeft(6, '0')}';
    }
    if (customer.stage == 'Installation' && instCode == null) {
      instCode = 'INS-${(list.where((c) => c.installationCode != null).length + 1).toString().padLeft(6, '0')}';
    }
    if (customer.stage == 'Net Meter' && nmtCode == null) {
      nmtCode = 'NMT-${(list.where((c) => c.netMeterCode != null).length + 1).toString().padLeft(6, '0')}';
    }
    if (customer.stage == 'Subsidy Pending' && subCode == null) {
      subCode = 'SUB-${(list.where((c) => c.subsidyCode != null).length + 1).toString().padLeft(6, '0')}';
    }
    if (customer.paymentMode != 'Not Selected' && payCode == null) {
      payCode = 'PAY-${(list.where((c) => c.paymentCode != null).length + 1).toString().padLeft(6, '0')}';
    }

    final updated = Customer(
      id: customer.id,
      name: customer.name,
      mobileNumber: customer.mobileNumber,
      emailAddress: customer.emailAddress,
      address: customer.address,
      consumerNumber: customer.consumerNumber,
      solarCapacity: customer.solarCapacity,
      stage: customer.stage,
      installationStage: customer.installationStage,
      paymentMode: customer.paymentMode,
      createdAt: customer.createdAt,
      customerCode: custCode,
      leadCode: leadCode,
      installationCode: instCode,
      netMeterCode: nmtCode,
      subsidyCode: subCode,
      quotationCode: qtnCode,
      paymentCode: payCode,
    );

    if (index >= 0) {
      list[index] = updated;
    } else {
      list.add(updated);
    }
    await _prefs?.setString(_keyCustomers, jsonEncode(list.map((c) => c.toJson()).toList()));
    return updated;
  }

  static Future<void> deleteCustomer(String id) async {
    final list = getCustomers();
    list.removeWhere((c) => c.id == id);
    await _prefs?.setString(_keyCustomers, jsonEncode(list.map((c) => c.toJson()).toList()));
    await addDeletedCustomerId(id);

    // Cascade delete related records from mock storage
    // 1. Tasks
    final tasksRaw = _prefs?.getString(_keyTasks);
    if (tasksRaw != null) {
      try {
        final tasksList = jsonDecode(tasksRaw) as List;
        tasksList.removeWhere((t) => (t as Map)['customer_id'] == id);
        await _prefs?.setString(_keyTasks, jsonEncode(tasksList));
      } catch (_) {}
    }

    // 2. Loans (and loan tasks)
    final loansRaw = _prefs?.getString(_keyLoans);
    if (loansRaw != null) {
      try {
        final loansList = jsonDecode(loansRaw) as List;
        final loanIdsToDelete = loansList
            .where((l) => (l as Map)['customer_id'] == id)
            .map((l) => (l as Map)['id'] as String)
            .toList();
        
        loansList.removeWhere((l) => (l as Map)['customer_id'] == id);
        await _prefs?.setString(_keyLoans, jsonEncode(loansList));

        // Delete loan tasks
        final loanTasksRaw = _prefs?.getString(_keyLoanTasks);
        if (loanTasksRaw != null) {
          final loanTasksList = jsonDecode(loanTasksRaw) as List;
          loanTasksList.removeWhere((lt) => loanIdsToDelete.contains((lt as Map)['loan_id']));
          await _prefs?.setString(_keyLoanTasks, jsonEncode(loanTasksList));
        }
      } catch (_) {}
    }

    // 3. Complaints (service requests)
    final complaintsRaw = _prefs?.getString(_keyComplaints);
    if (complaintsRaw != null) {
      try {
        final complaintsList = jsonDecode(complaintsRaw) as List;
        complaintsList.removeWhere((c) => (c as Map)['customer_id'] == id);
        await _prefs?.setString(_keyComplaints, jsonEncode(complaintsList));
      } catch (_) {}
    }

    // 4. Photos
    final photosRaw = _prefs?.getString(_keyPhotos);
    if (photosRaw != null) {
      try {
        final photosList = jsonDecode(photosRaw) as List;
        photosList.removeWhere((p) => (p as Map)['customer_id'] == id);
        await _prefs?.setString(_keyPhotos, jsonEncode(photosList));
      } catch (_) {}
    }

    // 5. Customer Labels
    final customerLabelsRaw = _prefs?.getString(_keyCustomerLabels);
    if (customerLabelsRaw != null) {
      try {
        final clList = jsonDecode(customerLabelsRaw) as List;
        clList.removeWhere((cl) => (cl as Map)['customer_id'] == id);
        await _prefs?.setString(_keyCustomerLabels, jsonEncode(clList));
      } catch (_) {}
    }
  }

  static List<String> getDeletedCustomerIds() {
    return _prefs?.getStringList(_keyDeletedCustomers) ?? [];
  }

  static Future<void> addDeletedCustomerId(String id) async {
    final list = getDeletedCustomerIds();
    if (!list.contains(id)) {
      list.add(id);
      await _prefs?.setStringList(_keyDeletedCustomers, list);
    }
  }

  // --- Employees CRUD ---
  static List<Employee> getEmployees() {
    final raw = _prefs?.getString(_keyEmployees);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => Employee.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Employee> saveEmployee(Employee employee) async {
    final list = getEmployees();
    final index = list.indexWhere((e) => e.id == employee.id);
    
    String? code = employee.employeeCode;
    if (code == null) {
      code = 'EMP-${(list.length + 1).toString().padLeft(6, '0')}';
    }

    final updated = Employee(
      id: employee.id,
      name: employee.name,
      mobileNumber: employee.mobileNumber,
      designation: employee.designation,
      role: employee.role,
      createdAt: employee.createdAt,
      employeeCode: code,
    );

    if (index >= 0) {
      list[index] = updated;
    } else {
      list.add(updated);
    }
    await _prefs?.setString(_keyEmployees, jsonEncode(list.map((e) => e.toJson()).toList()));
    return updated;
  }

  // --- Tasks CRUD ---
  static List<Task> getTasks() {
    final raw = _prefs?.getString(_keyTasks);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => Task.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Task> saveTask(Task task) async {
    final list = getTasks();
    final index = list.indexWhere((t) => t.id == task.id);
    
    String? code = task.taskCode;
    if (code == null) {
      code = 'TSK-${(list.length + 1).toString().padLeft(6, '0')}';
    }

    final updated = Task(
      id: task.id,
      customerId: task.customerId,
      taskType: task.taskType,
      assignedEmployeeId: task.assignedEmployeeId,
      dueDate: task.dueDate,
      priority: task.priority,
      remarks: task.remarks,
      status: task.status,
      createdAt: task.createdAt,
      taskCode: code,
    );

    if (index >= 0) {
      list[index] = updated;
    } else {
      list.add(updated);
    }
    await _prefs?.setString(_keyTasks, jsonEncode(list.map((t) => t.toJson()).toList()));
    return updated;
  }

  // --- Service complaints ---
  static List<ServiceRequest> getServiceRequests() {
    final raw = _prefs?.getString(_keyComplaints);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => ServiceRequest.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<ServiceRequest> saveServiceRequest(ServiceRequest request) async {
    final list = getServiceRequests();
    final index = list.indexWhere((r) => r.id == request.id);
    
    String? code = request.serviceRequestCode;
    if (code == null) {
      code = 'SRV-${(list.length + 1).toString().padLeft(6, '0')}';
    }

    final updated = ServiceRequest(
      id: request.id,
      customerId: request.customerId,
      mobileNumber: request.mobileNumber,
      complaintType: request.complaintType,
      description: request.description,
      photoUrl: request.photoUrl,
      status: request.status,
      createdAt: request.createdAt,
      serviceRequestCode: code,
    );

    if (index >= 0) {
      list[index] = updated;
    } else {
      list.add(updated);
    }
    await _prefs?.setString(_keyComplaints, jsonEncode(list.map((r) => r.toJson()).toList()));
    return updated;
  }

  // --- Installation Photos CRUD ---
  static List<InstallationPhotos> getInstallationPhotos() {
    final raw = _prefs?.getString(_keyPhotos);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => InstallationPhotos.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveInstallationPhotos(InstallationPhotos photoRecord) async {
    final list = getInstallationPhotos();
    final index = list.indexWhere((p) => p.customerId == photoRecord.customerId);
    if (index >= 0) {
      list[index] = photoRecord;
    } else {
      list.add(photoRecord);
    }
    await _prefs?.setString(_keyPhotos, jsonEncode(list.map((p) => p.toJson()).toList()));
  }

  // --- Loans CRUD ---
  static List<Loan> getLoans() {
    final raw = _prefs?.getString(_keyLoans);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => Loan.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<Loan> saveLoan(Loan loan) async {
    final list = getLoans();
    final index = list.indexWhere((l) => l.id == loan.id);
    
    String? code = loan.loanCode;
    if (code == null) {
      code = 'LON-${(list.length + 1).toString().padLeft(6, '0')}';
    }

    final updated = Loan(
      id: loan.id,
      customerId: loan.customerId,
      loanAmount: loan.loanAmount,
      bankName: loan.bankName,
      branch: loan.branch,
      status: loan.status,
      assignedEmployeeId: loan.assignedEmployeeId,
      remarks: loan.remarks,
      createdAt: loan.createdAt,
      loanCode: code,
    );

    if (index >= 0) {
      list[index] = updated;
    } else {
      list.add(updated);
    }
    await _prefs?.setString(_keyLoans, jsonEncode(list.map((l) => l.toJson()).toList()));
    return updated;
  }

  // --- Loan Tasks CRUD ---
  static List<LoanTask> getLoanTasks() {
    final raw = _prefs?.getString(_keyLoanTasks);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => LoanTask.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<LoanTask> getLoanTasksForLoan(String loanId) {
    return getLoanTasks().where((t) => t.loanId == loanId).toList();
  }

  static Future<void> saveLoanTask(LoanTask task) async {
    final list = getLoanTasks();
    final index = list.indexWhere((t) => t.id == task.id);
    if (index >= 0) {
      list[index] = task;
    } else {
      list.add(task);
    }
    await _prefs?.setString(_keyLoanTasks, jsonEncode(list.map((t) => t.toJson()).toList()));
  }

  // --- Labels, Categories & CustomerLabels CRUD ---
  static List<LabelCategory> getLabelCategories() {
    final raw = _prefs?.getString(_keyLabelCategories);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => LabelCategory.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLabelCategory(LabelCategory category) async {
    final list = getLabelCategories();
    final index = list.indexWhere((c) => c.id == category.id);
    if (index >= 0) {
      list[index] = category;
    } else {
      list.add(category);
    }
    await _prefs?.setString(_keyLabelCategories, jsonEncode(list.map((c) => c.toJson()).toList()));
  }

  static Future<void> deleteLabelCategory(String categoryId) async {
    final list = getLabelCategories();
    list.removeWhere((c) => c.id == categoryId);
    await _prefs?.setString(_keyLabelCategories, jsonEncode(list.map((c) => c.toJson()).toList()));

    final labelsList = getLabels();
    labelsList.removeWhere((l) => l.categoryId == categoryId);
    await _prefs?.setString(_keyLabels, jsonEncode(labelsList.map((l) => l.toJson()).toList()));
  }

  static List<Label> getLabels() {
    final raw = _prefs?.getString(_keyLabels);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => Label.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveLabel(Label label) async {
    final list = getLabels();
    final index = list.indexWhere((l) => l.id == label.id);
    if (index >= 0) {
      list[index] = label;
    } else {
      list.add(label);
    }
    await _prefs?.setString(_keyLabels, jsonEncode(list.map((l) => l.toJson()).toList()));
  }

  static List<CustomerLabel> getCustomerLabels() {
    final raw = _prefs?.getString(_keyCustomerLabels);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => CustomerLabel.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<CustomerLabel> getCustomerLabelsForCustomer(String customerId) {
    return getCustomerLabels().where((cl) => cl.customerId == customerId).toList();
  }

  static Future<void> saveCustomerLabelsForCustomer(String customerId, List<String> labelIds) async {
    final allCustomerLabels = getCustomerLabels();
    // Remove existing ones for this customer
    allCustomerLabels.removeWhere((cl) => cl.customerId == customerId);
    // Add new ones
    for (final lid in labelIds) {
      allCustomerLabels.add(CustomerLabel(
        id: '${customerId}_$lid',
        customerId: customerId,
        labelId: lid,
        createdAt: DateTime.now(),
      ));
    }
    await _prefs?.setString(_keyCustomerLabels, jsonEncode(allCustomerLabels.map((cl) => cl.toJson()).toList()));
  }

  // --- Import/Export History CRUD ---
  static List<ImportHistory> getImportHistory() {
    final raw = _prefs?.getString(_keyImportHistory);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => ImportHistory.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveImportHistory(ImportHistory record) async {
    final list = getImportHistory();
    list.insert(0, record); // Insert at top for chronologically descending order
    await _prefs?.setString(_keyImportHistory, jsonEncode(list.map((h) => h.toJson()).toList()));
  }

  static List<ExportHistory> getExportHistory() {
    final raw = _prefs?.getString(_keyExportHistory);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => ExportHistory.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveExportHistory(ExportHistory record) async {
    final list = getExportHistory();
    list.insert(0, record); // Insert at top
    await _prefs?.setString(_keyExportHistory, jsonEncode(list.map((h) => h.toJson()).toList()));
  }

  // --- Sync Queue CRUD ---
  static List<SyncQueueItem> getSyncQueue() {
    final raw = _prefs?.getString(_keySyncQueue);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => SyncQueueItem.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<SyncQueueItem> getPendingSyncItems() {
    return getSyncQueue().where((i) => i.syncStatus == 'Pending' || i.syncStatus == 'Failed').toList();
  }

  static int getPendingSyncCount() {
    return getPendingSyncItems().length;
  }

  static Future<void> saveSyncQueueItem(SyncQueueItem item) async {
    final list = getSyncQueue();
    final index = list.indexWhere((i) => i.id == item.id);
    if (index >= 0) {
      list[index] = item;
    } else {
      list.insert(0, item);
    }
    await _prefs?.setString(_keySyncQueue, jsonEncode(list.map((i) => i.toJson()).toList()));
  }

  static Future<void> updateSyncItemStatus(String id, String status, {String? errorMessage}) async {
    final list = getSyncQueue();
    final index = list.indexWhere((i) => i.id == id);
    if (index >= 0) {
      list[index] = list[index].copyWith(syncStatus: status, errorMessage: errorMessage);
      await _prefs?.setString(_keySyncQueue, jsonEncode(list.map((i) => i.toJson()).toList()));
    }
  }

  static Future<void> clearSuccessfulSyncItems() async {
    final list = getSyncQueue();
    list.removeWhere((i) => i.syncStatus == 'Success');
    await _prefs?.setString(_keySyncQueue, jsonEncode(list.map((i) => i.toJson()).toList()));
  }

  // --- Pending Approvals CRUD ---
  static List<PendingApproval> getPendingApprovals() {
    final raw = _prefs?.getString(_keyPendingApprovals);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => PendingApproval.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<PendingApproval> getPendingApprovalsByStatus(String status) {
    return getPendingApprovals().where((a) => a.status == status).toList();
  }

  static List<PendingApproval> getApprovalsByEmployee(String employeeId) {
    return getPendingApprovals().where((a) => a.employeeId == employeeId).toList();
  }

  static int getPendingApprovalCount() {
    return getPendingApprovals().where((a) => a.status == 'Pending').length;
  }

  static Future<void> savePendingApproval(PendingApproval approval) async {
    final list = getPendingApprovals();
    final index = list.indexWhere((a) => a.id == approval.id);
    if (index >= 0) {
      list[index] = approval;
    } else {
      list.insert(0, approval);
    }
    await _prefs?.setString(_keyPendingApprovals, jsonEncode(list.map((a) => a.toJson()).toList()));
  }

  static Future<void> updateApprovalStatus(
    String id,
    String status, {
    String? rejectionReason,
    String? approvedBy,
    DateTime? approvedAt,
  }) async {
    final list = getPendingApprovals();
    final index = list.indexWhere((a) => a.id == id);
    if (index >= 0) {
      list[index] = list[index].copyWith(
        status: status,
        rejectionReason: rejectionReason,
        approvedBy: approvedBy,
        approvedAt: approvedAt ?? DateTime.now(),
      );
      await _prefs?.setString(_keyPendingApprovals, jsonEncode(list.map((a) => a.toJson()).toList()));
    }
  }

  // --- Payments CRUD ---
  static List<Payment> getPayments() {
    final raw = _prefs?.getString(_keyPayments);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((item) => Payment.fromJson(item as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  static List<Payment> getPaymentsForCustomer(String customerId) {
    return getPayments().where((p) => p.customerId == customerId).toList();
  }

  static Future<Payment> savePayment(Payment payment) async {
    final list = getPayments();
    final index = list.indexWhere((p) => p.id == payment.id);

    String? code = payment.paymentCode;
    if (code == null) {
      code = 'PAY-${(list.length + 1).toString().padLeft(6, '0')}';
    }

    final updated = Payment(
      id: payment.id,
      customerId: payment.customerId,
      amount: payment.amount,
      paymentMode: payment.paymentMode,
      paymentDate: payment.paymentDate,
      receiptNumber: payment.receiptNumber,
      remarks: payment.remarks,
      paymentCode: code,
      createdAt: payment.createdAt ?? DateTime.now(),
    );

    if (index >= 0) {
      list[index] = updated;
    } else {
      list.insert(0, updated);
    }
    await _prefs?.setString(_keyPayments, jsonEncode(list.map((p) => p.toJson()).toList()));
    return updated;
  }

  static Future<void> deletePayment(String id) async {
    final list = getPayments();
    list.removeWhere((p) => p.id == id);
    await _prefs?.setString(_keyPayments, jsonEncode(list.map((p) => p.toJson()).toList()));
  }
}
