import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/plan.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class CollectorPlansScreen extends StatelessWidget {
  const CollectorPlansScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final plans = state.aggregationPlans;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Aggregated Route Proposals'),
      ),
      body: plans.isEmpty
          ? const Center(
              child: Text(
                'No route proposals assigned to your fleet.',
                style: TextStyle(color: AppTheme.slate500),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: plans.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final plan = plans[i];
                return _buildPlanCard(context, state, plan);
              },
            ),
    );
  }

  Widget _buildPlanCard(
      BuildContext context, AppState state, AggregationPlan plan) {
    final isAccepted = plan.status == 'ACCEPTED';
    // Collector Logistics Fee: separate from recycler purchase price!
    final collectorFee = plan.collectionCost;
    final ratePerKg = plan.totalEstimatedKg > 0
        ? collectorFee / plan.totalEstimatedKg
        : 3.50;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAccepted ? AppTheme.primary : AppTheme.slate200,
          width: isAccepted ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isAccepted ? AppTheme.primaryLight : AppTheme.slate50,
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isAccepted
                            ? AppTheme.primary
                            : const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.route,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          plan.planCode,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppTheme.slate900,
                          ),
                        ),
                        Text(
                          'Requested by Ecoplas Recycling • ${plan.materialCode.code}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.slate500),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isAccepted ? AppTheme.primary : AppTheme.amber100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    plan.status,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: isAccepted ? Colors.white : AppTheme.amber800,
                    ),
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Highlights
                Row(
                  children: [
                    Expanded(
                      child: _buildMetric(
                        'Total Volume',
                        '${plan.totalEstimatedKg.toStringAsFixed(0)} kg',
                        '${plan.stopsCount} stops',
                        Icons.scale,
                        AppTheme.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMetric(
                        'Collector Earnings',
                        '₹${collectorFee.toStringAsFixed(0)}',
                        '₹${ratePerKg.toStringAsFixed(2)}/kg margin',
                        Icons.payments,
                        const Color(0xFF0D9488),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Note on earnings transparency (from 09_DASHBOARDS_AND_UI.md §3)
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline,
                          size: 14, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your earnings (₹${collectorFee.toStringAsFixed(0)}) are your guaranteed logistics & doorstep aggregation fee, separate from recycler feedstock costs.',
                          style: const TextStyle(
                            fontSize: 10,
                            color: Color(0xFF1E40AF),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Stops Sequence
                const Text(
                  'Optimized Route Stops Sequence',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate800,
                  ),
                ),
                const SizedBox(height: 8),
                ...plan.items.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.slate50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: const Color(0xFF1E3A8A),
                          child: Text(
                            '${item.sequenceNo}',
                            style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.locality,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.slate900,
                                ),
                              ),
                              Text(
                                item.address,
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.slate500),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.kg.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                                color: AppTheme.primaryDark,
                              ),
                            ),
                            Text(
                              item.batchCode,
                              style: const TextStyle(
                                  fontSize: 9,
                                  color: AppTheme.slate400,
                                  fontFamily: 'monospace'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 16),

                // Action
                if (!isAccepted)
                  ElevatedButton.icon(
                    onPressed: () {
                      state.acceptAggregationPlan(plan.id);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                              'Route ${plan.planCode} accepted! Pickups scheduled for Western Suburbs fleet.'),
                          backgroundColor: AppTheme.primary,
                        ),
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline, size: 16),
                    label: const Text('Accept Proposed Route & Schedule'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E3A8A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle,
                            color: AppTheme.primaryDark, size: 16),
                        SizedBox(width: 8),
                        Text(
                          'Route Accepted • Dispatched to Driver App',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetric(
    String label,
    String value,
    String subtext,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate600),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            subtext,
            style: const TextStyle(fontSize: 9, color: AppTheme.slate400),
          ),
        ],
      ),
    );
  }
}
