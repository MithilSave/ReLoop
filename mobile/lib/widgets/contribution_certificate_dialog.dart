import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ContributionCertificateDialog extends StatelessWidget {
  final String orgName;
  final double totalKg;
  final double totalEarnings;

  const ContributionCertificateDialog({
    super.key,
    required this.orgName,
    required this.totalKg,
    required this.totalEarnings,
  });

  static void show(
    BuildContext context, {
    required String orgName,
    required double totalKg,
    required double totalEarnings,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => ContributionCertificateDialog(
        orgName: orgName,
        totalKg: totalKg,
        totalEarnings: totalEarnings,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Environmental equivalence calculations
    final co2Kg = totalKg * 1.8; // 1.8 kg CO2e saved per kg mechanical recycled PET/PP
    final waterLitres = totalKg * 24.0; // 24 L water saved per kg virgin polymer offset
    final treesEquiv = (co2Kg / 21.7).toStringAsFixed(1); // 1 mature tree absorbs ~21.7 kg CO2/yr

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Certificate Header Stamp
              Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: const Text(
                    'NON-STATUTORY VOLUNTARY RECYCLING CERTIFICATE',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryDark,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              const Center(
                child: Text(
                  'Circular Impact Certificate',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.slate900,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              const Center(
                child: Text(
                  'Issued by ReLoop Digital Traceability Hub • Mumbai Pilot',
                  style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                ),
              ),
              const SizedBox(height: 16),

              // Recipient Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Column(
                  children: [
                    const Text(
                      'PROUDLY PRESENTED TO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate400,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      orgName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate900,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'For verifiable segregation, collection, and ethical channelization of post-consumer plastic waste.',
                      style: TextStyle(fontSize: 11, color: AppTheme.slate600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Metrics Cards
              Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      'Diverted Plastic',
                      '${totalKg.toStringAsFixed(1)} kg',
                      'From landfill dumping',
                      Icons.recycling,
                      AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetric(
                      'GHG Avoided',
                      '${co2Kg.toStringAsFixed(1)} kg',
                      'CO2e equivalent',
                      Icons.cloud_done,
                      const Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildMetric(
                      'Water Conserved',
                      '${waterLitres.toStringAsFixed(0)} L',
                      'Virgin process offset',
                      Icons.water_drop,
                      const Color(0xFF0D9488),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildMetric(
                      'Trees Equiv.',
                      '$treesEquiv yrs',
                      'Annual absorption',
                      Icons.park,
                      const Color(0xFF15803D),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Disclaimer Banner
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.amber50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.amber200),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppTheme.amber600),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Disclaimer: This certificate reflects voluntary circular contributions by the source generator and cannot be traded or used as statutory EPR compliance fulfillment credits under CPCB rules.',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.amber800,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Close Button
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Close Certificate'),
              ),
            ],
          ),
        ),
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
        color: color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
              fontFamily: 'monospace',
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate700,
            ),
          ),
          Text(
            subtext,
            style: const TextStyle(fontSize: 8, color: AppTheme.slate500),
          ),
        ],
      ),
    );
  }
}
