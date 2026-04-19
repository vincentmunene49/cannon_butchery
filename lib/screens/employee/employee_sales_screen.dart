import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../app_theme.dart';
import '../../models/product.dart';
import '../../models/sale.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

class EmployeeSalesScreen extends StatefulWidget {
  final VoidCallback onLock;

  const EmployeeSalesScreen({super.key, required this.onLock});

  @override
  State<EmployeeSalesScreen> createState() => _EmployeeSalesScreenState();
}

class _EmployeeSalesScreenState extends State<EmployeeSalesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _confirmLock() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lock employee access?'),
        content: const Text('This will return to the PIN screen.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Yes, lock'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onLock();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) await _confirmLock();
      },
      child: Scaffold(
        backgroundColor: kBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Cannon Butchery',
              style: TextStyle(fontWeight: FontWeight.w700)),
          actions: [
            IconButton(
              icon: const Icon(Icons.lock_outline),
              tooltip: 'Lock employee access',
              onPressed: _confirmLock,
            ),
          ],
          bottom: TabBar(
            controller: _tabController,
            indicatorColor: kPrimary,
            labelColor: kPrimary,
            unselectedLabelColor: Colors.grey,
            tabs: const [
              Tab(text: 'Daily Entry'),
              Tab(text: 'History'),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: const [
            _DailyEntryTab(),
            _HistoryTab(),
          ],
        ),
      ),
    );
  }
}

// ─── Daily Entry Tab ──────────────────────────────────────────────────────────

class _DailyEntryTab extends StatefulWidget {
  const _DailyEntryTab();

  @override
  State<_DailyEntryTab> createState() => _DailyEntryTabState();
}

