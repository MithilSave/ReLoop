import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/format.dart';
import '../core/nav.dart';
import '../core/quantities.dart';
import '../core/query.dart';
import '../features/ai_detect.dart';
import '../features/photos.dart';
import '../ui/charts.dart';
import '../ui/data_list.dart';
import '../ui/widgets.dart';

const String _src = 'ReLoop API · /batches';

String bcode(J b) => sn(b['batch_code']) ?? '';
String? bstatus(J b) => sn(b['status']);

/// Parses a typed decimal, or null when empty/invalid.
double? numOf(String s) => double.tryParse(s.trim());

/// Columns shared by the generator's batch tables (same order as the web app).
List<Col<J>> batchCols() => [
      Col<J>('code', 'Batch', (b) => BatchLink(bcode(b)), sort: (b) => bcode(b)),
      tcol<J>('mat', 'Material', (b) => sn(b['material']) ?? ''),
      Col<J>('listed', 'Listed', (b) => Small(date(b['created_at'])), sort: (b) => sn(b['created_at'])),
      ncol<J>('est', 'Listed kg', (b) => bq(b, 'estimated_kg'), num1),
      ncol<J>('col', 'Collected kg', (b) => bq(b, 'collected_kg'), num1),
      ncol<J>('acc', 'Accepted kg', (b) => bq(b, 'accepted_kg'), num1),
      ncol<J>('out', 'Recovered kg', (b) => bq(b, 'processed_kg'), num1),
      Col<J>('st', 'Status', (b) => awaitingConfirmation(b) ? const Pill('Confirm handover', tone: Tone.warn) : BatchStatusPill(bstatus(b)), sort: (b) => bstatus(b)),
      Col<J>('ngo', 'NGO review', (b) => NgoPill(decisionOf(b)), sort: (b) => decisionOf(b) ?? ''),
    ];

QDef batchesQ([String? status]) => QDef(K.batchList(status), () => Api.batches(status: status));

/* ─────────────── Overview ─────────────── */
class GeneratorOverview extends StatelessWidget {
  const GeneratorOverview({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Queries(
      queries: {'b': batchesQ(), 'p': QDef(K.payments, Api.payments)},
      builder: (context, q) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        PageHeader(
          title: 'Overview',
          description: 'Your plastic listings, handovers and what happened to every kilogram after it left your premises.',
          actions: [Btn('Create listing', icon: Icons.add, onPressed: () => go('/g/listings/new'))],
        ),
        qView<List<J>>(q, 'b', (bs) {
          final confirm = bs.where(awaitingConfirmation).toList();
          final open = bs.where((b) => bstatus(b) == 'LISTED').toList();
          final live = bs.where((b) => bstatus(b) != 'CANCELLED').toList();
          final pays = q.list('p');
          final paid = pays.where((p) => p['status'] == 'PAID').fold<double>(0, (s, p) => s + (dn(p['amount']) ?? 0));
          final pending = pays.where((p) => p['status'] == 'PENDING').fold<double>(0, (s, p) => s + (dn(p['amount']) ?? 0));
          final verified = bs.fold<double>(0, (s, b) => s + (verifiedKg(jo(b['quantities']) ?? {}, decisionOf(b)) ?? 0));
          return Gap([
            for (final b in confirm)
              Note(
                tone: Tone.warn,
                title: 'Confirm handover for ${bcode(b)}',
                child: Wrap(crossAxisAlignment: WrapCrossAlignment.center, spacing: 6, children: [
                  Text('${b['assigned_collector_name'] ?? 'The collector'} recorded ${kg(bq(b, 'collected_kg'))}. Enter the code the collector gives you to confirm.'),
                  LinkText('Open handover', () => go('/g/handover')),
                ]),
              ),
            if (open.isNotEmpty)
              Note(
                child: Wrap(spacing: 6, children: [
                  Text('You have ${plural(open.length, 'open listing')}.'),
                  LinkText('Review collector offers', () => go('/g/offers')),
                ]),
              ),
            KpiGrid([
              Kpi(icon: Icons.account_balance_wallet_outlined, label: 'Paid to you', value: q.has('p') ? inr(paid, decimals: false) : '…', sub: pending != 0 ? '${inr(pending, decimals: false)} pending' : 'Nothing pending'),
              Kpi(icon: Icons.back_hand_outlined, label: 'Collected', value: kg(sumQ(bs, 'collected_kg')), sub: 'of ${kg(sumQ(live, 'estimated_kg'))} listed'),
              Kpi(icon: Icons.recycling, label: 'Recovered output', value: kg(sumQ(bs, 'processed_kg')), sub: 'Measured by recycler, pro rata'),
              Kpi(icon: Icons.verified_user_outlined, label: 'NGO-verified', value: kg(verified), sub: 'Independent review, non-statutory'),
            ]),
            Panel(
              title: 'Where your plastic went',
              sub: 'All your batches · each stage weighed separately',
              footer: const SourceLine(_src),
              child: Gap([
                BarChart(
                  labels: const ['Listed', 'Collected', 'Received', 'Accepted', 'Recovered'],
                  series: [
                    Series('Quantity (kg)', c.c2, [
                      sumQ(live, 'estimated_kg'),
                      sumQ(bs, 'collected_kg'),
                      sumQ(bs, 'received_kg'),
                      sumQ(bs, 'accepted_kg'),
                      sumQ(bs, 'processed_kg'),
                    ]),
                  ],
                ),
                Note(text: '${kg(sumQ(bs, 'rejected_kg'))} was rejected at the recycler gate and remains on record. Listed kg that has not been collected is not counted as recycled.'),
              ], gap: 12),
            ),
            Panel(
              title: 'Recent batches',
              flush: true,
              actions: [Btn('View all', small: true, kind: BtnKind.outline, onPressed: () => go('/g/batches'))],
              child: DataList<J>(
                label: 'Recent batches',
                rows: bs.take(6).toList(),
                cols: batchCols().take(8).toList(),
                rowKey: (b) => sn(b['id'])!,
                onTap: (b) => openPassport(bcode(b)),
                emptyTitle: 'No batches yet',
                emptyBody: 'Create your first listing to get collector offers.',
                emptyAction: Btn('Create listing', small: true, onPressed: () => go('/g/listings/new')),
              ),
            ),
          ]);
        }),
      ]),
    );
  }
}

