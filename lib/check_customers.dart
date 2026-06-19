import 'package:flutter/material.dart';
import 'package:siya_solar_task_manager/services/supabase_service.dart';
import 'package:siya_solar_task_manager/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();
  await SupabaseService.instance.initialize();
  
  final mockMode = SupabaseService.instance.isMockMode;
  print("Mock Mode: \$mockMode");
  
  final customers = await SupabaseService.instance.fetchCustomers();
  print("Fetched Customers Count: \${customers.length}");
  
  final localCustomers = StorageService.getCustomers();
  print("Local Cache Customers Count: \${localCustomers.length}");
}
