import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/quantities.dart';
import '../core/query.dart';
import '../features/passport.dart' show TabsView;
import '../features/photos.dart';
import '../ui/charts.dart';
import '../ui/data_list.dart';
import '../ui/widgets.dart';
import 'collector.dart' show ConsignmentDetail, PlansTable, openPlan, perfFmt, historyTone;
import 'generator.dart' show bcode, numOf;

double _sum(Iterable<J> rows, String k) => rows.fold<double>(0, (s, r) => s + (dn(r[k]) ?? 0));
double _unacc(J r) => (dn(r['input_kg']) ?? 0) - (dn(r['output_kg']) ?? 0) - (dn(r['residue_kg']) ?? 0);
double? _unaccPct(J r) {
  final i = dn(r['input_kg']) ?? 0;
  return i == 0 ? null : _unacc(r) / i * 100;
}

List<(String, String)> _matItems(List<J> mats, {bool withName = true}) =>
    [for (final m in mats) (sn(m['code'])!, withName ? '${m['code']} · ${m['name']}' : sn(m['code'])!)];

/* ─────────────── Dashboard ─────────────── */
class RecyclerDashboard extends StatelessWidget {
  const RecyclerDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Queries(
      queries: {
        'c': QDef(K.consignments, Api.consignments),
        'r': QDef(K.receipts(), () => Api.receipts()),
        'p': QDef(K.processing, Api.processing),
        'cap': QDef(K.capacity, Api.capacity),
        'a': QDef(K.allocations, Api.allocations),
      },
      builder: (context, q) {
        final open = q.list('c').where((x) => consStatus(x) != 'RECEIVED').toList();
        final rs = q.list('r');
        final ps = q.list('p');
        final inp = _sum(ps, 'input_kg'), out = _sum(ps, 'output_kg'), res = _sum(ps, 'residue_kg');
        final elig = _sum(ps, 'eligible_kg'), alloc = _sum(ps, 'allocated_kg');
        final waiting = rs.where((r) => (dn(r['available_kg']) ?? 0) > 0).length;
        final arrived = open.where((x) => consStatus(x) == 'ARRIVED').toList();
        final transit = open.where((x) => consStatus(x) == 'IN_TRANSIT').toList();
        final overRuns = ps.where((r) => r['yield_pct'] != null && (_unaccPct(r) ?? 0) > 3).toList();
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHeader(
            title: 'Operations dashboard',
            description: 'Feedstock arriving, accepted stock on hand, processing output and EPR attribution.',
            actions: [
              Btn('Plan sourcing', icon: Icons.layers_outlined, kind: BtnKind.outline, onPressed: () => go('/r/planner')),
              Btn('Record processing run', icon: Icons.science_outlined, onPressed: () => go('/r/runs')),
            ],
          ),
          Gap([
            KpiGrid([
              Kpi(
                  icon: Icons.local_shipping_outlined,
                  label: 'Incoming consignments',
                  value: q.has('c') ? '${open.length}' : '…',
                  sub: '${open.fold<int>(0, (s, x) => s + jl(x['items']).length)} batches · ${arrived.length} at gate'),
              Kpi(icon: Icons.inbox_outlined, label: 'Accepted stock on hand', value: q.has('r') ? kg(_sum(rs, 'available_kg')) : '…', sub: '${plural(waiting, 'batch', 'batches')} not fully processed'),
              Kpi(icon: Icons.speed, label: 'Processing yield', value: q.has('p') ? pct(inp != 0 ? out / inp * 100 : null) : '…', sub: '${kg(out)} recovered of ${kg(inp)} input'),
              Kpi(icon: Icons.link, label: 'EPR-eligible free', value: q.has('p') ? kg(elig - alloc) : '…', sub: '${kg(alloc)} of ${kg(elig)} declared kg allocated'),
            ]),
            TwoCol(
              main: Panel(
                title: 'Material flow',
                sub: 'Your receipts and processing runs',
                footer: const SourceLine('ReLoop API · /recycler/receipts, /recycler/processing-records'),
                child: Gap([
                  BarChart(
                    labels: const ['Received', 'Accepted', 'Processed input', 'Recovered output', 'Declared eligible', 'Allocated'],
                    series: [Series('Quantity', c.c2, [_sum(rs, 'received_kg'), _sum(rs, 'accepted_kg'), inp, out, elig, alloc])],
                  ),
                  KpiGrid([
                    Kpi(label: 'Rejected at receipt', value: kg(_sum(rs, 'rejected_kg'))),
                    Kpi(label: 'Process residue', value: kg(res)),
                    Kpi(label: 'Unaccounted', value: kg(inp - out - res), sub: inp != 0 ? '${pct((inp - out - res) / inp * 100)} of input' : null),
                  ], cols: 3),
                ], gap: 12),
              ),
              side: Gap([
                Panel(
                  title: 'Needs attention',
                  child: Gap([
                    for (final x in arrived)
                      Note(
                        tone: Tone.warn,
                        child: Wrap(spacing: 6, children: [
                          Text('${x['consignment_code']} is at your gate with ${plural(jl(x['items']).length, 'batch', 'batches')}.'),
                          LinkText('Record receipt', () => go('/r/incoming')),
                        ]),
                      ),
                    for (final x in transit) Note(text: '${x['consignment_code']} in transit · ${plural(jl(x['items']).length, 'batch', 'batches')}'),
                    for (final r in overRuns)
                      Note(tone: Tone.warn, text: '${r['record_code']}: unaccounted ${pct(_unaccPct(r))} of input exceeds the 3% guideline.'),
                    if (open.isEmpty) const Small('Nothing needs action.', size: 13.5),
                  ], gap: 8),
                ),
                Panel(
                  title: 'Capacity this month',
                  child: qView<J>(
                    q,
                    'cap',
                    (cap) => KV([
                      KVRow('Monthly capacity', kg(dn(cap['monthly_capacity_kg']))),
                      KVRow('Output this month', kg(dn(cap['processed_this_month_kg']))),
                      KVRow('Utilisation', pct(dn(cap['utilization_pct']))),
                      KVRow('Remaining', kg(dn(cap['remaining_capacity_kg'])), total: true),
                    ]),
                  ),
                ),
              ]),
            ),
            Panel(
              title: 'Recent processing runs',
              flush: true,
              actions: [Btn('All runs', small: true, kind: BtnKind.outline, onPressed: () => go('/r/runs'))],
              child: qView<List<J>>(q, 'p', (rows) => RunsTable(rows.take(5).toList(), onOpen: (_) => go('/r/runs'))),
            ),
            if (q.error('a') != null) const Note(tone: Tone.bad, text: 'Allocations could not be loaded.'),
          ]),
        ]);
      },
    );
  }
}

/* ─────────────── Procurement requirements ─────────────── */
class RecyclerRequirements extends StatelessWidget {
  const RecyclerRequirements({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {'d': QDef(K.demand, Api.demandProfiles), 'o': QDef(K.recOffers, Api.recyclerOffers), 'm': QDef(K.materials, Api.materials)},
        builder: (context, q) {
          final mats = q.list('m');
          void demand() => showSheet(context, _DemandSheet(mats));
          void offer() => showSheet(context, _PriceOfferSheet(mats));
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              title: 'Procurement requirements',
              description: 'Feedstock you need and the gate prices you pay. Requirements drive the aggregation planner and the supply outlook.',
              actions: [Btn('Price offer', icon: Icons.add, kind: BtnKind.outline, onPressed: offer), Btn('Requirement', icon: Icons.add, onPressed: demand)],
            ),
            Gap([
              Panel(
                title: 'Demand profiles',
                flush: true,
                footer: const SourceLine('ReLoop API · /recycler/demand-profiles'),
                child: qView<List<J>>(
                  q,
                  'd',
                  (ds) => DataList<J>(
                    label: 'Demand profiles',
                    rows: ds,
                    rowKey: (d) => sn(d['id'])!,
                    emptyTitle: 'No requirements yet',
                    emptyAction: Btn('Add requirement', small: true, onPressed: demand),
                    cols: [
                      tcol<J>('m', 'Material', (d) => sn(d['material_code']) ?? ''),
                      ncol<J>('q', 'Quantity', (d) => dn(d['quantity_kg']), kg),
                      tcol<J>('r', 'Recurrence', (d) => humanize(d['recurrence']), sortable: false),
                      tcol<J>('n', 'Need by', (d) => sn(d['need_by']) ?? '—'),
                      tcol<J>('g', 'Min grade', (d) => sn(d['min_quality_grade']) ?? '', sortable: false),
                      ncol<J>('c', 'Max contamination', (d) => dn(d['max_contamination_pct']), pct, sortable: false),
                      Col<J>('s', 'Status', (d) => Pill(humanize(d['status']), tone: d['status'] == 'ACTIVE' ? Tone.ok : Tone.neutral)),
                      Col<J>('x', '', (d) => Btn('Plan sourcing', small: true, kind: BtnKind.outline, onPressed: () => go('/r/planner'))),
                    ],
                  ),
                ),
              ),
              Panel(
                title: 'Gate price offers',
                sub: 'Published to collectors through the public offers list',
                flush: true,
                footer: const SourceLine('ReLoop API · /recycler/offers'),
                child: qView<List<J>>(
                  q,
                  'o',
                  (os) => DataList<J>(
                    label: 'Price offers',
                    rows: os,
                    rowKey: (o) => sn(o['id'])!,
                    emptyTitle: 'No price offers',
                    emptyAction: Btn('Publish price', small: true, kind: BtnKind.outline, onPressed: offer),
                    cols: [
                      tcol<J>('m', 'Material', (o) => sn(o['material_code']) ?? ''),
                      ncol<J>('p', 'Price', (o) => dn(o['price_per_kg']), (v) => '${inr(v)}/kg'),
                      ncol<J>('min', 'Minimum lot', (o) => dn(o['min_kg']), kg, sortable: false),
                      ncol<J>('c', 'Max contamination', (o) => dn(o['max_contamination_pct']), pct, sortable: false),
                      Col<J>('v', 'Valid', (o) => Small('${date(o['valid_from'])} – ${date(o['valid_to'])}')),
                      Col<J>('s', 'Status', (o) {
                        final active = o['is_active'] == true && (parseIso(o['valid_to'])?.isAfter(DateTime.now()) ?? false);
                        return active ? const Pill('Active', tone: Tone.ok) : const Pill('Inactive');
                      }),
                    ],
                  ),
                ),
              ),
            ]),
          ]);
        },
      );
}

String? _pct0to100(String v) {
  final n = numOf(v);
  return (n == null || n < 0 || n > 100) ? '0–100' : null;
}

class _DemandSheet extends StatefulWidget {
  final List<J> mats;
  const _DemandSheet(this.mats);
  @override
  State<_DemandSheet> createState() => _DemandSheetState();
}