/* ─────────────── Listings ─────────────── */
class GeneratorListings extends StatelessWidget {
  const GeneratorListings({super.key});

  Future<void> _withdraw(BuildContext context, J b) => showSheet(context, _WithdrawSheet(b));

  @override
  Widget build(BuildContext context) {
    final base = batchCols();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PageHeader(
        title: 'Waste listings',
        description: 'Plastic you have declared for collection. A listing can be withdrawn while it is open or assigned and not yet weighed.',
        actions: [Btn('Create listing', icon: Icons.add, onPressed: () => go('/g/listings/new'))],
      ),
      Panel(
        flush: true,
        footer: const SourceLine(_src),
        child: QueryView<List<J>>(
          qk: K.batchList(),
          fetch: () => Api.batches(),
          builder: (context, bs) => DataList<J>(
            label: 'Waste listings',
            rows: bs,
            rowKey: (b) => sn(b['id'])!,
            onTap: (b) => openPassport(bcode(b)),
            search: (b) => '${bcode(b)} ${b['locality'] ?? ''}',
            searchHint: 'Search batch code or locality',
            filters: [
              Flt<J>('st', 'Status', kBatchStatusOptions, (b) => bstatus(b) ?? ''),
              Flt<J>('m', 'Material', {for (final b in bs) sn(b['material']) ?? ''}.map((m) => (m, m)).toList(), (b) => sn(b['material']) ?? ''),
            ],
            sortKey: 'listed',
            sortAsc: false,
            emptyTitle: 'No listings yet',
            emptyAction: Btn('Create listing', small: true, onPressed: () => go('/g/listings/new')),
            cols: [
              base[0],
              base[1],
              Col<J>('win', 'Pickup window', (b) => Small('${dateTime(b['available_from'])} – ${dateTime(b['available_to'])}'), sort: (b) => sn(b['available_from'])),
              base[3],
              tcol<J>('loc', 'Locality', (b) => sn(b['locality']) ?? '—'),
              base[7],
              Col<J>(
                'x',
                '',
                (b) => (['LISTED', 'ASSIGNED'].contains(bstatus(b)) && !awaitingConfirmation(b))
                    ? Btn('Withdraw', small: true, kind: BtnKind.ghost, onPressed: () => _withdraw(context, b))
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    ]);
  }
}

class _WithdrawSheet extends StatefulWidget {
  final J b;
  const _WithdrawSheet(this.b);
  @override
  State<_WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<_WithdrawSheet> {
  bool _busy = false;
  ApiError? _err;
  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    return SheetScaffold(
      title: 'Withdraw listing?',
      description: '${bcode(b)} · ${kg(bq(b, 'estimated_kg'))} ${b['material']}',
      actions: [
        Btn('Keep listing', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)),
        Btn('Withdraw listing', kind: BtnKind.destructive, loading: _busy, onPressed: () async {
          setState(() => _busy = true);
          final r = await mutate(() => Api.cancelBatch(sn(b['id'])!), invalidate: [K.batches], success: (_) => 'Listing withdrawn', onError: (e) => _err = e);
          if (!context.mounted) return;
          setState(() => _busy = false);
          if (r != null) Navigator.pop(context);
        }),
      ],
      children: [
        const Note(tone: Tone.warn, text: 'The batch is marked cancelled. This cannot be undone; you can list the material again.'),
        if (_err != null) Note(tone: Tone.bad, text: _err!.message),
      ],
    );
  }
}

/* ─────────────── Create listing ─────────────── */
class CreateListing extends StatefulWidget {
  const CreateListing({super.key});
  @override
  State<CreateListing> createState() => _CreateListingState();
}

class _CreateListingState extends State<CreateListing> {
  String? _material;
  String? _predictionId;
  final _kg = TextEditingController();
  final _addr = TextEditingController();
  final _loc = TextEditingController();
  DateTime _from = DateTime.now();
  DateTime _to = DateTime.now().add(const Duration(days: 2));
  final List<RegisteredDoc> _photos = [];
  bool _uploading = false;
  bool _busy = false;
  bool _addrSet = false;
  Map<String, String> _errs = {};
  ApiError? _apiErr;

  @override
  void dispose() {
    _kg.dispose();
    _addr.dispose();
    _loc.dispose();
    super.dispose();
  }

  bool _validate() {
    final e = <String, String>{};
    if (_material == null) e['material_code'] = 'Choose a material';
    final k = kgError(_kg.text, label: 'Estimated weight');
    if (k != null) {
      e['estimated_kg'] = k;
    } else if (double.parse(_kg.text.trim()) > 50000) {
      e['estimated_kg'] = 'Listings above 50,000 kg need a bulk contract';
    }
    if (_addr.text.trim().length < 5) e['pickup_address'] = 'Enter the pickup address';
    if (_loc.text.trim().length > 128) e['locality'] = 'At most 128 characters';
    if (!_to.isAfter(_from)) e['available_to'] = 'End must be after start';
    setState(() => _errs = e);
    return e.isEmpty;
  }

  Future<void> _submit() async {
    if (!_validate()) return;
    setState(() {
      _busy = true;
      _apiErr = null;
    });
    final r = await mutate(
      () => Api.createBatch({
        'material_code': _material,
        'estimated_kg': double.parse(_kg.text.trim()),
        'pickup_address': _addr.text.trim(),
        'locality': _loc.text.trim().isEmpty ? null : _loc.text.trim(),
        'available_from': toIsoUtc(_from),
        'available_to': toIsoUtc(_to),
        'document_ids': _photos.map((p) => p.id).toList(),
        if (_predictionId != null) 'ai_prediction_id': _predictionId,
      }),
      invalidate: [K.batches],
      success: (d) => 'Listing ${d['batch_code']} published',
      onError: (e) => _apiErr = e,
      toastErrors: false,
    );
    if (!mounted) return;
    setState(() {
      _busy = false;
      if (_apiErr != null) _errs = {..._errs, ..._apiErr!.fieldErrors()};
    });
    if (r != null) {
      go('/g/listings');
      openPassport(sn(r['batch_code'])!);
    }
  }

  Future<void> _addPhoto() async {
    setState(() => _uploading = true);
    final d = await pickAndRegister(context, 'PHOTO_LISTING');
    if (!mounted) return;
    setState(() {
      _uploading = false;
      if (d != null) _photos.add(d);
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'Create listing', description: 'Declare sorted plastic for collection. Your estimate is compared with the weight the collector records at pickup.'),
      Queries(
        queries: {'m': QDef(K.materials, Api.materials), 'o': QDef(K.myOrg, Api.myOrg)},
        builder: (context, q) {
          final mats = q.list('m');
          final org = q.get<J>('o');
          if (!_addrSet && org != null) {
            _addrSet = true;
            // Pre-fill the organisation address once, after this frame (never edit a field mid-build).
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _addr.text.isEmpty) _addr.text = sn(org['address']) ?? '';
            });
          }
          final apiFieldErrs = _apiErr?.fieldErrors() ?? const {};
          return TwoCol(
            main: Panel(
              title: 'Listing details',
              sub: 'Fields marked * are required',
              footer: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Btn('Cancel', kind: BtnKind.outline, onPressed: () => back('/g')),
                const SizedBox(width: 8),
                Btn('Publish listing', loading: _busy, onPressed: _submit),
              ]),
              child: Gap([
                AiDetectPanel(
                  knownCodes: mats.map((m) => sn(m['code']) ?? '').toSet(),
                  onPhoto: (d) => setState(() => _photos.add(d)),
                  onApply: (code, pid) => setState(() {
                    _material = code;
                    _predictionId = pid;
                  }),
                ),
                Field(
                  label: 'Material',
                  required: true,
                  error: _errs['material_code'],
                  hint: _predictionId != null ? 'Suggested by AI detection. Change it if it is wrong; your final choice is recorded.' : 'Choose the polymer, or use AI detection above.',
                  child: Sel<String>(
                    value: _material,
                    placeholder: q.pending('m') ? 'Loading materials…' : 'Select material',
                    hasError: _errs['material_code'] != null,
                    items: [for (final m in mats) (sn(m['code'])!, '${m['code']} · ${m['name']}${m['resin_code'] != null ? ' (RIC ${m['resin_code']})' : ''}')],
                    onChanged: mats.isEmpty ? null : (v) => setState(() => _material = v),
                  ),
                ),
                RGrid(minWidth: 240, maxCols: 2, gap: 16, children: [
                  Field(
                    label: 'Estimated weight (kg)',
                    required: true,
                    error: _errs['estimated_kg'],
                    hint: 'The collector notes any difference above ±20% at pickup.',
                    child: In(_kg, decimal: true, hasError: _errs['estimated_kg'] != null),
                  ),
                  Field(label: 'Locality', error: _errs['locality'], child: In(_loc, placeholder: 'e.g. Vikhroli East')),
                ]),
                Field(
                  label: 'Pickup address',
                  required: true,
                  error: _errs['pickup_address'],
                  hint: 'Shared only with the assigned collector and recycler.',
                  child: In(_addr, maxLines: 2, hasError: _errs['pickup_address'] != null),
                ),
                RGrid(minWidth: 240, maxCols: 2, gap: 16, children: [
                  Field(label: 'Available from', required: true, child: DateTimeIn(value: _from, onChanged: (d) => setState(() => _from = d))),
                  Field(
                    label: 'Available until',
                    required: true,
                    error: _errs['available_to'],
                    child: DateTimeIn(value: _to, hasError: _errs['available_to'] != null, onChanged: (d) => setState(() => _to = d)),
                  ),
                ]),
                Field(
                  label: 'Photos',
                  hint: "Each file's SHA-256 is computed on this device and recorded. File storage is not yet connected on the backend, so the image itself is not uploaded.",
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    PhotoBox(
                      busy: _uploading,
                      onTap: _addPhoto,
                      text: _uploading ? 'Registering…' : (_photos.isNotEmpty ? '${plural(_photos.length, 'photo')} recorded' : 'Add photos of the bags or bales'),
                    ),
                    for (final p in _photos)
                      Padding(
                        padding: const EdgeInsets.only(top: 3),
                        child: Text('${p.name} · sha256 ${p.sha.length > 16 ? p.sha.substring(0, 16) : p.sha}…', style: mono(context, size: 11, color: c.fg3), overflow: TextOverflow.ellipsis),
                      ),
                  ]),
                ),
                if (_apiErr != null && apiFieldErrs.isEmpty) Note(tone: Tone.bad, title: 'Listing not published', text: _apiErr!.message),
              ]),
            ),
            side: const Panel(
              title: 'What happens next',
              child: Gap([
                Small('1. Collectors see the listing and make per-kg offers.', size: 13),
                Small('2. You accept one offer. Other offers are declined.', size: 13),
                Small('3. The collector weighs the material and gives you a 6-digit code.', size: 13),
                Small('4. You enter the code to confirm. You are paid on the collected weight.', size: 13),
                Small('5. The recycler records receipt, rejection and processing; you can follow every stage.', size: 13),
              ], gap: 6),
            ),
          );
        },
      ),
    ]);
  }
}

