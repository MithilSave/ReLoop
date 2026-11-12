import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';

class AvailableListingsScreen extends StatefulWidget {
  const AvailableListingsScreen({super.key});

  @override
  State<AvailableListingsScreen> createState() =>
      _AvailableListingsScreenState();
}

class _AvailableListingsScreenState extends State<AvailableListingsScreen> {
  PolymerType? _filterPolymer;

  void _showQuoteDialog(BuildContext context, WasteBatch batch) {
    double offeredRate = 16.50;
    String pickupSlot = 'Tomorrow, 11:30 AM - 1:30 PM';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          return AlertDialog(
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.transparent,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.request_quote,
                    color: AppTheme.primary, size: 22),
                const SizedBox(width: 8),
                Text(
                  'Quote ${batch.batchCode}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${batch.generatorName} • ${batch.locality}',
                    style:
                        const TextStyle(fontSize: 12, color: AppTheme.slate600),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.slate50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.slate200),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Material: ${batch.material.label}',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        Text(
                            'Est: ${batch.quantities.estimatedKg.toStringAsFixed(1)} kg',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text('Your Offer Rate (₹ / kg):',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: offeredRate.toStringAsFixed(2),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      prefixText: '₹ ',
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) {
                      final parsed = double.tryParse(val);
                      if (parsed != null) offeredRate = parsed;
                    },
                  ),
                  const SizedBox(height: 14),
                  const Text('Proposed Pickup Window:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  TextFormField(
                    initialValue: pickupSlot,
                    decoration: const InputDecoration(
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    onChanged: (val) => pickupSlot = val,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  final state = Provider.of<AppState>(context, listen: false);
                  state.makeOffer(batch.id, offeredRate, pickupSlot);
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          'Quote of ₹${offeredRate.toStringAsFixed(2)}/kg submitted to ${batch.generatorName}!'),
                      backgroundColor: AppTheme.primary,
                    ),
                  );
                },
                child: const Text('Send Quote'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    var listings =
        state.batches.where((b) => b.status.label == 'LISTED').toList();

    if (_filterPolymer != null) {
      listings = listings.where((b) => b.material == _filterPolymer).toList();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Listings (Mumbai)'),
      ),
      body: Column(
        children: [
          // Filter Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                ChoiceChip(
                  label: const Text('All Materials'),
                  selected: _filterPolymer == null,
                  onSelected: (val) => setState(() => _filterPolymer = null),
                ),
                const SizedBox(width: 8),
                ...PolymerType.values.map((p) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.label),
                      selected: _filterPolymer == p,
                      onSelected: (val) =>
                          setState(() => _filterPolymer = val ? p : null),
                    ),
                  );
                }),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.slate200),

          // List
          Expanded(
            child: listings.isEmpty
                ? const Center(
                    child: Text(
                      'No open listings for this filter.',
                      style: TextStyle(color: AppTheme.slate500),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: listings.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (ctx, i) {
                      final b = listings[i];
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
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      b.batchCode,
                                      style: const TextStyle(
                                        fontSize: 13,
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
                                        '${b.material.label} (RIC #${b.material.ricNumber})',
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
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text(
                                    '94% Proximity Match',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1D4ED8),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              b.generatorName,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.slate800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.location_on,
                                    size: 13, color: AppTheme.slate400),
                                const SizedBox(width: 4),
                                Expanded(
                                  child: Text(
                                    '${b.locality} • ${b.pickupAddress}',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: AppTheme.slate500),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment:
                                  MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    const Text('Estimated Load',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: AppTheme.slate500)),
                                    Text(
                                      '${b.quantities.estimatedKg.toStringAsFixed(1)} kg',
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.slate900,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _showQuoteDialog(context, b),
                                  icon: const Icon(Icons.send, size: 14),
                                  label: const Text('Make Offer'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