class _DemandSheetState extends State<_DemandSheet> {
  String? _mat;
  String _rec = 'ONE_OFF';
  String _grade = 'B';
  final _qty = TextEditingController();
  final _cont = TextEditingController(text: '5');
  DateTime? _needBy;
  Map<String, String> _e = {};
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    _qty.dispose();
    _cont.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final e = <String, String>{};
    if (_mat == null) e['m'] = 'Choose a material';
    final k = kgError(_qty.text, label: 'Quantity');
    if (k != null) e['q'] = k;
    final c = _pct0to100(_cont.text);
    if (c != null) e['c'] = c;
    setState(() => _e = e);
    if (e.isNotEmpty) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.createDemand({
        'material_code': _mat,
        'recurrence': _rec,
        'quantity_kg': double.parse(_qty.text.trim()),
        'min_quality_grade': _grade,
        'max_contamination_pct': double.parse(_cont.text.trim()),
        'need_by': _needBy?.toIso8601String().substring(0, 10),
      }),
      invalidate: [K.demand, 'intel/shortage'],
      success: (_) => 'Requirement published',
      onError: (e) => _err = e,
      toastErrors: false,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'New procurement requirement',
        actions: [Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)), Btn('Publish requirement', loading: _busy, onPressed: _save)],
        children: [
          RGrid(minWidth: 220, maxCols: 2, gap: 16, children: [
            Field(label: 'Material', required: true, error: _e['m'], child: Sel<String>(value: _mat, items: _matItems(widget.mats), hasError: _e['m'] != null, onChanged: (v) => setState(() => _mat = v))),
            Field(label: 'Quantity (kg)', required: true, error: _e['q'], child: In(_qty, decimal: true, hasError: _e['q'] != null)),
            Field(
              label: 'Recurrence',
              child: Sel<String>(value: _rec, items: const [('ONE_OFF', 'One-off'), ('WEEKLY', 'Weekly'), ('MONTHLY', 'Monthly')], onChanged: (v) => setState(() => _rec = v ?? 'ONE_OFF')),
            ),
            Field(label: 'Need by', child: DateTimeIn(value: _needBy, dateOnly: true, onChanged: (d) => setState(() => _needBy = d))),
            Field(label: 'Minimum grade', child: Sel<String>(value: _grade, items: const [('A', 'A'), ('B', 'B'), ('C', 'C')], onChanged: (v) => setState(() => _grade = v ?? 'B'))),
            Field(label: 'Max contamination (%)', error: _e['c'], child: In(_cont, decimal: true, hasError: _e['c'] != null)),
          ]),
          if (_err != null) Note(tone: Tone.bad, text: _err!.message),
        ],
      );
}

class _PriceOfferSheet extends StatefulWidget {
  final List<J> mats;
  const _PriceOfferSheet(this.mats);
  @override
  State<_PriceOfferSheet> createState() => _PriceOfferSheetState();
}

class _PriceOfferSheetState extends State<_PriceOfferSheet> {
  String? _mat;
  final _price = TextEditingController();
  final _min = TextEditingController(text: '100');
  final _cont = TextEditingController(text: '5');
  final _spec = TextEditingController();
  DateTime _validTo = DateTime.now().add(const Duration(days: 30));
  Map<String, String> _e = {};
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_price, _min, _cont, _spec]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final e = <String, String>{};
    if (_mat == null) e['m'] = 'Choose a material';
    if ((numOf(_price.text) ?? 0) <= 0) e['p'] = 'Enter a price';
    final k = kgError(_min.text, label: 'Minimum lot');
    if (k != null) e['min'] = k;
    final c = _pct0to100(_cont.text);
    if (c != null) e['c'] = c;
    setState(() => _e = e);
    if (e.isNotEmpty) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.createRecyclerOffer({
        'material_code': _mat,
        'price_per_kg': numOf(_price.text),
        'min_kg': numOf(_min.text),
        'max_contamination_pct': numOf(_cont.text),
        if (_spec.text.trim().isNotEmpty) 'quality_spec': _spec.text.trim(),
        'valid_to': toIsoUtc(DateTime(_validTo.year, _validTo.month, _validTo.day, 23, 59)),
      }),
      invalidate: [K.recOffers],
      success: (_) => 'Price offer published',
      onError: (e) => _err = e,
      toastErrors: false,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'Publish gate price',
        actions: [Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)), Btn('Publish price', loading: _busy, onPressed: _save)],
        children: [
          RGrid(minWidth: 220, maxCols: 2, gap: 16, children: [
            Field(label: 'Material', required: true, error: _e['m'], child: Sel<String>(value: _mat, items: _matItems(widget.mats), hasError: _e['m'] != null, onChanged: (v) => setState(() => _mat = v))),
            Field(label: 'Price (₹/kg)', required: true, error: _e['p'], child: In(_price, decimal: true, hasError: _e['p'] != null)),
            Field(label: 'Minimum lot (kg)', error: _e['min'], child: In(_min, decimal: true)),
            Field(label: 'Max contamination (%)', error: _e['c'], child: In(_cont, decimal: true)),
            Field(label: 'Valid until', required: true, child: DateTimeIn(value: _validTo, dateOnly: true, onChanged: (d) => setState(() => _validTo = d))),
            Field(label: 'Quality specification', child: In(_spec, placeholder: 'Clear bottles, labels removed')),
          ]),
          if (_err != null) Note(tone: Tone.bad, text: _err!.message),
        ],
      );
}

/* ─────────────── Suppliers ─────────────── */
class RecyclerSuppliers extends StatelessWidget {
  const RecyclerSuppliers({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {'c': QDef(K.orgs('COLLECTOR'), () => Api.orgs('COLLECTOR')), 'b': QDef(K.batchList(), () => Api.batches())},
        builder: (context, q) {
          final bs = q.list('b');
          final gens = <String, J>{};
          for (final b in bs) {
            final id = sn(b['generator_org_id']);
            if (id == null) continue;
            final g = gens.putIfAbsent(id, () => {'id': id, 'legal_name': b['generator_name'] ?? '—', 'role': 'Generator', 'batches': 0});
            g['batches'] = (g['batches'] as int) + 1;
          }
          final cols = [
            for (final c in q.list('c'))
              {'id': c['id'], 'legal_name': c['legal_name'], 'role': 'Collector', 'batches': bs.where((b) => b['assigned_collector_org_id'] == c['id']).length},
          ];
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(
                title: 'Suppliers',
                description: 'Collectors in the ReLoop directory and generators whose batches reached you. Indicators are rule-based and shown with their transaction count n.'),
            Panel(
              flush: true,
              footer: const Foot('ReLoop API · /orgs, /suppliers/{org}/performance',
                  note: 'Indicators are hidden until the backend has computed them (history level "insufficient").'),
              child: qView<List<J>>(
                q,
                'c',
                (_) => DataList<J>(
                  label: 'Suppliers',
                  rows: [...cols, ...gens.values],
                  rowKey: (o) => sn(o['id'])!,
                  pageSize: 20,
                  emptyTitle: 'No suppliers yet',
                  cols: [
                    Col<J>('n', 'Supplier', (o) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                          Text(sn(o['legal_name']) ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)),
                          Small(sn(o['role']) ?? ''),
                        ]), sort: (o) => sn(o['legal_name'])),
                    Col<J>('b', 'Batches with you', (o) => numText('${o['batches']}'), numeric: true, sort: (o) => o['batches'] as int),
                    Col<J>('p', 'Evidence', (o) => _PerfCells(sn(o['id'])!)),
                  ],
                ),
              ),
            ),
          ]);
        },
      );
}

/// Performance indicators of one supplier, loaded on demand.
class _PerfCells extends StatelessWidget {
  final String id;
  const _PerfCells(this.id);
  @override
  Widget build(BuildContext context) => QueryBuilder<J>(
        qk: K.perf(id),
        fetch: () => Api.supplierPerformance(id),
        builder: (context, q) {
          final p = q.data;
          if (p == null) return Small(q.error != null ? '—' : '…');
          return Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
            Pill('${humanize(p['history_level'])} · n=${p['n_transactions']}', tone: historyTone(p['history_level'])),
            Small('On-time ${perfFmt(p['on_time_rate'])}'),
            Small('Rejection ${perfFmt(p['rejection_rate'])}'),
            Small('Weight discrepancy ${perfFmt(p['weight_discrepancy_pct'])}'),
            Small('Contamination ${perfFmt(p['contamination_rate'])}'),
          ]);
        },
      );
}

/* ─────────────── Aggregation planner ─────────────── */
class RecyclerPlanner extends StatefulWidget {
  const RecyclerPlanner({super.key});
  @override
  State<RecyclerPlanner> createState() => _RecyclerPlannerState();
}

class _RecyclerPlannerState extends State<RecyclerPlanner> {
  String? _mat = 'PET';
  final _target = TextEditingController();
  String? _matErr, _targetErr;
  ApiError? _err;
  bool _busy = false;
  J? _result;

  @override
  void dispose() {
    _target.dispose();
    super.dispose();
  }

  Future<void> _propose() async {
    setState(() {
      _matErr = _mat == null ? 'Choose a material' : null;
      _targetErr = kgError(_target.text, label: 'Target');
    });
    if (_matErr != null || _targetErr != null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.proposePlan({'material_code': _mat, 'target_kg': double.parse(_target.text.trim())}),
      invalidate: [K.plans, K.batches],
      success: (d) => '${d['plan_code']} created with ${plural(jl(d['items']).length, 'batch', 'batches')}',
      onError: (e) => _err = e,
      toastErrors: false,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) _result = r;
    });
  }

  @override
  Widget build(BuildContext context) => Queries(
        queries: {'p': QDef(K.plans, Api.plans), 'm': QDef(K.materials, Api.materials), 'd': QDef(K.demand, Api.demandProfiles)},
        builder: (context, q) {
          final r = _result;
          final ds = q.list('d');
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(
                title: 'Aggregation planner',
                description: 'Combine small confirmed listings into one feedstock order. Only listed batches are used; predicted supply is never counted.'),
            Gap([
              Panel(
                title: 'Propose a plan',
                child: Gap([
                  RGrid(minWidth: 200, maxCols: 4, gap: 12, children: [
                    Field(
                        label: 'Material',
                        error: _matErr,
                        child: Sel<String>(value: _mat, items: _matItems(q.list('m'), withName: false), onChanged: (v) => setState(() => _mat = v))),
                    Field(label: 'Target (kg)', error: _targetErr, child: In(_target, decimal: true, hasError: _targetErr != null)),
                    if (ds.isNotEmpty)
                      Field(
                        label: 'Or use a requirement',
                        child: Sel<String>(
                          value: null,
                          placeholder: 'Select requirement',
                          items: [for (final d in ds) (sn(d['id'])!, '${d['material_code']} · ${kg(dn(d['quantity_kg']))} · ${humanize(d['recurrence'])}')],
                          onChanged: (v) {
                            final d = ds.where((x) => x['id'] == v).firstOrNull;
                            if (d == null) return;
                            setState(() {
                              _mat = sn(d['material_code']);
                              _target.text = '${dn(d['quantity_kg']) ?? ''}';
                            });
                          },
                        ),
                      ),
                    Padding(padding: const EdgeInsets.only(top: 22), child: Btn('Create plan', icon: Icons.layers_outlined, loading: _busy, onPressed: _propose)),
                  ]),
                  const Note(
                      text:
                          'Creating a plan saves it immediately and reserves the selected listings so other plans cannot use them. Cancel the plan to release them. The backend selects the largest listings first and uses a fixed 92% usable factor and fixed rates for the cost estimate.'),
                  if (_err != null) Note(tone: Tone.bad, text: _err!.message),
                ], gap: 12),
              ),
              if (r != null)
                Panel(
                  title: 'Result: ${r['plan_code']}',
                  actions: [Btn('Open plan', small: true, kind: BtnKind.outline, onPressed: () => openPlan(context, sn(r['plan_id'])!, sn(r['plan_code']) ?? ''))],
                  child: Builder(builder: (context) {
                    final items = jl(r['items']);
                    final ce = jo(r['cost_estimate']) ?? const <String, dynamic>{};
                    final short = dn(r['shortfall_kg']) ?? 0;
                    final usable = dn(r['est_usable_kg']) ?? 0;
                    final target = dn(r['target_kg']) ?? 0;
                    final excluded = jl(r['excluded']);
                    return Gap([
                      KpiGrid([
                        Kpi(label: 'Batches', value: '${items.length}', sub: '${kg(dn(r['est_total_kg']))} listed'),
                        Kpi(label: 'Expected usable', value: kg(usable)),
                        Kpi(
                            label: 'Landed cost',
                            value: '${inr(dn(ce['landed_cost_per_usable_kg']))}/kg',
                            sub: '${inr(dn(ce['total_cost']), decimals: false)} total · model estimate'),
                        Kpi(
                            label: short > 0 ? 'Shortfall' : 'Target (listed kg)',
                            value: short > 0 ? kg(short) : 'Met',
                            sub: usable < target ? 'Usable kg is ${kg(target - usable)} below target' : null),
                      ]),
                      if (items.isEmpty) EmptyState(title: 'No eligible listings', body: 'No unreserved $_mat listings are open.'),
                      if (excluded.isNotEmpty)
                        Small('${excluded.length} listings excluded (${{for (final e in excluded) humanize(e['reason'])}.join(', ')}).'),
                    ], gap: 12);
                  }),
                ),
              Panel(
                title: 'Your plans',
                flush: true,
                footer: const SourceLine('ReLoop API · /aggregation/plans'),
                child: qView<List<J>>(q, 'p', (ps) => PlansTable(ps)),
              ),
            ]),
          ]);
        },
      );
}

