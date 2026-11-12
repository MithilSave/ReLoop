import * as React from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useForm, useFieldArray } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { FlaskConical, Gauge, Inbox, Layers, Link2, Plus, Truck, Upload } from 'lucide-react'
import {
  K, useAllocations, useBatches, useCapacity, useConsignments, useDemand, useDemandForecasts, useIncoming, useMaterials, useOrgs, usePerformance,
  usePlans, usePricing, useProcessing, useReceipts, useRecyclerOffers, useShortage, useSupplyForecasts, useYield,
} from '@/hooks/queries'
import { useApiMutation } from '@/hooks/useApiMutation'
import * as recApi from '@/services/recycler'
import * as consApi from '@/services/consignments'
import * as eprApi from '@/services/epr'
import * as intelApi from '@/services/intelligence'
import { registerDocument } from '@/services/documents'
import { PageHeader, SourceLine } from '@/components/page'
import { Panel, Kpi, KV } from '@/components/ui/panel'
import { Button } from '@/components/ui/button'
import { Input, Select, Textarea } from '@/components/ui/input'
import { Field } from '@/components/ui/field'
import { Note } from '@/components/ui/note'
import { Badge } from '@/components/ui/badge'
import { Dialog, DialogContent, Drawer } from '@/components/ui/dialog'
import { Tabs, TabsContent, TabsList } from '@/components/ui/tabs'
import { DataTable } from '@/components/ui/data-table'
import { QueryState, EmptyState } from '@/components/states'
import { BatchStatusBadge, SimpleStatus } from '@/components/status'
import { BatchLink } from '@/features/batches/PassportView'
import { consStatus, CONS_STATUS } from '@/features/batches/consignment-status'
import { ConsignmentDetail, PlanDetailView, PlansTable } from '@/pages/collector/CollectorPages'
import { q, receiptBalances } from '@/lib/quantities'
import { CATEGORY_LABEL, currentReportingPeriod, date, dateTime, humanize, inr, kg, num0, num1, pct } from '@/lib/format'
import { kgField, kgFieldAllowZero, localToIso, toLocalInput } from '@/lib/forms'
import type { Allocation, Batch, Consignment, PlanSummary, ProcessingRecord, Receipt } from '@/types/api'
import { ApiError } from '@/api/errors'

const tt = { contentStyle: { background: 'var(--surface)', border: '1px solid var(--line)', fontSize: 12 } }
const axis = { tick: { fill: 'var(--fg-3)', fontSize: 11 }, axisLine: false, tickLine: false }

/* ─────────────── Dashboard ─────────────── */
export function RecyclerDashboard() {
  const cons = useConsignments()
  const receipts = useReceipts()
  const runs = useProcessing()
  const capacity = useCapacity()
  const allocations = useAllocations()
  const nav = useNavigate()
  const open = (cons.data ?? []).filter((c) => consStatus(c) !== 'RECEIVED')
  const R = receipts.data ?? []
  const P = runs.data ?? []
  const inp = P.reduce((s, r) => s + r.input_kg, 0), out = P.reduce((s, r) => s + r.output_kg, 0), res = P.reduce((s, r) => s + r.residue_kg, 0)
  const elig = P.reduce((s, r) => s + r.eligible_kg, 0), alloc = P.reduce((s, r) => s + r.allocated_kg, 0)
  const flow = [
    { stage: 'Received', kg: R.reduce((s, r) => s + r.received_kg, 0) }, { stage: 'Accepted', kg: R.reduce((s, r) => s + r.accepted_kg, 0) },
    { stage: 'Processed input', kg: inp }, { stage: 'Recovered output', kg: out }, { stage: 'Declared eligible', kg: elig }, { stage: 'Allocated', kg: alloc },
  ]
  return (
    <>
      <PageHeader title="Operations dashboard" description="Feedstock arriving, accepted stock on hand, processing output and EPR attribution."
        actions={<><Button variant="outline" asChild><Link to="/r/planner"><Layers />Plan sourcing</Link></Button><Button asChild><Link to="/r/runs"><FlaskConical />Record processing run</Link></Button></>} />
      <div className="flex flex-col gap-4">
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <Kpi icon={<Truck />} label="Incoming consignments" value={cons.isPending ? '…' : open.length} sub={`${open.reduce((s, c) => s + c.items.length, 0)} batches · ${open.filter((c) => consStatus(c) === 'ARRIVED').length} at gate`} />
          <Kpi icon={<Inbox />} label="Accepted stock on hand" value={receipts.isPending ? '…' : kg(R.reduce((s, r) => s + (r.available_kg ?? 0), 0))} sub={(() => { const n = R.filter((r) => (r.available_kg ?? 0) > 0).length; return `${n} batch${n === 1 ? '' : 'es'} not fully processed` })()} />
          <Kpi icon={<Gauge />} label="Processing yield" value={runs.isPending ? '…' : pct(inp ? (out / inp) * 100 : null)} sub={`${kg(out)} recovered of ${kg(inp)} input`} />
          <Kpi icon={<Link2 />} label="EPR-eligible free" value={runs.isPending ? '…' : kg(elig - alloc)} sub={`${kg(alloc)} of ${kg(elig)} declared kg allocated`} />
        </div>
        <div className="grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
          <Panel title="Material flow" sub="Your receipts and processing runs" footer={<SourceLine source="ReLoop API · /recycler/receipts, /recycler/processing-records" />}>
            <div className="h-60"><ResponsiveContainer><BarChart data={flow}><CartesianGrid vertical={false} stroke="var(--line)" /><XAxis dataKey="stage" {...axis} interval={0} tick={{ ...axis.tick, fontSize: 10 }} /><YAxis {...axis} width={52} /><Tooltip {...tt} formatter={(v: number) => kg(v)} />
              <Bar dataKey="kg" name="Quantity" fill="var(--c2)" radius={[3, 3, 0, 0]} /></BarChart></ResponsiveContainer></div>
            <div className="mt-3 grid grid-cols-3 gap-3">
              <Kpi label="Rejected at receipt" value={kg(R.reduce((s, r) => s + r.rejected_kg, 0))} />
              <Kpi label="Process residue" value={kg(res)} />
              <Kpi label="Unaccounted" value={kg(inp - out - res)} sub={inp ? `${pct(((inp - out - res) / inp) * 100)} of input` : undefined} />
            </div>
          </Panel>
          <div className="flex flex-col gap-4">
            <Panel title="Needs attention">
              <div className="flex flex-col gap-2">
                {open.filter((c) => consStatus(c) === 'ARRIVED').map((c) => <Note key={c.id} tone="warn">{c.consignment_code} is at your gate with {c.items.length} batch{c.items.length > 1 ? 'es' : ''}. <Link className="font-medium text-accent underline" to="/r/incoming">Record receipt</Link></Note>)}
                {open.filter((c) => consStatus(c) === 'IN_TRANSIT').map((c) => <Note key={c.id}>{c.consignment_code} in transit · {c.items.length} batch{c.items.length > 1 ? 'es' : ''}</Note>)}
                {P.filter((r) => r.yield_pct != null && r.input_kg && (r.input_kg - r.output_kg - r.residue_kg) / r.input_kg > 0.03).map((r) => <Note key={r.id} tone="warn">{r.record_code}: unaccounted {pct(((r.input_kg - r.output_kg - r.residue_kg) / r.input_kg) * 100)} of input exceeds the 3% guideline.</Note>)}
                {!open.length && <p className="text-sm text-fg-3">Nothing needs action.</p>}
              </div>
            </Panel>
            <Panel title="Capacity this month">
              <QueryState query={capacity}>{(c) => <KV rows={[['Monthly capacity', kg(c.monthly_capacity_kg)], ['Output this month', kg(c.processed_this_month_kg)], ['Utilisation', pct(c.utilization_pct)], ['Remaining', kg(c.remaining_capacity_kg), true]]} />}</QueryState>
            </Panel>
          </div>
        </div>
        <Panel title="Recent processing runs" flush actions={<Button size="sm" variant="outline" asChild><Link to="/r/runs">All runs</Link></Button>}>
          <QueryState query={runs}>{(rows) => <RunsTable rows={rows.slice(0, 5)} onOpen={() => nav('/r/runs')} />}</QueryState>
        </Panel>
        {allocations.isError && <Note tone="bad">Allocations could not be loaded.</Note>}
      </div>
    </>
  )
}

