import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/quantities.dart';
import '../core/query.dart';
import '../features/passport.dart';
import '../ui/charts.dart';
import '../ui/data_list.dart';
import '../ui/widgets.dart';
import 'generator.dart' show bcode;

const String kNgoDisclaimer =
    'NGO verification is an independent, non-statutory review of evidence held on ReLoop. It is not EPR certification, does not determine EPR eligibility and is not an approval by CPCB or any State Pollution Control Board.';

Map<String, J> byId(List<J> batches) => {for (final b in batches) sn(b['id'])!: b};

double? _bq(Map<String, J> m, dynamic id, String k) {
  final b = m[sn(id)];
  return b == null ? null : bq(b, k);
}

/* ─────────────── Dashboard ─────────────── */
class NgoDashboard extends StatelessWidget {
  const NgoDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Queries(
      queries: {
        'v': QDef(K.verifications, Api.verifications),
        'b': QDef(K.batchList(), () => Api.batches()),
        'i': QDef(K.ngoImpact, Api.ngoImpact),
        'a': QDef(K.anomalies, Api.anomalies),
      },
      builder: (context, q) {
        final m = byId(q.list('b'));
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHeader(title: 'Verification dashboard', description: 'Independent review of batch evidence: custody, weights and processing records.'),
          const Note(tone: Tone.warn, title: 'Scope boundary', text: '$kNgoDisclaimer Operational records are read-only here.'),
          const SizedBox(height: 16),
          qView<List<J>>(q, 'v', (vs) {
            List<J> by(List<String> d) => vs.where((v) => d.contains(v['decision'])).toList();
            double out(List<J> x) => x.fold<double>(0, (s, v) => s + (_bq(m, v['batch_id'], 'processed_kg') ?? 0));
            final chart = [for (final o in kNgoOptions) (o.$1, o.$2, by([o.$1]).length, out(by([o.$1])))];
            final maxKg = chart.fold<double>(1, (s, x) => math.max(s, x.$4));
            return Gap([
              KpiGrid([
                Kpi(icon: Icons.visibility_outlined, label: 'Awaiting review', value: '${by(['PENDING', 'UNDER_REVIEW']).length}', sub: '${kg(out(by(['PENDING', 'UNDER_REVIEW'])))} recovered output'),
                Kpi(icon: Icons.verified_user_outlined, label: 'Verified', value: '${by(['VERIFIED']).length}', sub: kg(out(by(['VERIFIED'])))),
                Kpi(
                    icon: Icons.warning_amber_rounded,
                    label: 'Flagged / rejected / correction',
                    value: '${by(['FLAGGED', 'REJECTED', 'REQUIRES_CORRECTION']).length}',
                    sub: kg(out(by(['FLAGGED', 'REJECTED', 'REQUIRES_CORRECTION'])))),
                Kpi(label: 'Open anomaly flags', value: qText<List<J>>(q, 'a', (a) => '${a.where((x) => x['status'] == 'OPEN').length}')),
              ]),
              TwoCol(
                main: Panel(
                  title: 'Decisions by recovered output',
                  sub: 'Pro rata recovered output of each case batch',
                  footer: const SourceLine('ReLoop API · /ngo/verifications, /batches'),
                  child: Gap([
                    for (final x in chart)
                      Row(children: [
                        SizedBox(width: context.phone ? 110 : 150, child: Text(x.$2, style: TextStyle(fontSize: 12.5, color: c.fg2), overflow: TextOverflow.ellipsis)),
                        Expanded(
                          child: SegBar([(x.$4, x.$1 == 'VERIFIED' ? c.c1 : (['FLAGGED', 'REJECTED'].contains(x.$1) ? c.c5 : c.c4))], maxKg, height: 10),
                        ),
                        SizedBox(width: 110, child: numText('${x.$3} · ${num1(x.$4)} kg')),
                      ]),
                  ], gap: 8),
                ),
                side: Panel(
                  title: 'Platform impact (backend estimate)',
                  footer: const SourceLine('ReLoop API · /ngo/impact'),
                  child: Gap([
                    qView<J>(
                      q,
                      'i',
                      (i) => KV([
                        KVRow('Verified batches', '${i['verified_batch_count'] ?? '—'}'),
                        KVRow('Accepted kg of verified batches', kg(dn(i['total_verified_kg']))),
                        KVRow('CO₂ estimate', kg(dn(i['co2_saved_kg_est']))),
                      ]),
                    ),
                    const Small('The backend counts accepted kg (not recovered output) and applies a fixed CO₂ multiplier. Shown for reference only.', size: 11.5),
                  ], gap: 8),
                ),
              ),
              Panel(
                title: 'Review queue',
                flush: true,
                actions: [Btn('All cases', small: true, kind: BtnKind.outline, onPressed: () => go('/n/cases'))],
                child: CasesTable(by(['PENDING', 'UNDER_REVIEW', 'REQUIRES_CORRECTION']), m),
              ),
            ]);
          }),
        ]);
      },
    );
  }
}

class CasesTable extends StatelessWidget {
  final List<J> rows;
  final Map<String, J> m;
  final bool filters;
  const CasesTable(this.rows, this.m, {super.key, this.filters = false});
  @override
  Widget build(BuildContext context) => DataList<J>(
        label: 'Verification cases',
        rows: rows,
        rowKey: (v) => sn(v['id'])!,
        onTap: (v) => push('/n/cases/${v['id']}'),
        sortKey: 't',
        sortAsc: false,
        search: filters ? (v) => sn(v['batch_code']) ?? '' : null,
        searchHint: 'Search batch code',
        filters: filters ? [Flt<J>('d', 'Decision', kNgoOptions, (v) => sn(v['decision']) ?? '')] : const [],
        emptyTitle: 'No cases',
        emptyBody: 'Batches enter review when a recycler records their processing run.',
        cols: [
          Col<J>('c', 'Batch', (v) => BatchLink(sn(v['batch_code']) ?? ''), sort: (v) => sn(v['batch_code'])),
          tcol<J>('m', 'Material', (v) => sn(m[sn(v['batch_id'])]?['material']) ?? '—', sortable: false),
          tcol<J>('r', 'Recycler', (v) => sn(m[sn(v['batch_id'])]?['destination_recycler_name']) ?? '—', sortable: false),
          ncol<J>('col', 'Collected', (v) => _bq(m, v['batch_id'], 'collected_kg'), num1, sortable: false),
          ncol<J>('a', 'Accepted', (v) => _bq(m, v['batch_id'], 'accepted_kg'), num1, sortable: false),
          ncol<J>('o', 'Recovered', (v) => _bq(m, v['batch_id'], 'processed_kg'), num1),
          Col<J>('d', 'Decision', (v) => NgoPill(sn(v['decision'])), sort: (v) => sn(v['decision'])),
          Col<J>('t', 'Since', (v) => Small(dateTime(v['created_at'])), sort: (v) => sn(v['created_at'])),
        ],
      );
}