/* ─────────────── Offers ─────────────── */
class GeneratorOffers extends StatelessWidget {
  const GeneratorOffers({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(title: 'Offers', description: 'Collector offers on your open listings. You choose; nothing is accepted automatically.'),
        QueryView<List<J>>(
          qk: K.batchList('LISTED'),
          fetch: () => Api.batches(status: 'LISTED'),
          emptyTitle: 'No open listings',
          emptyBody: 'Create a listing to receive offers.',
          emptyAction: Btn('Create listing', small: true, onPressed: () => go('/g/listings/new')),
          builder: (context, bs) => Gap([for (final b in bs) _OffersForBatch(b)]),
        ),
      ]);
}

class _OffersForBatch extends StatelessWidget {
  final J b;
  const _OffersForBatch(this.b);
  @override
  Widget build(BuildContext context) {
    final id = sn(b['id'])!;
    final est = bq(b, 'estimated_kg') ?? 0;
    return Panel(
      titleWidget: Text.rich(TextSpan(children: [
        TextSpan(text: bcode(b), style: mono(context, size: 13.5, weight: FontWeight.w600)),
        TextSpan(text: ' · ${b['material']} · ${kg(est)}', style: const TextStyle(fontWeight: FontWeight.w600)),
      ])),
      sub: 'Available ${dateTime(b['available_from'])} – ${dateTime(b['available_to'])}',
      flush: true,
      footer: const Text(
          "Estimated payment uses your listed weight. You are paid on the weight recorded at pickup. Declining a single offer is not supported by the backend; offers you don't accept are declined when you accept another."),
      child: QueryView<List<J>>(
        qk: K.offers(id),
        fetch: () => Api.batchOffers(id),
        emptyTitle: 'No offers yet',
        emptyBody: 'Collectors serving your area have been notified. Offers expire after two days.',
        isEmpty: (o) => o.where((x) => x['status'] == 'OPEN').isEmpty,
        builder: (context, offers) => DataList<J>(
          label: 'Offers for ${bcode(b)}',
          rows: offers.where((o) => o['status'] == 'OPEN').toList(),
          rowKey: (o) => sn(o['id'])!,
          sortKey: 'rate',
          sortAsc: false,
          cols: [
            Col<J>('c', 'Collector', (o) => Text(sn(o['collector_name']) ?? '—', style: const TextStyle(fontWeight: FontWeight.w600)), sort: (o) => sn(o['collector_name']) ?? ''),
            Col<J>('rate', 'Rate', (o) => numText('${inr(dn(o['generator_rate_per_kg']))}/kg'), numeric: true, sort: (o) => dn(o['generator_rate_per_kg'])),
            Col<J>('pay', 'Est. payment', (o) => numText(inr((dn(o['generator_rate_per_kg']) ?? 0) * est)), numeric: true, sort: (o) => dn(o['generator_rate_per_kg'])),
            Col<J>('when', 'Proposed pickup', (o) => Small(dateTime(o['proposed_pickup_at'])), sort: (o) => sn(o['proposed_pickup_at'])),
            Col<J>('exp', 'Expires', (o) => Small(dateTime(o['expires_at'])), sort: (o) => sn(o['expires_at'])),
            Col<J>('x', '', (o) => Btn('Accept', small: true, onPressed: () => showSheet(context, _AcceptSheet(b, o)))),
          ],
        ),
      ),
    );
  }
}

