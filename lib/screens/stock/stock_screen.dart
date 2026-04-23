import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../app_theme.dart';
import '../../models/product.dart';
import '../../models/stock_addition.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

class StockScreen extends StatefulWidget {
  const StockScreen({super.key});

  @override
  State<StockScreen> createState() => _StockScreenState();
}

class _StockScreenState extends State<StockScreen> {
  // ── Form state ───────────────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _costCtrl = TextEditingController();

  List<Product> _products = [];
  Product? _selectedProduct;
  String _paymentMethod = 'mpesa';
  bool _productsLoading = true;
  bool _saving = false;

  // ── History expansion ────────────────────────────────────────────────────
  bool _showAllHistory = false;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _costCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    final products = await FirestoreService.getProducts();
    if (!mounted) return;
    setState(() {
      _products = products.where((p) => p.isActive).toList();
      _productsLoading = false;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a product.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final sellable = double.parse(_amountCtrl.text);
      final cost = double.parse(_costCtrl.text);
      final addition = StockAddition(
        id: const Uuid().v4(),
        date: DateTime.now(),
        productId: _selectedProduct!.id,
        productName: _selectedProduct!.name,
        sellableAmount: sellable,
        costPaid: cost,
        costPerUnit: sellable > 0 ? cost / sellable : 0,
        paymentMethod: _paymentMethod,
        createdAt: DateTime.now(),
      );
      await FirestoreService.addStockAddition(addition);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Purchase logged!')),
        );
        _amountCtrl.clear();
        _costCtrl.clear();
        setState(() => _selectedProduct = null);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayId = dateToId(DateTime.now());
    final unitLabel = _selectedProduct?.isWeightBased == true ? 'kg' : 'units';

    return Scaffold(
      backgroundColor: kBackground,
      appBar: AppBar(title: const Text('Purchase')),
      body: _productsLoading
          ? const LoadingWidget()
          : _products.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_bag_outlined,
                  title: 'No active products',
                  subtitle:
                      'Add products in Settings before logging purchases.',
                )
              : StreamBuilder<List<StockAddition>>(
                  stream: FirestoreService.stockAdditionsStreamForDate(todayId),
                  builder: (context, snapshot) {
                    final todayItems = snapshot.data ?? [];
                    return CustomScrollView(
                      slivers: [
                        // ── Purchase form ──────────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                            child: _PurchaseForm(
                              formKey: _formKey,
                              products: _products,
                              selectedProduct: _selectedProduct,
                              amountCtrl: _amountCtrl,
                              costCtrl: _costCtrl,
                              paymentMethod: _paymentMethod,
                              unitLabel: unitLabel,
                              saving: _saving,
                              onProductChanged: (p) =>
                                  setState(() => _selectedProduct = p),
                              onPaymentMethodChanged: (m) =>
                                  setState(() => _paymentMethod = m),
                              onSave: _save,
                            ),
                          ),
                        ),

                        // ── Today's purchases ──────────────────────────
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                            child: Text(
                              "Today's Purchases",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ),

                        if (snapshot.connectionState == ConnectionState.waiting)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(
                                  child: CircularProgressIndicator(
                                      color: kPrimary)),
                            ),
                          )
                        else if (todayItems.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding:
                                  EdgeInsets.symmetric(horizontal: 16),
                              child: AppCard(
                                child: EmptyState(
                                  icon: Icons.receipt_long_outlined,
                                  title: 'No purchases today yet',
                                  subtitle:
                                      'Use the form above to log a purchase.',
                                ),
                              ),
                            ),
                          )
                        else
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(16, 0, 16, 8),
                                child:
                                    _PurchaseItem(addition: todayItems[index]),
                              ),
                              childCount: todayItems.length,
                            ),
                          ),

                        // ── View All History ───────────────────────────
                        SliverToBoxAdapter(
                          child: _HistorySection(
                            expanded: _showAllHistory,
                            onToggle: () => setState(
                                () => _showAllHistory = !_showAllHistory),
                            todayId: todayId,
                          ),
                        ),

                        const SliverToBoxAdapter(child: SizedBox(height: 32)),
                      ],
                    );
                  },
                ),
    );
  }
}

// ── Purchase form widget ─────────────────────────────────────────────────────