class NgoCases extends StatelessWidget {
  const NgoCases({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {'v': QDef(K.verifications, Api.verifications), 'b': QDef(K.batchList(), () => Api.batches())},
        builder: (context, q) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHeader(title: 'Cases', description: 'Every batch in independent review, with its current decision.'),
          const Note(text: 'The backend lists cases from all NGOs and assigns new ones to the first approved NGO organisation. All cases are shown here.'),
          const SizedBox(height: 16),
          Panel(
            flush: true,
            footer: const SourceLine('ReLoop API · /ngo/verifications'),
            child: qView<List<J>>(q, 'v', (vs) => CasesTable(vs, byId(q.list('b')), filters: true)),
          ),
        ]),
      );
}

/* ─────────────── Evidence checklist (computed from API data only) ─────────────── */
enum CheckState { ok, warn, bad, na }

class Check {
  final int n;
  final String label;
  final CheckState state;
  final String detail;
  const Check(this.n, this.label, this.state, this.detail);
}

List<Check> buildChecklist(J d, J? p, J? trace, J? y, List<J> recyclers, J? batch, List<J>? events) {
  final out = <Check>[];
  void add(int n, String l, CheckState s, String det) => out.add(Check(n, l, s, det));
  final docs = jl(d['documents']);
  final custody = jo(d['custody']) ?? const <String, dynamic>{};
  final photos = docs.where((x) => x['doc_type'] == 'PHOTO_LISTING').length;
  add(1, 'Listing photo present', photos > 0 ? CheckState.ok : CheckState.warn, photos > 0 ? '$photos photo record(s) with SHA-256' : 'No listing photo linked to the batch');
  final pk = jl(custody['pickup_records']).where((x) => x['is_current'] == true).firstOrNull;
  add(2, 'Pickup weighed and confirmed by generator (OTP/QR)', pk?['confirmed_at'] != null ? CheckState.ok : CheckState.bad,
      pk == null ? 'No pickup record' : (pk['confirmed_at'] != null ? 'Confirmed ${dateTime(pk['confirmed_at'])}' : 'Weight recorded but not confirmed'));
  final est = dn(jo(d['batch'])?['estimated_kg']) ?? 0;
  final pkKg = dn(pk?['collected_kg']);
  if (pk != null && pkKg != null && est != 0) {
    final dv = (pkKg - est) / est * 100;
    add(3, 'Collected vs listed within ±20%', dv.abs() <= 20 ? CheckState.ok : CheckState.warn, '${dv >= 0 ? '+' : ''}${pct(dv)} (${num1(pkKg)} vs ${num1(est)} kg)');
  } else {
    add(3, 'Collected vs listed within ±20%', CheckState.na, 'No pickup');
  }
  final rc = jl(custody['recycler_receipts']).where((x) => x['is_current'] == true).firstOrNull;
  if (pkKg != null && pkKg != 0 && rc != null) {
    final dv = ((dn(rc['received_kg']) ?? 0) - pkKg) / pkKg * 100;
    add(4, 'Received vs collected within −10% / +2%', (dv <= 2 && dv >= -10) ? CheckState.ok : CheckState.warn, '${dv >= 0 ? '+' : ''}${pct(dv)}');
  } else {
    add(4, 'Received vs collected within −10% / +2%', CheckState.na, 'No receipt');
  }
  if (rc != null) {
    final a = dn(rc['accepted_kg']) ?? 0, r = dn(rc['rejected_kg']) ?? 0, rv = dn(rc['received_kg']) ?? 0;
    add(5, 'Accepted + rejected = received', (a + r - rv).abs() <= 0.001 ? CheckState.ok : CheckState.bad, '${num1(a)} + ${num1(r)} = ${num1(rv)}');
  } else {
    add(5, 'Accepted + rejected = received', CheckState.na, 'No receipt');
  }
  add(6, 'Weighbridge slip or inspection record', CheckState.na, 'Not visible here: receipt documents are linked to the receipt, which the review endpoint does not return');
  final runs = jl(trace?['processing_runs']);
  add(7, 'Processing record includes this batch', runs.isEmpty ? CheckState.bad : (runs.every((r) => r['measurement_status'] == 'COMPLETE') ? CheckState.ok : CheckState.warn),
      runs.isEmpty ? 'No processing input recorded' : runs.map((r) => '${r['record_code']}: ${num1(dn(r['input_kg']))} kg in').join(', '));
  final rec = recyclers.where((r) => r['id'] == batch?['destination_recycler_org_id']).firstOrNull;
  final reg = jo(rec?['registration']);
  final validUntil = parseIso(reg?['registration_valid_until']);
  final runDate = runs.isEmpty ? null : parseIso(runs.first['run_started_at']);
  add(
    8,
    'Recycler registration valid on processing date',
    rec == null || reg?['pwp_registration_no'] == null
        ? CheckState.warn
        : (validUntil != null && runDate != null && validUntil.isBefore(runDate) ? CheckState.bad : CheckState.ok),
    rec == null ? 'Recycler not found in directory' : '${reg?['pwp_registration_no'] ?? 'No PWP number'} · valid until ${reg?['registration_valid_until'] ?? 'not recorded'}',
  );
  final certs = jl(p?['statutory_certificates']);
  add(9, 'Certificate references link to this run', certs.isNotEmpty ? CheckState.ok : CheckState.na,
      certs.isNotEmpty ? certs.map((c) => c['certificate_ref']).join(', ') : 'No certificate references recorded (optional)');
  final anomalies = jl(d['anomalies']);
  final open = anomalies.where((a) => a['status'] == 'OPEN').toList();
  add(10, 'Open anomaly flags reviewed', open.isNotEmpty ? CheckState.warn : CheckState.ok,
      open.isNotEmpty ? '${open.length} open: ${open.map((a) => humanize(a['rule_code'])).join(', ')}' : '${anomalies.length} flag(s), none open');
  final completed = jl(y?['completed_runs']);
  final yr = [for (final r in runs) ...completed.where((x) => x['record_code'] == r['record_code'])];
  if (yr.isNotEmpty) {
    final worst = yr.map((r) {
      final i = dn(r['input_kg']) ?? 0;
      return i == 0 ? 0.0 : (i - (dn(r['output_kg']) ?? 0) - (dn(r['residue_kg']) ?? 0)) / i * 100;
    }).reduce(math.max);
    add(11, 'Run mass balance: unaccounted ≤ 3%', worst <= 3 ? CheckState.ok : CheckState.warn, 'Worst run unaccounted ${pct(worst)}');
  } else {
    add(11, 'Run mass balance: unaccounted ≤ 3%', runs.isNotEmpty ? CheckState.warn : CheckState.na, runs.isNotEmpty ? 'Run measurements not available' : 'Not processed');
  }
  final cons = jo(jo(p?['custody'])?['consignment']);
  add(12, 'Weighed individually when consolidated', cons == null ? CheckState.na : (rc != null ? CheckState.ok : CheckState.bad),
      cons == null ? 'Not in a consignment' : '${cons['consignment_code']} · own receipt ${rc != null ? 'present' : 'missing'}');
  if (events != null && events.isNotEmpty) {
    const order = ['CREATED', 'OFFER_ACCEPTED', 'PICKED_UP', 'DISPATCHED', 'RECEIVED', 'PROCESSED'];
    final idx = events.map((e) => order.indexOf(sn(e['event_type']) ?? '')).where((i) => i >= 0).toList();
    var ordered = true;
    for (var i = 1; i < idx.length; i++) {
      if (idx[i] < idx[i - 1]) ordered = false;
    }
    add(13, 'Timeline order plausible', ordered ? CheckState.ok : CheckState.warn, ordered ? 'Events in expected order' : 'Events out of expected order');
  } else {
    add(13, 'Timeline order plausible', CheckState.na, 'No events');
  }
  return out;
}