class _AcceptSheet extends StatefulWidget {
  final J b, o;
  const _AcceptSheet(this.b, this.o);
  @override
  State<_AcceptSheet> createState() => _AcceptSheetState();
}

class _AcceptSheetState extends State<_AcceptSheet> {
  bool _busy = false;
  ApiError? _err;
  @override
  Widget build(BuildContext context) {
    final o = widget.o;
    final b = widget.b;
    final est = bq(b, 'estimated_kg') ?? 0;
    final rate = dn(o['generator_rate_per_kg']) ?? 0;
    return SheetScaffold(
      title: 'Accept offer?',
      description: '${o['collector_name']} · ${inr(rate)}/kg',
      actions: [
        Btn('Cancel', kind: BtnKind.outline, onPressed: () => Navigator.pop(context)),
        Btn('Accept offer', loading: _busy, onPressed: () async {
          setState(() => _busy = true);
          final r = await mutate(
            () => Api.acceptOffer(sn(b['id'])!, sn(o['id'])!),
            invalidate: [K.batches, K.offers(sn(b['id'])!)],
            success: (_) => 'Offer accepted. ${o['collector_name']} is assigned.',
            onError: (e) => _err = e,
          );
          if (!context.mounted) return;
          setState(() => _busy = false);
          if (r != null) Navigator.pop(context);
        }),
      ],
      children: [
        KV([
          KVRow('Listed weight', kg(est)),
          KVRow('Estimated payment', inr(rate * est)),
          KVRow('Proposed pickup', dateTime(o['proposed_pickup_at'])),
          const KVRow('Other open offers', 'Declined automatically'),
        ]),
        if (_err != null) Note(tone: Tone.bad, text: _err!.message),
      ],
    );
  }
}

