import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:siya_solar_task_manager/services/storage_service.dart';
import 'package:siya_solar_task_manager/models/customer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await StorageService.init();
  });

  test('Delete Customer cascades and removes from storage', () async {
    final customersBefore = StorageService.getCustomers();
    expect(customersBefore.isNotEmpty, true);
    
    final customerToDelete = customersBefore.first;
    final id = customerToDelete.id;

    await StorageService.deleteCustomer(id);

    final customersAfter = StorageService.getCustomers();
    expect(customersAfter.any((c) => c.id == id), false);
  });
}
