import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../../app_theme.dart';
import '../../models/product.dart';
import '../../services/auth_service.dart';
import '../../services/export_service.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/status_chip.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _ProductsSection(),
          const SizedBox(height: 24),
          const _Day1OpeningStockSection(),
          const _OpeningBalancesSection(),
          const SizedBox(height: 24),
          const _DataManagementSection(),
          const SizedBox(height: 24),
          const _AccountSection(),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

// ─── Products Section ──────────────────────────────────────────────────────────

class _ProductsSection extends StatelessWidget {
  const _ProductsSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          title: 'Products',
          trailing: IconButton(
            onPressed: () => _showProductForm(context, null),
            icon: const Icon(Icons.add_circle, color: kPrimary),
            tooltip: 'Add product',
          ),
        ),
        StreamBuilder<List<Product>>(
          stream: FirestoreService.productsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.all(20),
                child: Center(child: CircularProgressIndicator(color: kPrimary)),
              );
            }
            if (snapshot.hasError) {
              return AppCard(
                color: const Color(0xFFFFEBEE),
                child: Text(
                  'Error loading products: ${snapshot.error}',
                  style: const TextStyle(color: kRed, fontSize: 12),
                ),
              );
            }
            final products = snapshot.data ?? [];
            if (products.isEmpty) {
              return AppCard(
                child: EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No products yet',
                  subtitle: 'Tap + to add your first product.',
                  action: ElevatedButton(
                    onPressed: () => _showProductForm(context, null),
                    child: const Text('Add Product'),
                  ),
                ),
              );
            }
            return Column(
              children: products
                  .map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _ProductItem(product: p),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  static void _showProductForm(BuildContext context, Product? existing) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProductFormSheet(existing: existing),
    );
  }
}

class _ProductItem extends StatelessWidget {
  final Product product;
  const _ProductItem({required this.product});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: product.isActive ? kCardBackground : Colors.grey[100],
      onTap: () => _ProductsSection._showProductForm(context, product),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      product.name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: product.isActive ? null : Colors.grey,
                          ),
                    ),
                    const SizedBox(width: 8),
                    TypeBadge(productType: product.type),
                    if (!product.isActive) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Inactive',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey[600])),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${formatCurrency(product.currentPrice)} / ${product.isWeightBased ? 'kg' : 'unit'}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.grey),
        ],
      ),
    );
  }
}

class _ProductFormSheet extends StatefulWidget {
  final Product? existing;
  const _ProductFormSheet({this.existing});

  @override
  State<_ProductFormSheet> createState() => _ProductFormSheetState();
}

