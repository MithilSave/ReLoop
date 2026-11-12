import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/query.dart';
import '../ui/data_list.dart';
import '../ui/widgets.dart';
import 'generator.dart' show bcode;
import 'ngo.dart' show AnomalyTable, AuditTable, byId;

class AdminOverview extends StatelessWidget {
  const AdminOverview({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {
          'i': QDef(K.impact, Api.impactSummary),
          'p': QDef(K.adminOrgs('PENDING'), () => Api.adminOrgs('PENDING')),
          'a': QDef(K.anomalies, Api.anomalies),
        },
        builder: (context, q) {
          final pending = q.get<List<J>>('p');
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(title: 'Platform overview', description: 'Platform-wide totals, organisations awaiting approval and open alerts.'),
            const Note(text: 'Admin capabilities are limited to what the backend supports: organisation approval, anomaly review and the audit trail. User management is not available.'),
            const SizedBox(height: 16),
            Gap([
              KpiGrid([
                Kpi(icon: Icons.apartment, label: 'Organisations awaiting approval', value: qText<List<J>>(q, 'p', (p) => '${p.length}')),
                Kpi(icon: Icons.warning_amber_rounded, label: 'Open anomaly flags', value: qText<List<J>>(q, 'a', (a) => '${a.where((x) => x['status'] == 'OPEN').length}')),
                Kpi(icon: Icons.inventory_2_outlined, label: 'Batches on platform', value: qText<J>(q, 'i', (i) => '${i['total_batches'] ?? '—'}')),
                Kpi(label: 'NGO-verified batches', value: qText<J>(q, 'i', (i) => '${jo(i['stages'])?['verified_batches_count'] ?? '—'}')),
              ]),
              Panel(
                title: 'Quantities across the platform',
                footer: const SourceLine('ReLoop API · /impact/summary'),
                child: qView<J>(q, 'i', (i) {
                  final s = jo(i['stages']) ?? const <String, dynamic>{};
                  final e = jo(i['environmental_impact']) ?? const <String, dynamic>{};
                  return RGrid(minWidth: 300, maxCols: 2, gap: 24, children: [
                    KV([
                      KVRow('Collected', kg(dn(s['collected_kg']))),
                      KVRow('Received', kg(dn(s['received_kg']))),
                      KVRow('Accepted', kg(dn(s['accepted_kg']))),
                      KVRow('Recovered output', kg(dn(s['processed_output_kg']))),
                      KVRow('Allocated to EPR clients', kg(dn(s['epr_allocated_kg']))),
                    ]),
                    Gap([
                      KV([
                        KVRow('CO₂ avoided (backend estimate)', kg(dn(e['co2_avoided_kg']))),
                        KVRow('Landfill diverted (accepted kg)', kg(dn(e['landfill_diverted_kg']))),
                      ]),
                      const Small('Environmental figures use fixed multipliers in the backend and are not measured values.', size: 11.5),
                    ], gap: 8),
                  ]);
                }),
              ),
              if (pending != null && pending.isNotEmpty)
                Note(
                  tone: Tone.warn,
                  child: Wrap(spacing: 6, children: [
                    Text('${pending.length} organisation(s) cannot operate until approved.'),
                    LinkText('Review approvals', () => go('/a/organisations')),
                  ]),
                ),
            ]),
          ]);
        },
      );
}

class AdminOrganisations extends StatefulWidget {
  const AdminOrganisations({super.key});
  @override
  State<AdminOrganisations> createState() => _AdminOrganisationsState();
}

