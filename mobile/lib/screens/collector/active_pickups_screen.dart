import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class ActivePickupsScreen extends StatefulWidget {
  final String? initialBatchId;

  const ActivePickupsScreen({super.key, this.initialBatchId});

  @override
  State<ActivePickupsScreen> createState() => _ActivePickupsScreenState();
}

class _ActivePickupsScreenState extends State<ActivePickupsScreen> {
  String? _selectedBatchId;
  final TextEditingController _weightCtrl = TextEditingController(text: '108.5');
  final TextEditingController _otpCtrl = TextEditingController();
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedBatchId = widget.initialBatchId;
  }

  @override
  void dispose() {
    _weightCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _completeVerification(WasteBatch batch) {
    final weight = double.tryParse(_weightCtrl.text);
    if (weight == null || weight <= 0) {
      setState(() => _errorMessage = 'Please enter a valid scale weight.');
      return;
    }

    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      setState(() => _errorMessage = 'Please ask the generator for the OTP.');
      return;
    }

    final state = Provider.of<AppState>(context, listen: false);
    final res = state.completePickup(batch.id, weight, otp);

    if (res['success'] == true) {
      setState(() {
        _errorMessage = null;
        _selectedBatchId = null;
        _otpCtrl.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Batch ${batch.batchCode} verified (${weight.toStringAsFixed(1)} kg) & marked PICKED UP!'),
          backgroundColor: AppTheme.primary,
        ),
      );
    } else {
      setState(() => _errorMessage = res['error']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final assignedBatches = state.batches
        .where((b) =>
            b.collectorOrgId == state.currentPersona.orgId &&
            b.status.label == 'ASSIGNED')
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Doorstep Weighing & OTP Verification'),
      ),
      body: assignedBatches.isEmpty
          ? const Center(
              child: Text(
                'No assigned batches awaiting pickup.',
                style: TextStyle(color: AppTheme.slate500),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: assignedBatches.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 16),
              itemBuilder: (ctx, i) {
                final b = assignedBatches[i];
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
                                color: AppTheme.primaryLight,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${b.material.label} • Est: ${b.quantities.estimatedKg.toStringAsFixed(0)} kg',
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            ),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(b.generatorName,
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.slate800)),
                            Text(b.pickupAddress,
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
                                _weightCtrl.text =
                                    (b.quantities.estimatedKg - 1.5).toStringAsFixed(1);
                                _otpCtrl.text = b.pickupOtp ?? '';
                                _errorMessage = null;
                              }
                            });
                          },
                          child: Text(isExpanded ? 'Close' : 'Start Weighing'),
                        ),
                      ),

                      // Verification Form Drawer
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

                              if (_errorMessage != null)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF1F2),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: const Color(0xFFFECDD3)),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.error_outline,
                                          size: 16, color: Color(0xFFBE123C)),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorMessage!,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFBE123C),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              const Text(
                                'Step 1: Enter Actual Weight from Digital Scale (kg)',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _weightCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                                decoration: const InputDecoration(
                                  suffixText: 'kg',
                                  prefixIcon: Icon(Icons.scale, size: 18),
                                ),
                              ),
                              const SizedBox(height: 14),

                              const Text(
                                'Step 2: Enter 6-Digit Generator Handover OTP',
                                style: TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Generator sees this on their app upon weighing agreement',
                                style: TextStyle(
                                    fontSize: 10, color: AppTheme.slate500),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _otpCtrl,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 4,
                                ),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.key, size: 18),
                                  hintText: '••••••',
                                  counterText: '',
                                ),
                              ),
                              const SizedBox(height: 16),

                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _completeVerification(b),
                                  icon: const Icon(Icons.verified, size: 18),
                                  label: const Text(
                                      'Verify OTP & Confirm Pickup'),
                                ),
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
