// Stub for platform-specific export
void downloadFile(String content, String filename) {
  throw UnsupportedError('Cannot download files on this platform');
}

Future<void> shareFiles(
    String productsCsv, String entriesCsv, String stockCsv) async {
  throw UnsupportedError('Cannot share files on this platform');
}
