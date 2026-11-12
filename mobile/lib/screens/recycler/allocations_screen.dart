import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class AllocationsScreen extends StatefulWidget {
  const AllocationsScreen({super.key});

  @override
  State<AllocationsScreen> createState() => _AllocationsScreenState();
}

class _AllocationsScreenState extends State<AllocationsScreen> {
  void _showNewAllocationModal(BuildContext context) {
    final state = Provider.of<AppState>(context, listen: false);
    final runs = state.processingRuns;
    if (runs.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No processing runs available for allocation.')),
      );
      return;
    }

    String selectedRunId = runs.first.id;
    String eprOrgName = 'EcoConsumer Brands India';
    String eprOrgId = 'org-epr-01';
    double qty = 20.0;
    String period = 'FY 2026-27 (Q3)';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final curRun = runs.firstWhere((r) => r.id == selectedRunId);
          final available = curRun.eligibleKg - curRun.allocatedKg;

          return Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              top: 20,
              left: 20,
              right: 20,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Allocate CPCB Credit',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                  const Divider(height: 1, color: AppTheme.slate200),
                  const SizedBox(height: 16),

                  const Text('1. Source Processing Run',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedRunId,
                    items: runs
                        .map((r) => DropdownMenuItem(
                              value: r.id,
                              child: Text(
                                '${r.runCode} • ${r.materialCode.label} (${(r.eligibleKg - r.allocatedKg).toStringAsFixed(1)} kg available)',
                                style: const TextStyle(fontSize: 12),
                              ),
                            ))
                        .toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() => selectedRunId = val);
                      }
                    },
                  ),
                  const SizedBox(height: 14),

                  const Text('2. Target Brand Owner (PIBO)',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: eprOrgName,
                    decoration: const InputDecoration(
                      hintText: 'Enter corporate buyer...',
                    ),
                    onChanged: (val) => eprOrgName = val,
                  ),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('3. Allocation Quantity (kg)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold)),
                      Text(
                        'Max available: ${available.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: qty.toString(),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      suffixText: 'kg',
                    ),
                    onChanged: (val) {
                      final p = double.tryParse(val);
                      if (p != null) qty = p;
                    },
                  ),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      final res = state.createEPRAllocation(
                        processingRunId: selectedRunId,
                        eprOrgId: eprOrgId,
                        eprOrgName: eprOrgName,
                        quantityKg: qty,
                        period: period,
                      );

                      if (res['success'] == true) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Allocated ${qty.toStringAsFixed(1)} kg to $eprOrgName!'),
                            backgroundColor: AppTheme.primary,
                          ),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(res['error']),
                            backgroundColor: const Color(0xFFBE123C),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Confirm & Log Allocation'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _showReverseDialog(BuildContext context, String allocId) {
    String reason = 'Commercial order amendment by corporate client';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reverse Allocation',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Reversing will restore eligible kg capacity back to the source processing run. This event will be logged in the immutable audit chain.',
              style: TextStyle(fontSize: 11, color: AppTheme.slate600),
            ),
            const SizedBox(height: 12),
            const Text('Audit Reason:',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            TextFormField(
              initialValue: reason,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              onChanged: (val) => reason = val,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final state = Provider.of<AppState>(context, listen: false);
              state.reverseEPRAllocation(allocId, reason);
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Allocation reversed and capacity restored.'),
                  backgroundColor: AppTheme.primary,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFBE123C),
              foregroundColor: Colors.white,
            ),
            child: const Text('Confirm Reversal'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final allocs = state.allocations;

    return Scaffold(
      appBar: AppBar(
        title: const Text('EPR Credit Allocation Ledger'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewAllocationModal(context),
          ),
        ],
      ),
      body: allocs.isEmpty
          ? const Center(
              child: Text('No allocations recorded yet.',
                  style: TextStyle(color: AppTheme.slate500)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: allocs.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final a = allocs[i];
                final isActive = a.status == 'ACTIVE';

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isActive ? AppTheme.slate200 : const Color(0xFFFECDD3),
                    ),
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
                                  color: isActive
                                      ? AppTheme.primaryLight
                                      : const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  a.status,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: isActive
                                        ? AppTheme.primaryDark
                                        : const Color(0xFFBE123C),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            '${a.quantityKg.toStringAsFixed(1)} kg',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: isActive
                                  ? AppTheme.slate900
                                  : AppTheme.slate400,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Buyer: ${a.eprOrgName}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.slate800,
                        ),
                      ),
                      Text(
                        'Extrusion Run: ${a.runCode} (${a.packagingCategory.label}) • Period: ${a.reportingPeriod}',
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.slate600),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Certificate Reference: ${a.certificateId}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontFamily: 'monospace',
                          color: AppTheme.slate400,
                        ),
                      ),
                      if (!isActive && a.reversalReason != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Reversed: ${a.reversalReason}',
                            style: const TextStyle(
                                fontSize: 10, color: Color(0xFFBE123C)),
                          ),
                        ),
                      ],
                      if (isActive) ...[
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            TextButton.icon(
                              onPressed: () =>
                                  _showReverseDialog(context, a.id),
                              icon: const Icon(Icons.undo,
                                  size: 14, color: Color(0xFFBE123C)),
                              label: const Text(
                                'Reverse Allocation',
                                style: TextStyle(
                                    fontSize: 11, color: Color(0xFFBE123C)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewAllocationModal(context),
        icon: const Icon(Icons.add),
        label: const Text('Allocate Credit'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }
}
