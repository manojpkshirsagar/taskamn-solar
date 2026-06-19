import 'dart:convert';
import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/customer.dart';
import '../models/employee.dart';

class ImportExportHelper {
  // --- TEMPLATE GENERATION ---
  static List<int>? generateCsvTemplate(String type) {
    String csvData = "";
    if (type == 'customers') {
      csvData = "customer_name,mobile_number,email,address,consumer_number,solar_capacity,stage,assigned_employee\n"
          "Rajesh Patil,9876543201,rajesh@example.com,Main Road Kolhapur,123456789012,3.5,Lead,Rohan Shinde\n"
          "Sunita More,9876543202,sunita@example.com,Station Road Satara,123456789013,5.0,Survey,\n";
    } else if (type == 'tasks') {
      csvData = "customer_name,mobile_number,task_type,assigned_employee,due_date(yyyy-mm-dd),priority(Low/Medium/High),status(Pending/In Progress/Completed/Hold),remarks\n"
          "Rajesh Patil,9876543201,Site Survey,Rohan Shinde,2026-06-20,High,Pending,Verify roof space\n";
    } else if (type == 'employees') {
      csvData = "employee_name,mobile_number,designation,role(admin/employee)\n"
          "Karan Singh,9876543203,Field Supervisor,employee\n";
    } else if (type == 'loans') {
      csvData = "customer_name,mobile_number,bank_name,loan_amount,status,remarks\n"
          "Rajesh Patil,9876543201,SBI,120000,File at Bank,Aadhaar and PAN submitted\n";
    } else if (type == 'payments') {
      csvData = "customer_name,mobile_number,total_amount,advance_received,pending_amount,payment_status\n"
          "Rajesh Patil,9876543201,150000,50000,100000,Advance Received\n";
    }
    return utf8.encode(csvData);
  }

  static List<int>? generateExcelTemplate(String type) {
    final excel = Excel.createExcel();
    final Sheet sheet = excel['Sheet1'];

    List<String> headers = [];
    List<List<String>> sampleRows = [];

    if (type == 'customers') {
      headers = [
        'customer_name',
        'mobile_number',
        'email',
        'address',
        'consumer_number',
        'solar_capacity',
        'stage',
        'assigned_employee'
      ];
      sampleRows = [
        ['Rajesh Patil', '9876543201', 'rajesh@example.com', 'Kolhapur', '123456789012', '3.5', 'Lead', 'Rohan Shinde'],
        ['Sunita More', '9876543202', 'sunita@example.com', 'Satara', '123456789013', '5.0', 'Survey', '']
      ];
    } else if (type == 'tasks') {
      headers = [
        'customer_name',
        'mobile_number',
        'task_type',
        'assigned_employee',
        'due_date(yyyy-mm-dd)',
        'priority',
        'status',
        'remarks'
      ];
      sampleRows = [
        ['Rajesh Patil', '9876543201', 'Site Survey', 'Rohan Shinde', '2026-06-25', 'High', 'Pending', 'Verify shadow cast']
      ];
    } else if (type == 'employees') {
      headers = ['employee_name', 'mobile_number', 'designation', 'role'];
      sampleRows = [
        ['Karan Singh', '9876543203', 'Field Supervisor', 'employee']
      ];
    } else if (type == 'loans') {
      headers = ['customer_name', 'mobile_number', 'bank_name', 'loan_amount', 'status', 'remarks'];
      sampleRows = [
        ['Rajesh Patil', '9876543201', 'SBI', '120000', 'File at Bank', 'Aadhaar submitted']
      ];
    } else if (type == 'payments') {
      headers = ['customer_name', 'mobile_number', 'total_amount', 'advance_received', 'pending_amount', 'payment_status'];
      sampleRows = [
        ['Rajesh Patil', '9876543201', '150000', '50000', '100000', 'Advance Received']
      ];
    }

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var row in sampleRows) {
      sheet.appendRow(row.map((val) => TextCellValue(val)).toList());
    }

