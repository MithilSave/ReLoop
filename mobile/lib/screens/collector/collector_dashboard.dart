import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import 'available_listings_screen.dart';
import 'active_pickups_screen.dart';
import 'consignment_builder_screen.dart';
import 'collector_plans_screen.dart';

class CollectorDashboard extends StatelessWidget {
  const CollectorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final assignedBatches = state.batches
        .where((b) =>
            b.collectorOrgId == state.currentPersona.orgId &&
            b.status.label == 'ASSIGNED')
        .toList();

    final pickedUpBatches = state.batches
        .where((b) =>
            b.collectorOrgId == state.currentPersona.orgId &&
            b.status.label == 'PICKED_UP')
        .toList();

    double totalCollectedToday = 0;
    for (final b in state.batches) {
      if (b.collectorOrgId == state.currentPersona.orgId &&
          b.quantities.collectedKg != null) {
        totalCollectedToday += b.quantities.collectedKg!;
      }
    }
    final earningsMargin = totalCollectedToday * 3.50; // Collector fee ₹3.50/kg

    final availableCount =
        state.batches.where((b) => b.status.label == 'LISTED').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1E3A8A), Color(0xFF312E81)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('🚚', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'Fleet Aggregator & Logistics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  state.currentPersona.orgName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Doorstep weighing scale, OTP generator verification, and multi-batch consignment dispatches.',
                  style: TextStyle(color: Colors.white70, fontSize: 11),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (ctx) =>
                                    const AvailableListingsScreen()),
                          );
                        },
                        icon: const Icon(Icons.explore, size: 14),
                        label: Text('Listings ($availableCount)',
                            style: const TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF1E3A8A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (ctx) =>
                                    const CollectorPlansScreen()),
                          );
                        },
                        icon: const Icon(Icons.route, size: 14),
                        label: const Text('Routes (1)',
                            style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF38BDF8),
                          foregroundColor: const Color(0xFF0F172A),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (ctx) =>
                                    const ConsignmentBuilderScreen()),
                          );
                        },
                        icon: const Icon(Icons.local_shipping,
                            size: 14, color: Colors.white),
                        label: const Text('Dispatch',
                            style: TextStyle(
                                color: Colors.white, fontSize: 11)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // KPIs
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Today Stops',
                  value: '${assignedBatches.length}',
                  subtext: 'Pending OTP',
                  icon: Icons.location_on,
                  color: const Color(0xFF2563EB),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: 'Collected',
                  value: '${totalCollectedToday.toStringAsFixed(0)} kg',
                  subtext: 'Digital scale',
                  icon: Icons.scale,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: 'At Hub',
                  value: '${pickedUpBatches.length}',
                  subtext: 'Ready to ship',
                  icon: Icons.warehouse,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: 'Margin ₹',
                  value: '₹${earningsMargin.toStringAsFixed(0)}',
                  subtext: 'Aggregator fee',
                  icon: Icons.currency_rupee,
                  color: const Color(0xFF0D9488),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Active Assigned Stops
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Active Pickup Queue',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate900,
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (ctx) => const ActivePickupsScreen()),
                  );
                },
                child: const Text('Manage Pickups',
                    style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (assignedBatches.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Column(
                children: [
                  const Icon(Icons.check_circle_outline,
                      size: 36, color: AppTheme.slate400),
                  const SizedBox(height: 8),
                  const Text(
                    'All scheduled pickups completed!',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Browse available listings in your radius to quote new batches.',
                    style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (ctx) =>
                                const AvailableListingsScreen()),
                      );
                    },
                    child: const Text('Find Available Listings'),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: assignedBatches.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final b = assignedBatches[i];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.slate200),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  b.batchCode,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${b.material.label} (${b.quantities.estimatedKg.toStringAsFixed(0)} kg)',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.slate700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              b.pickupAddress,
                              style: const TextStyle(
                                  fontSize: 11, color: AppTheme.slate500),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) =>
                                  ActivePickupsScreen(initialBatchId: b.id),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                        child: const Text('Weigh & OTP'),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppTheme.slate900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }
}
