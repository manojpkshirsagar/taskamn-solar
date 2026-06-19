import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

Future<void> saveAndDownloadFileImpl({
  required String fileName,
  required List<int> bytes,
  required String mimeType,
}) async {
  final base64 = base64Encode(bytes);
  html.AnchorElement(
    href: 'data:$mimeType;base64,$base64',
  )
    ..setAttribute('download', fileName)
    ..click();
}
