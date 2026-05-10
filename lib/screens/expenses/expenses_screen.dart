import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../../app_theme.dart';
import '../../models/expense.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/empty_state.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  int _range = 0; // 0=today, 1=week, 2=month, 3=all
  bool _loading = true;
  List<Expense> _expenses = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final expenses = await FirestoreService.getAllExpenses();
    if (!mounted) return;
    setState(() {
      _expenses = expenses;
      _loading = false;
    });
  }

  (DateTime from, DateTime to) get _dateRange {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return switch (_range) {
      1 => (now.subtract(const Duration(days: 7)), now),
      2 => (now.subtract(const Duration(days: 30)), now),
      3 => (DateTime(2020), now),
      _ => (todayStart, todayStart.add(const Duration(days: 1))),
    };
  }

  List<Expense> get _filteredExpenses {
    final (from, to) = _dateRange;
    return _expenses
        .where((e) => !e.date.isBefore(from) && e.date.isBefore(to))
        .toList();
  }

  Future<void> _addExpense() async {
    final result = await showDialog<Expense>(
      context: context,
      builder: (ctx) => _ExpenseDialog(),
    );
    if (result != null) {
      await FirestoreService.addExpense(result);
      _load();
    }
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Expense'),
        content: Text('Delete ${expense.category} expense of ${formatCurrency(expense.amount)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kRed),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await FirestoreService.deleteExpense(expense.id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: kPrimary)),
      );
    }

    final filtered = _filteredExpenses;
    final totalCash = filtered
        .where((e) => e.paymentMethod == 'cash')
        .fold<double>(0, (s, e) => s + e.amount);
    final totalMpesa = filtered
        .where((e) => e.paymentMethod == 'mpesa')
        .fold<double>(0, (s, e) => s + e.amount);
    final totalExpenses = totalCash + totalMpesa;

    // Group by category
    final byCategory = <String, double>{};
    for (final e in filtered) {
      byCategory[e.category] = (byCategory[e.category] ?? 0) + e.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _addExpense,
            tooltip: 'Add Expense',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Today')),
                    ButtonSegment(value: 1, label: Text('This Week')),
                    ButtonSegment(value: 2, label: Text('This Month')),
                    ButtonSegment(value: 3, label: Text('All Time')),
                  ],
                  selected: {_range},
                  onSelectionChanged: (s) => setState(() => _range = s.first),
                  style: SegmentedButton.styleFrom(
                    selectedBackgroundColor: kPrimary.withValues(alpha: 0.1),
                    selectedForegroundColor: kPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                AppCard(
                  color: const Color(0xFFFFF3E0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Total Expenses',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w500)),
                          Text(formatCurrency(totalExpenses),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: Colors.orange[900])),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Cash',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(formatCurrency(totalCash),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('M-Pesa',
                              style: Theme.of(context).textTheme.bodySmall),
                          Text(formatCurrency(totalMpesa),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),
                if (byCategory.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('By Category',
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        ...byCategory.entries.map((e) => Padding(
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(e.key,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall),
                                  Text(formatCurrency(e.value),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(
                                              fontWeight: FontWeight.w600)),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (filtered.isEmpty)
            Expanded(
              child: EmptyState(
                icon: Icons.receipt_long_outlined,
                title: 'No expenses for this period',
                subtitle: 'Tap + to add an expense',
              ),
            )
          else
            Expanded(
              child: RefreshIndicator(
                color: kPrimary,
                onRefresh: _load,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final expense = filtered[index];
                    return AppCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(expense.category,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall
                                              ?.copyWith(
                                                  fontWeight: FontWeight.w700)),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: expense.paymentMethod == 'mpesa'
                                            ? Colors.green[50]
                                            : Colors.blue[50],
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        expense.paymentMethod.toUpperCase(),
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w600,
                                          color: expense.paymentMethod == 'mpesa'
                                              ? Colors.green[700]
                                              : Colors.blue[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                if (expense.description.isNotEmpty)
                                  Text(expense.description,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.grey[600])),
                                Text(formatDate(expense.date),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                            color: Colors.grey[500],
                                            fontSize: 11)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(formatCurrency(expense.amount),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: Colors.orange[900])),
                              const SizedBox(height: 4),
                              IconButton(
                                icon: const Icon(Icons.delete_outline,
                                    size: 20),
                                color: kRed,
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _deleteExpense(expense),
                              ),
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
      ),
    );
  }
}

class _ExpenseDialog extends StatefulWidget {
  @override
  State<_ExpenseDialog> createState() => _ExpenseDialogState();
}

class _ExpenseDialogState extends State<_ExpenseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _category = 'Electricity';
  String _paymentMethod = 'cash';
  DateTime _date = DateTime.now();

  final _categories = [
    'Electricity',
    'Employee Salary',
    'Rent',
    'Supplies',
    'Transportation',
    'Maintenance',
    'Other',
  ];

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
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
      setState(() => _date = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final expense = Expense(
      id: const Uuid().v4(),
      date: _date,
      category: _category,
      amount: double.parse(_amountController.text),
      description: _descriptionController.text.trim(),
      paymentMethod: _paymentMethod,
      createdAt: DateTime.now(),
    );

    Navigator.pop(context, expense);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Expense'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Category',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                items: _categories
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _category = v!),
              ),
              const SizedBox(height: 16),
              Text('Amount',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixText: 'K ',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Required';
                  final amount = double.tryParse(v);
                  if (amount == null || amount <= 0) return 'Invalid amount';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Text('Payment Method',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'cash', label: Text('Cash')),
                  ButtonSegment(value: 'mpesa', label: Text('M-Pesa')),
                ],
                selected: {_paymentMethod},
                onSelectionChanged: (s) =>
                    setState(() => _paymentMethod = s.first),
              ),
              const SizedBox(height: 16),
              Text('Date',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(Icons.calendar_today, size: 18),
                label: Text(formatDate(_date)),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 44),
                ),
              ),
              const SizedBox(height: 16),
              Text('Description (optional)',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'e.g., Monthly electricity bill',
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Add'),
        ),
      ],
    );
  }
}