/* ─────────────── Landed cost ─────────────── */
class _Opt {
  final TextEditingController name, kg, km;
  String type;
  String mat;
  _Opt(String n, this.type, String k, String d, this.mat)
      : name = TextEditingController(text: n),
        kg = TextEditingController(text: k),
        km = TextEditingController(text: d);
  J toJson() => {'name': name.text.trim(), 'type': type, 'est_kg': numOf(kg.text) ?? 0, 'distance_km': numOf(km.text) ?? 0, 'material_code': mat};
  void dispose() {
    name.dispose();
    kg.dispose();
    km.dispose();
  }
}

class RecyclerCosts extends StatefulWidget {
  const RecyclerCosts({super.key});
  @override
  State<RecyclerCosts> createState() => _RecyclerCostsState();
}

class _RecyclerCostsState extends State<RecyclerCosts> {
  final List<_Opt> _opts = [
    _Opt('Aggregated listings (Mumbai east)', 'PLAN', '400', '15', 'PET'),
    _Opt('Single collector bale', 'COLLECTOR', '400', '30', 'PET'),
  ];
  J? _cmp;
  ApiError? _cmpErr;
  bool _cmpBusy = false;
  String _qeMat = 'PET';
  final _qeKg = TextEditingController(text: '500');
  final _qeKm = TextEditingController(text: '15');
  J? _est;
  ApiError? _estErr;
  bool _estBusy = false;

  @override
  void dispose() {
    for (final o in _opts) {
      o.dispose();
    }
    _qeKg.dispose();
    _qeKm.dispose();
    super.dispose();
  }

  Future<void> _compare() async {
    setState(() {
      _cmpBusy = true;
      _cmpErr = null;
    });
    final r = await mutate(() => Api.compareCosts(_opts.map((o) => o.toJson()).toList()), onError: (e) => _cmpErr = e, toastErrors: false);
    if (!mounted) return;
    setState(() {
      _cmpBusy = false;
      if (r != null) _cmp = r;
    });
  }

  Future<void> _estimate() async {
    setState(() {
      _estBusy = true;
      _estErr = null;
    });
    final r = await mutate(() => Api.estimateCost({'est_kg': numOf(_qeKg.text) ?? 0, 'material_code': _qeMat, 'distance_km': numOf(_qeKm.text) ?? 0}),
        onError: (e) => _estErr = e, toastErrors: false);
    if (!mounted) return;
    setState(() {
      _estBusy = false;
      if (r != null) _est = r;
    });
  }

  @override
  Widget build(BuildContext context) => Queries(
        queries: {'p': QDef(K.pricing, Api.pricingAssumptions), 'm': QDef(K.materials, Api.materials)},
        builder: (context, q) {
          final mats = _matItems(q.list('m'), withName: false);
          final ranked = jl(_cmp?['ranked_options']);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(title: 'Landed cost comparison', description: 'Cost per usable kilogram after expected rejection and process loss, for sourcing options you describe.'),
            const Note(
                tone: Tone.warn,
                title: 'Model estimates',
                text:
                    'The backend cost endpoints use fixed rates (generator ₹14.5–15/kg, collector ₹7.5–8/kg, 15–17% loss). They do not yet read the versioned pricing assumptions below. Treat results as indicative.'),
            const SizedBox(height: 16),
            TwoCol(
              main: Gap([
                Panel(
                  title: 'Compare options',
                  footer: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Btn('Add option',
                        icon: Icons.add,
                        small: true,
                        kind: BtnKind.outline,
                        onPressed: () => setState(() => _opts.add(_Opt('Option ${_opts.length + 1}', 'BATCH', '200', '20', 'PET')))),
                    Btn('Compare', small: true, loading: _cmpBusy, onPressed: _compare),
                  ]),
                  child: Gap([
                    for (var i = 0; i < _opts.length; i++)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(border: Border.all(color: context.c.line), borderRadius: BorderRadius.circular(6)),
                        child: RGrid(minWidth: 150, maxCols: 5, gap: 8, children: [
                          Field(label: 'Name', child: In(_opts[i].name)),
                          Field(label: 'Material', child: Sel<String>(value: _opts[i].mat, items: mats, onChanged: (v) => setState(() => _opts[i].mat = v ?? 'PET'))),
                          Field(label: 'Gross kg', child: In(_opts[i].kg, decimal: true)),
                          Field(label: 'Distance km', child: In(_opts[i].km, decimal: true)),
                          Padding(
                            padding: const EdgeInsets.only(top: 22),
                            child: Btn('Remove',
                                small: true,
                                kind: BtnKind.ghost,
                                onPressed: _opts.length <= 1
                                    ? null
                                    : () => setState(() {
                                          _opts.removeAt(i).dispose();
                                        })),
                          ),
                        ]),
                      ),
                  ], gap: 12),
                ),
                if (_cmp != null)
                  Panel(
                    title: 'Ranked by cost per usable kg',
                    flush: true,
                    footer: const SourceLine('ReLoop API · /costs/compare (model estimate)'),
                    child: DataList<J>(
                      label: 'Cost comparison',
                      rows: ranked,
                      rowKey: (r) => sn(r['name']) ?? '',
                      cols: [
                        Col<J>('n', 'Option', (r) => Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                              Text(sn(r['name']) ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                              if (identical(r, ranked.first)) const Pill('Lowest', tone: Tone.ok),
                            ])),
                        ncol<J>('g', 'Gross kg', (r) => dn(r['est_kg']), num1, sortable: false),
                        ncol<J>('u', 'Usable kg', (r) => dn(r['usable_kg']), num1, sortable: false),
                        ncol<J>('gen', 'Generator', (r) => dn(jo(r['breakdown'])?['generator']), (v) => inr(v, decimals: false), sortable: false),
                        ncol<J>('col', 'Collector', (r) => dn(jo(r['breakdown'])?['collector']), (v) => inr(v, decimals: false), sortable: false),
                        ncol<J>('tr', 'Transport', (r) => dn(jo(r['breakdown'])?['transport']), (v) => inr(v, decimals: false), sortable: false),
                        ncol<J>('t', 'Total', (r) => dn(r['total_cost']), (v) => inr(v, decimals: false), sortable: false),
                        Col<J>('l', '₹ / usable kg', (r) => numText(inr(dn(r['landed_cost_per_usable_kg'])), bold: true), numeric: true),
                      ],
                    ),
                  ),
                if (_cmpErr != null) Note(tone: Tone.bad, text: _cmpErr!.message),
              ]),
              side: Gap([
                Panel(
                  title: 'Quick estimate',
                  child: Gap([
                    RGrid(minWidth: 90, maxCols: 3, gap: 8, children: [
                      Field(label: 'Material', child: Sel<String>(value: _qeMat, items: mats, onChanged: (v) => setState(() => _qeMat = v ?? 'PET'))),
                      Field(label: 'Gross kg', child: In(_qeKg, decimal: true)),
                      Field(label: 'Km', child: In(_qeKm, decimal: true)),
                    ]),
                    Btn('Estimate', kind: BtnKind.outline, loading: _estBusy, onPressed: _estimate),
                    if (_est != null)
                      KV([
                        for (final e in (jo(_est!['breakdown']) ?? const <String, dynamic>{}).entries) KVRow(humanize(e.key), inr(dn(e.value))),
                        KVRow('Expected usable', kg(dn(_est!['expected_usable_kg']))),
                        KVRow('Total', inr(dn(_est!['total_cost'])), total: true),
                        KVRow('Per usable kg', inr(dn(_est!['landed_cost_per_usable_kg'])), total: true),
                      ]),
                    if (_estErr != null) Note(tone: Tone.bad, text: _estErr!.message),
                  ], gap: 12),
                ),
                Panel(
                  title: 'Pricing assumptions',
                  sub: 'Versioned; recorded on the platform but not yet used by the cost endpoints',
                  footer: const SourceLine('ReLoop API · /pricing-assumptions'),
                  child: qView<J>(
                    q,
                    'p',
                    (p) => KV([
                      KVRow('Version', 'v${p['version']}'),
                      KVRow('Transport per km', inr(dn(p['transport_per_km']))),
                      KVRow('Transport per kg·km', inr(dn(p['transport_per_kg_km']))),
                      KVRow('Sorting per kg', inr(dn(p['sorting_per_kg']))),
                      KVRow('Handling per kg', inr(dn(p['handling_per_kg']))),
                      KVRow('Storage per kg·day', inr(dn(p['storage_per_kg_day']))),
                      KVRow('Rejection disposal per kg', inr(dn(p['rejection_cost_per_kg']))),
                      for (final e in (jo(p['default_rejection_rate']) ?? const <String, dynamic>{}).entries)
                        KVRow('Default rejection · ${e.key}', pct((dn(e.value) ?? 0) * 100)),
                      for (final e in (jo(p['default_process_loss_rate']) ?? const <String, dynamic>{}).entries)
                        KVRow('Default process loss · ${e.key}', pct((dn(e.value) ?? 0) * 100)),
                    ]),
                  ),
                ),
              ]),
            ),
          ]);
        },
      );
}