/* ─────────────── Case review ─────────────── */
class NgoCaseReview extends StatelessWidget {
  final String id;
  const NgoCaseReview({super.key, required this.id});

  @override
  Widget build(BuildContext context) => QueryView<J>(
        qk: K.verification(id),
        fetch: () => Api.verification(id),
        loadingRows: 8,
        builder: (context, d) {
          final ver = jo(d['verification']) ?? const <String, dynamic>{};
          final batchId = sn(ver['batch_id'])!;
          final code = sn(jo(d['batch'])?['batch_code']) ?? '';
          return Queries(
            queries: {
              'b': QDef(K.batch(batchId), () => Api.batch(batchId)),
              'p': QDef(K.passport(code), () => Api.passport(code)),
              't': QDef(K.trace(batchId), () => Api.batchTrace(batchId)),
              'e': QDef(K.events(batchId), () => Api.batchEvents(batchId)),
              'y': QDef(K.yieldKey, Api.yieldAnalytics),
              'r': QDef(K.orgs('RECYCLER'), () => Api.orgs('RECYCLER')),
            },
            builder: (context, q) => _CaseBody(id: id, d: d, q: q),
          );
        },
      );
}

class _CaseBody extends StatefulWidget {
  final String id;
  final J d;
  final QSet q;
  const _CaseBody({required this.id, required this.d, required this.q});
  @override
  State<_CaseBody> createState() => _CaseBodyState();
}

class _CaseBodyState extends State<_CaseBody> {
  bool _claiming = false;

