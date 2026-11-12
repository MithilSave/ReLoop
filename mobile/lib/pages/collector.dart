import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/auth.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/quantities.dart';
import '../core/query.dart';
import '../features/photos.dart';
import '../ui/data_list.dart';
import '../ui/widgets.dart';
import 'generator.dart' show PaymentsTable, bcode, bstatus, numOf, sumAmount;

/// The backend returns the handover OTP only once, in the pickup response. Keep it on this device until confirmed.
final Map<String, String> _otps = <String, String>{};

List<J> myBatches(List<J> all) {
  final orgId = auth.org?['id'];
  return all.where((b) => b['assigned_collector_org_id'] == orgId).toList();
}

String recyclerName(List<J> recyclers, dynamic id) => sn(recyclers.where((r) => r['id'] == id).firstOrNull?['legal_name']) ?? '—';

/* ─────────────── Overview ─────────────── */
class CollectorOverview extends StatelessWidget {
  const CollectorOverview({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {
          'b': QDef(K.batchList(), () => Api.batches()),
          'c': QDef(K.consignments, Api.consignments),
          'p': QDef(K.plans, Api.plans),
        },
        builder: (context, q) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          PageHeader(
            title: 'Operations overview',
            description: 'Pickups to make, weights awaiting generator confirmation and loads on the road.',
            actions: [Btn('Record a pickup', icon: Icons.back_hand_outlined, onPressed: () => go('/c/pickup'))],
          ),
          qView<List<J>>(q, 'b', (all) {
            final mine = myBatches(all);
            final assigned = mine.where((b) => bstatus(b) == 'ASSIGNED' && !awaitingConfirmation(b)).toList();
            final awaiting = mine.where(awaitingConfirmation).toList();
            final onHand = mine.where((b) => bstatus(b) == 'PICKED_UP').toList();
            final openCons = q.list('c').where((c) => consStatus(c) != 'RECEIVED').toList();
            final proposed = q.list('p').where((p) => p['status'] == 'PROPOSED').length;
            return Gap([
              KpiGrid([
                Kpi(icon: Icons.assignment_turned_in_outlined, label: 'Pickups to make', value: '${assigned.length}', sub: '${kg(sumQ(assigned, 'estimated_kg'))} listed'),
                Kpi(icon: Icons.back_hand_outlined, label: 'Awaiting generator code', value: '${awaiting.length}', sub: '${kg(sumQ(awaiting, 'collected_kg'))} weighed'),
                Kpi(label: 'On hand, not dispatched', value: kg(sumQ(onHand, 'collected_kg')), sub: plural(onHand.length, 'batch', 'batches')),
                Kpi(icon: Icons.local_shipping_outlined, label: 'Consignments open', value: q.has('c') ? '${openCons.length}' : '…', sub: 'In transit or at recycler'),
              ]),
              if (onHand.isNotEmpty)
                Note(
                  child: Wrap(spacing: 6, children: [
                    Text('${onHand.length} collected batch${onHand.length > 1 ? 'es are' : ' is'} ready to dispatch.'),
                    LinkText('Create consignment', () => go('/c/consignments')),
                  ]),
                ),
              if (proposed > 0) Note(child: Wrap(spacing: 6, children: [const Text('There are proposed aggregation plans.'), LinkText('Review plans', () => go('/c/plans'))])),
              Panel(
                title: 'Assigned pickups',
                flush: true,
                child: DataList<J>(
                  label: 'Assigned pickups',
                  rows: [...awaiting, ...assigned],
                  rowKey: (b) => sn(b['id'])!,
                  onTap: (b) => go('/c/pickup?batch=${b['id']}'),
                  emptyTitle: 'No pickups assigned',
                  emptyBody: 'Make offers on available listings to get work.',
                  emptyAction: Btn('Browse listings', small: true, onPressed: () => go('/c/listings')),
                  cols: [
                    Col<J>('c', 'Batch', (b) => BatchLink(bcode(b))),
                    Col<J>('g', 'Generator', (b) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [Text(sn(b['generator_name']) ?? '—'), Small(sn(b['locality']) ?? '')])),
                    tcol<J>('m', 'Material', (b) => sn(b['material']) ?? '', sortable: false, hideOnMobile: true),
                    ncol<J>('e', 'Listed kg', (b) => bq(b, 'estimated_kg'), num1, sortable: false),
                    Col<J>('w', 'Window', (b) => Small(dateTime(b['available_from'])), hideOnMobile: true),
                    Col<J>('s', 'Next step', (b) => awaitingConfirmation(b) ? const Pill('Generator to confirm', tone: Tone.warn) : const Pill('Weigh & record', tone: Tone.info)),
                  ],
                ),
              ),
            ]);
          }),
        ]),
      );
}