class _PurchaseForm extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final List<Product> products;
  final Product? selectedProduct;
  final TextEditingController amountCtrl;
  final TextEditingController costCtrl;
  final String paymentMethod;
  final String unitLabel;
  final bool saving;
  final ValueChanged<Product?> onProductChanged;
  final ValueChanged<String> onPaymentMethodChanged;
  final VoidCallback onSave;

  const _PurchaseForm({
    required this.formKey,
    required this.products,
    required this.selectedProduct,
    required this.amountCtrl,
    required this.costCtrl,
    required this.paymentMethod,
    required this.unitLabel,
    required this.saving,
    required this.onProductChanged,
    required this.onPaymentMethodChanged,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Log a Purchase',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700, color: kPrimary),
            ),
            const SizedBox(height: 16),

            // Product
            DropdownButtonFormField<Product>(
              initialValue: selectedProduct,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Product'),
              selectedItemBuilder: (context) => products
                  .map((p) => Text(p.name, overflow: TextOverflow.ellipsis))
                  .toList(),
              items: products.map((p) {
                return DropdownMenuItem(
                  value: p,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          p.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      TypeBadge(productType: p.type),
                    ],
                  ),
                );
              }).toList(),
              onChanged: onProductChanged,
              validator: (v) => v == null ? 'Select a product' : null,
            ),
            const SizedBox(height: 12),

            // Amount + Cost side by side
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,3}')),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Sellable amount',
                      suffixText: unitLabel,
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: costCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                    decoration: const InputDecoration(
                      labelText: 'Cost paid',
                      prefixText: 'KES ',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Required';
                      if (double.tryParse(v) == null) return 'Invalid';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Payment method
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'mpesa',
                  label: Text('M-Pesa'),
                  icon: Icon(Icons.phone_android, size: 16),
                ),
                ButtonSegment(
                  value: 'cash',
                  label: Text('Cash'),
                  icon: Icon(Icons.money, size: 16),
                ),
              ],
              selected: {paymentMethod},
              onSelectionChanged: (s) => onPaymentMethodChanged(s.first),
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: kPrimary.withValues(alpha: 0.1),
                selectedForegroundColor: kPrimary,
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: saving ? null : onSave,
                child: saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Text('Save Purchase'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Individual purchase row ───────────────────────────────────────────────────

class _PurchaseItem extends StatelessWidget {
  final StockAddition addition;
  const _PurchaseItem({required this.addition});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      addition.productName,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    PaymentBadge(method: addition.paymentMethod),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${addition.sellableAmount} sellable · ${formatCurrency(addition.costPaid)} · ${formatCurrency(addition.costPerUnit)}/unit',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: kRed, size: 20),
            onPressed: () => _confirmDelete(context),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Purchase'),
        content: Text(
            'Remove the ${addition.productName} purchase of ${formatCurrency(addition.costPaid)}?'),
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
    try {
      await FirestoreService.deleteStockAddition(addition.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Deleted.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ── History section (expandable) ─────────────────────────────────────────────

class _HistorySection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;
  final String todayId;

  const _HistorySection({
    required this.expanded,
    required this.onToggle,
    required this.todayId,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: onToggle,
            icon: Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 20,
            ),
            label: Text(expanded ? 'Hide Full History' : 'View All History'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.black87,
              side: const BorderSide(color: Color(0xFFE0E0E0)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (expanded) ...[
            const SizedBox(height: 12),
            StreamBuilder<List<StockAddition>>(
              stream: FirestoreService.allStockAdditionsStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                        child: CircularProgressIndicator(color: kPrimary)),
                  );
                }
                final all = snapshot.data ?? [];
                // Skip today — already shown above
                final history =
                    all.where((a) => dateToId(a.date) != todayId).toList();

                if (history.isEmpty) {
                  return const EmptyState(
                    icon: Icons.history,
                    title: 'No previous purchases',
                  );
                }

                // Group by date
                final byDate = <String, List<StockAddition>>{};
                for (final a in history) {
                  final key = dateToId(a.date);
                  byDate.putIfAbsent(key, () => []).add(a);
                }
                final sortedDates = byDate.keys.toList()
                  ..sort((a, b) => b.compareTo(a));

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: sortedDates.map((dateId) {
                    final items = byDate[dateId]!;
                    final date = idToDate(dateId);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6, top: 8),
                          child: Text(
                            formatShortDate(date),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w600),
                          ),
                        ),
                        ...items.map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _PurchaseItem(addition: a),
                            )),
                      ],
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}
