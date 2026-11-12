import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class NGOImpactDialog extends StatelessWidget {
  const NGOImpactDialog({super.key});

  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => const NGOImpactDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0369A1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.assessment,
                            color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'NGO Impact & Audit Summary',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.slate900,
                            ),
                          ),
                          Text(
                            'Mumbai Pilot Traceability Audits',
                            style: TextStyle(
                                fontSize: 10, color: AppTheme.slate500),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Overall Audit Scoreboard
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.slate50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Independent Audit Verification Rate',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.slate700),
                        ),
                        Text(
                          '88.4%',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 884,
                            child: Container(
                                height: 10, color: AppTheme.primary),
                          ),
                          Expanded(
                            flex: 72,
                            child: Container(
                                height: 10, color: AppTheme.amber500),
                          ),
                          Expanded(
                            flex: 44,
                            child: Container(
                                height: 10, color: AppTheme.red500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('88.4% Verified',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.bold)),
                        Text('7.2% Requires Correction',
                            style: TextStyle(
                                fontSize: 9,
                                color: Color(0xFFB45309),
                                fontWeight: FontWeight.bold)),
                        Text('4.4% Flagged',
                            style: TextStyle(
                                fontSize: 9,
                                color: AppTheme.red600,
                                fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Locality Breakdown Table
              const Text(
                'Audit Coverage by Mumbai Locality',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate900,
                ),
              ),
              const SizedBox(height: 8),
              _buildLocalityRow('Andheri West', '640 kg', '98.2%', '0 flags'),
              _buildLocalityRow('Dharavi', '1,200 kg', '96.5%', '1 resolved'),
              _buildLocalityRow('Bandra West', '310 kg', '100.0%', '0 flags'),
              _buildLocalityRow('Kurla East', '550 kg', '91.0%', '1 flagged'),
              const SizedBox(height: 16),

              // Mass Balance Discrepancy Table
              const Text(
                'Mass Balance Discrepancy Thresholds',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate900,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Column(
                  children: [
                    _buildVarianceRow('Doorstep Scale vs Listed', '-2.1%',
                        '< 5.0% threshold', true),
                    const Divider(height: 1, color: AppTheme.slate100),
                    _buildVarianceRow('Weighbridge vs Collector', '-0.8%',
                        '< 3.0% threshold', true),
                    const Divider(height: 1, color: AppTheme.slate100),
                    _buildVarianceRow('Extrusion Input vs Sum', '±0.0%',
                        'Exact match required', true),
                    const Divider(height: 1, color: AppTheme.slate100),
                    _buildVarianceRow('Pellet Output + Residue', '100.0%',
                        'Conservation of mass', true),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Export Action
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                          'Full NGO Traceability & Reconciliation Audit Report downloaded (PDF).'),
                      backgroundColor: Color(0xFF0369A1),
                    ),
                  );
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.picture_as_pdf, size: 16),
                label: const Text('Export Official Audit Pack (PDF)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0369A1),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalityRow(
      String locality, String volume, String passRate, String flagInfo) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              locality,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.slate800),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              volume,
              style: const TextStyle(
                fontSize: 11,
                fontFamily: 'monospace',
                color: AppTheme.slate600,
              ),
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              passRate,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                color: AppTheme.primaryDark,
              ),
            ),
          ),
          Text(
            flagInfo,
            style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
          ),
        ],
      ),
    );
  }

  Widget _buildVarianceRow(
      String stage, String variance, String limit, bool isPassed) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            stage,
            style: const TextStyle(fontSize: 11, color: AppTheme.slate700),
          ),
          Row(
            children: [
              Text(
                variance,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                  color: isPassed ? AppTheme.primaryDark : AppTheme.red600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '($limit)',
                style: const TextStyle(fontSize: 9, color: AppTheme.slate400),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