/* ─────────────── Procurement requirements ─────────────── */
const demandSchema = z.object({
  material_code: z.string().min(1, 'Choose a material'), recurrence: z.string(), quantity_kg: kgField('Quantity'),
  min_quality_grade: z.string(), max_contamination_pct: z.string().refine((v) => Number(v) >= 0 && Number(v) <= 100, '0–100'), need_by: z.string().optional(),
})
const offerSchema = z.object({
  material_code: z.string().min(1, 'Choose a material'), price_per_kg: z.string().refine((v) => Number(v) > 0, 'Enter a price'), min_kg: kgField('Minimum lot'),
  max_contamination_pct: z.string().refine((v) => Number(v) >= 0 && Number(v) <= 100, '0–100'), quality_spec: z.string().optional(), valid_to: z.string().min(1, 'Choose an end date'),
})
export function RecyclerRequirements() {
  const demand = useDemand()
  const offers = useRecyclerOffers()
  const materials = useMaterials()
  const [mode, setMode] = React.useState<'demand' | 'offer' | null>(null)
  const dForm = useForm<z.infer<typeof demandSchema>>({ resolver: zodResolver(demandSchema), defaultValues: { material_code: '', recurrence: 'ONE_OFF', quantity_kg: '', min_quality_grade: 'B', max_contamination_pct: '5', need_by: '' } })
  const oForm = useForm<z.infer<typeof offerSchema>>({ resolver: zodResolver(offerSchema), defaultValues: { material_code: '', price_per_kg: '', min_kg: '100', max_contamination_pct: '5', quality_spec: '', valid_to: toLocalInput(new Date(Date.now() + 30 * 86400_000)).slice(0, 10) } })
  const dM = useApiMutation((v: z.infer<typeof demandSchema>) => intelApi.createDemand({ material_code: v.material_code, recurrence: v.recurrence, quantity_kg: Number(v.quantity_kg), min_quality_grade: v.min_quality_grade, max_contamination_pct: Number(v.max_contamination_pct), need_by: v.need_by || null }),
    { invalidate: [K.demand, ['intel', 'shortage']], success: 'Requirement published', onSuccess: () => { setMode(null); dForm.reset() } })
  const oM = useApiMutation((v: z.infer<typeof offerSchema>) => recApi.createOffer({ material_code: v.material_code, price_per_kg: Number(v.price_per_kg), min_kg: Number(v.min_kg), max_contamination_pct: Number(v.max_contamination_pct), quality_spec: v.quality_spec || undefined, valid_to: localToIso(v.valid_to + 'T23:59') }),
    { invalidate: [K.recOffers], success: 'Price offer published', onSuccess: () => { setMode(null); oForm.reset() } })
  const matOptions = materials.data?.map((m) => <option key={m.code} value={m.code}>{m.code} · {m.name}</option>)
  return (
    <>
      <PageHeader title="Procurement requirements" description="Feedstock you need and the gate prices you pay. Requirements drive the aggregation planner and the supply outlook."
        actions={<><Button variant="outline" onClick={() => setMode('offer')}><Plus />Price offer</Button><Button onClick={() => setMode('demand')}><Plus />Requirement</Button></>} />
      <div className="flex flex-col gap-4">
        <Panel title="Demand profiles" flush footer={<SourceLine source="ReLoop API · /recycler/demand-profiles" />}>
          <QueryState query={demand}>{(D) => (
            <DataTable label="Demand profiles" rows={D} rowKey={(d) => d.id} empty={{ title: 'No requirements yet', action: <Button size="sm" onClick={() => setMode('demand')}>Add requirement</Button> }}
              columns={[
                { key: 'm', header: 'Material', cell: (d) => d.material_code, sortValue: (d) => d.material_code },
                { key: 'q', header: 'Quantity', numeric: true, cell: (d) => kg(d.quantity_kg), sortValue: (d) => d.quantity_kg },
                { key: 'r', header: 'Recurrence', cell: (d) => humanize(d.recurrence) },
                { key: 'n', header: 'Need by', cell: (d) => d.need_by ?? '—', sortValue: (d) => d.need_by ?? '' },
                { key: 'g', header: 'Min grade', cell: (d) => d.min_quality_grade },
                { key: 'c', header: 'Max contamination', numeric: true, cell: (d) => pct(d.max_contamination_pct) },
                { key: 's', header: 'Status', cell: (d) => <Badge tone={d.status === 'ACTIVE' ? 'ok' : 'neutral'}>{humanize(d.status)}</Badge> },
                { key: 'x', header: '', cell: () => <Button size="sm" variant="outline" asChild><Link to="/r/planner">Plan sourcing</Link></Button> },
              ]} />
          )}</QueryState>
        </Panel>
        <Panel title="Gate price offers" sub="Published to collectors through the public offers list" flush footer={<SourceLine source="ReLoop API · /recycler/offers" />}>
          <QueryState query={offers}>{(O) => (
            <DataTable label="Price offers" rows={O} rowKey={(o) => o.id} empty={{ title: 'No price offers', action: <Button size="sm" variant="outline" onClick={() => setMode('offer')}>Publish price</Button> }}
              columns={[
                { key: 'm', header: 'Material', cell: (o) => o.material_code, sortValue: (o) => o.material_code },
                { key: 'p', header: 'Price', numeric: true, cell: (o) => `${inr(o.price_per_kg)}/kg`, sortValue: (o) => o.price_per_kg },
                { key: 'min', header: 'Minimum lot', numeric: true, cell: (o) => kg(o.min_kg) },
                { key: 'c', header: 'Max contamination', numeric: true, cell: (o) => pct(o.max_contamination_pct) },
                { key: 'v', header: 'Valid', cell: (o) => <span className="text-xs">{date(o.valid_from)} – {date(o.valid_to)}</span> },
                { key: 's', header: 'Status', cell: (o) => (o.is_active && new Date(o.valid_to) > new Date() ? <Badge tone="ok">Active</Badge> : <Badge>Inactive</Badge>) },
              ]} />
          )}</QueryState>
        </Panel>
      </div>
      <Dialog open={mode === 'demand'} onOpenChange={(o) => !o && setMode(null)}>
        <DialogContent title="New procurement requirement" footer={<><Button variant="outline" onClick={() => setMode(null)}>Cancel</Button><Button loading={dM.isPending} onClick={dForm.handleSubmit((v) => dM.mutate(v))}>Publish requirement</Button></>}>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Material" htmlFor="d-mat" required error={dForm.formState.errors.material_code?.message}><Select id="d-mat" {...dForm.register('material_code')}><option value="">Select</option>{matOptions}</Select></Field>
            <Field label="Quantity (kg)" htmlFor="d-q" required error={dForm.formState.errors.quantity_kg?.message}><Input id="d-q" inputMode="decimal" {...dForm.register('quantity_kg')} /></Field>
            <Field label="Recurrence" htmlFor="d-r"><Select id="d-r" {...dForm.register('recurrence')}><option value="ONE_OFF">One-off</option><option value="WEEKLY">Weekly</option><option value="MONTHLY">Monthly</option></Select></Field>
            <Field label="Need by" htmlFor="d-n"><Input id="d-n" type="date" {...dForm.register('need_by')} /></Field>
            <Field label="Minimum grade" htmlFor="d-g"><Select id="d-g" {...dForm.register('min_quality_grade')}><option>A</option><option>B</option><option>C</option></Select></Field>
            <Field label="Max contamination (%)" htmlFor="d-c" error={dForm.formState.errors.max_contamination_pct?.message}><Input id="d-c" inputMode="decimal" {...dForm.register('max_contamination_pct')} /></Field>
          </div>
          {dM.error && <Note tone="bad">{dM.error.message}</Note>}
        </DialogContent>
      </Dialog>
      <Dialog open={mode === 'offer'} onOpenChange={(o) => !o && setMode(null)}>
        <DialogContent title="Publish gate price" footer={<><Button variant="outline" onClick={() => setMode(null)}>Cancel</Button><Button loading={oM.isPending} onClick={oForm.handleSubmit((v) => oM.mutate(v))}>Publish price</Button></>}>
          <div className="grid gap-4 sm:grid-cols-2">
            <Field label="Material" htmlFor="o-mat" required error={oForm.formState.errors.material_code?.message}><Select id="o-mat" {...oForm.register('material_code')}><option value="">Select</option>{matOptions}</Select></Field>
            <Field label="Price (₹/kg)" htmlFor="o-p" required error={oForm.formState.errors.price_per_kg?.message}><Input id="o-p" inputMode="decimal" {...oForm.register('price_per_kg')} /></Field>
            <Field label="Minimum lot (kg)" htmlFor="o-m" error={oForm.formState.errors.min_kg?.message}><Input id="o-m" inputMode="decimal" {...oForm.register('min_kg')} /></Field>
            <Field label="Max contamination (%)" htmlFor="o-c"><Input id="o-c" inputMode="decimal" {...oForm.register('max_contamination_pct')} /></Field>
            <Field label="Valid until" htmlFor="o-v" required error={oForm.formState.errors.valid_to?.message}><Input id="o-v" type="date" {...oForm.register('valid_to')} /></Field>
            <Field label="Quality specification" htmlFor="o-s"><Input id="o-s" placeholder="Clear bottles, labels removed" {...oForm.register('quality_spec')} /></Field>
          </div>
          {oM.error && <Note tone="bad">{oM.error.message}</Note>}
        </DialogContent>
      </Dialog>
    </>
  )
}

/* ─────────────── Suppliers ─────────────── */
function SupplierRow({ org }: { org: { id: string; legal_name: string; role: string; batches: number } }) {
  const p = usePerformance(org.id)
  const fmt = (v: number | null | undefined) => (v == null ? '—' : pct(v <= 1 ? v * 100 : v))
  return (
    <tr className="[&>td]:border-b [&>td]:border-line [&>td]:px-3 [&>td]:py-2.5">
      <td><b className="font-medium">{org.legal_name}</b><span className="block text-xs text-fg-3">{org.role}</span></td>
      <td className="tnum text-right">{org.batches}</td>
      <td>{p.isPending ? '…' : p.data ? <Badge tone={p.data.history_level === 'SUFFICIENT' ? 'ok' : p.data.history_level === 'LIMITED' ? 'warn' : 'neutral'}>{humanize(p.data.history_level)} · n={p.data.n_transactions}</Badge> : '—'}</td>
      <td className="tnum text-right">{fmt(p.data?.on_time_rate)}</td><td className="tnum text-right">{fmt(p.data?.rejection_rate)}</td>
      <td className="tnum text-right">{fmt(p.data?.weight_discrepancy_pct)}</td><td className="tnum text-right">{fmt(p.data?.contamination_rate)}</td>
    </tr>
  )
}
export function RecyclerSuppliers() {
  const collectors = useOrgs('COLLECTOR')
  const batches = useBatches()
  const B = batches.data ?? []
  const generators = Object.values(B.reduce<Record<string, { id: string; legal_name: string; role: string; batches: number }>>((acc, b) => {
    acc[b.generator_org_id] ??= { id: b.generator_org_id, legal_name: b.generator_name ?? '—', role: 'Generator', batches: 0 }
    acc[b.generator_org_id].batches++
    return acc
  }, {}))
  const cols = (collectors.data ?? []).map((c) => ({ id: c.id, legal_name: c.legal_name, role: 'Collector', batches: B.filter((b) => b.assigned_collector_org_id === c.id).length }))
  return (
    <>
      <PageHeader title="Suppliers" description="Collectors in the ReLoop directory and generators whose batches reached you. Indicators are rule-based and shown with their transaction count n." />
      <Panel flush footer={<><SourceLine source="ReLoop API · /orgs, /suppliers/{org}/performance" /><span>Indicators are hidden until the backend has computed them (history level “insufficient”).</span></>}>
        <QueryState query={collectors}>{() => (
          <div className="overflow-x-auto"><table className="w-full text-[13px]">
            <thead><tr className="text-left text-xs text-fg-2 [&>th]:border-b [&>th]:border-line [&>th]:bg-surface-2 [&>th]:px-3 [&>th]:py-2"><th>Supplier</th><th className="text-right">Batches with you</th><th>Evidence</th><th className="text-right">On-time</th><th className="text-right">Rejection</th><th className="text-right">Weight discrepancy</th><th className="text-right">Contamination</th></tr></thead>
            <tbody>{[...cols, ...generators].map((o) => <SupplierRow key={o.id} org={o} />)}</tbody>
          </table></div>
        )}</QueryState>
      </Panel>
    </>
  )
}

