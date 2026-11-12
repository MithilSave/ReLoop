import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import 'allocations_ledger_screen.dart';
import 'epr_evidence_screen.dart';

class ComplianceDashboardScreen extends StatelessWidget {
  const ComplianceDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final targets = state.eprTargets;

    double totalTargetKg = 0;
    double totalAllocatedKg = 0;
    double totalVerifiedKg = 0;

    for (final t in targets) {
      totalTargetKg += t.targetKg;
      totalAllocatedKg += t.allocatedKg;
      totalVerifiedKg += t.verifiedKg;
    }

    final overallPct = totalTargetKg > 0
        ? ((totalAllocatedKg / totalTargetKg) * 100).clamp(0, 100).toInt()
        : 0;

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
                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
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
                      Text('🏢', style: TextStyle(fontSize: 12)),
                      SizedBox(width: 4),
                      Text(
                        'EPR Brand Owner (PIBO)',
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
                  'CPCB Plastic Waste Management Compliance (EPR Rules 2022). Zero unverified allocations.',
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
                                    const AllocationsLedgerScreen()),
                          );
                        },
                        icon: const Icon(Icons.receipt_long, size: 14),
                        label: const Text('Trace Ledger',
                            style: TextStyle(fontSize: 11)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 8),
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
                                    const EPREvidenceScreen()),
                          );
                        },
                        icon: const Icon(Icons.verified_user_outlined,
                            size: 14, color: Colors.white),
                        label: const Text('Evidence Pack',
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

          // Overall Target Completion Bar Card
          Container(
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
                    const Text(
                      'FY 2026-27 EPR Target Fulfilment',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate900,
                      ),
                    ),
                    Text(
                      '$overallPct% Completed',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: overallPct / 100,
                    minHeight: 8,
                    backgroundColor: AppTheme.slate100,
                    color: AppTheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCol('Target Mandate',
                        '${totalTargetKg.toStringAsFixed(0)} kg'),
                    _buildStatCol('Allocated Volume',
                        '${totalAllocatedKg.toStringAsFixed(0)} kg'),
                    _buildStatCol('Verified Volume',
                        '${totalVerifiedKg.toStringAsFixed(0)} kg',
                        isHighlight: true),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Packaging Category Targets Breakdown
          const Text(
            'Mandated Packaging Categories (CPCB)',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppTheme.slate900,
            ),
          ),
          const SizedBox(height: 10),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: targets.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final t = targets[i];
              final catPct = t.targetKg > 0
                  ? ((t.allocatedKg / t.targetKg) * 100).clamp(0, 100).toInt()
                  : 0;

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
                        Text(
                          t.categoryLabel,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.slate900,
                          ),
                        ),
                        Text(
                          '$catPct%',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: catPct / 100,
                        minHeight: 6,
                        backgroundColor: AppTheme.slate100,
                        color: AppTheme.primary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Target: ${t.targetKg.toStringAsFixed(0)} kg',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.slate500),
                        ),
                        Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Verified: ${t.verifiedKg.toStringAsFixed(0)} kg',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857),
                              ),
                            ),
                            if (t.unverifiedKg > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: Color(0xFFF59E0B),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Pending: ${t.unverifiedKg.toStringAsFixed(0)} kg',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
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

  Widget _buildStatCol(String label, String value, {bool isHighlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontSize: 10, color: AppTheme.slate500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: isHighlight ? AppTheme.primaryDark : AppTheme.slate900,
          ),
        ),
      ],
    );
  }
}