class _DailyEntryTabState extends State<_DailyEntryTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<Product> _products = [];
  bool _loadingProducts = true;

  Product? _selectedProduct;
  final _amountCtrl = TextEditingController(); // For weight-based: KES amount; for unit-based: units
  String _paymentMethod = 'mpesa';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
    _amountCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await FirestoreService.getProducts();
    if (mounted) {
      setState(() {
        _products = products.where((p) => p.isActive).toList();
        _loadingProducts = false;
      });
    }
  }

  double get _price => _selectedProduct?.currentPrice ?? 0;
  double get _inputValue => double.tryParse(_amountCtrl.text) ?? 0;

  // For weight-based: amount = kg calculated from KES; total = KES entered
  // For unit-based: amount = units entered; total = units × price
  double get _amount {
    if (_selectedProduct == null) return 0;
    if (_selectedProduct!.isWeightBased) {
      // KES amount entered ÷ price per kg = kg
      return _price > 0 ? _inputValue / _price : 0;
    } else {
      // Units entered directly
      return _inputValue;
    }
  }

  double get _total {
    if (_selectedProduct == null) return 0;
    if (_selectedProduct!.isWeightBased) {
      // Employee entered KES amount directly
      return _inputValue;
    } else {
      // Units × price per unit
      return _inputValue * _price;
    }
  }

  bool get _canRecord =>
      _selectedProduct != null && _inputValue > 0 && !_saving;

  Future<void> _recordSale() async {
    final product = _selectedProduct;
    if (product == null || _inputValue <= 0) return;

    setState(() => _saving = true);
    try {
      final sale = Sale(
        id: const Uuid().v4(),
        date: DateTime.now(),
        productId: product.id,
        productName: product.name,
        productType: product.type,
        amount: _amount, // kg or units
        priceUsed: _price,
        total: _total, // KES
        paymentMethod: _paymentMethod,
        createdAt: DateTime.now(),
      );
      await FirestoreService.addSale(sale);

      _amountCtrl.clear();
      setState(() {
        _selectedProduct = null;
        _paymentMethod = 'mpesa';
        _saving = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sale recorded ✓'),
            backgroundColor: kGreen,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_loadingProducts) {
      return const Center(child: CircularProgressIndicator(color: kPrimary));
    }
    if (_products.isEmpty) {
      return const EmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'No products available',
        subtitle: 'Contact the owner to add products.',
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Record a Sale',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),

                // Product dropdown — no prices shown
                DropdownButtonFormField<Product>(
                  value: _selectedProduct,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Product'),
                  hint: const Text('Select a product'),
                  selectedItemBuilder: (ctx) => _products
                      .map((p) => Text(p.name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w500)))
                      .toList(),
                  items: _products
                      .map((p) => DropdownMenuItem(
                            value: p,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                    child: Text(p.name,
                                        overflow: TextOverflow.ellipsis)),
                                const SizedBox(width: 6),
                                TypeBadge(productType: p.type),
                              ],
                            ),
                          ))
                      .toList(),
                  onChanged: (p) {
                    setState(() {
                      _selectedProduct = p;
                      _amountCtrl.clear();
                    });
                  },
                ),
                const SizedBox(height: 14),

                // Input field — Weight-based: KES amount; Unit-based: units
                TextFormField(
                  controller: _amountCtrl,
                  enabled: _selectedProduct != null,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  decoration: InputDecoration(
                    labelText: _selectedProduct?.isWeightBased ?? true
                        ? 'Amount (KES)'
                        : 'Units',
                    prefixText: _selectedProduct?.isWeightBased ?? true ? 'KES ' : null,
                    suffixText: _selectedProduct?.isWeightBased == false ? 'units' : null,
                    hintText: '0',
                  ),
                ),
                const SizedBox(height: 14),

                // Price — read-only, greyed out
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: 'Price per ${_selectedProduct?.isWeightBased ?? true ? 'kg' : 'unit'}',
                    prefixText: 'KES ',
                    filled: true,
                    fillColor: Colors.grey[100],
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  controller: TextEditingController(
                      text: _selectedProduct != null
                          ? _price.toStringAsFixed(2)
                          : '—'),
                  style: TextStyle(color: Colors.grey[600]),
                ),
                const SizedBox(height: 14),

                // Calculated field — Weight-based: kg equivalent; Unit-based: total
                TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: _selectedProduct?.isWeightBased ?? true
                        ? 'Kg equivalent'
                        : 'Total (KES)',
                    prefixText: _selectedProduct?.isWeightBased == false ? 'KES ' : null,
                    suffixText: _selectedProduct?.isWeightBased ?? true ? 'kg' : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    disabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: Colors.grey[200]!),
                    ),
                  ),
                  controller: TextEditingController(
                      text: _selectedProduct != null && _inputValue > 0
                          ? (_selectedProduct!.isWeightBased
                              ? _amount.toStringAsFixed(2)
                              : _total.toStringAsFixed(2))
                          : '—'),
                  style: TextStyle(
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment method
                Text('Payment method',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[700])),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                        value: 'mpesa',
                        label: Text('M-Pesa'),
                        icon: Icon(Icons.phone_android, size: 16)),
                    ButtonSegment(
                        value: 'cash',
                        label: Text('Cash'),
                        icon: Icon(Icons.payments_outlined, size: 16)),
                  ],
                  selected: {_paymentMethod},
                  onSelectionChanged: (s) =>
                      setState(() => _paymentMethod = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: kPrimary.withValues(alpha: 0.1),
                    selectedForegroundColor: kPrimary,
                  ),
                ),
                const SizedBox(height: 20),

                // Record button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _canRecord ? _recordSale : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(kCardRadius)),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Record Sale',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),
          Text("Today's Sales",
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          _TodaySalesList(),
        ],
      ),
    );
  }
}

class _TodaySalesList extends StatelessWidget {
  _TodaySalesList();