/* ─────────────── Aggregation planner ─────────────── */
export function RecyclerPlanner() {
  const plans = usePlans()
  const materials = useMaterials()
  const demand = useDemand()
  const [open, setOpen] = React.useState<PlanSummary | null>(null)
  const form = useForm<{ material_code: string; target_kg: string }>({ resolver: zodResolver(z.object({ material_code: z.string().min(1, 'Choose a material'), target_kg: kgField('Target') })), defaultValues: { material_code: 'PET', target_kg: '' } })
  const propose = useApiMutation((v: { material_code: string; target_kg: string }) => intelApi.proposePlan({ material_code: v.material_code, target_kg: Number(v.target_kg) }), {
    invalidate: [K.plans, K.batches], success: (d) => `${d.plan_code} created with ${d.items.length} batches`,
  })
  const r = propose.data
  return (
    <>
      <PageHeader title="Aggregation planner" description="Combine small confirmed listings into one feedstock order. Only listed batches are used; predicted supply is never counted." />
      <div className="flex flex-col gap-4">
        <Panel title="Propose a plan">
          <form noValidate className="flex flex-wrap items-end gap-3" onSubmit={form.handleSubmit((v) => propose.mutate(v))}>
            <Field label="Material" htmlFor="p-mat" error={form.formState.errors.material_code?.message}><Select id="p-mat" className="w-44" {...form.register('material_code')}>{materials.data?.map((m) => <option key={m.code} value={m.code}>{m.code}</option>)}</Select></Field>
            <Field label="Target (kg)" htmlFor="p-t" error={form.formState.errors.target_kg?.message}><Input id="p-t" className="w-40" inputMode="decimal" {...form.register('target_kg')} /></Field>
            {demand.data && demand.data.length > 0 && (
              <Field label="Or use a requirement" htmlFor="p-d"><Select id="p-d" className="w-56" defaultValue="" onChange={(e) => { const d = demand.data!.find((x) => x.id === e.target.value); if (d) { form.setValue('material_code', d.material_code); form.setValue('target_kg', String(d.quantity_kg)) } }}>
                <option value="">Select requirement</option>{demand.data.map((d) => <option key={d.id} value={d.id}>{d.material_code} · {kg(d.quantity_kg)} · {humanize(d.recurrence)}</option>)}
              </Select></Field>
            )}
            <Button type="submit" loading={propose.isPending}><Layers />Create plan</Button>
          </form>
          <Note className="mt-3">Creating a plan saves it immediately and reserves the selected listings so other plans cannot use them. Cancel the plan to release them. The backend selects the largest listings first and uses a fixed 92% usable factor and fixed rates for the cost estimate.</Note>
          {propose.error && <Note tone="bad" className="mt-3">{propose.error.message}</Note>}
        </Panel>
        {r && (
          <Panel title={`Result: ${r.plan_code}`} actions={<Button size="sm" variant="outline" onClick={() => setOpen({ id: r.plan_id, plan_code: r.plan_code } as PlanSummary)}>Open plan</Button>}>
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
              <Kpi label="Batches" value={r.items.length} sub={`${kg(r.est_total_kg)} listed`} /><Kpi label="Expected usable" value={kg(r.est_usable_kg)} />
              <Kpi label="Landed cost" value={`${inr(r.cost_estimate.landed_cost_per_usable_kg)}/kg`} sub={`${inr(r.cost_estimate.total_cost, false)} total · model estimate`} />
              <Kpi label={r.shortfall_kg > 0 ? 'Shortfall' : 'Target (listed kg)'} value={r.shortfall_kg > 0 ? kg(r.shortfall_kg) : 'Met'} sub={r.est_usable_kg < r.target_kg ? `Usable kg is ${kg(r.target_kg - r.est_usable_kg)} below target` : undefined} />
            </div>
            {r.items.length === 0 && <EmptyState title="No eligible listings" body={`No unreserved ${form.getValues('material_code')} listings are open.`} />}
            {r.excluded.length > 0 && <p className="mt-3 text-xs text-fg-3">{r.excluded.length} listings excluded ({[...new Set(r.excluded.map((e) => humanize(e.reason)))].join(', ')}).</p>}
          </Panel>
        )}
        <Panel title="Your plans" flush footer={<SourceLine source="ReLoop API · /aggregation/plans" />}>
          <QueryState query={plans}>{(P) => <PlansTable rows={P} onOpen={setOpen} />}</QueryState>
        </Panel>
      </div>
      <Drawer open={!!open} onOpenChange={(o) => !o && setOpen(null)} title={open ? `Plan ${open.plan_code}` : ''}>{open && <PlanDetailView id={open.id} canAct />}</Drawer>
    </>
  )
}

/* ─────────────── Landed cost ─────────────── */
interface Opt { name: string; type: string; est_kg: string; distance_km: string; material_code: string }
export function RecyclerCosts() {
  const pricing = usePricing()
  const materials = useMaterials()
  const form = useForm<{ options: Opt[] }>({ defaultValues: { options: [
    { name: 'Aggregated listings (Mumbai east)', type: 'PLAN', est_kg: '400', distance_km: '15', material_code: 'PET' },
    { name: 'Single collector bale', type: 'COLLECTOR', est_kg: '400', distance_km: '30', material_code: 'PET' },
  ] } })
  const { fields, append, remove } = useFieldArray({ control: form.control, name: 'options' })
  const compare = useApiMutation((o: Opt[]) => intelApi.compareCosts(o.map((x) => ({ ...x, est_kg: Number(x.est_kg), distance_km: Number(x.distance_km) }))), { invalidate: [] })
  const estimate = useApiMutation((v: { est_kg: number; material_code: string; distance_km: number }) => intelApi.estimateCost(v), { invalidate: [] })
  return (
    <>
      <PageHeader title="Landed cost comparison" description="Cost per usable kilogram after expected rejection and process loss, for sourcing options you describe." />
      <Note tone="warn" className="mb-4" title="Model estimates">The backend cost endpoints use fixed rates (generator ₹14.5–15/kg, collector ₹7.5–8/kg, 15–17% loss). They do not yet read the versioned pricing assumptions below. Treat results as indicative.</Note>
      <div className="grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <div className="flex flex-col gap-4">
          <Panel title="Compare options" footer={<div className="flex w-full justify-between"><Button size="sm" variant="outline" onClick={() => append({ name: `Option ${fields.length + 1}`, type: 'BATCH', est_kg: '200', distance_km: '20', material_code: 'PET' })}><Plus />Add option</Button>
            <Button size="sm" loading={compare.isPending} onClick={form.handleSubmit((v) => compare.mutate(v.options))}>Compare</Button></div>}>
            <div className="flex flex-col gap-3">
              {fields.map((f, i) => (
                <div key={f.id} className="grid grid-cols-2 gap-2 rounded-md border border-line p-3 sm:grid-cols-[2fr_1fr_1fr_1fr_auto] sm:items-end">
                  <Field label="Name" htmlFor={`o${i}n`} className="col-span-2 sm:col-span-1"><Input id={`o${i}n`} {...form.register(`options.${i}.name`)} /></Field>
                  <Field label="Material" htmlFor={`o${i}m`}><Select id={`o${i}m`} {...form.register(`options.${i}.material_code`)}>{materials.data?.map((m) => <option key={m.code}>{m.code}</option>)}</Select></Field>
                  <Field label="Gross kg" htmlFor={`o${i}k`}><Input id={`o${i}k`} inputMode="decimal" {...form.register(`options.${i}.est_kg`)} /></Field>
                  <Field label="Distance km" htmlFor={`o${i}d`}><Input id={`o${i}d`} inputMode="decimal" {...form.register(`options.${i}.distance_km`)} /></Field>
                  <Button variant="ghost" size="sm" disabled={fields.length <= 1} onClick={() => remove(i)}>Remove</Button>
                </div>
              ))}
            </div>
          </Panel>
          {compare.data && (
            <Panel title="Ranked by cost per usable kg" flush footer={<SourceLine source="ReLoop API · /costs/compare (model estimate)" />}>
              <DataTable label="Cost comparison" rows={compare.data.ranked_options} rowKey={(r) => r.name} columns={[
                { key: 'n', header: 'Option', cell: (r) => <span><b className="font-medium">{r.name}</b>{r === compare.data!.ranked_options[0] && <Badge tone="ok" className="ml-2">Lowest</Badge>}</span> },
                { key: 'g', header: 'Gross kg', numeric: true, cell: (r) => num1(r.est_kg) },
                { key: 'u', header: 'Usable kg', numeric: true, cell: (r) => num1(r.usable_kg) },
                { key: 'gen', header: 'Generator', numeric: true, cell: (r) => inr(r.breakdown.generator, false) },
                { key: 'col', header: 'Collector', numeric: true, cell: (r) => inr(r.breakdown.collector, false) },
                { key: 'tr', header: 'Transport', numeric: true, cell: (r) => inr(r.breakdown.transport, false) },
                { key: 't', header: 'Total', numeric: true, cell: (r) => inr(r.total_cost, false) },
                { key: 'l', header: '₹ / usable kg', numeric: true, cell: (r) => <b>{inr(r.landed_cost_per_usable_kg)}</b> },
              ]} />
            </Panel>
          )}
          {compare.error && <Note tone="bad">{compare.error.message}</Note>}
        </div>
        <div className="flex flex-col gap-4">
          <Panel title="Quick estimate">
            <form noValidate className="flex flex-col gap-3" onSubmit={(e) => { e.preventDefault(); const f = new FormData(e.currentTarget); estimate.mutate({ est_kg: Number(f.get('k')), material_code: String(f.get('m')), distance_km: Number(f.get('d')) }) }}>
              <div className="grid grid-cols-3 gap-2">
                <Field label="Material" htmlFor="qe-m"><Select id="qe-m" name="m">{materials.data?.map((m) => <option key={m.code}>{m.code}</option>)}</Select></Field>
                <Field label="Gross kg" htmlFor="qe-k"><Input id="qe-k" name="k" defaultValue="500" inputMode="decimal" /></Field>
                <Field label="Km" htmlFor="qe-d"><Input id="qe-d" name="d" defaultValue="15" inputMode="decimal" /></Field>
              </div>
              <Button type="submit" variant="outline" loading={estimate.isPending}>Estimate</Button>
            </form>
            {estimate.data && <div className="mt-3"><KV rows={[...Object.entries(estimate.data.breakdown).map(([k, v]) => [humanize(k), inr(v)] as [string, string]), ['Expected usable', kg(estimate.data.expected_usable_kg)], ['Total', inr(estimate.data.total_cost), true], ['Per usable kg', inr(estimate.data.landed_cost_per_usable_kg), true]]} /></div>}
          </Panel>
          <Panel title="Pricing assumptions" sub="Versioned; recorded on the platform but not yet used by the cost endpoints" footer={<SourceLine source="ReLoop API · /pricing-assumptions" />}>
            <QueryState query={pricing}>{(p) => (
              <KV rows={[['Version', `v${p.version}`], ['Transport per km', inr(p.transport_per_km)], ['Transport per kg·km', inr(p.transport_per_kg_km)], ['Sorting per kg', inr(p.sorting_per_kg)], ['Handling per kg', inr(p.handling_per_kg)],
                ['Storage per kg·day', inr(p.storage_per_kg_day)], ['Rejection disposal per kg', inr(p.rejection_cost_per_kg)],
                ...Object.entries(p.default_rejection_rate ?? {}).map(([m, v]) => [`Default rejection · ${m}`, pct(v * 100)] as [string, string]),
                ...Object.entries(p.default_process_loss_rate ?? {}).map(([m, v]) => [`Default process loss · ${m}`, pct(v * 100)] as [string, string])]} />
            )}</QueryState>
          </Panel>
        </div>
      </div>
    </>
  )
}