  Future<void> _claim() async {
    setState(() => _claiming = true);
    await mutate(() => Api.claimVerification(widget.id), invalidate: [K.verifications], success: (_) => 'Review started');
    if (mounted) setState(() => _claiming = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final d = widget.d;
    final q = widget.q;
    final ver = jo(d['verification']) ?? const <String, dynamic>{};
    final batchInfo = jo(d['batch']) ?? const <String, dynamic>{};
    final b = q.get<J>('b');
    final checks = buildChecklist(d, q.get<J>('p'), q.get<J>('t'), q.get<J>('y'), q.list('r'), b, q.get<List<J>>('e'));
    int count(CheckState s) => checks.where((x) => x.state == s).length;
    final decision = sn(ver['decision']);
    final decided = !['PENDING', 'UNDER_REVIEW'].contains(decision);
    void decide(String dec) => showSheet(context, _DecisionSheet(widget.id, dec, checks));
    (IconData, Color, String) icon(CheckState s) => switch (s) {
          CheckState.ok => (Icons.check_circle_outline, c.ok, 'Pass'),
          CheckState.warn => (Icons.warning_amber_rounded, c.warn, 'Review'),
          CheckState.bad => (Icons.cancel_outlined, c.bad, 'Fail'),
          CheckState.na => (Icons.circle_outlined, c.fg3, 'N/A'),
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Case · ${batchInfo['batch_code']}',
        description: '${b?['material'] ?? ''} · ${b?['generator_name'] ?? ''} → ${b?['assigned_collector_name'] ?? '—'} → ${b?['destination_recycler_name'] ?? '—'}',
        actions: [Btn('All cases', kind: BtnKind.outline, onPressed: () => back('/n/cases'))],
      ),
      Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
        NgoPill(decision),
        BatchStatusPill(sn(batchInfo['status'])),
        if (ver['comments'] != null) Text('"${ver['comments']}"', style: TextStyle(fontSize: 13, color: c.fg2)),
      ]),
      const SizedBox(height: 16),
      TabsView([
        (
          'Evidence checklist',
          () => TwoCol(
                main: Panel(
                  title: 'Checklist',
                  sub: '${count(CheckState.ok)} pass · ${count(CheckState.warn)} review · ${count(CheckState.bad)} fail · ${count(CheckState.na)} not applicable or unavailable',
                  flush: true,
                  child: Column(children: [
                    for (final ch in checks)
                      Builder(builder: (context) {
                        final (ic, col, label) = icon(ch.state);
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Icon(ic, size: 16, color: col),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('${ch.n}. ${ch.label}', style: const TextStyle(fontSize: 13)),
                                Small(ch.detail),
                              ]),
                            ),
                            const SizedBox(width: 8),
                            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: col)),
                          ]),
                        );
                      }),
                  ]),
                ),
                side: Gap([
                  Panel(
                    title: 'Decision',
                    child: Gap([
                      if (decision == 'PENDING') Btn('Start review', icon: Icons.visibility_outlined, kind: BtnKind.outline, loading: _claiming, onPressed: _claim),
                      Btn('Verify', icon: Icons.verified_user_outlined, onPressed: () => decide('VERIFIED')),
                      Btn('Request correction', kind: BtnKind.outline, onPressed: () => decide('REQUIRES_CORRECTION')),
                      Btn('Flag concern', kind: BtnKind.outline, onPressed: () => decide('FLAGGED')),
                      Btn('Reject', kind: BtnKind.destructive, onPressed: () => decide('REJECTED')),
                      Btn('Request a document', icon: Icons.description_outlined, kind: BtnKind.ghost, onPressed: b == null ? null : () => showSheet(context, _DocRequestSheet(widget.id, b))),
                      if (decided) const Note(text: 'A decision is already recorded. A new decision adds a record; the earlier one stays in the history.'),
                    ], gap: 8),
                  ),
                  const Note(tone: Tone.warn, text: kNgoDisclaimer),
                ]),
              )
        ),
        (
          'Quantity reconciliation',
          () => b == null
              ? const LoadingRows()
              : Gap([
                  QuantityLadder(quantities: jo(b['quantities']) ?? {}, trace: q.get<J>('t'), decision: decision),
                  Panel(
                    title: 'Variances',
                    child: Column(children: [
                      for (final v in variances(jo(b['quantities']) ?? {}))
                        Container(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                          child: Row(children: [
                            Expanded(child: Text(v.label, style: const TextStyle(fontSize: 13))),
                            Text('${v.kg >= 0 ? '+' : ''}${num1(v.kg)} kg ${v.pct != null ? '(${pct(v.pct)})' : ''}',
                                style: TextStyle(fontSize: 13, color: v.outOfTolerance ? c.bad : null, fontWeight: v.outOfTolerance ? FontWeight.w600 : null)),
                          ]),
                        ),
                    ]),
                  ),
                  Panel(
                    title: 'Receipt versions',
                    flush: true,
                    child: MiniTable(
                      headers: const ['Version', 'Received', 'Accepted', 'Rejected', 'Grade'],
                      numeric: const {1, 2, 3},
                      emptyText: 'No receipts.',
                      rows: [
                        for (final r in jl(jo(d['custody'])?['recycler_receipts']))
                          [
                            Row(mainAxisSize: MainAxisSize.min, children: [Text('v${r['version']} '), r['is_current'] == true ? const Pill('Current', tone: Tone.ok) : const Pill('Superseded')]),
                            numText(num1(dn(r['received_kg']))),
                            numText(num1(dn(r['accepted_kg']))),
                            numText(num1(dn(r['rejected_kg']))),
                            Text('${r['quality_grade']} · ${pct(dn(r['contamination_pct']))}'),
                          ],
                      ],
                    ),
                  ),
                ])
        ),
        ('Chain of custody', () => Panel(title: 'Custody events', child: qView<List<J>>(q, 'e', (ev) => EventTimeline(ev)))),
        ('Material passport', () => PassportView(code: sn(batchInfo['batch_code']) ?? '')),
      ]),
    ]);
  }
}

class _DecisionSheet extends StatefulWidget {
  final String id;
  final String decision;
  final List<Check> checks;
  const _DecisionSheet(this.id, this.decision, this.checks);
  @override
  State<_DecisionSheet> createState() => _DecisionSheetState();
}

class _DecisionSheetState extends State<_DecisionSheet> {
  final _comments = TextEditingController();
  final _follow = TextEditingController();
  String? _cErr;
  ApiError? _err;
  bool _busy = false;

  List<Check> get _issues => widget.checks.where((c) => c.state == CheckState.bad || c.state == CheckState.warn).toList();
  bool get _needsComment => widget.decision != 'VERIFIED' || _issues.isNotEmpty;

