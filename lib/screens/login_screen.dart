import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/translation_provider.dart';
import '../services/supabase_service.dart';
import '../constants/colors.dart';
import 'main_navigation.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedRole = 'employee'; // default role
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final translator = Provider.of<TranslationProvider>(context, listen: false);

    final employee = await SupabaseService.instance.login(
      _identifierController.text.trim(),
      _passwordController.text,
      _selectedRole,
    );

    setState(() => _isLoading = false);

    if (employee != null) {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(translator.translate('login_failed')),
            backgroundColor: AppColors.holdColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final translator = Provider.of<TranslationProvider>(context);
    final locale = translator.currentLocale;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Language Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Icon(Icons.language, color: AppColors.primarySolarOrange, size: 20),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: locale,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(value: 'en', child: Text('English')),
                        DropdownMenuItem(value: 'mr', child: Text('मराठी (Marathi)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          translator.changeLocale(val);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 40),
                // Logo & Title
                const Center(
                  child: Icon(
                    Icons.solar_power,
                    size: 80,
                    color: AppColors.primarySolarOrange,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  translator.translate('app_title'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: AppColors.textDarkGray,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  translator.translate('tagline'),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.textLightGray,
                      ),
                ),
                const SizedBox(height: 48),

                // Role Toggle
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRole = 'employee'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'employee'
                                ? AppColors.primarySolarOrange
                                : AppColors.surfaceGray,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            translator.translate('role_employee'),
                            style: TextStyle(
                              color: _selectedRole == 'employee' ? Colors.white : AppColors.textDarkGray,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedRole = 'admin'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: _selectedRole == 'admin'
                                ? AppColors.primarySolarOrange
                                : AppColors.surfaceGray,
                            borderRadius: const BorderRadius.only(
                              topRight: Radius.circular(12),
                              bottomRight: Radius.circular(12),
                            ),
                            border: Border.all(color: AppColors.borderGray),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            translator.translate('role_admin'),
                            style: TextStyle(
                              color: _selectedRole == 'admin' ? Colors.white : AppColors.textDarkGray,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Identifier Input
                TextFormField(
                  controller: _identifierController,
                  keyboardType: TextInputType.text,
                  decoration: InputDecoration(
                    hintText: '${translator.translate('email')} / ${translator.translate('mobile_number')}',
                    prefixIcon: const Icon(Icons.person),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter email or mobile number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Password Input
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    hintText: translator.translate('password'),
                    prefixIcon: const Icon(Icons.lock),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter password';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 32),

                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Text(translator.translate('login')),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    'Demo Hint: Type "admin" for Admin, "employee" for Employee',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
