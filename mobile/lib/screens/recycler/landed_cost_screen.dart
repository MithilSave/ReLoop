import 'package:flutter/material.dart';
import '../../services/demo_data.dart';
import '../../theme/app_theme.dart';

class LandedCostScreen extends StatefulWidget {
  const LandedCostScreen({super.key});

  @override
  State<LandedCostScreen> createState() => _LandedCostScreenState();
}

class _LandedCostScreenState extends State<LandedCostScreen> {
  int _selectedOptionIdx = 0;

  @override
  Widget build(BuildContext context) {
    final opt = costComparisonOptions[_selectedOptionIdx];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Landed Cost & Yield Optimizer'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sourcing Mode Selector
            const Text(
              'Select Procurement Option to Analyze',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(costComparisonOptions.length, (i) {
                final o = costComparisonOptions[i];
                final isSel = i == _selectedOptionIdx;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _selectedOptionIdx = i),
                    child: Container(
                      margin: EdgeInsets.only(
                          left: i == 0 ? 0 : 4,
                          right: i == costComparisonOptions.length - 1 ? 0 : 4),
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: isSel ? AppTheme.primaryLight : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSel ? AppTheme.primary : AppTheme.slate200,
                          width: isSel ? 1.5 : 1,
                        ),
                      ),
                      child: Column(
                        children: [
                          Text(
                            o.type,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isSel
                                  ? AppTheme.primaryDark
                                  : AppTheme.slate600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '₹${o.costPerUsableKg.toStringAsFixed(1)}',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                              color: isSel
                                  ? AppTheme.primaryDark
                                  : AppTheme.slate900,
                            ),
                          ),
                          const Text('/ usable kg',
                              style: TextStyle(
                                  fontSize: 8, color: AppTheme.slate400)),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 16),

            // Highlight Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.slate900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        opt.optionName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: opt.type == 'Smart Aggregation'
                              ? const Color(0xFF10B981)
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          opt.type == 'Smart Aggregation'
                              ? '🏆 26% Lowest Cost'
                              : opt.type,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Landed Outflow',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 10)),
                          Text(
                            '₹${opt.totalCost.toStringAsFixed(0)}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Net Usable Output',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 10)),
                          Text(
                            '${opt.usableKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                              color: Color(0xFF34D399),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('₹ / Usable kg',
                              style: TextStyle(
                                  color: Colors.white60, fontSize: 10)),
                          Text(
                            '₹${opt.costPerUsableKg.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: Color(0xFF6EE7B7),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Itemized Cost Lines
            const Text(
              'Detailed Cost Waterfall Breakdown',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Column(
                children: [
                  _buildCostRow('Purchase Cost (Generator payout)',
                      opt.purchaseCost, const Color(0xFF2563EB)),
                  _buildCostRow('Collection & Doorstep Fee', opt.collectionCost,
                      const Color(0xFF4F46E5)),
                  _buildCostRow('Transport (EV LCV transit)', opt.transportCost,
                      const Color(0xFF7C3AED)),
                  _buildCostRow('Sorting & Quality Grading', opt.sortingCost,
                      const Color(0xFF0D9488)),
                  _buildCostRow('Buffer Storage / Inbound Holding',
                      opt.storageCost, const Color(0xFF059669)),
                  _buildCostRow(
                      'Rejection & Residual Loss (Disposal)',
                      opt.rejectionCost,
                      const Color(0xFFF43F5E),
                      isReject: true),
                  const Divider(height: 1, color: AppTheme.slate200),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Total Delivered Landed Cost',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(
                          '₹${opt.totalCost.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppTheme.slate900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Formula Note
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: const Text(
                'Landed Cost Formula = (Purchase + Collection + Transport + Sorting + Storage + Rejection) ÷ Usable Output kg.\nSpot markets appear cheaper initially but suffer higher contamination loss and transport overhead.',
                style: TextStyle(
                  fontSize: 10,
                  color: AppTheme.slate600,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCostRow(String label, double cost, Color barColor,
      {bool isReject = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 24,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isReject ? FontWeight.bold : FontWeight.normal,
                color: isReject ? const Color(0xFFBE123C) : AppTheme.slate800,
              ),
            ),
          ),
          Text(
            '₹${cost.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              color: AppTheme.slate900,
            ),
          ),
        ],
      ),
    );
  }
}