/* ─────────────── Supply outlook ─────────────── */
/// Values the backend substitutes for zero in /forecasts/shortages.
const Map<String, double> _placeholder = {'demand': 6000, 'confirmed': 2500, 'predicted': 4800};

class RecyclerOutlook extends StatefulWidget {
  const RecyclerOutlook({super.key});
  @override
  State<RecyclerOutlook> createState() => _RecyclerOutlookState();
}

class _RecyclerOutlookState extends State<RecyclerOutlook> {
  String _mat = 'PET';
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Queries(
      queries: {
        'm': QDef(K.materials, Api.materials),
        's': QDef(K.shortage(_mat), () => Api.shortages(_mat)),
        'sf': QDef(K.supplyFc, Api.supplyForecasts),
        'df': QDef(K.demandFc, Api.demandForecasts),
        'd': QDef(K.demand, Api.demandProfiles),
      },
      builder: (context, q) {
        final mats = q.list('m');
        final matId = mats.where((m) => m['code'] == _mat).firstOrNull?['id'];
        final fcRows = q.list('sf').where((f) => f['material_category_id'] == matId).toList();
        final myDemand = q.list('d').where((d) => d['material_code'] == _mat && d['status'] == 'ACTIVE').toList();
        bool suspect(String k, double v) => v == _placeholder[k] && (k == 'demand' ? myDemand.isEmpty : (k == 'predicted' ? fcRows.isEmpty : true));
        String matCode(dynamic id) => sn(mats.where((m) => m['id'] == id).firstOrNull?['code']) ?? '—';
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHeader(
            title: 'Supply outlook',
            description: 'Requirement against confirmed supply and the forecast. Forecasts help planning; they are never counted as inventory.',
            actions: [SizedBox(width: 160, child: Sel<String>(value: _mat, items: _matItems(mats, withName: false), onChanged: (v) => setState(() => _mat = v ?? 'PET')))],
          ),
          Gap([
            qView<J>(q, 's', (s) {
              final dk = dn(s['demand_kg']) ?? 0, ck = dn(s['confirmed_supply_kg']) ?? 0, pk = dn(s['predicted_supply_kg']) ?? 0;
              final any = suspect('demand', dk) || suspect('confirmed', ck) || suspect('predicted', pk);
              Widget? mark(String k, double v) => suspect(k, v) ? const Pill('Possible placeholder', tone: Tone.warn, dot: false) : null;
              return Gap([
                if (any)
                  const Note(
                      tone: Tone.warn,
                      title: 'Some figures may be backend placeholders',
                      text:
                          "When a value is zero, the backend's shortage endpoint substitutes 6,000 kg demand, 2,500 kg confirmed or 4,800 kg predicted. Values matching these with no supporting records are marked. The backend's suggested suppliers are hard-coded names and are not shown."),
                KpiGrid([
                  Kpi(label: 'Requirement', value: kg(dk), subWidget: mark('demand', dk), sub: '${myDemand.length} active requirement${myDemand.length == 1 ? '' : 's'} of yours'),
                  Kpi(label: 'Confirmed supply', value: kg(ck), subWidget: mark('confirmed', ck), sub: 'Assigned, picked up or in transit (all recyclers)'),
                  Kpi(label: 'Gap on confirmed supply', value: kg(dn(s['gap_confirmed_kg'])), sub: 'Act on this number'),
                  Kpi(label: 'Predicted supply', value: kg(pk), subWidget: mark('predicted', pk), sub: 'Forecast, not inventory'),
                ]),
                Panel(
                  title: '$_mat: requirement vs supply',
                  footer: const SourceLine('ReLoop API · /forecasts/shortages'),
                  child: Gap([
                    Row(children: [
                      const SizedBox(width: 110, child: Text('Requirement', style: TextStyle(fontSize: 12.5))),
                      Expanded(child: SegBar([(dk, c.c6)], [dk, ck + pk].reduce((a, b) => a > b ? a : b), height: 16)),
                      SizedBox(width: 100, child: numText(kg(dk))),
                    ]),
                    Row(children: [
                      const SizedBox(width: 110, child: Text('Supply', style: TextStyle(fontSize: 12.5))),
                      Expanded(child: SegBar([(ck, c.c1), (pk, c.c3)], [dk, ck + pk].reduce((a, b) => a > b ? a : b), height: 16)),
                      SizedBox(width: 100, child: numText(kg(ck + pk))),
                    ]),
                    Wrap(spacing: 14, children: [Legend('Requirement', c.c6), Legend('Confirmed', c.c1), Legend('Predicted', c.c3)]),
                    Small('Predicted supply is stacked on confirmed supply for comparison only. Gap after prediction: ${kg(dn(s['gap_expected_kg']))}.'),
                  ], gap: 10),
                ),
              ]);
            }),
            Panel(
              title: 'Supply forecasts',
              sub: 'Rows labelled PREDICTED by the backend',
              flush: true,
              footer: const SourceLine('ReLoop API · /forecasts/supply, /forecasts/demand'),
              child: qView<List<J>>(
                q,
                'sf',
                (sf) => DataList<J>(
                  label: 'Forecasts',
                  rows: [...sf, ...q.list('df')],
                  rowKey: (f) => '${f['kind']}${f['period_start']}${f['material_category_id']}${f['locality']}${f.hashCode}',
                  emptyTitle: 'No forecasts recorded',
                  cols: [
                    Col<J>('k', 'Kind', (f) => Pill(f['kind'] == 'PREDICTED' ? 'Predicted supply' : 'Demand forecast', tone: f['kind'] == 'PREDICTED' ? Tone.info : Tone.neutral)),
                    tcol<J>('m', 'Material', (f) => matCode(f['material_category_id']), sortable: false),
                    tcol<J>('l', 'Locality', (f) => sn(f['locality']) ?? '—', sortable: false),
                    Col<J>('p', 'Period', (f) => Small('${date(f['period_start'])} – ${date(f['period_end'])}'), sort: (f) => sn(f['period_start'])),
                    ncol<J>('v', 'Predicted kg', (f) => dn(f['predicted_kg']), num0),
                    Col<J>('r', 'Range', (f) => numText(f['lower_kg'] != null ? '${num0(dn(f['lower_kg']))}–${num0(dn(f['upper_kg']))}' : '—'), numeric: true),
                    tcol<J>('c', 'Confidence', (f) => humanize(f['confidence_label']), sortable: false),
                  ],
                ),
              ),
            ),
          ]),
        ]);
      },
    );
  }
}

/* ─────────────── Receipt sheet (shared by Incoming and Receipts) ─────────────── */
class ReceiptSheet extends StatefulWidget {
  final String batchId;
  final String batchCode;
  final String material;
  final double? collected;
  final J? existing;
  const ReceiptSheet({super.key, required this.batchId, required this.batchCode, required this.material, this.collected, this.existing});
  @override
  State<ReceiptSheet> createState() => _ReceiptSheetState();
}

class _ReceiptSheetState extends State<ReceiptSheet> {
  late final TextEditingController _rec, _acc, _rej, _cont, _disp, _reason;
  String _grade = 'B';
  RegisteredDoc? _slip;
  bool _slipBusy = false;
  Map<String, String> _e = {};
  ApiError? _err;
  bool _busy = false;
  bool _rejTouched = false;

  @override
  void initState() {
    super.initState();
    final x = widget.existing;
    String s(dynamic v) => v == null ? '' : '${dn(v) ?? v}';
    _rec = TextEditingController(text: x == null ? '' : s(x['received_kg']));
    _acc = TextEditingController(text: x == null ? '' : s(x['accepted_kg']));
    _rej = TextEditingController(text: x == null ? '0' : s(x['rejected_kg']));
    _cont = TextEditingController(text: x == null ? '' : s(x['contamination_pct']));
    _disp = TextEditingController(text: sn(x?['rejection_disposition']) ?? '');
    _reason = TextEditingController();
    _grade = sn(x?['quality_grade']) ?? 'B';
  }

