import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/six_stage_bar.dart';
import '../../widgets/status_badge.dart';
import '../../widgets/material_passport_dialog.dart';
import '../../widgets/contribution_certificate_dialog.dart';
import 'create_batch_screen.dart';
import 'collector_offers_screen.dart';

class GeneratorDashboard extends StatelessWidget {
  const GeneratorDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final myBatches = state.batches
        .where((b) =>
            b.generatorOrgId == state.currentPersona.orgId ||
            b.generatorName.contains('Green Society'))
        .toList();

    double totalKg = 0;
    for (final b in myBatches) {
      totalKg += b.quantities.collectedKg ?? 0;
    }
    final earnings = totalKg * 15.5; // Average ₹15.50/kg

    final assignedBatchWithOtp = myBatches.firstWhere(
      (b) => b.pickupOtp != null && b.status.label == 'ASSIGNED',
      orElse: () => myBatches.first,
    );
    final hasOtpBatch = assignedBatchWithOtp.pickupOtp != null &&
        assignedBatchWithOtp.status.label == 'ASSIGNED';

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
                colors: [Color(0xFF065F46), Color(0xFF0F766E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Text('🌱', style: TextStyle(fontSize: 12)),
                          SizedBox(width: 4),
                          Text(
                            'Segregated Source Generator',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  'Post-consumer dry plastic segregation, QR batch tracking, and doorstep scale verification.',
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
                                builder: (ctx) => const CreateBatchScreen()),
                          );
                        },
                        icon: const Icon(Icons.add_photo_alternate, size: 16),
                        label: const Text('List Batch (AI)'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF065F46),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          ContributionCertificateDialog.show(
                            context,
                            orgName: state.currentPersona.orgName,
                            totalKg: totalKg,
                            totalEarnings: earnings,
                          );
                        },
                        icon: const Icon(Icons.card_membership,
                            size: 16, color: Colors.white),
                        label: const Text('Green Cert',
                            style: TextStyle(color: Colors.white)),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.white70),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Doorstep OTP Verification Alert (if active)
          if (hasOtpBatch)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF), // Blue 50
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF93C5FD)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2563EB),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.key, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Collector Doorstep OTP Handover',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        Text(
                          'Batch ${assignedBatchWithOtp.batchCode} assigned to ${assignedBatchWithOtp.collectorName}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF3B82F6)),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Text(
                              'Share OTP with driver: ',
                              style: TextStyle(
                                  fontSize: 11, color: Color(0xFF1E3A8A)),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(6),
                                border:
                                    Border.all(color: const Color(0xFF2563EB)),
                              ),
                              child: Text(
                                assignedBatchWithOtp.pickupOtp ?? '',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1D4ED8),
                                  fontFamily: 'monospace',
                                  letterSpacing: 2,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // KPIs
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Recycled kg',
                  value: '${totalKg.toStringAsFixed(1)} kg',
                  subtext: 'Weighed on digital scale',
                  icon: Icons.scale,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: 'Total Earnings',
                  value: '₹${earnings.toStringAsFixed(0)}',
                  subtext: 'Direct UPI settlement',
                  icon: Icons.currency_rupee,
                  color: const Color(0xFF0D9488),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildKpiCard(
                  title: 'Active Batches',
                  value: '${myBatches.length}',
                  subtext: 'Traceable units',
                  icon: Icons.layers,
                  color: const Color(0xFF6366F1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Active Batches with SixStageBar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Waste Batches',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate900,
                ),
              ),
              TextButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (ctx) => const CollectorOffersScreen()),
                  );
                },
                icon: const Icon(Icons.local_offer, size: 14),
                label: const Text('Offers', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: myBatches.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 12),
            itemBuilder: (ctx, i) {
              final b = myBatches[i];
              return InkWell(
                onTap: () => MaterialPassportDialog.show(context, b),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(14),
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
                                  fontSize: 13,
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
                                  '${b.material.label} (${b.quantities.estimatedKg.toStringAsFixed(0)} kg)',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          StatusBadge(status: b.status),
                        ],
                      ),
                      const SizedBox(height: 10),
                      SixStageBar(quantities: b.quantities, compact: true),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on,
                                  size: 12, color: AppTheme.slate400),
                              const SizedBox(width: 4),
                              Text(
                                b.locality,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.slate500),
                              ),
                            ],
                          ),
                          Row(
                            children: const [
                              Text(
                                'View Passport',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.primary,
                                ),
                              ),
                              Icon(Icons.chevron_right,
                                  size: 14, color: AppTheme.primary),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
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
}