/* ─────────────── Supply outlook ─────────────── */
const PLACEHOLDER = { demand: 6000, confirmed: 2500, predicted: 4800 } // values the backend substitutes for zero (audit D8)
export function RecyclerOutlook() {
  const materials = useMaterials()
  const [mat, setMat] = React.useState('PET')
  const shortage = useShortage(mat)
  const supply = useSupplyForecasts()
  const demandFc = useDemandForecasts()
  const demand = useDemand()
  const matId = materials.data?.find((m) => m.code === mat)?.id
  const fcRows = (supply.data ?? []).filter((f) => f.material_category_id === matId)
  const myDemand = (demand.data ?? []).filter((d) => d.material_code === mat && d.status === 'ACTIVE')
  const suspect = (k: keyof typeof PLACEHOLDER, v: number) => v === PLACEHOLDER[k] && (k === 'demand' ? myDemand.length === 0 : k === 'predicted' ? fcRows.length === 0 : true)
  return (
    <>
      <PageHeader title="Supply outlook" description="Requirement against confirmed supply and the forecast. Forecasts help planning; they are never counted as inventory."
        actions={<Select aria-label="Material" value={mat} onChange={(e) => setMat(e.target.value)} className="w-40">{materials.data?.map((m) => <option key={m.code}>{m.code}</option>)}</Select>} />
      <div className="flex flex-col gap-4">
        <QueryState query={shortage}>{(s) => {
          const anySuspect = suspect('demand', s.demand_kg) || suspect('confirmed', s.confirmed_supply_kg) || suspect('predicted', s.predicted_supply_kg)
          const mark = (k: keyof typeof PLACEHOLDER, v: number) => (suspect(k, v) ? <Badge tone="warn" dot={false}>Possible placeholder</Badge> : null)
          return (
            <>
              {anySuspect && <Note tone="warn" title="Some figures may be backend placeholders">When a value is zero, the backend’s shortage endpoint substitutes 6,000 kg demand, 2,500 kg confirmed or 4,800 kg predicted (audit D8). Values matching these with no supporting records are marked. The backend’s suggested suppliers are hard-coded names and are not shown.</Note>}
              <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
                <Kpi label="Requirement" value={kg(s.demand_kg)} sub={mark('demand', s.demand_kg) ?? `${myDemand.length} active requirement${myDemand.length === 1 ? '' : 's'} of yours`} />
                <Kpi label="Confirmed supply" value={kg(s.confirmed_supply_kg)} sub={mark('confirmed', s.confirmed_supply_kg) ?? 'Assigned, picked up or in transit (all recyclers)'} />
                <Kpi label="Gap on confirmed supply" value={kg(s.gap_confirmed_kg)} sub="Act on this number" />
                <Kpi label="Predicted supply" value={kg(s.predicted_supply_kg)} sub={mark('predicted', s.predicted_supply_kg) ?? 'Forecast, not inventory'} />
              </div>
              <Panel title={`${mat}: requirement vs supply`} footer={<SourceLine source="ReLoop API · /forecasts/shortages" />}>
                <div className="h-56"><ResponsiveContainer><BarChart data={[{ n: mat, Requirement: s.demand_kg, Confirmed: s.confirmed_supply_kg, Predicted: s.predicted_supply_kg }]} layout="vertical" margin={{ left: 8 }}>
                  <CartesianGrid horizontal={false} stroke="var(--line)" /><XAxis type="number" {...axis} /><YAxis type="category" dataKey="n" {...axis} width={50} /><Tooltip {...tt} formatter={(v: number) => kg(v)} /><Legend wrapperStyle={{ fontSize: 12 }} />
                  <Bar dataKey="Requirement" fill="var(--c6)" /><Bar dataKey="Confirmed" stackId="s" fill="var(--c1)" /><Bar dataKey="Predicted" stackId="s" fill="var(--c3)" /></BarChart></ResponsiveContainer></div>
                <p className="mt-2 text-xs text-fg-3">Predicted supply is stacked on confirmed supply for comparison only. Gap after prediction: {kg(s.gap_expected_kg)}.</p>
              </Panel>
            </>
          )
        }}</QueryState>
        <Panel title="Supply forecasts" sub="Rows labelled PREDICTED by the backend" flush footer={<SourceLine source="ReLoop API · /forecasts/supply, /forecasts/demand" />}>
          <QueryState query={supply}>{(F) => (
            <DataTable label="Forecasts" rows={[...F, ...(demandFc.data ?? [])]} rowKey={(f) => `${f.kind}${f.period_start}${f.material_category_id}${f.locality}`}
              empty={{ title: 'No forecasts recorded' }}
              columns={[
                { key: 'k', header: 'Kind', cell: (f) => <Badge tone={f.kind === 'PREDICTED' ? 'info' : 'neutral'}>{f.kind === 'PREDICTED' ? 'Predicted supply' : 'Demand forecast'}</Badge> },
                { key: 'm', header: 'Material', cell: (f) => materials.data?.find((m) => m.id === f.material_category_id)?.code ?? '—' },
                { key: 'l', header: 'Locality', cell: (f) => f.locality ?? '—' },
                { key: 'p', header: 'Period', cell: (f) => <span className="text-xs">{date(f.period_start)} – {date(f.period_end)}</span>, sortValue: (f) => f.period_start },
                { key: 'v', header: 'Predicted kg', numeric: true, cell: (f) => num0(f.predicted_kg), sortValue: (f) => f.predicted_kg },
                { key: 'r', header: 'Range', numeric: true, cell: (f) => (f.lower_kg != null ? `${num0(f.lower_kg)}–${num0(f.upper_kg)}` : '—') },
                { key: 'c', header: 'Confidence', cell: (f) => humanize(f.confidence_label) },
              ]} />
          )}</QueryState>
        </Panel>
      </div>
    </>
  )
}

/* ─────────────── Receipt form (shared by Incoming and Receipts) ─────────────── */
const receiptSchema = z.object({
  received_kg: kgField('Received weight'), accepted_kg: kgFieldAllowZero('Accepted weight'), rejected_kg: kgFieldAllowZero('Rejected weight'),
  quality_grade: z.string(), contamination_pct: z.string().refine((v) => v === '' || (Number(v) >= 0 && Number(v) <= 100), '0–100'),
  rejection_disposition: z.string().max(300).optional(), reason: z.string().optional(),
}).refine((v) => receiptBalances(Number(v.received_kg), Number(v.accepted_kg), Number(v.rejected_kg)), { path: ['rejected_kg'], message: 'Accepted + rejected must equal received' })
  .refine((v) => Number(v.rejected_kg) === 0 || (v.rejection_disposition ?? '').trim().length > 2, { path: ['rejection_disposition'], message: 'Say what happens to the rejected material' })
type ReceiptForm = z.infer<typeof receiptSchema>

export function ReceiptDialog({ batch, existing, onClose }: { batch: Pick<Batch, 'id' | 'batch_code' | 'material' | 'quantities'>; existing?: Receipt; onClose: () => void }) {
  const collected = q(batch.quantities.collected_kg)
  const schema = existing ? receiptSchema.refine((v) => (v.reason ?? '').trim().length >= 5, { path: ['reason'], message: 'Give a reason for the correction' }) : receiptSchema
  const form = useForm<ReceiptForm>({ resolver: zodResolver(schema), defaultValues: existing
    ? { received_kg: String(existing.received_kg), accepted_kg: String(existing.accepted_kg), rejected_kg: String(existing.rejected_kg), quality_grade: existing.quality_grade, contamination_pct: String(existing.contamination_pct), rejection_disposition: existing.rejection_disposition ?? '', reason: '' }
    : { received_kg: '', accepted_kg: '', rejected_kg: '0', quality_grade: 'B', contamination_pct: '', rejection_disposition: '' } })
  const [slip, setSlip] = React.useState<{ id: string; name: string } | null>(null)
  const recv = Number(form.watch('received_kg')), acc = Number(form.watch('accepted_kg')), rej = Number(form.watch('rejected_kg'))
  React.useEffect(() => { if (recv > 0 && acc >= 0 && acc <= recv) form.setValue('rejected_kg', String(Math.round((recv - acc) * 1000) / 1000)) }, [recv, acc, form])
  const transit = collected && recv > 0 ? ((recv - collected) / collected) * 100 : null
  const m = useApiMutation(async (v: ReceiptForm) => {
    const base = { received_kg: Number(v.received_kg), accepted_kg: Number(v.accepted_kg), rejected_kg: Number(v.rejected_kg), quality_grade: v.quality_grade, contamination_pct: Number(v.contamination_pct || 0) }
    if (existing) return recApi.correctReceipt(existing.id, { ...base, reason: v.reason!.trim() })
    return recApi.createReceipt({ ...base, batch_id: batch.id, rejection_disposition: v.rejection_disposition || null, document_ids: slip ? [slip.id] : [] })
  }, { invalidate: [K.batches, K.receipts(), K.receipts(true), K.incoming, K.consignments], toastErrors: false, success: existing ? 'Correction saved as a new version; the original is kept' : 'Receipt recorded', onSuccess: onClose })
  const fe = m.error instanceof ApiError ? m.error.fieldErrors() : {}
  const err = (k: keyof ReceiptForm) => form.formState.errors[k]?.message ?? fe[k]
  return (
    <DialogContent title={existing ? `Correct receipt · ${batch.batch_code}` : `Record receipt · ${batch.batch_code}`} description={`${batch.material} · collected ${kg(collected)}`}
      footer={<><Button variant="outline" onClick={onClose}>Cancel</Button><Button loading={m.isPending} onClick={form.handleSubmit((v) => m.mutate(v))}>{existing ? 'Save as new version' : 'Save receipt'}</Button></>}>
      <div className="grid gap-4 sm:grid-cols-3">
        <Field label="Received (kg)" htmlFor="r-rec" required error={err('received_kg')}><Input id="r-rec" inputMode="decimal" {...form.register('received_kg')} /></Field>
        <Field label="Accepted (kg)" htmlFor="r-acc" required error={err('accepted_kg')}><Input id="r-acc" inputMode="decimal" {...form.register('accepted_kg')} /></Field>
        <Field label="Rejected (kg)" htmlFor="r-rej" required error={err('rejected_kg')} hint="Received − accepted"><Input id="r-rej" inputMode="decimal" {...form.register('rejected_kg')} /></Field>
        <Field label="Grade" htmlFor="r-g"><Select id="r-g" {...form.register('quality_grade')}><option>A</option><option>B</option><option>C</option></Select></Field>
        <Field label="Contamination (%)" htmlFor="r-c" error={err('contamination_pct')}><Input id="r-c" inputMode="decimal" {...form.register('contamination_pct')} /></Field>
        {!existing && <Field label="Weighbridge slip" htmlFor="r-slip" hint="SHA-256 recorded">
          <label htmlFor="r-slip" className="flex h-9 cursor-pointer items-center gap-2 rounded-md border border-dashed border-line-2 px-2.5 text-[12.5px] text-fg-2 hover:bg-surface-2"><Upload className="size-3.5" /><span className="truncate">{slip ? slip.name : 'Attach'}</span></label>
          <input id="r-slip" type="file" className="sr-only" onChange={async (e) => { const f = e.target.files?.[0]; if (f) { const r = await registerDocument(f, 'WEIGHBRIDGE_SLIP'); setSlip({ id: r.document_id, name: f.name }) } }} />
        </Field>}
        {!existing && <Field label="Rejected material goes to" htmlFor="r-d" className="sm:col-span-3" error={err('rejection_disposition')} required={rej > 0}><Input id="r-d" placeholder="Co-processing / returned to collector" {...form.register('rejection_disposition')} /></Field>}
        {existing && <Field label="Reason for correction" htmlFor="r-reason" className="sm:col-span-3" required error={err('reason')}><Textarea id="r-reason" rows={2} placeholder="Re-weighed after drying" {...form.register('reason')} /></Field>}
      </div>
      {recv > 0 && (receiptBalances(recv, acc, rej)
        ? <Note tone="ok">Accepted {num1(acc)} + rejected {num1(rej)} = received {num1(recv)} kg.</Note>
        : <Note tone="bad">Accepted + rejected must equal received. The server rejects unbalanced receipts.</Note>)}
      {transit != null && Math.abs(transit) > 2 && <Note tone="warn">Received differs from collected by {pct(transit)}, beyond the 2% weighing tolerance. Record it as weighed; the difference stays visible to the collector and NGO reviewer.</Note>}
      {existing && existing.processed_input_kg != null && existing.processed_input_kg > 0 && <Note>{kg(existing.processed_input_kg)} of this batch is already in processing runs. Accepted cannot be corrected below that.</Note>}
      {m.error && !Object.keys(fe).length && <Note tone="bad" title={m.error.code === 'RECEIPT_EXISTS' ? 'Already received' : 'Not saved'}>{m.error.message}</Note>}
    </DialogContent>
  )
}