  @override
  void dispose() {
    for (final c in [_rec, _acc, _rej, _cont, _disp, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Rejected = received − accepted, filled in as the user types (they can still override it).
  void _autoRejected() {
    final r = numOf(_rec.text), a = numOf(_acc.text);
    if (!_rejTouched && r != null && r > 0 && a != null && a >= 0 && a <= r) {
      _rej.text = (r - a).toStringAsFixed(3).replaceFirst(RegExp(r'\.?0+$'), '');
    }
    setState(() {});
  }

  Future<void> _save() async {
    final e = <String, String>{};
    final re = kgError(_rec.text, label: 'Received weight');
    if (re != null) e['received_kg'] = re;
    final ae = kgError(_acc.text, label: 'Accepted weight', allowZero: true);
    if (ae != null) e['accepted_kg'] = ae;
    final je = kgError(_rej.text, label: 'Rejected weight', allowZero: true);
    if (je != null) e['rejected_kg'] = je;
    if (_cont.text.trim().isNotEmpty && _pct0to100(_cont.text) != null) e['contamination_pct'] = '0–100';
    if (e.isEmpty && !receiptBalances(double.parse(_rec.text), double.parse(_acc.text), double.parse(_rej.text))) {
      e['rejected_kg'] = 'Accepted + rejected must equal received';
    }
    final ex = widget.existing;
    if (ex == null && e['rejected_kg'] == null && (numOf(_rej.text) ?? 0) != 0 && _disp.text.trim().length <= 2) {
      e['rejection_disposition'] = 'Say what happens to the rejected material';
    }
    if (ex != null && _reason.text.trim().length < 5) e['reason'] = 'Give a reason for the correction';
    setState(() => _e = e);
    if (e.isNotEmpty) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final base = <String, dynamic>{
      'received_kg': double.parse(_rec.text.trim()),
      'accepted_kg': double.parse(_acc.text.trim()),
      'rejected_kg': double.parse(_rej.text.trim()),
      'quality_grade': _grade,
      'contamination_pct': numOf(_cont.text) ?? 0,
    };
    final r = await mutate(
      () => ex != null
          ? Api.correctReceipt(sn(ex['id'])!, {...base, 'reason': _reason.text.trim()})
          : Api.createReceipt({
              ...base,
              'batch_id': widget.batchId,
              'rejection_disposition': _disp.text.trim().isEmpty ? null : _disp.text.trim(),
              'document_ids': _slip == null ? <String>[] : [_slip!.id],
            }),
      invalidate: [K.batches, K.receiptsAll, K.incoming, K.consignments],
      toastErrors: false,
      success: (_) => ex != null ? 'Correction saved as a new version; the original is kept' : 'Receipt recorded',
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (_err != null) _e = {..._e, ..._err!.fieldErrors()};
    });
    if (r != null) Navigator.pop(context);
  }

  Future<void> _pickSlip() async {
    setState(() => _slipBusy = true);
    final d = await pickAndRegister(context, 'WEIGHBRIDGE_SLIP');
    if (!mounted) return;
    setState(() {
      _slipBusy = false;
      if (d != null) _slip = d;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.existing;
    final recv = numOf(_rec.text) ?? 0, acc = numOf(_acc.text) ?? 0, rej = numOf(_rej.text) ?? 0;
    final col = widget.collected;
    final transit = (col != null && col != 0 && recv > 0) ? (recv - col) / col * 100 : null;
    final processed = dn(ex?['processed_input_kg']);
    final apiFieldErrs = _err?.fieldErrors() ?? const {};
    return SheetScaffold(
      title: ex != null ? 'Correct receipt · ${widget.batchCode}' : 'Record receipt · ${widget.batchCode}',
      description: '${widget.material} · collected ${kg(col)}',
      actions: [
        Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)),
        Btn(ex != null ? 'Save as new version' : 'Save receipt', loading: _busy, onPressed: _save),
      ],
      children: [
        RGrid(minWidth: 160, maxCols: 3, gap: 16, children: [
          Field(label: 'Received (kg)', required: true, error: _e['received_kg'], child: In(_rec, decimal: true, hasError: _e['received_kg'] != null, onChanged: (_) => _autoRejected())),
          Field(label: 'Accepted (kg)', required: true, error: _e['accepted_kg'], child: In(_acc, decimal: true, hasError: _e['accepted_kg'] != null, onChanged: (_) => _autoRejected())),
          Field(
            label: 'Rejected (kg)',
            required: true,
            error: _e['rejected_kg'],
            hint: 'Received − accepted',
            child: In(_rej, decimal: true, hasError: _e['rejected_kg'] != null, onChanged: (_) => setState(() => _rejTouched = true)),
          ),
          Field(label: 'Grade', child: Sel<String>(value: _grade, items: const [('A', 'A'), ('B', 'B'), ('C', 'C')], onChanged: (v) => setState(() => _grade = v ?? 'B'))),
          Field(label: 'Contamination (%)', error: _e['contamination_pct'], child: In(_cont, decimal: true)),
          if (ex == null)
            Field(label: 'Weighbridge slip', hint: 'SHA-256 recorded', child: PhotoBox(text: _slip?.name ?? 'Attach', busy: _slipBusy, height: 40, onTap: _pickSlip)),
        ]),
        if (ex == null)
          Field(
            label: 'Rejected material goes to',
            required: rej > 0,
            error: _e['rejection_disposition'],
            child: In(_disp, placeholder: 'Co-processing / returned to collector', hasError: _e['rejection_disposition'] != null),
          ),
        if (ex != null)
          Field(label: 'Reason for correction', required: true, error: _e['reason'], child: In(_reason, maxLines: 2, placeholder: 'Re-weighed after drying', hasError: _e['reason'] != null)),
        if (recv > 0)
          receiptBalances(recv, acc, rej)
              ? Note(tone: Tone.ok, text: 'Accepted ${num1(acc)} + rejected ${num1(rej)} = received ${num1(recv)} kg.')
              : const Note(tone: Tone.bad, text: 'Accepted + rejected must equal received. The server rejects unbalanced receipts.'),
        if (transit != null && transit.abs() > 2)
          Note(
              tone: Tone.warn,
              text:
                  'Received differs from collected by ${pct(transit)}, beyond the 2% weighing tolerance. Record it as weighed; the difference stays visible to the collector and NGO reviewer.'),
        if (processed != null && processed > 0) Note(text: '${kg(processed)} of this batch is already in processing runs. Accepted cannot be corrected below that.'),
        if (_err != null && apiFieldErrs.isEmpty) Note(tone: Tone.bad, title: _err!.code == 'RECEIPT_EXISTS' ? 'Already received' : 'Not saved', text: _err!.message),
      ],
    );
  }
}

/* ─────────────── Incoming ─────────────── */
class RecyclerIncoming extends StatelessWidget {
  const RecyclerIncoming({super.key});

  @override
  Widget build(BuildContext context) => Queries(
        queries: {
          'c': QDef(K.consignments, Api.consignments),
          'i': QDef(K.incoming, Api.incoming),
          'b': QDef(K.batchList(), () => Api.batches()),
          'col': QDef(K.orgs('COLLECTOR'), () => Api.orgs('COLLECTOR')),
        },
        builder: (context, q) {
          final bs = q.list('b');
          J? batchById(dynamic id) => bs.where((b) => b['id'] == id).firstOrNull;
          String colName(dynamic id) => sn(q.list('col').where((c) => c['id'] == id).firstOrNull?['legal_name']) ?? '—';
          final pending = q
              .list('c')
              .where((c) => jl(c['items']).any((i) => ['IN_TRANSIT', 'PICKED_UP'].contains(sn(batchById(i['batch_id'])?['status']) ?? sn(i['status']))))
              .toList();
          void open(J c) => showSheet(context, _ReceiveSheet(c, colName(c['collector_org_id'])), wide: true);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(title: 'Incoming consignments', description: 'Vehicles on the way or at your gate. Each batch is weighed and inspected on its own.'),
            Gap([
              Panel(
                title: 'Consignments to receive',
                flush: true,
                footer: const SourceLine('ReLoop API · /consignments, /recycler/incoming'),
                child: qView<List<J>>(
                  q,
                  'c',
                  (_) => DataList<J>(
                    label: 'Consignments to receive',
                    rows: pending,
                    rowKey: (c) => sn(c['id'])!,
                    onTap: open,
                    sortKey: 'd',
                    sortAsc: false,
                    emptyTitle: 'Nothing incoming',
                    emptyBody: 'Consignments that collectors dispatch to you appear here.',
                    cols: [
                      Col<J>('c', 'Consignment', (c) => Mono(sn(c['consignment_code']) ?? '', size: 12)),
                      tcol<J>('col', 'Collector', (c) => colName(c['collector_org_id']), sortable: false),
                      Col<J>('d', 'Dispatched', (c) => Small(dateTime(c['dispatched_at'])), sort: (c) => sn(c['dispatched_at'])),
                      Col<J>('n', 'Batches', (c) => numText('${jl(c['items']).length}'), numeric: true),
                      Col<J>(
                          'kg',
                          'Collected kg',
                          (c) => numText(num1(jl(c['items']).fold<double>(0, (s, i) {
                                final b = batchById(i['batch_id']);
                                return s + (b == null ? 0 : (bq(b, 'collected_kg') ?? 0));
                              }))),
                          numeric: true),
                      Col<J>('s', 'Status', (c) => StatusPill(consStatus(c), kConsStatus)),
                      Col<J>('x', '', (c) => consStatus(c) == 'IN_TRANSIT' ? _ArriveButton(sn(c['id'])!) : Btn('Receive batches', small: true, onPressed: () => open(c))),
                    ],
                  ),
                ),
              ),
              Panel(
                title: 'Batches destined for you',
                sub: 'From /recycler/incoming',
                flush: true,
                child: qView<List<J>>(
                  q,
                  'i',
                  (inc) => DataList<J>(
                    label: 'Incoming batches',
                    rows: inc,
                    rowKey: (b) => sn(b['batch_id'])!,
                    emptyTitle: 'No batches in transit to you',
                    cols: [
                      Col<J>('c', 'Batch', (b) => BatchLink(sn(b['batch_code']) ?? '')),
                      tcol<J>('l', 'From', (b) => sn(b['locality']) ?? '—', sortable: false),
                      ncol<J>('e', 'Listed kg', (b) => dn(b['estimated_kg']), num1, sortable: false),
                      ncol<J>('col', 'Collected kg', (b) {
                        final x = batchById(b['batch_id']);
                        return x == null ? null : bq(x, 'collected_kg');
                      }, num1, sortable: false),
                      Col<J>('s', 'Status', (b) => BatchStatusPill(sn(b['status']))),
                    ],
                  ),
                ),
              ),
            ]),
          ]);
        },
      );
}

class _ArriveButton extends StatefulWidget {
  final String id;
  const _ArriveButton(this.id);
  @override
  State<_ArriveButton> createState() => _ArriveButtonState();
}

class _ArriveButtonState extends State<_ArriveButton> {
  bool _busy = false;
  @override
  Widget build(BuildContext context) => Btn('Mark arrived', small: true, kind: BtnKind.outline, loading: _busy, onPressed: () async {
        setState(() => _busy = true);
        await mutate(() => Api.markArrived(widget.id), invalidate: [K.consignments], success: (_) => 'Marked as arrived');
        if (mounted) setState(() => _busy = false);
      });
}

/// Receive one consignment: each batch gets its own receipt.
class _ReceiveSheet extends StatelessWidget {
  final J initial;
  final String collector;
  const _ReceiveSheet(this.initial, this.collector);

  @override
  Widget build(BuildContext context) => Queries(
        queries: {'c': QDef(K.consignments, Api.consignments), 'b': QDef(K.batchList(), () => Api.batches())},
        builder: (context, q) {
          final cons = q.list('c').where((x) => x['id'] == initial['id']).firstOrNull ?? initial;
          final bs = q.list('b');
          final arrived = cons['status'] == 'ARRIVED';
          return SheetScaffold(
            title: 'Receive ${cons['consignment_code']}',
            description: collector,
            children: [
              ConsignmentDetail(consignment: cons),
              Panel(
                title: 'Record receipts',
                child: Gap([
                  for (final it in jl(cons['items']))
                    () {
                      final b = bs.where((x) => x['id'] == it['batch_id']).firstOrNull;
                      final done = b != null && bq(b, 'received_kg') != null;
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(border: Border.all(color: context.c.line), borderRadius: BorderRadius.circular(6)),
                        child: Wrap(alignment: WrapAlignment.spaceBetween, crossAxisAlignment: WrapCrossAlignment.center, spacing: 8, runSpacing: 6, children: [
                          Text.rich(TextSpan(children: [
                            TextSpan(text: sn(it['batch_code']) ?? '', style: mono(context, size: 12.5)),
                            TextSpan(text: ' · ${b?['material'] ?? ''} · collected ${kg(b == null ? null : bq(b, 'collected_kg'))}'),
                          ]), style: const TextStyle(fontSize: 13)),
                          done
                              ? Pill('Received ${kg(bq(b, 'received_kg'))}', tone: Tone.ok)
                              : Btn('Record receipt',
                                  small: true,
                                  tooltip: arrived ? null : 'Mark the consignment as arrived first',
                                  onPressed: (b == null || !arrived)
                                      ? null
                                      : () => showSheet(
                                            context,
                                            ReceiptSheet(batchId: sn(b['id'])!, batchCode: bcode(b), material: sn(b['material']) ?? '', collected: bq(b, 'collected_kg')),
                                          )),
                        ]),
                      );
                    }(),
                  if (!arrived) const Note(text: 'Mark the consignment as arrived before recording receipts.'),
                ], gap: 8),
              ),
            ],
          );
        },
      );
}

/* ─────────────── Receipts ─────────────── */
class RecyclerReceipts extends StatefulWidget {
  const RecyclerReceipts({super.key});
  @override
  State<RecyclerReceipts> createState() => _RecyclerReceiptsState();
}

