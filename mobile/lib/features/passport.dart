import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/format.dart';
import '../core/quantities.dart';
import '../core/query.dart';
import '../ui/widgets.dart';

/* ───────────── QR ───────────── */

/// The batch QR is a protected PNG, fetched with the access token.
class BatchQr extends StatelessWidget {
  final String batchId;
  final String code;
  final double size;
  const BatchQr({super.key, required this.batchId, required this.code, this.size = 116});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return QueryBuilder<Uint8List>(
      qk: K.qr(batchId),
      fetch: () => Api.batchQr(batchId),
      builder: (context, q) {
        final box = BoxDecoration(color: Colors.white, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(4));
        if (q.data != null) {
          return Semantics(
            label: 'QR code for batch $code',
            image: true,
            child: Container(decoration: box, child: Image.memory(q.data!, width: size, height: size, gaplessPlayback: true)),
          );
        }
        return Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: q.error != null ? box.copyWith(color: c.surface) : BoxDecoration(color: c.surface2, borderRadius: BorderRadius.circular(4)),
          child: q.error != null ? Small('QR unavailable', size: 11) : null,
        );
      },
    );
  }
}

/* ───────────── Quantity ladder ───────────── */

/// Six physical stages, each recorded by a different party. Losses between stages are shown, never hidden.
class QuantityLadder extends StatelessWidget {
  final J quantities;
  final J? trace;
  final String? decision;
  final bool? pickupConfirmed;
  final bool compact;
  const QuantityLadder({super.key, required this.quantities, this.trace, this.decision, this.pickupConfirmed, this.compact = false});

  ({String text, bool bad})? _delta(List<Stage> s, int i) {
    final st = s[i];
    if (i == 0 || st.value == null || s[i - 1].value == null) return null;
    final prev = s[i - 1].value!;
    final v = st.value!;
    if (st.key == 'accepted') {
      final rej = q(quantities['rejected_kg']);
      return (rej != null && rej != 0) ? (text: '${num1(rej)} kg rejected', bad: true) : (text: 'Nothing rejected', bad: false);
    }
    if (st.key == 'input') {
      final held = prev - v;
      return held > 0.001 ? (text: '${num1(held)} kg not yet processed', bad: false) : (text: 'All accepted kg processed', bad: false);
    }
    if (st.key == 'output') return (text: '${num1(prev - v)} kg residue and loss', bad: true);
    final d = v - prev;
    final p = prev != 0 ? d / prev * 100 : 0;
    final tol = st.key == 'collected' ? 20 : 2;
    return (text: '${d >= 0 ? '+' : ''}${num1(d)} kg vs ${s[i - 1].label.toLowerCase()}', bad: p.abs() > tol);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final stages = physicalStages(quantities, trace: trace, pickupConfirmed: pickupConfirmed);
    final base = (stages[0].value == null || stages[0].value == 0) ? 1.0 : stages[0].value!;
    final firstMissing = stages.indexWhere((s) => s.value == null);
    Widget tile(int i) {
      final s = stages[i];
      final d = _delta(stages, i);
      final state = s.value != null ? (s.provisional ? 'prov' : 'done') : (i == firstMissing ? 'next' : 'todo');
      final (Color dotBg, Color dotFg) = switch (state) {
        'done' => (c.brand, c.brandFg),
        'prov' || 'next' => (c.warnBg, c.warn),
        _ => (c.neuBg, c.fg2),
      };
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line, width: 0.5)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: dotBg, shape: BoxShape.circle),
              child: Text('${i + 1}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: dotFg)),
            ),
            const SizedBox(width: 6),
            Expanded(child: Text(s.label.toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 10.5, letterSpacing: 0.6, color: c.fg3))),
          ]),
          const SizedBox(height: 4),
          Text(
            s.value != null ? kg(s.value) : (state == 'next' ? 'Awaiting' : '—'),
            style: TextStyle(
              fontSize: s.value == null ? 13 : (compact ? 14 : 17),
              fontWeight: s.value == null ? FontWeight.w500 : FontWeight.w600,
              color: s.value == null ? c.fg3 : c.fg,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          if (!compact) ...[
            const SizedBox(height: 2),
            Text(s.provisional ? 'Awaiting generator confirmation' : (d?.text ?? s.hint),
                style: TextStyle(fontSize: 11.5, color: (d?.bad ?? false) ? c.bad : c.fg3), maxLines: 2),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: s.value == null ? 0 : (s.value! / base).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: c.surface2,
                color: c.c2,
              ),
            ),
          ],
        ]),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Semantics(
        label: 'Quantity progression',
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(8)),
            child: LayoutBuilder(builder: (context, box) {
              final cols = compact ? (box.maxWidth >= 640 ? 6 : 3) : (box.maxWidth >= 1100 ? 6 : (box.maxWidth >= 560 ? 3 : 2));
              final w = box.maxWidth / cols;
              return Wrap(children: [for (var i = 0; i < 6; i++) SizedBox(width: w, child: tile(i))]);
            }),
          ),
        ),
      ),
      if (!compact) ...[const SizedBox(height: 10), AssuranceRow(quantities: quantities, decision: decision)],
    ]);
  }
}