/* ─────────────── Incoming ─────────────── */
export function RecyclerIncoming() {
  const cons = useConsignments()
  const incoming = useIncoming()
  const batches = useBatches()
  const collectors = useOrgs('COLLECTOR')
  const [open, setOpen] = React.useState<Consignment | null>(null)
  const [receiving, setReceiving] = React.useState<Batch | null>(null)
  const arrive = useApiMutation((id: string) => consApi.markArrived(id), { invalidate: [K.consignments], success: 'Marked as arrived' })
  const batchById = (id: string) => batches.data?.find((b) => b.id === id)
  const colName = (id: string) => collectors.data?.find((c) => c.id === id)?.legal_name ?? '—'
  const pending = (cons.data ?? []).filter((c) => c.items.some((i) => ['IN_TRANSIT', 'PICKED_UP'].includes(batchById(i.batch_id)?.status ?? i.status)))
  return (
    <>
      <PageHeader title="Incoming consignments" description="Vehicles on the way or at your gate. Each batch is weighed and inspected on its own." />
      <div className="flex flex-col gap-4">
        <Panel flush title="Consignments to receive" footer={<SourceLine source="ReLoop API · /consignments, /recycler/incoming" />}>
          <QueryState query={cons}>{() => (
            <DataTable label="Consignments to receive" rows={pending} rowKey={(c) => c.id} onRowClick={setOpen} initialSort={{ key: 'd', dir: -1 }}
              empty={{ title: 'Nothing incoming', body: 'Consignments that collectors dispatch to you appear here.' }}
              columns={[
                { key: 'c', header: 'Consignment', cell: (c) => <span className="font-mono text-xs">{c.consignment_code}</span> },
                { key: 'col', header: 'Collector', cell: (c) => colName(c.collector_org_id) },
                { key: 'd', header: 'Dispatched', cell: (c) => <span className="text-xs">{dateTime(c.dispatched_at)}</span>, sortValue: (c) => c.dispatched_at },
                { key: 'n', header: 'Batches', numeric: true, cell: (c) => c.items.length },
                { key: 'kg', header: 'Collected kg', numeric: true, cell: (c) => num1(c.items.reduce((s, i) => s + (q(batchById(i.batch_id)?.quantities.collected_kg) ?? 0), 0)) },
                { key: 's', header: 'Status', cell: (c) => <SimpleStatus status={consStatus(c)} map={CONS_STATUS} /> },
                { key: 'x', header: '', cell: (c) => (consStatus(c) === 'IN_TRANSIT'
                  ? <Button size="sm" variant="outline" loading={arrive.isPending && arrive.variables === c.id} onClick={(e) => { e.stopPropagation(); arrive.mutate(c.id) }}>Mark arrived</Button>
                  : <Button size="sm" onClick={(e) => { e.stopPropagation(); setOpen(c) }}>Receive batches</Button>) },
              ]} />
          )}</QueryState>
        </Panel>
        <Panel flush title="Batches destined for you" sub="From /recycler/incoming">
          <QueryState query={incoming}>{(I) => (
            <DataTable label="Incoming batches" rows={I} rowKey={(b) => b.batch_id} empty={{ title: 'No batches in transit to you' }}
              columns={[
                { key: 'c', header: 'Batch', cell: (b) => <BatchLink code={b.batch_code} /> },
                { key: 'l', header: 'From', cell: (b) => b.locality ?? '—' },
                { key: 'e', header: 'Listed kg', numeric: true, cell: (b) => num1(b.estimated_kg) },
                { key: 'col', header: 'Collected kg', numeric: true, cell: (b) => num1(q(batchById(b.batch_id)?.quantities.collected_kg)) },
                { key: 's', header: 'Status', cell: (b) => <BatchStatusBadge status={b.status} /> },
              ]} />
          )}</QueryState>
        </Panel>
      </div>
      <Drawer open={!!open} onOpenChange={(o) => !o && setOpen(null)} title={open ? `Receive ${open.consignment_code}` : ''} sub={open ? colName(open.collector_org_id) : undefined}>
        {open && (
          <>
            <ConsignmentDetail consignment={open} />
            <Panel title="Record receipts">
              <div className="flex flex-col gap-2">
                {open.items.map((it) => { const b = batchById(it.batch_id); const done = b && q(b.quantities.received_kg) != null; return (
                  <div key={it.batch_id} className="flex flex-wrap items-center justify-between gap-2 rounded-md border border-line px-3 py-2">
                    <span className="text-[13px]"><span className="font-mono">{it.batch_code}</span> · {b?.material} · collected {kg(q(b?.quantities.collected_kg))}</span>
                    {done ? <Badge tone="ok">Received {kg(q(b!.quantities.received_kg))}</Badge>
                      : <Button size="sm" disabled={!b || open.status !== 'ARRIVED'} title={open.status !== 'ARRIVED' ? 'Mark the consignment as arrived first' : undefined} onClick={() => setReceiving(b!)}>Record receipt</Button>}
                  </div>) })}
              </div>
              {open.status !== 'ARRIVED' && <Note className="mt-3">Mark the consignment as arrived before recording receipts.</Note>}
            </Panel>
          </>
        )}
      </Drawer>
      <Dialog open={!!receiving} onOpenChange={(o) => !o && setReceiving(null)}>{receiving && <ReceiptDialog batch={receiving} onClose={() => setReceiving(null)} />}</Dialog>
    </>
  )
}

/* ─────────────── Receipts ─────────────── */
export function RecyclerReceipts() {
  const [history, setHistory] = React.useState(false)
  const receipts = useReceipts(history)
  const batches = useBatches()
  const [correcting, setCorrecting] = React.useState<Receipt | null>(null)
  const batchOf = (r: Receipt) => batches.data?.find((b) => b.id === r.batch_id)
  return (
    <>
      <PageHeader title="Material receipts" description="Weights and inspection results recorded at your gate. A correction creates a new version and keeps the original."
        actions={<label className="flex items-center gap-2 text-[13px]"><input type="checkbox" checked={history} onChange={(e) => setHistory(e.target.checked)} />Show superseded versions</label>} />
      <Panel flush footer={<><SourceLine source="ReLoop API · /recycler/receipts" /><span>Rule: accepted + rejected = received (enforced by the server).</span></>}>
        <QueryState query={receipts}>{(R) => (
          <DataTable label="Receipts" rows={R} rowKey={(r) => r.id} initialSort={{ key: 'd', dir: -1 }} search={(r) => r.batch_code} searchPlaceholder="Search batch"
            rowClassName={(r) => (r.is_current ? undefined : 'opacity-60')}
            filters={[{ key: 'm', label: 'Material', options: [...new Set(R.map((r) => r.material_code))].map((m) => ({ value: m, label: m })), get: (r) => r.material_code }, { key: 'g', label: 'Grade', options: ['A', 'B', 'C'].map((g) => ({ value: g, label: g })), get: (r) => r.quality_grade }]}
            empty={{ title: 'No receipts yet', body: 'Receipts are recorded from incoming consignments.', action: <Button size="sm" asChild><Link to="/r/incoming">Incoming</Link></Button> }}
            columns={[
              { key: 'c', header: 'Batch', cell: (r) => <BatchLink code={r.batch_code} />, sortValue: (r) => r.batch_code },
              { key: 'm', header: 'Material', cell: (r) => r.material_code },
              { key: 'd', header: 'Received', cell: (r) => <span className="text-xs">{dateTime(r.received_at)}</span>, sortValue: (r) => r.received_at },
              { key: 'col', header: 'Collected', numeric: true, cell: (r) => num1(q(batchOf(r)?.quantities.collected_kg)) },
              { key: 'rec', header: 'Received kg', numeric: true, cell: (r) => num1(r.received_kg), sortValue: (r) => r.received_kg },
              { key: 'a', header: 'Accepted', numeric: true, cell: (r) => num1(r.accepted_kg), sortValue: (r) => r.accepted_kg },
              { key: 'x', header: 'Rejected', numeric: true, cell: (r) => num1(r.rejected_kg), sortValue: (r) => r.rejected_kg },
              { key: 'g', header: 'Grade', cell: (r) => `${r.quality_grade} · ${pct(r.contamination_pct)}` },
              { key: 'v', header: 'Version', cell: (r) => <span>v{r.version} {r.is_current ? <Badge tone="ok">Current</Badge> : <Badge>Superseded</Badge>}</span> },
              { key: 'av', header: 'Not yet processed', numeric: true, cell: (r) => (r.available_kg != null ? num1(r.available_kg) : '—'), sortValue: (r) => r.available_kg },
              { key: 'z', header: '', cell: (r) => (r.is_current ? <Button size="sm" variant="ghost" onClick={() => setCorrecting(r)}>Correct</Button> : null) },
            ]}
            footer={(rows) => { const cur = rows.filter((r) => r.is_current); return <tr><td colSpan={4}>Current versions ({cur.length})</td><td className="tnum text-right">{num1(cur.reduce((s, r) => s + r.received_kg, 0))}</td><td className="tnum text-right">{num1(cur.reduce((s, r) => s + r.accepted_kg, 0))}</td><td className="tnum text-right">{num1(cur.reduce((s, r) => s + r.rejected_kg, 0))}</td><td colSpan={2} /><td className="tnum text-right">{num1(cur.reduce((s, r) => s + (r.available_kg ?? 0), 0))}</td><td /></tr> }} />
        )}</QueryState>
      </Panel>
      <Dialog open={!!correcting} onOpenChange={(o) => !o && setCorrecting(null)}>
        {correcting && <ReceiptDialog existing={correcting} batch={{ id: correcting.batch_id, batch_code: correcting.batch_code, material: correcting.material_code, quantities: batchOf(correcting)?.quantities ?? { estimated_kg: '0', collected_kg: null, received_kg: null, accepted_kg: null, rejected_kg: null, processed_kg: null, ngo_verified_kg: null, epr_allocated_kg: null } }} onClose={() => setCorrecting(null)} />}
      </Dialog>
    </>
  )
}

