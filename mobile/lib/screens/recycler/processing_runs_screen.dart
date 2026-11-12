import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class ProcessingRunsScreen extends StatefulWidget {
  const ProcessingRunsScreen({super.key});

  @override
  State<ProcessingRunsScreen> createState() => _ProcessingRunsScreenState();
}

class _ProcessingRunsScreenState extends State<ProcessingRunsScreen> {
  final Set<String> _selectedBatchIds = {};
  PolymerType _selectedPolymer = PolymerType.pet;
  PackagingCategory _selectedCategory = PackagingCategory.catI;
  final TextEditingController _outputCtrl = TextEditingController(text: '82.0');
  final TextEditingController _residueCtrl = TextEditingController(text: '8.0');
  final TextEditingController _certRefCtrl =
      TextEditingController(text: 'CPCB/PWM/2026/MH/7802');
  String _outputForm = 'Pellets';

  @override
  void dispose() {
    _outputCtrl.dispose();
    _residueCtrl.dispose();
    _certRefCtrl.dispose();
    super.dispose();
  }

  void _showNewRunModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final state = Provider.of<AppState>(context);
          final receivedBatches = state.batches
              .where((b) =>
                  b.status.label == 'RECEIVED' &&
                  (b.quantities.acceptedKg ?? 0) > 0)
              .toList();

          double totalInputKg = 0;
          for (final b in receivedBatches) {
            if (_selectedBatchIds.contains(b.id)) {
              totalInputKg += b.quantities.acceptedKg ?? 0;
            }
          }

