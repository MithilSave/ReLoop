import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class SourcingPlannerScreen extends StatelessWidget {
  const SourcingPlannerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final plans = state.aggregationPlans;
    if (plans.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Smart Sourcing Planner')),
        body: const Center(child: Text('No aggregation plans generated.')),
      );
    }

    final p = plans.first;
    final isAccepted = p.status == 'ACCEPTED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Aggregation Planner'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Plan Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        p.planCode,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isAccepted
                              ? const Color(0xFF10B981)
                              : const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          isAccepted ? '✓ Plan Accepted' : 'Proposed',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Target Demand: ${p.targetKg.toStringAsFixed(0)} kg ${p.materialCode.label} (Need by: ${p.needBy})',
                    style:
                        const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _buildHeaderStat('Total Planned',
                          '${p.totalEstimatedKg.toStringAsFixed(1)} kg'),
                      _buildHeaderStat('Expected Usable',
                          '${p.expectedUsableKg.toStringAsFixed(1)} kg'),
                      _buildHeaderStat('Landed ₹ / kg',
                          '₹${p.landedCostPerUsableKg.toStringAsFixed(2)}'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Suggested Collector & Feasibility
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping,
                      color: Color(0xFF1D4ED8), size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Suggested Logistics Aggregator',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A8A)),
                        ),
                        Text(
                          p.suggestedCollectorName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const Text(
                          'Optimal 4-stop Western Suburbs EV LCV route',
                          style: TextStyle(
                              fontSize: 10, color: Color(0xFF3B82F6)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Planned Stops Sequence
            Text(
              'Planned Pickup Sequence (${p.items.length} Stops)',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate900,
              ),
            ),
            const SizedBox(height: 8),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: p.items.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 8),
              itemBuilder: (ctx, i) {
                final item = p.items[i];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.slate200),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${item.sequenceNo}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  item.batchCode,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                Text(
                                  '${item.kg.toStringAsFixed(1)} kg',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                    color: AppTheme.slate900,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${item.locality} (${item.address})',
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.slate600),
                            ),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children: item.reasons.map((r) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.slate100,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    r,
                                    style: const TextStyle(
                                        fontSize: 9, color: AppTheme.slate600),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 16),

            // Excluded Batches Card
            if (p.excluded.isNotEmpty) ...[
              const Text(
                'Excluded Batches (Hard Rule Violations)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate800,
                ),
              ),
              const SizedBox(height: 6),
              ...p.excluded.map((ex) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFECDD3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.block, size: 16, color: Color(0xFFBE123C)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${ex.batchCode} (${ex.kg.toStringAsFixed(0)} kg in ${ex.locality})',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF9F1239),
                              ),
                            ),
                            Text(
                              ex.reason,
                              style: const TextStyle(
                                fontSize: 10,
                                color: Color(0xFFBE123C),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ],
            const SizedBox(height: 24),

            if (!isAccepted)
              ElevatedButton.icon(
                onPressed: () {
                  state.acceptAggregationPlan(p.id);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Plan ${p.planCode} accepted! Collection dispatch notifications sent.'),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                },
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: const Text('Accept Aggregation Plan & Issue Dispatches'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderStat(String title, String val) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(color: Colors.white60, fontSize: 10)),
          const SizedBox(height: 2),
          Text(
            val,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
    );
  }
}
