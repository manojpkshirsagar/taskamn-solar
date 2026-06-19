import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';
import 'l10n/translation_provider.dart';
import 'services/storage_service.dart';
import 'services/supabase_service.dart';
import 'services/logger_service.dart';
import 'services/connectivity_service.dart';
import 'services/sync_service.dart';
import 'services/approval_service.dart';
import 'constants/colors.dart';
import 'screens/login_screen.dart';
import 'screens/main_navigation.dart';
import 'screens/sync/sync_queue_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Logger Service
  await LoggerService.init();

  // Route terminal / framework errors to local LoggerService
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    LoggerService.logError(
      'FlutterError',
      details.exceptionAsString(),
      details.exception,
      details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    LoggerService.logError('PlatformDispatcher', 'UnhandledException', error, stack);
    return false;
  };

  // Initialize Storage Service (offline cache DB)
  await StorageService.init();
  
  // Initialize Supabase Service (if credentials configured)
  await SupabaseService.instance.initialize();

  // Initialize Connectivity & Sync Services
  await ConnectivityService.instance.init();
  SyncService.instance.init();

  runApp(const SiyaSolarApp());
}

class SiyaSolarApp extends StatelessWidget {
  const SiyaSolarApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if user session already exists
    final cachedUser = SupabaseService.instance.cachedUser;
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => TranslationProvider()),
        ChangeNotifierProvider.value(value: ConnectivityService.instance),
        ChangeNotifierProvider.value(value: SyncService.instance),
        ChangeNotifierProvider.value(value: ApprovalService.instance),
      ],
      child: Consumer<TranslationProvider>(
        builder: (context, translator, _) {
          return MaterialApp(
            title: 'Siya Solar Task Manager',
            theme: AppColors.lightTheme,
            debugShowCheckedModeBanner: false,
            home: cachedUser != null ? const MainNavigation() : const LoginScreen(),
            routes: {
              '/sync-queue': (_) => const SyncQueueScreen(),
            },
          );
        },
      ),
    );
  }
}
