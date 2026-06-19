import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../../constants/colors.dart';
import '../../l10n/translation_provider.dart';
import '../../models/customer.dart';
import '../../models/employee.dart';
import '../../models/import_export_history.dart';
import '../../models/task.dart';
import '../../models/loan.dart';
import '../../models/label.dart';
import '../../services/supabase_service.dart';
import '../../services/import_export_helper.dart';
import '../../services/universal_file_saver.dart';

class ImportExportScreen extends StatefulWidget {
  const ImportExportScreen({super.key});

  @override
  State<ImportExportScreen> createState() => _ImportExportScreenState();
}

class _ImportExportScreenState extends State<ImportExportScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false;

  // DB Data Cached
  List<Customer> _customers = [];
  List<Employee> _employees = [];
  List<Task> _tasks = [];
  List<Loan> _loans = [];
  List<Label> _labels = [];
  List<ImportHistory> _importHistory = [];
  List<ExportHistory> _exportHistory = [];

  // Import State
  String _selectedImportType = 'customers';
  String? _importedFileName;
  List<Map<String, String>> _parsedRecords = [];
  Map<String, dynamic>? _validationResult;

  // Import Options checkboxes
  bool _skipDuplicates = true;
  bool _updateExisting = false;
  bool _createEmployees = true;
  bool _autoCreateLabels = true;

  // Export Filter State
  String _selectedExportFormat = 'xlsx';
  String _selectedExportType = 'customers';
  String _selectedDateRange = 'All';
  DateTimeRange? _customDateTimeRange;
  String _filterVillage = 'All';
  String _filterStage = 'All';
  double? _filterCapacity;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    _customers = await SupabaseService.instance.fetchCustomers();
    _employees = await SupabaseService.instance.fetchEmployees();
    _tasks = await SupabaseService.instance.fetchTasks();
    _loans = await SupabaseService.instance.fetchLoans();
    _labels = await SupabaseService.instance.fetchLabels();
    _importHistory = await SupabaseService.instance.fetchImportHistory();
    _exportHistory = await SupabaseService.instance.fetchExportHistory();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- TEMPLATE DOWNLOADS ---
  Future<void> _downloadTemplate(String type, String format) async {
    List<int>? fileBytes;
    String fileName = "${type}_template.$format";
    if (format == 'csv') {
      fileBytes = ImportExportHelper.generateCsvTemplate(type);
    } else {
      fileBytes = ImportExportHelper.generateExcelTemplate(type);
    }

    if (fileBytes == null) return;

    try {
      final mimeType = format == 'csv' ? 'text/csv' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      await UniversalFileSaver.saveAndDownloadFile(
        fileName: fileName,
        bytes: fileBytes,
        mimeType: mimeType,
      );
      _showSuccessSnackBar(kIsWeb ? "Template '$fileName' download started." : "Template downloaded to Documents folder.");
    } catch (e) {
      _showErrorSnackBar("Failed to save template: $e");
    }
  }

  // --- PARSE AND PREVIEW UPLOAD ---
  void _simulateUploadFile() {
    // We will simulate file upload for mobile-friendly or offline CRM usage
    // depending on the type, we seed a list of valid/invalid mock data to preview
    String mockData = "";
    if (_selectedImportType == 'customers') {
      mockData = "customer_name,mobile_number,email,address,consumer_number,solar_capacity,stage,assigned_employee\n"
          "Rajesh Patil,9876543201,rajesh@example.com,Kolhapur,123456789012,3.5,Lead,Rohan Shinde\n"
          "Amit Deshmukh,9890223344,amit.deshmukh@example.com,Satara,987654321098,8.0,Installation,\n" // duplicate mobile & consumer number
          "Invalid Customer,,invalidEmail,Pune,,abc,UnknownStage,DoesNotExist\n" // invalid mobile, missing name/addr, invalid capacity
          "Hemalata,9988776655,hema@example.com,Sangli,123456789019,4.2,Quotation,Rohan Shinde\n"; // valid with labels and employees
    } else if (_selectedImportType == 'tasks') {
      mockData = "customer_name,mobile_number,task_type,assigned_employee,due_date(yyyy-mm-dd),priority,status,remarks\n"
          "Rajesh Patil,9876543201,Site Survey,Rohan Shinde,2026-06-20,High,Pending,Verify shadow cast\n"
          "Unknown Patil,9876540001,Installation,Rohan Shinde,2026-06-22,Medium,Pending,No customer match\n";
    } else if (_selectedImportType == 'employees') {
      mockData = "employee_name,mobile_number,designation,role\n"
          "Rohan Shinde,8888888888,Field Technician,employee\n" // duplicate
          "New Supervisor,9876543219,Field Supervisor,employee\n"; // valid
    }

    _importedFileName = "solar_${_selectedImportType}_import.csv";
    _parsedRecords = ImportExportHelper.parseCsv(mockData);

    _validationResult = ImportExportHelper.validateRecords(
      type: _selectedImportType,
      records: _parsedRecords,
      existingCustomers: _customers,
      existingEmployees: _employees,
    );

    setState(() {});
    _showSuccessSnackBar("Loaded $_importedFileName. Review validation preview below.");
  }

  // --- SUBMIT AND BULK IMPORT ---
  Future<void> _performImport() async {
    if (_validationResult == null) return;
    setState(() => _isLoading = true);

    final List<dynamic> validatedRecords = _validationResult!['records'] as List<dynamic>;
    int success = 0;
    int failed = 0;

    const uuid = Uuid();
    final user = SupabaseService.instance.cachedUser;
    final String currentUserName = user?.name ?? "Admin";

    for (var vRec in validatedRecords) {
      final status = vRec['status'] as String;
      final data = vRec['data'] as Map<String, String>;

      if (status == 'invalid' || (status == 'duplicate' && _skipDuplicates && !_updateExisting)) {
        failed++;
        continue;
      }

      try {
        if (_selectedImportType == 'customers') {
          final mobile = data['mobile_number'] ?? data['mobile'] ?? '';
          final name = data['customer_name'] ?? data['name'] ?? '';
          final email = data['email'] ?? '';
          final address = data['address'] ?? '';
          final consumer = data['consumer_number'] ?? '';
          final capacity = double.tryParse(data['solar_capacity'] ?? '') ?? 0.0;
          final stage = data['stage'] ?? 'Lead';
          final assignedEmpName = data['assigned_employee'] ?? '';

          Customer? existingCust;
          try {
            existingCust = _customers.firstWhere((c) => c.mobileNumber == mobile);
          } catch (_) {}

          if (existingCust != null && !_updateExisting) {
            failed++;
            continue;
          }

          // Handle Employee check
          if (assignedEmpName.isNotEmpty) {
            Employee? matchedEmp;
            try {
              matchedEmp = _employees.firstWhere((e) => e.name.toLowerCase() == assignedEmpName.toLowerCase());
            } catch (_) {}

            if (matchedEmp == null && _createEmployees) {
              final newEmp = Employee(
                id: uuid.v4(),
                name: assignedEmpName,
                mobileNumber: '9900${uuid.v4().substring(0, 6)}',
                designation: 'Field Agent',
                role: 'employee',
                createdAt: DateTime.now(),
              );
              await SupabaseService.instance.addEmployee(newEmp);
              _employees.add(newEmp);
            }
          }

          // Stage mapping default
          int instStage = 1;
          switch (stage) {
            case 'Lead': instStage = 1; break;
            case 'Survey': instStage = 2; break;
            case 'Quotation': instStage = 3; break;
            case 'Loan Process': instStage = 4; break;
            case 'Approved': instStage = 5; break;
            case 'Material Dispatch': instStage = 6; break;
            case 'Installation': instStage = 7; break;
            case 'Net Meter': instStage = 8; break;
            case 'Subsidy': instStage = 9; break;
            case 'Completed': instStage = 10; break;
          }

          final finalCust = Customer(
            id: existingCust?.id ?? uuid.v4(),
            name: name,
            mobileNumber: mobile,
            emailAddress: email,
            address: address,
            consumerNumber: consumer.isEmpty ? null : consumer,
            solarCapacity: capacity,
            stage: stage,
            installationStage: instStage,
            createdAt: existingCust?.createdAt ?? DateTime.now(),
          );

          await SupabaseService.instance.upsertCustomer(finalCust);

          // Handle auto-create labels if any labels specified (e.g. in comma separated form inside customer data)
          final rawLabels = data['labels'] ?? '';
          if (rawLabels.isNotEmpty && _autoCreateLabels) {
            final List<String> labelNames = rawLabels.split(',').map((l) => l.trim()).toList();
            final List<String> labelIdsToAssign = [];
            for (var lname in labelNames) {
              Label? matchingLabel;
              try {
                matchingLabel = _labels.firstWhere((l) => l.labelName.toLowerCase() == lname.toLowerCase());
              } catch (_) {}

              if (matchingLabel == null) {
                final newLabel = Label(
                  id: uuid.v4(),
                  categoryId: 'c-installation',
                  labelName: lname,
                  isActive: true,
                  createdAt: DateTime.now(),
                );
                await SupabaseService.instance.upsertLabel(newLabel);
                _labels.add(newLabel);
                labelIdsToAssign.add(newLabel.id);
              } else {
                labelIdsToAssign.add(matchingLabel.id);
              }
            }
            await SupabaseService.instance.assignLabelsToCustomer(finalCust.id, labelIdsToAssign);
          }

          success++;
        } else if (_selectedImportType == 'tasks') {
          final name = data['customer_name'] ?? '';
          final mobile = data['mobile_number'] ?? '';
          final taskType = data['task_type'] ?? '';
          final priority = data['priority'] ?? 'Medium';
          final status = data['status'] ?? 'Pending';
          final remarks = data['remarks'] ?? '';
          final dueDateStr = data['due_date'] ?? '';

          Customer? matchingCustomer;
          try {
            matchingCustomer = _customers.firstWhere((c) => c.name.toLowerCase() == name.toLowerCase() || c.mobileNumber == mobile);
          } catch (_) {}

          if (matchingCustomer == null) {
            failed++;
            continue;
          }

          final task = Task(
            id: uuid.v4(),
            customerId: matchingCustomer.id,
            taskType: taskType,
            dueDate: DateTime.tryParse(dueDateStr) ?? DateTime.now().add(const Duration(days: 3)),
            priority: priority,
            remarks: remarks,
            status: status,
            createdAt: DateTime.now(),
          );

          await SupabaseService.instance.upsertTask(task);
          success++;
        } else if (_selectedImportType == 'employees') {
          final name = data['employee_name'] ?? '';
          final mobile = data['mobile_number'] ?? '';
          final designation = data['designation'] ?? 'Field Technician';
          final role = data['role'] ?? 'employee';

          final emp = Employee(
            id: uuid.v4(),
            name: name,
            mobileNumber: mobile,
            designation: designation,
            role: role,
            createdAt: DateTime.now(),
          );
          await SupabaseService.instance.addEmployee(emp);
          success++;
        }
      } catch (e) {
        failed++;
        debugPrint("Import record error: $e");
      }
    }

    // Add import history
    final history = ImportHistory(
      id: uuid.v4(),
      fileName: _importedFileName ?? "manual_input.csv",
      moduleName: _selectedImportType.toUpperCase(),
      importDate: DateTime.now(),
      importedBy: currentUserName,
      successCount: success,
      failedCount: failed,
    );

    await SupabaseService.instance.addImportHistory(history);
    await _loadAllData();

    setState(() {
      _parsedRecords = [];
      _validationResult = null;
      _importedFileName = null;
    });

    _showSuccessSnackBar("Bulk Import Completed. Success: $success, Failed: $failed");
  }

  Future<void> _downloadErrorLog() async {
    final res = _validationResult;
    if (res == null) return;

    final recordsList = res['records'] as List<dynamic>;
    final List<String> headers = ['Row Number', 'Record Identifiers', 'Status', 'Errors / Issues'];
    final List<List<dynamic>> dataRows = [];

    int rowNum = 1;
    for (var rec in recordsList) {
      final status = rec['status'] as String;
      if (status != 'valid') {
        final data = rec['data'] as Map<String, String>;
        final errors = rec['errors'] as List<String>;
        
        final identifier = data['customer_name'] ?? data['employee_name'] ?? data['mobile_number'] ?? 'Row $rowNum';
        dataRows.add([
          rowNum.toString(),
          identifier,
          status.toUpperCase(),
          errors.join('; '),
        ]);
      }
      rowNum++;
    }

    if (dataRows.isEmpty) {
      _showSuccessSnackBar("No validation errors found to generate log.");
      return;
    }

    final fileBytes = ImportExportHelper.exportToCsv(headers: headers, data: dataRows);
    final fileName = "import_${_selectedImportType}_error_log_${DateTime.now().millisecondsSinceEpoch}.csv";

    await UniversalFileSaver.saveAndDownloadFile(
      fileName: fileName,
      bytes: fileBytes,
      mimeType: 'text/csv',
    );
    _showSuccessSnackBar("Error log downloaded: $fileName");
  }

  // --- FILTERS AND EXPORT ---
  List<Customer> _applyExportFilters() {
    return _customers.where((c) {
      // 1. Date Range
      if (_selectedDateRange != 'All') {
        final now = DateTime.now();
        final startToday = DateTime(now.year, now.month, now.day);
        if (c.createdAt == null) return false;

        if (_selectedDateRange == 'Today') {
          if (c.createdAt!.isBefore(startToday)) return false;
        } else if (_selectedDateRange == 'This Week') {
          final weekStart = startToday.subtract(Duration(days: now.weekday - 1));
          if (c.createdAt!.isBefore(weekStart)) return false;
        } else if (_selectedDateRange == 'This Month') {
          final monthStart = DateTime(now.year, now.month, 1);
          if (c.createdAt!.isBefore(monthStart)) return false;
        } else if (_selectedDateRange == 'Custom' && _customDateTimeRange != null) {
          if (c.createdAt!.isBefore(_customDateTimeRange!.start) ||
              c.createdAt!.isAfter(_customDateTimeRange!.end.add(const Duration(days: 1)))) {
            return false;
          }
        }
      }

      // 2. Village Filter
      if (_filterVillage != 'All') {
        if (!c.address.toLowerCase().contains(_filterVillage.toLowerCase())) {
          return false;
        }
      }

      // 3. Stage Filter
      if (_filterStage != 'All') {
        if (c.stage != _filterStage) return false;
      }

      // 4. Capacity Filter
      if (_filterCapacity != null) {
        if (c.solarCapacity < _filterCapacity!) return false;
      }

      // 5. Label Filter
      // Handled globally if checked
      return true;
    }).toList();
  }

  Future<void> _performExport({String? quickReportName, List<Customer>? customDataList}) async {
    setState(() => _isLoading = true);
    final dataList = customDataList ?? _applyExportFilters();
    final user = SupabaseService.instance.cachedUser;
    final String currentUserName = user?.name ?? "Admin";

    List<String> headers = [];
    List<List<dynamic>> rows = [];
    String reportName = quickReportName ?? "Customers_${_selectedExportType}_Report";

    if (_selectedExportType == 'customers') {
      headers = ['Customer ID', 'Lead ID', 'Customer Name', 'Mobile', 'Email', 'Consumer Number', 'Capacity (kW)', 'Stage', 'Address', 'Quotation ID', 'Installation ID', 'Net Meter ID', 'Subsidy ID', 'Payment ID'];
      rows = dataList.map((c) => [
        c.customerCode ?? '',
        c.leadCode ?? '',
        c.name,
        c.mobileNumber,
        c.emailAddress,
        c.consumerNumber ?? 'N/A',
        c.solarCapacity,
        c.stage,
        c.address,
        c.quotationCode ?? '',
        c.installationCode ?? '',
        c.netMeterCode ?? '',
        c.subsidyCode ?? '',
        c.paymentCode ?? ''
      ]).toList();
    } else if (_selectedExportType == 'tasks') {
      headers = ['Task ID', 'Task Type', 'Customer Name', 'Due Date', 'Priority', 'Status', 'Remarks'];
      for (var t in _tasks) {
        final cust = _customers.firstWhere((c) => c.id == t.customerId, orElse: () => Customer(id: '', name: 'N/A', mobileNumber: '', emailAddress: '', address: '', solarCapacity: 0, stage: 'Lead', installationStage: 1));
        rows.add([t.taskCode ?? t.id, t.taskType, cust.name, t.dueDate.toIso8601String().split('T')[0], t.priority, t.status, t.remarks ?? '']);
      }
    } else if (_selectedExportType == 'loans') {
      headers = ['Loan ID', 'Customer Name', 'Loan Amount (₹)', 'Bank Name', 'Status', 'Remarks'];
      for (var l in _loans) {
        final cust = _customers.firstWhere((c) => c.id == l.customerId, orElse: () => Customer(id: '', name: 'N/A', mobileNumber: '', emailAddress: '', address: '', solarCapacity: 0, stage: 'Lead', installationStage: 1));
        rows.add([l.loanCode ?? l.id, cust.name, l.loanAmount, l.bankName, l.status, l.remarks ?? '']);
      }
    }

    List<int>? fileBytes;
    String fileExt = _selectedExportFormat;

    if (_selectedExportFormat == 'xlsx') {
      fileBytes = ImportExportHelper.exportToExcel(sheetName: 'Report', headers: headers, data: rows);
    } else if (_selectedExportFormat == 'csv') {
      fileBytes = ImportExportHelper.exportToCsv(headers: headers, data: rows);
    } else {
      // PDF
      final stringData = rows.map((r) => r.map((cell) => cell.toString()).toList()).toList();
      fileBytes = await ImportExportHelper.exportToPdf(title: reportName, headers: headers, data: stringData);
    }

    if (fileBytes != null) {
      try {
        final uuid = const Uuid();
        final finalFileName = "${reportName}_${DateTime.now().millisecondsSinceEpoch}.$fileExt";
        
        String mimeType = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
        if (fileExt == 'csv') mimeType = 'text/csv';
        if (fileExt == 'pdf') mimeType = 'application/pdf';

        await UniversalFileSaver.saveAndDownloadFile(
          fileName: finalFileName,
          bytes: fileBytes,
          mimeType: mimeType,
        );

        _showSuccessSnackBar(kIsWeb ? "Report download started: $finalFileName" : "Report exported successfully to Documents folder");

        // Save History
        final exportHistoryRecord = ExportHistory(
          id: uuid.v4(),
          reportName: reportName,
          exportType: fileExt.toUpperCase(),
          exportDate: DateTime.now(),
          exportedBy: currentUserName,
          totalRecords: rows.length,
        );
        await SupabaseService.instance.addExportHistory(exportHistoryRecord);
        await _loadAllData();
      } catch (e) {
        _showErrorSnackBar("Export failed: $e");
      }
    }

    setState(() => _isLoading = false);
  }

  // --- QUICK EXPORTS ---
  void _runQuickExport(String type) {
    List<Customer> filteredList = [];
    String reportTitle = "";

    switch (type) {
      case 'installation_pending':
        filteredList = _customers.where((c) => c.stage == 'Installation').toList();
        reportTitle = "Installation_Pending_Report";
        break;
      case 'net_meter_pending':
        filteredList = _customers.where((c) => c.stage == 'Net Meter').toList();
        reportTitle = "Net_Meter_Pending_Report";
        break;
      case 'subsidy_pending':
        filteredList = _customers.where((c) => c.stage == 'Subsidy').toList();
        reportTitle = "Subsidy_Pending_Report";
        break;
      case 'loan_pending':
        filteredList = _customers.where((c) => c.stage == 'Loan Process').toList();
        reportTitle = "Loan_Pending_Report";
        break;
      case 'completed_projects':
        filteredList = _customers.where((c) => c.stage == 'Completed').toList();
        reportTitle = "Completed_Projects_Report";
        break;
    }

    _performExport(quickReportName: reportTitle, customDataList: filteredList);
  }

  // --- UI HELPER SNACKBARS ---
  void _showSuccessSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.completedColor),
    );
  }

  void _showErrorSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.holdColor),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('import_export')),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            Tab(icon: const Icon(Icons.upload_file), text: translator.translate('tab_import')),
            Tab(icon: const Icon(Icons.download), text: translator.translate('tab_export')),
            Tab(icon: const Icon(Icons.history), text: translator.translate('import_history')),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primarySolarOrange))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildImportTab(translator),
                _buildExportTab(translator),
                _buildHistoryTab(translator),
              ],
            ),
    );
  }

  // --- IMPORT TAB WIDGET ---
  Widget _buildImportTab(TranslationProvider translator) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildImportDashboardCard(translator),
          const SizedBox(height: 16),
          // Download Templates Section
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    translator.translate('download_templates'),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textDarkGray),
                  ),
                  Text(
                    translator.translate('templates_subtitle'),
                    style: const TextStyle(color: AppColors.textLightGray, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primarySolarOrange,
                          side: const BorderSide(color: AppColors.primarySolarOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Customer Template'),
                        onPressed: () => _downloadTemplate('customers', 'csv'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primarySolarOrange,
                          side: const BorderSide(color: AppColors.primarySolarOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Task Template'),
                        onPressed: () => _downloadTemplate('tasks', 'csv'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primarySolarOrange,
                          side: const BorderSide(color: AppColors.primarySolarOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Employee Template'),
                        onPressed: () => _downloadTemplate('employees', 'csv'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primarySolarOrange,
                          side: const BorderSide(color: AppColors.primarySolarOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Loan Template'),
                        onPressed: () => _downloadTemplate('loans', 'csv'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.primarySolarOrange,
                          side: const BorderSide(color: AppColors.primarySolarOrange),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        icon: const Icon(Icons.download, size: 16),
                        label: const Text('Payment Template'),
                        onPressed: () => _downloadTemplate('payments', 'csv'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Upload Selector Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Select Module for Import', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedImportType,
                    decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                    items: const [
                      DropdownMenuItem(value: 'customers', child: Text('Customers Data')),
                      DropdownMenuItem(value: 'tasks', child: Text('Tasks Checklist')),
                      DropdownMenuItem(value: 'employees', child: Text('Employees / Field Team')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedImportType = val;
                          _validationResult = null;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primarySolarOrange),
                    icon: const Icon(Icons.file_upload, color: Colors.white),
                    label: const Text('Upload CSV / Excel File', style: TextStyle(color: Colors.white)),
                    onPressed: _simulateUploadFile,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Validation Options & Actions
          if (_validationResult != null) ...[
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      translator.translate('import_options'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    CheckboxListTile(
                      title: const Text('Skip Duplicate Customers'),
                      value: _skipDuplicates,
                      onChanged: (val) => setState(() => _skipDuplicates = val ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      title: const Text('Update Existing Customers Data'),
                      value: _updateExisting,
                      onChanged: (val) => setState(() => _updateExisting = val ?? false),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      title: const Text('Create Missing Employees'),
                      value: _createEmployees,
                      onChanged: (val) => setState(() => _createEmployees = val ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    CheckboxListTile(
                      title: const Text('Auto Create Missing Labels'),
                      value: _autoCreateLabels,
                      onChanged: (val) => setState(() => _autoCreateLabels = val ?? true),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    const SizedBox(height: 16),
                    _buildPreviewStatsSection(translator),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.completedColor),
                        onPressed: _performImport,
                        child: const Text('Execute Bulk Import', style: TextStyle(color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- PREVIEW STATS ---
  Widget _buildPreviewStatsSection(TranslationProvider translator) {
    final res = _validationResult!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          translator.translate('validation_preview'),
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildStatChip("Total", res['total'].toString(), Colors.blue),
            _buildStatChip("Valid", res['valid'].toString(), AppColors.completedColor),
            _buildStatChip("Duplicates", res['duplicate'].toString(), AppColors.pendingColor),
            _buildStatChip("Invalid", res['invalid'].toString(), AppColors.holdColor),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Data Preview Table:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            if (res['invalid'] > 0 || res['duplicate'] > 0)
              TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: AppColors.holdColor),
                onPressed: _downloadErrorLog,
                icon: const Icon(Icons.download_for_offline, size: 16),
                label: const Text('Download Error Log', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 150,
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.borderGray),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListView.builder(
            itemCount: (res['records'] as List).length,
            itemBuilder: (ctx, idx) {
              final rec = (res['records'] as List)[idx];
              final status = rec['status'] as String;
              final data = rec['data'] as Map<String, String>;
              final errors = rec['errors'] as List<String>;

              Color statusColor = AppColors.completedColor;
              if (status == 'duplicate') statusColor = AppColors.pendingColor;
              if (status == 'invalid') statusColor = AppColors.holdColor;

              return ListTile(
                dense: true,
                title: Text(data['customer_name'] ?? data['employee_name'] ?? 'Record $idx', style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(errors.isNotEmpty ? errors.join(', ') : 'All checks passed'),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16)),
          Text(label, style: const TextStyle(color: AppColors.textLightGray, fontSize: 10)),
        ],
      ),
    );
  }

  // --- EXPORT TAB WIDGET ---
  Widget _buildExportTab(TranslationProvider translator) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildExportDashboardCard(translator),
          const SizedBox(height: 16),
          // Export Filters
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Report Configuration', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedExportType,
                    decoration: const InputDecoration(labelText: 'Export Module'),
                    items: const [
                      DropdownMenuItem(value: 'customers', child: Text('Customers Master Data')),
                      DropdownMenuItem(value: 'tasks', child: Text('Tasks List & Checklist')),
                      DropdownMenuItem(value: 'loans', child: Text('Loans Status & Banking')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedExportType = val);
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: _selectedExportFormat,
                    decoration: const InputDecoration(labelText: 'File Format'),
                    items: const [
                      DropdownMenuItem(value: 'xlsx', child: Text('Excel (.xlsx)')),
                      DropdownMenuItem(value: 'csv', child: Text('CSV (.csv)')),
                      DropdownMenuItem(value: 'pdf', child: Text('PDF Documents (.pdf)')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedExportFormat = val);
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  const Text('Custom Filter Criteria', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: _selectedDateRange,
                    decoration: const InputDecoration(labelText: 'Registration Date Range'),
                    items: const [
                      DropdownMenuItem(value: 'All', child: Text('All Times')),
                      DropdownMenuItem(value: 'Today', child: Text('Today')),
                      DropdownMenuItem(value: 'This Week', child: Text('This Week')),
                      DropdownMenuItem(value: 'This Month', child: Text('This Month')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _selectedDateRange = val);
                      }
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primarySolarOrange),
                    icon: const Icon(Icons.download, color: Colors.white),
                    label: const Text('Export Filtered Report', style: TextStyle(color: Colors.white)),
                    onPressed: () => _performExport(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Quick Exports
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Quick One-Click Exports', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade100, foregroundColor: Colors.blue.shade800),
                        onPressed: () => _runQuickExport('installation_pending'),
                        child: const Text('Installation Pending'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.purple.shade100, foregroundColor: Colors.purple.shade800),
                        onPressed: () => _runQuickExport('net_meter_pending'),
                        child: const Text('Net Meter Pending'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade100, foregroundColor: Colors.teal.shade800),
                        onPressed: () => _runQuickExport('subsidy_pending'),
                        child: const Text('Subsidy Pending'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo.shade100, foregroundColor: Colors.indigo.shade800),
                        onPressed: () => _runQuickExport('loan_pending'),
                        child: const Text('Loan Pending'),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade100, foregroundColor: Colors.green.shade800),
                        onPressed: () => _runQuickExport('completed_projects'),
                        child: const Text('Completed Projects'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- HISTORY TAB ---
  Widget _buildHistoryTab(TranslationProvider translator) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Bulk Import Log History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _importHistory.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No import logs found.')))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _importHistory.length,
                itemBuilder: (ctx, idx) {
                  final log = _importHistory[idx];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.upload_file, color: AppColors.primarySolarOrange),
                      title: Text(log.fileName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Module: ${log.moduleName} | By: ${log.importedBy}\nDate: ${log.importDate.toLocal().toString().split('.')[0]}'),
                      trailing: Text('Success: ${log.successCount}\nFailed: ${log.failedCount}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  );
                },
              ),
        const SizedBox(height: 24),
        const Text('Export Download Log History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 8),
        _exportHistory.isEmpty
            ? const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('No export logs found.')))
            : ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _exportHistory.length,
                itemBuilder: (ctx, idx) {
                  final log = _exportHistory[idx];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.download, color: Colors.blue),
                      title: Text(log.reportName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('Format: ${log.exportType} | By: ${log.exportedBy}\nDate: ${log.exportDate.toLocal().toString().split('.')[0]}'),
                      trailing: Text('Records: ${log.totalRecords}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    ),
                  );
                },
              ),
      ],
    );
  }

  // --- STATS DASHBOARDS WIDGETS ---
  Widget _buildImportDashboardCard(TranslationProvider translator) {
    int totalImports = _importHistory.length;
    int todayImports = _importHistory.where((h) {
      final now = DateTime.now();
      return h.importDate.year == now.year && h.importDate.month == now.month && h.importDate.day == now.day;
    }).length;
    int failedImports = _importHistory.where((h) => h.failedCount > 0).length;

    return Row(
      children: [
        Expanded(child: _buildSmallWidgetCard("Total Imports", totalImports.toString(), Icons.cloud_upload_outlined, Colors.orange)),
        const SizedBox(width: 8),
        Expanded(child: _buildSmallWidgetCard("Today's", todayImports.toString(), Icons.today, Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _buildSmallWidgetCard("Failed", failedImports.toString(), Icons.error_outline, Colors.red)),
      ],
    );
  }

  Widget _buildExportDashboardCard(TranslationProvider translator) {
    int totalExports = _exportHistory.length;
    int todayExports = _exportHistory.where((h) {
      final now = DateTime.now();
      return h.exportDate.year == now.year && h.exportDate.month == now.month && h.exportDate.day == now.day;
    }).length;

    // Find the most exported format or report name
    String popularFormat = "N/A";
    if (_exportHistory.isNotEmpty) {
      final map = <String, int>{};
      for (var h in _exportHistory) {
        map[h.exportType] = (map[h.exportType] ?? 0) + 1;
      }
      popularFormat = map.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    }

    return Row(
      children: [
        Expanded(child: _buildSmallWidgetCard("Total Exports", totalExports.toString(), Icons.cloud_download_outlined, Colors.blue)),
        const SizedBox(width: 8),
        Expanded(child: _buildSmallWidgetCard("Today's", todayExports.toString(), Icons.today, Colors.green)),
        const SizedBox(width: 8),
        Expanded(child: _buildSmallWidgetCard("Format", popularFormat, Icons.file_present, Colors.purple)),
      ],
    );
  }

  Widget _buildSmallWidgetCard(String title, String val, IconData icon, Color color) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Column(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 6),
            Text(val, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(color: AppColors.textLightGray, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