class _RecyclerReceiptsState extends State<RecyclerReceipts> {
  bool _history = false;
  @override
  Widget build(BuildContext context) => Queries(
        queries: {'r': QDef(K.receipts(_history), () => Api.receipts(_history)), 'b': QDef(K.batchList(), () => Api.batches())},
        builder: (context, q) {
          J? batchOf(J r) => q.list('b').where((b) => b['id'] == r['batch_id']).firstOrNull;
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              title: 'Material receipts',
              description: 'Weights and inspection results recorded at your gate. A correction creates a new version and keeps the original.',
              actions: [CheckLine(value: _history, label: 'Show superseded versions', onChanged: (v) => setState(() => _history = v))],
            ),
            Panel(
              flush: true,
              footer: const Foot('ReLoop API · /recycler/receipts', note: 'Rule: accepted + rejected = received (enforced by the server).'),
              child: qView<List<J>>(
                q,
                'r',
                (rs) => DataList<J>(
                  label: 'Receipts',
                  rows: rs,
                  rowKey: (r) => sn(r['id'])!,
                  sortKey: 'd',
                  sortAsc: false,
                  search: (r) => sn(r['batch_code']) ?? '',
                  searchHint: 'Search batch',
                  dim: (r) => r['is_current'] != true,
                  filters: [
                    Flt<J>('m', 'Material', {for (final r in rs) sn(r['material_code']) ?? ''}.map((m) => (m, m)).toList(), (r) => sn(r['material_code']) ?? ''),
                    Flt<J>('g', 'Grade', const [('A', 'A'), ('B', 'B'), ('C', 'C')], (r) => sn(r['quality_grade']) ?? ''),
                  ],
                  emptyTitle: 'No receipts yet',
                  emptyBody: 'Receipts are recorded from incoming consignments.',
                  emptyAction: Btn('Incoming', small: true, onPressed: () => go('/r/incoming')),
                  cols: [
                    Col<J>('c', 'Batch', (r) => BatchLink(sn(r['batch_code']) ?? ''), sort: (r) => sn(r['batch_code'])),
                    tcol<J>('m', 'Material', (r) => sn(r['material_code']) ?? '', sortable: false),
                    Col<J>('d', 'Received', (r) => Small(dateTime(r['received_at'])), sort: (r) => sn(r['received_at'])),
                    ncol<J>('col', 'Collected', (r) {
                      final b = batchOf(r);
                      return b == null ? null : bq(b, 'collected_kg');
                    }, num1, sortable: false),
                    ncol<J>('rec', 'Received kg', (r) => dn(r['received_kg']), num1),
                    ncol<J>('a', 'Accepted', (r) => dn(r['accepted_kg']), num1),
                    ncol<J>('x', 'Rejected', (r) => dn(r['rejected_kg']), num1),
                    tcol<J>('g', 'Grade', (r) => '${r['quality_grade']} · ${pct(dn(r['contamination_pct']))}', sortable: false),
                    Col<J>('v', 'Version', (r) => Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('v${r['version']} '),
                          r['is_current'] == true ? const Pill('Current', tone: Tone.ok) : const Pill('Superseded'),
                        ])),
                    ncol<J>('av', 'Not yet processed', (r) => dn(r['available_kg']), num1),
                    Col<J>(
                      'z',
                      '',
                      (r) => r['is_current'] == true
                          ? Btn('Correct', small: true, kind: BtnKind.ghost, onPressed: () {
                              final b = batchOf(r);
                              showSheet(
                                context,
                                ReceiptSheet(
                                  batchId: sn(r['batch_id'])!,
                                  batchCode: sn(r['batch_code']) ?? '',
                                  material: sn(r['material_code']) ?? '',
                                  collected: b == null ? null : bq(b, 'collected_kg'),
                                  existing: r,
                                ),
                              );
                            })
                          : const SizedBox.shrink(),
                    ),
                  ],
                  footer: (rows) {
                    final cur = rows.where((r) => r['is_current'] == true).toList();
                    return [
                      FootItem('Current versions (${cur.length})', ''),
                      FootItem('Received', num1(_sum(cur, 'received_kg'))),
                      FootItem('Accepted', num1(_sum(cur, 'accepted_kg'))),
                      FootItem('Rejected', num1(_sum(cur, 'rejected_kg'))),
                      FootItem('Not yet processed', num1(_sum(cur, 'available_kg'))),
                    ];
                  },
                ),
              ),
            ),
          ]);
        },
      );
}

/* ─────────────── Processing runs ─────────────── */
class RunsTable extends StatelessWidget {
  final List<J> rows;
  final void Function(J run) onOpen;
  const RunsTable(this.rows, {super.key, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return DataList<J>(
      label: 'Processing runs',
      rows: rows,
      rowKey: (r) => sn(r['id'])!,
      onTap: onOpen,
      sortKey: 'd',
      sortAsc: false,
      emptyTitle: 'No processing runs yet',
      cols: [
        Col<J>('c', 'Run', (r) => Mono(sn(r['record_code']) ?? '', size: 12), sort: (r) => sn(r['record_code'])),
        Col<J>('d', 'Started', (r) => Small(dateTime(r['run_started_at'])), sort: (r) => sn(r['run_started_at'])),
        tcol<J>('m', 'Material', (r) => sn(r['material_code']) ?? '', sortable: false),
        ncol<J>('i', 'Input', (r) => dn(r['input_kg']), num1),
        ncol<J>('o', 'Output', (r) => dn(r['output_kg']), num1),
        ncol<J>('res', 'Residue', (r) => dn(r['residue_kg']), num1, sortable: false),
        ncol<J>('y', 'Yield', (r) => dn(r['yield_pct']), pct),
        Col<J>('u', 'Unaccounted', (r) {
          final u = _unaccPct(r);
          return numText(pct(u), bold: (u ?? 0) > 3, color: (u ?? 0) > 3 ? c.bad : null);
        }, numeric: true, sort: (r) => _unaccPct(r)),
        ncol<J>('e', 'Eligible', (r) => dn(r['eligible_kg']), num1, sortable: false),
        ncol<J>('a', 'Allocated', (r) => dn(r['allocated_kg']), num1, sortable: false),
        Col<J>('f', 'Free', (r) => numText(num1(dn(r['available_kg'])), bold: true), numeric: true, sort: (r) => dn(r['available_kg'])),
      ],
    );
  }
}

class _RunSheet extends StatefulWidget {
  const _RunSheet();
  @override
  State<_RunSheet> createState() => _RunSheetState();
}

class _RunSheetState extends State<_RunSheet> {
  String? _mat;
  DateTime _start = DateTime.now().subtract(const Duration(hours: 4));
  DateTime _end = DateTime.now();
  final Map<String, bool> _use = {};
  final Map<String, TextEditingController> _inKg = {};
  final _out = TextEditingController();
  final _res = TextEditingController();
  final _elig = TextEditingController();
  final _form = TextEditingController(text: 'flakes');
  final _basis = TextEditingController();
  Map<String, String> _e = {};
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [_out, _res, _elig, _form, _basis, ..._inKg.values]) {
      c.dispose();
    }
    super.dispose();
  }

  TextEditingController _ctl(J r) => _inKg.putIfAbsent(sn(r['id'])!, () => TextEditingController(text: '${dn(r['available_kg']) ?? ''}'));

  Future<void> _save(List<J> avail) async {
    final rows = avail.where((r) => r['material_code'] == _mat).toList();
    final used = rows.where((r) => _use[r['id']] == true).toList();
    final e = <String, String>{};
    if (_mat == null) e['material'] = 'Choose a material';
    if (_end.isBefore(_start)) e['end'] = 'End must be after start';
    if (used.isEmpty) {
      e['inputs'] = 'Select at least one receipt as input';
    } else {
      for (final r in used) {
        final n = numOf(_ctl(r).text);
        final max = dn(r['available_kg']) ?? 0;
        if (n == null || n <= 0) {
          e['inputs'] = 'Enter kg for each selected input';
        } else if (n > max + 0.0005) {
          e['inputs'] = 'An input exceeds its available ${num1(max)} kg';
        }
      }
    }
    for (final (k, ctl, label) in [('output', _out, 'Output'), ('residue', _res, 'Residue'), ('eligible', _elig, 'Eligible')]) {
      final err = kgError(ctl.text, label: label, allowZero: true);
      if (err != null) e[k] = err;
    }
    final input = used.fold<double>(0, (s, r) => s + (numOf(_ctl(r).text) ?? 0));
    if (e['output'] == null && e['residue'] == null && (numOf(_out.text)! + numOf(_res.text)!) > input + 0.001) {
      e['residue'] = 'Output + residue cannot exceed input (${num1(input)} kg)';
    }
    if (e['eligible'] == null && e['output'] == null && numOf(_elig.text)! > numOf(_out.text)! + 0.001) e['eligible'] = 'Eligible cannot exceed measured output';
    setState(() => _e = e);
    if (e.isNotEmpty) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.createProcessing({
        'material_code': _mat,
        'run_started_at': toIsoUtc(_start),
        'run_ended_at': toIsoUtc(_end),
        'inputs': [
          for (final r in used) {'recycler_receipt_id': r['id'], 'input_kg': numOf(_ctl(r).text)},
        ],
        'output_kg': numOf(_out.text),
        'residue_kg': numOf(_res.text),
        'eligible_kg': numOf(_elig.text),
        'output_form': _form.text.trim().isEmpty ? null : _form.text.trim(),
        'eligibility_basis': _basis.text.trim().isEmpty ? null : _basis.text.trim(),
      }),
      invalidate: [K.processing, K.receiptsAll, K.batches, K.yieldKey, K.capacity, K.verifications],
      toastErrors: false,
      success: (d) => '${d['record_code']} recorded: yield ${pct(dn(d['yield_pct']))}. Batches queued for NGO review.',
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => Queries(
        queries: {'r': QDef(K.receipts(), () => Api.receipts()), 'm': QDef(K.materials, Api.materials)},
        builder: (context, q) {
          final avail = q.list('r').where((r) => r['is_current'] == true && (dn(r['available_kg']) ?? 0) > 0.0005).toList();
          final mats = {for (final r in avail) sn(r['material_code'])!}.toList();
          String matName(String c) => sn(q.list('m').where((m) => m['code'] == c).firstOrNull?['name']) ?? '';
          final rows = avail.where((r) => r['material_code'] == _mat).toList();
          final input = rows.where((r) => _use[r['id']] == true).fold<double>(0, (s, r) => s + (numOf(_ctl(r).text) ?? 0));
          final out = numOf(_out.text), res = numOf(_res.text);
          final un = (out != null && res != null) ? input - out - res : null;
          final c = context.c;
          return SheetScaffold(
            title: 'Record processing run',
            description: 'Select accepted stock used as input and enter measured quantities. Only your organisation can record processing outcomes.',
            actions: [Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)), Btn('Save run', loading: _busy, onPressed: () => _save(avail))],
            children: [
              RGrid(minWidth: 200, maxCols: 3, gap: 16, children: [
                Field(
                  label: 'Material',
                  required: true,
                  error: _e['material'],
                  hint: 'A run processes one material',
                  child: Sel<String>(
                    value: _mat,
                    placeholder: q.pending('r') ? 'Loading…' : (mats.isEmpty ? 'No unprocessed stock' : 'Select'),
                    items: [for (final m in mats) (m, '$m · ${matName(m)}')],
                    onChanged: (v) => setState(() => _mat = v),
                  ),
                ),
                Field(label: 'Started', required: true, child: DateTimeIn(value: _start, onChanged: (d) => setState(() => _start = d))),
                Field(label: 'Ended', required: true, error: _e['end'], child: DateTimeIn(value: _end, hasError: _e['end'] != null, onChanged: (d) => setState(() => _end = d))),
              ]),
              if (_mat != null)
                Container(
                  decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(6)),
                  child: rows.isEmpty
                      ? Padding(padding: const EdgeInsets.all(16), child: Small('No unprocessed accepted stock for $_mat.', size: 13))
                      : MiniTable(
                          headers: const ['Use', 'Batch', 'Accepted', 'Available', 'Input kg'],
                          numeric: const {2, 3, 4},
                          rows: [
                            for (final r in rows)
                              [
                                Checkbox(
                                  value: _use[r['id']] == true,
                                  semanticLabel: 'Use ${r['batch_code']}',
                                  onChanged: (v) => setState(() => _use[sn(r['id'])!] = v ?? false),
                                ),
                                Mono(sn(r['batch_code']) ?? '', size: 12),
                                numText(num1(dn(r['accepted_kg']))),
                                numText(num1(dn(r['available_kg']))),
                                SizedBox(
                                  width: 110,
                                  child: In(_ctl(r), decimal: true, align: TextAlign.right, enabled: _use[r['id']] == true, onChanged: (_) => setState(() {})),
                                ),
                              ],
                          ],
                        ),
                ),
              if (_e['inputs'] != null) Text(_e['inputs']!, style: TextStyle(fontSize: 12, color: c.bad)),
              RGrid(minWidth: 180, maxCols: 4, gap: 16, children: [
                Field(label: 'Total input', child: In(TextEditingController(text: '${num1(input)} kg'), readOnly: true)),
                Field(label: 'Recovered output (kg)', required: true, error: _e['output'], child: In(_out, decimal: true, hasError: _e['output'] != null, onChanged: (_) => setState(() {}))),
                Field(label: 'Residue (kg)', required: true, error: _e['residue'], child: In(_res, decimal: true, hasError: _e['residue'] != null, onChanged: (_) => setState(() {}))),
                Field(
                  label: 'Declared EPR-eligible (kg)',
                  required: true,
                  error: _e['eligible'],
                  hint: 'Your declaration; ≤ output',
                  child: In(_elig, decimal: true, hasError: _e['eligible'] != null),
                ),
                Field(label: 'Output form', child: In(_form)),
                Field(label: 'Eligibility basis', child: In(_basis, placeholder: 'e.g. Recycler declaration; CPCB certificate pending')),
              ]),
              if (input > 0 && un != null)
                un < -0.001
                    ? const Note(tone: Tone.bad, text: 'Output + residue exceeds input.')
                    : Note(
                        tone: un / input > 0.03 ? Tone.warn : Tone.ok,
                        text:
                            'Yield ${pct(out! / input * 100)} · unaccounted ${kg(un)} (${pct(un / input * 100)} of input)${un / input > 0.03 ? '. Above the 3% guideline: the NGO reviewer will see this. The backend does not raise a flag automatically.' : '.'}'),
              const Note(text: 'The backend requires measured output; there is no "incomplete measurement" mode. Record the run once output and residue are weighed.'),
              if (_err != null)
                Note(
                  tone: Tone.bad,
                  title: _err!.code == 'INPUT_EXCEEDS_AVAILABLE' ? 'Input exceeds available stock' : (_err!.code == 'MATERIAL_MISMATCH' ? 'Material mismatch' : 'Run not saved'),
                  text: _err!.message,
                ),
            ],
          );
        },
      );
}

