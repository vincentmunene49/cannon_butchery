import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/daily_entry.dart';
import '../../models/product.dart';
import '../../models/product_entry.dart';
import '../../models/sale.dart';
import '../../models/stock_addition.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late final _tabController = TabController(length: 7, vsync: this);

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: kPrimary,
          labelColor: kPrimary,
          unselectedLabelColor: Colors.grey,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Daily'),
            Tab(text: 'Revenue'),
            Tab(text: 'Profit & Margins'),
            Tab(text: 'Accountability'),
            Tab(text: 'Trends'),
            Tab(text: 'Sales Log'),
            Tab(text: 'Product Sales'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _DailyTab(),
          _RevenueTab(),
          _ProfitTab(),
          _AccountabilityTab(),
          _TrendsTab(),
          _SalesTab(),
          _ProductSalesTab(),
        ],
      ),
    );
  }
}

// ─── Daily Tab ─────────────────────────────────────────────────────────────────

class _DailyTab extends StatefulWidget {
  const _DailyTab();

  @override
  State<_DailyTab> createState() => _DailyTabState();
}

class _DailyTabState extends State<_DailyTab> {
  DateTime _selectedDate = DateTime.now();
  bool _loading = false;
  DailyEntry? _entry;
  List<ProductEntry> _productEntries = [];
  // Bag weights from the day before _selectedDate, keyed by productId
  Map<String, double> _prevDayBagWeights = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final dateId = dateToId(_selectedDate);
    final entry = await FirestoreService.getEntryForDate(dateId);
    final pes = entry != null
        ? await FirestoreService.getProductEntriesForDate(dateId)
        : <ProductEntry>[];
    final prevBags =
        await FirestoreService.getYesterdayWastageBagWeights(_selectedDate);
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _productEntries = pes;
      _prevDayBagWeights = prevBags;
      _loading = false;
    });
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _load();
    }
  }

  Future<void> _deleteEntry() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Entry'),
        content: Text('Delete entry for ${formatShortDate(_selectedDate)}?'),
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
    await FirestoreService.deleteDailyEntry(dateToId(_selectedDate));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Date picker bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(formatDate(_selectedDate)),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    foregroundColor: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_loading)
          const Expanded(child: LoadingWidget())
        else if (_entry == null)
          Expanded(
            child: EmptyState(
              icon: Icons.event_busy_outlined,
              title: 'No entry for ${formatShortDate(_selectedDate)}',
              subtitle: 'Nightly entries appear here after saving.',
            ),
          )
        else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Column(
                children: [
                  // Verdict
                  _VerdictBanner(entry: _entry!),
                  const SizedBox(height: 16),

                  // Money
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Money',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 12),
                        _kv('M-Pesa received',
                            formatCurrency(_entry!.mpesaReceived)),
                        _kv('Cash received',
                            formatCurrency(_entry!.cashReceived)),
                        const Divider(),
                        _kv('Total received',
                            formatCurrency(_entry!.totalReceived),
                            bold: true),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Per product
                  ..._productEntries.map((pe) {
                    final prevBag = _prevDayBagWeights[pe.productId];
                    final isDay1Wastage =
                        pe.wastageBagWeight != null && pe.actualWastage == null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(pe.productName,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w700)),
                                ),
                                TypeBadge(productType: pe.productType),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _kv('Opening',
                                formatWeight(pe.openingStock, pe.productType)),
                            _kv('Added',
                                formatWeight(pe.stockAdded, pe.productType)),
                            _kv(
                                'Remaining',
                                formatWeight(
                                    pe.remainingStock, pe.productType)),
                            _kv('Estimated sold',
                                formatWeight(pe.estimatedSold, pe.productType)),

                            // Wastage section — weight-based products only
                            if (pe.isWeightBased) ...[
                              const Divider(height: 16),
                              if (pe.wastageBagWeight != null)
                                _kv('Wastage bag tonight',
                                    '${pe.wastageBagWeight!.toStringAsFixed(2)} kg'),
                              if (!isDay1Wastage && prevBag != null)
                                _kv('Wastage bag last night',
                                    '${prevBag.toStringAsFixed(2)} kg'),
                              if (isDay1Wastage) ...[
                                _kvCustom(
                                  context,
                                  'Actual wastage',
                                  'Tracking starts tomorrow',
                                  valueColor: Colors.blue[700],
                                ),
                                _kv(
                                    'Accountable sold',
                                    formatWeight(
                                        pe.estimatedSold, pe.productType)),
                              ] else if (pe.actualWastage != null) ...[
                                _kv(
                                    'Actual wastage',
                                    formatWeight(
                                        pe.actualWastage!, pe.productType)),
                                _kv(
                                    'Accountable sold',
                                    formatWeight(
                                        pe.accountableSold, pe.productType)),
                              ],
                              const Divider(height: 16),
                            ],

                            _kv('Price used', formatCurrency(pe.priceUsed)),
                            if (!pe.isWeightBased) const Divider(),
                            _kv('Min expected',
                                formatCurrency(pe.minimumExpected),
                                bold: true),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _deleteEntry,
                      icon: const Icon(Icons.delete_outline, color: kRed),
                      label: const Text("Delete this day's entry"),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: kRed,
                        side: const BorderSide(color: kRed),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: bold ? FontWeight.w700 : null,
                  )),
          Text(v,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  )),
        ],
      ),
    );
  }

  Widget _kvCustom(BuildContext context, String k, String v,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600])),
          Text(v,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600, color: valueColor)),
        ],
      ),
    );
  }
}