/* ─────────────── Available listings ─────────────── */
class CollectorListings extends StatelessWidget {
  const CollectorListings({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {'l': QDef(K.available, Api.availableListings), 'm': QDef(K.materials, Api.materials)},
        builder: (context, q) {
          String matCode(dynamic id) => sn(q.list('m').where((m) => m['id'] == id).firstOrNull?['code']) ?? '#$id';
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const PageHeader(title: 'Available listings', description: 'Open listings from generators. Every row is a declared listing; predicted supply never appears here.'),
            Panel(
              flush: true,
              footer: const Foot('ReLoop API · /collections/available', note: 'Distance is shown only when both locations have coordinates.'),
              child: qView<List<J>>(q, 'l', (ls) {
                void open(J l) => showSheet(context, _OfferSheet(l, matCode(l['material_category_id'])));
                return DataList<J>(
                  label: 'Available listings',
                  rows: ls,
                  rowKey: (l) => sn(l['id'])!,
                  onTap: open,
                  sortKey: 'from',
                  search: (l) => '${l['batch_code']} ${l['locality'] ?? ''} ${l['pickup_address'] ?? ''}',
                  searchHint: 'Search area or batch',
                  filters: [
                    Flt<J>('m', 'Material', {for (final l in ls) '${l['material_category_id']}'}.map((id) => (id, matCode(int.tryParse(id) ?? id))).toList(), (l) => '${l['material_category_id']}'),
                  ],
                  emptyTitle: 'No open listings',
                  emptyBody: 'New listings appear here as generators publish them.',
                  cols: [
                    Col<J>('c', 'Listing', (l) => Mono(shortCode(sn(l['batch_code']) ?? ''), size: 12), sort: (l) => sn(l['batch_code'])),
                    Col<J>(
                      'loc',
                      'Area',
                      (l) => Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                        Text(sn(l['locality']) ?? '—'),
                        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 260), child: Small(sn(l['pickup_address']) ?? '', size: 11.5)),
                      ]),
                      sort: (l) => sn(l['locality']) ?? '',
                    ),
                    tcol<J>('m', 'Material', (l) => matCode(l['material_category_id'])),
                    ncol<J>('kg', 'Listed kg', (l) => dn(l['estimated_kg']), num1),
                    ncol<J>('d', 'Distance', (l) => dn(l['distance_km']), (v) => (v == null || v == 0) ? '—' : '${num1(v)} km', hideOnMobile: true),
                    Col<J>('from', 'Available', (l) => Small(dateTime(l['available_from'])), sort: (l) => sn(l['available_from']), hideOnMobile: true),
                    Col<J>('x', '', (l) => Btn('Make offer', small: true, kind: BtnKind.outline, onPressed: () => open(l))),
                  ],
                );
              }),
            ),
          ]);
        },
      );
}

class _OfferSheet extends StatefulWidget {
  final J l;
  final String material;
  const _OfferSheet(this.l, this.material);
  @override
  State<_OfferSheet> createState() => _OfferSheetState();
}

class _OfferSheetState extends State<_OfferSheet> {
  final _rate = TextEditingController();
  late DateTime _when;
  String? _rateErr;
  ApiError? _err;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final from = parseIso(widget.l['available_from']) ?? DateTime.now();
    final soon = DateTime.now().add(const Duration(hours: 1));
    _when = from.isAfter(soon) ? from : soon;
  }

  @override
  void dispose() {
    _rate.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final v = _rate.text.trim();
    final n = numOf(v);
    if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v) || n == null || n <= 0 || n >= 200) {
      setState(() => _rateErr = 'Enter a rate between ₹0 and ₹200 per kg');
      return;
    }
    setState(() {
      _rateErr = null;
      _err = null;
      _busy = true;
    });
    final id = sn(widget.l['id'])!;
    final r = await mutate(
      () => Api.makeOffer(id, {'generator_rate_per_kg': n, 'proposed_pickup_at': toIsoUtc(_when)}),
      invalidate: [K.available, K.offers(id)],
      success: (_) => 'Offer sent to the generator',
      onError: (e) => _err = e,
      toastErrors: false,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l = widget.l;
    final est = dn(l['estimated_kg']) ?? 0;
    final rate = numOf(_rate.text) ?? 0;
    return SheetScaffold(
      title: 'Make an offer',
      description: '${l['batch_code']} · ${kg(est)} ${widget.material} · ${l['locality'] ?? ''}',
      actions: [Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)), Btn('Send offer', loading: _busy, onPressed: _send)],
      children: [
        RGrid(minWidth: 220, maxCols: 2, gap: 16, children: [
          Field(label: 'Rate paid to generator (₹/kg)', required: true, error: _rateErr, child: In(_rate, decimal: true, hasError: _rateErr != null, onChanged: (_) => setState(() {}))),
          Field(label: 'Proposed pickup', required: true, child: DateTimeIn(value: _when, onChanged: (d) => setState(() => _when = d))),
        ]),
        KV([
          KVRow('Generator payment at listed weight', rate > 0 ? inr(rate * est) : '—'),
          KVRow('Pickup window', '${dateTime(l['available_from'])} – ${dateTime(l['available_to'])}'),
        ]),
        const Note(text: 'The generator is paid on the weight you record at pickup. Rejections at the recycler are your risk.'),
        if (_err != null) Note(tone: Tone.bad, title: _err!.code == 'DUPLICATE_OFFER' ? 'You already have an open offer on this listing' : 'Offer not sent', text: _err!.message),
      ],
    );
  }
}