  final String _todayId = dateToId(DateTime.now());

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sale>>(
      stream: FirestoreService.salesStreamForDate(_todayId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(color: kPrimary));
        }
        final sales = snapshot.data ?? [];
        if (sales.isEmpty) {
          return AppCard(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text('No sales recorded today yet.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ),
            ),
          );
        }
        return Column(
          children: sales
              .map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _SaleTile(sale: s, isToday: true),
                  ))
              .toList(),
        );
      },
    );
  }
}

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends StatelessWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Sale>>(
      stream: FirestoreService.allSalesStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: kPrimary));
        }
        final sales = snapshot.data ?? [];
        if (sales.isEmpty) {
          return const EmptyState(
            icon: Icons.receipt_long_outlined,
            title: 'No sales yet',
            subtitle: 'Sales you record will appear here.',
          );
        }

        // Group by date id (yyyy-MM-dd)
        final grouped = <String, List<Sale>>{};
        for (final s in sales) {
          final key = dateToId(s.date);
          (grouped[key] ??= []).add(s);
        }
        final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: dates.fold<int>(
              0, (acc, d) => acc + 1 + (grouped[d]?.length ?? 0)),
          itemBuilder: (context, index) {
            // Build a flat list: date header + sale rows
            int cursor = 0;
            for (final date in dates) {
              if (index == cursor) {
                // Date header
                final dt = idToDate(date);
                return Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    DateFormat('EEEE, d MMM yyyy').format(dt),
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[600],
                          letterSpacing: 0.4,
                        ),
                  ),
                );
              }
              cursor++;
              final daySales = grouped[date]!;
              if (index < cursor + daySales.length) {
                final sale = daySales[index - cursor];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _SaleTile(sale: sale),
                );
              }
              cursor += daySales.length;
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}

// ─── Sale Tile (shared) ───────────────────────────────────────────────────────

class _SaleTile extends StatelessWidget {
  final Sale sale;
  final bool isToday;
  const _SaleTile({required this.sale, this.isToday = false});

  Future<void> _editPaymentMethod(BuildContext context) async {
    final newMethod = await showDialog<String>(
      context: context,
      builder: (ctx) => _PaymentMethodDialog(currentMethod: sale.paymentMethod),
    );
    if (newMethod != null && newMethod != sale.paymentMethod) {
      try {
        await FirestoreService.updateSalePaymentMethod(sale.id, newMethod);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Payment method updated ✓'),
              backgroundColor: kGreen,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('HH:mm').format(sale.date);
    final amountStr = sale.isWeightBased
        ? '${sale.amount.toStringAsFixed(2)} kg'
        : '${sale.amount.toStringAsFixed(0)} units';

    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(sale.productName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(width: 6),
                    TypeBadge(productType: sale.productType),
                  ],
                ),
                const SizedBox(height: 4),
                Text('$timeStr · $amountStr',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[600])),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(formatCurrency(sale.total),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      )),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _PaymentBadge(method: sale.paymentMethod),
                  if (isToday) ...[
                    const SizedBox(width: 4),
                    InkWell(
                      onTap: () => _editPaymentMethod(context),
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.edit_outlined,
                          size: 16,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String method;
  const _PaymentBadge({required this.method});

  @override
  Widget build(BuildContext context) {
    final isMpesa = method == 'mpesa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMpesa
            ? const Color(0xFFE8F5E9)
            : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isMpesa ? 'M-Pesa' : 'Cash',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isMpesa ? const Color(0xFF2E7D32) : const Color(0xFF795548),
        ),
      ),
    );
  }
}

// ─── Payment Method Edit Dialog ───────────────────────────────────────────────

class _PaymentMethodDialog extends StatefulWidget {
  final String currentMethod;
  const _PaymentMethodDialog({required this.currentMethod});

  @override
  State<_PaymentMethodDialog> createState() => _PaymentMethodDialogState();
}

class _PaymentMethodDialogState extends State<_PaymentMethodDialog> {
  late String _selectedMethod;

  @override
  void initState() {
    super.initState();
    _selectedMethod = widget.currentMethod;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change payment method'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<String>(
            value: 'mpesa',
            groupValue: _selectedMethod,
            onChanged: (value) => setState(() => _selectedMethod = value!),
            title: const Text('M-Pesa'),
            contentPadding: EdgeInsets.zero,
            activeColor: kPrimary,
          ),
          RadioListTile<String>(
            value: 'cash',
            groupValue: _selectedMethod,
            onChanged: (value) => setState(() => _selectedMethod = value!),
            title: const Text('Cash'),
            contentPadding: EdgeInsets.zero,
            activeColor: kPrimary,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _selectedMethod),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
