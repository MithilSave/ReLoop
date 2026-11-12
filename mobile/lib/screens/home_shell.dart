import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/persona.dart';
import '../services/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/persona_selector_sheet.dart';
import '../widgets/material_passport_dialog.dart';
import 'generator/generator_dashboard.dart';
import 'collector/collector_dashboard.dart';
import 'recycler/recycler_dashboard.dart';
import 'ngo/verification_queue_screen.dart';
import 'epr/compliance_dashboard_screen.dart';
import 'admin/admin_system_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final persona = state.currentPersona;

    Widget body;
    switch (persona.role) {
      case UserRole.generator:
        body = const GeneratorDashboard();
        break;
      case UserRole.collector:
        body = const CollectorDashboard();
        break;
      case UserRole.recycler:
        body = const RecyclerDashboard();
        break;
      case UserRole.ngo:
        body = const VerificationQueueScreen();
        break;
      case UserRole.eprBody:
        body = const ComplianceDashboardScreen();
        break;
      case UserRole.admin:
        body = const AdminSystemScreen();
        break;
    }

    // Sample batch for DPP shortcut
    final sampleBatch = state.batches.firstWhere(
      (b) => b.batchCode == 'RL-MUM-2026-000123',
      orElse: () => state.batches.first,
    );

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 16,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppTheme.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.recycling, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'ReLoop',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.slate900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryLight,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'PILOT',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  'Mumbai Traceability Hub',
                  style: const TextStyle(
                      fontSize: 10, color: AppTheme.slate500, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Passport shortcut
          IconButton(
            icon: const Icon(Icons.qr_code_2, size: 22),
            tooltip: 'Sample Material Passport',
            onPressed: () => MaterialPassportDialog.show(context, sampleBatch),
          ),

          // Persona Switcher Pill
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              onTap: () => PersonaSelectorSheet.show(context),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.slate100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.slate300),
                ),
                child: Row(
                  children: [
                    Text(persona.avatar, style: const TextStyle(fontSize: 14)),
                    const SizedBox(width: 6),
                    Text(
                      persona.name.split(' ').first,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.slate800,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Icon(Icons.arrow_drop_down,
                        size: 16, color: AppTheme.slate500),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: body,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: AppTheme.slate200, width: 1)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF10B981),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Active Role: ${persona.orgTypeLabel}',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate700,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => PersonaSelectorSheet.show(context),
                child: const Text(
                  'Switch Persona ❯',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