/* ─────────────── Handover ─────────────── */
class GeneratorHandover extends StatelessWidget {
  const GeneratorHandover({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(
            title: 'Handover confirmation',
            description: 'The collector weighs your material and reads you a 6-digit code. Entering the code confirms the collected weight and records your payment.'),
        QueryView<List<J>>(
          qk: K.batchList(),
          fetch: () => Api.batches(),
          builder: (context, bs) {
            final confirm = bs.where(awaitingConfirmation).toList();
            final scheduled = bs.where((b) => bstatus(b) == 'ASSIGNED' && !awaitingConfirmation(b)).toList();
            final cols = batchCols();
            return Gap([
              if (confirm.isNotEmpty)
                for (final b in confirm) _HandoverCard(b, key: ValueKey(b['id']))
              else
                const Panel(title: 'Waiting for your confirmation', child: EmptyState(title: 'Nothing to confirm', body: 'When a collector records a weight at your premises, it appears here.')),
              Panel(
                title: 'Scheduled pickups',
                flush: true,
                child: DataList<J>(
                  label: 'Scheduled pickups',
                  rows: scheduled,
                  rowKey: (b) => sn(b['id'])!,
                  emptyTitle: 'No pickups scheduled',
                  emptyBody: 'Accept an offer to schedule a pickup.',
                  cols: [
                    cols[0],
                    cols[1],
                    cols[3],
                    tcol<J>('c', 'Collector', (b) => sn(b['assigned_collector_name']) ?? '—'),
                    Col<J>('w', 'Window', (b) => Small('${dateTime(b['available_from'])} – ${dateTime(b['available_to'])}')),
                  ],
                ),
              ),
            ]);
          },
        ),
      ]);
}

