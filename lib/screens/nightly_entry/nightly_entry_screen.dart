import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app_theme.dart';
import '../../models/daily_entry.dart';
import '../../models/product.dart';
import '../../models/product_entry.dart';
import '../../models/stock_addition.dart';
import '../../services/firestore_service.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

// Fixed wastage buffer subtracted from accountable sold when bag weight is used
const double _kWastageBuffer = 0.2;

class NightlyEntryScreen extends StatefulWidget {
  const NightlyEntryScreen({super.key});

  @override
  State<NightlyEntryScreen> createState() => _NightlyEntryScreenState();
}

class _NightlyEntryScreenState extends State<NightlyEntryScreen> {
  final _today = DateTime.now();
  late final String _todayId = dateToId(_today);

  bool _loading = true;
  bool _saving = false;
  bool _hasExistingEntry = false;

  // True when there is no completed yesterday entry → first time recording wastage
  bool _isDay1Wastage = true;

  List<Product> _products = [];
  List<StockAddition> _todayAdditions = [];
  Map<String, double> _openingStocks = {};
  Map<String, double> _openingBalances = {};
  Map<String, double> _stockAddedByProduct = {};
  Map<String, double> _priceByProduct = {};
  // Yesterday's wastage bag weights per product (empty on Day 1)
  Map<String, double> _yesterdayBagWeights = {};
  // New batch detection per product (yesterday = 0, today has additions)
  Map<String, bool> _isNewBatchByProduct = {};

