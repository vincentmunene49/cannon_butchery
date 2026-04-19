import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/product.dart';
import '../models/daily_entry.dart';
import '../models/product_entry.dart';
import '../models/sale.dart';
import '../models/stock_addition.dart';
import '../utils/formatters.dart';

class FirestoreService {
  static final _db = FirebaseFirestore.instance;

  // ─── Collections ───────────────────────────────────────────────────────────
  static CollectionReference get _products => _db.collection('products');
  static CollectionReference get _dailyEntries => _db.collection('dailyEntries');
  static CollectionReference get _stockAdditions => _db.collection('stockAdditions');
  static CollectionReference get _sales => _db.collection('sales');

  // ─── Products ──────────────────────────────────────────────────────────────

  static Stream<List<Product>> productsStream() {
    return _products.snapshots().map((s) {
      final list = s.docs.map((d) => Product.fromFirestore(d)).toList();
      // Sort in Dart to avoid requiring a Firestore composite index
      list.sort((a, b) {
        if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
        return a.name.compareTo(b.name);
      });
      return list;
    });
  }

  static Future<List<Product>> getProducts() async {
    final snap = await _products.orderBy('name').get();
    return snap.docs.map((d) => Product.fromFirestore(d)).toList();
  }

  static Future<void> addProduct(Product product) async {
    await _products.doc(product.id).set(product.toFirestore());
  }

  static Future<void> updateProduct(Product product) async {
    await _products.doc(product.id).update(product.toFirestore());
  }

  static Future<void> updateProductPrice(String productId, double newPrice) async {
    final productRef = _products.doc(productId);
    final snap = await productRef.get();
    final oldPrice = (snap.data() as Map<String, dynamic>)['currentPrice'] ?? 0;

    final batch = _db.batch();
    batch.update(productRef, {'currentPrice': newPrice});
    batch.set(
      productRef.collection('priceHistory').doc(),
      {
        'price': oldPrice,
        'effectiveFrom': Timestamp.fromDate(DateTime.now()),
      },
    );
    await batch.commit();
  }

  static Future<bool> productHasEntries(String productId) async {
    // Check if any daily entry's productEntries subcollection references this product
    final snap = await _dailyEntries
        .limit(1)
        .get();
    for (final doc in snap.docs) {
      final subSnap = await _dailyEntries
          .doc(doc.id)
          .collection('productEntries')
          .where('productId', isEqualTo: productId)
          .limit(1)
          .get();
      if (subSnap.docs.isNotEmpty) return true;
    }
    return false;
  }

  static Future<void> deleteProduct(String productId) async {
    await _products.doc(productId).delete();
  }

  // Get price for a product on a given date (from priceHistory)
  static Future<double> getPriceForDate(String productId, DateTime date) async {
    final productSnap = await _products.doc(productId).get();
    if (!productSnap.exists) return 0;

    final currentPrice =
        ((productSnap.data() as Map<String, dynamic>)['currentPrice'] ?? 0).toDouble();

    // Check price history for any price that was effective on or before the given date
    final historySnap = await _products
        .doc(productId)
        .collection('priceHistory')
        .where('effectiveFrom', isLessThanOrEqualTo: Timestamp.fromDate(date))
        .orderBy('effectiveFrom', descending: true)
        .limit(1)
        .get();

    if (historySnap.docs.isNotEmpty) {
      return ((historySnap.docs.first.data())['price'] ?? currentPrice).toDouble();
    }
    return currentPrice;
  }

  // ─── Daily Entries ─────────────────────────────────────────────────────────

  static Stream<DailyEntry?> entryStreamForDate(String dateId) {
    return _dailyEntries.doc(dateId).snapshots().map((s) {
      if (!s.exists) return null;
      return DailyEntry.fromFirestore(s);
    });
  }

  static Future<DailyEntry?> getEntryForDate(String dateId) async {
    final snap = await _dailyEntries.doc(dateId).get();
    if (!snap.exists) return null;
    return DailyEntry.fromFirestore(snap);
  }