class _HandoverCard extends StatefulWidget {
  final J b;
  const _HandoverCard(this.b, {super.key});
  @override
  State<_HandoverCard> createState() => _HandoverCardState();
}

class _HandoverCardState extends State<_HandoverCard> {
  final _otp = TextEditingController();
  String? _fieldErr;
  ApiError? _err;
  bool _busy = false;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final v = _otp.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(v)) {
      setState(() => _fieldErr = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _fieldErr = null;
      _err = null;
      _busy = true;
    });
    await mutate(
      () => Api.confirmHandover(sn(widget.b['id'])!, {'otp': v}),
      invalidate: [K.batches, K.payments],
      toastErrors: false,
      success: (d) => 'Handover confirmed: ${kg(dn(d['collected_kg']))}. Payment of ${inr(dn(d['payment_generated']))} recorded.',
      onError: (e) => _err = e,
    );
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final b = widget.b;
    final c = context.c;
    final col = bq(b, 'collected_kg') ?? 0;
    final est = bq(b, 'estimated_kg') ?? 0;
    final dev = est != 0 ? (col - est) / est * 100 : 0.0;
    final otpErr = _fieldErr ?? (_err?.code == 'OTP_INVALID' ? 'That code does not match. Ask the collector to read it again.' : null);
    return Panel(
      titleWidget: Mono(bcode(b), size: 13.5, weight: FontWeight.w600),
      sub: '${b['material']} · collector ${b['assigned_collector_name'] ?? '—'}',
      child: Gap([
        RGrid(minWidth: 280, maxCols: 2, gap: 16, children: [
          KV([
            KVRow('Listed weight', kg(est)),
            KVRow('Weighed by collector', Text(kg(col), style: const TextStyle(fontWeight: FontWeight.w700))),
            KVRow('Difference', Text('${dev >= 0 ? '+' : ''}${pct(dev)}', style: TextStyle(color: dev.abs() > 20 ? c.bad : null, fontWeight: FontWeight.w500))),
          ]),
          Gap([
            Field(
              label: 'Code from the collector',
              required: true,
              error: otpErr,
              hint: 'Only confirm if the weight shown matches what you saw on the scale.',
              child: In(_otp, numeric: true, monoFont: true, big: true, maxLength: 6, hasError: otpErr != null, autofill: const [AutofillHints.oneTimeCode], onSubmitted: (_) => _confirm()),
            ),
            if (_err != null && _err!.code != 'OTP_INVALID') Note(tone: Tone.bad, text: _err!.message),
            Btn('Confirm ${kg(col)}', loading: _busy, onPressed: _confirm),
          ], gap: 8),
        ]),
        if (dev.abs() > 20)
          const Note(tone: Tone.warn, text: 'The weighed amount differs from your estimate by more than 20%. If it is wrong, do not confirm; ask the collector to re-weigh.'),
      ], gap: 12),
    );
  }
}

/* ─────────────── Batch tracking ─────────────── */
class GeneratorBatches extends StatelessWidget {
  const GeneratorBatches({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(title: 'Batch tracking', description: 'Every batch from listing to recovered output. Each quantity is recorded by a different party and shown separately.'),
        Panel(
          flush: true,
          footer: const Foot(_src, note: 'Recovered kg is a pro rata share of measured run output.'),
          child: QueryView<List<J>>(
            qk: K.batchList(),
            fetch: () => Api.batches(),
            builder: (context, bs) => DataList<J>(
              label: 'Batches',
              rows: bs,
              cols: batchCols(),
              rowKey: (b) => sn(b['id'])!,
              onTap: (b) => openPassport(bcode(b)),
              search: (b) => bcode(b),
              searchHint: 'Search batch code',
              sortKey: 'listed',
              sortAsc: false,
              filters: [Flt<J>('st', 'Status', kBatchStatusOptions, (b) => bstatus(b) ?? '')],
              emptyTitle: 'No batches yet',
              footer: (r) => [
                FootItem('Total (${r.length})', ''),
                FootItem('Listed', num1(sumQ(r, 'estimated_kg'))),
                FootItem('Collected', num1(sumQ(r, 'collected_kg'))),
                FootItem('Accepted', num1(sumQ(r, 'accepted_kg'))),
                FootItem('Recovered', num1(sumQ(r, 'processed_kg'))),
              ],
            ),
          ),
        ),
      ]);
}

