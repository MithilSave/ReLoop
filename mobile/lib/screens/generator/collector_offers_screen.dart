import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class CollectorOffersScreen extends StatelessWidget {
  const CollectorOffersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final batchesWithOffers =
        state.batches.where((b) => b.offers.isNotEmpty).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Collector Quotes & Offers'),
      ),
      body: batchesWithOffers.isEmpty
          ? const Center(
              child: Text(
                'No active collector quotes right now.',
                style: TextStyle(color: AppTheme.slate500),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: batchesWithOffers.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final b = batchesWithOffers[i];
                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.slate200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                b.batchCode,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppTheme.slate900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${b.material.label} • ${b.quantities.estimatedKg.toStringAsFixed(0)} kg',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${b.offers.length} quotes',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.slate500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppTheme.slate100),
                      const SizedBox(height: 12),

                      ...b.offers.map((offer) {
                        final isAccepted = offer.status == 'ACCEPTED';
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isAccepted
                                ? AppTheme.primaryLight
                                : AppTheme.slate50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isAccepted
                                  ? AppTheme.primary
                                  : AppTheme.slate200,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        offer.collectorName,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.slate900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Slot: ${offer.proposedPickupAt}',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.slate500),
                                      ),
                                    ],
                                  ),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '₹${offer.ratePerKg.toStringAsFixed(2)} / kg',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primaryDark,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                      Text(
                                        'Match ${(offer.matchScore * 100).toInt()}%',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppTheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),

                              // Reasons breakdown
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: offer.reasons.map((r) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                          color: AppTheme.slate200),
                                    ),
                                    child: Text(
                                      '✓ $r',
                                      style: const TextStyle(
                                        fontSize: 9,
                                        color: AppTheme.slate600,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                              const SizedBox(height: 10),

                              // Action
                              if (isAccepted)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '✓ Offer Accepted (Assigned)',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                )
                              else if (b.status.label == 'LISTED')
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: () {
                                      state.acceptOffer(b.id, offer.id);
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Accepted offer from ${offer.collectorName}! Pickup OTP generated.'),
                                          backgroundColor: AppTheme.primary,
                                        ),
                                      );
                                    },
                                    child: const Text('Accept Offer & Assign Pickup'),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
