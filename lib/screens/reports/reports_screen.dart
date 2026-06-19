import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:excel/excel.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/customer.dart';
import 'import_export_screen.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  List<Customer> _customers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final customers = await SupabaseService.instance.fetchCustomers();
    
    if (mounted) {
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    }
  }

  // Filter lists based on report types
  List<Customer> _getPendingSurveyCustomers() {
    return _customers.where((c) => c.stage == 'Survey' || c.installationStage == 2).toList();
  }

  List<Customer> _getPendingInstallationCustomers() {
    return _customers.where((c) => c.stage == 'Installation' || (c.installationStage >= 4 && c.installationStage <= 6)).toList();
  }

  List<Customer> _getPendingNetMeterCustomers() {
    return _customers.where((c) => c.stage == 'Net Meter' || (c.installationStage >= 7 && c.installationStage <= 9)).toList();
  }

  List<Customer> _getPendingSubsidyCustomers() {
    return _customers.where((c) => c.stage == 'Subsidy Pending' || c.installationStage == 10).toList();
  }

  // --- PDF Export Logic ---
  Future<void> _exportToPdf(String title, List<Customer> dataList) async {
    final pdf = pw.Document();
    
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                color: PdfColors.orange800,
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Siya Solar Task Manager',
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      DateTime.now().toIso8601String().split('T')[0],
                      style: const pw.TextStyle(color: PdfColors.white),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),
              pw.Text(title, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 16),
              pw.TableHelper.fromTextArray(
                headers: ['Name', 'Mobile', 'Email', 'Stage'],
                data: dataList.map((c) => [c.name, c.mobileNumber, c.emailAddress, c.stage]).toList(),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                cellHeight: 30,
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                },
              ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getApplicationDocumentsDirectory();
      final sanitizedTitle = title.toLowerCase().replaceAll(' ', '_');
      final file = File('${output.path}/$sanitizedTitle.pdf');
      await file.writeAsBytes(await pdf.save());
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported to: ${file.path}'),
            backgroundColor: AppColors.completedColor,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      debugPrint("PDF generation error: $e");
    }
  }

  // --- Excel Export Logic ---
  Future<void> _exportToExcel(String title, List<Customer> dataList) async {
    final excel = Excel.createExcel();
    final Sheet sheetObject = excel['Sheet1'];
    
    // Add Headers
    sheetObject.appendRow([
      TextCellValue('Customer Name'),
      TextCellValue('Mobile Number'),
      TextCellValue('Email'),
      TextCellValue('Stage'),
      TextCellValue('Installation Step')
    ]);

    // Add Data
    for (var c in dataList) {
      sheetObject.appendRow([
        TextCellValue(c.name),
        TextCellValue(c.mobileNumber),
        TextCellValue(c.emailAddress),
        TextCellValue(c.stage),
        TextCellValue(c.installationStage.toString())
      ]);
    }

    try {
      final output = await getApplicationDocumentsDirectory();
      final sanitizedTitle = title.toLowerCase().replaceAll(' ', '_');
      final file = File('${output.path}/$sanitizedTitle.xlsx');
      final fileBytes = excel.save();
      if (fileBytes != null) {
        await file.writeAsBytes(fileBytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Excel exported to: ${file.path}'),
              backgroundColor: AppColors.completedColor,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint("Excel generation error: $e");
    }
  }

  void _showReportDetails(String title, List<Customer> dataList, TranslationProvider translator) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(topLeft: Radius.circular(20), topRight: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.textDarkGray),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const Divider(),
              
              // Export Actions
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade700),
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: Text(translator.translate('export_pdf')),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _exportToPdf(title, dataList);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                      icon: const Icon(Icons.table_chart, color: Colors.white),
                      label: Text(translator.translate('export_excel')),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _exportToExcel(title, dataList);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // List details
              Expanded(
                child: dataList.isEmpty
                    ? const Center(child: Text('No records found.'))
                    : ListView.builder(
                        itemCount: dataList.length,
                        itemBuilder: (ctx, idx) {
                          final c = dataList[idx];
                          return Card(
                            child: ListTile(
                              title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${c.emailAddress.isNotEmpty ? "${c.emailAddress} | " : ""}${c.mobileNumber}'),
                              trailing: Text('Step ${c.installationStage}/11', style: const TextStyle(color: AppColors.primarySolarOrange, fontWeight: FontWeight.bold)),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('reports')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildReportButton(
                      title: translator.translate('import_export'),
                      count: _customers.length,
                      icon: Icons.import_export,
                      color: AppColors.primarySolarOrange,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ImportExportScreen()),
                        ).then((_) => _loadData());
                      },
                    ),
                    const SizedBox(height: 8),
                    _buildReportButton(
                      title: translator.translate('pending_survey_report'),
                      count: _getPendingSurveyCustomers().length,
                      icon: Icons.explore_outlined,
                      color: AppColors.pendingColor,
                      onTap: () => _showReportDetails(
                        translator.translate('pending_survey_report'),
                        _getPendingSurveyCustomers(),
                        translator,
                      ),
                    ),
                    _buildReportButton(
                      title: translator.translate('pending_installation_report'),
                      count: _getPendingInstallationCustomers().length,
                      icon: Icons.construction_outlined,
                      color: AppColors.progressColor,
                      onTap: () => _showReportDetails(
                        translator.translate('pending_installation_report'),
                        _getPendingInstallationCustomers(),
                        translator,
                      ),
                    ),
                    _buildReportButton(
                      title: translator.translate('pending_net_meter_report'),
                      count: _getPendingNetMeterCustomers().length,
                      icon: Icons.electric_meter_outlined,
                      color: Colors.purple,
                      onTap: () => _showReportDetails(
                        translator.translate('pending_net_meter_report'),
                        _getPendingNetMeterCustomers(),
                        translator,
                      ),
                    ),
                    _buildReportButton(
                      title: translator.translate('pending_subsidy_report'),
                      count: _getPendingSubsidyCustomers().length,
                      icon: Icons.assignment_turned_in_outlined,
                      color: Colors.teal,
                      onTap: () => _showReportDetails(
                        translator.translate('pending_subsidy_report'),
                        _getPendingSubsidyCustomers(),
                        translator,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReportButton({
    required String title,
    required int count,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          radius: 26,
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        subtitle: Text('Pending customers: $count', style: const TextStyle(color: AppColors.textLightGray)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
      ),
    );
  }
}