class _AdminOrganisationsState extends State<AdminOrganisations> {
  String _status = 'PENDING';
  @override
  Widget build(BuildContext context) {
    final st = _status.isEmpty ? null : _status;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Organisation approvals',
        description: 'Collectors, recyclers, NGOs and EPR companies must be approved before they can act. Generators are approved automatically.',
        actions: [
          SizedBox(
            width: 170,
            child: Sel<String>(
              value: _status,
              items: const [('PENDING', 'Pending'), ('APPROVED', 'Approved'), ('REJECTED', 'Rejected'), ('SUSPENDED', 'Suspended'), ('', 'All')],
              onChanged: (v) => setState(() => _status = v ?? ''),
            ),
          ),
        ],
      ),
      Panel(
        flush: true,
        footer: const SourceLine('ReLoop API · /admin/orgs (integration patch #1)'),
        child: QueryView<List<J>>(
          qk: K.adminOrgs(st),
          fetch: () => Api.adminOrgs(st),
          builder: (context, os) => DataList<J>(
            label: 'Organisations',
            rows: os,
            rowKey: (o) => sn(o['id'])!,
            search: (o) => sn(o['legal_name']) ?? '',
            searchHint: 'Search organisation',
            filters: [
              Flt<J>('t', 'Type', [for (final t in ['GENERATOR', 'COLLECTOR', 'RECYCLER', 'NGO', 'EPR_CLIENT']) (t, humanize(t))], (o) => sn(o['org_type']) ?? ''),
            ],
            emptyTitle: _status == 'PENDING' ? 'No organisations awaiting approval' : 'No organisations',
            cols: [
              Col<J>(
                'n',
                'Organisation',
                (o) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                  Text(sn(o['legal_name']) ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Small(sn(o['address']) ?? '')),
                ]),
                sort: (o) => sn(o['legal_name']),
              ),
              tcol<J>('t', 'Type', (o) => humanize(o['org_type']), sortable: false),
              Col<J>('r', 'Registration', (o) {
                final reg = jo(o['registration']) ?? const <String, dynamic>{};
                final v = reg.values.where((x) => x != null && '$x'.isNotEmpty).take(2).join(' · ');
                return Mono(v.isEmpty ? '—' : v, size: 12);
              }),
              Col<J>('g', 'GSTIN', (o) => Mono(sn(o['gstin']) ?? '—', size: 12)),
              Col<J>('s', 'Status', (o) => Pill(humanize(o['approval_status']), tone: o['approval_status'] == 'APPROVED' ? Tone.ok : (o['approval_status'] == 'PENDING' ? Tone.warn : Tone.bad))),
              Col<J>('x', '', (o) => Btn('Change status', small: true, kind: BtnKind.outline, onPressed: () => showSheet(context, _ApproveSheet(o)))),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _ApproveSheet extends StatefulWidget {
  final J o;
  const _ApproveSheet(this.o);
  @override
  State<_ApproveSheet> createState() => _ApproveSheetState();
}

class _ApproveSheetState extends State<_ApproveSheet> {
  late String _decision = widget.o['approval_status'] == 'APPROVED' ? 'SUSPENDED' : 'APPROVED';
  final _note = TextEditingController();
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.approveOrg(sn(widget.o['id'])!, _decision, _note.text.trim().isEmpty ? null : _note.text.trim()),
      invalidate: [K.admin, 'orgs'],
      success: (d) => 'Organisation ${humanize(d['approval_status']).toLowerCase()}',
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'Change status · ${widget.o['legal_name']}',
        description: '${humanize(widget.o['org_type'])} · currently ${humanize(widget.o['approval_status'])}',
        actions: [Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)), Btn('Save', loading: _busy, onPressed: _save)],
        children: [
          Field(
            label: 'New status',
            child: Sel<String>(
              value: _decision,
              items: const [('APPROVED', 'Approve'), ('REJECTED', 'Reject'), ('SUSPENDED', 'Suspend')],
              onChanged: (v) => setState(() => _decision = v ?? _decision),
            ),
          ),
          Field(label: 'Note', hint: 'The backend does not store this note yet.', child: In(_note, maxLines: 2)),
          if (_err != null) Note(tone: Tone.bad, text: _err!.message),
        ],
      );
}

class AdminAnomalies extends StatelessWidget {
  const AdminAnomalies({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {'a': QDef(K.anomalies, Api.anomalies), 'b': QDef(K.batchList(), () => Api.batches())},
        builder: (context, q) {
          final m = byId(q.list('b'));
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(title: 'Anomaly alerts', description: 'All anomaly flags on the platform.'),
            Panel(
              flush: true,
              footer: const SourceLine('ReLoop API · /anomalies'),
              child: qView<List<J>>(q, 'a', (as) => AnomalyTable(rows: as, canResolve: true, batchCode: (id) => m[sn(id)] == null ? null : bcode(m[sn(id)]!))),
            ),
          ]);
        },
      );
}

class AdminAudit extends StatelessWidget {
  const AdminAudit({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
        PageHeader(
            title: 'Audit trail',
            description: "Hash-chained audit log written by the backend. The chain check compares each row's previous hash with the row before it."),
        Panel(flush: true, footer: SourceLine('ReLoop API · /audit/logs (last 100 rows)'), child: AuditTable()),
      ]);
}

class AdminLookup extends StatefulWidget {
  const AdminLookup({super.key});
  @override
  State<AdminLookup> createState() => _AdminLookupState();
}

class _AdminLookupState extends State<AdminLookup> {
  final _q = TextEditingController();
  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  void _open() {
    final v = _q.text.trim().toUpperCase();
    if (v.isNotEmpty) openPassport(v);
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(title: 'Batch lookup', description: "Open any batch's material passport."),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          SizedBox(width: 340, child: In(_q, placeholder: 'RL-MUM-2026-000105', onSubmitted: (_) => _open())),
          Btn('Open passport', onPressed: _open),
        ]),
        const SizedBox(height: 16),
        Panel(
          flush: true,
          child: QueryView<List<J>>(
            qk: K.batchList(),
            fetch: () => Api.batches(),
            builder: (context, bs) => DataList<J>(
              label: 'All batches',
              rows: bs,
              rowKey: (b) => sn(b['id'])!,
              onTap: (b) => openPassport(bcode(b)),
              search: (b) => '${bcode(b)} ${b['generator_name'] ?? ''}',
              cols: [
                Col<J>('c', 'Batch', (b) => Mono(bcode(b), size: 12), sort: (b) => bcode(b)),
                tcol<J>('g', 'Generator', (b) => sn(b['generator_name']) ?? '—', sortable: false),
                tcol<J>('m', 'Material', (b) => sn(b['material']) ?? '', sortable: false),
                tcol<J>('s', 'Status', (b) => humanize(b['status'])),
              ],
            ),
          ),
        ),
      ]);
}
