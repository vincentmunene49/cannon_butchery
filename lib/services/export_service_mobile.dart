// Mobile-specific export implementation
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/formatters.dart';

void downloadFile(String content, String filename) {
  throw UnsupportedError(
      'downloadFile should not be called on mobile, use shareFiles instead');
}

Future<void> shareFiles(
    String productsCsv, String entriesCsv, String stockCsv) async {
  final dir = await getTemporaryDirectory();
  final files = <XFile>[];

  // Products CSV
  final productsFile = File('${dir.path}/products.csv');
  await productsFile.writeAsString(productsCsv);
  files.add(XFile(productsFile.path));

  // Daily Entries CSV
  final entriesFile = File('${dir.path}/daily_entries.csv');
  await entriesFile.writeAsString(entriesCsv);
  files.add(XFile(entriesFile.path));

  // Stock Additions CSV
  final stockFile = File('${dir.path}/stock_additions.csv');
  await stockFile.writeAsString(stockCsv);
  files.add(XFile(stockFile.path));

  await Share.shareXFiles(
    files,
    subject: 'Cannon Butchery Data Export',
    text: 'Cannon Butchery data exported on ${formatDate(DateTime.now())}',
  );
}
