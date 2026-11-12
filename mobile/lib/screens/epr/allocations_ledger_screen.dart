import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/material_passport_dialog.dart';

class AllocationsLedgerScreen extends StatelessWidget {
  const AllocationsLedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final allocs = state.allocations
        .where((a) => a.eprOrgId == state.currentPersona.orgId)
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('EPR Credit Traceability Ledger'),
      ),
      body: allocs.isEmpty
          ? const Center(
              child: Text(
                'No allocations recorded for your organization yet.',
                style: TextStyle(color: AppTheme.slate500),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: allocs.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) {
                final a = allocs[i];
                final isVerified = a.isNgoVerified;

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
                                a.allocationCode,
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
                                  color: isVerified
                                      ? AppTheme.primaryLight
                                      : const Color(0xFFFFFBEB),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: isVerified
                                        ? const Color(0xFFA7F3D0)
                                        : const Color(0xFFFDE68A),
                                  ),
                                ),
                                child: Text(
                                  isVerified ? '✓ NGO Verified' : 'Pending Verification',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isVerified
                                        ? AppTheme.primaryDark
                                        : const Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${a.quantityKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: AppTheme.slate900,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'PWP Recycler: ${a.recyclerName}',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Category: ${a.packagingCategory.label} • Reporting Period: ${a.reportingPeriod}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.slate600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Statutory Certificate Ref: ${a.certificateId}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: AppTheme.slate400,
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppTheme.slate100),
                      const SizedBox(height: 10),

                      const Text(
                        'Source Batches Lineage (Pro-Rata Attribution):',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.slate700),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: a.batchCodes.map((bCode) {
                          final matchBatch = state.batches.firstWhere(
                            (b) => b.batchCode == bCode,
                            orElse: () => state.batches.first,
                          );

                          return ActionChip(
                            avatar: const Icon(Icons.qr_code,
                                size: 14, color: AppTheme.primary),
                            label: Text(
                              bCode,
                              style: const TextStyle(
                                fontSize: 10,
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            backgroundColor: AppTheme.slate50,
                            side: const BorderSide(color: AppTheme.slate200),
                            onPressed: () {
                              MaterialPassportDialog.show(context, matchBatch);
                            },
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
