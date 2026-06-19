import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'universal_file_saver.dart';

class LoggerService {
  static const String _keyLogs = 'siya_solar_app_logs';
  static SharedPreferences? _prefs;
  static final List<String> _inMemoryLogs = [];

  static Future<void> init() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      final saved = _prefs?.getStringList(_keyLogs);
      if (saved != null) {
        _inMemoryLogs.addAll(saved);
      }
    } catch (_) {}
  }

  static void logError(String module, String action, dynamic error, [dynamic stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final logEntry = '[$timestamp] [$module] $action - Error: $error${stackTrace != null ? "\nStack: $stackTrace" : ""}';
    _inMemoryLogs.add(logEntry);
    
    // Limit in-memory logs to last 100 entries to prevent memory bloating
    if (_inMemoryLogs.length > 100) {
      _inMemoryLogs.removeAt(0);
    }

    // Persist
    _saveLogs();
  }

  static Future<void> _saveLogs() async {
    try {
      await _prefs?.setStringList(_keyLogs, _inMemoryLogs);
    } catch (_) {}
  }

  static List<String> getLogs() {
    return List.unmodifiable(_inMemoryLogs);
  }

  static Future<void> clearLogs() async {
    _inMemoryLogs.clear();
    await _prefs?.remove(_keyLogs);
  }

  static Future<void> downloadLogs() async {
    if (_inMemoryLogs.isEmpty) {
      _inMemoryLogs.add('--- Siya Solar App Log Initialization ---\nNo runtime errors logged.');
    }
    
    final content = _inMemoryLogs.join('\n\n');
    final bytes = utf8.encode(content);
    final fileName = 'siya_solar_error_logs_${DateTime.now().millisecondsSinceEpoch}.txt';

    await UniversalFileSaver.saveAndDownloadFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: 'text/plain',
    );
  }
}
