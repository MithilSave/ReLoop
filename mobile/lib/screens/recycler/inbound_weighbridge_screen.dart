import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/material_passport_dialog.dart';

class InboundWeighbridgeScreen extends StatefulWidget {
  const InboundWeighbridgeScreen({super.key});

  @override
  State<InboundWeighbridgeScreen> createState() =>
      _InboundWeighbridgeScreenState();
}

class _InboundWeighbridgeScreenState extends State<InboundWeighbridgeScreen> {
  String? _selectedBatchId;
  final TextEditingController _receivedCtrl = TextEditingController(text: '97.5');
  final TextEditingController _acceptedCtrl = TextEditingController(text: '90.0');
  final TextEditingController _rejectedCtrl = TextEditingController(text: '7.5');
  final TextEditingController _rejectionReasonCtrl = TextEditingController(
    text: 'Adhesive tape and dirt reject fraction separated at bale breaker',
  );
  String _qualityGrade = 'A';
  double _contaminationPct = 7.5;

  @override
  void dispose() {
    _receivedCtrl.dispose();
    _acceptedCtrl.dispose();
    _rejectedCtrl.dispose();
    _rejectionReasonCtrl.dispose();
    super.dispose();
  }

  void _receive(WasteBatch batch) {
    final received = double.tryParse(_receivedCtrl.text) ?? 0;
    final accepted = double.tryParse(_acceptedCtrl.text) ?? 0;
    final rejected = double.tryParse(_rejectedCtrl.text) ?? 0;

    // Strict validation check: accepted + rejected = received
    if ((accepted + rejected - received).abs() > 0.05) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Mass Balance Violation: Accepted kg + Rejected kg must equal Received kg.'),
          backgroundColor: Color(0xFFBE123C),
        ),
      );
      return;
    }

    final state = Provider.of<AppState>(context, listen: false);
    state.receiveBatch(
      batchId: batch.id,
      receivedKg: received,
      acceptedKg: accepted,
      rejectedKg: rejected,
      qualityGrade: _qualityGrade,
      contaminationPct: _contaminationPct,
      rejectionReason: _rejectionReasonCtrl.text,
    );

    setState(() => _selectedBatchId = null);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Batch ${batch.batchCode} received at plant gate! (Accepted: ${accepted.toStringAsFixed(1)} kg)'),
        backgroundColor: AppTheme.primary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final inTransitBatches =
        state.batches.where((b) => b.status.label == 'IN_TRANSIT').toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inbound Weighbridge Receipt'),
      ),
      body: inTransitBatches.isEmpty
          ? const Center(
              child: Text(
                'No batches in transit to this plant right now.',
                style: TextStyle(color: AppTheme.slate500),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: inTransitBatches.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final b = inTransitBatches[i];
                final isExpanded = _selectedBatchId == b.id;

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isExpanded ? AppTheme.primary : AppTheme.slate200,
                      width: isExpanded ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        title: Row(
                          children: [
                            Text(
                              b.batchCode,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'monospace',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFAF5FF),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                    color: const Color(0xFFE9D5FF)),
                              ),
                              child: Text(
                                'In Transit (${(b.quantities.collectedKg ?? b.quantities.estimatedKg).toStringAsFixed(0)} kg)',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF7E22CE),
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${b.material.label} • Shipped by ${b.collectorName ?? 'Collector'}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.slate800),
                            ),
                            Text('Origin: ${b.generatorName} (${b.locality})',
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.slate500)),
                          ],
                        ),
                        trailing: ElevatedButton(
                          onPressed: () {
                            setState(() {
                              if (_selectedBatchId == b.id) {
                                _selectedBatchId = null;
                              } else {
                                _selectedBatchId = b.id;
                                final coll = b.quantities.collectedKg ??
                                    b.quantities.estimatedKg;
                                _receivedCtrl.text = coll.toStringAsFixed(1);
                                _acceptedCtrl.text =
                                    (coll * 0.95).toStringAsFixed(1);
                                _rejectedCtrl.text =
                                    (coll * 0.05).toStringAsFixed(1);
                              }
                            });
                          },
                          child: Text(isExpanded ? 'Close' : 'Weigh In'),
                        ),
                      ),

                      // Weighbridge Drawer
                      if (isExpanded)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppTheme.slate50,
                            borderRadius: BorderRadius.vertical(
                                bottom: Radius.circular(16)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Divider(height: 1, color: AppTheme.slate200),
                              const SizedBox(height: 14),

                              const Text(
                                'Weighbridge Balance Check (Rule: Accepted + Rejected = Received)',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.slate700),
                              ),
                              const SizedBox(height: 12),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Gross Received (kg)',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _receivedCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                          ),
                                          onChanged: (val) => setState(() {}),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Accepted (kg)',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _acceptedCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                          ),
                                          onChanged: (val) => setState(() {}),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Rejected (kg)',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        TextField(
                                          controller: _rejectedCtrl,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8),
                                          ),
                                          onChanged: (val) => setState(() {}),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Quality Grade',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        DropdownButtonFormField<String>(
                                          value: _qualityGrade,
                                          items: ['A', 'B', 'C']
                                              .map((g) => DropdownMenuItem(
                                                    value: g,
                                                    child: Text('Grade $g'),
                                                  ))
                                              .toList(),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() => _qualityGrade = val);
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('Contamination %',
                                            style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold)),
                                        const SizedBox(height: 4),
                                        TextFormField(
                                          initialValue:
                                              _contaminationPct.toString(),
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            suffixText: '%',
                                          ),
                                          onChanged: (val) {
                                            final parsed = double.tryParse(val);
                                            if (parsed != null) {
                                              _contaminationPct = parsed;
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              const Text('Rejection Reason / Note',
                                  style: TextStyle(
                                      fontSize: 11, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              TextField(
                                controller: _rejectionReasonCtrl,
                                decoration: const InputDecoration(
                                  hintText:
                                      'Disposition note for rejected fractions...',
                                ),
                              ),
                              const SizedBox(height: 16),

                              Row(
                                children: [
                                  OutlinedButton(
                                    onPressed: () =>
                                        MaterialPassportDialog.show(context, b),
                                    child: const Text('View Passport'),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => _receive(b),
                                      icon: const Icon(Icons.check_circle,
                                          size: 16),
                                      label:
                                          const Text('Confirm Gate Receipt'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}