class _CertificateSheet extends StatefulWidget {
  final J run;
  const _CertificateSheet(this.run);
  @override
  State<_CertificateSheet> createState() => _CertificateSheetState();
}

class _CertificateSheetState extends State<_CertificateSheet> {
  final _ref = TextEditingController();
  late final _kg = TextEditingController(text: '${dn(widget.run['eligible_kg']) ?? ''}');
  String _cat = 'CAT_I';
  DateTime _on = DateTime.now();
  Map<String, String> _e = {};
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    _ref.dispose();
    _kg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final out = dn(widget.run['output_kg']) ?? 0;
    final e = <String, String>{};
    if (_ref.text.trim().length < 3) e['ref'] = 'Enter the reference';
    final k = kgError(_kg.text, label: 'Quantity');
    if (k != null) {
      e['kg'] = k;
    } else if (double.parse(_kg.text.trim()) > out + 0.001) {
      e['kg'] = 'Cannot exceed run output ${num1(out)} kg';
    }
    setState(() => _e = e);
    if (e.isNotEmpty) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.addCertificate(sn(widget.run['id'])!, {
        'certificate_ref': _ref.text.trim(),
        'packaging_category': _cat,
        'certificate_kg': double.parse(_kg.text.trim()),
        'issued_on': _on.toIso8601String().substring(0, 10),
      }),
      invalidate: [K.batches, K.eprCerts],
      toastErrors: false,
      success: (_) => 'Certificate reference recorded',
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'Record certificate reference · ${widget.run['record_code']}',
        description: 'Enter a certificate generated on the CPCB EPR portal. ReLoop records the reference; it does not issue or validate certificates.',
        actions: [Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)), Btn('Record reference', loading: _busy, onPressed: _save)],
        children: [
          RGrid(minWidth: 220, maxCols: 2, gap: 16, children: [
            Field(label: 'Certificate reference', required: true, error: _e['ref'], child: In(_ref, monoFont: true, hasError: _e['ref'] != null)),
            Field(label: 'Packaging category', child: Sel<String>(value: _cat, items: kCategoryLabel.entries.map((e) => (e.key, e.value)).toList(), onChanged: (v) => setState(() => _cat = v ?? 'CAT_I'))),
            Field(label: 'Quantity (kg)', required: true, error: _e['kg'], child: In(_kg, decimal: true, hasError: _e['kg'] != null)),
            Field(label: 'Issued on', child: DateTimeIn(value: _on, dateOnly: true, onChanged: (d) => setState(() => _on = d))),
          ]),
          if (_err != null) Note(tone: Tone.bad, title: _err!.code == 'DUPLICATE_CERTIFICATE_REF' ? 'Reference already recorded' : 'Not recorded', text: _err!.message),
        ],
      );
}

class RecyclerRuns extends StatelessWidget {
  const RecyclerRuns({super.key});

  void _open(BuildContext context, J r) {
    final inp = dn(r['input_kg']) ?? 0;
    showSheet(
      context,
      Builder(
        builder: (ctx) => SheetScaffold(
          title: 'Run ${r['record_code']}',
          description: '${r['material_code']} · ${dateTime(r['run_started_at'])}',
          actions: [
            Btn('Record certificate reference', kind: BtnKind.outline, onPressed: () {
              Navigator.pop(ctx);
              showSheet(context, _CertificateSheet(r));
            }),
            Btn('Allocate to EPR client', onPressed: () {
              Navigator.pop(ctx);
              go('/r/allocations');
            }),
          ],
          children: [
            KpiGrid([
              Kpi(label: 'Input', value: kg(inp)),
              Kpi(label: 'Recovered output', value: kg(dn(r['output_kg']))),
              Kpi(label: 'Residue', value: kg(dn(r['residue_kg']))),
              Kpi(label: 'Unaccounted', value: kg(_unacc(r)), sub: pct(_unaccPct(r))),
            ]),
            Panel(
              title: 'EPR attribution',
              child: KV([
                KVRow('Recovered output', kg(dn(r['output_kg']))),
                KVRow('Declared EPR-eligible', kg(dn(r['eligible_kg']))),
                KVRow('Allocated to clients', kg(dn(r['allocated_kg']))),
                KVRow('Free to allocate', kg(dn(r['available_kg'])), total: true),
                KVRow('Measurement', humanize(r['measurement_status'])),
              ]),
            ),
            const Note(text: "Source batches and their share of this run are listed on each batch's passport. The backend does not expose a per-run input list to this screen."),
          ],
        ),
      ),
      wide: true,
    );
  }

  @override
  Widget build(BuildContext context) => Queries(
        queries: {'p': QDef(K.processing, Api.processing), 'r': QDef(K.receipts(), () => Api.receipts())},
        builder: (context, q) {
          final stock = _sum(q.list('r'), 'available_kg');
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              title: 'Processing runs',
              description: 'Measured input, recovered output and residue for each run. Yield and unaccounted mass are calculated by the server.',
              actions: [Btn('Record processing run', icon: Icons.add, onPressed: q.has('r') ? () => showSheet(context, const _RunSheet(), wide: true) : null)],
            ),
            Gap([
              if (q.has('r') && stock <= 0) const Note(text: 'No accepted stock is waiting for processing. Receive a consignment first.'),
              Panel(
                flush: true,
                footer: const Foot('ReLoop API · /recycler/processing-records', note: 'Yield = output ÷ input. Unaccounted = input − output − residue; above 3% is highlighted.'),
                child: qView<List<J>>(q, 'p', (rs) => RunsTable(rs, onOpen: (r) => _open(context, r))),
              ),
            ]),
          ]);
        },
      );
}

/* ─────────────── Yield ─────────────── */
class RecyclerYield extends StatelessWidget {
  const RecyclerYield({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'Material yield', description: 'Measured yield, residue and unaccounted mass by run.'),
      QueryView<J>(
        qk: K.yieldKey,
        fetch: Api.yieldAnalytics,
        emptyTitle: 'No measured runs yet',
        isEmpty: (d) => (dn(d['completed_runs_count']) ?? 0) == 0,
        builder: (context, d) {
          final rows = jl(d['completed_runs']);
          final mats = {for (final r in rows) sn(r['material']) ?? ''}.toList();
          return Gap([
            KpiGrid([
              Kpi(label: 'Average run yield', value: pct(dn(d['average_yield_pct'])), sub: '${d['completed_runs_count']} measured runs (unweighted)'),
              for (final m in mats.take(2))
                () {
                  final x = rows.where((r) => r['material'] == m);
                  final i = _sum(x, 'input_kg');
                  return Kpi(label: '$m yield (weighted)', value: pct(i != 0 ? _sum(x, 'output_kg') / i * 100 : null), sub: '${kg(i)} input');
                }(),
              Kpi(label: 'Runs above 3% unaccounted', value: '${rows.where((r) => (_unaccPct(r) ?? 0) > 3).length}'),
            ]),
            Panel(
              title: 'Mass balance by run',
              sub: 'kg · full bar = measured input',
              footer: const SourceLine('ReLoop API · /yield'),
              child: BarChart(
                stacked: true,
                labels: [for (final r in rows) shortCode(sn(r['record_code']) ?? '')],
                series: [
                  Series('Recovered output', c.c1, [for (final r in rows) dn(r['output_kg']) ?? 0]),
                  Series('Residue', c.c4, [for (final r in rows) dn(r['residue_kg']) ?? 0]),
                  Series('Unaccounted', c.c5, [for (final r in rows) _unacc(r)]),
                ],
              ),
            ),
            Panel(
              flush: true,
              child: DataList<J>(
                label: 'Yield by run',
                rows: rows,
                rowKey: (r) => sn(r['record_code'])!,
                cols: [
                  Col<J>('c', 'Run', (r) => Mono(sn(r['record_code']) ?? '', size: 12)),
                  tcol<J>('m', 'Material', (r) => sn(r['material']) ?? '', sortable: false),
                  ncol<J>('i', 'Input', (r) => dn(r['input_kg']), num1, sortable: false),
                  ncol<J>('o', 'Output', (r) => dn(r['output_kg']), num1, sortable: false),
                  ncol<J>('r', 'Residue', (r) => dn(r['residue_kg']), num1, sortable: false),
                  ncol<J>('u', 'Unaccounted', _unacc, num1, sortable: false),
                  ncol<J>('y', 'Yield', (r) => dn(r['yield_pct']), pct),
                  Col<J>('mb', 'Mass balance', (r) {
                    final u = _unaccPct(r) ?? 0;
                    return u > 3 ? Pill('${pct(u)} above 3%', tone: Tone.bad) : Pill(pct(u), tone: Tone.ok);
                  }),
                ],
              ),
            ),
          ]);
        },
      ),
    ]);
  }
}

