import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/daily_entry.dart';
import '../../models/product_entry.dart';
import '../../models/sale.dart';
import '../../services/firestore_service.dart';
import '../../utils/error_handler.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_chip.dart';
import '../main_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final todayId = dateToId(DateTime.now());
    final user = FirebaseAuth.instance.currentUser;
    final displayName = user?.displayName?.split(' ').first ?? 'there';

    return Scaffold(
      backgroundColor: kBackground,
      body: SafeArea(
        child: StreamBuilder<DailyEntry?>(
          stream: FirestoreService.entryStreamForDate(todayId),
          builder: (context, snapshot) {
            // Handle permission denied errors
            if (snapshot.hasError) {
              handleFirestoreError(snapshot.error, context);
            }
            final entry = snapshot.data;
            return RefreshIndicator(
              color: kPrimary,
              onRefresh: () async {},
              child: CustomScrollView(
                slivers: [
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatDate(DateTime.now()),
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: Colors.grey[500]),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${greeting()}, $displayName',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 20),

                          // Last entry verdict card
                          if (entry != null) ...[
                            _VerdictCard(entry: entry),
                            const SizedBox(height: 16),

                            // Summary row
                            Row(
                              children: [
                                Expanded(
                                  child: SummaryCard(
                                    label: 'Total Received',
                                    value: formatCurrency(entry.totalReceived),
                                    icon: Icons.payments_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: SummaryCard(
                                    label: 'Expected Min',
                                    value: formatCurrency(entry.totalExpectedMinimum),
                                    icon: Icons.calculate_outlined,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SummaryCard(
                              label: "Today's Variance",
                              value: formatVariance(entry.variance),
                              valueColor: entry.variance >= 0 ? kGreen : kRed,
                              icon: Icons.trending_up_rounded,
                            ),
                          ] else ...[
                            // No entry today
                            _buildNoEntryCard(context),
                          ],

                          const SizedBox(height: 16),

                          // Cumulative variance
                          _CumulativeVarianceCard(),

                          const SizedBox(height: 16),

                          if (entry != null) ...[
                            Text(
                              "Today's Product Breakdown",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 12),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Per-product breakdown with employee sales reconciliation
                  if (entry != null)
                    _ProductBreakdownList(dateId: todayId),

                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final shell = context.findAncestorStateOfType<MainShellState>();
          shell?.navigateTo(1);
        },
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.nights_stay_rounded),
        label: const Text("Tonight's Entry"),
      ),
    );
  }

  Widget _buildNoEntryCard(BuildContext context) {
    return AppCard(
      color: const Color(0xFFFFF8E1),
      child: Row(
        children: [
          const Icon(Icons.info_outline, color: Color(0xFFF57F17)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "No entry yet for today. Tap Tonight's Entry to record tonight's data.",
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: const Color(0xFF5D4037)),
            ),
          ),
        ],
      ),
    );
  }
}

class _VerdictCard extends StatelessWidget {
  final DailyEntry entry;
  const _VerdictCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isOk = entry.variance >= 0;
    return AppCard(
      color: isOk ? kGreenLight : kRedLight,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Tonight's Result",
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: isOk ? kGreen : kRed,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatDate(entry.date),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          StatusChip(
            isGood: isOk,
            customLabel: isOk
                ? formatVariance(entry.variance)
                : formatVariance(entry.variance),
          ),
        ],
      ),
    );
  }
}

class _CumulativeVarianceCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<DailyEntry>>(
      future: FirestoreService.getAllEntries(),
      builder: (context, snapshot) {
        final entries = snapshot.data ?? [];
        final cumulative = entries.fold<double>(0, (sum, e) => sum + e.variance);
        final isOk = cumulative >= 0;

        return AppCard(
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isOk ? kGreenLight : kRedLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.account_balance_wallet_outlined,
                  color: isOk ? kGreen : kRed,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All-Time Variance',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      snapshot.connectionState == ConnectionState.waiting
                          ? '—'
                          : formatVariance(cumulative),
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isOk ? kGreen : kRed,
                          ),
                    ),
                  ],
                ),
              ),
              Text(
                '${entries.length} days',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.grey[400]),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ProductBreakdownList extends StatefulWidget {
  final String dateId;
  const _ProductBreakdownList({required this.dateId});

  @override
  State<_ProductBreakdownList> createState() => _ProductBreakdownListState();
}

class _ProductBreakdownListState extends State<_ProductBreakdownList> {
  List<ProductEntry> _productEntries = [];
  bool _loadingEntries = true;

  @override
  void initState() {
    super.initState();
    FirestoreService.getProductEntriesForDate(widget.dateId).then((entries) {
      if (mounted) setState(() { _productEntries = entries; _loadingEntries = false; });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingEntries) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(color: kPrimary)),
        ),
      );
    }

    if (_productEntries.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }

    return StreamBuilder<List<Sale>>(
      stream: FirestoreService.salesStreamForDate(widget.dateId),
      builder: (context, salesSnap) {
        final sales = salesSnap.data ?? [];

        // Aggregate logged totals + payment split per product name
        final loggedByProduct = <String, double>{};
        final mpesaByProduct = <String, double>{};
        final cashByProduct = <String, double>{};
        for (final s in sales) {
          loggedByProduct[s.productName] =
              (loggedByProduct[s.productName] ?? 0) + s.total;
          if (s.paymentMethod == 'mpesa') {
            mpesaByProduct[s.productName] =
                (mpesaByProduct[s.productName] ?? 0) + s.total;
          } else {
            cashByProduct[s.productName] =
                (cashByProduct[s.productName] ?? 0) + s.total;
          }
        }

        final hasSales = sales.isNotEmpty;

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              // Last item: footer note
              if (index == _productEntries.length) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                  child: Text(
                    'Based on employee sales entries vs stock movement',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.grey[400], fontSize: 11),
                  ),
                );
              }

              final pe = _productEntries[index];
              final logged = loggedByProduct[pe.productName] ?? 0;
              final mpesa = mpesaByProduct[pe.productName] ?? 0;
              final cash = cashByProduct[pe.productName] ?? 0;
              final variance = logged - pe.minimumExpected;
              final isOk = variance >= 0;
              final productHasSales = logged > 0;

              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              pe.productName,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          TypeBadge(productType: pe.productType),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _row(context, 'Stock expected min',
                          formatCurrency(pe.minimumExpected)),
                      if (hasSales) ...[
                        _row(context, 'Employee logged',
                            formatCurrency(logged)),
                        // Payment split sub-rows — only for this product's sales
                        if (productHasSales) ...[
                          _subRow(context, 'M-Pesa', formatCurrency(mpesa)),
                          _subRow(context, 'Cash', formatCurrency(cash)),
                        ],
                        const Divider(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Variance',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w600)),
                            Row(
                              children: [
                                Text(
                                  formatVariance(variance),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isOk ? kGreen : kRed),
                                ),
                                const SizedBox(width: 8),
                                StatusChip(
                                  isGood: isOk,
                                  customLabel: isOk ? 'OK' : 'Low',
                                ),
                              ],
                            ),
                          ],
                        ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            'No sales logged yet today',
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: Colors.grey[400],
                                    fontStyle: FontStyle.italic),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
            // +1 for the footer note row
            childCount: _productEntries.length + 1,
          ),
        );
      },
    );
  }

  Widget _row(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[600])),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _subRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, top: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('└ $label',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.grey[400],
                    fontSize: 11,
                  )),
          Text(value,
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
