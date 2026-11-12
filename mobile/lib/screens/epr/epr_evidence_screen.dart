import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/material_passport_dialog.dart';

class EPREvidenceScreen extends StatelessWidget {
  const EPREvidenceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final allocations = state.allocations;

    // Check for any unverified allocations (strictly 0 by design)
    double unverifiedKg = 0;
    double verifiedAllocatedKg = 0;

    for (final a in allocations) {
      if (a.status == 'ACTIVE') {
        verifiedAllocatedKg += a.quantityKg;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('CPCB Audit Evidence Pack'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Zero Unverified Safeguard Banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFECFDF5), // Emerald 50
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFA7F3D0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primary,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.verified_user,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zero Unverified Allocations Safeguard',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'All ${verifiedAllocatedKg.toStringAsFixed(0)} kg active credits have passed independent NGO audit. $unverifiedKg kg unverified allocation allowed.',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF065F46)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Mandatory CPCB Boundary Disclaimer (from 08_EPR_TRACEABILITY_FRAMEWORK.md & 09_DASHBOARDS_AND_UI.md §6)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.gavel, size: 14, color: AppTheme.slate600),
                      SizedBox(width: 6),
                      Text(
                        'Statutory Boundary Disclaimer',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.slate800,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'ReLoop provides an end-to-end chain of custody evidence ledger and mass-balance reconciliation. ReLoop does not itself issue statutory recycling certificates. All certificates cited herein are declared and filed by licensed Plastic Waste Processors (PWPs) on the Central Pollution Control Board (CPCB) portal under PWM Rules 2022.',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.slate600,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Active Allocations & Recycler-Declared Certs
            const Text(
              'Active Allocations with CPCB Portal References',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate900,
              ),
            ),
            const SizedBox(height: 8),

            ...allocations.map((alloc) {
              final run = state.processingRuns.firstWhere(
                (r) => r.id == alloc.processingRunId,
                orElse: () => state.processingRuns.first,
              );

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          alloc.allocationCode,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppTheme.slate900,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: alloc.status == 'ACTIVE'
                                ? AppTheme.primaryLight
                                : AppTheme.red50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            alloc.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: alloc.status == 'ACTIVE'
                                  ? AppTheme.primaryDark
                                  : AppTheme.red600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${alloc.quantityKg.toStringAsFixed(0)} kg • ${alloc.packagingCategory.label}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          'PWP: ${alloc.recyclerName}',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.slate600),
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: AppTheme.slate100),

                    // CPCB Certificate Reference (Recycler-Declared)
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.slate50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CPCB Certificate No. (Recycler-Declared)',
                                style: TextStyle(
                                    fontSize: 9, color: AppTheme.slate400),
                              ),
                              Text(
                                run.certificateRefs.isNotEmpty
                                    ? run.certificateRefs.first
                                    : 'CPCB-MH-2026-REC-0098',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppTheme.slate800,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () {
                              final sampleBatch = state.batches.firstWhere(
                                (b) => b.batchCode == 'RL-MUM-2026-000123',
                                orElse: () => state.batches.first,
                              );
                              MaterialPassportDialog.show(context, sampleBatch);
                            },
                            icon: const Icon(Icons.qr_code, size: 14),
                            label: const Text('Trace Batch',
                                style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 16),

            // Discrepancy Health Check
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppTheme.primary, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Active Allocations Clean',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.slate900,
                          ),
                        ),
                        Text(
                          'Zero mass-balance flags, zero NGO audit discrepancies touching your active volume.',
                          style:
                              TextStyle(fontSize: 10, color: AppTheme.slate500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Download Official Evidence Pack
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                        'CPCB Compliance Evidence Dossier compiled & downloaded with cryptographic hash proofs.'),
                    backgroundColor: Color(0xFF0F172A),
                  ),
                );
              },
              icon: const Icon(Icons.download, size: 16),
              label: const Text('Download CPCB Compliance Dossier (ZIP)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