  @override
  void dispose() {
    _comments.dispose();
    _follow.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    String? e;
    if (_needsComment && _comments.text.trim().length < 10) e = 'Explain the decision (at least 10 characters)';
    if (_comments.text.length > 2000) e = 'At most 2,000 characters';
    setState(() => _cErr = e);
    if (e != null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.decide(widget.id, {
        'decision': widget.decision,
        if (_comments.text.trim().isNotEmpty) 'comments': _comments.text.trim(),
        if (_follow.text.trim().isNotEmpty) 'follow_up_required': _follow.text.trim(),
      }),
      invalidate: [K.verifications, K.ngo, K.batches, K.anomalies, K.epr],
      success: (_) => 'Decision recorded: ${humanize(widget.decision)}',
      toastErrors: false,
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: kNgo[widget.decision]?.$2 ?? widget.decision,
        description: 'Recorded with your name. Visible to the recycler, collector and affected EPR clients.',
        actions: [
          Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)),
          Btn('Record decision', kind: widget.decision == 'REJECTED' ? BtnKind.destructive : BtnKind.primary, loading: _busy, onPressed: _save),
        ],
        children: [
          if (widget.decision == 'VERIFIED' && _issues.isNotEmpty)
            Note(tone: Tone.warn, text: '${_issues.length} checklist item(s) need review or failed. Explain why the evidence is still sufficient.'),
          if (widget.decision == 'FLAGGED') const Note(text: 'Flagging opens a high-severity anomaly visible to the recycler and EPR clients.'),
          Field(label: 'Reviewer comments', required: _needsComment, error: _cErr, child: In(_comments, maxLines: 4, hasError: _cErr != null)),
          if (widget.decision != 'VERIFIED') Field(label: 'Follow-up required', child: In(_follow, placeholder: 'e.g. upload processing log for the run')),
          if (_err != null) Note(tone: Tone.bad, title: _err!.code == 'NOT_CURRENT' ? 'This case was updated by someone else' : 'Not recorded', text: _err!.message),
        ],
      );
}

class _DocRequestSheet extends StatefulWidget {
  final String id;
  final J b;
  const _DocRequestSheet(this.id, this.b);
  @override
  State<_DocRequestSheet> createState() => _DocRequestSheetState();
}

class _DocRequestSheetState extends State<_DocRequestSheet> {
  late final List<(String, String)> _parties = [
    if (widget.b['assigned_collector_org_id'] != null) (sn(widget.b['assigned_collector_org_id'])!, '${widget.b['assigned_collector_name']} (collector)'),
    if (widget.b['destination_recycler_org_id'] != null) (sn(widget.b['destination_recycler_org_id'])!, '${widget.b['destination_recycler_name']} (recycler)'),
  ];
  late String? _to = _parties.isEmpty ? null : _parties.first.$1;
  final _text = TextEditingController();
  String? _toErr, _textErr;
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _toErr = _to == null ? 'Choose a party' : null;
      _textErr = _text.text.trim().length < 10 ? 'Describe the evidence needed' : null;
    });
    if (_toErr != null || _textErr != null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.requestDocument(widget.id, {'addressed_to_org_id': _to, 'request_text': _text.text.trim()}),
      invalidate: [K.events(sn(widget.b['id'])!)],
      success: (_) => 'Document request recorded',
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'Request a document',
        description: bcode(widget.b),
        actions: [Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)), Btn('Send request', loading: _busy, onPressed: _send)],
        children: [
          Field(label: 'Addressed to', required: true, error: _toErr, child: Sel<String>(value: _to, items: _parties, onChanged: (v) => setState(() => _to = v))),
          Field(label: 'What is needed', required: true, error: _textErr, child: In(_text, maxLines: 3, hasError: _textErr != null)),
          const Note(text: 'The backend records the request as a batch event only. It does not notify the party or track responses yet.'),
          if (_err != null) Note(tone: Tone.bad, text: _err!.message),
        ],
      );
}

/* ─────────────── Chain of custody ─────────────── */
class NgoCustody extends StatefulWidget {
  const NgoCustody({super.key});
  @override
  State<NgoCustody> createState() => _NgoCustodyState();
}

class _NgoCustodyState extends State<NgoCustody> {
  String? _sel;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Queries(
      queries: {'v': QDef(K.verifications, Api.verifications), 'b': QDef(K.batchList(), () => Api.batches())},
      builder: (context, q) {
        final m = byId(q.list('b'));
        final vs = q.list('v');
        final current = _sel ?? sn(vs.firstOrNull?['batch_id']);
        final b = current == null ? null : m[current];
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHeader(title: 'Chain of custody', description: 'Custodian handoffs for each case: generator, collector, consignment, recycler and processing run.'),
          TwoCol(
            mainFlex: 1,
            sideFlex: 2,
            main: Panel(
              title: 'Cases',
              flush: true,
              child: qView<List<J>>(
                q,
                'v',
                (vs) => ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 520),
                  child: ListView(shrinkWrap: true, children: [
                    for (final v in vs)
                      Material(
                        color: v['batch_id'] == current ? c.accentSoft : Colors.transparent,
                        child: InkWell(
                          onTap: () => setState(() => _sel = sn(v['batch_id'])),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                            decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
                            child: Row(children: [
                              Expanded(
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Mono(sn(v['batch_code']) ?? '', size: 12),
                                  Small(sn(m[sn(v['batch_id'])]?['generator_name']) ?? '', size: 11.5),
                                ]),
                              ),
                              NgoPill(sn(v['decision'])),
                            ]),
                          ),
                        ),
                      ),
                  ]),
                ),
              ),
            ),
            side: b == null
                ? const Panel(child: EmptyState(title: 'Select a case'))
                : Queries(
                    queries: {'e': QDef(K.events(current!), () => Api.batchEvents(current)), 'p': QDef(K.passport(bcode(b)), () => Api.passport(bcode(b)))},
                    builder: (context, q2) {
                      final custody = jo(q2.get<J>('p')?['custody']);
                      final cons = jo(custody?['consignment']);
                      final runs = jl(custody?['processing_runs']);
                      final steps = [
                        ('Generator', sn(b['generator_name']), 'listed ${kg(bq(b, 'estimated_kg'))}'),
                        ('Collector', sn(b['assigned_collector_name']), 'collected ${kg(bq(b, 'collected_kg'))}'),
                        ('Consignment', sn(cons?['consignment_code']) ?? '—', sn(cons?['vehicle_no']) ?? ''),
                        ('Recycler', sn(b['destination_recycler_name']), 'received ${kg(bq(b, 'received_kg'))} · accepted ${kg(bq(b, 'accepted_kg'))}'),
                        ('Processing', runs.isEmpty ? '—' : runs.map((r) => r['record_code']).join(', '), 'recovered ${kg(bq(b, 'processed_kg'))}'),
                      ];
                      return Gap([
                        Panel(
                          title: 'Custodians',
                          child: Gap([
                            for (var i = 0; i < steps.length; i++)
                              Padding(
                                padding: EdgeInsets.only(left: math.min(i * 14.0, context.phone ? 28 : 56)),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(6)),
                                  child: Wrap(spacing: 12, runSpacing: 2, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                    SizedBox(width: 96, child: Text(steps[i].$1.toUpperCase(), style: TextStyle(fontSize: 10.5, letterSpacing: 0.6, color: c.fg3))),
                                    Text(steps[i].$2 ?? '—', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                    Small(steps[i].$3),
                                  ]),
                                ),
                              ),
                          ], gap: 8),
                        ),
                        Panel(title: 'Event log', sub: 'Append-only', child: qView<List<J>>(q2, 'e', (ev) => EventTimeline(ev))),
                      ]);
                    },
                  ),
          ),
        ]);
      },
    );
  }
}

