import 'package:flutter/material.dart';
import '../models/batch.dart';
import '../theme/app_theme.dart';

class AIScannerDialog extends StatefulWidget {
  final Function(PolymerType polymer, double confidence) onDetected;

  const AIScannerDialog({super.key, required this.onDetected});

  @override
  State<AIScannerDialog> createState() => _AIScannerDialogState();
}

class _AIScannerDialogState extends State<AIScannerDialog>
    with SingleTickerProviderStateMixin {
  int _selectedTargetIdx = 0;
  bool _isScanning = true;
  late AnimationController _animController;

  final List<_ScanTarget> _targets = [
    _ScanTarget(
      title: 'Clear Mineral Water Bottle Bale',
      polymer: PolymerType.pet,
      ricNumber: 1,
      confidence: 96.4,
      image:
          'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=600&q=80',
      description:
          'Polyethylene Terephthalate — clear bottle body with standard injection gate at bottom center.',
      features: [
        'High optical clarity',
        'Base injection gate mark',
        'Rigid thin-wall structure'
      ],
    ),
    _ScanTarget(
      title: 'Opaque Detergent & Milk Bottles',
      polymer: PolymerType.hdpe,
      ricNumber: 2,
      confidence: 94.1,
      image:
          'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?auto=format&fit=crop&w=600&q=80',
      description:
          'High-Density Polyethylene — opaque rigid blow-molded bottles with bottom pinch-off seam.',
      features: [
        'Matte surface finish',
        'Continuous base seam',
        'Chemical resistant'
      ],
    ),
    _ScanTarget(
      title: 'Food Takeaway Tubs & Closures',
      polymer: PolymerType.pp,
      ricNumber: 5,
      confidence: 91.8,
      image:
          'https://images.unsplash.com/photo-1618477461853-cf6ed80faba5?auto=format&fit=crop&w=600&q=80',
      description:
          'Polypropylene — translucent heat-tolerant containers with living hinge capability.',
      features: [
        'Semi-gloss finish',
        'High stiffness-to-weight',
        'Float characteristic in water'
      ],
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _triggerScan();
  }

  void _triggerScan() {
    setState(() => _isScanning = true);
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = _targets[_selectedTargetIdx];

    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                color: AppTheme.slate50,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.psychology,
                          color: AppTheme.primary, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Text(
                                'Optical AI Classifier',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.slate900,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryLight,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: AppTheme.primary.withValues(alpha: 0.3)),
                                ),
                                child: const Text(
                                  'YOLOv8',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryDark,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Text(
                            'Resin Identification Code (RIC) CV Engine',
                            style: TextStyle(fontSize: 11, color: AppTheme.slate500),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.of(context).pop(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Viewfinder simulation
              Stack(
                children: [
                  AspectRatio(
                    aspectRatio: 16 / 10,
                    child: Image.network(
                      active.image,
                      fit: BoxFit.cover,
                    ),
                  ),
                  // Dark vignette
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.5),
                            Colors.transparent,
                            Colors.black.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),

                  // Bounding Box
                  Positioned(
                    top: 24,
                    left: 24,
                    right: 24,
                    bottom: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: AppTheme.primary,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  // Laser sweep scan animation
                  if (_isScanning)
                    AnimatedBuilder(
                      animation: _animController,
                      builder: (context, child) {
                        return Positioned(
                          top: 24 + (_animController.value * 140),
                          left: 24,
                          right: 24,
                          child: Container(
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppTheme.primary,
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primary.withValues(alpha: 0.8),
                                  blurRadius: 8,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  // Scanning overlay HUD
                  Positioned(
                    top: 12,
                    left: 16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'LIVE CAM_STREAM (1080p)',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Target Selector Bar
                  Positioned(
                    bottom: 8,
                    left: 8,
                    right: 8,
                    child: Row(
                      children: List.generate(_targets.length, (i) {
                        final isSel = i == _selectedTargetIdx;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () {
                              setState(() => _selectedTargetIdx = i);
                              _triggerScan();
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              decoration: BoxDecoration(
                                color: isSel
                                    ? AppTheme.primary
                                    : Colors.black.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: isSel
                                      ? Colors.white
                                      : Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Text(
                                '${_targets[i].polymer.label} (#${_targets[i].ricNumber})',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),

              // Details & Detection Results
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Result Header
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppTheme.primary),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '♳ ${active.ricNumber}',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${active.polymer.label} (RIC #${active.ricNumber})',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.slate900,
                                ),
                              ),
                              Text(
                                active.title,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.slate500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryLight,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppTheme.primary),
                          ),
                          child: Text(
                            '${active.confidence}% confidence',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      active.description,
                      style: const TextStyle(fontSize: 12, color: AppTheme.slate700),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: active.features.map((f) {
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.slate100,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppTheme.slate200),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check,
                                  size: 12, color: AppTheme.primary),
                              const SizedBox(width: 4),
                              Text(
                                f,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.slate700,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 18),

                    // Actions
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: _triggerScan,
                          icon: const Icon(Icons.refresh, size: 16),
                          label: const Text('Re-scan'),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              widget.onDetected(active.polymer, active.confidence);
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.check_circle_outline, size: 16),
                            label: Text('Apply ${active.polymer.label}'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanTarget {
  final String title;
  final PolymerType polymer;
  final int ricNumber;
  final double confidence;
  final String image;
  final String description;
  final List<String> features;

  const _ScanTarget({
    required this.title,
    required this.polymer,
    required this.ricNumber,
    required this.confidence,
    required this.image,
    required this.description,
    required this.features,
  });
}
