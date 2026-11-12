import { physicalStages, verifiedKg, allocatedKg, q } from '@/lib/quantities'
import { kg, num1 } from '@/lib/format'
import { cn } from '@/lib/utils'
import type { BatchQuantities, BatchTrace, NgoDecision } from '@/types/api'

/** Six physical stages, each recorded by a different party. Losses between stages are shown, never hidden. */
export function QuantityLadder({ quantities, trace, decision, pickupConfirmed, compact }: {
  quantities: BatchQuantities; trace?: BatchTrace | null; decision?: NgoDecision | null; pickupConfirmed?: boolean; compact?: boolean
}) {
  const stages = physicalStages(quantities, trace, { pickupConfirmed })
  const base = stages[0].value || 1
  const firstMissing = stages.findIndex((s) => s.value == null)
  const delta = (i: number): { text: string; bad?: boolean } | null => {
    const s = stages[i], prev = stages[i - 1]
    if (s.value == null || !prev || prev.value == null) return null
    if (s.key === 'accepted') { const rej = q(quantities.rejected_kg); return rej ? { text: `${num1(rej)} kg rejected`, bad: true } : { text: 'Nothing rejected' } }
    if (s.key === 'input') { const held = prev.value - s.value; return held > 0.001 ? { text: `${num1(held)} kg not yet processed` } : { text: 'All accepted kg processed' } }
    if (s.key === 'output') return { text: `${num1(prev.value - s.value)} kg residue and loss`, bad: true }
    const d = s.value - prev.value
    const p = prev.value ? (d / prev.value) * 100 : 0
    const tol = s.key === 'collected' ? 20 : 2
    return { text: `${d >= 0 ? '+' : ''}${num1(d)} kg vs ${prev.label.toLowerCase()}`, bad: Math.abs(p) > tol }
  }
  return (
    <div className="min-w-0">
      <ol aria-label="Quantity progression" className={cn('grid overflow-hidden rounded-lg border border-line bg-surface', compact ? 'grid-cols-3 sm:grid-cols-6' : 'grid-cols-2 sm:grid-cols-3 xl:grid-cols-6')}>
        {stages.map((s, i) => {
          const d = delta(i)
          const state = s.value != null ? (s.provisional ? 'prov' : 'done') : i === firstMissing ? 'next' : 'todo'
          return (
            <li key={s.key} className="min-w-0 border-b border-r border-line px-3 py-2.5 [&:nth-child(6)]:border-r-0">
              <div className="flex items-center gap-1.5 text-[10.5px] uppercase tracking-[.06em] text-fg-3">
                <span className={cn('grid size-4 shrink-0 place-items-center rounded-full text-[10px] font-semibold',
                  state === 'done' ? 'bg-brand text-brand-fg' : state === 'prov' || state === 'next' ? 'bg-warn-bg text-warn' : 'bg-neu text-fg-2')}>{i + 1}</span>
                <span className="truncate">{s.label}</span>
              </div>
              <div className={cn('tnum mt-1 font-semibold', compact ? 'text-sm' : 'text-[17px]', s.value == null && 'text-sm font-medium text-fg-3')}>
                {s.value != null ? kg(s.value) : state === 'next' ? 'Awaiting' : '—'}
              </div>
              {!compact && (
                <div className={cn('mt-0.5 text-[11.5px]', d?.bad ? 'text-bad' : 'text-fg-3')}>
                  {s.provisional ? 'Awaiting generator confirmation' : d ? d.text : s.hint}
                </div>
              )}
              {!compact && <div className="mt-2 h-1 overflow-hidden rounded bg-surface-2"><div className="h-full bg-chart-2" style={{ width: `${s.value != null ? Math.min(100, (s.value / base) * 100) : 0}%` }} /></div>}
            </li>
          )
        })}
      </ol>
      {!compact && <AssuranceRow quantities={quantities} decision={decision} />}
    </div>
  )
}

export function AssuranceRow({ quantities, decision }: { quantities: BatchQuantities; decision?: NgoDecision | null }) {
  const v = verifiedKg(quantities, decision)
  const a = allocatedKg(quantities)
  const out = q(quantities.processed_kg)
  return (
    <div className="mt-2.5 grid overflow-hidden rounded-lg border border-line bg-surface sm:grid-cols-2">
      <div className="border-b border-line px-3 py-2.5 sm:border-b-0 sm:border-r">
        <div className="text-[11.5px] text-fg-2">NGO-verified quantity</div>
        <div className="tnum font-semibold">{v != null ? kg(v) : '—'}</div>
        <div className="text-[11px] text-fg-3">
          {decision == null ? 'Enters independent review once output is measured' : out == null ? 'Shown only after recovered output is measured' : decision === 'VERIFIED' ? 'Independent, non-statutory evidence review' : 'Not verified: see decision'}
        </div>
      </div>
      <div className="px-3 py-2.5">
        <div className="text-[11.5px] text-fg-2">Allocated to EPR clients</div>
        <div className="tnum font-semibold">{a != null ? kg(a) : '—'}</div>
        <div className="text-[11px] text-fg-3">Pro rata share of active allocations on the run. Verification does not make kg EPR-eligible; eligibility is declared by the recycler.</div>
      </div>
    </div>
  )
}