/* ─────────────── Assignments ─────────────── */
class CollectorAssignments extends StatelessWidget {
  const CollectorAssignments({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(title: 'Collection assignments', description: 'Every batch assigned to you, from accepted offer to delivery.'),
        Panel(
          flush: true,
          child: QueryView<List<J>>(
            qk: K.batchList(),
            fetch: () => Api.batches(),
            builder: (context, all) => DataList<J>(
              label: 'Assignments',
              rows: myBatches(all),
              rowKey: (b) => sn(b['id'])!,
              onTap: (b) => openPassport(bcode(b)),
              sortKey: 'c',
              sortAsc: false,
              search: (b) => '${bcode(b)} ${b['generator_name'] ?? ''}',
              searchHint: 'Search batch or generator',
              filters: [Flt<J>('s', 'Status', [for (final s in ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'RECEIVED', 'PROCESSED']) (s, humanize(s))], (b) => bstatus(b) ?? '')],
              emptyTitle: 'No assignments yet',
              cols: [
                Col<J>('c', 'Batch', (b) => BatchLink(bcode(b)), sort: (b) => sn(b['created_at'])),
                tcol<J>('g', 'Generator', (b) => sn(b['generator_name']) ?? '—'),
                tcol<J>('m', 'Material', (b) => sn(b['material']) ?? '', sortable: false),
                ncol<J>('e', 'Listed', (b) => bq(b, 'estimated_kg'), num1, sortable: false),
                ncol<J>('col', 'Collected', (b) => bq(b, 'collected_kg'), num1),
                ncol<J>('r', 'Received', (b) => bq(b, 'received_kg'), num1, sortable: false),
                ncol<J>('a', 'Accepted', (b) => bq(b, 'accepted_kg'), num1, sortable: false),
                Col<J>('s', 'Status', (b) => awaitingConfirmation(b) ? const Pill('Awaiting generator code', tone: Tone.warn) : BatchStatusPill(bstatus(b)), sort: (b) => bstatus(b)),
              ],
            ),
          ),
        ),
      ]);
}

/* ─────────────── Pickup verification ─────────────── */
class CollectorPickup extends StatefulWidget {
  final String? batchId;
  const CollectorPickup({super.key, this.batchId});
  @override
  State<CollectorPickup> createState() => _CollectorPickupState();
}

class _CollectorPickupState extends State<CollectorPickup> {
  String? _sel;
  @override
  void initState() {
    super.initState();
    _sel = widget.batchId;
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(title: 'Pickup verification', description: 'Weigh the material, photograph the scale, then read the handover code to the generator.'),
        QueryView<List<J>>(
          qk: K.batchList(),
          fetch: () => Api.batches(),
          builder: (context, all) {
            final cand = myBatches(all).where((b) => bstatus(b) == 'ASSIGNED').toList();
            if (cand.isEmpty) {
              return Panel(
                child: EmptyState(
                  title: 'No pickups waiting',
                  body: 'Batches assigned to you appear here until the generator confirms the handover.',
                  action: Btn('Browse listings', small: true, onPressed: () => go('/c/listings')),
                ),
              );
            }
            final sel = cand.where((b) => b['id'] == _sel).firstOrNull ?? cand.first;
            return Gap([
              Field(
                label: 'Batch',
                child: Sel<String>(
                  value: sn(sel['id']),
                  items: [
                    for (final b in cand)
                      (sn(b['id'])!, '${bcode(b)} · ${b['generator_name']} · ${awaitingConfirmation(b) ? 'awaiting confirmation' : '${kg(bq(b, 'estimated_kg'))} listed'}'),
                  ],
                  onChanged: (v) => setState(() => _sel = v),
                ),
              ),
              _PickupForm(sel, key: ValueKey(sel['id'])),
            ]);
          },
        ),
      ]);
}

class _PickupForm extends StatefulWidget {
  final J b;
  const _PickupForm(this.b, {super.key});
  @override
  State<_PickupForm> createState() => _PickupFormState();
}

class _PickupFormState extends State<_PickupForm> {
  final _kg = TextEditingController();
  final _notes = TextEditingController();
  RegisteredDoc? _photo;
  bool _photoBusy = false;
  String? _kgErr, _notesErr, _photoErr;
  ApiError? _err;
  bool _busy = false;
  String? _otp;

  @override
  void initState() {
    super.initState();
    _otp = _otps[sn(widget.b['id'])];
  }

  @override
  void dispose() {
    _kg.dispose();
    _notes.dispose();
    super.dispose();
  }

  double get _est => bq(widget.b, 'estimated_kg') ?? 0;

