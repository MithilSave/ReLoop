import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/batch.dart';
import '../../services/app_state.dart';
import '../../theme/app_theme.dart';
import '../../widgets/ai_scanner_dialog.dart';
import '../../widgets/material_passport_dialog.dart';

class CreateBatchScreen extends StatefulWidget {
  const CreateBatchScreen({super.key});

  @override
  State<CreateBatchScreen> createState() => _CreateBatchScreenState();
}

class _CreateBatchScreenState extends State<CreateBatchScreen> {
  PolymerType _selectedPolymer = PolymerType.pet;
  PackagingCategory _selectedCategory = PackagingCategory.catI;
  double _estimatedKg = 85.0;
  String _selectedLocality = 'Andheri West';
  final TextEditingController _addressCtrl = TextEditingController(
    text: 'Veera Desai Road, Andheri West, Mumbai 400053',
  );
  double? _aiConfidence;

  final List<String> _localities = [
    'Andheri West',
    'Andheri East',
    'Bandra West',
    'Bandra East',
    'Goregaon East',
    'Goregaon West',
    'Malad West',
    'Lower Parel',
    'Dadar West',
    'Powai',
    'Kurla West',
    'Vikhroli West',
    'Thane West',
    'Navi Mumbai (Vashi)',
  ];

  @override
  void dispose() {
    _addressCtrl.dispose();
    super.dispose();
  }

  void _openAIScanner() {
    showDialog(
      context: context,
      builder: (ctx) => AIScannerDialog(
        onDetected: (polymer, confidence) {
          setState(() {
            _selectedPolymer = polymer;
            _aiConfidence = confidence;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Optical AI detected ${polymer.label} with ${confidence.toStringAsFixed(1)}% confidence!'),
              backgroundColor: AppTheme.primary,
            ),
          );
        },
      ),
    );
  }

  void _submit() {
    final state = Provider.of<AppState>(context, listen: false);
    final batch = state.createBatch(
      material: _selectedPolymer,
      packagingCategory: _selectedCategory,
      estimatedKg: _estimatedKg,
      pickupAddress: _addressCtrl.text,
      locality: _selectedLocality,
      availableFrom: '2026-11-13',
      availableTo: '2026-11-16',
    );

    Navigator.of(context).pop();
    MaterialPassportDialog.show(context, batch);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('List Plastic Batch'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // AI Scanner trigger banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: AppTheme.primary, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Optical AI Polymer Scanner',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Scan bales/bottles to auto-detect Resin Code',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _openAIScanner,
                    child: const Text('Scan'),
                  ),
                ],
              ),
            ),
            if (_aiConfidence != null)
              Container(
                margin: const EdgeInsets.only(top: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppTheme.primary.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle,
                        size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'AI Suggested ${_selectedPolymer.label} (${_aiConfidence!.toStringAsFixed(1)}% match). Tap below to modify if needed.',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primaryDark,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 24),

            // Polymer selector
            const Text(
              '1. Polymer Type (Resin Identification Code)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PolymerType.values.map((p) {
                final isSel = p == _selectedPolymer;
                return ChoiceChip(
                  label: Text('♳ #${p.ricNumber} ${p.label}'),
                  selected: isSel,
                  selectedColor: AppTheme.primaryLight,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSel ? AppTheme.primary : AppTheme.slate300,
                    width: isSel ? 1.5 : 1,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 12,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? AppTheme.primaryDark : AppTheme.slate700,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedPolymer = p);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Packaging Category selector
            const Text(
              '2. Packaging Category (CPCB Rules 2022)',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate800,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: PackagingCategory.values.map((cat) {
                final isSel = cat == _selectedCategory;
                return ChoiceChip(
                  label: Text(cat.label),
                  selected: isSel,
                  selectedColor: const Color(0xFFF0FDF4),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSel ? AppTheme.primary : AppTheme.slate300,
                    width: isSel ? 1.5 : 1,
                  ),
                  labelStyle: TextStyle(
                    fontSize: 11,
                    fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                    color: isSel ? AppTheme.primaryDark : AppTheme.slate700,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // Weight Slider
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '3. Estimated Quantity (kg)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate800,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.primary),
                  ),
                  child: Text(
                    '${_estimatedKg.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryDark,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: _estimatedKg,
              min: 10.0,
              max: 500.0,
              divisions: 98,
              activeColor: AppTheme.primary,
              label: '${_estimatedKg.toStringAsFixed(0)} kg',
              onChanged: (val) => setState(() => _estimatedKg = val),
            ),
            const Text(
              'Doorstep digital scale verification will determine final accepted weight.',
              style: TextStyle(fontSize: 11, color: AppTheme.slate500),
            ),
            const SizedBox(height: 20),

            // Locality
            const Text(
              '4. Mumbai Locality',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate800,
              ),
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
                  value: _selectedLocality,
                  isExpanded: true,
                  items: _localities
                      .map((loc) => DropdownMenuItem(
                            value: loc,
                            child: Text(loc,
                                style: const TextStyle(fontSize: 13)),
                          ))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedLocality = val);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Pickup Address
            const Text(
              '5. Detailed Pickup Address',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppTheme.slate800,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _addressCtrl,
              decoration: const InputDecoration(
                hintText: 'Building name, gate, street address...',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 28),

            // Submit
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Create Batch & Generate QR',
                  style: TextStyle(fontSize: 15)),
            ),
          ],
        ),
      ),
    );
  }
}