/* ─────────────── Processing runs ─────────────── */
function RunsTable({ rows, onOpen }: { rows: ProcessingRecord[]; onOpen: (r: ProcessingRecord) => void }) {
  return (
    <DataTable label="Processing runs" rows={rows} rowKey={(r) => r.id} onRowClick={onOpen} initialSort={{ key: 'd', dir: -1 }}
      empty={{ title: 'No processing runs yet' }}
      columns={[
        { key: 'c', header: 'Run', cell: (r) => <span className="font-mono text-xs">{r.record_code}</span>, sortValue: (r) => r.record_code },
        { key: 'd', header: 'Started', cell: (r) => <span className="text-xs">{dateTime(r.run_started_at)}</span>, sortValue: (r) => r.run_started_at },
        { key: 'm', header: 'Material', cell: (r) => r.material_code },
        { key: 'i', header: 'Input', numeric: true, cell: (r) => num1(r.input_kg), sortValue: (r) => r.input_kg },
        { key: 'o', header: 'Output', numeric: true, cell: (r) => num1(r.output_kg), sortValue: (r) => r.output_kg },
        { key: 'res', header: 'Residue', numeric: true, cell: (r) => num1(r.residue_kg) },
        { key: 'y', header: 'Yield', numeric: true, cell: (r) => pct(r.yield_pct), sortValue: (r) => r.yield_pct },
        { key: 'u', header: 'Unaccounted', numeric: true, sortValue: (r) => (r.input_kg - r.output_kg - r.residue_kg) / r.input_kg,
          cell: (r) => { const u = ((r.input_kg - r.output_kg - r.residue_kg) / r.input_kg) * 100; return <span className={u > 3 ? 'font-semibold text-bad' : ''}>{pct(u)}</span> } },
        { key: 'e', header: 'Eligible', numeric: true, cell: (r) => num1(r.eligible_kg) },
        { key: 'a', header: 'Allocated', numeric: true, cell: (r) => num1(r.allocated_kg) },
        { key: 'f', header: 'Free', numeric: true, cell: (r) => <b>{num1(r.available_kg)}</b>, sortValue: (r) => r.available_kg },
      ]} />
  )
}
const runSchema = z.object({
  material_code: z.string().min(1, 'Choose a material'),
  run_started_at: z.string().min(1, 'Required'), run_ended_at: z.string().min(1, 'Required'),
  inputs: z.array(z.object({ receipt_id: z.string(), use: z.boolean(), input_kg: z.string(), max: z.number() })),
  output_kg: kgFieldAllowZero('Output'), residue_kg: kgFieldAllowZero('Residue'), eligible_kg: kgFieldAllowZero('Eligible'),
  output_form: z.string().optional(), eligibility_basis: z.string().optional(),
}).superRefine((v, ctx) => {
  const used = v.inputs.filter((i) => i.use)
  if (!used.length) ctx.addIssue({ code: 'custom', path: ['inputs'], message: 'Select at least one receipt as input' })
  used.forEach((i) => {
    const n = Number(i.input_kg)
    if (!(n > 0)) ctx.addIssue({ code: 'custom', path: ['inputs'], message: 'Enter kg for each selected input' })
    else if (n > i.max + 0.0005) ctx.addIssue({ code: 'custom', path: ['inputs'], message: `An input exceeds its available ${num1(i.max)} kg` })
  })
  const input = used.reduce((s, i) => s + (Number(i.input_kg) || 0), 0)
  if (Number(v.output_kg) + Number(v.residue_kg) > input + 0.001) ctx.addIssue({ code: 'custom', path: ['residue_kg'], message: `Output + residue cannot exceed input (${num1(input)} kg)` })
  if (Number(v.eligible_kg) > Number(v.output_kg) + 0.001) ctx.addIssue({ code: 'custom', path: ['eligible_kg'], message: 'Eligible cannot exceed measured output' })
  if (new Date(v.run_ended_at) < new Date(v.run_started_at)) ctx.addIssue({ code: 'custom', path: ['run_ended_at'], message: 'End must be after start' })
})
type RunForm = z.infer<typeof runSchema>
function RunDialog({ onClose }: { onClose: () => void }) {
  const receipts = useReceipts()
  const materials = useMaterials()
  const avail = (receipts.data ?? []).filter((r) => r.is_current && (r.available_kg ?? 0) > 0.0005)
  const form = useForm<RunForm>({ resolver: zodResolver(runSchema), defaultValues: { material_code: '', run_started_at: toLocalInput(new Date(Date.now() - 4 * 3600_000)), run_ended_at: toLocalInput(new Date()), inputs: [], output_kg: '', residue_kg: '', eligible_kg: '', output_form: 'flakes', eligibility_basis: '' } })
  const mat = form.watch('material_code')
  React.useEffect(() => { form.setValue('inputs', avail.filter((r) => r.material_code === mat).map((r) => ({ receipt_id: r.id, use: false, input_kg: String(r.available_kg), max: r.available_kg ?? 0 }))) }, [mat, receipts.data]) // eslint-disable-line
  const inputs = form.watch('inputs')
  const input = inputs.filter((i) => i.use).reduce((s, i) => s + (Number(i.input_kg) || 0), 0)
  const out = Number(form.watch('output_kg')), res = Number(form.watch('residue_kg'))
  const un = input - out - res
  const m = useApiMutation((v: RunForm) => recApi.createProcessing({
    material_code: v.material_code, run_started_at: localToIso(v.run_started_at), run_ended_at: localToIso(v.run_ended_at),
    inputs: v.inputs.filter((i) => i.use).map((i) => ({ recycler_receipt_id: i.receipt_id, input_kg: Number(i.input_kg) })),
    output_kg: Number(v.output_kg), residue_kg: Number(v.residue_kg), eligible_kg: Number(v.eligible_kg), output_form: v.output_form || null, eligibility_basis: v.eligibility_basis || null,
  }), { invalidate: [K.processing, K.receipts(), K.receipts(true), K.batches, K.yield, K.capacity, K.verifications], toastErrors: false, success: (d) => `${d.record_code} recorded: yield ${pct(d.yield_pct)}. Batches queued for NGO review.`, onSuccess: onClose })
  const mats = [...new Set(avail.map((r) => r.material_code))]
  return (
    <DialogContent wide title="Record processing run" description="Select accepted stock used as input and enter measured quantities. Only your organisation can record processing outcomes."
      footer={<><Button variant="outline" onClick={onClose}>Cancel</Button><Button loading={m.isPending} onClick={form.handleSubmit((v) => m.mutate(v))}>Save run</Button></>}>
      <div className="grid gap-4 sm:grid-cols-3">
        <Field label="Material" htmlFor="run-m" required error={form.formState.errors.material_code?.message} hint="A run processes one material">
          <Select id="run-m" {...form.register('material_code')}><option value="">{receipts.isPending ? 'Loading…' : mats.length ? 'Select' : 'No unprocessed stock'}</option>{mats.map((c) => <option key={c} value={c}>{c} · {materials.data?.find((x) => x.code === c)?.name}</option>)}</Select>
        </Field>
        <Field label="Started" htmlFor="run-s" required error={form.formState.errors.run_started_at?.message}><Input id="run-s" type="datetime-local" {...form.register('run_started_at')} /></Field>
        <Field label="Ended" htmlFor="run-e" required error={form.formState.errors.run_ended_at?.message}><Input id="run-e" type="datetime-local" {...form.register('run_ended_at')} /></Field>
      </div>
      {mat && (
        <div className="overflow-x-auto rounded-md border border-line">
          <table className="w-full text-[13px]"><thead><tr className="text-left text-xs text-fg-2 [&>th]:bg-surface-2 [&>th]:px-3 [&>th]:py-2"><th>Use</th><th>Batch</th><th className="text-right">Accepted</th><th className="text-right">Available</th><th className="text-right">Input kg</th></tr></thead>
            <tbody>{inputs.map((i, idx) => { const r = avail.find((x) => x.id === i.receipt_id)!; return (
              <tr key={i.receipt_id} className="[&>td]:border-t [&>td]:border-line [&>td]:px-3 [&>td]:py-2">
                <td><input type="checkbox" aria-label={`Use ${r.batch_code}`} {...form.register(`inputs.${idx}.use`)} /></td>
                <td className="font-mono text-xs">{r.batch_code}</td><td className="tnum text-right">{num1(r.accepted_kg)}</td><td className="tnum text-right">{num1(r.available_kg)}</td>
                <td className="text-right"><Input aria-label={`Input kg for ${r.batch_code}`} className="ml-auto h-8 w-28 text-right" inputMode="decimal" disabled={!i.use} {...form.register(`inputs.${idx}.input_kg`)} /></td>
              </tr>) })}
              {!inputs.length && <tr><td colSpan={5} className="px-3 py-4 text-center text-fg-3">No unprocessed accepted stock for {mat}.</td></tr>}
            </tbody></table>
        </div>
      )}
      {form.formState.errors.inputs?.message && <p role="alert" className="text-[12px] text-bad">{form.formState.errors.inputs.message}</p>}
      {(form.formState.errors.inputs as unknown as { root?: { message?: string } })?.root?.message && <p role="alert" className="text-[12px] text-bad">{(form.formState.errors.inputs as unknown as { root: { message: string } }).root.message}</p>}
      <div className="grid gap-4 sm:grid-cols-4">
        <Field label="Total input" htmlFor="run-in"><Input id="run-in" readOnly value={`${num1(input)} kg`} /></Field>
        <Field label="Recovered output (kg)" htmlFor="run-o" required error={form.formState.errors.output_kg?.message}><Input id="run-o" inputMode="decimal" {...form.register('output_kg')} /></Field>
        <Field label="Residue (kg)" htmlFor="run-r" required error={form.formState.errors.residue_kg?.message}><Input id="run-r" inputMode="decimal" {...form.register('residue_kg')} /></Field>
        <Field label="Declared EPR-eligible (kg)" htmlFor="run-el" required error={form.formState.errors.eligible_kg?.message} hint="Your declaration; ≤ output"><Input id="run-el" inputMode="decimal" {...form.register('eligible_kg')} /></Field>
        <Field label="Output form" htmlFor="run-f"><Input id="run-f" {...form.register('output_form')} /></Field>
        <Field label="Eligibility basis" htmlFor="run-b" className="sm:col-span-3"><Input id="run-b" placeholder="e.g. Recycler declaration; CPCB certificate pending" {...form.register('eligibility_basis')} /></Field>
      </div>
      {input > 0 && out >= 0 && form.watch('output_kg') !== '' && form.watch('residue_kg') !== '' && (
        un < -0.001 ? <Note tone="bad">Output + residue exceeds input.</Note>
          : <Note tone={un / input > 0.03 ? 'warn' : 'ok'}>Yield {pct((out / input) * 100)} · unaccounted {kg(un)} ({pct((un / input) * 100)} of input){un / input > 0.03 ? '. Above the 3% guideline: the NGO reviewer will see this. The backend does not raise a flag automatically.' : '.'}</Note>
      )}
      <Note>The backend requires measured output; there is no “incomplete measurement” mode. Record the run once output and residue are weighed.</Note>
      {m.error && <Note tone="bad" title={m.error.code === 'INPUT_EXCEEDS_AVAILABLE' ? 'Input exceeds available stock' : m.error.code === 'MATERIAL_MISMATCH' ? 'Material mismatch' : 'Run not saved'}>{m.error.message}</Note>}
    </DialogContent>
  )
}
function CertificateDialog({ run, onClose }: { run: ProcessingRecord; onClose: () => void }) {
  const form = useForm<{ ref: string; cat: string; kg: string; on: string }>({ resolver: zodResolver(z.object({ ref: z.string().trim().min(3, 'Enter the reference'), cat: z.string(), kg: kgField('Quantity').refine((v) => Number(v) <= run.output_kg + 0.001, `Cannot exceed run output ${num1(run.output_kg)} kg`), on: z.string() })), defaultValues: { ref: '', cat: 'CAT_I', kg: String(run.eligible_kg), on: new Date().toISOString().slice(0, 10) } })
  const m = useApiMutation((v: { ref: string; cat: string; kg: string; on: string }) => recApi.addCertificate(run.id, { certificate_ref: v.ref.trim(), packaging_category: v.cat, certificate_kg: Number(v.kg), issued_on: v.on }), { invalidate: [K.batches, K.eprCerts], toastErrors: false, success: 'Certificate reference recorded', onSuccess: onClose })
  return (
    <DialogContent title={`Record certificate reference · ${run.record_code}`} description="Enter a certificate generated on the CPCB EPR portal. ReLoop records the reference; it does not issue or validate certificates."
      footer={<><Button variant="outline" onClick={onClose}>Cancel</Button><Button loading={m.isPending} onClick={form.handleSubmit((v) => m.mutate(v))}>Record reference</Button></>}>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Certificate reference" htmlFor="c-ref" required error={form.formState.errors.ref?.message}><Input id="c-ref" className="font-mono" {...form.register('ref')} /></Field>
        <Field label="Packaging category" htmlFor="c-cat"><Select id="c-cat" {...form.register('cat')}>{Object.entries(CATEGORY_LABEL).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</Select></Field>
        <Field label="Quantity (kg)" htmlFor="c-kg" required error={form.formState.errors.kg?.message}><Input id="c-kg" inputMode="decimal" {...form.register('kg')} /></Field>
        <Field label="Issued on" htmlFor="c-on"><Input id="c-on" type="date" {...form.register('on')} /></Field>
      </div>
      {m.error && <Note tone="bad" title={m.error.code === 'DUPLICATE_CERTIFICATE_REF' ? 'Reference already recorded' : 'Not recorded'}>{m.error.message}</Note>}
    </DialogContent>
  )
}
export function RecyclerRuns() {
  const runs = useProcessing()
  const receipts = useReceipts()
  const [creating, setCreating] = React.useState(false)
  const [open, setOpen] = React.useState<ProcessingRecord | null>(null)
  const [cert, setCert] = React.useState<ProcessingRecord | null>(null)
  const stock = (receipts.data ?? []).reduce((s, r) => s + (r.available_kg ?? 0), 0)
  return (
    <>
      <PageHeader title="Processing runs" description="Measured input, recovered output and residue for each run. Yield and unaccounted mass are calculated by the server."
        actions={<Button onClick={() => setCreating(true)} disabled={receipts.isPending}><Plus />Record processing run</Button>} />
      <div className="flex flex-col gap-4">
        {!receipts.isPending && stock <= 0 && <Note>No accepted stock is waiting for processing. Receive a consignment first.</Note>}
        <Panel flush footer={<><SourceLine source="ReLoop API · /recycler/processing-records" /><span>Yield = output ÷ input. Unaccounted = input − output − residue; above 3% is highlighted.</span></>}>
          <QueryState query={runs}>{(R) => <RunsTable rows={R} onOpen={setOpen} />}</QueryState>
        </Panel>
      </div>
      <Dialog open={creating} onOpenChange={setCreating}>{creating && <RunDialog onClose={() => setCreating(false)} />}</Dialog>
      <Dialog open={!!cert} onOpenChange={(o) => !o && setCert(null)}>{cert && <CertificateDialog run={cert} onClose={() => setCert(null)} />}</Dialog>
      <Drawer open={!!open} onOpenChange={(o) => !o && setOpen(null)} title={open ? `Run ${open.record_code}` : ''} sub={open ? `${open.material_code} · ${dateTime(open.run_started_at)}` : undefined}>
        {open && (
          <div className="flex flex-col gap-4">
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
              <Kpi label="Input" value={kg(open.input_kg)} /><Kpi label="Recovered output" value={kg(open.output_kg)} /><Kpi label="Residue" value={kg(open.residue_kg)} />
              <Kpi label="Unaccounted" value={kg(open.input_kg - open.output_kg - open.residue_kg)} sub={pct(((open.input_kg - open.output_kg - open.residue_kg) / open.input_kg) * 100)} />
            </div>
            <Panel title="EPR attribution"><KV rows={[['Recovered output', kg(open.output_kg)], ['Declared EPR-eligible', kg(open.eligible_kg)], ['Allocated to clients', kg(open.allocated_kg)], ['Free to allocate', kg(open.available_kg), true], ['Measurement', humanize(open.measurement_status)]]} /></Panel>
            <Note>Source batches and their share of this run are listed on each batch’s passport. The backend does not expose a per-run input list to this screen.</Note>
            <div className="flex flex-wrap gap-2"><Button variant="outline" onClick={() => setCert(open)}>Record certificate reference</Button><Button asChild><Link to="/r/allocations">Allocate to EPR client</Link></Button></div>
          </div>
        )}
      </Drawer>
    </>
  )
}

/* ─────────────── Yield ─────────────── */
export function RecyclerYield() {
  const y = useYield()
  return (
    <>
      <PageHeader title="Material yield" description="Measured yield, residue and unaccounted mass by run." />
      <QueryState query={y} isEmpty={(d) => d.completed_runs_count === 0} empty={{ title: 'No measured runs yet' }}>{(d) => {
        const rows = d.completed_runs.map((r) => ({ ...r, unaccounted: r.input_kg - r.output_kg - r.residue_kg }))
        const mats = [...new Set(rows.map((r) => r.material))]
        return (
          <div className="flex flex-col gap-4">
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
              <Kpi label="Average run yield" value={pct(d.average_yield_pct)} sub={`${d.completed_runs_count} measured runs (unweighted)`} />
              {mats.slice(0, 2).map((m) => { const X = rows.filter((r) => r.material === m); const i = X.reduce((s, r) => s + r.input_kg, 0); return <Kpi key={m} label={`${m} yield (weighted)`} value={pct(i ? (X.reduce((s, r) => s + r.output_kg, 0) / i) * 100 : null)} sub={`${kg(i)} input`} /> })}
              <Kpi label="Runs above 3% unaccounted" value={rows.filter((r) => r.unaccounted / r.input_kg > 0.03).length} />
            </div>
            <Panel title="Mass balance by run" sub="kg · full bar = measured input" footer={<SourceLine source="ReLoop API · /yield" />}>
              <div className="h-64"><ResponsiveContainer><BarChart data={rows}><CartesianGrid vertical={false} stroke="var(--line)" /><XAxis dataKey="record_code" {...axis} /><YAxis {...axis} width={52} /><Tooltip {...tt} formatter={(v: number) => kg(v)} /><Legend wrapperStyle={{ fontSize: 12 }} />
                <Bar dataKey="output_kg" name="Recovered output" stackId="a" fill="var(--c1)" /><Bar dataKey="residue_kg" name="Residue" stackId="a" fill="var(--c4)" /><Bar dataKey="unaccounted" name="Unaccounted" stackId="a" fill="var(--c5)" /></BarChart></ResponsiveContainer></div>
            </Panel>
            <Panel flush>
              <DataTable label="Yield by run" rows={rows} rowKey={(r) => r.record_code} columns={[
                { key: 'c', header: 'Run', cell: (r) => <span className="font-mono text-xs">{r.record_code}</span> }, { key: 'm', header: 'Material', cell: (r) => r.material },
                { key: 'i', header: 'Input', numeric: true, cell: (r) => num1(r.input_kg) }, { key: 'o', header: 'Output', numeric: true, cell: (r) => num1(r.output_kg) },
                { key: 'r', header: 'Residue', numeric: true, cell: (r) => num1(r.residue_kg) }, { key: 'u', header: 'Unaccounted', numeric: true, cell: (r) => num1(r.unaccounted) },
                { key: 'y', header: 'Yield', numeric: true, cell: (r) => pct(r.yield_pct), sortValue: (r) => r.yield_pct },
                { key: 'mb', header: 'Mass balance', cell: (r) => { const u = (r.unaccounted / r.input_kg) * 100; return u > 3 ? <Badge tone="bad">{pct(u)} above 3%</Badge> : <Badge tone="ok">{pct(u)}</Badge> } },
              ]} />
            </Panel>
          </div>
        )
      }}</QueryState>
    </>
  )
}

/* ─────────────── EPR allocations ─────────────── */
const allocSchema = z.object({ run: z.string().min(1, 'Choose a run'), client: z.string().min(1, 'Choose an EPR client'), category: z.string(), period: z.string().regex(/^FY\d{4}-\d{2}$/, 'Format FY2026-27'), kg: kgField('Quantity') })
function AllocateDialog({ runs, onClose }: { runs: ProcessingRecord[]; onClose: () => void }) {
  const clients = useOrgs('EPR_CLIENT')
  const form = useForm<z.infer<typeof allocSchema>>({ resolver: zodResolver(allocSchema), defaultValues: { run: runs.find((r) => r.available_kg > 0)?.id ?? '', client: '', category: 'CAT_I', period: currentReportingPeriod(), kg: '' } })
  const run = runs.find((r) => r.id === form.watch('run'))
  const m = useApiMutation((v: z.infer<typeof allocSchema>) => eprApi.createAllocation({ processing_record_id: v.run, epr_org_id: v.client, packaging_category: v.category, reporting_period: v.period, quantity_kg: Number(v.kg) }),
    { invalidate: [K.allocations, K.processing, K.batches, ['epr']], toastErrors: false, success: (d) => `${kg(d.quantity_kg)} allocated. ${kg(d.remaining_available_kg)} remains free on this run.`, onSuccess: onClose })
  const det = m.error?.code === 'ALLOCATION_EXCEEDS_AVAILABLE' ? (m.error.details as { eligible_kg: string; allocated_kg: string; available_kg: string }) : null
  return (
    <DialogContent title="Allocate to an EPR client" description="Records a contractual attribution of your declared eligible output. The client files its own returns on the CPCB portal."
      footer={<><Button variant="outline" onClick={onClose}>Cancel</Button><Button loading={m.isPending} onClick={form.handleSubmit((v) => m.mutate(v))}>Allocate</Button></>}>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="From run" htmlFor="a-run" required error={form.formState.errors.run?.message}>
          <Select id="a-run" {...form.register('run')}><option value="">Select run</option>{runs.map((r) => <option key={r.id} value={r.id} disabled={r.available_kg <= 0}>{r.record_code} · {r.material_code} · {kg(r.available_kg)} free</option>)}</Select>
        </Field>
        <Field label="EPR client" htmlFor="a-client" required error={form.formState.errors.client?.message} hint="Approved EPR companies from the ReLoop directory">
          <Select id="a-client" {...form.register('client')} disabled={clients.isPending}><option value="">{clients.isPending ? 'Loading…' : 'Select client'}</option>{clients.data?.map((c) => <option key={c.id} value={c.id}>{c.legal_name}</option>)}</Select>
        </Field>
        <Field label="Packaging category" htmlFor="a-cat"><Select id="a-cat" {...form.register('category')}>{Object.entries(CATEGORY_LABEL).map(([k, l]) => <option key={k} value={k}>{l}</option>)}</Select></Field>
        <Field label="Reporting period" htmlFor="a-per" error={form.formState.errors.period?.message}><Input id="a-per" {...form.register('period')} /></Field>
        <Field label="Quantity (kg)" htmlFor="a-kg" required error={form.formState.errors.kg?.message} hint={run ? `${kg(run.available_kg)} free of ${kg(run.eligible_kg)} declared eligible` : undefined}><Input id="a-kg" inputMode="decimal" {...form.register('kg')} /></Field>
      </div>
      {det && <Note tone="bad" title="Allocation refused: it would double-count output">{m.error!.message}. Declared eligible {det.eligible_kg} kg, already allocated {det.allocated_kg} kg, available {det.available_kg} kg. Nothing was saved. Enter a quantity within the available amount or choose another run.</Note>}
      {m.error && !det && <Note tone="bad">{m.error.message}</Note>}
      <Note>NGO verification status does not change what can be allocated. The client sees which share of its allocation comes from verified batches.</Note>
    </DialogContent>
  )
}
export function RecyclerAllocations() {
  const allocations = useAllocations()
  const runs = useProcessing()
  const clients = useOrgs('EPR_CLIENT')
  const [allocating, setAllocating] = React.useState(false)
  const [reversing, setReversing] = React.useState<Allocation | null>(null)
  const [reason, setReason] = React.useState('')
  const rev = useApiMutation(() => eprApi.reverseAllocation(reversing!.id, reason.trim()), { invalidate: [K.allocations, K.processing, K.batches, ['epr']], success: 'Allocation reversed; a reversal entry was added', onSuccess: () => { setReversing(null); setReason('') } })
  const runCode = (id: string) => runs.data?.find((r) => r.id === id)?.record_code ?? id.slice(0, 8)
  const client = (id: string) => clients.data?.find((c) => c.id === id)?.legal_name ?? id.slice(0, 8)
  const R = runs.data ?? []
  return (
    <>
      <PageHeader title="EPR allocation records" description="Attribute your declared EPR-eligible output to client companies. The server refuses any allocation that would exceed what is available."
        actions={<Button onClick={() => setAllocating(true)} disabled={!R.some((r) => r.available_kg > 0)}><Link2 />Allocate</Button>} />
      <Tabs defaultValue="ledger">
        <TabsList items={[{ value: 'ledger', label: 'Allocation ledger' }, { value: 'runs', label: 'Eligible output by run' }, { value: 'requests', label: 'Client requests' }]} />
        <TabsContent value="ledger" className="flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <Kpi label="Declared eligible" value={kg(R.reduce((s, r) => s + r.eligible_kg, 0))} /><Kpi label="Allocated" value={kg(R.reduce((s, r) => s + r.allocated_kg, 0))} />
            <Kpi label="Free to allocate" value={kg(R.reduce((s, r) => s + r.available_kg, 0))} /><Kpi label="Active entries" value={(allocations.data ?? []).filter((a) => a.status === 'ACTIVE').length} />
          </div>
          <Panel flush footer={<SourceLine source="ReLoop API · /epr/allocations" />}>
            <QueryState query={allocations}>{(A) => (
              <DataTable label="Allocation ledger" rows={A} rowKey={(a) => a.id} initialSort={{ key: 'd', dir: -1 }} search={(a) => `${client(a.epr_org_id)} ${runCode(a.processing_record_id)}`} searchPlaceholder="Search client or run"
                filters={[{ key: 's', label: 'Status', options: [{ value: 'ACTIVE', label: 'Active' }, { value: 'REVERSED', label: 'Reversed' }], get: (a) => a.status }]}
                empty={{ title: 'No allocations yet' }}
                columns={[
                  { key: 'd', header: 'Recorded', cell: (a) => <span className="text-xs">{dateTime(a.created_at)}</span>, sortValue: (a) => a.created_at },
                  { key: 'c', header: 'Client', cell: (a) => client(a.epr_org_id), sortValue: (a) => client(a.epr_org_id) },
                  { key: 'r', header: 'Run', cell: (a) => <span className="font-mono text-xs">{runCode(a.processing_record_id)}</span> },
                  { key: 'cat', header: 'Category', cell: (a) => CATEGORY_LABEL[a.packaging_category] ?? a.packaging_category },
                  { key: 'p', header: 'Period', cell: (a) => a.reporting_period },
                  { key: 'q', header: 'Quantity', numeric: true, cell: (a) => num1(a.quantity_kg), sortValue: (a) => a.quantity_kg },
                  { key: 's', header: 'Status', cell: (a) => (a.reverses_allocation_id ? <Badge tone="warn">Reversal entry</Badge> : a.status === 'ACTIVE' ? <Badge tone="ok">Active</Badge> : <Badge>Reversed</Badge>), sortValue: (a) => a.status },
                  { key: 'why', header: 'Reason', cell: (a) => <span className="text-xs">{a.reason ?? ''}</span> },
                  { key: 'x', header: '', cell: (a) => (a.status === 'ACTIVE' ? <Button size="sm" variant="ghost" onClick={() => setReversing(a)}>Reverse</Button> : null) },
                ]} />
            )}</QueryState>
          </Panel>
        </TabsContent>
        <TabsContent value="runs">
          <Panel flush><QueryState query={runs}>{(rows) => <RunsTable rows={rows} onOpen={() => {}} />}</QueryState></Panel>
        </TabsContent>
        <TabsContent value="requests">
          <Panel><EmptyState title="Allocation requests are not available" body="The backend accepts EPR clients’ allocation requests but does not store them (audit §5.6), so there is nothing to list. Agree quantities with clients directly, then allocate here." /></Panel>
        </TabsContent>
      </Tabs>
      <Dialog open={allocating} onOpenChange={setAllocating}>{allocating && <AllocateDialog runs={R} onClose={() => setAllocating(false)} />}</Dialog>
      <Dialog open={!!reversing} onOpenChange={(o) => !o && setReversing(null)}>
        {reversing && <DialogContent title="Reverse allocation?" description={`${kg(reversing.quantity_kg)} to ${client(reversing.epr_org_id)} from ${runCode(reversing.processing_record_id)}`}
          footer={<><Button variant="outline" onClick={() => setReversing(null)}>Cancel</Button><Button variant="destructive" disabled={reason.trim().length < 5} loading={rev.isPending} onClick={() => rev.mutate(undefined)}>Reverse allocation</Button></>}>
          <Note tone="warn">The original entry stays in the ledger as reversed and a reversal entry is added. The quantity becomes free again.</Note>
          <Field label="Reason" htmlFor="rev-r" required hint="At least 5 characters"><Textarea id="rev-r" rows={2} value={reason} onChange={(e) => setReason(e.target.value)} placeholder="Client contract amended" /></Field>
          {rev.error && <Note tone="bad">{rev.error.message}</Note>}
        </DialogContent>}
      </Dialog>
    </>
  )
}
