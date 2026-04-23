import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/product.dart';
import '../models/daily_entry.dart';
import '../models/stock_addition.dart';
import '../services/firestore_service.dart';
import '../utils/formatters.dart';
import 'export_service_stub.dart'
    if (dart.library.html) 'export_service_web.dart'
    if (dart.library.io) 'export_service_mobile.dart';

class ExportService {
  static Future<void> exportAll() async {
    final products = await FirestoreService.getProducts();
    final entries = await FirestoreService.getAllEntries();
    final stockAdditions = await FirestoreService.getAllStockAdditions();

    final productsCsv = _buildProductsCsv(products);
    final entriesCsv = _buildEntriesCsv(entries);
    final stockCsv = _buildStockCsv(stockAdditions);

    if (kIsWeb) {
      // Web: Combine all CSVs into one file and trigger download
      final combinedCsv = StringBuffer();
      combinedCsv.writeln('=== PRODUCTS ===');
      combinedCsv.writeln(productsCsv);
      combinedCsv.writeln('\n=== DAILY ENTRIES ===');
      combinedCsv.writeln(entriesCsv);
      combinedCsv.writeln('\n=== STOCK ADDITIONS ===');
      combinedCsv.writeln(stockCsv);

      downloadFile(
        combinedCsv.toString(),
        'cannon_butchery_export_${formatShortDate(DateTime.now())}.csv',
      );
    } else {
      // Mobile: Share separate CSV files
      await shareFiles(productsCsv, entriesCsv, stockCsv);
    }
  }

  static String _buildProductsCsv(List<Product> products) {
    final buf = StringBuffer();
    buf.writeln('ID,Name,Type,Current Price (KES),Active');
    for (final p in products) {
      buf.writeln(
          '${p.id},${_esc(p.name)},${p.type},${p.currentPrice},${p.isActive}');
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
    buf.writeln(
        'Date,Product,Sellable Amount,Cost Paid (KES),Cost Per Unit,Payment Method,Note');
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
