import 'dart:io' if (dart.library.html) 'dart:html';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/product.dart';
import '../models/daily_entry.dart';
import '../models/stock_addition.dart';
import '../services/firestore_service.dart';
import '../utils/formatters.dart';
import 'export_service_stub.dart'
    if (dart.library.html) 'export_service_web.dart';

class ExportService {
  static Future<void> exportAll() async {
    final products = await FirestoreService.getProducts();
    final entries = await FirestoreService.getAllEntries();
    final stockAdditions = await FirestoreService.getAllStockAdditions();

    if (kIsWeb) {
      // Web: Combine all CSVs into one file and trigger download
      final combinedCsv = StringBuffer();

      combinedCsv.writeln('=== PRODUCTS ===');
      combinedCsv.writeln(_buildProductsCsv(products));
      combinedCsv.writeln('\n=== DAILY ENTRIES ===');
      combinedCsv.writeln(_buildEntriesCsv(entries));
      combinedCsv.writeln('\n=== STOCK ADDITIONS ===');
      combinedCsv.writeln(_buildStockCsv(stockAdditions));

      downloadFile(
        combinedCsv.toString(),
        'cannon_butchery_export_${formatShortDate(DateTime.now())}.csv',
      );
    } else {
      // Mobile: Use share_plus
      final dir = await getTemporaryDirectory();
      final files = <XFile>[];

      // Products CSV
      final productsCsv = _buildProductsCsv(products);
      final productsFile = File('${dir.path}/products.csv');
      await productsFile.writeAsString(productsCsv);
      files.add(XFile(productsFile.path));

      // Daily Entries CSV
      final entriesCsv = _buildEntriesCsv(entries);
      final entriesFile = File('${dir.path}/daily_entries.csv');
      await entriesFile.writeAsString(entriesCsv);
      files.add(XFile(entriesFile.path));

      // Stock Additions CSV
      final stockCsv = _buildStockCsv(stockAdditions);
      final stockFile = File('${dir.path}/stock_additions.csv');
      await stockFile.writeAsString(stockCsv);
      files.add(XFile(stockFile.path));

      await Share.shareXFiles(
        files,
        subject: 'Cannon Butchery Data Export',
        text: 'Cannon Butchery data exported on ${formatDate(DateTime.now())}',
      );
    }
  }

  static String _buildProductsCsv(List<Product> products) {
    final buf = StringBuffer();
    buf.writeln('ID,Name,Type,Current Price (KES),Active');
    for (final p in products) {
      buf.writeln('${p.id},${_esc(p.name)},${p.type},${p.currentPrice},${p.isActive}');
    }
    return buf.toString();
  }

  static String _buildEntriesCsv(List<DailyEntry> entries) {
    final buf = StringBuffer();
    buf.writeln(
      'Date,M-Pesa Opening,M-Pesa Closing,Cash Opening,Cash Closing,'
      'M-Pesa Stock Expenses,Cash Stock Expenses,'
      'M-Pesa Received,Cash Received,Total Received,'
      'Total Expected Minimum,Variance,Flagged',
    );
    for (final e in entries) {
      buf.writeln(
        '${e.id},${e.mpesaOpeningBalance},${e.mpesaClosingBalance},'
        '${e.cashOpeningBalance},${e.cashClosingBalance},'
        '${e.mpesaStockExpenses},${e.cashStockExpenses},'
        '${e.mpesaReceived},${e.cashReceived},${e.totalReceived},'
        '${e.totalExpectedMinimum},${e.variance},${e.isFlagged}',
      );
    }
    return buf.toString();
  }

  static String _buildStockCsv(List<StockAddition> additions) {
    final buf = StringBuffer();
    buf.writeln('Date,Product,Sellable Amount,Cost Paid (KES),Cost Per Unit,Payment Method,Note');
    for (final s in additions) {
      buf.writeln(
        '${formatShortDate(s.date)},${_esc(s.productName)},${s.sellableAmount},'
        '${s.costPaid},${s.costPerUnit},${s.paymentMethod},${_esc(s.note ?? '')}',
      );
    }
    return buf.toString();
  }

  static String _esc(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
