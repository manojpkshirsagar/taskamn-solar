import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../constants/colors.dart';
import '../../models/loan.dart';
import '../../models/customer.dart';
import 'loan_detail_screen.dart';
import 'loan_form_screen.dart';

class LoanDashboardScreen extends StatefulWidget {
  final String? initialStatusFilter;

  const LoanDashboardScreen({super.key, this.initialStatusFilter});

  @override
  State<LoanDashboardScreen> createState() => _LoanDashboardScreenState();
}

class _LoanDashboardScreenState extends State<LoanDashboardScreen> {
  bool _isLoading = true;
  List<Loan> _loans = [];
  List<Customer> _customers = [];
  String _searchQuery = '';
  String _selectedStatusFilter = 'All';
  String _selectedBankFilter = 'All';
  String _selectedBranchFilter = 'All';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      _selectedStatusFilter = widget.initialStatusFilter!;
    }
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      SupabaseService.instance.fetchLoans(),
      SupabaseService.instance.fetchCustomers(),
    ]);

    final loans = results[0] as List<Loan>;
    final customers = results[1] as List<Customer>;
    if (mounted) {
      setState(() {
        _loans = loans;
        _customers = customers;
        _isLoading = false;
      });
    }
  }

  Customer _findCustomer(String customerId) {
    return _customers.firstWhere(
      (c) => c.id == customerId,
      orElse: () => Customer(
        id: '', name: 'Unknown', mobileNumber: '', emailAddress: '', address: '',
        solarCapacity: 0, stage: 'Lead', installationStage: 1,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final user = SupabaseService.instance.cachedUser;
    final isAdmin = user?.role == 'admin';

    // Stats
    final countApp = _loans.where((l) => l.status == 'Loan Application').length;
    final countPrint = _loans.where((l) => l.status == 'File Print').length;
    final countOffice = _loans.where((l) => l.status == 'File at Office').length;
    final countBank = _loans.where((l) => l.status == 'File at Bank').length;
    final countIssue = _loans.where((l) => l.status == 'Bank Issue').length;
    final countVisit = _loans.where((l) => l.status == 'Bank Visit At Home').length;
    final countApproved = _loans.where((l) => l.status == 'Approved').length;

    // Filter loans by search and selected status filter
    var filteredLoans = _loans;
    if (_selectedStatusFilter == 'Pending') {
      filteredLoans = filteredLoans.where((loan) => loan.status != 'Approved').toList();
    } else if (_selectedStatusFilter != 'All') {
      filteredLoans = filteredLoans.where((loan) => loan.status == _selectedStatusFilter).toList();
    }
    
    if (_selectedBankFilter != 'All') {
      filteredLoans = filteredLoans.where((loan) => loan.bankName == _selectedBankFilter).toList();
    }
    
    if (_selectedBranchFilter != 'All') {
      filteredLoans = filteredLoans.where((loan) => (loan.branch ?? '') == _selectedBranchFilter).toList();
    }

    if (_searchQuery.isNotEmpty) {
      filteredLoans = filteredLoans.where((loan) {
        final customer = _findCustomer(loan.customerId);
        final query = _searchQuery.toLowerCase();
        return customer.name.toLowerCase().contains(query) ||
               loan.bankName.toLowerCase().contains(query) ||
               loan.status.toLowerCase().contains(query);
      }).toList();
    }

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: Text(translator.translate('tab_loans')),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          Builder(
            builder: (ctx) => IconButton(
              icon: Icon(
                Icons.filter_alt,
                color: _selectedBankFilter != 'All' || _selectedBranchFilter != 'All'
                    ? AppColors.primarySolarOrange
                    : null,
              ),
              onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            ),
          ),
        ],
      ),
      endDrawer: _buildFilterDrawer(translator),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Center(
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 1100),
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Stat Cards Horizontally Scrollable
                            SizedBox(
                              height: 100,
                              child: ListView(
                                scrollDirection: Axis.horizontal,
                                children: [
                                  _buildStatCard(
                                    title: translator.translate('loan_status_loan_application'),
                                    value: countApp.toString(),
                                    icon: Icons.hourglass_empty,
                                    color: AppColors.pendingColor,
                                    isSelected: _selectedStatusFilter == 'Loan Application',
                                    onTap: () => setState(() {
                                      _selectedStatusFilter = _selectedStatusFilter == 'Loan Application' ? 'All' : 'Loan Application';
                                    }),
                                  ),
                                  _buildStatCard(
                                    title: translator.translate('loan_status_file_print'),
                                    value: countPrint.toString(),
                                    icon: Icons.print,
                                    color: Colors.blueGrey,
                                    isSelected: _selectedStatusFilter == 'File Print',
                                    onTap: () => setState(() {
                                      _selectedStatusFilter = _selectedStatusFilter == 'File Print' ? 'All' : 'File Print';
                                    }),
                                  ),
                                  _buildStatCard(
                                    title: translator.translate('loan_status_file_at_office'),
                                    value: countOffice.toString(),
                                    icon: Icons.folder_open,
                                    color: AppColors.loanDocPending,
                                    isSelected: _selectedStatusFilter == 'File at Office',
                                    onTap: () => setState(() {
                                      _selectedStatusFilter = _selectedStatusFilter == 'File at Office' ? 'All' : 'File at Office';
                                    }),
                                  ),
                                  _buildStatCard(
                                    title: translator.translate('loan_status_file_at_bank'),
                                    value: countBank.toString(),
                                    icon: Icons.account_balance,
                                    color: AppColors.loanBankVerification,
                                    isSelected: _selectedStatusFilter == 'File at Bank',
                                    onTap: () => setState(() {
                                      _selectedStatusFilter = _selectedStatusFilter == 'File at Bank' ? 'All' : 'File at Bank';
                                    }),
                                  ),
                                  _buildStatCard(
                                    title: translator.translate('loan_status_bank_issue'),
                                    value: countIssue.toString(),
                                    icon: Icons.warning_amber_rounded,
                                    color: Colors.redAccent,
                                    isSelected: _selectedStatusFilter == 'Bank Issue',
                                    onTap: () => setState(() {
                                      _selectedStatusFilter = _selectedStatusFilter == 'Bank Issue' ? 'All' : 'Bank Issue';
                                    }),
                                  ),
                                  _buildStatCard(
                                    title: translator.translate('loan_status_bank_visit_at_home'),
                                    value: countVisit.toString(),
                                    icon: Icons.home_work,
                                    color: Colors.teal,
                                    isSelected: _selectedStatusFilter == 'Bank Visit At Home',
                                    onTap: () => setState(() {
                                      _selectedStatusFilter = _selectedStatusFilter == 'Bank Visit At Home' ? 'All' : 'Bank Visit At Home';
                                    }),
                                  ),
                                  _buildStatCard(
                                    title: translator.translate('loan_status_approved'),
                                    value: countApproved.toString(),
                                    icon: Icons.check_circle,
                                    color: AppColors.loanDisbursed,
                                    isSelected: _selectedStatusFilter == 'Approved',
                                    onTap: () => setState(() {
                                      _selectedStatusFilter = _selectedStatusFilter == 'Approved' ? 'All' : 'Approved';
                                    }),
                                  ),
                                ].map((card) => Padding(
                                  padding: const EdgeInsets.only(right: 10.0),
                                  child: SizedBox(width: 110, child: card),
                                )).toList(),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Search Bar
                            TextField(
                              decoration: InputDecoration(
                                hintText: translator.translate('search_loans'),
                                prefixIcon: const Icon(Icons.search),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              onChanged: (val) => setState(() => _searchQuery = val),
                            ),
                            const SizedBox(height: 16),

                            // Loan Cards List
                            if (filteredLoans.isEmpty)
                              Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32.0),
                                  child: Text(
                                    translator.translate('no_loans_found'),
                                    style: const TextStyle(color: AppColors.textLightGray, fontSize: 16),
                                  ),
                                ),
                              )
                            else
                              ...filteredLoans.map((loan) {
                                final customer = _findCustomer(loan.customerId);
                                return _buildLoanCard(translator, loan, customer);
                              }),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: isAdmin
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.primarySolarOrange,
              foregroundColor: Colors.white,
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const LoanFormScreen()),
                ).then((_) => _loadData());
              },
              icon: const Icon(Icons.add),
              label: Text(translator.translate('new_loan_task')),
            )
          : null,
    );
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
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 6),
              Text(
                value,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: Center(
                  child: Text(
                    title,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textLightGray),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoanCard(TranslationProvider translator, Loan loan, Customer customer) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => LoanDetailScreen(loan: loan, customer: customer),
            ),
          ).then((_) => _loadData());
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      customer.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildLoanStatusBadge(loan.status),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (loan.loanCode != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        loan.loanCode!,
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  const Icon(Icons.account_balance, size: 14, color: AppColors.textLightGray),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('Bank: ${loan.bankName}', style: const TextStyle(color: AppColors.textLightGray, fontSize: 13), overflow: TextOverflow.ellipsis),
                  ),
                  Text(
                    'Loan: \u20b9${_formatAmount(loan.loanAmount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primarySolarOrange, fontSize: 14),
                  ),
                ],
              ),
              if (loan.branch != null && loan.branch!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_city, size: 14, color: AppColors.textLightGray),
                    const SizedBox(width: 4),
                    Text('Branch: ${loan.branch}', style: const TextStyle(color: AppColors.textLightGray, fontSize: 13)),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _getLoanStatusTranslationKey(String status) {
    return 'loan_status_${status.toLowerCase().replaceAll(' ', '_').replaceAll('/', '_').replaceAll('-', '_').replaceAll('__', '_')}';
  }

  Widget _buildLoanStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'File Print':
      case 'File at Office':
        color = AppColors.loanDocPending;
        break;
      case 'File at Bank':
        color = AppColors.loanBankVerification;
        break;
      case 'Bank Issue':
      case 'Bank Visit At Home':
        color = AppColors.loanApproved;
        break;
      case 'Approved':
        color = AppColors.loanDisbursed;
        break;
      default:
        color = AppColors.pendingColor;
    }

    final translator = Provider.of<TranslationProvider>(context, listen: false);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        translator.translate(_getLoanStatusTranslationKey(status)),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 100000) {
      return '${(amount / 100000).toStringAsFixed(amount % 100000 == 0 ? 0 : 2)}L';
    } else if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}K';
    }
    return amount.toStringAsFixed(0);
  }

  Widget _buildFilterDrawer(TranslationProvider translator) {
    final banks = {'All', ..._loans.map((l) => l.bankName).where((b) => b.isNotEmpty)}.toList()..sort();
    final branches = {'All', ..._loans.map((l) => l.branch ?? '').where((b) => b.isNotEmpty)}.toList()..sort();

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, color: AppColors.primarySolarOrange),
                  const SizedBox(width: 8),
                  const Text('Filter Loans', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Bank Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLightGray)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedBankFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: banks.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBankFilter = val ?? 'All';
                      });
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  const Text('Branch Name', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textLightGray)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedBranchFilter,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedBranchFilter = val ?? 'All';
                      });
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    setState(() {
                      _selectedBankFilter = 'All';
                      _selectedBranchFilter = 'All';
                    });
                  },
                  child: const Text('Clear Filters'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