class _ProductFormSheetState extends State<_ProductFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _nameCtrl =
      TextEditingController(text: widget.existing?.name ?? '');
  late final _priceCtrl = TextEditingController(
      text: widget.existing?.currentPrice.toStringAsFixed(2) ?? '');
  late final _currentStockCtrl = TextEditingController();
  late String _type = widget.existing?.type ?? 'weight';
  late bool _isActive = widget.existing?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _currentStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    try {
      final isEdit = widget.existing != null;
      final price = double.parse(_priceCtrl.text);

      if (isEdit) {
        final oldPrice = widget.existing!.currentPrice;
        if (price != oldPrice) {
          await FirestoreService.updateProductPrice(widget.existing!.id, price);
        }
        await FirestoreService.updateProduct(widget.existing!.copyWith(
          name: _nameCtrl.text.trim(),
          type: _type,
          currentPrice: price,
          isActive: _isActive,
        ));
      } else {
        final product = Product(
          id: const Uuid().v4(),
          name: _nameCtrl.text.trim(),
          type: _type,
          currentPrice: price,
          isActive: _isActive,
          createdAt: DateTime.now(),
        );
        await FirestoreService.addProduct(product);
        final openingStock =
            double.tryParse(_currentStockCtrl.text.trim()) ?? 0;
        await FirestoreService.saveNewProductOpeningStock(product, openingStock);
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(isEdit ? 'Product updated.' : 'Product added.')),
        );
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

  Future<void> _delete() async {
    final product = widget.existing!;
    final hasEntries = await FirestoreService.productHasEntries(product.id);
    if (!mounted) return;

    if (hasEntries) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cannot Delete'),
          content: Text(
              '${product.name} has daily entries referencing it. You can only deactivate it.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await FirestoreService.updateProduct(
                    product.copyWith(isActive: false));
                if (mounted) Navigator.pop(context);
              },
              child: const Text('Deactivate'),
            ),
          ],
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Product'),
        content: Text('Permanently delete ${product.name}?'),
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

    await FirestoreService.deleteProduct(product.id);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Product deleted.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Container(
      // Cap the sheet at 90% of screen height so it's always scrollable
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: kBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          // Keyboard padding is handled here so the sheet scrolls above it
          padding: EdgeInsets.fromLTRB(
              24, 12, 24, 32 + MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    isEdit ? 'Edit Product' : 'Add Product',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (isEdit)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline, color: kRed, size: 18),
                      label: const Text('Delete', style: TextStyle(color: kRed)),
                    ),
                ],
              ),
              const SizedBox(height: 20),

              // Name
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'Product name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),

              // Type
              Text('Type',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[700])),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'weight',
                    label: Text('Weight-based (kg)'),
                    icon: Icon(Icons.scale),
                  ),
                  ButtonSegment(
                    value: 'unit',
                    label: Text('Unit-based'),
                    icon: Icon(Icons.tag),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() => _type = s.first),
                style: SegmentedButton.styleFrom(
                  selectedBackgroundColor: kPrimary.withValues(alpha: 0.1),
                  selectedForegroundColor: kPrimary,
                ),
              ),
              const SizedBox(height: 16),

              // Price
              TextFormField(
                controller: _priceCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
                ],
                decoration: InputDecoration(
                  labelText: 'Selling price',
                  prefixText: 'KES ',
                  suffixText: _type == 'weight' ? '/ kg' : '/ unit',
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  if (double.tryParse(v) == null) return 'Enter a number';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Current stock (new products only)
              if (!isEdit) ...[
                TextFormField(
                  controller: _currentStockCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d+\.?\d{0,3}')),
                  ],
                  decoration: InputDecoration(
                    labelText: _type == 'weight'
                        ? 'Current stock (kg)'
                        : 'Current stock (units)',
                    suffixText: _type == 'weight' ? 'kg' : 'units',
                    helperText: 'Stock on hand right now — enter 0 if none',
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required (enter 0 if none)';
                    if (double.tryParse(v) == null) return 'Enter a number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Active toggle
              if (isEdit) ...[
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Active'),
                  subtitle:
                      const Text('Inactive products are hidden from entry screens.'),
                  activeThumbColor: kPrimary,
                  contentPadding: EdgeInsets.zero,
                ),
                const SizedBox(height: 16),
              ],

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Text(isEdit ? 'Save Changes' : 'Add Product'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Day 1 Opening Stock Section ──────────────────────────────────────────────

class _Day1OpeningStockSection extends StatefulWidget {
  const _Day1OpeningStockSection();

  @override
  State<_Day1OpeningStockSection> createState() =>
      _Day1OpeningStockSectionState();
}

class _Day1OpeningStockSectionState extends State<_Day1OpeningStockSection> {
  bool _loading = true;
  bool _shouldShow = false;
  bool _saving = false;
  List<Product> _products = [];
  final Map<String, TextEditingController> _controllers = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) c.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final hasEntries = await FirestoreService.hasAnyCompletedEntries();
    if (hasEntries) {
      if (mounted) setState(() { _loading = false; _shouldShow = false; });
      return;
    }

    final products = await FirestoreService.getProducts();
    final active = products.where((p) => p.isActive).toList();
    final day1 = await FirestoreService.getDay1OpeningStock();

    final newCtrl = <String, TextEditingController>{};
    for (final p in active) {
      final existing = day1[p.id];
      newCtrl[p.id] = TextEditingController(
        text: (existing != null && existing > 0)
            ? existing.toStringAsFixed(2)
            : '',
      );
    }

    if (mounted) {
      setState(() {
        _products = active;
        _controllers.addAll(newCtrl);
        _shouldShow = true;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final stock = {
        for (final p in _products)
          p.id: double.tryParse(_controllers[p.id]?.text ?? '') ?? 0,
      };
      final todayId = dateToId(DateTime.now());
      // Write to today's productEntries subcollection so Nightly Entry shows
      // the correct opening stock immediately
      await FirestoreService.saveDay1OpeningStockToProductEntries(
          todayId, stock, _products);
      // Also persist to config as a fallback
      await FirestoreService.setDay1OpeningStock(stock);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Day 1 opening stock saved.')),
        );
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
    if (_loading || !_shouldShow) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Day 1 Opening Stock'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Enter the stock you are starting with on Day 1. '
                  'This will be used as the opening stock for your first nightly entry.',
                  style: TextStyle(fontSize: 12, color: Color(0xFF2E7D32)),
                ),
              ),
              const SizedBox(height: 16),
              if (_products.isEmpty)
                const Text('No active products. Add products above first.')
              else ...[
                ..._products.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _controllers[p.id],
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'^\d+\.?\d{0,3}')),
                        ],
                        decoration: InputDecoration(
                          labelText: '${p.name} — Opening stock',
                          suffixText: p.isWeightBased ? 'kg' : 'units',
                        ),
                      ),
                    )),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2),
                          )
                        : const Text('Save Opening Stock'),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ─── Opening Balances Section ──────────────────────────────────────────────────

