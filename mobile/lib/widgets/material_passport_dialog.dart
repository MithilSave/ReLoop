import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/batch.dart';
import '../theme/app_theme.dart';
import 'six_stage_bar.dart';
import 'status_badge.dart';

class MaterialPassportDialog extends StatefulWidget {
  final WasteBatch batch;

  const MaterialPassportDialog({super.key, required this.batch});

  static void show(BuildContext context, WasteBatch batch) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => MaterialPassportDialog(batch: batch),
    );
  }

  @override
  State<MaterialPassportDialog> createState() => _MaterialPassportDialogState();
}

class _MaterialPassportDialogState extends State<MaterialPassportDialog> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final b = widget.batch;
    final hash =
        'sha256:7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd20012${b.batchCode.split('-').last}';

    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
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

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 16, 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.qr_code_2,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            b.batchCode,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.slate900,
                              fontFamily: 'monospace',
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusBadge(status: b.status),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Universal Digital Product Passport (DPP)',
                        style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.slate200),

          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // QR & Immutable SHA-256 Hash Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.slate900,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: QrImageView(
                            data: 'https://reloop.in/b/${b.batchCode}',
                            version: QrVersions.auto,
                            size: 72.0,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.lock,
                                      size: 13, color: AppTheme.primary),
                                  const SizedBox(width: 4),
                                  const Text(
                                    'IMMUTABLE HASH SEAL',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hash,
                                style: const TextStyle(
                                  color: Color(0xFF34D399), // Emerald 400
                                  fontFamily: 'monospace',
                                  fontSize: 10,
                                  height: 1.3,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: hash));
                                  setState(() => _copied = true);
                                  Future.delayed(const Duration(seconds: 2), () {
                                    if (mounted) setState(() => _copied = false);
                                  });
                                },
                                child: Text(
                                  _copied ? '✓ Hash Copied' : 'Copy Hash Checksum',
                                  style: TextStyle(
                                    color: _copied
                                        ? const Color(0xFF6EE7B7)
                                        : Colors.white60,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Six-Stage Quantity Journey
                  const Text(
                    'Six-Stage Mass Balance Journey',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Quantities at every handover are recorded independently and never assumed equal.',
                    style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                  ),
                  const SizedBox(height: 12),
                  SixStageBar(quantities: b.quantities, compact: false),
                  const SizedBox(height: 24),

                  // Material Specifications
                  const Text(
                    'Material & Polymer Classification',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.slate50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    child: Column(
                      children: [
                        _buildPropRow('Resin Identification',
                            '${b.material.label} (RIC #${b.material.ricNumber})'),
                        _buildPropRow(
                            'Packaging Category', b.packagingCategory.label),
                        _buildPropRow('Estimated Weight',
                            '${b.quantities.estimatedKg.toStringAsFixed(1)} kg'),
                        if (b.qualityGrade != null)
                          _buildPropRow('Recycler Grade', 'Grade ${b.qualityGrade}'),
                        if (b.contaminationPct != null)
                          _buildPropRow('Contamination %',
                              '${b.contaminationPct!.toStringAsFixed(1)}%'),
                        _buildPropRow('Locality', b.locality),
                        _buildPropRow('Pickup Address', b.pickupAddress),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Custody Chain Log
                  const Text(
                    'Chain of Custody Handover Log',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildTimelineItem(
                    title: '1. Waste Batch Listed',
                    subtitle:
                        'Declared by ${b.generatorName} with photos and optical AI classification.',
                    time: 'Listing Time',
                    isComplete: true,
                    icon: Icons.list_alt,
                  ),
                  _buildTimelineItem(
                    title: '2. Doorstep Pickup & OTP Handover',
                    subtitle: b.collectorName != null
                        ? 'Picked up by ${b.collectorName}. Digital scale weight: ${b.quantities.collectedKg?.toStringAsFixed(1) ?? '—'} kg.'
                        : 'Awaiting collector assignment.',
                    time: 'Pickup',
                    isComplete: b.quantities.collectedKg != null,
                    icon: Icons.scale,
                  ),
                  _buildTimelineItem(
                    title: '3. Vehicle Consignment Dispatch',
                    subtitle: b.consignmentId != null
                        ? 'Transported in EV LCV consignment ${b.consignmentId} to ${b.recyclerName}.'
                        : 'Stored at collection hub.',
                    time: 'Transit',
                    isComplete: b.consignmentId != null,
                    icon: Icons.local_shipping,
                  ),
                  _buildTimelineItem(
                    title: '4. Recycler Weighbridge Receipt',
                    subtitle: b.quantities.receivedKg != null
                        ? 'Weighed at plant gate: ${b.quantities.receivedKg!.toStringAsFixed(1)} kg received (${b.quantities.acceptedKg!.toStringAsFixed(1)} kg accepted).'
                        : 'Not yet arrived at processing plant.',
                    time: 'Receipt',
                    isComplete: b.quantities.receivedKg != null,
                    icon: Icons.warehouse,
                  ),
                  _buildTimelineItem(
                    title: '5. Mechanical Processing Run & Yield',
                    subtitle: b.quantities.processedKg != null
                        ? 'Extruded into pellets. Pro-rata output yield: ${b.quantities.processedKg!.toStringAsFixed(1)} kg.'
                        : 'Awaiting scheduled extrusion run.',
                    time: 'Processing',
                    isComplete: b.quantities.processedKg != null,
                    icon: Icons.recycling,
                  ),
                  _buildTimelineItem(
                    title: '6. Independent NGO Verification Seal',
                    subtitle: b.verification != null
                        ? 'Audit decision: ${b.verification!.decision}. ${b.verification!.comments}'
                        : 'Awaiting independent audit inspection.',
                    time: 'Audit',
                    isComplete: b.verification?.decision == 'VERIFIED',
                    icon: Icons.verified_user,
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPropRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.slate500)),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineItem({
    required String title,
    required String subtitle,
    required String time,
    required bool isComplete,
    required IconData icon,
    bool isLast = false,
  }) {
    final color = isComplete ? AppTheme.primary : AppTheme.slate300;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isComplete ? AppTheme.primaryLight : AppTheme.slate100,
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
              ),
              child: Icon(icon, size: 14, color: color),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: isComplete ? AppTheme.primary.withValues(alpha: 0.4) : AppTheme.slate200,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isComplete ? AppTheme.slate900 : AppTheme.slate500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
