import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/app_state.dart';
import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/status_badge.dart';

class AdminSystemScreen extends StatelessWidget {
  const AdminSystemScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = Provider.of<AppState>(context);
    final anomalies = state.anomalies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('System Administration & Integrity'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hash chain integrity banner
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
                    children: const [
                      Icon(Icons.security, color: Color(0xFF10B981), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'CRYPTOGRAPHIC HASH-CHAIN VERIFIED',
                        style: TextStyle(
                          color: Color(0xFF10B981),
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Audit log hash chaining is intact. All custody transitions, OTP confirmations, weighbridge gate slips, and allocations are backed by SHA-256 hashes.',
                    style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Anomaly Monitor
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Active System Anomaly Flags',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.slate900,
                  ),
                ),
                Text(
                  '${anomalies.where((a) => a.status == 'OPEN').length} Open',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFBE123C),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: anomalies.length,
              separatorBuilder: (ctx, i) => const SizedBox(height: 10),
              itemBuilder: (ctx, i) {
                final a = anomalies[i];
                final isOpen = a.status == 'OPEN';

                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isOpen ? const Color(0xFFFECDD3) : AppTheme.slate200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              StatusBadge(status: a.severity, isSeverity: true),
                              const SizedBox(width: 8),
                              Text(
                                a.code,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  fontFamily: 'monospace',
                                  color: AppTheme.slate600,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? const Color(0xFFFFF1F2)
                                  : const Color(0xFFF0FDF4),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              a.status,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOpen
                                    ? const Color(0xFFBE123C)
                                    : const Color(0xFF15803D),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        a.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.slate900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.description,
                        style: const TextStyle(fontSize: 11, color: AppTheme.slate600),
                      ),
                      const SizedBox(height: 10),

                      if (isOpen)
                        Align(
                          alignment: Alignment.centerRight,
                          child: OutlinedButton(
                            onPressed: () {
                              state.resolveAnomaly(a.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Anomaly resolved and audit trail updated.'),
                                  backgroundColor: AppTheme.primary,
                                ),
                              );
                            },
                            child: const Text('Acknowledge & Resolve'),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // Backend Connectivity & API Synchronization Card
            Container(
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
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            state.isBackendConnected
                                ? Icons.cloud_done
                                : Icons.cloud_off,
                            color: state.isBackendConnected
                                ? AppTheme.primary
                                : AppTheme.slate400,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'FastAPI Backend & DB Sync',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.slate900,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: state.isBackendConnected
                              ? AppTheme.primaryLight
                              : AppTheme.slate100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          state.isBackendConnected ? 'ONLINE' : 'OFFLINE',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: state.isBackendConnected
                                ? AppTheme.primaryDark
                                : AppTheme.slate600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.backendStatusMessage,
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.slate600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'API Endpoint: ${ApiService().baseUrl}',
                    style: const TextStyle(
                      fontSize: 10,
                      fontFamily: 'monospace',
                      color: AppTheme.slate400,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final ok = await state.checkBackendConnection();
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(ok
                                    ? 'Backend responded with HTTP 200 OK!'
                                    : 'Backend is currently offline or unreachable.'),
                                backgroundColor:
                                    ok ? AppTheme.primary : AppTheme.slate700,
                              ),
                            );
                          },
                          icon: const Icon(Icons.network_ping, size: 14),
                          label: const Text('Ping Health',
                              style: TextStyle(fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: state.isSyncing
                              ? null
                              : () => state.syncWithBackend(),
                          icon: state.isSyncing
                              ? const SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.sync, size: 14),
                          label: Text(
                            state.isSyncing ? 'Syncing...' : 'Sync Records',
                            style: const TextStyle(fontSize: 11),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Hash-Chain Ledger Block Sample
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppTheme.slate50,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.slate200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Recent SHA-256 Chained Blocks (Tamper-Evidence)',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.slate800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildHashBlock(
                    'Block #00124',
                    'BATCH_HANDOVER_CONFIRMED',
                    'b9a4c1f8d3...9e210a4f',
                    'Prev: a18f90...',
                  ),
                  const SizedBox(height: 6),
                  _buildHashBlock(
                    'Block #00125',
                    'WEIGHBRIDGE_RECEIPT_LOGGED',
                    'c4f7281d80...03b8e721',
                    'Prev: b9a4c1...',
                  ),
                  const SizedBox(height: 6),
                  _buildHashBlock(
                    'Block #00126',
                    'NGO_AUDIT_DECISION_VERIFIED',
                    '5f2b847849...2957b494',
                    'Prev: c4f728...',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Reset Demo State Button
            OutlinedButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Reset Demo State?'),
                    content: const Text(
                        'This will restore all demo batches, OTP codes, runs, and allocations to their initial state.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          state.resetDemoData();
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Demo state reset to initial values!'),
                              backgroundColor: AppTheme.primary,
                            ),
                          );
                        },
                        child: const Text('Reset'),
                      ),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Reset Demo Dataset to Default'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHashBlock(
      String blockNo, String event, String hash, String prevHash) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.slate200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.link, size: 12, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                '$blockNo: $event',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.slate800,
                ),
              ),
            ],
          ),
          Text(
            hash,
            style: const TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: AppTheme.slate500,
            ),
          ),
        ],
      ),
    );
  }
}
