import 'package:supabase/supabase.dart';

void main() async {
  final supabase = SupabaseClient(
    'https://gbdllbncblhhrzekhngi.supabase.co',
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImdiZGxsYm5jYmxoaHJ6ZWtobmdpIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE2MDE4MDQsImV4cCI6MjA5NzE3NzgwNH0.U81MRNtb_0mDNKGx0m5QOLUNNlczF9yN3BJu4QQk_vc'
  );
  
  try {
    final data = await supabase.from('customers').select();
    print('==============================');
    print('Customers in Supabase: ${data.length}');
    print('==============================');
    for (var c in data) {
      print('- ${c["name"]} (${c["mobile_number"]})');
    }
  } catch (e) {
    print('Error querying Supabase: \$e');
  }
}
