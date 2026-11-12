import 'json.dart';

/// One of the six physical stages of a batch.
class Stage {
  final String key;
  final String label;
  final String hint;
  final double? value;

  /// Collected but awaiting generator OTP confirmation.
  final bool provisional;
  const Stage(this.key, this.label, this.hint, this.value, {this.provisional = false});
}

/// Backend sends quantities as "123.000" strings or null.
double? q(dynamic v) => dn(v);

/// The six physical stages. Field mapping:
///  - processing input comes from /trace (sum of input_kg), NOT from quantities
///  - quantities.processed_kg is the batch's pro rata share of measured run OUTPUT (recovered output)
List<Stage> physicalStages(J quantities, {J? trace, bool? pickupConfirmed}) {
  double? input;
  if (trace != null) {
    final runs = jl(trace['processing_runs']);
    if (runs.isNotEmpty) {
      input = runs.fold<double>(0, (s, r) => s + (dn(r['input_kg']) ?? 0));
    }
  }
  final collected = q(quantities['collected_kg']);
  return [
    Stage('listed', 'Listed', 'Generator estimate', q(quantities['estimated_kg'])),
    Stage('collected', 'Collected', 'Weighed at pickup', collected, provisional: collected != null && pickupConfirmed == false),
    Stage('received', 'Received', 'Weighed at recycler', q(quantities['received_kg'])),
    Stage('accepted', 'Accepted', 'After inspection', q(quantities['accepted_kg'])),
    Stage('input', 'Processing input', 'Fed into a run', input),
    Stage('output', 'Recovered output', 'Pro rata share of measured output', q(quantities['processed_kg'])),
  ];
}

/// NGO-verified kg is shown only when (a) the current decision is VERIFIED and (b) a measured output exists.
/// The backend falls back to accepted/collected/estimated kg otherwise; that fallback is never displayed.
double? verifiedKg(J quantities, String? decision) {
  if (decision != 'VERIFIED') return null;
  if (q(quantities['processed_kg']) == null) return null;
  return q(quantities['ngo_verified_kg']);
}

double? allocatedKg(J quantities) => q(quantities['epr_allocated_kg']);

class Variance {
  final String label;
  final double kg;
  final double? pct;
  final bool outOfTolerance;
  const Variance(this.label, this.kg, this.pct, this.outOfTolerance);
}

/// Differences between consecutive stages with the documented tolerances (±2% transit, ±20% estimate).
List<Variance> variances(J quantities) {
  final est = q(quantities['estimated_kg']);
  final col = q(quantities['collected_kg']);
  final rec = q(quantities['received_kg']);
  final rej = q(quantities['rejected_kg']);
  final out = <Variance>[];
  if (est != null && col != null) {
    final double? p = est != 0 ? ((col - est) / est) * 100 : null;
    out.add(Variance('Collected vs listed', col - est, p, p != null && p.abs() > 20));
  }
  if (col != null && rec != null) {
    final double? p = col != 0 ? ((rec - col) / col) * 100 : null;
    out.add(Variance('Received vs collected', rec - col, p, p != null && p.abs() > 2));
  }
  if (rej != null && rej > 0) {
    out.add(Variance('Rejected at receipt', -rej, (rec != null && rec != 0) ? (-rej / rec) * 100 : null, false));
  }
  return out;
}

/// accepted + rejected must equal received (enforced again by the backend with 0.001 kg tolerance).
bool receiptBalances(double received, double accepted, double rejected) => (accepted + rejected - received).abs() <= 0.001;

/// Sum of one quantity field across batches.
double sumQ(Iterable<J> batches, String key) {
  double s = 0;
  for (final b in batches) {
    final qs = jo(b['quantities']);
    if (qs != null) s += q(qs[key]) ?? 0;
  }
  return s;
}

/// Quantity field of one batch.
double? bq(J batch, String key) {
  final qs = jo(batch['quantities']);
  return qs == null ? null : q(qs[key]);
}

/// Current NGO decision of a batch, or null when not in review.
String? decisionOf(J batch) => sn(jo(batch['verification'])?['decision']);

/// Collected weight recorded by the collector but not yet confirmed by the generator's OTP.
bool awaitingConfirmation(J b) => b['status'] == 'ASSIGNED' && bq(b, 'collected_kg') != null;

/// The backend keeps a consignment at ARRIVED forever (no closed state). The operational status is
/// derived from its batches: received once every batch has a receipt.
String consStatus(J c) {
  final waiting = jl(c['items']).any((i) => i['status'] == 'IN_TRANSIT' || i['status'] == 'PICKED_UP');
  if (!waiting) return 'RECEIVED';
  return c['status'] == 'ARRIVED' ? 'ARRIVED' : 'IN_TRANSIT';
}