  final Map<String, TextEditingController> _remainingControllers = {};
  final Map<String, TextEditingController> _bagWeightControllers = {};
  final _mpesaClosingCtrl = TextEditingController();
  final _cashClosingCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _remainingControllers.values) c.dispose();
    for (final c in _bagWeightControllers.values) c.dispose();
    _mpesaClosingCtrl.dispose();
    _cashClosingCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final products = await FirestoreService.getProducts();
      final activeProducts = products.where((p) => p.isActive).toList();
      final additions =
          await FirestoreService.getStockAdditionsForDate(_todayId);
      final openingStocks =
          await FirestoreService.getOpeningStockForDate(_today);
      final openingBalances =
          await FirestoreService.getOpeningBalancesForDate(_today);
      final existingEntry = await FirestoreService.getEntryForDate(_todayId);

      // Determine whether yesterday had a completed entry
      final yesterdayId =
          dateToId(_today.subtract(const Duration(days: 1)));
      final yesterdayEntry =
          await FirestoreService.getEntryForDate(yesterdayId);
      final isDay1 =
          yesterdayEntry == null || !yesterdayEntry.isCompleted;

      // Yesterday's bag weights (needed for actualWastage calculation)
      final yesterdayBags = isDay1
          ? <String, double>{}
          : await FirestoreService.getYesterdayWastageBagWeights(_today);

      // Get yesterday's remaining stock to detect new batches
      final yesterdayProductEntries = isDay1
          ? <String, double>{}
          : await FirestoreService.getProductEntriesForDate(yesterdayId)
              .then((entries) => {for (final e in entries) e.productId: e.remainingStock});

      // Stock added per product
      final stockAddedMap = <String, double>{};
      for (final a in additions) {
        stockAddedMap[a.productId] =
            (stockAddedMap[a.productId] ?? 0) + a.sellableAmount;
      }

      // Detect new batch per product: yesterday = 0 AND today has stock additions
      final isNewBatch = <String, bool>{};
      for (final p in activeProducts) {
        final yesterdayRemaining = yesterdayProductEntries[p.id] ?? 0;
        final todayAdded = stockAddedMap[p.id] ?? 0;
        isNewBatch[p.id] = yesterdayRemaining == 0 && todayAdded > 0;
      }

      // Price per product
      final priceMap = <String, double>{};
      for (final p in activeProducts) {
        priceMap[p.id] = await FirestoreService.getPriceForDate(p.id, _today);
      }

      // Build controllers
      final remainingMap = <String, TextEditingController>{};
      final bagMap = <String, TextEditingController>{};
      for (final p in activeProducts) {
        remainingMap[p.id] = TextEditingController();
        if (p.isWeightBased) {
          bagMap[p.id] = TextEditingController();
        }
      }

      // Pre-fill from completed entry
      final isRealEntry = existingEntry != null && existingEntry.isCompleted;
      if (isRealEntry) {
        final existingPEs =
            await FirestoreService.getProductEntriesForDate(_todayId);
        _mpesaClosingCtrl.text =
            existingEntry.mpesaClosingBalance.toStringAsFixed(2);
        _cashClosingCtrl.text =
            existingEntry.cashClosingBalance.toStringAsFixed(2);
        for (final pe in existingPEs) {
          remainingMap[pe.productId]?.text =
              pe.remainingStock.toStringAsFixed(2);
          if (pe.wastageBagWeight != null) {
            bagMap[pe.productId]?.text =
                pe.wastageBagWeight!.toStringAsFixed(2);
          }
        }
      }

      setState(() {
        _products = activeProducts;
        _todayAdditions = additions;
        _openingStocks = openingStocks;
        _openingBalances = openingBalances;
        _stockAddedByProduct = stockAddedMap;
        _priceByProduct = priceMap;
        _yesterdayBagWeights = yesterdayBags;
        _isNewBatchByProduct = isNewBatch;
        _isDay1Wastage = isDay1;
        _remainingControllers.addAll(remainingMap);
        _bagWeightControllers.addAll(bagMap);
        _hasExistingEntry = isRealEntry;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  // ─── Calculations ────────────────────────────────────────────────────────────

  double _openingFor(Product p) => _openingStocks[p.id] ?? 0;
  double _addedFor(Product p) => _stockAddedByProduct[p.id] ?? 0;
  double _availableFor(Product p) => _openingFor(p) + _addedFor(p);

  double _remainingFor(Product p) {
    final text = _remainingControllers[p.id]?.text ?? '';
    return double.tryParse(text) ?? 0;
  }

  double _estimatedSoldFor(Product p) {
    final sold = _availableFor(p) - _remainingFor(p);
    return sold < 0 ? 0 : sold;
  }

  double? _wastageBagFor(Product p) {
    if (!p.isWeightBased) return null;
    final text = _bagWeightControllers[p.id]?.text ?? '';
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  double? _actualWastageFor(Product p) {
    if (!p.isWeightBased) return null;
    final tonight = _wastageBagFor(p);
    if (tonight == null) return null;
    if (_isDay1Wastage) return null; // Day 1: just recording, no delta yet

    // New batch detection: yesterday = 0 kg AND today has stock additions
    if (_isNewBatchByProduct[p.id] == true) return null; // Baseline for new batch

    final yesterday = _yesterdayBagWeights[p.id];
    if (yesterday == null) return null;
    final delta = tonight - yesterday;
    return delta < 0 ? 0 : delta;
  }

  double _accountableSoldFor(Product p) {
    final estimated = _estimatedSoldFor(p);
    if (!p.isWeightBased) return estimated;
    final actualWastage = _actualWastageFor(p);
    if (actualWastage == null) return estimated; // no bag entered
    final accountable = estimated - actualWastage - _kWastageBuffer;
    return accountable < 0 ? 0 : accountable;
  }

  double _minimumExpectedFor(Product p) {
    return _accountableSoldFor(p) * (_priceByProduct[p.id] ?? p.currentPrice);
  }

  double _expectedRevenueFor(Product p) {
    return _estimatedSoldFor(p) * (_priceByProduct[p.id] ?? p.currentPrice);
  }

  double get _mpesaStockExpenses => _todayAdditions
      .where((a) => a.paymentMethod == 'mpesa')
      .fold(0, (sum, a) => sum + a.costPaid);

  double get _cashStockExpenses => _todayAdditions
      .where((a) => a.paymentMethod == 'cash')
      .fold(0, (sum, a) => sum + a.costPaid);

  double get _mpesaOpeningBalance => _openingBalances['mpesa'] ?? 0;
  double get _cashOpeningBalance => _openingBalances['cash'] ?? 0;

  double get _mpesaClosing => double.tryParse(_mpesaClosingCtrl.text) ?? 0;
  double get _cashClosing => double.tryParse(_cashClosingCtrl.text) ?? 0;

  double get _mpesaReceived =>
      _mpesaClosing - _mpesaOpeningBalance + _mpesaStockExpenses;
  double get _cashReceived =>
      _cashClosing - _cashOpeningBalance + _cashStockExpenses;
  double get _totalReceived => _mpesaReceived + _cashReceived;

  double get _totalExpectedMinimum =>
      _products.fold(0, (sum, p) => sum + _minimumExpectedFor(p));

  double get _variance => _totalReceived - _totalExpectedMinimum;

  // ─── Save ────────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final productEntries = _products.map((p) {
        final estimated = _estimatedSoldFor(p);
        final accountable = _accountableSoldFor(p);
        final price = _priceByProduct[p.id] ?? p.currentPrice;
        final minExpected = _minimumExpectedFor(p);
        final expectedRev = _expectedRevenueFor(p);
        return ProductEntry(
          productId: p.id,
          productName: p.name,
          productType: p.type,
          openingStock: _openingFor(p),
          stockAdded: _addedFor(p),
          remainingStock: _remainingFor(p),
          estimatedSold: estimated,
          priceUsed: price,
          expectedRevenue: expectedRev,
          accountableSold: accountable,
          minimumExpected: minExpected,
          variance: (minExpected > 0)
              ? (_totalReceived / _products.length) - minExpected
              : 0,
          wastageBagWeight: _wastageBagFor(p),
          actualWastage: _actualWastageFor(p),
        );
      }).toList();

      final entry = DailyEntry(
        id: _todayId,
        date: _today,
        mpesaOpeningBalance: _mpesaOpeningBalance,
        mpesaClosingBalance: _mpesaClosing,
        cashOpeningBalance: _cashOpeningBalance,
        cashClosingBalance: _cashClosing,
        mpesaStockExpenses: _mpesaStockExpenses,
        cashStockExpenses: _cashStockExpenses,
        mpesaReceived: _mpesaReceived,
        cashReceived: _cashReceived,
        totalReceived: _totalReceived,
        totalExpectedMinimum: _totalExpectedMinimum,
        variance: _variance,
        isFlagged: _variance < 0,
        createdAt: DateTime.now(),
      );

      await FirestoreService.saveDailyEntry(entry, productEntries);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Entry saved successfully!')),
        );
        setState(() => _hasExistingEntry = true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Today's Entry"),
        content: const Text(
            "Are you sure you want to delete tonight's entry? This cannot be undone."),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _saving = true);
    try {
      await FirestoreService.deleteDailyEntry(_todayId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Today's entry deleted.")),
        );
        _mpesaClosingCtrl.clear();
        _cashClosingCtrl.clear();
        for (final c in _remainingControllers.values) c.clear();
        for (final c in _bagWeightControllers.values) c.clear();
        setState(() => _hasExistingEntry = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Delete failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nightly Entry'),
            Text(
              formatDate(_today),
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w400,
                  color: Colors.grey),
            ),
          ],
        ),
        actions: [
          if (_hasExistingEntry)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: kRed),
              tooltip: "Delete today's entry",
              onPressed: _deleteEntry,
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: _loading
          ? const LoadingWidget(message: 'Loading today\'s data…')
          : _products.isEmpty
              ? const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No active products',
                  subtitle: 'Add products in Settings first.',
                )
              : Stack(
                  children: [
                    _buildForm(),
                    if (_saving)
                      const ColoredBox(
                        color: Colors.black26,
                        child: Center(
                          child: CircularProgressIndicator(color: kPrimary),
                        ),
                      ),
                  ],
                ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_hasExistingEntry)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: AppCard(
                color: const Color(0xFFE3F2FD),
                child: Row(
                  children: [
                    const Icon(Icons.edit_note, color: Color(0xFF1565C0)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Editing tonight's saved entry. Changes will overwrite the saved data.",
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: const Color(0xFF1565C0),
                            ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Section 1: Stock Remaining ───────────────────────────────────
          _sectionHeader('1. Stock Remaining Tonight'),
          ..._products.map((p) => _StockEntryCard(
                product: p,
                opening: _openingFor(p),
                added: _addedFor(p),
                remainingController: _remainingControllers[p.id]!,
                bagWeightController: _bagWeightControllers[p.id],
                isDay1Wastage: _isDay1Wastage,
                isNewBatch: _isNewBatchByProduct[p.id] ?? false,
                yesterdayBagWeight: _yesterdayBagWeights[p.id],
                onChanged: () => setState(() {}),
              )),

          const SizedBox(height: 24),

          // ── Section 2: Money ─────────────────────────────────────────────
          _sectionHeader('2. Money'),
          _MoneySection(
            mpesaClosingCtrl: _mpesaClosingCtrl,
            cashClosingCtrl: _cashClosingCtrl,
            mpesaOpening: _mpesaOpeningBalance,
            cashOpening: _cashOpeningBalance,
            mpesaStockExpenses: _mpesaStockExpenses,
            cashStockExpenses: _cashStockExpenses,
            mpesaReceived: _mpesaReceived,
            cashReceived: _cashReceived,
            totalReceived: _totalReceived,
            onChanged: () => setState(() {}),
          ),

          const SizedBox(height: 24),

          // ── Section 3: Review & Save ─────────────────────────────────────
          _sectionHeader('3. Review & Save'),
          ..._products.map((p) => _ReviewCard(
                product: p,
                available: _availableFor(p),
                remaining: _remainingFor(p),
                estimated: _estimatedSoldFor(p),
                accountable: _accountableSoldFor(p),
                actualWastage: _actualWastageFor(p),
                minimumExpected: _minimumExpectedFor(p),
                price: _priceByProduct[p.id] ?? p.currentPrice,
                isDay1Wastage: _isDay1Wastage,
                isNewBatch: _isNewBatchByProduct[p.id] ?? false,
                hasWastageBag: _wastageBagFor(p) != null,
              )),

          const SizedBox(height: 16),
          _OverallSummary(
            totalExpected: _totalExpectedMinimum,
            totalReceived: _totalReceived,
            variance: _variance,
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: Text(_hasExistingEntry ? 'Update Entry' : 'Save Entry'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: kPrimary,
            ),
      ),
    );
  }
}

// ─── Stock Entry Card ─────────────────────────────────────────────────────────

class _StockEntryCard extends StatelessWidget {
  final Product product;
  final double opening;
  final double added;
  final TextEditingController remainingController;
  final TextEditingController? bagWeightController;
  final bool isDay1Wastage;
  final bool isNewBatch;
  final double? yesterdayBagWeight;
  final VoidCallback onChanged;

  const _StockEntryCard({
    required this.product,
    required this.opening,
    required this.added,
    required this.remainingController,
    required this.bagWeightController,
    required this.isDay1Wastage,
    required this.isNewBatch,
    required this.yesterdayBagWeight,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final available = opening + added;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                TypeBadge(productType: product.type),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _InfoPill('Opening', formatWeight(opening, product.type)),
                const SizedBox(width: 8),
                _InfoPill('Added', formatWeight(added, product.type)),
                const SizedBox(width: 8),
                _InfoPill(
                    'Available', formatWeight(available, product.type),
                    highlight: true),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: remainingController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,3}')),
              ],
              onChanged: (_) => onChanged(),
              decoration: InputDecoration(
                labelText: 'Remaining tonight',
                suffixText: product.isWeightBased ? 'kg' : 'units',
                hintText: '0',
                helperText: product.isWeightBased ? null : 'Decimals allowed (e.g., 0.5, 1.5)',
              ),
            ),

            // Wastage bag weight — weight-based products only
            if (product.isWeightBased && bagWeightController != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: bagWeightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,3}')),
                ],
                onChanged: (_) => onChanged(),
                decoration: InputDecoration(
                  labelText: 'Wastage bag weight tonight',
                  suffixText: 'kg',
                  hintText: '0',
                  helperText: isDay1Wastage
                      ? 'Day 1 — recording for reference, tracking starts tomorrow'
                      : isNewBatch
                          ? 'New batch detected — baseline recorded, tracking starts tomorrow'
                          : yesterdayBagWeight != null
                              ? 'Last night: ${yesterdayBagWeight!.toStringAsFixed(2)} kg'
                              : 'No last night data',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoPill(this.label, this.value, {this.highlight = false});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        decoration: BoxDecoration(
          color:
              highlight ? kPrimary.withValues(alpha: 0.08) : Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: highlight ? kPrimary : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Money Section ────────────────────────────────────────────────────────────

class _MoneySection extends StatelessWidget {
  final TextEditingController mpesaClosingCtrl;
  final TextEditingController cashClosingCtrl;
  final double mpesaOpening;
  final double cashOpening;
  final double mpesaStockExpenses;
  final double cashStockExpenses;
  final double mpesaReceived;
  final double cashReceived;
  final double totalReceived;
  final VoidCallback onChanged;

  const _MoneySection({
    required this.mpesaClosingCtrl,
    required this.cashClosingCtrl,
    required this.mpesaOpening,
    required this.cashOpening,
    required this.mpesaStockExpenses,
    required this.cashStockExpenses,
    required this.mpesaReceived,
    required this.cashReceived,
    required this.totalReceived,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            controller: mpesaClosingCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'M-Pesa closing balance tonight',
              prefixText: 'KES ',
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'M-Pesa received today: ${formatCurrency(mpesaReceived)}',
              style: TextStyle(
                fontSize: 12,
                color: mpesaReceived >= 0 ? Colors.grey[600] : kRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 24),
          TextFormField(
            controller: cashClosingCtrl,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
            ],
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Cash count tonight',
              prefixText: 'KES ',
            ),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: Text(
              'Cash received today: ${formatCurrency(cashReceived)}',
              style: TextStyle(
                fontSize: 12,
                color: cashReceived >= 0 ? Colors.grey[600] : kRed,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total received today',
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              Text(
                formatCurrency(totalReceived),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'Stock expenses (M-Pesa: ${formatCurrency(mpesaStockExpenses)}, '
              'Cash: ${formatCurrency(cashStockExpenses)}) have been factored in '
              'automatically from today\'s stock additions.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Review Card ──────────────────────────────────────────────────────────────

class _ReviewCard extends StatelessWidget {
  final Product product;
  final double available;
  final double remaining;
  final double estimated;
  final double accountable;
  final double? actualWastage;
  final double minimumExpected;
  final double price;
  final bool isDay1Wastage;
  final bool isNewBatch;
  final bool hasWastageBag;

  const _ReviewCard({
    required this.product,
    required this.available,
    required this.remaining,
    required this.estimated,
    required this.accountable,
    required this.actualWastage,
    required this.minimumExpected,
    required this.price,
    required this.isDay1Wastage,
    required this.isNewBatch,
    required this.hasWastageBag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    product.name,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                StatusChip(isGood: minimumExpected >= 0),
              ],
            ),
            const SizedBox(height: 10),
            _row(context, 'Available → Remaining → Sold',
                '${formatWeight(available, product.type)} → ${formatWeight(remaining, product.type)} → ${formatWeight(estimated, product.type)}'),

            if (product.isWeightBased) ...[
              if (isDay1Wastage && hasWastageBag)
                // Day 1: just recorded, no calculation yet
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: Colors.blue[700]),
                        const SizedBox(width: 6),
                        Text(
                          'Wastage tracking starts tomorrow',
                          style: TextStyle(
                              fontSize: 11, color: Colors.blue[700]),
                        ),
                      ],
                    ),
                  ),
                )
              else if (isNewBatch && hasWastageBag)
                // New batch: baseline recorded
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.refresh_rounded,
                            size: 14, color: Colors.green[700]),
                        const SizedBox(width: 6),
                        Text(
                          'New batch — baseline recorded',
                          style: TextStyle(
                              fontSize: 11, color: Colors.green[700]),
                        ),
                      ],
                    ),
                  ),
                )
              else if (!isDay1Wastage && actualWastage != null) ...[
                _row(context, 'Actual wastage',
                    formatWeight(actualWastage!, product.type)),
                _row(context, 'Buffer', formatWeight(_kWastageBuffer, product.type)),
                _row(context, 'Accountable sold',
                    formatWeight(accountable, product.type)),
              ],
            ],

            _row(context, 'Price used',
                '${formatCurrency(price)} / ${product.isWeightBased ? 'kg' : 'unit'}'),
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Minimum expected',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w600)),
                Text(
                  formatCurrency(minimumExpected),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[600])),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(value,
                textAlign: TextAlign.end,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Overall Summary ──────────────────────────────────────────────────────────

class _OverallSummary extends StatelessWidget {
  final double totalExpected;
  final double totalReceived;
  final double variance;

  const _OverallSummary({
    required this.totalExpected,
    required this.totalReceived,
    required this.variance,
  });

  @override
  Widget build(BuildContext context) {
    final isOk = variance >= 0;
    return AppCard(
      color: isOk ? kGreenLight : kRedLight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _summaryRow(context, 'Total expected minimum',
              formatCurrency(totalExpected)),
          _summaryRow(context, 'Total received', formatCurrency(totalReceived)),
          const Divider(),
          _summaryRow(context, 'Variance', formatVariance(variance),
              valueColor: isOk ? kGreen : kRed, bold: true),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isOk ? kGreen : kRed,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isOk
                      ? Icons.check_circle_rounded
                      : Icons.warning_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  isOk
                      ? 'Within tolerance ✓'
                      : 'Shortfall of ${formatCurrency(variance.abs())} — investigate',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryRow(BuildContext context, String label, String value,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: valueColor,
                ),
          ),
        ],
      ),
    );
  }
}