class AssuranceRow extends StatelessWidget {
  final J quantities;
  final String? decision;
  const AssuranceRow({super.key, required this.quantities, this.decision});

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final v = verifiedKg(quantities, decision);
    final a = allocatedKg(quantities);
    final out = q(quantities['processed_kg']);
    Widget cell(String label, String value, String note) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11.5, color: c.fg2)),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontFeatures: [FontFeature.tabularFigures()])),
            Text(note, style: TextStyle(fontSize: 11, color: c.fg3)),
          ]),
        );
    final verifiedNote = decision == null
        ? 'Enters independent review once output is measured'
        : out == null
            ? 'Shown only after recovered output is measured'
            : decision == 'VERIFIED'
                ? 'Independent, non-statutory evidence review'
                : 'Not verified: see decision';
    final a1 = cell('NGO-verified quantity', v != null ? kg(v) : '—', verifiedNote);
    final a2 = cell('Allocated to EPR clients', a != null ? kg(a) : '—',
        'Pro rata share of active allocations on the run. Verification does not make kg EPR-eligible; eligibility is declared by the recycler.');
    return Container(
      decoration: BoxDecoration(color: c.surface, border: Border.all(color: c.line), borderRadius: BorderRadius.circular(8)),
      child: LayoutBuilder(
        builder: (context, box) => box.maxWidth >= 560
            ? IntrinsicHeight(
                child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Expanded(child: a1),
                  VerticalDivider(width: 1, color: c.line),
                  Expanded(child: a2),
                ]),
              )
            : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [a1, Divider(height: 1, color: c.line), a2]),
      ),
    );
  }
}

/* ───────────── Event timeline ───────────── */

class EventTimeline extends StatelessWidget {
  final List<J> events;
  const EventTimeline(this.events, {super.key});

  static String summary(J e) {
    final p = jo(e['payload']) ?? const <String, dynamic>{};
    final parts = <String>[];
    p.forEach((k, v) {
      if (v == null || v is Map || v is List) return;
      parts.add('${humanize(k)}: $v');
    });
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    if (events.isEmpty) return Text('No events recorded.', style: TextStyle(fontSize: 13.5, color: c.fg3));
    (IconData, Color, Color) style(String t) => switch (t) {
          'NGO_FLAGGED' => (Icons.warning_amber_rounded, c.bad, c.badBg),
          'NGO_REJECTED' => (Icons.cancel_outlined, c.bad, c.badBg),
          'CANCELLED' => (Icons.cancel_outlined, c.fg3, c.neuBg),
          'COLLECTOR_WITHDRAWN' || 'CORRECTION_SUBMITTED' => (Icons.warning_amber_rounded, c.warn, c.warnBg),
          'DOCUMENT_REQUESTED' => (Icons.circle_outlined, c.info, c.infoBg),
          _ => (Icons.check_circle_outline, c.ok, c.okBg),
        };
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      for (var i = 0; i < events.length; i++)
        IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            SizedBox(
              width: 22,
              child: Column(children: [
                Builder(builder: (context) {
                  final (ic, fg, bg) = style(sn(events[i]['event_type']) ?? '');
                  return Container(width: 22, height: 22, decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(ic, size: 12, color: fg));
                }),
                if (i < events.length - 1) Expanded(child: Container(width: 1, color: c.line)),
              ]),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Wrap(spacing: 12, runSpacing: 2, alignment: WrapAlignment.spaceBetween, children: [
                    Text('${humanize(events[i]['event_type'])}${events[i]['to_status'] != null ? ' → ${humanize(events[i]['to_status'])}' : ''}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    Small(dateTime(events[i]['created_at'])),
                  ]),
                  if (summary(events[i]).isNotEmpty) Text(summary(events[i]), style: TextStyle(fontSize: 12, color: c.fg2)),
                ]),
              ),
            ),
          ]),
        ),
    ]);
  }
}

/* ───────────── Tabs ───────────── */

