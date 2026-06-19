import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/customer.dart';
import '../../models/loan.dart';
import '../../models/task.dart';
import '../../models/label_category.dart';
import '../../models/label.dart';
import '../../models/customer_label.dart';
import '../../models/employee.dart';
import 'customer_form_screen.dart';
import 'customer_detail_screen.dart';
import 'admin_labels_screen.dart';

class CustomerListScreen extends StatefulWidget {
  final String? initialStageFilter;
  final String? initialLabelFilter;
  final bool initialPaymentPending;

  const CustomerListScreen({
    super.key,
    this.initialStageFilter,
    this.initialLabelFilter,
    this.initialPaymentPending = false,
  });

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  List<Customer> _allCustomers = [];
  List<Customer> _filteredCustomers = [];
  List<Loan> _loans = [];
  List<Task> _tasks = [];
  List<LabelCategory> _categories = [];
  List<Label> _labels = [];
  List<CustomerLabel> _customerLabels = [];
  List<Employee> _employees = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedStageFilter = 'All';
  String _selectedLabelFilter = 'All';
  String _selectedEmployeeFilter = 'All';
  String _villageFilter = '';
  bool _isPaymentPendingOnly = false;

  @override
  void initState() {
    super.initState();
    _selectedStageFilter = widget.initialStageFilter ?? 'All';
    _selectedLabelFilter = widget.initialLabelFilter ?? 'All';
    _isPaymentPendingOnly = widget.initialPaymentPending;
    _fetchCustomers();
  }