  Future<void> _submit() async {
    final ke = kgError(_kg.text, label: 'Weight');
    String? ne;
    if (ke == null && _est != 0) {
      final d = ((double.parse(_kg.text.trim()) - _est) / _est * 100).abs();
      if (d > 20 && _notes.text.trim().length < 5) ne = 'Explain why the weight differs from the listing by more than 20%';
    }
    if (_notes.text.length > 500) ne = 'At most 500 characters';
    setState(() {
      _kgErr = ke;
      _notesErr = ne;
      _photoErr = _photo == null ? 'Add a photo that shows the scale reading' : null;
    });
    if (ke != null || ne != null || _photo == null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final id = sn(widget.b['id'])!;
    final r = await mutate(
      () => Api.recordPickup(id, {
        'collected_kg': double.parse(_kg.text.trim()),
        if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
        'document_ids': [_photo!.id],
      }),
      invalidate: [K.batches, K.jobs],
      toastErrors: false,
      success: (_) => 'Weight recorded. Read the code to the generator.',
      onError: (e) => _err = e,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null && r['otp'] != null) {
        _otp = sn(r['otp']);
        _otps[id] = _otp!;
      }
    });
  }

  Future<void> _pick() async {
    setState(() {
      _photoBusy = true;
      _photoErr = null;
    });
    final d = await pickAndRegister(context, 'PHOTO_PICKUP');
    if (!mounted) return;
    setState(() {
      _photoBusy = false;
      if (d != null) _photo = d;
    });
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final c = context.c;
    final kgv = numOf(_kg.text);
    final dev = (kgv != null && kgv > 0 && _est != 0) ? (kgv - _est) / _est * 100 : null;
    if (_otp != null || awaitingConfirmation(b)) {
      return Panel(
        title: 'Handover code',
        sub: '${bcode(b)} · ${b['generator_name'] ?? ''}',
        child: Gap([
          Text('Weight recorded: ${kg(bq(b, 'collected_kg') ?? kgv)}. Read this code to the generator. They enter it in their app to confirm the weight.',
              textAlign: TextAlign.center, style: TextStyle(fontSize: 13, color: c.fg2)),
          if (_otp != null)
            Semantics(
              label: 'Handover code ${_otp!.split('').join(' ')}',
              child: Center(child: SelectableText(_otp!, style: mono(context, size: 36, color: c.brand, weight: FontWeight.w600).copyWith(letterSpacing: 12))),
            )
          else
            const Note(
                tone: Tone.warn,
                text: 'The code was shown once, on the device that recorded the weight. The backend has no endpoint to show it again, so use that device to read it to the generator.'),
          const Center(child: Pill('Awaiting generator confirmation', tone: Tone.warn)),
          const Note(text: 'Recording a second weight is blocked until the generator confirms (backend guard). The collected quantity becomes final when they enter the code.'),
        ], gap: 12),
      );
    }
    return Panel(
      title: 'Record handover',
      sub: '${bcode(b)} · ${b['generator_name'] ?? ''} · ${b['locality'] ?? ''}',
      footer: Wrap(alignment: WrapAlignment.end, spacing: 8, runSpacing: 8, children: [Btn('Record weight & code', loading: _busy, onPressed: _submit)]),
      child: Gap([
        RGrid(minWidth: 260, maxCols: 2, gap: 16, children: [
          Field(
            label: 'Weight on your scale (kg)',
            required: true,
            error: _kgErr,
            hint: dev != null ? '${dev >= 0 ? '+' : ''}${pct(dev)} vs listed ${kg(_est)} · ${dev.abs() > 20 ? 'note required' : 'within ±20%'}' : 'Listed ${kg(_est)}',
            child: In(_kg, decimal: true, big: true, hasError: _kgErr != null, onChanged: (_) => setState(() {})),
          ),
          Field(
            label: 'Scale photo',
            required: true,
            error: _photoErr,
            hint: 'SHA-256 recorded; the image file is not stored by the backend yet.',
            child: PhotoBox(text: _photo?.name ?? 'Take or choose a photo', busy: _photoBusy, hasError: _photoErr != null, height: 52, onTap: _pick),
          ),
        ]),
        Field(
          label: 'Notes',
          required: dev != null && dev.abs() > 20,
          error: _notesErr,
          child: In(_notes, maxLines: 2, placeholder: 'e.g. generator added two extra bags', hasError: _notesErr != null),
        ),
        if (_err != null) Note(tone: Tone.bad, title: 'Weight not recorded', text: _err!.message),
      ]),
    );
  }
}

/* ─────────────── Consignments ─────────────── */

/// Batches of one consignment with their weights at each stage. Shared with the recycler's Incoming screen.
class ConsignmentDetail extends StatelessWidget {
  final J consignment;
  final String? recyclerName;
  const ConsignmentDetail({super.key, required this.consignment, this.recyclerName});

  @override
  Widget build(BuildContext context) {
    final cn = consignment;
    return Gap([
      KV([
        KVRow('Consignment', cn['consignment_code']),
        KVRow('Destination', recyclerName ?? '—'),
        KVRow('Vehicle', cn['vehicle_no'] ?? '—'),
        KVRow('Dispatched', dateTime(cn['dispatched_at'])),
        KVRow('Arrived', dateTime(cn['arrived_at'])),
        KVRow('Status', StatusPill(consStatus(cn), kConsStatus)),
      ]),
      const Note(text: 'Batches travel together but are weighed and recorded individually at receipt. They are never merged.'),
      Panel(
        title: 'Batches',
        flush: true,
        child: QueryView<List<J>>(
          qk: K.batchList(),
          fetch: () => Api.batches(),
          builder: (context, all) => MiniTable(
            headers: const ['Batch', 'Collected', 'Received', 'Accepted', 'Status'],
            numeric: const {1, 2, 3},
            rows: [
              for (final it in jl(cn['items']))
                () {
                  final b = all.where((x) => x['id'] == it['batch_id']).firstOrNull;
                  return [
                    BatchLink(sn(it['batch_code']) ?? ''),
                    numText(num1(b == null ? null : bq(b, 'collected_kg'))),
                    numText(num1(b == null ? null : bq(b, 'received_kg'))),
                    numText(num1(b == null ? null : bq(b, 'accepted_kg'))),
                    BatchStatusPill(sn(b?['status']) ?? sn(it['status'])),
                  ];
                }(),
            ],
          ),
        ),
      ),
    ]);
  }
}

