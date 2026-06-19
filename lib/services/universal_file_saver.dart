// Conditional imports for web vs native
import 'file_saver_mobile.dart' if (dart.library.js_util) 'file_saver_web.dart';

class UniversalFileSaver {
  static Future<void> saveAndDownloadFile({
    required String fileName,
    required List<int> bytes,
    required String mimeType,
  }) async {
    await saveAndDownloadFileImpl(
      fileName: fileName,
      bytes: bytes,
      mimeType: mimeType,
    );
  }
}