  static Future<List<ProductEntry>> getProductEntriesForDate(String dateId) async {
    final snap = await _dailyEntries.doc(dateId).collection('productEntries').get();
    return snap.docs.map((d) => ProductEntry.fromFirestore(d)).toList();
  }

  static Future<void> saveDailyEntry(
    DailyEntry entry,
    List<ProductEntry> productEntries,
  ) async {
    final batch = _db.batch();
    final entryRef = _dailyEntries.doc(entry.id);

    batch.set(entryRef, entry.toFirestore());

    for (final pe in productEntries) {
      batch.set(
        entryRef.collection('productEntries').doc(pe.productId),
        pe.toFirestore(),
      );
    }
    await batch.commit();
  }

  static Future<void> deleteDailyEntry(String dateId) async {
    // Delete subcollection productEntries first
    final subSnap =
        await _dailyEntries.doc(dateId).collection('productEntries').get();
    final batch = _db.batch();
    for (final doc in subSnap.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_dailyEntries.doc(dateId));
    await batch.commit();
  }

  static Future<List<DailyEntry>> getAllEntries() async {
    final snap = await _dailyEntries
        .where('isCompleted', isEqualTo: true)
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => DailyEntry.fromFirestore(d)).toList();
  }

  // Get opening balances for a date (= previous day's closing balances,
  // or today's Day 1 setup balances, or initial config)
  static Future<Map<String, double>> getOpeningBalancesForDate(DateTime date) async {
    final yesterday = date.subtract(const Duration(days: 1));
    final yesterdayId = dateToId(yesterday);
    final yesterdayEntry = await getEntryForDate(yesterdayId);
    if (yesterdayEntry != null && yesterdayEntry.isCompleted) {
      return {
        'mpesa': yesterdayEntry.mpesaClosingBalance,
        'cash': yesterdayEntry.cashClosingBalance,
      };
    }
    // Check if today has a Day 1 setup doc with opening balances pre-filled
    final todayId = dateToId(date);
    final todayEntry = await getEntryForDate(todayId);
    if (todayEntry != null) {
      return {
        'mpesa': todayEntry.mpesaOpeningBalance,
        'cash': todayEntry.cashOpeningBalance,
      };
    }
    // Fall back to initial balances config
    return getInitialBalances();
  }

  // Get opening stock for each product for a date:
  //  1. Yesterday's remainingStock (normal carry-forward)
  //  2. Today's pre-set openingStock written by Day 1 setup in Settings
  //  3. config/day1OpeningStock as final fallback
  static Future<Map<String, double>> getOpeningStockForDate(DateTime date) async {
    final yesterday = date.subtract(const Duration(days: 1));
    final yesterdayId = dateToId(yesterday);
    final yesterdayEntries = await getProductEntriesForDate(yesterdayId);
    if (yesterdayEntries.isNotEmpty) {
      return {for (final e in yesterdayEntries) e.productId: e.remainingStock};
    }
    // Check if Day 1 setup wrote openingStock into today's productEntries
    final todayId = dateToId(date);
    final todayEntries = await getProductEntriesForDate(todayId);
    if (todayEntries.isNotEmpty) {
      return {for (final e in todayEntries) e.productId: e.openingStock};
    }
    // Final fallback: config written by old Day 1 setup
    return getDay1OpeningStock();
  }

  // ─── Stock Additions ───────────────────────────────────────────────────────

  static Stream<List<StockAddition>> stockAdditionsStreamForDate(String dateId) {
    final startOfDay = idToDate(dateId);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _stockAdditions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => StockAddition.fromFirestore(d)).toList());
  }

  static Future<List<StockAddition>> getStockAdditionsForDate(String dateId) async {
    final startOfDay = idToDate(dateId);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final snap = await _stockAdditions
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => StockAddition.fromFirestore(d)).toList();
  }

  static Future<List<StockAddition>> getAllStockAdditions() async {
    final snap =
        await _stockAdditions.orderBy('date', descending: true).get();
    return snap.docs.map((d) => StockAddition.fromFirestore(d)).toList();
  }

  static Stream<List<StockAddition>> allStockAdditionsStream() {
    return _stockAdditions
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => StockAddition.fromFirestore(d)).toList());
  }

  static Future<void> addStockAddition(StockAddition addition) async {
    await _stockAdditions.doc(addition.id).set(addition.toFirestore());
  }

  static Future<void> deleteStockAddition(String id) async {
    await _stockAdditions.doc(id).delete();
  }

  // ─── Day 1 Opening Stock ───────────────────────────────────────────────────

  static Future<bool> hasAnyCompletedEntries() async {
    final snap = await _dailyEntries
        .where('isCompleted', isEqualTo: true)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  static Future<Map<String, double>> getDay1OpeningStock() async {
    final snap =
        await _db.collection('config').doc('day1OpeningStock').get();
    if (!snap.exists) return {};
    final data = snap.data() as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, (v as num).toDouble()));
  }

  static Future<void> setDay1OpeningStock(Map<String, double> stock) async {
    await _db.collection('config').doc('day1OpeningStock').set(stock);
  }

  // Writes opening stock directly into today's productEntries subcollection.
  // Does NOT create a parent dailyEntry doc, so hasAnyCompletedEntries stays correct.
  static Future<void> saveDay1OpeningStockToProductEntries(
    String todayId,
    Map<String, double> openingStock,
    List<Product> products,
  ) async {
    final batch = _db.batch();
    final entryRef = _dailyEntries.doc(todayId);
    for (final p in products) {
      final amount = openingStock[p.id] ?? 0;
      batch.set(
        entryRef.collection('productEntries').doc(p.id),
        {
          'productId': p.id,
          'productName': p.name,
          'productType': p.type,
          'openingStock': amount,
          'stockAdded': 0.0,
          'remainingStock': 0.0,
          'estimatedSold': 0.0,
          'priceUsed': p.currentPrice,
          'expectedRevenue': 0.0,
          'accountableSold': 0.0,
          'minimumExpected': 0.0,
          'variance': 0.0,
        },
      );
    }
    await batch.commit();
  }

  // Returns wastage bag weights from yesterday's productEntries keyed by productId.
  static Future<Map<String, double>> getYesterdayWastageBagWeights(
      DateTime date) async {
    final yesterdayId = dateToId(date.subtract(const Duration(days: 1)));
    final entries = await getProductEntriesForDate(yesterdayId);
    final result = <String, double>{};
    for (final pe in entries) {
      if (pe.wastageBagWeight != null) {
        result[pe.productId] = pe.wastageBagWeight!;
      }
    }
    return result;
  }

  // Writes opening balances into today's dailyEntry with isCompleted: false so
  // NightlyEntry does not treat this as a completed entry.
  static Future<void> saveDay1OpeningBalancesToEntry(
      String todayId, double mpesa, double cash) async {
    await _dailyEntries.doc(todayId).set(
      {
        'mpesaOpeningBalance': mpesa,
        'cashOpeningBalance': cash,
        'isCompleted': false,
        'date': Timestamp.fromDate(idToDate(todayId)),
      },
      SetOptions(merge: true),
    );
  }

  // ─── Initial Balances ──────────────────────────────────────────────────────

  static Future<void> setInitialBalances(double mpesa, double cash) async {
    await _db.collection('config').doc('initialBalances').set({
      'mpesa': mpesa,
      'cash': cash,
      'updatedAt': Timestamp.now(),
    });
  }

  static Future<Map<String, double>> getInitialBalances() async {
    final snap = await _db.collection('config').doc('initialBalances').get();
    if (!snap.exists) return {'mpesa': 0, 'cash': 0};
    final data = snap.data() as Map<String, dynamic>;
    return {
      'mpesa': (data['mpesa'] ?? 0).toDouble(),
      'cash': (data['cash'] ?? 0).toDouble(),
    };
  }

  // ─── Sales (employee log — isolated from all accounting calculations) ─────

  static Future<void> addSale(Sale sale) async {
    await _sales.doc(sale.id).set(sale.toFirestore());
  }

  static Future<void> updateSalePaymentMethod(String saleId, String paymentMethod) async {
    await _sales.doc(saleId).update({'paymentMethod': paymentMethod});
  }

  static Stream<List<Sale>> salesStreamForDate(String dateId) {
    final startOfDay = idToDate(dateId);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    return _sales
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
        .where('date', isLessThan: Timestamp.fromDate(endOfDay))
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Sale.fromFirestore(d)).toList());
  }

  static Stream<List<Sale>> allSalesStream() {
    return _sales
        .orderBy('date', descending: true)
        .snapshots()
        .map((s) => s.docs.map((d) => Sale.fromFirestore(d)).toList());
  }

  static Future<List<Sale>> getAllSales() async {
    final snap = await _sales.orderBy('date', descending: true).get();
    return snap.docs.map((d) => Sale.fromFirestore(d)).toList();
  }

  static Future<List<Sale>> getSalesForRange(
      DateTime from, DateTime to) async {
    final snap = await _sales
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThan: Timestamp.fromDate(to))
        .orderBy('date', descending: true)
        .get();
    return snap.docs.map((d) => Sale.fromFirestore(d)).toList();
  }

  // ─── Employee PIN ──────────────────────────────────────────────────────────

  static Future<String?> getEmployeePin() async {
    final snap =
        await _db.collection('config').doc('app_config').get();
    if (!snap.exists) return null;
    final data = snap.data() as Map<String, dynamic>;
    return data['employeePin'] as String?;
  }

  static Future<void> setEmployeePin(String pin) async {
    await _db.collection('config').doc('app_config').set(
      {'employeePin': pin},
      SetOptions(merge: true),
    );
  }

  static Future<void> clearEmployeePin() async {
    await _db.collection('config').doc('app_config').update(
      {'employeePin': FieldValue.delete()},
    );
  }

  // ─── New Product Opening Stock ────────────────────────────────────────────

  static Future<void> saveNewProductOpeningStock(
      Product product, double openingStock) async {
    final todayId = dateToId(DateTime.now());
    final entryRef = _dailyEntries.doc(todayId);
    final snap = await entryRef.get();
    if (!snap.exists) {
      await entryRef.set({
        'date': Timestamp.fromDate(idToDate(todayId)),
        'isCompleted': false,
      });
    }
    await entryRef.collection('productEntries').doc(product.id).set({
      'productId': product.id,
      'productName': product.name,
      'productType': product.type,
      'openingStock': openingStock,
      'stockAdded': 0.0,
      'remainingStock': 0.0,
      'estimatedSold': 0.0,
      'priceUsed': product.currentPrice,
      'expectedRevenue': 0.0,
      'accountableSold': 0.0,
      'minimumExpected': 0.0,
      'variance': 0.0,
    });
  }

  // ─── Delete All Data ───────────────────────────────────────────────────────

  static Future<void> deleteAllData() async {
    final futures = <Future>[];

    // Delete all stock additions
    final stockSnap = await _stockAdditions.get();
    for (final doc in stockSnap.docs) {
      futures.add(doc.reference.delete());
    }

    // Delete all daily entries (and their subcollections)
    final entriesSnap = await _dailyEntries.get();
    for (final doc in entriesSnap.docs) {
      final subSnap = await doc.reference.collection('productEntries').get();
      for (final sub in subSnap.docs) {
        futures.add(sub.reference.delete());
      }
      futures.add(doc.reference.delete());
    }

    // Delete products
    final productsSnap = await _products.get();
    for (final doc in productsSnap.docs) {
      final priceHistorySnap = await doc.reference.collection('priceHistory').get();
      for (final ph in priceHistorySnap.docs) {
        futures.add(ph.reference.delete());
      }
      futures.add(doc.reference.delete());
    }

    // Delete config
    futures.add(_db.collection('config').doc('initialBalances').delete());
    futures.add(_db.collection('config').doc('day1OpeningStock').delete());

    await Future.wait(futures);
  }
}