class CollectorConsignments extends StatelessWidget {
  const CollectorConsignments({super.key});
  @override
  Widget build(BuildContext context) => Queries(
        queries: {
          'c': QDef(K.consignments, Api.consignments),
          'b': QDef(K.batchList(), () => Api.batches()),
          'r': QDef(K.orgs('RECYCLER'), () => Api.orgs('RECYCLER')),
        },
        builder: (context, q) {
          final onHand = myBatches(q.list('b')).where((b) => bstatus(b) == 'PICKED_UP').toList();
          final recs = q.list('r');
          return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            PageHeader(
              title: 'Transport consignments',
              description: 'Group collected batches into one vehicle trip. Only batches whose handover the generator has confirmed can be dispatched.',
              actions: [
                Btn('New consignment',
                    icon: Icons.local_shipping_outlined,
                    tooltip: onHand.isEmpty ? 'No confirmed pickups to dispatch' : null,
                    onPressed: onHand.isEmpty ? null : () => showSheet(context, _NewConsignmentSheet(onHand), wide: true)),
              ],
            ),
            if (q.has('b') && onHand.isEmpty)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Note(text: 'No batches are ready to dispatch. A batch becomes dispatchable after the generator confirms the handover.'),
              ),
            Panel(
              flush: true,
              child: qView<List<J>>(
                q,
                'c',
                (cs) => DataList<J>(
                  label: 'Consignments',
                  rows: cs,
                  rowKey: (c) => sn(c['id'])!,
                  onTap: (c) => showSheet(
                    context,
                    SheetScaffold(
                      title: 'Consignment ${c['consignment_code']}',
                      children: [ConsignmentDetail(consignment: c, recyclerName: recyclerName(recs, c['destination_recycler_org_id']))],
                    ),
                    wide: true,
                  ),
                  sortKey: 'd',
                  sortAsc: false,
                  filters: [Flt<J>('s', 'Status', kConsStatus.entries.map((e) => (e.key, e.value.$2)).toList(), (c) => consStatus(c))],
                  emptyTitle: 'No consignments yet',
                  cols: [
                    Col<J>('c', 'Consignment', (c) => Mono(sn(c['consignment_code']) ?? '', size: 12), sort: (c) => sn(c['consignment_code'])),
                    Col<J>('d', 'Dispatched', (c) => Small(dateTime(c['dispatched_at'])), sort: (c) => sn(c['dispatched_at'])),
                    tcol<J>('to', 'Destination', (c) => recyclerName(recs, c['destination_recycler_org_id']), sortable: false),
                    Col<J>('n', 'Batches', (c) => numText('${jl(c['items']).length}'), numeric: true, sort: (c) => jl(c['items']).length),
                    Col<J>('v', 'Vehicle', (c) => Mono(sn(c['vehicle_no']) ?? '—', size: 12)),
                    Col<J>('s', 'Status', (c) => StatusPill(consStatus(c), kConsStatus), sort: (c) => consStatus(c)),
                  ],
                ),
              ),
            ),
          ]);
        },
      );
}

class _NewConsignmentSheet extends StatefulWidget {
  final List<J> batches;
  const _NewConsignmentSheet(this.batches);
  @override
  State<_NewConsignmentSheet> createState() => _NewConsignmentSheetState();
}