class _VerdictBanner extends StatelessWidget {
  final DailyEntry entry;
  const _VerdictBanner({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isOk = entry.variance >= 0;
    return AppCard(
      color: isOk ? kGreenLight : kRedLight,
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Expected min',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text(formatCurrency(entry.totalExpectedMinimum),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Total received',
                  style: Theme.of(context).textTheme.bodyMedium),
              Text(formatCurrency(entry.totalReceived),
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Variance',
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              Text(
                formatVariance(entry.variance),
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: isOk ? kGreen : kRed,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          StatusChip(
            isGood: isOk,
            customLabel: isOk ? 'Within tolerance' : 'Shortfall',
          ),
        ],
      ),
    );
  }
}

// ─── Revenue Tab ───────────────────────────────────────────────────────────────

class _RevenueTab extends StatefulWidget {
  const _RevenueTab();

  @override
  State<_RevenueTab> createState() => _RevenueTabState();
}

class _RevenueTabState extends State<_RevenueTab> {
  int _range = 0; // 0=week, 1=month, 2=all
  bool _loading = true;
  List<DailyEntry> _entries = [];
  List<ProductEntry> _productEntries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await FirestoreService.getAllEntries();
    final allPEs = <ProductEntry>[];
    for (final e in entries) {
      final pes = await FirestoreService.getProductEntriesForDate(e.id);
      allPEs.addAll(pes);
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _productEntries = allPEs;
      _loading = false;
    });
  }

  List<DailyEntry> get _filteredEntries {
    final now = DateTime.now();
    return _entries.where((e) {
      if (_range == 0) {
        return e.date.isAfter(now.subtract(const Duration(days: 7)));
      }
      if (_range == 1) {
        return e.date.isAfter(now.subtract(const Duration(days: 30)));
      }
      return true;
    }).toList();
  }

  Map<String, double> _revenueByProduct() {
    final filtered = _filteredEntries.map((e) => e.id).toSet();
    final result = <String, double>{};
    for (final pe in _productEntries) {
      // We need daily entry date — we stored it on entry id
      // Use all if all time, else filter by entry date
      if (_range == 2 || filtered.isNotEmpty) {
        result[pe.productName] =
            (result[pe.productName] ?? 0) + pe.minimumExpected;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();

    final revenue = _revenueByProduct();
    final sorted = revenue.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final best = sorted.isNotEmpty ? sorted.first.key : null;

    final filtered = _filteredEntries;
    final totalReceived =
        filtered.fold<double>(0, (s, e) => s + e.totalReceived);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('This Week')),
              ButtonSegment(value: 1, label: Text('This Month')),
              ButtonSegment(value: 2, label: Text('All Time')),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: kPrimary.withValues(alpha: 0.1),
              selectedForegroundColor: kPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (filtered.isEmpty)
            const EmptyState(
              icon: Icons.bar_chart_outlined,
              title: 'No data for this period',
            )
          else ...[
            // Total card
            Row(
              children: [
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Total Received',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(formatCurrency(totalReceived),
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Best Product',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600])),
                        const SizedBox(height: 4),
                        Text(best ?? '—',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: kPrimary)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Bar chart
            if (sorted.isNotEmpty) ...[
              AppCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Revenue by Product',
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 20),
                    SizedBox(
                      height: 200,
                      child: BarChart(
                        BarChartData(
                          alignment: BarChartAlignment.spaceAround,
                          maxY: sorted.first.value * 1.2,
                          barTouchData: BarTouchData(enabled: false),
                          titlesData: FlTitlesData(
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (value, meta) {
                                  final i = value.toInt();
                                  if (i >= sorted.length) {
                                    return const SizedBox.shrink();
                                  }
                                  final name = sorted[i].key;
                                  final short = name.length > 8
                                      ? name.substring(0, 8)
                                      : name;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(short,
                                        style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500)),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 50,
                                getTitlesWidget: (value, meta) {
                                  if (value == 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Text(
                                    value >= 1000
                                        ? '${(value / 1000).toStringAsFixed(0)}K'
                                        : value.toStringAsFixed(0),
                                    style: const TextStyle(fontSize: 10),
                                  );
                                },
                              ),
                            ),
                            topTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(
                                sideTitles: SideTitles(showTitles: false)),
                          ),
                          gridData: FlGridData(
                            horizontalInterval: (sorted.first.value / 4)
                                .clamp(1.0, double.infinity),
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: Colors.grey[200]!,
                              strokeWidth: 1,
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          barGroups: sorted.asMap().entries.map((entry) {
                            return BarChartGroupData(
                              x: entry.key,
                              barRods: [
                                BarChartRodData(
                                  toY: entry.value.value,
                                  color: kPrimary,
                                  width: 20,
                                  borderRadius: const BorderRadius.vertical(
                                      top: Radius.circular(6)),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Product list
            ...sorted.map((entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: AppCard(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(entry.key,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600)),
                        Text(formatCurrency(entry.value),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: kPrimary)),
                      ],
                    ),
                  ),
                )),
          ],
        ],
      ),
    );
  }
}

// ─── Profit Tab ────────────────────────────────────────────────────────────────

class _ProfitTab extends StatefulWidget {
  const _ProfitTab();

  @override
  State<_ProfitTab> createState() => _ProfitTabState();
}

class _ProfitTabState extends State<_ProfitTab> {
  int _range = 0;
  bool _loading = true;
  List<DailyEntry> _entries = [];
  List<StockAddition> _stockAdditions = [];
  List<ProductEntry> _productEntries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await FirestoreService.getAllEntries();
    final stock = await FirestoreService.getAllStockAdditions();
    final allPEs = <ProductEntry>[];
    for (final e in entries) {
      final pes = await FirestoreService.getProductEntriesForDate(e.id);
      allPEs.addAll(pes);
    }
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _stockAdditions = stock;
      _productEntries = allPEs;
      _loading = false;
    });
  }

  List<DailyEntry> get _filteredEntries {
    final now = DateTime.now();
    return _entries.where((e) {
      if (_range == 0) {
        return e.date.isAfter(now.subtract(const Duration(days: 7)));
      }
      if (_range == 1) {
        return e.date.isAfter(now.subtract(const Duration(days: 30)));
      }
      return true;
    }).toList();
  }

  List<StockAddition> get _filteredStock {
    final now = DateTime.now();
    return _stockAdditions.where((s) {
      if (_range == 0) {
        return s.date.isAfter(now.subtract(const Duration(days: 7)));
      }
      if (_range == 1) {
        return s.date.isAfter(now.subtract(const Duration(days: 30)));
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();

    final filteredIds = _filteredEntries.map((e) => e.id).toSet();

    // Revenue per product (from productEntries in range)
    final revenueByProduct = <String, double>{};
    for (final pe in _productEntries) {
      if (filteredIds.contains(
          dateToId(pe.openingStock > 0 ? DateTime.now() : DateTime.now()))) {
        // Include all product entries for simplicity (date tracking would need productEntry date)
        revenueByProduct[pe.productName] =
            (revenueByProduct[pe.productName] ?? 0) + pe.minimumExpected;
      }
    }

    // Cost per product
    final costByProduct = <String, double>{};
    for (final s in _filteredStock) {
      costByProduct[s.productName] =
          (costByProduct[s.productName] ?? 0) + s.costPaid;
    }

    final allProducts = {
      ...revenueByProduct.keys,
      ...costByProduct.keys,
    }.toList()
      ..sort();

    final totalRevenue =
        revenueByProduct.values.fold<double>(0, (s, v) => s + v);
    final totalCost = costByProduct.values.fold<double>(0, (s, v) => s + v);
    final totalProfit = totalRevenue - totalCost;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('This Week')),
              ButtonSegment(value: 1, label: Text('This Month')),
              ButtonSegment(value: 2, label: Text('All Time')),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: kPrimary.withValues(alpha: 0.1),
              selectedForegroundColor: kPrimary,
            ),
          ),
          const SizedBox(height: 16),
          if (allProducts.isEmpty)
            const EmptyState(
              icon: Icons.pie_chart_outline,
              title: 'No data for this period',
            )
          else ...[
            AppCard(
              child: Column(
                children: [
                  _headerRow(context),
                  const Divider(),
                  ...allProducts.map((name) {
                    final rev = revenueByProduct[name] ?? 0;
                    final cost = costByProduct[name] ?? 0;
                    final profit = rev - cost;
                    final margin = rev > 0 ? (profit / rev * 100) : 0;
                    return _productRow(
                        context, name, rev, cost, profit, margin);
                  }),
                  const Divider(thickness: 2),
                  _productRow(
                    context,
                    'TOTAL',
                    totalRevenue,
                    totalCost,
                    totalProfit,
                    totalRevenue > 0 ? (totalProfit / totalRevenue * 100) : 0,
                    bold: true,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _headerRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text('Product',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700, color: Colors.grey[600]))),
          Expanded(
              child: Text('Revenue',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700, color: Colors.grey[600]))),
          Expanded(
              child: Text('Cost',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700, color: Colors.grey[600]))),
          Expanded(
              child: Text('Profit',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700, color: Colors.grey[600]))),
          Expanded(
              child: Text('Margin',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700, color: Colors.grey[600]))),
        ],
      ),
    );
  }

  Widget _productRow(BuildContext context, String name, double rev, double cost,
      double profit, num margin,
      {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
              flex: 2,
              child: Text(name,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                      ))),
          Expanded(
              child: Text('K${(rev / 1000).toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: bold ? FontWeight.w700 : null))),
          Expanded(
              child: Text('K${(cost / 1000).toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: bold ? FontWeight.w700 : null))),
          Expanded(
              child: Text('K${(profit / 1000).toStringAsFixed(1)}',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: profit >= 0 ? kGreen : kRed,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                      ))),
          Expanded(
              child: Text('${margin.toStringAsFixed(1)}%',
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: profit >= 0 ? kGreen : kRed,
                        fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                      ))),
        ],
      ),
    );
  }
}

