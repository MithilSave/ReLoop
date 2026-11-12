import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class ConsignmentBuilderScreen extends StatefulWidget {
  const ConsignmentBuilderScreen({super.key});

  @override
  State<ConsignmentBuilderScreen> createState() =>
      _ConsignmentBuilderScreenState();
}

class _ConsignmentBuilderScreenState extends State<ConsignmentBuilderScreen> {
  final Set<String> _selectedBatchIds = {};
  String _selectedRecyclerId = 'org-rec-01';
  String _selectedRecyclerName = 'Apex Plastic Recovery PWP';
  final TextEditingController _vehicleCtrl =
      TextEditingController(text: 'MH-02-EE-8421 (Tata Ace EV)');

  final List<Map<String, String>> _recyclers = [
    {
      'id': 'org-rec-01',
      'name': 'Apex Plastic Recovery PWP',
      'locality': 'Turbhe, Navi Mumbai',
      'types': 'PET, HDPE, PP',
    },
    {
      'id': 'org-rec-02',
      'name': 'Maharashtra Polymer Recycling Ltd',
      'locality': 'Bhiwandi Hub',
      'types': 'PET, PP, LDPE',
    },
  ];

  @override
  void dispose() {
    _vehicleCtrl.dispose();
    super.dispose();
  }

  void _dispatch() {
    if (_selectedBatchIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least 1 picked-up batch for dispatch.'),
          backgroundColor: Color(0xFFBE123C),
        ),
      );
      return;
    }

    final state = Provider.of<AppState>(context, listen: false);
    final consignment = state.createConsignment(
      batchIds: _selectedBatchIds.toList(),
      destinationRecyclerId: _selectedRecyclerId,
      destinationRecyclerName: _selectedRecyclerName,
      vehicleNo: _vehicleCtrl.text,
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            'Consignment ${consignment.consignmentCode} dispatched to $_selectedRecyclerName!'),
        backgroundColor: AppTheme.primary,
      ),
    );

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final readyBatches = state.batches
        .where((b) =>
            b.collectorOrgId == state.currentPersona.orgId &&
            b.status.label == 'PICKED_UP')
        .toList();

    double totalSelectedKg = 0;
    for (final b in readyBatches) {
      if (_selectedBatchIds.contains(b.id)) {
        totalSelectedKg += b.quantities.collectedKg ?? 0;
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Consignment Dispatch Builder'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Top instructions
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, size: 18, color: Color(0xFF1D4ED8)),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Group multiple picked-up batches into a single transport vehicle without losing individual batch traceability.',
                      style: TextStyle(fontSize: 11, color: Color(0xFF1E3A8A)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Select Recycler Destination
            const Text(
              '1. Destination Plastic Waste Processor (PWP)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.slate300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedRecyclerId,
                  isExpanded: true,
                  items: _recyclers
                      .map((r) => DropdownMenuItem(
                            value: r['id'],
                            child: Text(
                              '${r['name']} (${r['locality']})',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedRecyclerId = val;
                        _selectedRecyclerName = _recyclers
                            .firstWhere((r) => r['id'] == val)['name']!;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Vehicle number
            const Text(
              '2. Transport Vehicle Registration',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _vehicleCtrl,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.directions_car, size: 18),
                hintText: 'e.g. MH-02-EE-8421 (Tata Ace EV)',
              ),
            ),
            const SizedBox(height: 20),

            // Select Batches Checkbox list
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '3. Batches at Hub Ready for Transit',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      if (_selectedBatchIds.length == readyBatches.length) {
                        _selectedBatchIds.clear();
                      } else {
                        _selectedBatchIds
                            .addAll(readyBatches.map((b) => b.id));
                      }
                    });
                  },
                  child: Text(
                    _selectedBatchIds.length == readyBatches.length
                        ? 'Deselect All'
                        : 'Select All',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (readyBatches.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.slate200),
                ),
                child: const Center(
                  child: Text(
                    'No batches in PICKED_UP status awaiting dispatch.',
                    style: TextStyle(fontSize: 12, color: AppTheme.slate500),
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: readyBatches.length,
                separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final b = readyBatches[i];
                  final isChecked = _selectedBatchIds.contains(b.id);

                  return CheckboxListTile(
                    value: isChecked,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedBatchIds.add(b.id);
                        } else {
                          _selectedBatchIds.remove(b.id);
                        }
                      });
                    },
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color:
                            isChecked ? AppTheme.primary : AppTheme.slate200,
                      ),
                    ),
                    tileColor: isChecked ? AppTheme.primaryLight : Colors.white,
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          b.batchCode,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          ),
                        ),
                        Text(
                          '${(b.quantities.collectedKg ?? 0).toStringAsFixed(1)} kg',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                            color: AppTheme.slate900,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      '${b.material.label} • From ${b.generatorName}',
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.slate600),
                    ),
                  );
                },
              ),
            const SizedBox(height: 24),

            // Summary Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.slate900,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TOTAL CONSIGNMENT LOAD',
                        style: TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${totalSelectedKg.toStringAsFixed(1)} kg',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                      Text(
                        '${_selectedBatchIds.length} batches selected',
                        style: const TextStyle(
                            color: Color(0xFF34D399), fontSize: 11),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _dispatch,
                    icon: const Icon(Icons.send, size: 16),
                    label: const Text('Dispatch'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