/// Segmented tabs that keep their content in the page scroll (the web app's `Tabs`).
class TabsView extends StatefulWidget {
  final List<(String, Widget Function())> tabs;
  const TabsView(this.tabs, {super.key});
  @override
  State<TabsView> createState() => _TabsViewState();
}

class _TabsViewState extends State<TabsView> {
  int _i = 0;
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, mainAxisSize: MainAxisSize.min, children: [
      Container(
        decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.line))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < widget.tabs.length; i++)
              InkWell(
                onTap: () => setState(() => _i = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == _i ? c.brand : Colors.transparent, width: 2))),
                  child: Text(widget.tabs[i].$1,
                      style: TextStyle(fontSize: 13.5, fontWeight: i == _i ? FontWeight.w600 : FontWeight.w500, color: i == _i ? c.fg : c.fg2)),
                ),
              ),
          ]),
        ),
      ),
      const SizedBox(height: 16),
      KeyedSubtree(key: ValueKey(_i), child: widget.tabs[_i].$2()),
    ]);
  }
}

/* ───────────── Passport ───────────── */

/// The material passport: everything the backend holds about one batch, read-only.
class PassportView extends StatelessWidget {
  final String code;
  const PassportView({super.key, required this.code});

  @override
  Widget build(BuildContext context) {
    return Queries(
      queries: {'p': QDef(K.passport(code), () => Api.passport(code)), 'b': QDef(K.batch(code), () => Api.batch(code))},
      builder: (context, s) {
        if (s.error('p') != null) return ErrorState(error: s.error('p')!, onRetry: s.refetch);
        if (s.error('b') != null) return ErrorState(error: s.error('b')!, onRetry: s.refetch);
        final p = s.get<J>('p');
        final b = s.get<J>('b');
        if (p == null || b == null) return const LoadingRows(rows: 8);
        final id = sn(b['id'])!;
        return Queries(
          queries: {'t': QDef(K.trace(id), () => Api.batchTrace(id)), 'e': QDef(K.events(id), () => Api.batchEvents(id))},
          builder: (context, s2) => _body(context, p, b, s2),
        );
      },
    );
  }