/* ─────────────── Payments ─────────────── */
class PaymentsTable extends StatelessWidget {
  final List<J> rows;
  final bool payee;
  const PaymentsTable({super.key, required this.rows, required this.payee});

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<List<J>>(
      qk: K.batchList(),
      fetch: () => Api.batches(),
      builder: (context, bq_) {
        String? codeOf(dynamic id) => bq_.data?.where((b) => b['id'] == id).map(bcode).firstOrNull;
        return DataList<J>(
          label: 'Payments',
          rows: rows,
          rowKey: (p) => sn(p['id'])!,
          sortKey: 'at',
          sortAsc: false,
          filters: [Flt<J>('st', 'Status', const [('PENDING', 'Pending'), ('PAID', 'Paid')], (p) => sn(p['status']) ?? '')],
          emptyTitle: 'No payments yet',
          emptyBody: 'A payment is created when a handover is confirmed.',
          cols: [
            Col<J>('at', 'Date', (p) => Small(dateTime(p['created_at'])), sort: (p) => sn(p['created_at'])),
            Col<J>('b', 'Batch', (p) {
              final code = codeOf(p['batch_id']);
              final id = sn(p['batch_id']);
              return code != null ? BatchLink(code) : Mono(id == null ? '—' : id.substring(0, id.length < 8 ? id.length : 8), size: 12, color: context.c.fg3);
            }),
            tcol<J>('type', 'Type', (p) => p['payment_type'] == 'GENERATOR_PAYOUT' ? (payee ? 'Payout to you' : 'Payout to generator') : (sn(p['payment_type']) ?? '')),
            ncol<J>('kg', 'Collected kg', (p) => dn(p['quantity_kg']), num1),
            ncol<J>('rate', 'Rate', (p) => dn(p['rate']), (v) => v == null ? '—' : '${inr(v)}/kg', sortable: false),
            ncol<J>('amt', 'Amount', (p) => dn(p['amount']), inr),
            Col<J>('st', 'Status', (p) => p['status'] == 'PAID' ? const Pill('Paid', tone: Tone.ok) : const Pill('Pending', tone: Tone.warn), sort: (p) => sn(p['status'])),
            Col<J>('ref', 'Reference', (p) => Mono(sn(p['external_ref']) ?? '—', size: 12)),
          ],
          footer: (r) => [FootItem('Total', inr(r.fold<double>(0, (s, p) => s + (dn(p['amount']) ?? 0))))],
        );
      },
    );
  }
}

double sumAmount(Iterable<J> ps) => ps.fold<double>(0, (s, p) => s + (dn(p['amount']) ?? 0));

class GeneratorPayments extends StatelessWidget {
  const GeneratorPayments({super.key});
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const PageHeader(title: 'Payments', description: 'Payments are calculated on the weight recorded at pickup and confirmed by you. The collector bears any later rejection.'),
        QueryView<List<J>>(
          qk: K.payments,
          fetch: Api.payments,
          builder: (context, ps) {
            final paid = ps.where((p) => p['status'] == 'PAID').toList();
            return Gap([
              KpiGrid([
                Kpi(label: 'Paid', value: inr(sumAmount(paid)), sub: plural(paid.length, 'payment')),
                Kpi(label: 'Pending', value: inr(sumAmount(ps.where((p) => p['status'] == 'PENDING'))), sub: 'Marked paid by the collector'),
                Kpi(label: 'Collected kg paid for', value: kg(ps.fold<double>(0, (s, p) => s + (dn(p['quantity_kg']) ?? 0)))),
              ], cols: 3),
              Panel(flush: true, footer: const SourceLine('ReLoop API · /payments (simulated ledger; no money moves)'), child: PaymentsTable(rows: ps, payee: true)),
            ]);
          },
        ),
      ]);
}

/* ─────────────── Contribution statements ─────────────── */
class GeneratorStatements extends StatelessWidget {
  const GeneratorStatements({super.key});

  String _sid(J b) {
    final c = bcode(b);
    return 'RCS-${c.length > 6 ? c.substring(c.length - 6) : c}';
  }