class _NewConsignmentSheetState extends State<_NewConsignmentSheet> {
  late final Set<String> _sel = widget.batches.map((b) => sn(b['id'])!).toSet();
  String? _dest;
  final _veh = TextEditingController();
  String? _destErr, _vehErr;
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    _veh.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _destErr = _dest == null ? 'Choose a recycler' : null;
      _vehErr = _veh.text.trim().length > 32 ? 'At most 32 characters' : null;
    });
    if (_destErr != null || _vehErr != null) return;
    setState(() {
      _busy = true;
      _err = null;
    });
    final r = await mutate(
      () => Api.createConsignment({
        'batch_ids': _sel.toList(),
        'destination_recycler_org_id': _dest,
        if (_veh.text.trim().isNotEmpty) 'vehicle_no': _veh.text.trim(),
      }),
      invalidate: [K.consignments, K.batches, K.incoming],
      success: (c) => '${c['consignment_code']} dispatched with ${plural(jl(c['items']).length, 'batch', 'batches')}',
      onError: (e) => _err = e,
      toastErrors: false,
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (r != null) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final n = _sel.length;
    return SheetScaffold(
      title: 'New consignment',
      description: 'Select the batches loaded on this vehicle. Each batch keeps its own record and is weighed separately at receipt.',
      actions: [
        Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)),
        Btn('Dispatch ${plural(n, 'batch', 'batches')}', loading: _busy, onPressed: n == 0 ? null : _send),
      ],
      children: [
        Container(
          decoration: BoxDecoration(border: Border.all(color: context.c.line), borderRadius: BorderRadius.circular(6)),
          child: MiniTable(
            headers: const ['', 'Batch', 'Material', 'Collected kg'],
            numeric: const {3},
            rows: [
              for (final b in widget.batches)
                [
                  Checkbox(
                    value: _sel.contains(b['id']),
                    onChanged: (v) => setState(() => v == true ? _sel.add(sn(b['id'])!) : _sel.remove(b['id'])),
                    semanticLabel: 'Include ${bcode(b)}',
                  ),
                  Mono(bcode(b), size: 12),
                  Text(sn(b['material']) ?? ''),
                  numText(num1(bq(b, 'collected_kg'))),
                ],
            ],
          ),
        ),
        QueryView<List<J>>(
          qk: K.orgs('RECYCLER'),
          fetch: () => Api.orgs('RECYCLER'),
          builder: (context, recs) => RGrid(minWidth: 240, maxCols: 2, gap: 16, children: [
            Field(
              label: 'Destination recycler',
              required: true,
              error: _destErr,
              hint: 'Approved recyclers from the ReLoop directory',
              child: Sel<String>(
                value: _dest,
                placeholder: 'Select recycler',
                hasError: _destErr != null,
                items: [
                  for (final r in recs)
                    (sn(r['id'])!, '${r['legal_name']}${jo(r['registration'])?['pwp_registration_no'] != null ? ' · ${jo(r['registration'])!['pwp_registration_no']}' : ''}'),
                ],
                onChanged: (v) => setState(() => _dest = v),
              ),
            ),
            Field(label: 'Vehicle number', error: _vehErr, child: In(_veh, placeholder: 'MH-02-AB-1234')),
          ]),
        ),
        if (_err != null) Note(tone: Tone.bad, title: 'Not dispatched', text: _err!.message),
      ],
    );
  }
}

/* ─────────────── Aggregation plans (shared with the recycler) ─────────────── */
class PlanDetailView extends StatefulWidget {
  final String id;
  final bool canAct;
  const PlanDetailView({super.key, required this.id, this.canAct = true});
  @override
  State<PlanDetailView> createState() => _PlanDetailViewState();
}

class _PlanDetailViewState extends State<PlanDetailView> {
  bool _accepting = false, _cancelling = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    await mutate(() => Api.acceptPlan(widget.id), invalidate: [K.plans], success: (d) => 'Plan ${humanize(d['plan_status']).toLowerCase()}');
    if (mounted) setState(() => _accepting = false);
  }

  Future<void> _cancel() async {
    setState(() => _cancelling = true);
    await mutate(() => Api.cancelPlan(widget.id), invalidate: [K.plans, K.batches, K.available], success: (_) => 'Plan cancelled; batches released');
    if (mounted) setState(() => _cancelling = false);
  }

  @override
  Widget build(BuildContext context) => QueryView<J>(
        qk: K.plan(widget.id),
        fetch: () => Api.plan(widget.id),
        builder: (context, p) {
          final ce = jo(p['cost_estimate']);
          final usable = dn(p['est_usable_kg']) ?? 0;
          final target = dn(p['target_kg']) ?? 0;
          return Gap([
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [Mono(sn(p['plan_code']) ?? '', weight: FontWeight.w600, size: 14), StatusPill(sn(p['status']), kPlanStatus)]),
            KpiGrid([
              Kpi(label: 'Target', value: kg(target)),
              Kpi(label: 'Listed in plan', value: kg(dn(p['est_total_kg']))),
              Kpi(label: 'Expected usable', value: kg(usable), sub: 'Backend model: fixed 92%'),
              Kpi(label: 'Shortfall', value: kg(dn(p['shortfall_kg'])), sub: p['fulfils_requirement'] == true ? 'Listed kg meets target' : 'Not enough listings'),
            ]),
            if (p['fulfils_requirement'] == true && usable < target)
              Note(tone: Tone.warn, text: 'The backend marks this plan as meeting the target because listed kg ≥ target. Expected usable kg (${kg(usable)}) is below target.'),
            Panel(
              title: 'Source batches',
              sub: 'Each batch stays individually traceable',
              flush: true,
              child: DataList<J>(
                label: 'Plan items',
                rows: jl(p['items']),
                rowKey: (i) => sn(i['batch_id'])!,
                cols: [
                  Col<J>('c', 'Batch', (i) => BatchLink(sn(i['batch_code']) ?? '')),
                  ncol<J>('p', 'Planned kg', (i) => dn(i['planned_kg']), num1, sortable: false),
                  ncol<J>('u', 'Est. usable kg', (i) => dn(i['est_usable_kg']), num1, sortable: false),
                  ncol<J>('d', 'Distance', (i) => dn(i['distance_km']), (v) => '${num1(v)} km', sortable: false),
                  tcol<J>('s', 'Item status', (i) => humanize(i['item_status']), sortable: false),
                ],
              ),
            ),
            if (ce != null)
              Panel(
                title: 'Cost estimate',
                sub: 'Backend model with fixed rates; not based on your pricing assumptions',
                child: KV([
                  for (final e in (jo(ce['breakdown']) ?? const <String, dynamic>{}).entries) KVRow(humanize(e.key), inr(dn(e.value))),
                  KVRow('Total', inr(dn(ce['total_cost'])), total: true),
                  KVRow('Per usable kg', inr(dn(ce['landed_cost_per_usable_kg'])), total: true),
                ]),
              ),
            if (widget.canAct && ['PROPOSED', 'ACCEPTED'].contains(p['status']))
              Wrap(spacing: 8, runSpacing: 8, children: [
                Btn('Accept plan', loading: _accepting, onPressed: _accept),
                Btn('Cancel plan', kind: BtnKind.destructive, loading: _cancelling, onPressed: _cancel),
              ]),
            const Note(
                text:
                    'Accepting a plan records your agreement. It does not assign the batches to you; each batch is still collected through the normal offer and handover flow (backend behaviour).'),
          ]);
        },
      );
}

