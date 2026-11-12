const nf1 = new Intl.NumberFormat('en-IN', { minimumFractionDigits: 1, maximumFractionDigits: 1 })
const nf0 = new Intl.NumberFormat('en-IN', { maximumFractionDigits: 0 })
const inr2 = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', minimumFractionDigits: 2, maximumFractionDigits: 2 })
const inr0 = new Intl.NumberFormat('en-IN', { style: 'currency', currency: 'INR', maximumFractionDigits: 0 })

export const kg = (v: number | null | undefined) => (v == null || !isFinite(v) ? '—' : `${nf1.format(v)} kg`)
export const num1 = (v: number | null | undefined) => (v == null || !isFinite(v) ? '—' : nf1.format(v))
export const num0 = (v: number | null | undefined) => (v == null || !isFinite(v) ? '—' : nf0.format(v))
export const pct = (v: number | null | undefined) => (v == null || !isFinite(v) ? '—' : `${(Math.round(v * 10) / 10).toFixed(1)}%`)
export const inr = (v: number | null | undefined, decimals = true) => (v == null || !isFinite(v) ? '—' : (decimals ? inr2 : inr0).format(v))

export function dateTime(iso: string | null | undefined) {
  if (!iso) return '—'
  const d = new Date(iso)
  if (isNaN(d.getTime())) return '—'
  return d.toLocaleString('en-IN', { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' })
}
export function date(iso: string | null | undefined) {
  if (!iso) return '—'
  const d = new Date(iso)
  if (isNaN(d.getTime())) return '—'
  return d.toLocaleDateString('en-IN', { day: 'numeric', month: 'short', year: 'numeric' })
}
/** "RL-MUM-2026-000123" → "…000123" for dense tables; full code always in title/tooltip. */
export const shortCode = (code: string) => (code.startsWith('RL-') ? `…${code.slice(-6)}` : code)
export const humanize = (s: string | null | undefined) =>
  !s ? '—' : s.toLowerCase().replace(/_/g, ' ').replace(/^\w/, (c) => c.toUpperCase())
export const CATEGORY_LABEL: Record<string, string> = {
  CAT_I: 'Cat I · Rigid', CAT_II: 'Cat II · Flexible', CAT_III: 'Cat III · Multilayer', CAT_IV: 'Cat IV · Compostable',
}
export const currentReportingPeriod = (d = new Date()) => {
  const y = d.getMonth() >= 3 ? d.getFullYear() : d.getFullYear() - 1
  return `FY${y}-${String((y + 1) % 100).padStart(2, '0')}`
}