/* ─────────────── EPR allocations ─────────────── */
class _AllocateSheet extends StatefulWidget {
  final List<J> runs;
  const _AllocateSheet(this.runs);
  @override
  State<_AllocateSheet> createState() => _AllocateSheetState();
}

class _AllocateSheetState extends State<_AllocateSheet> {
  late String? _run = sn(widget.runs.where((r) => (dn(r['available_kg']) ?? 0) > 0).firstOrNull?['id']);
  String? _client;
  String _cat = 'CAT_I';
  final _period = TextEditingController(text: currentReportingPeriod());
  final _kg = TextEditingController();
  Map<String, String> _e = {};
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    _period.dispose();
    _kg.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final e = <String, String>{};
    if (_run == null) e['run'] = 'Choose a run';
    if (_client == null) e['client'] = 'Choose an EPR client';
    if (!RegExp(r'^FY\d{4}-\d{2}$').hasMatch(_period.text.trim())) e['period'] = 'Format FY2026-27';
    final k = kgError(_kg.text, label: 'Quantity');
    if (k != null) e['kg'] = k;
    setState(() => _e = e);
    if (e.isNotEmpty) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    // The quantity is sent exactly as entered. A 409 is shown with the server's figures; it is never retried with a smaller amount.
    final r = await mutate(
      () => Api.createAllocation({
        'processing_record_id': _run,
        'epr_org_id': _client,
        'packaging_category': _cat,
        'reporting_period': _period.text.trim(),
        'quantity_kg': double.parse(_kg.text.trim()),
      }),
      invalidate: [K.allocations, K.processing, K.batches, K.epr],
      toastErrors: false,
      success: (d) => '${kg(dn(d['quantity_kg']))} allocated. ${kg(dn(d['remaining_available_kg']))} remains free on this run.',
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final run = widget.runs.where((r) => r['id'] == _run).firstOrNull;
    final det = _err?.code == 'ALLOCATION_EXCEEDS_AVAILABLE' ? jo(_err!.details) : null;
    return SheetScaffold(
      title: 'Allocate to an EPR client',
      description: 'Records a contractual attribution of your declared eligible output. The client files its own returns on the CPCB portal.',
      actions: [Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)), Btn('Allocate', loading: _busy, onPressed: _save)],
      children: [
        QueryView<List<J>>(
          qk: K.orgs('EPR_CLIENT'),
          fetch: () => Api.orgs('EPR_CLIENT'),
          builder: (context, clients) => RGrid(minWidth: 220, maxCols: 2, gap: 16, children: [
            Field(
              label: 'From run',
              required: true,
              error: _e['run'],
              child: Sel<String>(
                value: _run,
                placeholder: 'Select run',
                hasError: _e['run'] != null,
                disabled: (id) => (dn(widget.runs.where((r) => r['id'] == id).firstOrNull?['available_kg']) ?? 0) <= 0,
                items: [for (final r in widget.runs) (sn(r['id'])!, '${r['record_code']} · ${r['material_code']} · ${kg(dn(r['available_kg']))} free')],
                onChanged: (v) => setState(() => _run = v),
              ),
            ),
            Field(
              label: 'EPR client',
              required: true,
              error: _e['client'],
              hint: 'Approved EPR companies from the ReLoop directory',
              child: Sel<String>(
                value: _client,
                placeholder: 'Select client',
                hasError: _e['client'] != null,
                items: [for (final c in clients) (sn(c['id'])!, sn(c['legal_name']) ?? '')],
                onChanged: (v) => setState(() => _client = v),
              ),
            ),
            Field(label: 'Packaging category', child: Sel<String>(value: _cat, items: kCategoryLabel.entries.map((e) => (e.key, e.value)).toList(), onChanged: (v) => setState(() => _cat = v ?? 'CAT_I'))),
            Field(label: 'Reporting period', error: _e['period'], child: In(_period, hasError: _e['period'] != null)),
            Field(
              label: 'Quantity (kg)',
              required: true,
              error: _e['kg'],
              hint: run != null ? '${kg(dn(run['available_kg']))} free of ${kg(dn(run['eligible_kg']))} declared eligible' : null,
              child: In(_kg, decimal: true, hasError: _e['kg'] != null),
            ),
          ]),
        ),
        if (det != null)
          Note(
            tone: Tone.bad,
            title: 'Allocation refused: it would double-count output',
            text:
                '${_err!.message}. Declared eligible ${det['eligible_kg']} kg, already allocated ${det['allocated_kg']} kg, available ${det['available_kg']} kg. Nothing was saved. Enter a quantity within the available amount or choose another run.',
          ),
        if (_err != null && det == null) Note(tone: Tone.bad, text: _err!.message),
        const Note(text: 'NGO verification status does not change what can be allocated. The client sees which share of its allocation comes from verified batches.'),
      ],
    );
  }
}

class _ReverseSheet extends StatefulWidget {
  final J a;
  final String client;
  final String run;
  const _ReverseSheet(this.a, this.client, this.run);
  @override
  State<_ReverseSheet> createState() => _ReverseSheetState();
}

class _ReverseSheetState extends State<_ReverseSheet> {
  final _reason = TextEditingController();
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.reverseAllocation(sn(widget.a['id'])!, _reason.text.trim()),
      invalidate: [K.allocations, K.processing, K.batches, K.epr],
      success: (_) => 'Allocation reversed; a reversal entry was added',
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'Reverse allocation?',
        description: '${kg(dn(widget.a['quantity_kg']))} to ${widget.client} from ${widget.run}',
        actions: [
          Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)),
          Btn('Reverse allocation', kind: BtnKind.destructive, loading: _busy, onPressed: _reason.text.trim().length < 5 ? null : _go),
        ],
        children: [
          const Note(tone: Tone.warn, text: 'The original entry stays in the ledger as reversed and a reversal entry is added. The quantity becomes free again.'),
          Field(label: 'Reason', required: true, hint: 'At least 5 characters', child: In(_reason, maxLines: 2, placeholder: 'Client contract amended', onChanged: (_) => setState(() {}))),
          if (_err != null) Note(tone: Tone.bad, text: _err!.message),
        ],
      );
}

class RecyclerAllocations extends StatelessWidget {
  const RecyclerAllocations({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {
          'a': QDef(K.allocations, Api.allocations),
          'p': QDef(K.processing, Api.processing),
          'c': QDef(K.orgs('EPR_CLIENT'), () => Api.orgs('EPR_CLIENT')),
        },
        builder: (context, q) {
          final runs = q.list('p');
          String runCode(dynamic id) => sn(runs.where((r) => r['id'] == id).firstOrNull?['record_code']) ?? (sn(id) ?? '').padRight(8).substring(0, 8);
          String client(dynamic id) => sn(q.list('c').where((c) => c['id'] == id).firstOrNull?['legal_name']) ?? (sn(id) ?? '').padRight(8).substring(0, 8);
          final canAllocate = runs.any((r) => (dn(r['available_kg']) ?? 0) > 0);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              title: 'EPR allocation records',
              description: 'Attribute your declared EPR-eligible output to client companies. The server refuses any allocation that would exceed what is available.',
              actions: [Btn('Allocate', icon: Icons.link, onPressed: canAllocate ? () => showSheet(context, _AllocateSheet(runs)) : null)],
            ),
            TabsView([
              (
                'Allocation ledger',
                () => Gap([
                      KpiGrid([
                        Kpi(label: 'Declared eligible', value: kg(_sum(runs, 'eligible_kg'))),
                        Kpi(label: 'Allocated', value: kg(_sum(runs, 'allocated_kg'))),
                        Kpi(label: 'Free to allocate', value: kg(_sum(runs, 'available_kg'))),
                        Kpi(label: 'Active entries', value: '${q.list('a').where((a) => a['status'] == 'ACTIVE').length}'),
                      ]),
                      Panel(
                        flush: true,
                        footer: const SourceLine('ReLoop API · /epr/allocations'),
                        child: qView<List<J>>(
                          q,
                          'a',
                          (as) => DataList<J>(
                            label: 'Allocation ledger',
                            rows: as,
                            rowKey: (a) => sn(a['id'])!,
                            sortKey: 'd',
                            sortAsc: false,
                            search: (a) => '${client(a['epr_org_id'])} ${runCode(a['processing_record_id'])}',
                            searchHint: 'Search client or run',
                            filters: [Flt<J>('s', 'Status', const [('ACTIVE', 'Active'), ('REVERSED', 'Reversed')], (a) => sn(a['status']) ?? '')],
                            emptyTitle: 'No allocations yet',
                            cols: [
                              Col<J>('d', 'Recorded', (a) => Small(dateTime(a['created_at'])), sort: (a) => sn(a['created_at'])),
                              tcol<J>('c', 'Client', (a) => client(a['epr_org_id'])),
                              Col<J>('r', 'Run', (a) => Mono(runCode(a['processing_record_id']), size: 12)),
                              tcol<J>('cat', 'Category', (a) => categoryLabel(a['packaging_category']), sortable: false),
                              tcol<J>('p', 'Period', (a) => sn(a['reporting_period']) ?? '', sortable: false),
                              ncol<J>('q', 'Quantity', (a) => dn(a['quantity_kg']), num1),
                              Col<J>(
                                's',
                                'Status',
                                (a) => a['reverses_allocation_id'] != null
                                    ? const Pill('Reversal entry', tone: Tone.warn)
                                    : (a['status'] == 'ACTIVE' ? const Pill('Active', tone: Tone.ok) : const Pill('Reversed')),
                                sort: (a) => sn(a['status']),
                              ),
                              Col<J>('why', 'Reason', (a) => Small(sn(a['reason']) ?? '')),
                              Col<J>(
                                'x',
                                '',
                                (a) => a['status'] == 'ACTIVE' && a['reverses_allocation_id'] == null
                                    ? Btn('Reverse',
                                        small: true,
                                        kind: BtnKind.ghost,
                                        onPressed: () => showSheet(context, _ReverseSheet(a, client(a['epr_org_id']), runCode(a['processing_record_id']))))
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ])
              ),
              ('Eligible output by run', () => Panel(flush: true, child: qView<List<J>>(q, 'p', (rs) => RunsTable(rs, onOpen: (_) {})))),
              (
                'Client requests',
                () => const Panel(
                      child: EmptyState(
                        title: 'Allocation requests are not available',
                        body:
                            "The backend accepts EPR clients' allocation requests but does not store them, so there is nothing to list. Agree quantities with clients directly, then allocate here.",
                      ),
                    )
              ),
            ]),
          ]);
        },
      );
}