    return excel.save();
  }

  // --- PARSE IMPORTED DATA ---
  static List<Map<String, String>> parseCsv(String csvString) {
    final List<Map<String, String>> records = [];
    final lines = const LineSplitter().convert(csvString);
    if (lines.isEmpty) return [];

    // Parse headers
    final headers = lines[0].split(',').map((h) => h.trim().toLowerCase()).toList();

    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;
      
      final values = line.split(',');
      final Map<String, String> record = {};
      for (int j = 0; j < headers.length; j++) {
        if (j < values.length) {
          record[headers[j]] = values[j].trim();
        } else {
          record[headers[j]] = "";
        }
      }
      records.add(record);
    }
    return records;
  }

  static List<Map<String, String>> parseExcel(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    final List<Map<String, String>> records = [];

    for (var table in excel.tables.keys) {
      final sheet = excel.tables[table];
      if (sheet == null || sheet.maxRows == 0) continue;

      final headers = sheet.rows[0].map((cell) => cell?.value?.toString().trim().toLowerCase() ?? '').toList();

      for (int i = 1; i < sheet.maxRows; i++) {
        final row = sheet.rows[i];
        final Map<String, String> record = {};
        bool isEmpty = true;
        for (int j = 0; j < headers.length; j++) {
          if (headers[j].isEmpty) continue;
          final cellValue = j < row.length ? row[j]?.value?.toString().trim() ?? '' : '';
          if (cellValue.isNotEmpty) isEmpty = false;
          record[headers[j]] = cellValue;
        }
        if (!isEmpty) {
          records.add(record);
        }
      }
      break; // Only parse the first sheet
    }
    return records;
  }

  // --- VALIDATION FLOW ---
  static Map<String, dynamic> validateRecords({
    required String type,
    required List<Map<String, String>> records,
    required List<Customer> existingCustomers,
    required List<Employee> existingEmployees,
  }) {
    int total = records.length;
    int valid = 0;
    int duplicates = 0;
    int invalid = 0;

    final List<Map<String, dynamic>> validatedList = [];

    final Set<String> mobileNumbersInImport = {};
    final Set<String> consumerNumbersInImport = {};

    for (var record in records) {
      final Map<String, dynamic> validatedRecord = {
        'data': record,
        'status': 'valid',
        'errors': <String>[],
      };

      final errors = validatedRecord['errors'] as List<String>;

      if (type == 'customers') {
        final name = record['customer_name'] ?? record['name'] ?? '';
        final mobile = record['mobile_number'] ?? record['mobile'] ?? '';
        final consumer = record['consumer_number'] ?? '';
        final capacityStr = record['solar_capacity'] ?? record['capacity'] ?? '';
        final stage = record['stage'] ?? 'Lead';

        // 1. Required Fields Missing
        if (name.isEmpty) errors.add("Missing required field: customer_name");
        if (mobile.isEmpty) errors.add("Missing required field: mobile_number");

        // 2. Invalid Capacity
        if (capacityStr.isNotEmpty) {
          final cap = double.tryParse(capacityStr);
          if (cap == null || cap <= 0) {
            errors.add("Invalid capacity: must be a positive number");
          }
        }

        // 3. Invalid Stage
        final allowedStages = [
          'lead', 'survey', 'quotation', 'loan process', 'approved',
          'material dispatch', 'installation', 'net meter', 'subsidy pending', 'subsidy', 'completed'
        ];
        if (stage.isNotEmpty && !allowedStages.contains(stage.toLowerCase())) {
          errors.add("Invalid stage: '$stage'");
        }

        // 4. Duplicate Checks (Within the file & DB)
        if (mobile.isNotEmpty) {
          if (mobileNumbersInImport.contains(mobile)) {
            validatedRecord['status'] = 'duplicate';
            errors.add("Duplicate mobile number in import file: '$mobile'");
          } else {
            mobileNumbersInImport.add(mobile);
            final existsInDb = existingCustomers.any((c) => c.mobileNumber == mobile);
            if (existsInDb) {
              validatedRecord['status'] = 'duplicate';
              errors.add("Mobile number already exists in Database: '$mobile'");
            }
          }
        }

        if (consumer.isNotEmpty) {
          if (consumerNumbersInImport.contains(consumer)) {
            validatedRecord['status'] = 'duplicate';
            errors.add("Duplicate consumer number in import file: '$consumer'");
          } else {
            consumerNumbersInImport.add(consumer);
            final existsInDb = existingCustomers.any((c) => c.consumerNumber == consumer);
            if (existsInDb) {
              validatedRecord['status'] = 'duplicate';
              errors.add("Consumer number already exists in Database: '$consumer'");
            }
          }
        }
      } else if (type == 'tasks') {
        final name = record['customer_name'] ?? '';
        final mobile = record['mobile_number'] ?? '';
        final taskType = record['task_type'] ?? '';

        if (name.isEmpty) errors.add("Missing required field: customer_name");
        if (mobile.isEmpty) errors.add("Missing required field: mobile_number");
        if (taskType.isEmpty) errors.add("Missing required field: task_type");

        final customerExists = existingCustomers.any((c) => c.name.toLowerCase() == name.toLowerCase() || c.mobileNumber == mobile);
        if (!customerExists && name.isNotEmpty) {
          errors.add("Warning: Customer '$name ($mobile)' not found in DB. Will skip or require creation.");
        }
      } else if (type == 'employees') {
        final name = record['employee_name'] ?? record['name'] ?? '';
        final mobile = record['mobile_number'] ?? record['mobile'] ?? '';

        if (name.isEmpty) errors.add("Missing required field: employee_name");
        if (mobile.isEmpty) errors.add("Missing required field: mobile_number");

        if (mobile.isNotEmpty) {
          final exists = existingEmployees.any((e) => e.mobileNumber == mobile);
          if (exists) {
            validatedRecord['status'] = 'duplicate';
            errors.add("Employee with mobile '$mobile' already exists in DB");
          }
        }
      }

      if (errors.isNotEmpty) {
        if (validatedRecord['status'] != 'duplicate') {
          validatedRecord['status'] = 'invalid';
        }
      }

      if (validatedRecord['status'] == 'valid') {
        valid++;
      } else if (validatedRecord['status'] == 'duplicate') {
        duplicates++;
      } else {
        invalid++;
      }

      validatedList.add(validatedRecord);
    }

    return {
      'total': total,
      'valid': valid,
      'duplicate': duplicates,
      'invalid': invalid,
      'records': validatedList,
    };
  }

  // --- EXPORT PDF FLOW ---
  static Future<List<int>> exportToPdf({
    required String title,
    required List<String> headers,
    required List<List<String>> data,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return [
            pw.Container(
              color: PdfColors.orange800,
              padding: const pw.EdgeInsets.all(12),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Siya Solar CRM',
                    style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.Text(
                    DateTime.now().toIso8601String().split('T')[0],
                    style: const pw.TextStyle(color: PdfColors.white, fontSize: 12),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
            pw.SizedBox(height: 12),
            pw.TableHelper.fromTextArray(
              headers: headers,
              data: data,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
              cellStyle: const pw.TextStyle(fontSize: 8),
              cellHeight: 22,
              cellAlignments: Map.fromIterable(
                Iterable.generate(headers.length),
                key: (item) => item as int,
                value: (item) => pw.Alignment.centerLeft,
              ),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  // --- EXPORT EXCEL FLOW ---
  static List<int>? exportToExcel({
    required String sheetName,
    required List<String> headers,
    required List<List<dynamic>> data,
  }) {
    final excel = Excel.createExcel();
    final Sheet sheet = excel[sheetName];

    sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());
    for (var row in data) {
      sheet.appendRow(row.map((val) => TextCellValue(val.toString())).toList());
    }

    return excel.save();
  }

  // --- EXPORT CSV FLOW ---
  static List<int> exportToCsv({
    required List<String> headers,
    required List<List<dynamic>> data,
  }) {
    final buffer = StringBuffer();
    buffer.writeln(headers.join(','));
    for (var row in data) {
      final sanitizedRow = row.map((val) {
        final str = val.toString().replaceAll('"', '""');
        if (str.contains(',') || str.contains('\n') || str.contains('"')) {
          return '"$str"';
        }
        return str;
      }).join(',');
      buffer.writeln(sanitizedRow);
    }
    return utf8.encode(buffer.toString());
  }
}
