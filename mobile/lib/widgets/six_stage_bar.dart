import 'package:flutter/material.dart';
import '../models/batch.dart';
import '../theme/app_theme.dart';

class SixStageBar extends StatelessWidget {
  final BatchQuantities quantities;
  final bool compact;
  final bool showLabels;

  const SixStageBar({
    super.key,
    required this.quantities,
    this.compact = false,
    this.showLabels = true,
  });

  @override
  Widget build(BuildContext context) {
    final estKg = quantities.estimatedKg > 0 ? quantities.estimatedKg : 100.0;

    final stages = [
      _StageConfig(
        title: 'Collected',
        shortTitle: 'Coll',
        value: quantities.collectedKg,
        color: const Color(0xFF2563EB), // Blue 600
        bg: const Color(0xFFEFF6FF),
      ),
      _StageConfig(
        title: 'Received',
        shortTitle: 'Recv',
        value: quantities.receivedKg,
        color: const Color(0xFF4F46E5), // Indigo 600
        bg: const Color(0xFFEEF2FF),
      ),
      _StageConfig(
        title: 'Accepted',
        shortTitle: 'Acpt',
        value: quantities.acceptedKg,
        color: const Color(0xFF0D9488), // Teal 600
        bg: const Color(0xFFF0FDFA),
      ),
      _StageConfig(
        title: 'Processed',
        shortTitle: 'Proc',
        value: quantities.processedKg,
        color: const Color(0xFF059669), // Emerald 600
        bg: const Color(0xFFECFDF5),
      ),
      _StageConfig(
        title: 'Verified',
        shortTitle: 'Verf',
        value: quantities.verifiedKg,
        color: const Color(0xFF047857), // Emerald 700
        bg: const Color(0xFFD1FAE5),
      ),
      _StageConfig(
        title: 'Allocated',
        shortTitle: 'Aloc',
        value: quantities.allocatedKg,
        color: const Color(0xFF7C3AED), // Purple 600
        bg: const Color(0xFFF5F3FF),
      ),
    ];

    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: stages.map((stg) {
              final isComplete = stg.value != null && stg.value! > 0;
              final valText = isComplete ? '${stg.value!.toStringAsFixed(0)}k' : '—';
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                  decoration: BoxDecoration(
                    color: isComplete ? stg.bg : AppTheme.slate100,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: isComplete ? stg.color.withValues(alpha: 0.3) : AppTheme.slate200,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        stg.shortTitle,
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isComplete ? stg.color : AppTheme.slate400,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        valText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isComplete ? AppTheme.slate900 : AppTheme.slate400,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: stages.map((stg) {
            final isComplete = stg.value != null && stg.value! > 0;
            final valText = isComplete ? '${stg.value!.toStringAsFixed(1)} kg' : '—';
            final pct = isComplete ? ((stg.value! / estKg) * 100).clamp(0, 100).toInt() : 0;

            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isComplete ? Colors.white : AppTheme.slate50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isComplete ? AppTheme.slate300 : AppTheme.slate200,
                    width: 1,
                  ),
                  boxShadow: isComplete
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.02),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            stg.shortTitle,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isComplete ? AppTheme.slate700 : AppTheme.slate400,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isComplete)
                          Icon(Icons.check_circle, size: 11, color: stg.color)
                        else
                          Icon(Icons.access_time, size: 11, color: AppTheme.slate300),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isComplete ? AppTheme.slate900 : AppTheme.slate400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        height: 3,
                        color: AppTheme.slate100,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: isComplete ? (pct / 100) : 0.0,
                            child: Container(color: stg.color),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        if (showLabels &&
            quantities.rejectedKg != null &&
            quantities.rejectedKg! > 0)
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB), // Amber 50
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Color(0xFFD97706)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Weighbridge rejection: ${quantities.rejectedKg!.toStringAsFixed(1)} kg separated at gate inspection.',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF92400E),
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _StageConfig {
  final String title;
  final String shortTitle;
  final double? value;
  final Color color;
  final Color bg;

  const _StageConfig({
    required this.title,
    required this.shortTitle,
    required this.value,
    required this.color,
    required this.bg,
  });
}