// ─── Accountability Tab ────────────────────────────────────────────────────────

class _AccountabilityTab extends StatefulWidget {
  const _AccountabilityTab();

  @override
  State<_AccountabilityTab> createState() => _AccountabilityTabState();
}

class _AccountabilityTabState extends State<_AccountabilityTab> {
  bool _loading = true;
  List<DailyEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await FirestoreService.getAllEntries();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();

    final cumulative = _entries.fold<double>(0, (sum, e) => sum + e.variance);
    final flaggedCount = _entries.where((e) => e.isFlagged).length;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              AppCard(
                color: cumulative >= 0 ? kGreenLight : kRedLight,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Cumulative Variance (All Time)',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatVariance(cumulative),
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: cumulative >= 0 ? kGreen : kRed,
                                ),
                          ),
                        ],
                      ),
                    ),
                    Column(
                      children: [
                        Text(
                          '$flaggedCount',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: flaggedCount > 0 ? kRed : kGreen,
                              ),
                        ),
                        Text(
                          'flagged days',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_entries.isEmpty)
          const Expanded(
            child: EmptyState(
              icon: Icons.assignment_outlined,
              title: 'No entries yet',
              subtitle:
                  'Your accountability log will appear here after saving nightly entries.',
            ),
          )
        else
          Expanded(
            child: RefreshIndicator(
              color: kPrimary,
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                itemCount: _entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  return AppCard(
                    onTap: () {
                      // Navigate to daily report for this date
                      // TODO: deep link to daily tab for this date
                    },
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                formatShortDate(entry.date),
                                style: Theme.of(context)
                                    .textTheme
                                    .titleSmall
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Expected: ${formatCurrency(entry.totalExpectedMinimum)} · Received: ${formatCurrency(entry.totalReceived)}',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatVariance(entry.variance),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: entry.variance >= 0 ? kGreen : kRed,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            StatusChip(isGood: !entry.isFlagged),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Trends Tab ────────────────────────────────────────────────────────────────

class _TrendsTab extends StatefulWidget {
  const _TrendsTab();

  @override
  State<_TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<_TrendsTab> {
  static const _palette = [
    Color(0xFFE53935),
    Color(0xFF1565C0),
    Color(0xFF2E7D32),
    Color(0xFFE65100),
    Color(0xFF6A1B9A),
    Color(0xFF00838F),
    Color(0xFFAD1457),
    Color(0xFF37474F),
  ];

  bool _loading = true;
  List<DailyEntry> _entries = [];
  Map<String, List<ProductEntry>> _peByDate = {};
  Set<String> _shownVolume = {};
  Set<String> _shownWastage = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    final entries = await FirestoreService.getAllEntries();
    entries.sort((a, b) => a.date.compareTo(b.date));

    final byDate = <String, List<ProductEntry>>{};
    for (final e in entries) {
      byDate[e.id] = await FirestoreService.getProductEntriesForDate(e.id);
    }

    final volumeNames = <String>{};
    final wastageNames = <String>{};
    for (final pes in byDate.values) {
      for (final pe in pes) {
        volumeNames.add(pe.productName);
        if (pe.isWeightBased) wastageNames.add(pe.productName);
      }
    }

    if (mounted) {
      setState(() {
        _entries = entries;
        _peByDate = byDate;
        _shownVolume = Set.from(volumeNames);
        _shownWastage = Set.from(wastageNames);
        _loading = false;
      });
    }
  }

  List<DailyEntry> get _last30 {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    return _entries.where((e) => !e.date.isBefore(cutoff)).toList();
  }

  Color _colorFor(String name, List<String> sorted) {
    final i = sorted.indexOf(name) % _palette.length;
    return _palette[i < 0 ? 0 : i];
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFlaggedSummary(),
            const SizedBox(height: 20),
            _buildVarianceChart(),
            const SizedBox(height: 20),
            _buildRevenueChart(),
            const SizedBox(height: 20),
            _buildSalesVolumeChart(),
            const SizedBox(height: 20),
            _buildWastageTrendChart(),
            const SizedBox(height: 20),
            _buildWeeklyPatternChart(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Flagged Days ─────────────────────────────────────────────────────────────

  Widget _buildFlaggedSummary() {
    int countFlagged(int days) {
      final cutoff = DateTime.now().subtract(Duration(days: days));
      return _entries
          .where((e) => !e.date.isBefore(cutoff) && e.isFlagged)
          .length;
    }

    final f7 = countFlagged(7);
    final f14 = countFlagged(14);
    final f30 = countFlagged(30);
    final increasing = f7 > 0 && (f7 / 7) > (f14 / 14) + 0.01;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Flagged Days'),
        if (increasing)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              color: const Color(0xFFFFEBEE),
              child: Row(
                children: [
                  const Icon(Icons.trending_up, color: kRed, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Shortfalls are increasing — review recent entries.',
                      style: TextStyle(fontSize: 12, color: Colors.red[800]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        Row(
          children: [
            Expanded(child: _flaggedCard('Last 7 days', f7)),
            const SizedBox(width: 8),
            Expanded(child: _flaggedCard('Last 14 days', f14)),
            const SizedBox(width: 8),
            Expanded(child: _flaggedCard('Last 30 days', f30)),
          ],
        ),
      ],
    );
  }

  Widget _flaggedCard(String label, int count) {
    final ok = count == 0;
    return AppCard(
      color: ok ? kGreenLight : kRedLight,
      child: Column(
        children: [
          Text(
            '$count',
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: ok ? kGreen : kRed),
          ),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  // ── Daily Variance Line Chart ────────────────────────────────────────────────

  Widget _buildVarianceChart() {
    final data = _last30;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Daily Variance — Last 30 Days'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
          child: data.length < 2
              ? _emptyChart()
              : SizedBox(height: 200, child: LineChart(_varianceData(data))),
        ),
      ],
    );
  }

  LineChartData _varianceData(List<DailyEntry> data) {
    final spots = data
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.variance))
        .toList();
    final ys = data.map((e) => e.variance).toList();
    final minY = ys.reduce((a, b) => a < b ? a : b);
    final maxY = ys.reduce((a, b) => a > b ? a : b);
    final pad = ((maxY - minY).abs()).clamp(500.0, double.infinity) * 0.15;

    return LineChartData(
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          color: Colors.grey[400],
          barWidth: 1.5,
          isCurved: false,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
              radius: 4,
              color: spot.y >= 0 ? kGreen : kRed,
              strokeWidth: 0,
              strokeColor: Colors.transparent,
            ),
          ),
          belowBarData: BarAreaData(show: false),
        ),
      ],
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
              y: 0, color: Colors.black38, strokeWidth: 1, dashArray: [4, 4]),
        ],
      ),
      minY: minY - pad,
      maxY: maxY + pad,
      titlesData: _buildTitlesData(data.length, (i) {
        final d = data[i].date;
        return '${d.day}/${d.month}';
      },
          leftReservedSize: 54,
          leftFormatter: (v) => v >= 1000
              ? '${(v / 1000).toStringAsFixed(0)}K'
              : v.toStringAsFixed(0)),
      gridData: FlGridData(
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey[200]!, strokeWidth: 1),
        getDrawingVerticalLine: (_) =>
            FlLine(color: Colors.grey[100]!, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
    );
  }

  // ── Revenue Trend Bar Chart ──────────────────────────────────────────────────

  Widget _buildRevenueChart() {
    final data = _last30;
    final avg = data.isEmpty
        ? 0.0
        : data.fold(0.0, (s, e) => s + e.totalReceived) / data.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: _sectionTitle('Revenue — Last 30 Days')),
            Container(
                width: 20,
                height: 2,
                color: Colors.orange,
                margin: const EdgeInsets.only(right: 4)),
            Text('Avg ${formatCurrency(avg)}',
                style: const TextStyle(
                    fontSize: 11,
                    color: Colors.orange,
                    fontWeight: FontWeight.w600)),
          ],
        ),
        AppCard(
          padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
          child: data.length < 2
              ? _emptyChart()
              : SizedBox(height: 200, child: BarChart(_revenueData(data, avg))),
        ),
      ],
    );
  }

  BarChartData _revenueData(List<DailyEntry> data, double avg) {
    final maxY =
        data.map((e) => e.totalReceived).reduce((a, b) => a > b ? a : b);
    final barW = (240.0 / data.length).clamp(4.0, 16.0);

    return BarChartData(
      alignment: BarChartAlignment.spaceAround,
      maxY: maxY * 1.15,
      barTouchData: BarTouchData(enabled: false),
      barGroups: data.asMap().entries.map((e) {
        return BarChartGroupData(x: e.key, barRods: [
          BarChartRodData(
            toY: e.value.totalReceived,
            color: kPrimary.withValues(alpha: 0.8),
            width: barW,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
          ),
        ]);
      }).toList(),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
              y: avg,
              color: Colors.orange,
              strokeWidth: 1.5,
              dashArray: [6, 4]),
        ],
      ),
      titlesData: _buildTitlesData(data.length, (i) {
        final d = data[i].date;
        return '${d.day}/${d.month}';
      },
          leftReservedSize: 54,
          leftFormatter: (v) => v >= 1000
              ? '${(v / 1000).toStringAsFixed(0)}K'
              : v.toStringAsFixed(0)),
      gridData: FlGridData(
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey[200]!, strokeWidth: 1),
        drawVerticalLine: false,
      ),
      borderData: FlBorderData(show: false),
    );
  }

  // ── Sales Volume Per Product ─────────────────────────────────────────────────

  Widget _buildSalesVolumeChart() {
    final data = _last30;
    final products = _productNamesIn(data);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Sales Volume Per Product — Last 30 Days'),
        _legendChips(
            products,
            _shownVolume,
            (name, v) => setState(
                () => v ? _shownVolume.add(name) : _shownVolume.remove(name))),
        AppCard(
          padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
          child: data.length < 2
              ? _emptyChart()
              : SizedBox(
                  height: 200,
                  child: LineChart(_multiLineData(
                      data, products, _shownVolume, (pe) => pe.estimatedSold,
                      yLabel: (v) => v.toStringAsFixed(0))),
                ),
        ),
      ],
    );
  }

  // ── Wastage Trend Per Product ────────────────────────────────────────────────

  Widget _buildWastageTrendChart() {
    final data = _last30;
    final products = _weightProductNamesIn(data);
    if (products.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Wastage Bag Weight Per Product — Last 30 Days'),
        _legendChips(
            products,
            _shownWastage,
            (name, v) => setState(() =>
                v ? _shownWastage.add(name) : _shownWastage.remove(name))),
        AppCard(
          padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
          child: data.length < 2
              ? _emptyChart()
              : SizedBox(
                  height: 200,
                  child: LineChart(_multiLineData(data, products, _shownWastage,
                      (pe) => pe.wastageBagWeight,
                      yLabel: (v) => '${v.toStringAsFixed(1)}kg',
                      fillArea: true)),
                ),
        ),
      ],
    );
  }

  // ── Weekly Pattern ───────────────────────────────────────────────────────────

  Widget _buildWeeklyPatternChart() {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final buckets = List.generate(7, (_) => <double>[]);
    for (final e in _entries) {
      buckets[e.date.weekday - 1].add(e.totalReceived);
    }
    final avgs = buckets
        .map((b) => b.isEmpty ? 0.0 : b.fold(0.0, (a, v) => a + v) / b.length)
        .toList();
    final maxAvg = avgs.reduce((a, b) => a > b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Average Revenue by Day of Week'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(4, 16, 16, 8),
          child: _entries.length < 2
              ? _emptyChart()
              : SizedBox(
                  height: 200,
                  child: BarChart(BarChartData(
                    alignment: BarChartAlignment.spaceAround,
                    maxY: maxAvg == 0 ? 100 : maxAvg * 1.2,
                    barTouchData: BarTouchData(enabled: false),
                    barGroups: List.generate(7, (i) {
                      final isBest = avgs[i] == maxAvg && maxAvg > 0;
                      return BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: avgs[i],
                          color: isBest
                              ? kGreen
                              : kPrimary.withValues(alpha: 0.75),
                          width: 28,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ]);
                    }),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, _) {
                            final i = v.toInt();
                            if (i >= labels.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(labels[i],
                                  style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600)),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 54,
                          getTitlesWidget: (v, _) => Text(
                            v >= 1000
                                ? '${(v / 1000).toStringAsFixed(0)}K'
                                : v.toStringAsFixed(0),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ),
                      ),
                      topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false)),
                    ),
                    gridData: FlGridData(
                      getDrawingHorizontalLine: (_) =>
                          FlLine(color: Colors.grey[200]!, strokeWidth: 1),
                      drawVerticalLine: false,
                    ),
                    borderData: FlBorderData(show: false),
                  )),
                ),
        ),
      ],
    );
  }

  // ── Generic multi-product line chart ─────────────────────────────────────────

  LineChartData _multiLineData(
    List<DailyEntry> data,
    List<String> products,
    Set<String> shown,
    double? Function(ProductEntry) valueOf, {
    String Function(double)? yLabel,
    bool fillArea = false,
  }) {
    final bars = <LineChartBarData>[];
    for (final name in products) {
      if (!shown.contains(name)) continue;
      final color = _colorFor(name, products);
      final spots = <FlSpot>[];
      for (var i = 0; i < data.length; i++) {
        final pe = (_peByDate[data[i].id] ?? [])
            .cast<ProductEntry?>()
            .firstWhere((p) => p?.productName == name, orElse: () => null);
        final v = pe != null ? valueOf(pe) : null;
        if (v != null) spots.add(FlSpot(i.toDouble(), v));
      }
      if (spots.isEmpty) continue;
      bars.add(LineChartBarData(
        spots: spots,
        color: color,
        barWidth: 2,
        isCurved: true,
        curveSmoothness: 0.3,
        dotData: FlDotData(
          show: spots.length <= 14,
          getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
              radius: 3,
              color: color,
              strokeWidth: 0,
              strokeColor: Colors.transparent),
        ),
        belowBarData: fillArea
            ? BarAreaData(show: true, color: color.withValues(alpha: 0.06))
            : BarAreaData(show: false),
      ));
    }

    if (bars.isEmpty) {
      return LineChartData(lineBarsData: [
        LineChartBarData(
            spots: const [FlSpot(0, 0)], color: Colors.transparent),
      ]);
    }

    final allY = bars.expand((b) => b.spots.map((s) => s.y)).toList();
    final maxY = allY.reduce((a, b) => a > b ? a : b);

    return LineChartData(
      lineBarsData: bars,
      minY: 0,
      maxY: maxY == 0 ? 10 : maxY * 1.15,
      titlesData: _buildTitlesData(data.length, (i) {
        final d = data[i].date;
        return '${d.day}/${d.month}';
      },
          leftReservedSize: 42,
          leftFormatter: yLabel ?? (v) => v.toStringAsFixed(0)),
      gridData: FlGridData(
        getDrawingHorizontalLine: (_) =>
            FlLine(color: Colors.grey[200]!, strokeWidth: 1),
        getDrawingVerticalLine: (_) =>
            FlLine(color: Colors.grey[100]!, strokeWidth: 1),
      ),
      borderData: FlBorderData(show: false),
    );
  }

  // ── Reusable helpers ─────────────────────────────────────────────────────────

  List<String> _productNamesIn(List<DailyEntry> data) {
    final s = <String>{};
    for (final e in data) {
      for (final pe in _peByDate[e.id] ?? []) {
        s.add(pe.productName);
      }
    }
    return s.toList()..sort();
  }

  List<String> _weightProductNamesIn(List<DailyEntry> data) {
    final s = <String>{};
    for (final e in data) {
      for (final pe in _peByDate[e.id] ?? []) {
        if (pe.isWeightBased) s.add(pe.productName);
      }
    }
    return s.toList()..sort();
  }

  FlTitlesData _buildTitlesData(
    int count,
    String Function(int) dateLabel, {
    required double leftReservedSize,
    required String Function(double) leftFormatter,
  }) {
    final interval = (count / 4).ceilToDouble().clamp(1.0, 10.0);
    return FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: leftReservedSize,
          getTitlesWidget: (v, _) =>
              Text(leftFormatter(v), style: const TextStyle(fontSize: 10)),
        ),
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: interval,
          getTitlesWidget: (v, _) {
            final i = v.toInt();
            if (i < 0 || i >= count) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(dateLabel(i), style: const TextStyle(fontSize: 9)),
            );
          },
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _legendChips(
    List<String> products,
    Set<String> shown,
    void Function(String, bool) onToggle,
  ) {
    if (products.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: products.map((name) {
          final color = _colorFor(name, products);
          final visible = shown.contains(name);
          return GestureDetector(
            onTap: () => onToggle(name, !visible),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color:
                    visible ? color.withValues(alpha: 0.12) : Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: visible ? color : Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: visible ? color : Colors.grey[400]),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: visible ? color : Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _emptyChart() => const SizedBox(
        height: 120,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bar_chart_outlined, size: 32, color: Colors.grey),
              SizedBox(height: 8),
              Text('Not enough data yet',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              Text('Trends appear after 2+ days of entries',
                  style: TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
        ),
      );
}

// ─── Sales Log Tab (admin only) ───────────────────────────────────────────────

class _SalesTab extends StatefulWidget {
  const _SalesTab();

  @override
  State<_SalesTab> createState() => _SalesTabState();
}

class _SalesTabState extends State<_SalesTab> {
  int _range = 0; // 0=today, 1=week, 2=month
  bool _loading = true;
  List<DailyEntry> _entries = [];
  List<Sale> _sales = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final entries = await FirestoreService.getAllEntries();
    final sales = await FirestoreService.getAllSales();
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _sales = sales;
      _loading = false;
    });
  }

  (DateTime from, DateTime to) get _dateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      1 => (now.subtract(const Duration(days: 7)), now),
      2 => (now.subtract(const Duration(days: 30)), now),
      _ => (todayStart, todayStart.add(const Duration(days: 1))),
    };
  }

  List<DailyEntry> get _filteredEntries {
    final (from, to) = _dateRange;
    return _entries
        .where((e) => !e.date.isBefore(from) && e.date.isBefore(to))
        .toList();
  }

  List<Sale> get _filteredSales {
    final (from, to) = _dateRange;
    return _sales
        .where((s) => !s.date.isBefore(from) && s.date.isBefore(to))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingWidget();

    final entries = _filteredEntries;
    final sales = _filteredSales;

    final totalReceived =
        entries.fold<double>(0, (s, e) => s + e.totalReceived);
    final totalExpected =
        entries.fold<double>(0, (s, e) => s + e.totalExpectedMinimum);
    final totalVariance = entries.fold<double>(0, (s, e) => s + e.variance);

    final totalLogged = sales.fold<double>(0, (s, sale) => s + sale.total);
    final salesCount = sales.length;

    final byProduct = <String, double>{};
    final mpesaByProduct = <String, double>{};
    final cashByProduct = <String, double>{};
    for (final sale in sales) {
      byProduct[sale.productName] =
          (byProduct[sale.productName] ?? 0) + sale.total;
      if (sale.paymentMethod == 'mpesa') {
        mpesaByProduct[sale.productName] =
            (mpesaByProduct[sale.productName] ?? 0) + sale.total;
      } else {
        cashByProduct[sale.productName] =
            (cashByProduct[sale.productName] ?? 0) + sale.total;
      }
    }

    final mpesaLogged = sales
        .where((s) => s.paymentMethod == 'mpesa')
        .fold<double>(0, (s, sale) => s + sale.total);
    final cashLogged = sales
        .where((s) => s.paymentMethod == 'cash')
        .fold<double>(0, (s, sale) => s + sale.total);

    final receivedVsLogged = totalReceived - totalLogged;
    final expectedVsLogged = totalExpected - totalLogged;

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: _load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('Today')),
                ButtonSegment(value: 1, label: Text('This Week')),
                ButtonSegment(value: 2, label: Text('This Month')),
              ],
              selected: {_range},
              onSelectionChanged: (s) => setState(() => _range = s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: kPrimary.withValues(alpha: 0.1),
                selectedForegroundColor: kPrimary,
              ),
            ),
            const SizedBox(height: 20),

            // Section 1 — Stock System
            _sectionHeader(context, 'Stock System'),
            AppCard(
              child: Column(
                children: [
                  _kv(context, 'Expected minimum',
                      formatCurrency(totalExpected)),
                  _kv(context, 'Total received', formatCurrency(totalReceived)),
                  const Divider(),
                  _kv(context, 'Variance', formatVariance(totalVariance),
                      valueColor: totalVariance >= 0 ? kGreen : kRed,
                      bold: true),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Section 2 — Employee Sales Log
            _sectionHeader(context, 'Employee Sales Log'),
            AppCard(
              child: sales.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Text('No employee sales logged for this period.',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    )
                  : Column(
                      children: [
                        _kv(context, 'Total logged',
                            formatCurrency(totalLogged),
                            bold: true),
                        _kv(context, 'Transactions',
                            '$salesCount sale${salesCount == 1 ? '' : 's'}'),
                        if (byProduct.isNotEmpty) ...[
                          const Divider(),
                          ...byProduct.entries.map((e) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _kv(context, e.key, formatCurrency(e.value)),
                                  _subKv(
                                      context,
                                      'M-Pesa',
                                      formatCurrency(
                                          mpesaByProduct[e.key] ?? 0)),
                                  _subKv(
                                      context,
                                      'Cash',
                                      formatCurrency(
                                          cashByProduct[e.key] ?? 0)),
                                ],
                              )),
                        ],
                        const Divider(),
                        _kv(context, 'M-Pesa', formatCurrency(mpesaLogged)),
                        _kv(context, 'Cash', formatCurrency(cashLogged)),
                      ],
                    ),
            ),
            const SizedBox(height: 16),

            // Section 3 — Reconciliation
            _sectionHeader(context, 'Reconciliation'),
            AppCard(
              child: Column(
                children: [
                  _kv(context, 'Received vs logged',
                      formatVariance(receivedVsLogged),
                      valueColor: receivedVsLogged >= 0 ? Colors.black87 : kRed,
                      bold: true),
                  _kv(context, 'Expected vs logged',
                      formatVariance(expectedVsLogged)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            AppCard(
              color: const Color(0xFFFFF8E1),
              child: Text(
                'Positive gaps in received vs logged are normal on busy days '
                'when not every sale is entered. A negative gap means more was '
                'logged than actually received — investigate.',
                style: TextStyle(fontSize: 11, color: Colors.brown[700]),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(BuildContext context, String title) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(title,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      );

  Widget _kv(BuildContext context, String k, String v,
      {Color? valueColor, bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[600],
                    fontWeight: bold ? FontWeight.w700 : null,
                  )),
          Text(v,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                    color: valueColor,
                  )),
        ],
      ),
    );
  }

  Widget _subKv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 1, bottom: 1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('└ $k',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 11,
                  )),
          Text(v,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[500],
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  )),
        ],
      ),
    );
  }
}