/* ─────────────── Reconciliation ─────────────── */
class NgoReconciliation extends StatelessWidget {
  const NgoReconciliation({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    Widget varCell(Variance? v) => v == null ? numText('—') : numText(pct(v.pct), bold: v.outOfTolerance, color: v.outOfTolerance ? c.bad : null);
    return Queries(
      queries: {'v': QDef(K.verifications, Api.verifications), 'b': QDef(K.batchList(), () => Api.batches())},
      builder: (context, q) {
        final m = byId(q.list('b'));
        final rows = [
          for (final v in q.list('v'))
            if (m[sn(v['batch_id'])] != null) {'v': v, 'b': m[sn(v['batch_id'])]},
        ];
        J bOf(Map<String, J?> r) => r['b']!;
        Variance? vOf(J b, String label) => variances(jo(b['quantities']) ?? {}).where((x) => x.label == label).firstOrNull;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const PageHeader(
              title: 'Quantity reconciliation',
              description: 'Every stage of every case side by side. Red cells are outside tolerance: ±20% listed vs collected, ±2% collected vs received.'),
          Panel(
            flush: true,
            footer: const SourceLine('ReLoop API · /ngo/verifications, /batches'),
            child: qView<List<J>>(
              q,
              'v',
              (_) => DataList<Map<String, J?>>(
                label: 'Reconciliation',
                rows: rows,
                rowKey: (r) => sn(r['v']!['id'])!,
                onTap: (r) => push('/n/cases/${r['v']!['id']}'),
                emptyTitle: 'No cases',
                cols: [
                  Col('c', 'Batch', (r) => BatchLink(bcode(bOf(r)))),
                  ncol('l', 'Listed', (r) => bq(bOf(r), 'estimated_kg'), num1, sortable: false),
                  ncol('col', 'Collected', (r) => bq(bOf(r), 'collected_kg'), num1, sortable: false),
                  Col('d1', 'Δ listed', (r) => varCell(vOf(bOf(r), 'Collected vs listed')), numeric: true),
                  ncol('rec', 'Received', (r) => bq(bOf(r), 'received_kg'), num1, sortable: false),
                  Col('d2', 'Δ transit', (r) => varCell(vOf(bOf(r), 'Received vs collected')), numeric: true),
                  ncol('a', 'Accepted', (r) => bq(bOf(r), 'accepted_kg'), num1, sortable: false),
                  ncol('x', 'Rejected', (r) => bq(bOf(r), 'rejected_kg'), num1, sortable: false),
                  ncol('o', 'Recovered', (r) => bq(bOf(r), 'processed_kg'), num1, sortable: false),
                  Col('n', 'Decision', (r) => NgoPill(sn(r['v']!['decision']))),
                ],
                footer: (rs) {
                  final bs = rs.map(bOf).toList();
                  return [
                    const FootItem('Total', ''),
                    FootItem('Listed', num1(sumQ(bs, 'estimated_kg'))),
                    FootItem('Collected', num1(sumQ(bs, 'collected_kg'))),
                    FootItem('Received', num1(sumQ(bs, 'received_kg'))),
                    FootItem('Accepted', num1(sumQ(bs, 'accepted_kg'))),
                    FootItem('Rejected', num1(sumQ(bs, 'rejected_kg'))),
                    FootItem('Recovered', num1(sumQ(bs, 'processed_kg'))),
                  ];
                },
              ),
            ),
          ),
        ]);
      },
    );
  }
}

/* ─────────────── Document requests (derived from batch events) ─────────────── */
class NgoDocuments extends StatelessWidget {
  const NgoDocuments({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {'v': QDef(K.verifications, Api.verifications), 'o': QDef(K.orgs(), () => Api.orgs())},
        builder: (context, q) {
          final vs = q.list('v');
          final ids = {for (final v in vs) sn(v['batch_id'])!}.toList();
          String orgName(dynamic id) => sn(q.list('o').where((o) => o['id'] == id).firstOrNull?['legal_name']) ?? (sn(id) ?? '—').padRight(8).substring(0, 8);
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(title: 'Document requests', description: 'Evidence requested from collectors and recyclers. Create new requests from a case.'),
            const Note(
                text: 'The backend stores document requests as batch events only: there is no response, status or notification yet. This list is assembled from those events.'),
            const SizedBox(height: 16),
            Panel(
              flush: true,
              child: !q.has('v')
                  ? (q.error('v') != null ? ErrorState(error: q.error('v')!, onRetry: q.refetch) : const LoadingRows())
                  : Queries(
                      queries: {for (final id in ids) id: QDef(K.events(id), () => Api.batchEvents(id))},
                      builder: (context, ev) {
                        if (ids.any((id) => ev.pending(id))) return const LoadingRows();
                        final rows = <J>[];
                        for (final id in ids) {
                          final v = vs.firstWhere((x) => x['batch_id'] == id);
                          for (final e in ev.list(id).where((e) => e['event_type'] == 'DOCUMENT_REQUESTED')) {
                            rows.add({'e': e, 'code': v['batch_code'], 'vid': v['id']});
                          }
                        }
                        return DataList<J>(
                          label: 'Document requests',
                          rows: rows,
                          rowKey: (r) => '${jo(r['e'])?['id']}',
                          onTap: (r) => push('/n/cases/${r['vid']}'),
                          sortKey: 'd',
                          sortAsc: false,
                          emptyTitle: 'No document requests',
                          emptyBody: 'Open a case and choose "Request a document".',
                          cols: [
                            Col<J>('d', 'Sent', (r) => Small(dateTime(jo(r['e'])?['created_at'])), sort: (r) => sn(jo(r['e'])?['created_at'])),
                            Col<J>('c', 'Batch', (r) => BatchLink(sn(r['code']) ?? '')),
                            tcol<J>('t', 'Addressed to', (r) => orgName(jo(jo(r['e'])?['payload'])?['addressed_to']), sortable: false),
                            tcol<J>('r', 'Request', (r) => sn(jo(jo(r['e'])?['payload'])?['request']) ?? '', sortable: false),
                            Col<J>('s', 'Status', (r) => const Pill('Not tracked by backend')),
                          ],
                        );
                      },
                    ),
            ),
          ]);
        },
      );
}

