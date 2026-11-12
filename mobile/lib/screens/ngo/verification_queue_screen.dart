import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';
import 'batch_review_screen.dart';
import 'ngo_impact_dialog.dart';

class VerificationQueueScreen extends StatefulWidget {
  const VerificationQueueScreen({super.key});

  @override
  State<VerificationQueueScreen> createState() =>
      _VerificationQueueScreenState();
}

class _VerificationQueueScreenState extends State<VerificationQueueScreen> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final allBatches = state.batches;

    final filtered = allBatches.where((b) {
      if (_selectedFilter == 'ALL') return true;
      if (_selectedFilter == 'PENDING') {
        return b.verification?.decision == 'PENDING' ||
            (b.verification == null &&
                ['RECEIVED', 'PROCESSED'].contains(b.status.label));
      }
      return b.verification?.decision == _selectedFilter;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Independent NGO Audit Queue'),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: 'Audit & Impact Report',
            onPressed: () => NGOImpactDialog.show(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('ALL', 'All Batches'),
                _buildFilterChip('PENDING', 'Pending Audit'),
                _buildFilterChip('VERIFIED', 'Verified'),
                _buildFilterChip('REQUIRES_CORRECTION', 'Needs Correction'),
                _buildFilterChip('FLAGGED', 'Flagged'),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.slate200),

          // Queue List
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'No batches found for this audit state.',
                      style: TextStyle(color: AppTheme.slate500),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final b = filtered[i];
                      final ver = b.verification;

                      return InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => BatchReviewScreen(batch: b),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
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
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        b.batchCode,
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
                                          color: AppTheme.primaryLight,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${b.material.label} (${(b.quantities.processedKg ?? b.quantities.acceptedKg ?? b.quantities.estimatedKg).toStringAsFixed(0)} kg)',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                            color: AppTheme.primaryDark,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (ver != null)
                                    StatusBadge(
                                      status: ver.decision,
                                      isVerification: true,
                                    )
                                  else
                                    const StatusBadge(
                                      status: 'PENDING',
                                      isVerification: true,
                                    ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Origin: ${b.generatorName} (${b.locality})',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.slate800),
                              ),
                              Text(
                                'Processor: ${b.recyclerName ?? 'Apex Plastic Recovery PWP'}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.slate500),
                              ),
                              const SizedBox(height: 10),
                              const Divider(height: 1, color: AppTheme.slate100),
                              const SizedBox(height: 8),

                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.shield,
                                          size: 13, color: AppTheme.primary),
                                      const SizedBox(width: 4),
                                      Text(
                                        ver != null
                                            ? '${ver.evidenceReviewed.length} evidence docs attached'
                                            : 'Audit pending review',
                                        style: const TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.slate600),
                                      ),
                                    ],
                                  ),
                                  Row(
                                    children: const [
                                      Text(
                                        'Open Audit Dossier',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
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
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSel = _selectedFilter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSel,
        selectedColor: AppTheme.primaryLight,
        backgroundColor: Colors.white,
        side: BorderSide(
          color: isSel ? AppTheme.primary : AppTheme.slate300,
        ),
        labelStyle: TextStyle(
          fontSize: 11,
          fontWeight: isSel ? FontWeight.bold : FontWeight.normal,
          color: isSel ? AppTheme.primaryDark : AppTheme.slate700,
        ),
        onSelected: (val) {
          if (val) setState(() => _selectedFilter = value);
        },
      ),
    );
  }
}
