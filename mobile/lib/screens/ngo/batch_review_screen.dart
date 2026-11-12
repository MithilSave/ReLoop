import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/six_stage_bar.dart';
import '../../widgets/material_passport_dialog.dart';

class BatchReviewScreen extends StatefulWidget {
  final WasteBatch batch;

  const BatchReviewScreen({super.key, required this.batch});

  @override
  State<BatchReviewScreen> createState() => _BatchReviewScreenState();
}

class _BatchReviewScreenState extends State<BatchReviewScreen> {
  String _selectedDecision = 'VERIFIED';
  late TextEditingController _commentCtrl;
  bool _chkOtp = true;
  bool _chkScale = true;
  bool _chkWeighbridge = true;
  bool _chkMassBalance = true;

  @override
  void initState() {
    super.initState();
    final prev = widget.batch.verification;
    _selectedDecision = prev != null && prev.decision != 'PENDING'
        ? prev.decision
        : 'VERIFIED';
    _commentCtrl = TextEditingController(
      text: prev?.comments ??
          'All six handover stages, weighbridge slips, and mass balance checked and verified within 1.2% variance.',
    );
  }

  @override
  void dispose() {
    _commentCtrl.dispose();
    super.dispose();
  }

  void _submitDecision() {
    final state = Provider.of<AppState>(context, listen: false);
    state.submitNGOVerification(
      batchId: widget.batch.id,
      decision: _selectedDecision,
      comments: _commentCtrl.text,
      evidenceDocs: [
        'Doorstep OTP Handover Log',
        'Weighbridge Calibrated Slip',
        'Extrusion Mass Balance Energy Ledger',
      ],
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Batch ${widget.batch.batchCode} audit decision recorded: $_selectedDecision!'),
        backgroundColor: _selectedDecision == 'VERIFIED'
            ? AppTheme.primary
            : const Color(0xFFD97706),
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;

    return Scaffold(
      appBar: AppBar(
        title: Text('Audit Review: ${b.batchCode}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_2),
            onPressed: () => MaterialPassportDialog.show(context, b),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Batch Details
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
                      Text(
                        b.batchCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryLight,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${b.material.label} (RIC #${b.material.ricNumber})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.primaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('Generator: ${b.generatorName} (${b.locality})',
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.bold)),
                  Text('Collector: ${b.collectorName ?? 'Mumbai Eco Logistics'}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.slate600)),
                  Text(
                      'Processor: ${b.recyclerName ?? 'Apex Plastic Recovery PWP'}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.slate600)),
                  const SizedBox(height: 14),
                  const Text('Six-Stage Custody Trail (kg):',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SixStageBar(quantities: b.quantities, compact: false),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Independent Audit Checklist
            const Text(
              'Independent NGO Verification Checklist',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate900,
              ),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Column(
                children: [
                  CheckboxListTile(
                    value: _chkOtp,
                    title: const Text('Doorstep Handover OTP & Scale Verification',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        'Generator OTP confirmed digital scale reading at source.',
                        style: TextStyle(fontSize: 10, color: AppTheme.slate500)),
                    onChanged: (val) => setState(() => _chkOtp = val ?? false),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    value: _chkScale,
                    title: const Text('Logistics Consignment Vehicle Route Matched',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        'EV LCV registration verified against trip manifest.',
                        style: TextStyle(fontSize: 10, color: AppTheme.slate500)),
                    onChanged: (val) => setState(() => _chkScale = val ?? false),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    value: _chkWeighbridge,
                    title: const Text('Plant Gate Calibrated Weighbridge Slip',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        'Gross received weight matches accepted + rejected fraction.',
                        style: TextStyle(fontSize: 10, color: AppTheme.slate500)),
                    onChanged: (val) =>
                        setState(() => _chkWeighbridge = val ?? false),
                  ),
                  const Divider(height: 1),
                  CheckboxListTile(
                    value: _chkMassBalance,
                    title: const Text('Mechanical Extrusion Mass Balance Checked',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    subtitle: const Text(
                        'Input vs Output + Residue verified within 2% process loss.',
                        style: TextStyle(fontSize: 10, color: AppTheme.slate500)),
                    onChanged: (val) =>
                        setState(() => _chkMassBalance = val ?? false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Decision Selection
            const Text(
              'Audit Finding & Decision',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate900,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                _buildDecisionButton('VERIFIED', 'Verified', Icons.verified,
                    const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _buildDecisionButton(
                    'REQUIRES_CORRECTION',
                    'Correction',
                    Icons.edit_note,
                    const Color(0xFFF59E0B)),
                const SizedBox(width: 6),
                _buildDecisionButton('FLAGGED', 'Flag',
                    Icons.flag, const Color(0xFFEF4444)),
              ],
            ),
            const SizedBox(height: 14),

            // Audit Comments
            const Text('Auditor Commentary & Trace Notes',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            TextField(
              controller: _commentCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Enter formal audit commentary...',
              ),
            ),
            const SizedBox(height: 24),

            ElevatedButton.icon(
              onPressed: _submitDecision,
              icon: const Icon(Icons.shield_outlined, size: 18),
              label: Text('Record Audit Decision ($_selectedDecision)'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                backgroundColor: _selectedDecision == 'VERIFIED'
                    ? AppTheme.primary
                    : const Color(0xFFD97706),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDecisionButton(
      String value, String label, IconData icon, Color color) {
    final isSel = _selectedDecision == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedDecision = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? color.withValues(alpha: 0.1) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSel ? color : AppTheme.slate300,
              width: isSel ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 18, color: isSel ? color : AppTheme.slate500),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSel ? color : AppTheme.slate700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