/* ─────────────── Discrepancies (shared with admin) ─────────────── */
class AnomalyTable extends StatelessWidget {
  final List<J> rows;
  final bool canResolve;
  final String? Function(dynamic batchId) batchCode;
  const AnomalyTable({super.key, required this.rows, required this.canResolve, required this.batchCode});

  @override
  Widget build(BuildContext context) => DataList<J>(
        label: 'Anomaly flags',
        rows: rows,
        rowKey: (a) => sn(a['id'])!,
        sortKey: 'd',
        sortAsc: false,
        filters: [
          Flt<J>('s', 'Status', const [('OPEN', 'Open'), ('RESOLVED', 'Resolved'), ('ACKNOWLEDGED', 'Acknowledged'), ('DISMISSED', 'Dismissed')], (a) => sn(a['status']) ?? ''),
          Flt<J>('v', 'Severity', {for (final a in rows) sn(a['severity']) ?? ''}.map((s) => (s, humanize(s))).toList(), (a) => sn(a['severity']) ?? ''),
        ],
        emptyTitle: 'No anomaly flags',
        cols: [
          Col<J>('d', 'Raised', (a) => Small(dateTime(a['created_at'])), sort: (a) => sn(a['created_at'])),
          tcol<J>('r', 'Rule', (a) => humanize(a['rule_code'])),
          Col<J>('v', 'Severity', (a) => Pill(humanize(a['severity']), tone: a['severity'] == 'HIGH' ? Tone.bad : (a['severity'] == 'WARN' ? Tone.warn : Tone.info))),
          Col<J>('b', 'Batch', (a) {
            final code = batchCode(a['batch_id']);
            return code != null ? BatchLink(code) : const Text('—');
          }),
          Col<J>('x', 'Details', (a) {
            final det = jo(a['details']);
            return ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                Small(det == null || det.isEmpty ? '—' : det.entries.map((e) => '${humanize(e.key)}: ${e.value}').join(' · '), color: context.c.fg2),
                if (a['resolution_note'] != null) Small('Resolution: ${a['resolution_note']}'),
              ]),
            );
          }),
          Col<J>('s', 'Status', (a) => a['status'] == 'OPEN' ? const Pill('Open', tone: Tone.bad) : Pill(humanize(a['status']), tone: Tone.ok), sort: (a) => sn(a['status'])),
          Col<J>('z', '', (a) => canResolve && a['status'] == 'OPEN' ? Btn('Resolve', small: true, kind: BtnKind.outline, onPressed: () => showSheet(context, _ResolveSheet(a))) : const SizedBox.shrink()),
        ],
      );
}

class _ResolveSheet extends StatefulWidget {
  final J a;
  const _ResolveSheet(this.a);
  @override
  State<_ResolveSheet> createState() => _ResolveSheetState();
}

class _ResolveSheetState extends State<_ResolveSheet> {
  String _status = 'RESOLVED';
  final _note = TextEditingController();
  String? _nErr;
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _nErr = _note.text.trim().length < 10 ? 'Explain the resolution (at least 10 characters)' : null);
    if (_nErr != null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.resolveAnomaly(sn(widget.a['id'])!, {'status': _status, 'note': _note.text.trim()}),
      invalidate: [K.anomalies, K.batches, K.epr],
      success: (_) => 'Flag updated',
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'Update flag · ${humanize(widget.a['rule_code'])}',
        description: 'The flag stays in the log with your note.',
        actions: [Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)), Btn('Save', loading: _busy, onPressed: _save)],
        children: [
          Field(
            label: 'New status',
            child: Sel<String>(
              value: _status,
              items: const [('RESOLVED', 'Resolved'), ('ACKNOWLEDGED', 'Acknowledged'), ('DISMISSED', 'Dismissed')],
              onChanged: (v) => setState(() => _status = v ?? 'RESOLVED'),
            ),
          ),
          Field(label: 'Resolution note', required: true, error: _nErr, child: In(_note, maxLines: 3, hasError: _nErr != null)),
          if (_err != null) Note(tone: Tone.bad, text: _err!.message),
        ],
      );
}

class NgoDiscrepancies extends StatelessWidget {
  const NgoDiscrepancies({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {'a': QDef(K.anomalies, Api.anomalies), 'b': QDef(K.batchList(), () => Api.batches())},
        builder: (context, q) {
          final m = byId(q.list('b'));
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(title: 'Discrepancies', description: 'Anomaly flags raised by rules, reviewers or participants. Resolving requires a note; the flag stays in the log.'),
            Panel(
              flush: true,
              footer: const SourceLine('ReLoop API · /anomalies'),
              child: qView<List<J>>(q, 'a', (as) => AnomalyTable(rows: as, canResolve: true, batchCode: (id) => m[sn(id)] == null ? null : bcode(m[sn(id)]!))),
            ),
          ]);
        },
      );
}