          final outKg = double.tryParse(_outputCtrl.text) ?? 0;
          final resKg = double.tryParse(_residueCtrl.text) ?? 0;
          final yieldPct =
              totalInputKg > 0 ? (outKg / totalInputKg) * 100 : 0.0;
          final isMassBalanceValid = outKg + resKg <= totalInputKg + 0.1;

          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.slate300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'New Mechanical Extrusion Run',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 20),
                        onPressed: () => Navigator.of(ctx).pop(),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: AppTheme.slate200),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Select Received Feedstock Batches to Combine',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        if (receivedBatches.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppTheme.slate50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.slate200),
                            ),
                            child: const Center(
                              child: Text(
                                'No received batches available. Process inbound batches at weighbridge first.',
                                style: TextStyle(
                                    fontSize: 11, color: AppTheme.slate500),
                              ),
                            ),
                          )
                        else
                          ...receivedBatches.map((b) {
                            final isSel = _selectedBatchIds.contains(b.id);
                            return CheckboxListTile(
                              value: isSel,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              tileColor: isSel
                                  ? AppTheme.primaryLight
                                  : AppTheme.slate50,
                              title: Text(
                                '${b.batchCode} • ${b.material.label} (${(b.quantities.acceptedKg ?? 0).toStringAsFixed(1)} kg accepted)',
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              subtitle: Text(
                                'Origin: ${b.generatorName}',
                                style: const TextStyle(
                                    fontSize: 10, color: AppTheme.slate600),
                              ),
                              onChanged: (val) {
                                setModalState(() {
                                  if (val == true) {
                                    _selectedBatchIds.add(b.id);
                                    _selectedPolymer = b.material;
                                    _selectedCategory = b.packagingCategory;
                                    // Default output to 90%
                                    final curIn = totalInputKg +
                                        (b.quantities.acceptedKg ?? 0);
                                    _outputCtrl.text =
                                        (curIn * 0.90).toStringAsFixed(1);
                                    _residueCtrl.text =
                                        (curIn * 0.10).toStringAsFixed(1);
                                  } else {
                                    _selectedBatchIds.remove(b.id);
                                  }
                                });
                              },
                            );
                          }),
                        const SizedBox(height: 16),

                        // Input kg display
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppTheme.slate900,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL MEASURED INPUT',
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold)),
                              Text(
                                '${totalInputKg.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  color: Color(0xFF34D399),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Measured Output & Residue
                        const Text(
                          '2. Mechanical Processing Yield (Output + Residue <= Input)',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Usable Output (kg)',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _outputCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                      suffixText: 'kg',
                                    ),
                                    onChanged: (val) => setModalState(() {}),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Residue / Loss (kg)',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _residueCtrl,
                                    keyboardType:
                                        const TextInputType.numberWithOptions(
                                            decimal: true),
                                    decoration: const InputDecoration(
                                      suffixText: 'kg',
                                    ),
                                    onChanged: (val) => setModalState(() {}),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Form & Cert Ref
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Output Form',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  DropdownButtonFormField<String>(
                                    value: _outputForm,
                                    items: ['Pellets', 'Flakes', 'Granules']
                                        .map((f) => DropdownMenuItem(
                                              value: f,
                                              child: Text(f),
                                            ))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setModalState(() => _outputForm = val);
                                      }
                                    },
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('CPCB Certificate Ref',
                                      style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _certRefCtrl,
                                    decoration: const InputDecoration(
                                      hintText: 'e.g. CPCB/PWM/2026/MH/7802',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Yield % Box
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMassBalanceValid
                                ? AppTheme.primaryLight
                                : const Color(0xFFFFF1F2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isMassBalanceValid
                                  ? AppTheme.primary
                                  : const Color(0xFFFECDD3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                isMassBalanceValid
                                    ? 'Measured Yield: ${yieldPct.toStringAsFixed(1)}%'
                                    : 'Mass Balance Invalid: Output + Residue exceeds Input',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: isMassBalanceValid
                                      ? AppTheme.primaryDark
                                      : const Color(0xFFBE123C),
                                ),
                              ),
                              Icon(
                                isMassBalanceValid
                                    ? Icons.check_circle
                                    : Icons.error_outline,
                                size: 16,
                                color: isMassBalanceValid
                                    ? AppTheme.primary
                                    : const Color(0xFFBE123C),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        ElevatedButton(
                          onPressed: () {
                            if (_selectedBatchIds.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text('Please select at least 1 batch.')),
                              );
                              return;
                            }
                            if (!isMassBalanceValid) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                    content: Text(
                                        'Please correct output and residue to balance with input.')),
                              );
                              return;
                            }

                            final run = state.createProcessingRun(
                              materialCode: _selectedPolymer,
                              packagingCategory: _selectedCategory,
                              batchIds: _selectedBatchIds.toList(),
                              outputKg: outKg,
                              residueKg: resKg,
                              outputForm: _outputForm,
                              certificateRef: _certRefCtrl.text,
                            );

                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                    'Processing Run ${run.runCode} completed! Yield: ${run.yieldPct.toStringAsFixed(1)}%'),
                                backgroundColor: AppTheme.primary,
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Center(
                              child: Text('Complete Processing Run')),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final runs = state.processingRuns;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Processing Runs & Yield Mass Balance'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _showNewRunModal(context),
          ),
        ],
      ),
      body: runs.isEmpty
          ? const Center(
              child: Text('No processing runs recorded yet.',
                  style: TextStyle(color: AppTheme.slate500)),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: runs.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 14),
              itemBuilder: (ctx, i) {
                final r = runs[i];
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
                                r.runCode,
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
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${r.materialCode.label} • ${r.outputForm}',
                                  style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF86EFAC)),
                            ),
                            child: Text(
                              'Yield ${r.yieldPct.toStringAsFixed(1)}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Mass balance breakdown line
                      Row(
                        children: [
                          _buildRunStat(
                              'Input (Feedstock)', '${r.inputKg.toStringAsFixed(1)} kg'),
                          const Icon(Icons.arrow_forward,
                              size: 14, color: AppTheme.slate300),
                          _buildRunStat('Usable Output',
                              '${r.outputKg.toStringAsFixed(1)} kg',
                              highlight: true),
                          const Icon(Icons.add,
                              size: 14, color: AppTheme.slate300),
                          _buildRunStat(
                              'Residue Loss', '${r.residueKg.toStringAsFixed(1)} kg'),
                        ],
                      ),
                      const SizedBox(height: 12),
                      const Divider(height: 1, color: AppTheme.slate100),
                      const SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Eligible: ${r.eligibleKg.toStringAsFixed(1)} kg | Claimed: ${r.allocatedKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                                fontSize: 11, color: AppTheme.slate600),
                          ),
                          Text(
                            r.certificateRefs.isNotEmpty
                                ? r.certificateRefs.first
                                : 'CPCB Ref Logged',
                            style: const TextStyle(
                              fontSize: 10,
                              fontFamily: 'monospace',
                              color: AppTheme.slate400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewRunModal(context),
        icon: const Icon(Icons.add),
        label: const Text('New Run'),
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildRunStat(String label, String value, {bool highlight = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.slate500)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: highlight ? AppTheme.primaryDark : AppTheme.slate900,
            ),
          ),
        ],
      ),
    );
  }
}