  Widget _body(BuildContext context, J p, J b, QSet s2) {
    final c = context.c;
    final isEpr = auth.role == 'epr';
    final custody = jo(p['custody']) ?? const <String, dynamic>{};
    final pickups = jl(custody['pickup_records']);
    final receipts = jl(custody['receipts']);
    final runs = jl(custody['processing_runs']);
    final cons = jo(custody['consignment']);
    final verifs = jl(p['verifications']);
    final curPick = pickups.where((x) => x['is_current'] == true).firstOrNull;
    final curVer = verifs.where((v) => v['is_current'] == true).firstOrNull;
    final mat = jo(p['material']) ?? const <String, dynamic>{};
    final gen = jo(p['generator']) ?? const <String, dynamic>{};
    final qty = jo(p['quantities']) ?? const <String, dynamic>{};
    final allocs = jl(p['epr_allocations']);
    final certs = jl(p['statutory_certificates']);
    final docs = jl(p['documents']);
    final anomalies = jl(p['anomalies']);
    final matText = '${mat['name'] ?? mat['code']}${mat['resin_code'] != null ? ' (RIC ${mat['resin_code']})' : ''}';
    final genText = isEpr ? '${humanize(gen['generator_type'])} generator, ${gen['locality'] ?? gen['city_id']}' : '${gen['legal_name'] ?? '—'} · ${gen['locality'] ?? ''}';

    return Gap([
      Wrap(spacing: 16, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.start, children: [
        BatchQr(batchId: sn(b['id'])!, code: sn(p['batch_code'])!),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.screenW < 520 ? context.screenW - 48 : 560),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SelectableText(sn(p['batch_code'])!, style: mono(context, size: 15, weight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text('$matText · $genText', style: TextStyle(fontSize: 13, color: c.fg2)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              BatchStatusPill(sn(p['status'])),
              if (curVer != null) NgoPill(sn(curVer['decision'])),
              if (cons != null) TagChip(sn(cons['consignment_code']) ?? ''),
              for (final r in runs) TagChip(sn(r['record_code']) ?? ''),
            ]),
            const SizedBox(height: 8),
            const Small('Read-only record from the ReLoop API. Not a statutory document.', size: 11.5),
          ]),
        ),
      ]),
      QuantityLadder(
        quantities: qty,
        trace: s2.get<J>('t'),
        decision: sn(curVer?['decision']),
        pickupConfirmed: curPick == null ? null : curPick['confirmed_at'] != null,
      ),
      TabsView([
        (
          'Custody records',
          () => Gap([
                RGrid(minWidth: 380, maxCols: 2, gap: 16, children: [
                  Panel(
                    title: 'Parties',
                    child: KV([
                      KVRow('Generator', isEpr ? '${humanize(gen['generator_type'])} (identity withheld)' : (gen['legal_name'] ?? '—')),
                      KVRow('Pickup locality', gen['locality'] ?? '—'),
                      KVRow('Collector', b['assigned_collector_name'] ?? '—'),
                      KVRow('Recycler', b['destination_recycler_name'] ?? '—'),
                      KVRow('Listed', dateTime(b['created_at'])),
                    ]),
                  ),
                  Panel(
                    title: 'Pickup',
                    sub: 'Collected quantity is weighed by the collector and confirmed by the generator',
                    child: pickups.isEmpty
                        ? const Small('Not collected yet.', size: 13.5)
                        : Gap([
                            for (final r in pickups)
                              KV([
                                KVRow('Version ${r['version']}', r['is_current'] == true ? const Pill('Current', tone: Tone.ok) : const Pill('Superseded')),
                                KVRow('Collected', kg(dn(r['collected_kg']))),
                                KVRow('Generator rate', '${inr(dn(r['rate']))}/kg'),
                                KVRow('Handover method', r['handover_method'] ?? '—'),
                                KVRow('Generator confirmed', r['confirmed_at'] != null ? dateTime(r['confirmed_at']) : Text('Not yet', style: TextStyle(color: c.warn, fontSize: 13))),
                              ]),
                          ], gap: 12),
                  ),
                  Panel(
                    title: 'Transport',
                    child: cons == null
                        ? const Small('No consignment recorded.', size: 13.5)
                        : KV([KVRow('Consignment', cons['consignment_code']), KVRow('Vehicle', cons['vehicle_no'] ?? '—'), KVRow('Status', humanize(cons['status']))]),
                  ),
                  Panel(
                    title: 'Recycler receipt',
                    sub: 'Corrections add versions; earlier versions stay visible',
                    flush: true,
                    child: MiniTable(
                      headers: const ['Version', 'Received', 'Accepted', 'Rejected', 'Grade', 'Recorded'],
                      numeric: const {1, 2, 3},
                      emptyText: 'Not received yet.',
                      rows: [
                        for (final r in receipts)
                          [
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('v${r['version']} '),
                              r['is_current'] == true ? const Pill('Current', tone: Tone.ok) : const Pill('Superseded'),
                            ]),
                            numText(num1(dn(r['received_kg']))),
                            numText(num1(dn(r['accepted_kg']))),
                            numText(num1(dn(r['rejected_kg']))),
                            Text('${r['quality_grade']} · ${pct(dn(r['contamination_pct']))}'),
                            Small(dateTime(r['received_at'])),
                          ],
                      ],
                    ),
                  ),
                ]),
                Panel(
                  title: 'Processing',
                  sub: "This batch's share of each run; source batches stay individually traceable",
                  flush: true,
                  child: MiniTable(
                    headers: const ['Run', 'Started', 'Input from this batch', 'Recovered output share', 'Run yield', 'Output form', 'Measurement'],
                    numeric: const {2, 3, 4},
                    emptyText: 'Not processed yet.',
                    rows: [
                      for (final r in runs)
                        [
                          Mono(sn(r['record_code']) ?? ''),
                          Small(dateTime(r['run_started_at'])),
                          numText(kg(dn(r['input_kg']))),
                          numText(kg(dn(r['apportioned_output_kg']))),
                          numText(pct(dn(r['run_yield_pct']))),
                          Text(sn(r['output_form']) ?? '—'),
                          r['measurement_status'] == 'COMPLETE' ? const Pill('Complete', tone: Tone.ok) : Pill(humanize(r['measurement_status']), tone: Tone.warn),
                        ],
                    ],
                  ),
                ),
              ])
        ),
        (
          'Event timeline',
          () => Panel(
                title: 'Event timeline',
                sub: 'Append-only batch events',
                child: qView<List<J>>(s2, 'e', (ev) => EventTimeline(ev)),
              )
        ),
        (
          'NGO verification',
          () => Panel(
                title: 'NGO decision history',
                sub: 'Each decision adds a record; earlier decisions remain',
                child: Gap([
                  const Note(text: 'NGO verification is an independent, non-statutory review of the evidence on ReLoop. It is not EPR certification and does not make material EPR-eligible.'),
                  if (verifs.isEmpty)
                    const Small('No NGO review yet. Batches enter review when a recycler records their processing run.', size: 13.5)
                  else
                    for (final v in verifs)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(6)),
                        child: Wrap(alignment: WrapAlignment.spaceBetween, spacing: 8, runSpacing: 4, children: [
                          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Wrap(spacing: 8, children: [NgoPill(sn(v['decision'])), if (v['is_current'] == true) const TagChip('Current')]),
                            const SizedBox(height: 4),
                            Small('${v['ngo_name'] ?? '—'}${v['comments'] != null ? ' · ${v['comments']}' : ''}', color: c.fg2),
                          ]),
                          Small(dateTime(v['created_at'])),
                        ]),
                      ),
                ], gap: 10),
              )
        ),
        (
          'EPR & certificates',
          () => RGrid(minWidth: 380, maxCols: 2, gap: 16, children: [
                Panel(
                  title: 'EPR allocations',
                  sub: isEpr ? "Only your organisation's allocations are shown" : 'Contractual attributions recorded by the recycler',
                  flush: true,
                  footer: const Text('Run-level quantities. This batch\'s pro rata share is shown as "Allocated to EPR clients" above.'),
                  child: MiniTable(
                    headers: const ['Period', 'Category', 'Run allocation', 'Status', 'Recorded'],
                    numeric: const {2},
                    emptyText: "No allocations on this batch's runs.",
                    rows: [
                      for (final a in allocs)
                        [
                          Text(sn(a['reporting_period']) ?? ''),
                          Text(categoryLabel(a['packaging_category'])),
                          numText(kg(dn(a['quantity_kg']))),
                          a['is_reversal'] == true
                              ? const Pill('Reversal entry', tone: Tone.warn)
                              : (a['status'] == 'ACTIVE' ? const Pill('Active', tone: Tone.ok) : Pill(humanize(a['status']))),
                          Small(date(a['created_at'])),
                        ],
                    ],
                  ),
                ),
                Panel(
                  title: 'Certificate references',
                  sub: 'Entered by the recycler; generated on the CPCB portal, not by ReLoop',
                  child: certs.isEmpty
                      ? const Small('No certificate references recorded.', size: 13.5)
                      : Gap([
                          for (final ce in certs)
                            KV([
                              KVRow('Reference', Mono(sn(ce['certificate_ref']) ?? '')),
                              KVRow('Category', categoryLabel(ce['packaging_category'])),
                              KVRow('Quantity', kg(dn(ce['certificate_kg']))),
                              KVRow('Issued', ce['issued_on'] ?? '—'),
                              KVRow('Status on ReLoop', humanize(ce['status'])),
                            ]),
                        ]),
                ),
              ])
        ),
        (
          'Evidence & flags',
          () => RGrid(minWidth: 380, maxCols: 2, gap: 16, children: [
                Panel(
                  title: 'Documents',
                  sub: 'Metadata and SHA-256 as recorded by the backend',
                  child: Gap([
                    if (docs.isEmpty)
                      const Small('No documents linked to this batch.', size: 13.5)
                    else
                      for (final d in docs)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(6)),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${humanize(d['doc_type'])} · ${d['mime_type'] ?? '—'} · ${dateTime(d['created_at'])}', style: const TextStyle(fontSize: 13)),
                            SelectableText('sha256 ${d['sha256'] ?? 'not recorded'}', style: mono(context, size: 11, color: c.fg3)),
                          ]),
                        ),
                    const Note(text: 'The backend stores document metadata only; file storage is not connected yet.'),
                  ], gap: 8),
                ),
                Panel(
                  title: 'Anomaly flags',
                  child: anomalies.isEmpty
                      ? const Small('No anomalies raised for this batch.', size: 13.5)
                      : Gap([
                          for (final a in anomalies)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(border: Border.all(color: c.line), borderRadius: BorderRadius.circular(6)),
                              child: Row(children: [
                                Expanded(
                                  child: Wrap(spacing: 8, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                                    Text(humanize(a['rule_code']), style: const TextStyle(fontSize: 13)),
                                    Pill(sn(a['severity']) ?? '', tone: a['severity'] == 'HIGH' ? Tone.bad : Tone.warn),
                                  ]),
                                ),
                                a['status'] == 'OPEN' ? const Pill('Open', tone: Tone.bad) : Pill(humanize(a['status']), tone: Tone.ok),
                              ]),
                            ),
                        ], gap: 8),
                ),
              ])
        ),
      ]),
    ]);
  }
}
