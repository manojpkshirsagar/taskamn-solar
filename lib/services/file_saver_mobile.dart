import 'dart:io';
import 'package:path_provider/path_provider.dart';

Future<void> saveAndDownloadFileImpl({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File("${dir.path}/$fileName");
  await file.writeAsBytes(bytes);
}