  Future<void> _fetchCustomers() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      SupabaseService.instance.fetchCustomers(),
      SupabaseService.instance.fetchLoans(),
      SupabaseService.instance.fetchTasks(),
      SupabaseService.instance.fetchLabelCategories(),
      SupabaseService.instance.fetchLabels(),
      SupabaseService.instance.fetchAllCustomerLabels(),
      SupabaseService.instance.fetchEmployees(),
    ]);

    final data = results[0] as List<Customer>;
    final loansData = results[1] as List<Loan>;
    final tasksData = results[2] as List<Task>;
    final cats = results[3] as List<LabelCategory>;
    final lbs = results[4] as List<Label>;
    final clbs = results[5] as List<CustomerLabel>;
    final emps = results[6] as List<Employee>;

    if (mounted) {
      setState(() {
        _allCustomers = data;
        _loans = loansData;
        _tasks = tasksData;
        _categories = cats;
        _labels = lbs;
        _customerLabels = clbs;
        _employees = emps;
        
        if (widget.initialLabelFilter != null && widget.initialLabelFilter != 'All') {
          try {
            final lbl = _labels.firstWhere((l) => l.labelName == widget.initialLabelFilter || l.id == widget.initialLabelFilter);
            _selectedLabelFilter = lbl.id;
          } catch (_) {}
        }
        
        _applyFilters();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredCustomers = _allCustomers.where((c) {
        final matchesSearch = c.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            c.mobileNumber.contains(_searchQuery) ||
            (c.customerCode?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        final matchesStage = _selectedStageFilter == 'All' || c.stage == _selectedStageFilter;

        bool matchesLabel = true;
        if (_selectedLabelFilter != 'All') {
          matchesLabel = _customerLabels.any((cl) => cl.customerId == c.id && cl.labelId == _selectedLabelFilter);
        }

        bool matchesEmployee = true;
        if (_selectedEmployeeFilter != 'All') {
          final hasTasksForEmp = _tasks.any((t) => t.customerId == c.id && t.assignedEmployeeId == _selectedEmployeeFilter);
          final hasLoansForEmp = _loans.any((l) => l.customerId == c.id && l.assignedEmployeeId == _selectedEmployeeFilter);
          matchesEmployee = hasTasksForEmp || hasLoansForEmp;
        }

        bool matchesVillage = true;
        if (_villageFilter.isNotEmpty) {
          matchesVillage = c.address.toLowerCase().contains(_villageFilter.toLowerCase());
        }
        
        bool matchesPayment = true;
        if (_isPaymentPendingOnly) {
          matchesPayment = _customerLabels.any((cl) {
            if (cl.customerId != c.id) return false;
            final lbl = _labels.firstWhere((l) => l.id == cl.labelId, orElse: () => Label(id: '', categoryId: '', labelName: ''));
            return lbl.labelName == 'Advance Pending' ||
                   lbl.labelName == 'Material Payment Pending' ||
                   lbl.labelName == 'Final Payment Pending';
          });
        }

        return matchesSearch && matchesStage && matchesLabel && matchesEmployee && matchesVillage && matchesPayment;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final user = SupabaseService.instance.cachedUser;
    final isAdmin = user?.role == 'admin';



    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(translator.translate('tab_customers')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCustomers,
          ),
          IconButton(
            icon: const Icon(Icons.filter_alt),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
          if (isAdmin)
            IconButton(
              icon: const Icon(Icons.settings),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const AdminLabelsScreen()),
                ).then((_) => _fetchCustomers());
              },
            ),
        ],
      ),
      endDrawer: _buildFilterDrawer(translator),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: translator.translate('search_customer'),
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: (val) {
                _searchQuery = val;
                _applyFilters();
              },
            ),
          ),

          // Stat Cards Horizontally Scrollable
          SizedBox(
            height: 100,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 4.0),
              children: [
                _buildStatCard(
                  title: 'Total',
                  value: _allCustomers.length.toString(),
                  icon: Icons.people,
                  color: AppColors.primarySolarOrange,
                  isSelected: _selectedStageFilter == 'All',
                  onTap: () => setState(() {
                    _selectedStageFilter = 'All';
                    _applyFilters();
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('stage_lead'),
                  value: _allCustomers.where((c) => c.stage == 'Lead').length.toString(),
                  icon: Icons.contact_page,
                  color: AppColors.pendingColor,
                  isSelected: _selectedStageFilter == 'Lead',
                  onTap: () => setState(() {
                    _selectedStageFilter = 'Lead';
                    _applyFilters();
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('stage_quotation_sent'),
                  value: _allCustomers.where((c) => c.stage == 'Quotation Sent').length.toString(),
                  icon: Icons.explore,
                  color: AppColors.priorityMedium,
                  isSelected: _selectedStageFilter == 'Quotation Sent',
                  onTap: () => setState(() {
                    _selectedStageFilter = 'Quotation Sent';
                    _applyFilters();
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('stage_customer_confirmed'),
                  value: _allCustomers.where((c) => c.stage == 'Customer Confirmed').length.toString(),
                  icon: Icons.assignment_turned_in,
                  color: AppColors.progressColor,
                  isSelected: _selectedStageFilter == 'Customer Confirmed',
                  onTap: () => setState(() {
                    _selectedStageFilter = 'Customer Confirmed';
                    _applyFilters();
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('stage_pm_surya_ghar_application'),
                  value: _allCustomers.where((c) => c.stage == 'PM Surya Ghar Application').length.toString(),
                  icon: Icons.app_registration,
                  color: Colors.blue,
                  isSelected: _selectedStageFilter == 'PM Surya Ghar Application',
                  onTap: () => setState(() {
                    _selectedStageFilter = 'PM Surya Ghar Application';
                    _applyFilters();
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('stage_installation'),
                  value: _allCustomers.where((c) => c.stage == 'Installation').length.toString(),
                  icon: Icons.build,
                  color: Colors.orange,
                  isSelected: _selectedStageFilter == 'Installation',
                  onTap: () => setState(() {
                    _selectedStageFilter = 'Installation';
                    _applyFilters();
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('stage_rts'),
                  value: _allCustomers.where((c) => c.stage == 'RTS').length.toString(),
                  icon: Icons.electric_meter,
                  color: Colors.purple,
                  isSelected: _selectedStageFilter == 'RTS',
                  onTap: () => setState(() {
                    _selectedStageFilter = 'RTS';
                    _applyFilters();
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('stage_subsidy'),
                  value: _allCustomers.where((c) => c.stage == 'Subsidy').length.toString(),
                  icon: Icons.account_balance_wallet,
                  color: Colors.teal,
                  isSelected: _selectedStageFilter == 'Subsidy',
                  onTap: () => setState(() {
                    _selectedStageFilter = 'Subsidy';
                    _applyFilters();
                  }),
                ),
                _buildStatCard(
                  title: translator.translate('stage_completed'),
                  value: _allCustomers.where((c) => c.stage == 'Completed').length.toString(),
                  icon: Icons.check_circle,
                  color: AppColors.completedColor,
                  isSelected: _selectedStageFilter == 'Completed',
                  onTap: () => setState(() {
                    _selectedStageFilter = 'Completed';
                    _applyFilters();
                  }),
                ),
              ].map((card) => Padding(
                padding: const EdgeInsets.only(right: 10.0),
                child: SizedBox(width: 110, child: card),
              )).toList(),
            ),
          ),
          const Divider(),

          // Customer List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredCustomers.isEmpty
                    ? const Center(child: Text('No customers found.'))
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 80),
                        itemCount: _filteredCustomers.length,
                        itemBuilder: (context, index) {
                          final customer = _filteredCustomers[index];
                          Loan? loan;
                          try {
                            loan = _loans.firstWhere((l) => l.customerId == customer.id);
                          } catch (_) {
                            loan = null;
                          }

                          final customerTasks = _tasks.where((t) => t.customerId == customer.id).toList();
                          final pendingTasks = customerTasks.where((t) => t.status != 'Completed').length;

                          return Card(
                            child: ListTile(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => CustomerDetailScreen(customer: customer),
                                  ),
                                ).then((_) => _fetchCustomers());
                              },
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primarySolarOrange.withOpacity(0.1),
                                child: const Icon(Icons.person, color: AppColors.primarySolarOrange),
                              ),
                              title: Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 8,
                                runSpacing: 4,
                                children: [
                                  Text(
                                    customer.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  if (customer.customerCode != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.grey.shade200,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        customer.customerCode!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade800,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${customer.emailAddress.isNotEmpty ? "${customer.emailAddress} | " : ""}${customer.mobileNumber}'),
                                  if (customerTasks.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.assignment,
                                          size: 13,
                                          color: pendingTasks > 0 ? AppColors.pendingColor : AppColors.completedColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Tasks: ${customerTasks.length} total (${pendingTasks} pending)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: pendingTasks > 0 ? AppColors.pendingColor : AppColors.completedColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                  if (loan != null) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.account_balance, size: 12, color: AppColors.primarySolarOrange),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${loan.bankName} - ${translator.translate('loan_status_${loan.status.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll('-', '_').replaceAll('__', '_')}')}',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: _getLoanStatusColor(loan.status),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              trailing: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 110),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primarySolarOrange.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    translator.translate('stage_${customer.stage.toLowerCase().replaceAll(' ', '_')}'),
                                    style: const TextStyle(
                                      color: AppColors.primarySolarOrange,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    softWrap: true,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
        ),
      ),
      floatingActionButton: isAdmin
          ? FloatingActionButton(
              heroTag: 'customer_list_fab',
              backgroundColor: AppColors.primarySolarOrange,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
                ).then((_) => _fetchCustomers());
              },
              child: const Icon(Icons.add),
            )
          : null,
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

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      elevation: isSelected ? 3.0 : 1.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? color : AppColors.borderGray,
          width: isSelected ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              Text(
                value,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 2),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textLightGray),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterDrawer(TranslationProvider translator) {
    return Drawer(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filters',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.primarySolarOrange),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _selectedStageFilter = 'All';
                        _selectedLabelFilter = 'All';
                        _selectedEmployeeFilter = 'All';
                        _villageFilter = '';
                        _isPaymentPendingOnly = false;
                        _applyFilters();
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Reset All'),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 10),
              
              // Village Filter
              const Text('Village / Address', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Filter by village...',
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  border: OutlineInputBorder(),
                ),
                onChanged: (val) {
                  setState(() {
                    _villageFilter = val;
                    _applyFilters();
                  });
                },
              ),
              const SizedBox(height: 16),
              
              // Stage Filter
              const Text('Stage', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedStageFilter,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                items: (() {
                  final stagesList = [
                    'All',
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
                  if (!stagesList.contains(_selectedStageFilter)) {
                    stagesList.add(_selectedStageFilter);
                  }
                  return stagesList.map((stg) => DropdownMenuItem(
                    value: stg,
                    child: Text(stg == 'All' 
                        ? 'All Stages' 
                        : (translator.translate('stage_${stg.toLowerCase().replaceAll(' ', '_')}') ?? stg)),
                  )).toList();
                })(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedStageFilter = val;
                      _applyFilters();
                    });
                  }
                },
              ),
              const SizedBox(height: 16),
              
              // Label Filter
              const Text('Label', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              InkWell(
                onTap: _showLabelFilterSearchDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.withOpacity(0.5)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _selectedLabelFilter == 'All'
                              ? 'All Labels'
                              : _labels
                                  .firstWhere((l) => l.id == _selectedLabelFilter,
                                      orElse: () => Label(
                                          id: '',
                                          categoryId: '',
                                          labelName: 'All Labels'))
                                  .labelName,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down,
                          color: AppColors.primarySolarOrange),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Employee Filter
              const Text('Employee', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              DropdownButtonFormField<String>(
                isExpanded: true,
                value: _selectedEmployeeFilter,
                decoration: const InputDecoration(contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                items: ['All', ..._employees.map((e) => e.id)].map((eid) {
                  if (eid == 'All') return const DropdownMenuItem(value: 'All', child: Text('All Employees'));
                  final emp = _employees.firstWhere((e) => e.id == eid);
                  return DropdownMenuItem(value: eid, child: Text(emp.name));
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedEmployeeFilter = val;
                      _applyFilters();
                    });
                  }
                },
              ),
              
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primarySolarOrange,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLabelFilterSearchDialog() {
    final activeLabels = _labels.where((l) => l.isActive).toList();
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
              title: const Text('Filter by Label'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
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
                    ListTile(
                      title: const Text('All Labels',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      selected: _selectedLabelFilter == 'All',
                      onTap: () {
                        setState(() {
                          _selectedLabelFilter = 'All';
                          _applyFilters();
                        });
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(),
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
                                return ListTile(
                                  title: Text(label.labelName),
                                  selected: _selectedLabelFilter == label.id,
                                  onTap: () {
                                    setState(() {
                                      _selectedLabelFilter = label.id;
                                      _applyFilters();
                                    });
                                    Navigator.pop(context);
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
                  child: const Text('Close'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
