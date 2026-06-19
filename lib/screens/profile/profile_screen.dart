import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../l10n/translation_provider.dart';
import '../../services/supabase_service.dart';
import '../../services/logger_service.dart';
import '../../constants/colors.dart';
import '../login_screen.dart';
import '../reports/reports_screen.dart';
import 'employee_manage_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final user = SupabaseService.instance.cachedUser;
    final isAdmin = user?.role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Text(translator.translate('tab_profile')),
      ),
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 700),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 10),
                // Avatar Circle
                Center(
                  child: CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primarySolarOrange.withOpacity(0.1),
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: AppColors.primarySolarOrange,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Name & Designation
                Center(
                  child: Text(
                    user?.name ?? 'User Name',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                Center(
                  child: Text(
                    user?.designation ?? 'Solar Staff',
                    style: const TextStyle(fontSize: 16, color: AppColors.textLightGray),
                  ),
                ),
                const SizedBox(height: 30),

                // Profile info box
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceGray,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.borderGray),
                  ),
                  child: Column(
                    children: [
                      _buildProfileRow(Icons.phone, translator.translate('mobile_number'), user?.mobileNumber ?? ''),
                      const Divider(),
                      _buildProfileRow(Icons.security, 'Role', user?.role == 'admin' ? translator.translate('role_admin') : translator.translate('role_employee')),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Language Switch Tile
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.translate, color: AppColors.primarySolarOrange),
                    title: Text(translator.translate('language')),
                    trailing: DropdownButton<String>(
                      value: translator.currentLocale,
                      underline: const SizedBox(),
                      onChanged: (val) {
                        if (val != null) {
                          translator.changeLocale(val);
                        }
                      },
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'mr', child: Text('मराठी')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Reports
                Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: const Icon(Icons.bar_chart, color: AppColors.primarySolarOrange),
                    title: Text(translator.translate('reports')),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ReportsScreen()),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Admin: Manage Employees
                if (isAdmin) ...[
                  Card(
                    margin: EdgeInsets.zero,
                    child: ListTile(
                      leading: const Icon(Icons.people, color: AppColors.primarySolarOrange),
                      title: Text(translator.translate('employees')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const EmployeeManageScreen()),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Download App Error Logs Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade50,
                    foregroundColor: Colors.red.shade900,
                    elevation: 0,
                  ),
                  onPressed: () async {
                    await LoggerService.downloadLogs();
                  },
                  icon: const Icon(Icons.bug_report),
                  label: const Text('Download App Error Logs'),
                ),
                const SizedBox(height: 12),

                // Logout Button
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey.shade200,
                    foregroundColor: AppColors.textDarkGray,
                  ),
                  onPressed: () async {
                    await SupabaseService.instance.logout();
                    if (context.mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                        (route) => false,
                      );
                    }
                  },
                  icon: const Icon(Icons.logout),
                  label: Text(translator.translate('logout')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primarySolarOrange, size: 20),
          const SizedBox(width: 16),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textLightGray)),
          const Spacer(),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textDarkGray)),
        ],
      ),
    );
  }
}
