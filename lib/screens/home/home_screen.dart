import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../app_theme.dart';
import '../../models/daily_entry.dart';
import '../../models/product_entry.dart';
import '../../services/firestore_service.dart';
import '../../utils/formatters.dart';
import '../../widgets/app_card.dart';
import '../../widgets/status_chip.dart';
import '../main_shell.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

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
                              'Products Today',
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

                  // Per-product list
                  if (entry != null)
                    _ProductEntriesList(dateId: todayId),

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

class _ProductEntriesList extends StatelessWidget {
  final String dateId;
  const _ProductEntriesList({required this.dateId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ProductEntry>>(
      future: FirestoreService.getProductEntriesForDate(dateId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: kPrimary)),
            ),
          );
        }

        final entries = snapshot.data ?? [];
        if (entries.isEmpty) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final pe = entries[index];
              return Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: AppCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  pe.productName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 8),
                                TypeBadge(productType: pe.productType),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sold: ${formatWeight(pe.estimatedSold, pe.productType)} · Min: ${formatCurrency(pe.minimumExpected)}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      ),
                      StatusChip(isGood: pe.variance >= 0),
                    ],
                  ),
                ),
              );
            },
            childCount: entries.length,
          ),
        );
      },
    );
  }
}