void openPlan(BuildContext context, String id, String code) =>
    showSheet(context, SheetScaffold(title: 'Plan $code', children: [PlanDetailView(id: id)]), wide: true);

class PlansTable extends StatelessWidget {
  final List<J> rows;
  const PlansTable(this.rows, {super.key});
  @override
  Widget build(BuildContext context) => DataList<J>(
        label: 'Aggregation plans',
        rows: rows,
        rowKey: (p) => sn(p['id'])!,
        onTap: (p) => openPlan(context, sn(p['id'])!, sn(p['plan_code']) ?? ''),
        sortKey: 'd',
        sortAsc: false,
        filters: [Flt<J>('s', 'Status', kPlanStatus.entries.map((e) => (e.key, e.value.$2)).toList(), (p) => sn(p['status']) ?? '')],
        emptyTitle: 'No aggregation plans',
        cols: [
          Col<J>('c', 'Plan', (p) => Mono(sn(p['plan_code']) ?? '', size: 12), sort: (p) => sn(p['plan_code'])),
          Col<J>('d', 'Created', (p) => Small(date(p['created_at'])), sort: (p) => sn(p['created_at'])),
          ncol<J>('t', 'Target kg', (p) => dn(p['target_kg']), num1),
          ncol<J>('e', 'Listed kg', (p) => dn(p['est_total_kg']), num1, sortable: false),
          ncol<J>('u', 'Expected usable', (p) => dn(p['est_usable_kg']), num1, sortable: false),
          Col<J>('s', 'Status', (p) => StatusPill(sn(p['status']), kPlanStatus), sort: (p) => sn(p['status'])),
        ],
      );
}

class CollectorPlans extends StatelessWidget {
  const CollectorPlans({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(
            title: 'Aggregation plans',
            description: 'Recyclers group small listings into one feedstock order. A plan becomes active once both the recycler and a collector accept it.'),
        const Note(text: 'Plans do not name a collector in the backend, so every plan is visible here.'),
        const SizedBox(height: 16),
        Panel(flush: true, child: QueryView<List<J>>(qk: K.plans, fetch: Api.plans, builder: (context, ps) => PlansTable(ps))),
      ]);
}

/* ─────────────── Delivery records ─────────────── */
class CollectorDeliveries extends StatelessWidget {
  const CollectorDeliveries({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    double? transit(J b) {
      final col = bq(b, 'collected_kg'), rec = bq(b, 'received_kg');
      if (col == null || rec == null || col == 0) return null;
      return (rec - col) / col * 100;
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(
          title: 'Delivery records', description: 'What recyclers recorded for each batch you delivered. Differences above 2% between collected and received weight are highlighted.'),
      Panel(
        flush: true,
        footer: const SourceLine('ReLoop API · /batches (receipt quantities)'),
        child: QueryView<List<J>>(
          qk: K.batchList(),
          fetch: () => Api.batches(),
          builder: (context, all) => DataList<J>(
            label: 'Delivery records',
            rows: myBatches(all).where((b) => bq(b, 'received_kg') != null).toList(),
            rowKey: (b) => sn(b['id'])!,
            emptyTitle: 'No deliveries recorded yet',
            cols: [
              Col<J>('c', 'Batch', (b) => BatchLink(bcode(b)), sort: (b) => bcode(b)),
              tcol<J>('r', 'Recycler', (b) => sn(b['destination_recycler_name']) ?? '—', sortable: false),
              ncol<J>('col', 'Collected', (b) => bq(b, 'collected_kg'), num1, sortable: false),
              ncol<J>('rec', 'Received', (b) => bq(b, 'received_kg'), num1, sortable: false),
              Col<J>('v', 'Transit variance', (b) {
                final v = transit(b);
                if (v == null) return numText('—');
                return numText('${v >= 0 ? '+' : ''}${pct(v)}', bold: v.abs() > 2, color: v.abs() > 2 ? c.bad : null);
              }, numeric: true, sort: (b) => transit(b)?.abs()),
              ncol<J>('a', 'Accepted', (b) => bq(b, 'accepted_kg'), num1, sortable: false),
              ncol<J>('x', 'Rejected', (b) => bq(b, 'rejected_kg'), num1, sortable: false),
              Col<J>('s', 'Status', (b) => BatchStatusPill(bstatus(b))),
            ],
          ),
        ),
      ),
    ]);
  }
}

