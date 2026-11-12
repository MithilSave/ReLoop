import 'package:flutter/material.dart';
import '../../models/batch.dart';
import '../../theme/app_theme.dart';
import 'sourcing_planner_screen.dart';

class SupplyOutlookScreen extends StatefulWidget {
  const SupplyOutlookScreen({super.key});

  @override
  State<SupplyOutlookScreen> createState() => _SupplyOutlookScreenState();
}

class _SupplyOutlookScreenState extends State<SupplyOutlookScreen> {
  PolymerType _selectedPolymer = PolymerType.pp;

  final Map<PolymerType, List<_WeeklyForecast>> _forecastData = {
    PolymerType.pp: [
      _WeeklyForecast(
        weekLabel: 'W45 (Past)',
        confirmedKg: 4200,
        predictedKg: 850,
        targetKg: 5000,
      ),
      _WeeklyForecast(
        weekLabel: 'W46 (Current)',
        confirmedKg: 3800,
        predictedKg: 1100,
        targetKg: 5000,
      ),
      _WeeklyForecast(
        weekLabel: 'W47 (Next)',
        confirmedKg: 2900,
        predictedKg: 1600,
        targetKg: 5000,
      ),
      _WeeklyForecast(
        weekLabel: 'W48 (2 Wks)',
        confirmedKg: 1850,
        predictedKg: 2500,
        targetKg: 5000,
      ),
    ],
    PolymerType.pet: [
      _WeeklyForecast(
        weekLabel: 'W45 (Past)',
        confirmedKg: 6100,
        predictedKg: 900,
        targetKg: 7000,
      ),
      _WeeklyForecast(
        weekLabel: 'W46 (Current)',
        confirmedKg: 5800,
        predictedKg: 1300,
        targetKg: 7000,
      ),
      _WeeklyForecast(
        weekLabel: 'W47 (Next)',
        confirmedKg: 4200,
        predictedKg: 2400,
        targetKg: 7000,
      ),
      _WeeklyForecast(
        weekLabel: 'W48 (2 Wks)',
        confirmedKg: 3100,
        predictedKg: 3400,
        targetKg: 7000,
      ),
    ],
    PolymerType.hdpe: [
      _WeeklyForecast(
        weekLabel: 'W45 (Past)',
        confirmedKg: 3200,
        predictedKg: 600,
        targetKg: 4000,
      ),
      _WeeklyForecast(
        weekLabel: 'W46 (Current)',
        confirmedKg: 3000,
        predictedKg: 900,
        targetKg: 4000,
      ),
      _WeeklyForecast(
        weekLabel: 'W47 (Next)',
        confirmedKg: 2100,
        predictedKg: 1700,
        targetKg: 4000,
      ),
      _WeeklyForecast(
        weekLabel: 'W48 (2 Wks)',
        confirmedKg: 1400,
        predictedKg: 2200,
        targetKg: 4000,
      ),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final weeks = _forecastData[_selectedPolymer] ??
        _forecastData[PolymerType.pp]!;

    final futureWeek = weeks[3];
    final projectedDeficit = (futureWeek.targetKg -
            (futureWeek.confirmedKg + futureWeek.predictedKg))
        .clamp(0, 10000);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Supply Outlook & Forecasts'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Material Filter
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildPolymerChip(PolymerType.pp),
                  _buildPolymerChip(PolymerType.pet),
                  _buildPolymerChip(PolymerType.hdpe),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Gap Callout
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB), // Amber 50
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFDE68A)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFD97706),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.warning_amber_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Feedstock Gap Alert • Week 48',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF92400E),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Confirmed contracts cover only ${futureWeek.confirmedKg.toStringAsFixed(0)} kg of ${futureWeek.targetKg.toStringAsFixed(0)} kg capacity. Even with predicted informal supply, a shortfall of ~${projectedDeficit.toStringAsFixed(0)} kg is forecasted.',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFFB45309)),
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (ctx) =>
                                      const SourcingPlannerScreen()),
                            );
                          },
                          icon: const Icon(Icons.add_shopping_cart, size: 14),
                          label: const Text('Launch Sourcing Plan',
                              style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFD97706),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Principle Callout
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: const Row(
                children: [
                  Icon(Icons.shield_outlined,
                      size: 16, color: AppTheme.slate500),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Compliance Rule: Predicted forecasts are never summed into confirmed inventory and cannot be pledged for EPR allocations until weighbridge receipt.',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.slate600,
                          fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Confirmed Supply', AppTheme.primary, false),
                const SizedBox(width: 16),
                _buildLegendItem('Predicted (Informal)', AppTheme.amber500, true),
                const SizedBox(width: 16),
                _buildLegendItem('Weekly Target', AppTheme.slate400, false),
              ],
            ),
            const SizedBox(height: 16),

            // Weekly Bars Chart
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Weekly Inflow vs Processing Target (kg)',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate900,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...weeks.map((w) => _buildWeekBarRow(w)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Recommended Local Suppliers
            const Text(
              'Recommended High-Reliability Hubs',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate900,
              ),
            ),
            const SizedBox(height: 8),

            _buildSupplierCard(
              name: 'Dharavi Green Collect',
              rating: '98.5% scale fidelity',
              avgLeadTime: '4.2 hrs',
              locality: 'Dharavi, Mumbai',
              capacityKg: '5,000 kg/day',
              status: 'AVAILABLE NOW',
            ),
            const SizedBox(height: 8),
            _buildSupplierCard(
              name: 'Andheri West Civic Recovery Centre',
              rating: '94.2% scale fidelity',
              avgLeadTime: '6.0 hrs',
              locality: 'Andheri West, Mumbai',
              capacityKg: '2,500 kg/day',
              status: 'READY IN 24H',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPolymerChip(PolymerType p) {
    final isSelected = p == _selectedPolymer;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(p.code),
        selected: isSelected,
        onSelected: (val) {
          if (val) setState(() => _selectedPolymer = p);
        },
        selectedColor: AppTheme.primaryLight,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryDark : AppTheme.slate700,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color, bool isPredicted) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: isPredicted ? color.withValues(alpha: 0.3) : color,
            borderRadius: BorderRadius.circular(3),
            border: isPredicted ? Border.all(color: color, width: 1.5) : null,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 10, color: AppTheme.slate600),
        ),
      ],
    );
  }

  Widget _buildWeekBarRow(_WeeklyForecast w) {
    const maxVal = 7500.0;
    final confirmedRatio = (w.confirmedKg / maxVal).clamp(0.0, 1.0);
    final predictedRatio = (w.predictedKg / maxVal).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                w.weekLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate800,
                ),
              ),
              Row(
                children: [
                  Text(
                    '${w.confirmedKg.toStringAsFixed(0)} kg confirmed',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const Text(' • ', style: TextStyle(color: AppTheme.slate300)),
                  Text(
                    '+${w.predictedKg.toStringAsFixed(0)} kg predicted',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFFD97706),
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 18,
              color: AppTheme.slate100,
              child: Row(
                children: [
                  // Confirmed bar (solid emerald)
                  Flexible(
                    flex: (confirmedRatio * 1000).toInt(),
                    child: Container(color: AppTheme.primary),
                  ),
                  // Predicted bar (hatched/semi-transparent amber)
                  Flexible(
                    flex: (predictedRatio * 1000).toInt(),
                    child: Container(
                      color: AppTheme.amber400.withValues(alpha: 0.65),
                      child: const Center(
                        child: Text(
                          'PREDICTED',
                          style: TextStyle(
                            fontSize: 7,
                            color: Color(0xFF78350F),
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Remaining gap
                  Flexible(
                    flex: ((1.0 - confirmedRatio - predictedRatio) * 1000)
                        .clamp(0, 1000)
                        .toInt(),
                    child: const SizedBox.shrink(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSupplierCard({
    required String name,
    required String rating,
    required String avgLeadTime,
    required String locality,
    required String capacityKg,
    required String status,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate900,
                  ),
                ),
                Text(
                  '$locality • $capacityKg',
                  style: const TextStyle(fontSize: 10, color: AppTheme.slate500),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star, size: 12, color: AppTheme.amber500),
                    const SizedBox(width: 4),
                    Text(
                      rating,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Avg ETA: $avgLeadTime',
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.slate500),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              status,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyForecast {
  final String weekLabel;
  final double confirmedKg;
  final double predictedKg;
  final double targetKg;

  const _WeeklyForecast({
    required this.weekLabel,
    required this.confirmedKg,
    required this.predictedKg,
    required this.targetKg,
  });
}