/* ─────────────── Reports ─────────────── */
class NgoReports extends StatelessWidget {
  const NgoReports({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {'r': QDef(K.ngoReports, Api.ngoReports), 'v': QDef(K.verifications, Api.verifications), 'b': QDef(K.batchList(), () => Api.batches())},
        builder: (context, q) {
          final m = byId(q.list('b'));
          final vs = q.list('v');
          void export() {
            final today = DateTime.now().toIso8601String().substring(0, 10);
            showCsv(context, 'reloop-verification-report-$today.csv', [
              ['batch_code', 'material', 'recycler', 'collected_kg', 'accepted_kg', 'recovered_output_kg', 'decision', 'decision_at', 'comments'],
              for (final v in vs)
                [
                  v['batch_code'],
                  m[sn(v['batch_id'])]?['material'],
                  m[sn(v['batch_id'])]?['destination_recycler_name'],
                  _bq(m, v['batch_id'], 'collected_kg'),
                  _bq(m, v['batch_id'], 'accepted_kg'),
                  _bq(m, v['batch_id'], 'processed_kg'),
                  v['decision'],
                  v['created_at'],
                  v['comments'],
                ],
            ]);
          }

          final rep = q.get<J>('r');
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              title: 'Verification reports',
              description: 'Decisions and quantities for the reporting period, exported from live records.',
              actions: [Btn('Export CSV', icon: Icons.download_outlined, kind: BtnKind.outline, onPressed: vs.isEmpty ? null : export)],
            ),
            Gap([
              Panel(
                title: 'Decisions by type',
                sub: rep != null ? 'Reporting period ${rep['reporting_period']} (as labelled by the backend)' : null,
                footer: const SourceLine('ReLoop API · /ngo/reports'),
                child: Gap([
                  qView<J>(
                    q,
                    'r',
                    (r) => KpiGrid([for (final o in kNgoOptions) Kpi(label: o.$2, value: '${jo(r['counts_by_decision'])?[o.$1] ?? 0}')], cols: 6),
                  ),
                  const Small('Counts are for decisions recorded by your organisation. PDF reports are not generated by the backend; use CSV export.', size: 11.5),
                ], gap: 8),
              ),
              Panel(
                title: 'Report contents',
                flush: true,
                footer: const Text(kNgoDisclaimer),
                child: qView<List<J>>(
                  q,
                  'v',
                  (vs) => DataList<J>(
                    label: 'Report rows',
                    rows: vs,
                    rowKey: (v) => sn(v['id'])!,
                    cols: [
                      Col<J>('c', 'Batch', (v) => BatchLink(sn(v['batch_code']) ?? '')),
                      ncol<J>('a', 'Accepted', (v) => _bq(m, v['batch_id'], 'accepted_kg'), num1, sortable: false),
                      ncol<J>('o', 'Recovered', (v) => _bq(m, v['batch_id'], 'processed_kg'), num1, sortable: false),
                      Col<J>('d', 'Decision', (v) => NgoPill(sn(v['decision']))),
                      Col<J>('t', 'Recorded', (v) => Small(dateTime(v['created_at']))),
                      Col<J>('n', 'Comments', (v) => Small(sn(v['comments']) ?? '')),
                    ],
                  ),
                ),
              ),
            ]),
          ]);
        },
      );
}

/* ─────────────── Audit history (shared with admin) ─────────────── */
class AuditTable extends StatelessWidget {
  const AuditTable({super.key});
  @override
  Widget build(BuildContext context) => QueryView<List<J>>(
        qk: K.audit,
        fetch: Api.auditLogs,
        builder: (context, logs) {
          int idOf(J r) => (dn(r['id']) ?? 0).toInt();
          final sorted = [...logs]..sort((a, b) => idOf(a).compareTo(idOf(b)));
          final broken = <int>{};
          for (var i = 1; i < sorted.length; i++) {
            if (idOf(sorted[i - 1]) == idOf(sorted[i]) - 1 && sorted[i]['prev_hash'] != sorted[i - 1]['row_hash']) broken.add(idOf(sorted[i]));
          }
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Note(
                tone: broken.isNotEmpty ? Tone.bad : Tone.ok,
                text: broken.isNotEmpty
                    ? "${broken.length} row(s) do not link to the previous row's hash."
                    : "Each consecutive row's previous-hash matches the prior row's hash (last 100 rows).",
              ),
            ),
            DataList<J>(
              label: 'Audit log',
              rows: logs,
              rowKey: (r) => '${r['id']}',
              sortKey: 'id',
              sortAsc: false,
              search: (r) => '${r['action']} ${r['entity_type']}',
              searchHint: 'Search action or entity',
              cols: [
                Col<J>('id', '#', (r) => numText('${r['id']}'), numeric: true, sort: idOf),
                Col<J>('d', 'Time', (r) => Small(dateTime(r['created_at']))),
                tcol<J>('a', 'Action', (r) => humanize(r['action']), sortable: false),
                Col<J>('e', 'Entity', (r) => Small(humanize(r['entity_type']))),
                Col<J>('af', 'Change', (r) {
                  final s = r['after'] == null ? '—' : jsonEncode(r['after']);
                  return ConstrainedBox(constraints: const BoxConstraints(maxWidth: 320), child: Mono(s.length > 90 ? s.substring(0, 90) : s, size: 11, color: context.c.fg2));
                }),
                Col<J>('h', 'Row hash', (r) {
                  final h = sn(r['row_hash']) ?? '';
                  return Mono('${h.length > 16 ? h.substring(0, 16) : h}…', size: 11, color: broken.contains(idOf(r)) ? context.c.bad : context.c.fg3);
                }),
              ],
            ),
          ]);
        },
      );
}

class NgoAudit extends StatelessWidget {
  const NgoAudit({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: const [
        PageHeader(title: 'Audit history', description: 'Tamper-evident audit log written by the backend for batch creation and EPR allocation events.'),
        Panel(flush: true, footer: SourceLine('ReLoop API · /audit/logs (last 100 rows)'), child: AuditTable()),
      ]);
}