// ─── Product Sales Tab ─────────────────────────────────────────────────────────

class _ProductSalesTab extends StatefulWidget {
  const _ProductSalesTab();

  @override
  State<_ProductSalesTab> createState() => _ProductSalesTabState();
}

class _ProductSalesTabState extends State<_ProductSalesTab> {
  bool _loading = false;
  bool _hasGenerated = false;
  List<Product> _products = [];
  String? _selectedProductId;
  DateTime? _fromDate;
  DateTime? _toDate;

  // Results
  double _totalRevenue = 0;
  double _totalAmount = 0;
  double _avgPrice = 0;
  int _numSales = 0;
  List<Sale> _sales = [];

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    final products = await FirestoreService.getProducts();
    if (mounted) {
      setState(() {
        _products = products;
      });
    }
  }

  Future<void> _pickFromDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now().subtract(const Duration(days: 30)),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _fromDate = picked);
    }
  }

  Future<void> _pickToDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _toDate = picked);
    }
  }

  Future<void> _generateReport() async {
    if (_selectedProductId == null || _fromDate == null || _toDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select product and date range'),
          backgroundColor: kRed,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
    final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);

    final allSales = await FirestoreService.getSalesForRange(from, to);
    final productSales = allSales
        .where((s) => s.productId == _selectedProductId)
        .toList();

    double totalRevenue = 0;
    double totalAmount = 0;
    for (final sale in productSales) {
      totalRevenue += sale.total;
      totalAmount += sale.amount;
    }

    final avgPrice = productSales.isNotEmpty ? totalRevenue / totalAmount : 0.0;

    if (mounted) {
      setState(() {
        _totalRevenue = totalRevenue;
        _totalAmount = totalAmount;
        _avgPrice = avgPrice;
        _numSales = productSales.length;
        _sales = productSales;
        _hasGenerated = true;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Product',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedProductId,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                  ),
                  hint: const Text('Select product'),
                  items: _products
                      .map((p) => DropdownMenuItem(
                            value: p.id,
                            child: Text(p.name),
                          ))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedProductId = v),
                ),
                const SizedBox(height: 16),
                Text('Date Range',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickFromDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(_fromDate == null
                            ? 'From'
                            : formatShortDate(_fromDate!)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickToDate,
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(
                            _toDate == null ? 'To' : formatShortDate(_toDate!)),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          side: const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _generateReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text('Generate Report'),
                  ),
                ),
              ],
            ),
          ),
          if (_hasGenerated && !_loading) ...[
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                children: [
                  _metricRow(context, 'Total Revenue',
                      formatCurrency(_totalRevenue), kPrimary),
                  const Divider(),
                  _metricRow(
                      context,
                      'Total Amount',
                      '${_totalAmount.toStringAsFixed(2)} ${_products.firstWhere((p) => p.id == _selectedProductId, orElse: () => _products.first).type == 'weight' ? 'kg' : 'pcs'}',
                      Colors.black87),
                  const Divider(),
                  _metricRow(context, 'Average Price',
                      formatCurrency(_avgPrice), Colors.black87),
                  const Divider(),
                  _metricRow(
                      context, 'Number of Sales', '$_numSales', Colors.black87),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const Text('Sales Breakdown',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            if (_sales.isEmpty)
              AppCard(
                child: Text(
                  'No sales found for this product in the selected date range.',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
              )
            else
              ..._sales.map((sale) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(formatDate(sale.date),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600)),
                              Text(formatCurrency(sale.total),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: kPrimary,
                                      )),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                  '${sale.amount.toStringAsFixed(2)} ${sale.productType == 'weight' ? 'kg' : 'pcs'} @ ${formatCurrency(sale.priceUsed)}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: Colors.grey[600])),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: sale.paymentMethod == 'mpesa'
                                      ? Colors.green[50]
                                      : Colors.blue[50],
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  sale.paymentMethod.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: sale.paymentMethod == 'mpesa'
                                        ? Colors.green[700]
                                        : Colors.blue[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  )),
          ],
        ],
      ),
    );
  }

  Widget _metricRow(
      BuildContext context, String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w500)),
          Text(value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: valueColor,
                  )),
        ],
      ),
    );
  }
}

class LoadingWidget extends StatelessWidget {
  const LoadingWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: kPrimary),
    );
  }
}