class _OpeningBalancesSection extends StatefulWidget {
  const _OpeningBalancesSection();

  @override
  State<_OpeningBalancesSection> createState() =>
      _OpeningBalancesSectionState();
}

class _OpeningBalancesSectionState extends State<_OpeningBalancesSection> {
  final _mpesaCtrl = TextEditingController();
  final _cashCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _mpesaCtrl.dispose();
    _cashCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final balances = await FirestoreService.getInitialBalances();
    if (!mounted) return;
    setState(() {
      _mpesaCtrl.text = (balances['mpesa'] ?? 0).toStringAsFixed(2);
      _cashCtrl.text = (balances['cash'] ?? 0).toStringAsFixed(2);
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final mpesa = double.tryParse(_mpesaCtrl.text) ?? 0;
      final cash = double.tryParse(_cashCtrl.text) ?? 0;
      // Save to config (used as fallback in carry-forward logic)
      await FirestoreService.setInitialBalances(mpesa, cash);
      // Also write directly into today's dailyEntry so opening balances are
      // immediately visible in Nightly Entry without waiting for carry-forward
      final todayId = dateToId(DateTime.now());
      await FirestoreService.saveDay1OpeningBalancesToEntry(todayId, mpesa, cash);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Opening balances saved.')),
        );
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Opening Balances'),
        AppCard(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: kPrimary))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF8E1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        '⚠️ Only change these if starting fresh. Changing mid-use will break calculations.',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF5D4037)),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _mpesaCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Initial M-Pesa balance',
                        prefixText: 'KES ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _cashCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                            RegExp(r'^\d+\.?\d{0,2}')),
                      ],
                      decoration: const InputDecoration(
                        labelText: 'Initial cash balance',
                        prefixText: 'KES ',
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _save,
                        child: const Text('Save Balances'),
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

// ─── Data Management Section ───────────────────────────────────────────────────

class _DataManagementSection extends StatelessWidget {
  const _DataManagementSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Data Management'),
        AppCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.download_outlined, color: kPrimary),
                title: const Text('Export Data as CSV'),
                subtitle: const Text('Exports products, entries, and stock additions'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () async {
                  try {
                    await ExportService.exportAll();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
                    }
                  }
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.delete_forever_outlined, color: kRed),
                title: const Text('Delete ALL Data',
                    style: TextStyle(color: kRed)),
                subtitle: const Text('Permanently removes everything'),
                trailing: const Icon(Icons.chevron_right, color: kRed),
                onTap: () => _confirmDeleteAll(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmDeleteAll(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ALL Data?'),
        content: const Text(
            'This will permanently delete all products, entries, and stock additions. This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    // Second confirmation: type DELETE
    final textCtrl = TextEditingController();
    final doubleConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Type DELETE to confirm'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('This action is irreversible. Type DELETE to confirm.'),
            const SizedBox(height: 12),
            TextField(
              controller: textCtrl,
              decoration:
                  const InputDecoration(hintText: 'DELETE', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, textCtrl.text == 'DELETE'),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Delete Everything'),
          ),
        ],
      ),
    );

    if (doubleConfirmed != true) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Deletion cancelled — text did not match.')),
        );
      }
      return;
    }

    try {
      await FirestoreService.deleteAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All data deleted.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}

// ─── Account Section ───────────────────────────────────────────────────────────

class _AccountSection extends StatelessWidget {
  const _AccountSection();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(title: 'Account'),
        AppCard(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  backgroundColor: kPrimary.withValues(alpha: 0.1),
                  backgroundImage: user?.photoURL != null
                      ? NetworkImage(user!.photoURL!)
                      : null,
                  child: user?.photoURL == null
                      ? const Icon(Icons.person, color: kPrimary)
                      : null,
                ),
                title: Text(user?.displayName ?? 'Owner',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(user?.email ?? ''),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, color: Colors.grey),
                title: const Text('Sign Out'),
                onTap: () => _confirmSignOut(context),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('You will need to sign in again on this device.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await AuthService.signOut();
  }
}

// ─── Shared ────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const _SectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const Spacer(),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}
