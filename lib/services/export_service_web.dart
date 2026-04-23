// Web-specific export implementation
import 'dart:html' as html;

void downloadFile(String content, String filename) {
  final blob = html.Blob([content]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

Future<void> shareFiles(
    String productsCsv, String entriesCsv, String stockCsv) async {
  throw UnsupportedError(
      'shareFiles should not be called on web, use downloadFile instead');
}
