import type { Batch, BatchQuantities, BatchTrace, NgoDecision } from '@/types/api'

/** Backend sends quantities as "123.000" strings or null. */
export function q(v: string | null | undefined): number | null {
  if (v == null || v === '') return null
  const n = Number(v)
  return isFinite(n) ? n : null
}

export interface Stage {
  key: 'listed' | 'collected' | 'received' | 'accepted' | 'input' | 'output'
  label: string
  hint: string
  value: number | null
  /** e.g. collected but awaiting generator OTP confirmation */
  provisional?: boolean
}

/**
 * The six physical stages. Field mapping (audit §8):
 *  - processing input comes from /trace (sum of input_kg), NOT from quantities
 *  - quantities.processed_kg is the batch's pro rata share of measured run OUTPUT (recovered output)
 */
export function physicalStages(quantities: BatchQuantities, trace?: BatchTrace | null, opts?: { pickupConfirmed?: boolean }): Stage[] {
  const input = trace ? (trace.processing_runs.length ? trace.processing_runs.reduce((s, r) => s + r.input_kg, 0) : null) : null
  const collected = q(quantities.collected_kg)
  return [
    { key: 'listed', label: 'Listed', hint: 'Generator estimate', value: q(quantities.estimated_kg) },
    { key: 'collected', label: 'Collected', hint: 'Weighed at pickup', value: collected, provisional: collected != null && opts?.pickupConfirmed === false },
    { key: 'received', label: 'Received', hint: 'Weighed at recycler', value: q(quantities.received_kg) },
    { key: 'accepted', label: 'Accepted', hint: 'After inspection', value: q(quantities.accepted_kg) },
    { key: 'input', label: 'Processing input', hint: 'Fed into a run', value: input },
    { key: 'output', label: 'Recovered output', hint: 'Pro rata share of measured output', value: q(quantities.processed_kg) },
  ]
}

/**
 * NGO-verified kg is shown only when (a) the current decision is VERIFIED and (b) a measured output exists.
 * The backend falls back to accepted/collected/estimated kg otherwise (audit D9); we never display that fallback.
 */
export function verifiedKg(quantities: BatchQuantities, decision: NgoDecision | null | undefined): number | null {
  if (decision !== 'VERIFIED') return null
  if (q(quantities.processed_kg) == null) return null
  return q(quantities.ngo_verified_kg)
}

export function allocatedKg(quantities: BatchQuantities): number | null {
  return q(quantities.epr_allocated_kg)
}

export interface Variance { label: string; kg: number; pct: number | null; outOfTolerance: boolean }

/** Differences between consecutive stages with the documented tolerances (A-07 ±2% transit, A-08 ±20% estimate). */
export function variances(batch: Pick<Batch, 'quantities'>): Variance[] {
  const Q = batch.quantities
  const est = q(Q.estimated_kg), col = q(Q.collected_kg), rec = q(Q.received_kg), rej = q(Q.rejected_kg)
  const out: Variance[] = []
  if (est != null && col != null) {
    const p = est ? ((col - est) / est) * 100 : null
    out.push({ label: 'Collected vs listed', kg: col - est, pct: p, outOfTolerance: p != null && Math.abs(p) > 20 })
  }
  if (col != null && rec != null) {
    const p = col ? ((rec - col) / col) * 100 : null
    out.push({ label: 'Received vs collected', kg: rec - col, pct: p, outOfTolerance: p != null && Math.abs(p) > 2 })
  }
  if (rej != null && rej > 0) out.push({ label: 'Rejected at receipt', kg: -rej, pct: rec ? (-rej / rec) * 100 : null, outOfTolerance: false })
  return out
}

/** accepted + rejected must equal received (enforced again by the backend with 0.001 kg tolerance). */
export function receiptBalances(received: number, accepted: number, rejected: number) {
  return Math.abs(accepted + rejected - received) <= 0.001
}

export const sumQ = (rows: Batch[], key: keyof BatchQuantities) => rows.reduce((s, b) => s + (q(b.quantities[key]) ?? 0), 0)