/* ─────────────── Payments & earnings ─────────────── */
class CollectorTransactions extends StatefulWidget {
  const CollectorTransactions({super.key});
  @override
  State<CollectorTransactions> createState() => _CollectorTransactionsState();
}

class _CollectorTransactionsState extends State<CollectorTransactions> {
  String? _paying;
  final _ref = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _ref.dispose();
    super.dispose();
  }

  Future<void> _markPaid() async {
    setState(() => _busy = true);
    final r = await mutate(() => Api.markPaid(_paying!, _ref.text.trim()), invalidate: [K.payments], success: (_) => 'Payment marked as paid');
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (r != null) {
        _paying = null;
        _ref.clear();
      }
    });
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(
            title: 'Payments & earnings', description: 'Generator payouts you owe for confirmed handovers. Mark a payout as paid once you have transferred it.'),
        const Note(
            tone: Tone.warn, text: 'The backend records generator payouts only. Collector earnings from recyclers are not modelled yet, so no earnings figures are shown.'),
        const SizedBox(height: 16),
        QueryView<List<J>>(
          qk: K.payments,
          fetch: Api.payments,
          builder: (context, ps) {
            final pending = ps.where((p) => p['status'] == 'PENDING').toList();
            return Gap([
              KpiGrid([
                Kpi(label: 'Owed to generators', value: inr(sumAmount(pending)), sub: '${pending.length} pending'),
                Kpi(label: 'Paid to generators', value: inr(sumAmount(ps.where((p) => p['status'] == 'PAID')))),
              ], cols: 3),
              Panel(flush: true, footer: const SourceLine('ReLoop API · /payments (simulated ledger; no money moves)'), child: PaymentsTable(rows: ps, payee: false)),
              if (pending.isNotEmpty)
                Panel(
                  title: 'Settle a payout',
                  child: RGrid(minWidth: 240, maxCols: 3, gap: 12, children: [
                    Field(
                      label: 'Payout',
                      child: Sel<String>(
                        value: _paying,
                        placeholder: 'Select pending payout',
                        items: [for (final p in pending) (sn(p['id'])!, '${inr(dn(p['amount']))} · ${num1(dn(p['quantity_kg']))} kg · ${date(p['created_at'])}')],
                        onChanged: (v) => setState(() => _paying = v),
                      ),
                    ),
                    Field(label: 'Transfer reference (UPI / bank)', child: In(_ref, placeholder: 'UPI ref no.', onChanged: (_) => setState(() {}))),
                    Padding(
                      padding: const EdgeInsets.only(top: 22),
                      child: Btn('Mark as paid', loading: _busy, onPressed: (_paying == null || _ref.text.trim().length < 4) ? null : _markPaid),
                    ),
                  ]),
                ),
            ]);
          },
        ),
      ]);
}

/* ─────────────── Performance ─────────────── */
String perfFmt(dynamic raw) {
  final v = dn(raw);
  if (v == null) return '—';
  return pct(v <= 1 ? v * 100 : v);
}

Tone historyTone(dynamic level) => level == 'SUFFICIENT' ? Tone.ok : (level == 'LIMITED' ? Tone.warn : Tone.neutral);

class CollectorPerformance extends StatelessWidget {
  const CollectorPerformance({super.key});
  @override
  Widget build(BuildContext context) {
    final id = sn(auth.org?['id']) ?? '';
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(
          title: 'Performance', description: 'Rule-based indicators recyclers see when they review your work. Each is shown with the number of transactions behind it.'),
      QueryView<J>(
        qk: K.perf(id),
        fetch: () => Api.supplierPerformance(id),
        builder: (context, p) {
          final n = (dn(p['n_transactions']) ?? 0).toInt();
          return Gap([
            Wrap(spacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
              Pill('${humanize(p['history_level'])} history', tone: historyTone(p['history_level'])),
              Small('n = $n', size: 13.5, color: context.c.fg2),
            ]),
            if (n == 0)
              const Panel(child: EmptyState(title: 'Not enough history', body: 'Indicators appear once the backend has computed metrics for your organisation.'))
            else
              KpiGrid([
                Kpi(label: 'Fulfilment', value: perfFmt(p['fulfilment_rate'])),
                Kpi(label: 'On-time pickup', value: perfFmt(p['on_time_rate'])),
                Kpi(label: 'Weight discrepancy', value: perfFmt(p['weight_discrepancy_pct'])),
                Kpi(label: 'Rejection at receipt', value: perfFmt(p['rejection_rate'])),
                Kpi(label: 'Contamination', value: perfFmt(p['contamination_rate'])),
                Kpi(label: 'Completion', value: perfFmt(p['completion_rate'])),
              ], cols: 3),
            const SourceLine('ReLoop API · /suppliers/{org}/performance'),
          ]);
        },
      ),
    ]);
  }
}