  void _open(BuildContext context, J b) {
    final v = jo(b['verification']);
    final verified = v?['decision'] == 'VERIFIED';
    showSheet(
      context,
      SheetScaffold(
        title: 'Recycling contribution statement',
        description: '${_sid(b)} · generated from ReLoop records',
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: sn(b['generator_name']) ?? '', style: const TextStyle(fontWeight: FontWeight.w700)),
            TextSpan(text: ' contributed the material below, recycled by ${b['destination_recycler_name'] ?? 'the recycler'}.'),
          ]), style: const TextStyle(fontSize: 13)),
          KV([
            KVRow('Batch', Mono(bcode(b))),
            KVRow('Material', b['material_name'] ?? b['material']),
            KVRow('Collected', kg(bq(b, 'collected_kg'))),
            KVRow('Accepted at recycler', kg(bq(b, 'accepted_kg'))),
            KVRow('Recovered output (pro rata)', kg(bq(b, 'processed_kg')), total: true),
            KVRow('Independently reviewed', verified ? '${kg(verifiedKg(jo(b['quantities']) ?? {}, 'VERIFIED'))} by ${v?['ngo'] ?? '—'}' : 'Not yet'),
          ]),
          const Note(tone: Tone.warn, text: 'Non-statutory. Not an EPR certificate and not valid for regulatory filing.'),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cols = batchCols();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(
          title: 'Contribution statements', description: 'Your share of measured recycling output, per processed batch. Issued from ReLoop records; not statutory EPR certificates.'),
      const Note(
          tone: Tone.warn,
          text:
              "These statements are not issued by CPCB or any government body and cannot be used for EPR compliance. \"Independently reviewed\" appears only for batches an NGO has verified. The backend's own certificate endpoint reports listed kg as contributed, so it is not used here."),
      const SizedBox(height: 16),
      Panel(
        flush: true,
        child: QueryView<List<J>>(
          qk: K.batchList(),
          fetch: () => Api.batches(),
          builder: (context, bs) => DataList<J>(
            label: 'Contribution statements',
            rows: bs.where((b) => bq(b, 'processed_kg') != null).toList(),
            rowKey: (b) => sn(b['id'])!,
            onTap: (b) => _open(context, b),
            emptyTitle: 'No statements yet',
            emptyBody: 'A statement appears once a recycler measures the output of a run that includes your batch.',
            cols: [
              Col<J>('id', 'Statement', (b) => Mono(_sid(b), size: 12)),
              cols[0],
              cols[1],
              cols[4],
              cols[6],
              Col<J>('v', 'Independent review', (b) => decisionOf(b) == 'VERIFIED' ? const Pill('NGO-verified', tone: Tone.ok) : NgoPill(decisionOf(b))),
            ],
          ),
        ),
      ),
    ]);
  }
}

/* ─────────────── Analytics ─────────────── */
class GeneratorAnalytics extends StatelessWidget {
  const GeneratorAnalytics({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const PageHeader(title: 'Contribution analytics', description: 'How your listings convert into collected, accepted and recovered material, and where losses occur.'),
      QueryView<List<J>>(
        qk: K.batchList(),
        fetch: () => Api.batches(),
        emptyTitle: 'No data yet',
        emptyBody: 'Analytics appear after your first collected batch.',
        builder: (context, bs) {
          final live = bs.where((b) => bstatus(b) != 'CANCELLED').toList();
          final picked = live.where((b) => bq(b, 'collected_kg') != null).toList();
          final mats = {for (final b in live) sn(b['material']) ?? ''}.toList();
          final months = {for (final b in live) (sn(b['created_at']) ?? '').padRight(7).substring(0, 7)}.toList()..sort();
          List<J> ofMat(String m) => live.where((b) => b['material'] == m).toList();
          List<J> ofMonth(String mo) => live.where((b) => (sn(b['created_at']) ?? '').startsWith(mo)).toList();
          final pe = sumQ(picked, 'estimated_kg');
          final rc = sumQ(bs, 'received_kg');
          String monthLabel(String mo) {
            final d = DateTime.tryParse('$mo-01');
            return d == null ? mo : monthYear(d);
          }

          return Gap([
            KpiGrid([
              Kpi(icon: Icons.inventory_2_outlined, label: 'Collection accuracy', value: pct(pe != 0 ? sumQ(picked, 'collected_kg') / pe * 100 : null), sub: 'Collected ÷ listed, collected batches'),
              Kpi(label: 'Acceptance rate', value: pct(rc != 0 ? sumQ(bs, 'accepted_kg') / rc * 100 : null), sub: 'Accepted ÷ received'),
              Kpi(label: 'Rejected at gate', value: kg(sumQ(bs, 'rejected_kg')), sub: 'Kept on record, not recycled'),
              Kpi(label: 'Recovered output', value: kg(sumQ(bs, 'processed_kg')), sub: 'Pro rata share of runs'),
            ]),
            RGrid(minWidth: 420, maxCols: 2, gap: 16, children: [
              Panel(
                title: 'By listing month',
                footer: const SourceLine(_src),
                child: BarChart(
                  labels: months.map(monthLabel).toList(),
                  series: [
                    Series('Listed', c.c3, [for (final m in months) sumQ(ofMonth(m), 'estimated_kg')]),
                    Series('Collected', c.c2, [for (final m in months) sumQ(ofMonth(m), 'collected_kg')]),
                    Series('Recovered', c.c1, [for (final m in months) sumQ(ofMonth(m), 'processed_kg')]),
                  ],
                ),
              ),
              Panel(
                title: 'By material',
                footer: const SourceLine(_src),
                child: BarChart(
                  labels: mats,
                  series: [
                    Series('Listed', c.c3, [for (final m in mats) sumQ(ofMat(m), 'estimated_kg')]),
                    Series('Collected', c.c2, [for (final m in mats) sumQ(ofMat(m), 'collected_kg')]),
                    Series('Accepted', c.c4, [for (final m in mats) sumQ(ofMat(m), 'accepted_kg')]),
                    Series('Recovered', c.c1, [for (final m in mats) sumQ(ofMat(m), 'processed_kg')]),
                  ],
                ),
              ),
            ]),
          ]);
        },
      ),
    ]);
  }
}
