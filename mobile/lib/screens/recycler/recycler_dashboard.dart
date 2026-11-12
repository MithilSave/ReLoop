import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import 'inbound_weighbridge_screen.dart';
import 'processing_runs_screen.dart';
import 'sourcing_planner_screen.dart';
import 'landed_cost_screen.dart';
import 'allocations_screen.dart';
import 'supply_outlook_screen.dart';

class RecyclerDashboard extends StatelessWidget {
  const RecyclerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final inTransitCount =
        state.batches.where((b) => b.status.label == 'IN_TRANSIT').length;
    final receivedCount =
        state.batches.where((b) => b.status.label == 'RECEIVED').length;
    final totalEligibleKg =
        state.processingRuns.fold<double>(0, (sum, r) => sum + r.eligibleKg);
    final totalAllocatedKg =
        state.processingRuns.fold<double>(0, (sum, r) => sum + r.allocatedKg);

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
                colors: [Color(0xFF581C87), Color(0xFF3B0764)],
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
                      Text('🏭', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'Plastic Waste Processor (PWP)',
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
                  'Mechanical extrusion, measured yield mass balance, and non-fungible CPCB EPR credit allocations.',
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
                                    const InboundWeighbridgeScreen()),
                          );
                        },
                        icon: const Icon(Icons.scale, size: 16),
                        label: Text('Inbound ($inTransitCount)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF581C87),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (ctx) =>
                                    const ProcessingRunsScreen()),
                          );
                        },
                        icon: const Icon(Icons.recycling,
                            size: 16, color: Colors.white),
                        label: const Text('New Run',
                            style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white54),
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
                  title: 'Inbound LCVs',
                  value: '$inTransitCount batches',
                  subtext: 'En route to gate',
                  icon: Icons.local_shipping,
                  color: const Color(0xFF7C3AED),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: 'At Plant Bay',
                  value: '$receivedCount ready',
                  subtext: 'Weighed & accepted',
                  icon: Icons.warehouse,
                  color: const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: 'Eligible Output',
                  value: '${totalEligibleKg.toStringAsFixed(0)} kg',
                  subtext: '${totalAllocatedKg.toStringAsFixed(0)} kg claimed',
                  icon: Icons.verified,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Core Recycler Modules Navigation
          const Text(
            'Recycling Operations & Sourcing',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.slate900,
            ),
          ),
          const SizedBox(height: 10),

          _buildActionCard(
            context: context,
            title: 'Inbound Weighbridge & Quality Inspection',
            subtitle:
                'Scan QR tokens, record gate weighbridge slips, and separate non-conforming reject fractions.',
            icon: Icons.scale,
            color: const Color(0xFF0D9488),
            badge: '$inTransitCount pending',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (ctx) => const InboundWeighbridgeScreen()),
              );
            },
          ),
          const SizedBox(height: 10),

          _buildActionCard(
            context: context,
            title: 'Mechanical Processing Runs & Measured Yield',
            subtitle:
                'Combine multiple batches into one extrusion run with strict mass balance calculation (Input = Output + Residue).',
            icon: Icons.recycling,
            color: AppTheme.primary,
            badge: '${state.processingRuns.length} runs logged',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (ctx) => const ProcessingRunsScreen()),
              );
            },
          ),
          const SizedBox(height: 10),

          _buildActionCard(
            context: context,
            title: 'Smart Feedstock Sourcing Planner',
            subtitle:
                'Generate greedy aggregation sourcing plans for high-demand polymers (e.g. 500 kg PP) from scattered local listings.',
            icon: Icons.explore,
            color: const Color(0xFF2563EB),
            badge: '1 plan proposed',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (ctx) => const SourcingPlannerScreen()),
              );
            },
          ),
          const SizedBox(height: 10),

          _buildActionCard(
            context: context,
            title: 'Landed Cost Optimizer',
            subtitle:
                'Compare true procurement cost per usable kg against spot traders and direct collectors with full cost waterfall.',
            icon: Icons.waterfall_chart,
            color: const Color(0xFFD97706),
            badge: 'Cost breakdown',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (ctx) => const LandedCostScreen()),
              );
            },
          ),
          const SizedBox(height: 10),

          _buildActionCard(
            context: context,
            title: 'Supply Outlook & Feedstock Forecast',
            subtitle:
                'Compare confirmed contracts vs predicted informal sector recovery with automated shortfall detection.',
            icon: Icons.trending_up,
            color: const Color(0xFF0284C7),
            badge: '4-week outlook',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (ctx) => const SupplyOutlookScreen()),
              );
            },
          ),
          const SizedBox(height: 10),

          _buildActionCard(
            context: context,
            title: 'EPR Allocation Ledger & Certificates',
            subtitle:
                'Allocate certified post-consumer recycling volume to brand owners with database-level over-allocation prevention.',
            icon: Icons.assignment_turned_in,
            color: const Color(0xFF7C3AED),
            badge: '${state.allocations.length} allocations',
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (ctx) => const AllocationsScreen()),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppTheme.slate900,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required String badge,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.slate200),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.slate900,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.slate100,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.slate600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style:
                        const TextStyle(fontSize: 11, color: AppTheme.slate500),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
