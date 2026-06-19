import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';
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
import 'logger_service.dart';
import 'connectivity_service.dart';
import 'package:uuid/uuid.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();

  SupabaseService._internal();

  bool _isMockMode = true;
  bool get isMockMode => _isMockMode;
  bool get _shouldUseLocalData => _isMockMode || !ConnectivityService.instance.isOnline;

  // Change these to your actual Supabase project credentials in production
  static const String supabaseUrl = 'https://gbdllbncblhhrzekhngi.supabase.co';
  static const String supabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiZGxsYm5jYmxoaHJ6ZWtobmdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MDE4MDQsImV4cCI6MjA5NzE3NzgwNH0.U81MRNtb_0mDNKGx0m5QOLUNNlczF9yN3BJu4QQk_vc';

  Future<void> initialize() async {
    if (supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty) {
      try {
        await Supabase.initialize(
          url: supabaseUrl,
          anonKey: supabaseAnonKey,
        );
        _isMockMode = false;
        debugPrint("Supabase initialized successfully.");
      } catch (e) {
        debugPrint("Failed to initialize Supabase, fallback to Mock Mode: $e");
        LoggerService.logError('SupabaseService', 'initialize', e);
        _isMockMode = true;
      }
    } else {
      debugPrint("Supabase credentials empty. Starting in Offline/Mock Mode.");
      _isMockMode = true;
    }
  }

  // --- Auth & Session ---
  Future<Employee?> login(String identifier, String password, String role) async {
    if (_isMockMode) {
      // Offline/Mock Auth logic: match mobile or email
      final employees = StorageService.getEmployees();
      for (final e in employees) {
        if ((e.mobileNumber == identifier || e.id == identifier) && e.role == role) {
          await StorageService.saveCurrentUser(e);
          return e;
        }
      }
      // Demo accounts for easier testing
      if (identifier == 'admin' && role == 'admin') {
        final admin = employees.firstWhere((e) => e.role == 'admin');
        await StorageService.saveCurrentUser(admin);
        return admin;
      } else if (identifier == 'employee' && role == 'employee') {
        final emp = employees.firstWhere((e) => e.role == 'employee');
        await StorageService.saveCurrentUser(emp);
        return emp;
      }
      return null;
    } else {
      try {
        final email = identifier.contains('@') ? identifier : '$identifier@siyasolar.com';
        debugPrint("Supabase Login: attempting auth for $email");
        final response = await Supabase.instance.client.auth.signInWithPassword(
          email: email,
          password: password,
        );
        if (response.user != null) {
          debugPrint("Supabase Login: auth succeeded, user id=${response.user!.id}");
          // Fetch employee record matching the auth user id
          final empData = await Supabase.instance.client
              .from('employees')
              .select()
              .eq('id', response.user!.id)
              .maybeSingle();
          if (empData != null) {
            final employee = Employee.fromJson(empData);
            await StorageService.saveCurrentUser(employee);
            debugPrint("Supabase Login: employee found, role=${employee.role}");
            return employee;
          } else {
            debugPrint("Supabase Login: No employee record found for auth user id=${response.user!.id}");
          }
        } else {
          debugPrint("Supabase Login: auth response had null user");
        }
        return null;
      } catch (e, stack) {
        debugPrint("Supabase Login Error: $e");
        debugPrint("Stacktrace: $stack");
        LoggerService.logError('SupabaseService', 'login', e, stack);
        return null;
      }
    }
  }

  Future<void> logout() async {
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.auth.signOut();
      } catch (_) {}
    }
    await StorageService.clearCurrentUser();
  }

  Employee? get cachedUser => StorageService.getCurrentUser();

  // --- Customers API ---
  Future<List<Customer>> fetchCustomers() async {
    if (_shouldUseLocalData) {
      return StorageService.getCustomers();
    } else {
      try {
        final data = await Supabase.instance.client
            .from('customers')
            .select()
            .order('created_at', ascending: false);
        final list = (data as List).map((x) => Customer.fromJson(x as Map<String, dynamic>)).toList();
        // Check which IDs have been locally deleted so they don't reappear
        // if Supabase RLS blocked the remote delete
        final deletedIds = StorageService.getDeletedCustomerIds().toSet();
        final filteredList = list.where((c) => !deletedIds.contains(c.id)).toList();
        for (var c in filteredList) {
          await StorageService.saveCustomer(c);
        }
        return filteredList;
      } catch (e) {
        debugPrint("Supabase fetchCustomers error, using cache: $e");
        return StorageService.getCustomers();
      }
    }
  }

  Future<Customer> upsertCustomer(Customer customer) async {
    final updated = await StorageService.saveCustomer(customer);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('customers').upsert(updated.toJson());
      } catch (e) {
        debugPrint("Supabase upsertCustomer error: $e");
        LoggerService.logError('SupabaseService', 'upsertCustomer', e);
      }
    }
    return updated;
  }

  Future<bool> deleteCustomer(String id) async {
    await StorageService.deleteCustomer(id);
    if (!_isMockMode) {
      try {
        // Explicitly delete related records first to bypass any missing database-level ON DELETE CASCADE constraints
        // 1. Delete customer labels mapping
        try {
          await Supabase.instance.client.from('customer_labels').delete().eq('customer_id', id);
        } catch (e) {
          debugPrint("Supabase deleteCustomer - customer_labels delete error: $e");
        }
        
        // 2. Delete loan tasks and loans
        try {
          final loansData = await Supabase.instance.client
              .from('loans')
              .select('id')
              .eq('customer_id', id);
          if (loansData is List) {
            for (final loan in loansData) {
              final loanId = (loan as Map)['id'];
              await Supabase.instance.client.from('loan_tasks').delete().eq('loan_id', loanId);
            }
          }
          await Supabase.instance.client.from('loans').delete().eq('customer_id', id);
        } catch (e) {
          debugPrint("Supabase deleteCustomer - loans/loan_tasks delete error: $e");
        }

        // 3. Delete tasks
        try {
          await Supabase.instance.client.from('tasks').delete().eq('customer_id', id);
        } catch (e) {
          debugPrint("Supabase deleteCustomer - tasks delete error: $e");
        }

        // 4. Delete service requests
        try {
          await Supabase.instance.client.from('service_requests').delete().eq('customer_id', id);
        } catch (e) {
          debugPrint("Supabase deleteCustomer - service_requests delete error: $e");
        }

        // 5. Delete installation photos
        try {
          await Supabase.instance.client.from('installation_photos').delete().eq('customer_id', id);
        } catch (e) {
          debugPrint("Supabase deleteCustomer - installation_photos delete error: $e");
        }

        // 6. Delete the customer record from Supabase
        try {
          await Supabase.instance.client.from('customers').delete().eq('id', id);
        } catch (e, stack) {
          // Log but don't rethrow — local cache deletion already succeeded.
          // RLS may block the Supabase delete, but the customer is removed from local cache.
          debugPrint("Supabase deleteCustomer - customer row delete error (RLS?): $e");
          LoggerService.logError('SupabaseService', 'deleteCustomer', e, stack);
        }
      } catch (e, stack) {
        debugPrint("Supabase deleteCustomer outer error: $e");
        LoggerService.logError('SupabaseService', 'deleteCustomer', e, stack);
        // Don't rethrow — local cache deletion already succeeded.
      }
    }
    return true;
  }

  // --- Tasks API ---
  Future<List<Task>> fetchTasks() async {
    if (_shouldUseLocalData) {
      return StorageService.getTasks();
    } else {
      try {
        final data = await Supabase.instance.client
            .from('tasks')
            .select()
            .order('due_date', ascending: true);
        final list = (data as List).map((x) => Task.fromJson(x as Map<String, dynamic>)).toList();
        final deletedIds = StorageService.getDeletedCustomerIds().toSet();
        final filteredList = list.where((t) => !deletedIds.contains(t.customerId)).toList();
        for (var t in filteredList) {
          await StorageService.saveTask(t);
        }
        return filteredList;
      } catch (e) {
        debugPrint("Supabase fetchTasks error, using cache: $e");
        return StorageService.getTasks();
      }
    }
  }

  Future<Task> upsertTask(Task task) async {
    final updated = await StorageService.saveTask(task);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('tasks').upsert(updated.toJson());
      } catch (e) {
        debugPrint("Supabase upsertTask error: $e");
        LoggerService.logError('SupabaseService', 'upsertTask', e);
      }
    }
    return updated;
  }

  // --- Employees API ---
  Future<List<Employee>> fetchEmployees() async {
    if (_shouldUseLocalData) {
      return StorageService.getEmployees();
    } else {
      try {
        final data = await Supabase.instance.client.from('employees').select();
        final list = (data as List).map((x) => Employee.fromJson(x as Map<String, dynamic>)).toList();
        for (var e in list) {
          await StorageService.saveEmployee(e);
        }
        return list;
      } catch (e) {
        debugPrint("Supabase fetchEmployees error, using cache: $e");
        return StorageService.getEmployees();
      }
    }
  }

  Future<Employee> addEmployee(Employee employee) async {
    final updated = await StorageService.saveEmployee(employee);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('employees').insert(updated.toJson());
      } catch (e) {
        debugPrint("Supabase addEmployee error: $e");
      }
    }
    return updated;
  }

  // --- Service Requests ---
  Future<List<ServiceRequest>> fetchServiceRequests() async {
    if (_shouldUseLocalData) {
      return StorageService.getServiceRequests();
    } else {
      try {
        final data = await Supabase.instance.client.from('service_requests').select();
        final list = (data as List).map((x) => ServiceRequest.fromJson(x as Map<String, dynamic>)).toList();
        final deletedIds = StorageService.getDeletedCustomerIds().toSet();
        final filteredList = list.where((s) => !deletedIds.contains(s.customerId)).toList();
        for (var r in filteredList) {
          await StorageService.saveServiceRequest(r);
        }
        return filteredList;
      } catch (e) {
        debugPrint("Supabase fetchServiceRequests error, using cache: $e");
        return StorageService.getServiceRequests();
      }
    }
  }

  Future<ServiceRequest> upsertServiceRequest(ServiceRequest request) async {
    final updated = await StorageService.saveServiceRequest(request);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('service_requests').upsert(updated.toJson());
      } catch (e) {
        debugPrint("Supabase upsertServiceRequest error: $e");
      }
    }
    return updated;
  }

  // --- Installation Photos & Storage ---
  Future<InstallationPhotos?> fetchInstallationPhotos(String customerId) async {
    if (_shouldUseLocalData) {
      final list = StorageService.getInstallationPhotos();
      final idx = list.indexWhere((p) => p.customerId == customerId);
      return idx >= 0 ? list[idx] : null;
    } else {
      try {
        final data = await Supabase.instance.client
            .from('installation_photos')
            .select()
            .eq('customer_id', customerId)
            .maybeSingle();
        if (data != null) {
          final photos = InstallationPhotos.fromJson(data);
          await StorageService.saveInstallationPhotos(photos);
          return photos;
        }
        return null;
      } catch (e) {
        debugPrint("Supabase fetchInstallationPhotos error, using cache: $e");
        final list = StorageService.getInstallationPhotos();
        final idx = list.indexWhere((p) => p.customerId == customerId);
        return idx >= 0 ? list[idx] : null;
      }
    }
  }

  Future<void> savePhotos(InstallationPhotos photoRecord) async {
    await StorageService.saveInstallationPhotos(photoRecord);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('installation_photos').upsert(photoRecord.toJson());
      } catch (e) {
        debugPrint("Supabase savePhotos error: $e");
      }
    }
  }

  Future<String?> uploadPhoto(String customerId, File file, String type) async {
    final fileName = '${customerId}_${type}_${DateTime.now().millisecondsSinceEpoch}.jpg';
    if (_isMockMode) {
      // In mock mode, we just return the local file path as the URL
      return file.path;
    } else {
      try {
        final bucket = Supabase.instance.client.storage.from('installation-photos');
        await bucket.upload(fileName, file);
        final publicUrl = bucket.getPublicUrl(fileName);
        return publicUrl;
      } catch (e) {
        debugPrint("Supabase uploadPhoto error: $e");
        return file.path; // Fallback to local path on upload failure
      }
    }
  }

  // --- Loans API ---
  Future<List<Loan>> fetchLoans() async {
    if (_shouldUseLocalData) {
      return StorageService.getLoans();
    } else {
      try {
        final data = await Supabase.instance.client
            .from('loans')
            .select()
            .order('created_at', ascending: false);
        final list = (data as List).map((x) => Loan.fromJson(x as Map<String, dynamic>)).toList();
        final deletedIds = StorageService.getDeletedCustomerIds().toSet();
        final filteredList = list.where((l) => !deletedIds.contains(l.customerId)).toList();
        for (var l in filteredList) {
          await StorageService.saveLoan(l);
        }
        return filteredList;
      } catch (e) {
        debugPrint("Supabase fetchLoans error, using cache: $e");
        return StorageService.getLoans();
      }
    }
  }

  Future<Loan> upsertLoan(Loan loan) async {
    final updated = await StorageService.saveLoan(loan);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('loans').upsert(updated.toJson());
      } catch (e) {
        debugPrint("Supabase upsertLoan error: $e");
        LoggerService.logError('SupabaseService', 'upsertLoan', e);
      }
    }
    return updated;
  }

  Future<Loan?> fetchLoanById(String id) async {
    if (_shouldUseLocalData) {
      final list = StorageService.getLoans();
      final idx = list.indexWhere((l) => l.id == id);
      return idx >= 0 ? list[idx] : null;
    } else {
      try {
        final data = await Supabase.instance.client
            .from('loans')
            .select()
            .eq('id', id)
            .maybeSingle();
        if (data != null) {
          final loan = Loan.fromJson(data);
          await StorageService.saveLoan(loan);
          return loan;
        }
        return null;
      } catch (e) {
        debugPrint("Supabase fetchLoanById error, using cache: $e");
        final list = StorageService.getLoans();
        final idx = list.indexWhere((l) => l.id == id);
        return idx >= 0 ? list[idx] : null;
      }
    }
  }

  // --- Loan Tasks API ---
  Future<List<LoanTask>> fetchLoanTasks(String loanId) async {
    if (_shouldUseLocalData) {
      return StorageService.getLoanTasksForLoan(loanId);
    } else {
      try {
        final data = await Supabase.instance.client
            .from('loan_tasks')
            .select()
            .eq('loan_id', loanId)
            .order('created_at', ascending: true);
        final list = (data as List).map((x) => LoanTask.fromJson(x as Map<String, dynamic>)).toList();
        // Can't directly filter by customerId here as LoanTask doesn't have it, but the loans themselves are filtered.
        for (var t in list) {
          await StorageService.saveLoanTask(t);
        }
        return list;
      } catch (e) {
        debugPrint("Supabase fetchLoanTasks error, using cache: $e");
        return StorageService.getLoanTasksForLoan(loanId);
      }
    }
  }

  Future<void> upsertLoanTask(LoanTask task) async {
    await StorageService.saveLoanTask(task);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('loan_tasks').upsert(task.toJson());
      } catch (e) {
        debugPrint("Supabase upsertLoanTask error: $e");
      }
    }
  }

  // Auto-generate loan checklist tasks
  static const List<String> defaultLoanTaskTypes = [
    'Collect Aadhaar',
    'Collect PAN',
    'Collect Light Bill',
    'Collect Passbook',
    'Loan Application',
    'Bank Follow-up',
    'Approval Follow-up',
    'Disbursement Follow-up',
  ];

  Future<void> createLoanWithAutoTasks(Loan loan) async {
    await upsertLoan(loan);
    const uuid = Uuid();
    for (final taskType in defaultLoanTaskTypes) {
      final loanTask = LoanTask(
        id: uuid.v4(),
        loanId: loan.id,
        taskType: taskType,
        isCompleted: false,
        createdAt: DateTime.now(),
      );
      await upsertLoanTask(loanTask);
    }
  }

  // --- Labels, Categories & CustomerLabels API ---
  Future<List<LabelCategory>> fetchLabelCategories() async {
    if (_shouldUseLocalData) {
      return StorageService.getLabelCategories();
    } else {
      try {
        final data = await Supabase.instance.client
            .from('label_categories')
            .select()
            .order('category_name', ascending: true);
        final list = (data as List).map((x) => LabelCategory.fromJson(x as Map<String, dynamic>)).toList();
        for (var c in list) {
          await StorageService.saveLabelCategory(c);
        }
        return list;
      } catch (e) {
        debugPrint("Supabase fetchLabelCategories error, using cache: $e");
        return StorageService.getLabelCategories();
      }
    }
  }

  Future<void> createLabelCategory(LabelCategory category) async {
    await StorageService.saveLabelCategory(category);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('label_categories').insert(category.toJson());
      } catch (e) {
        debugPrint("Supabase createLabelCategory error: $e");
      }
    }
  }

  Future<void> deleteLabelCategory(String categoryId) async {
    await StorageService.deleteLabelCategory(categoryId);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('label_categories').delete().eq('id', categoryId);
      } catch (e) {
        debugPrint("Supabase deleteLabelCategory error: $e");
      }
    }
  }

  Future<List<Label>> fetchLabels() async {
    if (_shouldUseLocalData) {
      return StorageService.getLabels();
    } else {
      try {
        final data = await Supabase.instance.client
            .from('labels')
            .select()
            .order('label_name', ascending: true);
        final list = (data as List).map((x) => Label.fromJson(x as Map<String, dynamic>)).toList();
        for (var l in list) {
          await StorageService.saveLabel(l);
        }
        return list;
      } catch (e) {
        debugPrint("Supabase fetchLabels error, using cache: $e");
        return StorageService.getLabels();
      }
    }
  }

  Future<void> upsertLabel(Label label) async {
    await StorageService.saveLabel(label);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('labels').upsert(label.toJson());
      } catch (e) {
        debugPrint("Supabase upsertLabel error: $e");
      }
    }
  }

  Future<List<CustomerLabel>> fetchCustomerLabels(String customerId) async {
    if (_shouldUseLocalData) {
      return StorageService.getCustomerLabelsForCustomer(customerId);
    } else {
      try {
        final data = await Supabase.instance.client
            .from('customer_labels')
            .select()
            .eq('customer_id', customerId);
        final list = (data as List).map((x) => CustomerLabel.fromJson(x as Map<String, dynamic>)).toList();
        
        final allLocal = StorageService.getCustomerLabels();
        allLocal.removeWhere((cl) => cl.customerId == customerId);
        allLocal.addAll(list);
        await StorageService.saveCustomerLabelsForCustomer(customerId, list.map((cl) => cl.labelId).toList());
        return list;
      } catch (e) {
        debugPrint("Supabase fetchCustomerLabels error, using cache: $e");
        return StorageService.getCustomerLabelsForCustomer(customerId);
      }
    }
  }

  Future<void> assignLabelsToCustomer(String customerId, List<String> labelIds) async {
    await StorageService.saveCustomerLabelsForCustomer(customerId, labelIds);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client
            .from('customer_labels')
            .delete()
            .eq('customer_id', customerId);
        if (labelIds.isNotEmpty) {
          final inserts = labelIds.map((lid) => {
            'customer_id': customerId,
            'label_id': lid,
          }).toList();
          await Supabase.instance.client.from('customer_labels').insert(inserts);
        }
      } catch (e) {
        debugPrint("Supabase assignLabelsToCustomer error: $e");
      }
    }
  }

  Future<List<CustomerLabel>> fetchAllCustomerLabels() async {
    if (_shouldUseLocalData) {
      return StorageService.getCustomerLabels();
    } else {
      try {
        final data = await Supabase.instance.client.from('customer_labels').select();
        final list = (data as List).map((x) => CustomerLabel.fromJson(x as Map<String, dynamic>)).toList();
        final deletedIds = StorageService.getDeletedCustomerIds().toSet();
        final filteredList = list.where((cl) => !deletedIds.contains(cl.customerId)).toList();
        return filteredList;
      } catch (e) {
        debugPrint("Supabase fetchAllCustomerLabels error, using cache: $e");
        return StorageService.getCustomerLabels();
      }
    }
  }

  // --- Import / Export History API ---
  Future<List<ImportHistory>> fetchImportHistory() async {
    if (_shouldUseLocalData) {
      return StorageService.getImportHistory();
    } else {
      try {
        final data = await Supabase.instance.client
            .from('import_history')
            .select()
            .order('import_date', ascending: false);
        return (data as List).map((x) => ImportHistory.fromJson(x as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint("Supabase fetchImportHistory error, using cache: $e");
        return StorageService.getImportHistory();
      }
    }
  }

  Future<void> addImportHistory(ImportHistory record) async {
    await StorageService.saveImportHistory(record);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('import_history').insert(record.toJson());
      } catch (e) {
        debugPrint("Supabase addImportHistory error: $e");
      }
    }
  }

  Future<List<ExportHistory>> fetchExportHistory() async {
    if (_shouldUseLocalData) {
      return StorageService.getExportHistory();
    } else {
      try {
        final data = await Supabase.instance.client
            .from('export_history')
            .select()
            .order('export_date', ascending: false);
        return (data as List).map((x) => ExportHistory.fromJson(x as Map<String, dynamic>)).toList();
      } catch (e) {
        debugPrint("Supabase fetchExportHistory error, using cache: $e");
        return StorageService.getExportHistory();
      }
    }
  }

  Future<void> addExportHistory(ExportHistory record) async {
    await StorageService.saveExportHistory(record);
    if (!_isMockMode) {
      try {
        await Supabase.instance.client.from('export_history').insert(record.toJson());
      } catch (e) {
        debugPrint("Supabase addExportHistory error: $e");
      }
    }
  }
}
