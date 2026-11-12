import * as React from 'react'
import { Link, useNavigate, useParams } from 'react-router-dom'
import { useQueries } from '@tanstack/react-query'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { AlertTriangle, CheckCircle2, Circle, Download, Eye, FileText, ShieldCheck, XCircle } from 'lucide-react'
import { K, useAnomalies, useAudit, useBatch, useBatches, useEvents, useNgoImpact, useNgoReports, useOrgs, usePassport, useTrace, useVerification, useVerifications, useYield } from '@/hooks/queries'
import { useApiMutation } from '@/hooks/useApiMutation'
import * as ngoApi from '@/services/ngo'
import { batchEvents } from '@/services/batches'
import { resolveAnomaly } from '@/services/shared'
import { PageHeader, SourceLine } from '@/components/page'
import { Panel, Kpi, KV } from '@/components/ui/panel'
import { Button } from '@/components/ui/button'
import { Input, Select, Textarea } from '@/components/ui/input'
import { Field } from '@/components/ui/field'
import { Note } from '@/components/ui/note'
import { Badge } from '@/components/ui/badge'
import { Dialog, DialogContent } from '@/components/ui/dialog'
import { Tabs, TabsContent, TabsList } from '@/components/ui/tabs'
import { DataTable, type Column } from '@/components/ui/data-table'
import { QueryState, EmptyState, LoadingRows } from '@/components/states'
import { BatchStatusBadge, NgoBadge, NGO_OPTIONS } from '@/components/status'
import { BatchLink, PassportView } from '@/features/batches/PassportView'
import { QuantityLadder } from '@/features/batches/QuantityLadder'
import { EventTimeline } from '@/features/batches/Timeline'
import { q, variances } from '@/lib/quantities'
import { dateTime, humanize, kg, num1, pct } from '@/lib/format'
import { downloadCsv } from '@/lib/csv'
import type { Anomaly, Batch, Passport, VerificationDetail, VerificationListItem, YieldAnalytics, DirectoryOrg, BatchTrace, BatchEvent } from '@/types/api'

const DISCLAIMER = 'NGO verification is an independent, non-statutory review of evidence held on ReLoop. It is not EPR certification, does not determine EPR eligibility and is not an approval by CPCB or any State Pollution Control Board.'

function useCaseBatches() {
  const ver = useVerifications()
  const batches = useBatches()
  const byId = React.useMemo(() => new Map((batches.data ?? []).map((b) => [b.id, b])), [batches.data])
  return { ver, batches, byId }
}

/* ─────────────── Dashboard ─────────────── */
export function NgoDashboard() {
  const { ver, byId } = useCaseBatches()
  const impact = useNgoImpact()
  const anomalies = useAnomalies()
  const nav = useNavigate()
  return (
    <>
      <PageHeader title="Verification dashboard" description="Independent review of batch evidence: custody, weights and processing records." />
      <Note tone="warn" className="mb-4" title="Scope boundary">{DISCLAIMER} Operational records are read-only here.</Note>
      <QueryState query={ver}>{(V) => {
        const by = (...d: string[]) => V.filter((v) => d.includes(v.decision))
        const out = (X: VerificationListItem[]) => X.reduce((s, v) => s + (q(byId.get(v.batch_id)?.quantities.processed_kg) ?? 0), 0)
        const chart = NGO_OPTIONS.map((o) => ({ ...o, n: by(o.value).length, kg: out(by(o.value)) }))
        const max = Math.max(1, ...chart.map((c) => c.kg))
        return (
          <div className="flex flex-col gap-4">
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
              <Kpi icon={<Eye />} label="Awaiting review" value={by('PENDING', 'UNDER_REVIEW').length} sub={`${kg(out(by('PENDING', 'UNDER_REVIEW')))} recovered output`} />
              <Kpi icon={<ShieldCheck />} label="Verified" value={by('VERIFIED').length} sub={kg(out(by('VERIFIED')))} />
              <Kpi icon={<AlertTriangle />} label="Flagged / rejected / correction" value={by('FLAGGED', 'REJECTED', 'REQUIRES_CORRECTION').length} sub={kg(out(by('FLAGGED', 'REJECTED', 'REQUIRES_CORRECTION')))} />
              <Kpi label="Open anomaly flags" value={anomalies.isPending ? '…' : (anomalies.data ?? []).filter((a) => a.status === 'OPEN').length} />
            </div>
            <div className="grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
              <Panel title="Decisions by recovered output" sub="Pro rata recovered output of each case batch" footer={<SourceLine source="ReLoop API · /ngo/verifications, /batches" />}>
                <div className="flex flex-col gap-2">
                  {chart.map((c) => (
                    <div key={c.value} className="grid grid-cols-[150px_minmax(0,1fr)_110px] items-center gap-3 text-[12.5px] max-sm:grid-cols-[110px_minmax(0,1fr)_90px]">
                      <span className="truncate text-fg-2">{c.label}</span>
                      <span className="h-2.5 overflow-hidden rounded bg-surface-2"><span className="block h-full" style={{ width: `${(c.kg / max) * 100}%`, background: c.value === 'VERIFIED' ? 'var(--c1)' : ['FLAGGED', 'REJECTED'].includes(c.value) ? 'var(--c5)' : 'var(--c4)' }} /></span>
                      <span className="tnum text-right">{c.n} · {num1(c.kg)} kg</span>
                    </div>
                  ))}
                </div>
              </Panel>
              <Panel title="Platform impact (backend estimate)" footer={<SourceLine source="ReLoop API · /ngo/impact" />}>
                <QueryState query={impact}>{(i) => <KV rows={[['Verified batches', i.verified_batch_count], ['Accepted kg of verified batches', kg(i.total_verified_kg)], ['CO₂ estimate', kg(i.co2_saved_kg_est)]]} />}</QueryState>
                <p className="mt-2 text-[11.5px] text-fg-3">The backend counts accepted kg (not recovered output) and applies a fixed CO₂ multiplier. Shown for reference only.</p>
              </Panel>
            </div>
            <Panel title="Review queue" flush actions={<Button size="sm" variant="outline" asChild><Link to="/n/cases">All cases</Link></Button>}>
              <CasesTable rows={by('PENDING', 'UNDER_REVIEW', 'REQUIRES_CORRECTION')} byId={byId} onOpen={(v) => nav(`/n/cases/${v.id}`)} />
            </Panel>
          </div>
        )
      }}</QueryState>
    </>
  )
}

function CasesTable({ rows, byId, onOpen, filters }: { rows: VerificationListItem[]; byId: Map<string, Batch>; onOpen: (v: VerificationListItem) => void; filters?: boolean }) {
  const cols: Column<VerificationListItem>[] = [
    { key: 'c', header: 'Batch', cell: (v) => <BatchLink code={v.batch_code} />, sortValue: (v) => v.batch_code },
    { key: 'm', header: 'Material', cell: (v) => byId.get(v.batch_id)?.material ?? '—' },
    { key: 'r', header: 'Recycler', cell: (v) => byId.get(v.batch_id)?.destination_recycler_name ?? '—' },
    { key: 'col', header: 'Collected', numeric: true, cell: (v) => num1(q(byId.get(v.batch_id)?.quantities.collected_kg)) },
    { key: 'a', header: 'Accepted', numeric: true, cell: (v) => num1(q(byId.get(v.batch_id)?.quantities.accepted_kg)) },
    { key: 'o', header: 'Recovered', numeric: true, cell: (v) => num1(q(byId.get(v.batch_id)?.quantities.processed_kg)), sortValue: (v) => q(byId.get(v.batch_id)?.quantities.processed_kg) },
    { key: 'd', header: 'Decision', cell: (v) => <NgoBadge decision={v.decision} />, sortValue: (v) => v.decision },
    { key: 't', header: 'Since', cell: (v) => <span className="text-xs">{dateTime(v.created_at)}</span>, sortValue: (v) => v.created_at },
  ]
  return (
    <DataTable label="Verification cases" rows={rows} rowKey={(v) => v.id} onRowClick={onOpen} columns={cols} initialSort={{ key: 't', dir: -1 }}
      search={filters ? (v) => v.batch_code : undefined} searchPlaceholder="Search batch code"
      filters={filters ? [{ key: 'd', label: 'Decision', options: NGO_OPTIONS, get: (v) => v.decision }] : []}
      empty={{ title: 'No cases', body: 'Batches enter review when a recycler records their processing run.' }} />
  )
}

export function NgoCases() {
  const { ver, byId } = useCaseBatches()
  const nav = useNavigate()
  return (
    <>
      <PageHeader title="Cases" description="Every batch in independent review, with its current decision." />
      <Note className="mb-4">The backend lists cases from all NGOs and assigns new ones to the first approved NGO organisation (audit §3, D6). All cases are shown here.</Note>
      <Panel flush footer={<SourceLine source="ReLoop API · /ngo/verifications" />}><QueryState query={ver}>{(V) => <CasesTable rows={V} byId={byId} onOpen={(v) => nav(`/n/cases/${v.id}`)} filters />}</QueryState></Panel>
    </>
  )
}

/* ─────────────── Evidence checklist (computed from API data only) ─────────────── */
type CheckState = 'ok' | 'warn' | 'bad' | 'na'
interface Check { n: number; label: string; state: CheckState; detail: string }
export function buildChecklist(d: VerificationDetail, p: Passport | undefined, trace: BatchTrace | undefined, y: YieldAnalytics | undefined, recyclers: DirectoryOrg[] | undefined, batch: Batch | undefined, events: BatchEvent[] | undefined): Check[] {
  const C: Check[] = []
  const add = (n: number, label: string, state: CheckState, detail: string) => C.push({ n, label, state, detail })
  const docs = d.documents
  const listingPhotos = docs.filter((x) => x.doc_type === 'PHOTO_LISTING')
  add(1, 'Listing photo present', listingPhotos.length ? 'ok' : 'warn', listingPhotos.length ? `${listingPhotos.length} photo record(s) with SHA-256` : 'No listing photo linked to the batch')
  const pk = d.custody.pickup_records.find((x) => x.is_current)
  add(2, 'Pickup weighed and confirmed by generator (OTP/QR)', pk?.confirmed_at ? 'ok' : pk ? 'bad' : 'bad', pk ? (pk.confirmed_at ? `Confirmed ${dateTime(pk.confirmed_at)}` : 'Weight recorded but not confirmed') : 'No pickup record')
  const est = d.batch.estimated_kg
  if (pk) { const dv = ((pk.collected_kg - est) / est) * 100; add(3, 'Collected vs listed within ±20%', Math.abs(dv) <= 20 ? 'ok' : 'warn', `${dv >= 0 ? '+' : ''}${pct(dv)} (${num1(pk.collected_kg)} vs ${num1(est)} kg)`) } else add(3, 'Collected vs listed within ±20%', 'na', 'No pickup')
  const rc = d.custody.recycler_receipts.find((x) => x.is_current)
  if (pk && rc) { const dv = ((rc.received_kg - pk.collected_kg) / pk.collected_kg) * 100; add(4, 'Received vs collected within −10% / +2%', dv <= 2 && dv >= -10 ? 'ok' : 'warn', `${dv >= 0 ? '+' : ''}${pct(dv)}`) } else add(4, 'Received vs collected within −10% / +2%', 'na', 'No receipt')
  add(5, 'Accepted + rejected = received', rc ? (Math.abs(rc.accepted_kg + rc.rejected_kg - rc.received_kg) <= 0.001 ? 'ok' : 'bad') : 'na', rc ? `${num1(rc.accepted_kg)} + ${num1(rc.rejected_kg)} = ${num1(rc.received_kg)}` : 'No receipt')
  add(6, 'Weighbridge slip or inspection record', 'na', 'Not visible here: receipt documents are linked to the receipt, which the review endpoint does not return')
  const runs = trace?.processing_runs ?? []
  add(7, 'Processing record includes this batch', runs.length ? (runs.every((r) => r.measurement_status === 'COMPLETE') ? 'ok' : 'warn') : 'bad', runs.length ? runs.map((r) => `${r.record_code}: ${num1(r.input_kg)} kg in`).join(', ') : 'No processing input recorded')
  const rec = recyclers?.find((r) => r.id === batch?.destination_recycler_org_id)
  const validUntil = rec?.registration?.registration_valid_until
  const runDate = runs[0]?.run_started_at
  add(8, 'Recycler registration valid on processing date', !rec ? 'warn' : !rec.registration?.pwp_registration_no ? 'warn' : validUntil && runDate && new Date(validUntil) < new Date(runDate) ? 'bad' : 'ok',
    rec ? `${rec.registration?.pwp_registration_no ?? 'No PWP number'} · valid until ${validUntil ?? 'not recorded'}` : 'Recycler not found in directory')
  const certs = p?.statutory_certificates ?? []
  add(9, 'Certificate references link to this run', certs.length ? 'ok' : 'na', certs.length ? certs.map((c) => c.certificate_ref).join(', ') : 'No certificate references recorded (optional)')
  const open = d.anomalies.filter((a) => a.status === 'OPEN')
  add(10, 'Open anomaly flags reviewed', open.length ? 'warn' : 'ok', open.length ? `${open.length} open: ${open.map((a) => humanize(a.rule_code)).join(', ')}` : `${d.anomalies.length} flag(s), none open`)
  const yr = runs.map((r) => y?.completed_runs.find((x) => x.record_code === r.record_code)).filter(Boolean) as YieldAnalytics['completed_runs']
  if (yr.length) {
    const worst = Math.max(...yr.map((r) => ((r.input_kg - r.output_kg - r.residue_kg) / r.input_kg) * 100))
    add(11, 'Run mass balance: unaccounted ≤ 3%', worst <= 3 ? 'ok' : 'warn', `Worst run unaccounted ${pct(worst)}`)
  } else add(11, 'Run mass balance: unaccounted ≤ 3%', runs.length ? 'warn' : 'na', runs.length ? 'Run measurements not available' : 'Not processed')
  const consigned = !!p?.custody.consignment
  add(12, 'Weighed individually when consolidated', consigned ? (rc ? 'ok' : 'bad') : 'na', consigned ? `${p!.custody.consignment!.consignment_code} · own receipt ${rc ? 'present' : 'missing'}` : 'Not in a consignment')
  if (events?.length) {
    const order = ['CREATED', 'OFFER_ACCEPTED', 'PICKED_UP', 'DISPATCHED', 'RECEIVED', 'PROCESSED']
    const idx = events.map((e) => order.indexOf(e.event_type)).filter((i) => i >= 0)
    const ordered = idx.every((v, i) => i === 0 || v >= idx[i - 1])
    add(13, 'Timeline order plausible', ordered ? 'ok' : 'warn', ordered ? 'Events in expected order' : 'Events out of expected order')
  } else add(13, 'Timeline order plausible', 'na', 'No events')
  return C
}
const CHECK_ICON: Record<CheckState, [React.ComponentType<{ className?: string }>, string, string]> = {
  ok: [CheckCircle2, 'text-ok', 'Pass'], warn: [AlertTriangle, 'text-warn', 'Review'], bad: [XCircle, 'text-bad', 'Fail'], na: [Circle, 'text-fg-3', 'N/A'],
}

/* ─────────────── Case review ─────────────── */
const decisionSchema = z.object({ decision: z.string(), comments: z.string().max(2000).optional(), follow_up_required: z.string().max(500).optional() })
export function NgoCaseReview() {
  const { id = '' } = useParams()
  const detail = useVerification(id)
  const batchId = detail.data?.verification.batch_id
  const batch = useBatch(batchId)
  const passport = usePassport(detail.data?.batch.batch_code)
  const trace = useTrace(batchId)
  const events = useEvents(batchId)
  const y = useYield()
  const recyclers = useOrgs('RECYCLER')
  const [deciding, setDeciding] = React.useState<string | null>(null)
  const [docReq, setDocReq] = React.useState(false)
  const claim = useApiMutation(() => ngoApi.claimVerification(id), { invalidate: [K.verifications, K.verification(id)], success: 'Review started' })
  if (detail.isPending) return <LoadingRows rows={8} />
  if (detail.isError) return <QueryState query={detail}>{() => null}</QueryState>
  const d = detail.data
  const checks = buildChecklist(d, passport.data, trace.data, y.data, recyclers.data, batch.data, events.data)
  const count = (s: CheckState) => checks.filter((c) => c.state === s).length
  const decided = !['PENDING', 'UNDER_REVIEW'].includes(d.verification.decision)
  return (
    <>
      <PageHeader title={`Case · ${d.batch.batch_code}`} description={`${batch.data?.material ?? ''} · ${batch.data?.generator_name ?? ''} → ${batch.data?.assigned_collector_name ?? '—'} → ${batch.data?.destination_recycler_name ?? '—'}`}
        actions={<Button variant="outline" asChild><Link to="/n/cases">All cases</Link></Button>} />
      <div className="mb-4 flex flex-wrap items-center gap-2"><NgoBadge decision={d.verification.decision} /><BatchStatusBadge status={d.batch.status} />{d.verification.comments && <span className="text-[13px] text-fg-2">“{d.verification.comments}”</span>}</div>
      <Tabs defaultValue="checks">
        <TabsList items={[{ value: 'checks', label: 'Evidence checklist' }, { value: 'qty', label: 'Quantity reconciliation' }, { value: 'custody', label: 'Chain of custody' }, { value: 'passport', label: 'Material passport' }]} />
        <TabsContent value="checks">
          <div className="grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
            <Panel title="Checklist" sub={`${count('ok')} pass · ${count('warn')} review · ${count('bad')} fail · ${count('na')} not applicable or unavailable`} flush>
              <ul>{checks.map((c) => { const [Icon, cls, label] = CHECK_ICON[c.state]; return (
                <li key={c.n} className="grid grid-cols-[22px_minmax(0,1fr)_auto] items-start gap-3 border-b border-line px-4 py-2.5 last:border-b-0">
                  <Icon className={`mt-0.5 size-4 ${cls}`} />
                  <div className="min-w-0"><p className="text-[13px]">{c.n}. {c.label}</p><p className="text-xs text-fg-3">{c.detail}</p></div>
                  <span className={`text-xs font-medium ${cls}`}>{label}</span>
                </li>) })}</ul>
            </Panel>
            <div className="flex flex-col gap-4">
              <Panel title="Decision">
                <div className="flex flex-col gap-2">
                  {d.verification.decision === 'PENDING' && <Button variant="outline" loading={claim.isPending} onClick={() => claim.mutate(undefined)}><Eye />Start review</Button>}
                  <Button onClick={() => setDeciding('VERIFIED')}><ShieldCheck />Verify</Button>
                  <Button variant="outline" onClick={() => setDeciding('REQUIRES_CORRECTION')}>Request correction</Button>
                  <Button variant="outline" onClick={() => setDeciding('FLAGGED')}>Flag concern</Button>
                  <Button variant="destructive" onClick={() => setDeciding('REJECTED')}>Reject</Button>
                  <Button variant="ghost" onClick={() => setDocReq(true)}><FileText />Request a document</Button>
                </div>
                {decided && <Note className="mt-3">A decision is already recorded. A new decision adds a record; the earlier one stays in the history.</Note>}
              </Panel>
              <Note tone="warn">{DISCLAIMER}</Note>
            </div>
          </div>
        </TabsContent>
        <TabsContent value="qty">
          {batch.data && <div className="flex flex-col gap-4">
            <QuantityLadder quantities={batch.data.quantities} trace={trace.data} decision={d.verification.decision} />
            <Panel title="Variances">{variances(batch.data).map((v) => <div key={v.label} className="flex justify-between border-b border-line py-1.5 text-[13px] last:border-0"><span>{v.label}</span><span className={v.outOfTolerance ? 'font-semibold text-bad' : ''}>{v.kg >= 0 ? '+' : ''}{num1(v.kg)} kg {v.pct != null ? `(${pct(v.pct)})` : ''}</span></div>)}</Panel>
            <Panel title="Receipt versions" flush>
              <DataTable label="Receipt versions" rows={d.custody.recycler_receipts} rowKey={(r) => r.id} columns={[
                { key: 'v', header: 'Version', cell: (r) => <span>v{r.version} {r.is_current ? <Badge tone="ok">Current</Badge> : <Badge>Superseded</Badge>}</span> },
                { key: 'r', header: 'Received', numeric: true, cell: (r) => num1(r.received_kg) }, { key: 'a', header: 'Accepted', numeric: true, cell: (r) => num1(r.accepted_kg) },
                { key: 'x', header: 'Rejected', numeric: true, cell: (r) => num1(r.rejected_kg) }, { key: 'g', header: 'Grade', cell: (r) => `${r.quality_grade} · ${pct(r.contamination_pct)}` },
              ]} />
            </Panel>
          </div>}
        </TabsContent>
        <TabsContent value="custody">
          <Panel title="Custody events"><QueryState query={events}>{(ev) => <EventTimeline events={ev} />}</QueryState></Panel>
        </TabsContent>
        <TabsContent value="passport"><PassportView code={d.batch.batch_code} /></TabsContent>
      </Tabs>
      <Dialog open={!!deciding} onOpenChange={(o) => !o && setDeciding(null)}>{deciding && <DecisionDialog id={id} decision={deciding} checks={checks} onClose={() => setDeciding(null)} />}</Dialog>
      <Dialog open={docReq} onOpenChange={setDocReq}>{docReq && batch.data && <DocRequestDialog id={id} batch={batch.data} onClose={() => setDocReq(false)} />}</Dialog>
    </>
  )
}
function DecisionDialog({ id, decision, checks, onClose }: { id: string; decision: string; checks: Check[]; onClose: () => void }) {
  const issues = checks.filter((c) => c.state === 'bad' || c.state === 'warn')
  const needsComment = decision !== 'VERIFIED' || issues.length > 0
  const form = useForm<z.infer<typeof decisionSchema>>({ resolver: zodResolver(decisionSchema.refine((v) => !needsComment || (v.comments ?? '').trim().length >= 10, { path: ['comments'], message: 'Explain the decision (at least 10 characters)' })), defaultValues: { decision, comments: '', follow_up_required: '' } })
  const m = useApiMutation((v: z.infer<typeof decisionSchema>) => ngoApi.decide(id, { decision, comments: v.comments || undefined, follow_up_required: v.follow_up_required || undefined }),
    { invalidate: [K.verifications, ['ngo'], K.batches, K.anomalies, ['epr']], success: `Decision recorded: ${humanize(decision)}`, onSuccess: onClose, toastErrors: false })
  return (
    <DialogContent title={`${NGO_OPTIONS.find((o) => o.value === decision)?.label ?? decision}`} description="Recorded with your name. Visible to the recycler, collector and affected EPR clients."
      footer={<><Button variant="outline" onClick={onClose}>Cancel</Button><Button variant={decision === 'REJECTED' ? 'destructive' : 'default'} loading={m.isPending} onClick={form.handleSubmit((v) => m.mutate(v))}>Record decision</Button></>}>
      {decision === 'VERIFIED' && issues.length > 0 && <Note tone="warn">{issues.length} checklist item(s) need review or failed. Explain why the evidence is still sufficient.</Note>}
      {decision === 'FLAGGED' && <Note>Flagging opens a high-severity anomaly visible to the recycler and EPR clients.</Note>}
      <Field label="Reviewer comments" htmlFor="dc-c" required={needsComment} error={form.formState.errors.comments?.message}><Textarea id="dc-c" rows={4} {...form.register('comments')} /></Field>
      {decision !== 'VERIFIED' && <Field label="Follow-up required" htmlFor="dc-f"><Input id="dc-f" placeholder="e.g. upload processing log for the run" {...form.register('follow_up_required')} /></Field>}
      {m.error && <Note tone="bad" title={m.error.code === 'NOT_CURRENT' ? 'This case was updated by someone else' : 'Not recorded'}>{m.error.message}</Note>}
    </DialogContent>
  )
}
function DocRequestDialog({ id, batch, onClose }: { id: string; batch: Batch; onClose: () => void }) {
  const parties = [
    batch.assigned_collector_org_id && { id: batch.assigned_collector_org_id, name: `${batch.assigned_collector_name} (collector)` },
    batch.destination_recycler_org_id && { id: batch.destination_recycler_org_id, name: `${batch.destination_recycler_name} (recycler)` },
  ].filter(Boolean) as { id: string; name: string }[]
  const form = useForm<{ to: string; text: string }>({ resolver: zodResolver(z.object({ to: z.string().min(1, 'Choose a party'), text: z.string().trim().min(10, 'Describe the evidence needed') })), defaultValues: { to: parties[0]?.id ?? '', text: '' } })
  const m = useApiMutation((v: { to: string; text: string }) => ngoApi.requestDocument(id, { addressed_to_org_id: v.to, request_text: v.text.trim() }), { invalidate: [K.events(batch.id), ['ngo', 'docreqs']], success: 'Document request recorded', onSuccess: onClose })
  return (
    <DialogContent title="Request a document" description={batch.batch_code}
      footer={<><Button variant="outline" onClick={onClose}>Cancel</Button><Button loading={m.isPending} onClick={form.handleSubmit((v) => m.mutate(v))}>Send request</Button></>}>
      <Field label="Addressed to" htmlFor="dr-to" required error={form.formState.errors.to?.message}><Select id="dr-to" {...form.register('to')}>{parties.map((p) => <option key={p.id} value={p.id}>{p.name}</option>)}</Select></Field>
      <Field label="What is needed" htmlFor="dr-t" required error={form.formState.errors.text?.message}><Textarea id="dr-t" rows={3} {...form.register('text')} /></Field>
      <Note>The backend records the request as a batch event only. It does not notify the party or track responses yet (audit §5.5).</Note>
      {m.error && <Note tone="bad">{m.error.message}</Note>}
    </DialogContent>
  )
}

/* ─────────────── Chain of custody ─────────────── */
export function NgoCustody() {
  const { ver, byId } = useCaseBatches()
  const [sel, setSel] = React.useState<string | null>(null)
  const current = sel ?? ver.data?.[0]?.batch_id ?? null
  const b = current ? byId.get(current) : undefined
  const events = useEvents(current ?? undefined)
  const passport = usePassport(b?.batch_code)
  return (
    <>
      <PageHeader title="Chain of custody" description="Custodian handoffs for each case: generator, collector, consignment, recycler and processing run." />
      <div className="grid gap-4 lg:grid-cols-[minmax(0,1fr)_minmax(0,2fr)]">
        <Panel title="Cases" flush>
          <QueryState query={ver}>{(V) => (
            <ul>{V.map((v) => (
              <li key={v.id}><button onClick={() => setSel(v.batch_id)} className={`flex w-full items-center justify-between gap-2 border-b border-line px-4 py-2.5 text-left hover:bg-surface-2 ${v.batch_id === current ? 'bg-accent-soft' : ''}`}>
                <span className="min-w-0"><span className="font-mono text-xs">{v.batch_code}</span><span className="block truncate text-xs text-fg-3">{byId.get(v.batch_id)?.generator_name}</span></span><NgoBadge decision={v.decision} />
              </button></li>))}</ul>
          )}</QueryState>
        </Panel>
        <div className="flex flex-col gap-4">
          {b ? (
            <>
              <Panel title="Custodians">
                <ol className="flex flex-col gap-2 text-[13px]">
                  {[
                    ['Generator', b.generator_name, `listed ${kg(q(b.quantities.estimated_kg))}`],
                    ['Collector', b.assigned_collector_name, `collected ${kg(q(b.quantities.collected_kg))}`],
                    ['Consignment', passport.data?.custody.consignment?.consignment_code ?? '—', passport.data?.custody.consignment?.vehicle_no ?? ''],
                    ['Recycler', b.destination_recycler_name, `received ${kg(q(b.quantities.received_kg))} · accepted ${kg(q(b.quantities.accepted_kg))}`],
                    ['Processing', passport.data?.custody.processing_runs.map((r) => r.record_code).join(', ') || '—', `recovered ${kg(q(b.quantities.processed_kg))}`],
                  ].map(([k, v, s], i) => (
                    <li key={i} className="flex flex-wrap items-center gap-3 rounded-md border border-line px-3 py-2" style={{ marginLeft: `${i * 14}px` }}>
                      <span className="w-24 text-[10.5px] uppercase tracking-wide text-fg-3">{k}</span><b className="font-medium">{v ?? '—'}</b><span className="text-xs text-fg-3">{s}</span>
                    </li>))}
                </ol>
              </Panel>
              <Panel title="Event log" sub="Append-only"><QueryState query={events}>{(ev) => <EventTimeline events={ev} />}</QueryState></Panel>
            </>
          ) : <Panel><EmptyState title="Select a case" /></Panel>}
        </div>
      </div>
    </>
  )
}

/* ─────────────── Reconciliation ─────────────── */
export function NgoReconciliation() {
  const { ver, byId } = useCaseBatches()
  const nav = useNavigate()
  const rows = (ver.data ?? []).map((v) => ({ v, b: byId.get(v.batch_id) })).filter((x): x is { v: VerificationListItem; b: Batch } => !!x.b)
  const varOf = (b: Batch, i: number) => variances(b)[i]
  return (
    <>
      <PageHeader title="Quantity reconciliation" description="Every stage of every case side by side. Red cells are outside tolerance: ±20% listed vs collected, ±2% collected vs received." />
      <Panel flush footer={<SourceLine source="ReLoop API · /ngo/verifications, /batches" />}>
        <QueryState query={ver}>{() => (
          <DataTable label="Reconciliation" rows={rows} rowKey={(r) => r.v.id} onRowClick={(r) => nav(`/n/cases/${r.v.id}`)}
            columns={[
              { key: 'c', header: 'Batch', cell: (r) => <BatchLink code={r.b.batch_code} /> },
              { key: 'l', header: 'Listed', numeric: true, cell: (r) => num1(q(r.b.quantities.estimated_kg)) },
              { key: 'col', header: 'Collected', numeric: true, cell: (r) => num1(q(r.b.quantities.collected_kg)) },
              { key: 'd1', header: 'Δ listed', numeric: true, cell: (r) => { const x = varOf(r.b, 0); return x ? <span className={x.outOfTolerance ? 'font-semibold text-bad' : ''}>{pct(x.pct)}</span> : '—' } },
              { key: 'rec', header: 'Received', numeric: true, cell: (r) => num1(q(r.b.quantities.received_kg)) },
              { key: 'd2', header: 'Δ transit', numeric: true, cell: (r) => { const x = variances(r.b).find((v) => v.label === 'Received vs collected'); return x ? <span className={x.outOfTolerance ? 'font-semibold text-bad' : ''}>{pct(x.pct)}</span> : '—' } },
              { key: 'a', header: 'Accepted', numeric: true, cell: (r) => num1(q(r.b.quantities.accepted_kg)) },
              { key: 'x', header: 'Rejected', numeric: true, cell: (r) => num1(q(r.b.quantities.rejected_kg)) },
              { key: 'o', header: 'Recovered', numeric: true, cell: (r) => num1(q(r.b.quantities.processed_kg)) },
              { key: 'n', header: 'Decision', cell: (r) => <NgoBadge decision={r.v.decision} /> },
            ]}
            footer={(R) => <tr><td>Total</td>{(['estimated_kg', 'collected_kg'] as const).map((k) => <td key={k} className="tnum text-right">{num1(R.reduce((s, r) => s + (q(r.b.quantities[k]) ?? 0), 0))}</td>)}<td />
              <td className="tnum text-right">{num1(R.reduce((s, r) => s + (q(r.b.quantities.received_kg) ?? 0), 0))}</td><td />
              {(['accepted_kg', 'rejected_kg', 'processed_kg'] as const).map((k) => <td key={k} className="tnum text-right">{num1(R.reduce((s, r) => s + (q(r.b.quantities[k]) ?? 0), 0))}</td>)}<td /></tr>} />
        )}</QueryState>
      </Panel>
    </>
  )
}

/* ─────────────── Document requests (derived from batch events) ─────────────── */
export function NgoDocuments() {
  const { ver } = useCaseBatches()
  const orgs = useOrgs()
  const ids = [...new Set((ver.data ?? []).map((v) => v.batch_id))]
  const results = useQueries({ queries: ids.map((id) => ({ queryKey: K.events(id), queryFn: () => batchEvents(id) })) })
  const loading = ver.isPending || results.some((r) => r.isPending)
  const rows = results.flatMap((r, i) => (r.data ?? []).filter((e) => e.event_type === 'DOCUMENT_REQUESTED').map((e) => ({ e, code: ver.data!.find((v) => v.batch_id === ids[i])!.batch_code, vid: ver.data!.find((v) => v.batch_id === ids[i])!.id })))
  const nav = useNavigate()
  const orgName = (id: unknown) => orgs.data?.find((o) => o.id === id)?.legal_name ?? String(id ?? '—').slice(0, 8)
  return (
    <>
      <PageHeader title="Document requests" description="Evidence requested from collectors and recyclers. Create new requests from a case." />
      <Note className="mb-4">The backend stores document requests as batch events only: there is no response, status or notification yet (audit §5.5). This list is assembled from those events.</Note>
      <Panel flush>
        {loading ? <LoadingRows /> : (
          <DataTable label="Document requests" rows={rows} rowKey={(r) => String(r.e.id)} onRowClick={(r) => nav(`/n/cases/${r.vid}`)} initialSort={{ key: 'd', dir: -1 }}
            empty={{ title: 'No document requests', body: 'Open a case and choose “Request a document”.' }}
            columns={[
              { key: 'd', header: 'Sent', cell: (r) => <span className="text-xs">{dateTime(r.e.created_at)}</span>, sortValue: (r) => r.e.created_at },
              { key: 'c', header: 'Batch', cell: (r) => <BatchLink code={r.code} /> },
              { key: 't', header: 'Addressed to', cell: (r) => orgName(r.e.payload.addressed_to) },
              { key: 'r', header: 'Request', cell: (r) => <span className="text-[12.5px]">{String(r.e.payload.request ?? '')}</span> },
              { key: 's', header: 'Status', cell: () => <Badge tone="neutral">Not tracked by backend</Badge> },
            ]} />
        )}
      </Panel>
    </>
  )
}

/* ─────────────── Discrepancies (shared with admin) ─────────────── */
export function AnomalyTable({ rows, canResolve, batchCode }: { rows: Anomaly[]; canResolve: boolean; batchCode: (id: string | null) => string | undefined }) {
  const [resolving, setResolving] = React.useState<Anomaly | null>(null)
  const form = useForm<{ status: string; note: string }>({ resolver: zodResolver(z.object({ status: z.string(), note: z.string().trim().min(10, 'Explain the resolution (at least 10 characters)') })), defaultValues: { status: 'RESOLVED', note: '' } })
  const m = useApiMutation((v: { status: string; note: string }) => resolveAnomaly(resolving!.id, v), { invalidate: [K.anomalies, K.batches, ['epr']], success: 'Flag updated', onSuccess: () => { setResolving(null); form.reset() } })
  return (
    <>
      <DataTable label="Anomaly flags" rows={rows} rowKey={(a) => a.id} initialSort={{ key: 'd', dir: -1 }}
        filters={[{ key: 's', label: 'Status', options: [{ value: 'OPEN', label: 'Open' }, { value: 'RESOLVED', label: 'Resolved' }, { value: 'ACKNOWLEDGED', label: 'Acknowledged' }, { value: 'DISMISSED', label: 'Dismissed' }], get: (a) => a.status },
          { key: 'v', label: 'Severity', options: [...new Set(rows.map((a) => a.severity))].map((s) => ({ value: s, label: humanize(s) })), get: (a) => a.severity }]}
        empty={{ title: 'No anomaly flags' }}
        columns={[
          { key: 'd', header: 'Raised', cell: (a) => <span className="text-xs">{dateTime(a.created_at)}</span>, sortValue: (a) => a.created_at },
          { key: 'r', header: 'Rule', cell: (a) => humanize(a.rule_code), sortValue: (a) => a.rule_code },
          { key: 'v', header: 'Severity', cell: (a) => <Badge tone={a.severity === 'HIGH' ? 'bad' : a.severity === 'WARN' ? 'warn' : 'info'}>{humanize(a.severity)}</Badge> },
          { key: 'b', header: 'Batch', cell: (a) => (batchCode(a.batch_id) ? <BatchLink code={batchCode(a.batch_id)!} /> : '—') },
          { key: 'x', header: 'Details', cell: (a) => <span className="text-xs text-fg-2">{a.details ? Object.entries(a.details).map(([k, v]) => `${humanize(k)}: ${String(v)}`).join(' · ') : '—'}{a.resolution_note ? <span className="block text-fg-3">Resolution: {a.resolution_note}</span> : null}</span> },
          { key: 's', header: 'Status', cell: (a) => (a.status === 'OPEN' ? <Badge tone="bad">Open</Badge> : <Badge tone="ok">{humanize(a.status)}</Badge>), sortValue: (a) => a.status },
          { key: 'z', header: '', cell: (a) => (canResolve && a.status === 'OPEN' ? <Button size="sm" variant="outline" onClick={() => setResolving(a)}>Resolve</Button> : null) },
        ]} />
      <Dialog open={!!resolving} onOpenChange={(o) => !o && setResolving(null)}>
        {resolving && <DialogContent title={`Update flag · ${humanize(resolving.rule_code)}`} description="The flag stays in the log with your note."
          footer={<><Button variant="outline" onClick={() => setResolving(null)}>Cancel</Button><Button loading={m.isPending} onClick={form.handleSubmit((v) => m.mutate(v))}>Save</Button></>}>
          <Field label="New status" htmlFor="an-s"><Select id="an-s" {...form.register('status')}><option value="RESOLVED">Resolved</option><option value="ACKNOWLEDGED">Acknowledged</option><option value="DISMISSED">Dismissed</option></Select></Field>
          <Field label="Resolution note" htmlFor="an-n" required error={form.formState.errors.note?.message}><Textarea id="an-n" rows={3} {...form.register('note')} /></Field>
          {m.error && <Note tone="bad">{m.error.message}</Note>}
        </DialogContent>}
      </Dialog>
    </>
  )
}
export function NgoDiscrepancies() {
  const anomalies = useAnomalies()
  const batches = useBatches()
  const code = (id: string | null) => batches.data?.find((b) => b.id === id)?.batch_code
  return (
    <>
      <PageHeader title="Discrepancies" description="Anomaly flags raised by rules, reviewers or participants. Resolving requires a note; the flag stays in the log." />
      <Panel flush footer={<SourceLine source="ReLoop API · /anomalies" />}><QueryState query={anomalies}>{(A) => <AnomalyTable rows={A} canResolve batchCode={code} />}</QueryState></Panel>
    </>
  )
}

/* ─────────────── Reports ─────────────── */
export function NgoReports() {
  const reports = useNgoReports()
  const { ver, byId } = useCaseBatches()
  const exportCsv = () => downloadCsv(`reloop-verification-report-${new Date().toISOString().slice(0, 10)}.csv`, [
    ['batch_code', 'material', 'recycler', 'collected_kg', 'accepted_kg', 'recovered_output_kg', 'decision', 'decision_at', 'comments'],
    ...(ver.data ?? []).map((v) => { const b = byId.get(v.batch_id); return [v.batch_code, b?.material, b?.destination_recycler_name, q(b?.quantities.collected_kg), q(b?.quantities.accepted_kg), q(b?.quantities.processed_kg), v.decision, v.created_at, v.comments] }),
  ])
  return (
    <>
      <PageHeader title="Verification reports" description="Decisions and quantities for the reporting period, exported from live records."
        actions={<Button variant="outline" disabled={!ver.data?.length} onClick={exportCsv}><Download />Export CSV</Button>} />
      <div className="flex flex-col gap-4">
        <Panel title="Decisions by type" sub={reports.data ? `Reporting period ${reports.data.reporting_period} (as labelled by the backend)` : undefined} footer={<SourceLine source="ReLoop API · /ngo/reports" />}>
          <QueryState query={reports}>{(r) => (
            <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-6">
              {NGO_OPTIONS.map((o) => <Kpi key={o.value} label={o.label} value={r.counts_by_decision[o.value] ?? 0} />)}
            </div>
          )}</QueryState>
          <p className="mt-2 text-[11.5px] text-fg-3">Counts are for decisions recorded by your organisation. PDF reports are not generated by the backend; use CSV export.</p>
        </Panel>
        <Panel title="Report contents" flush footer={<span>{DISCLAIMER}</span>}>
          <QueryState query={ver}>{(V) => (
            <DataTable label="Report rows" rows={V} rowKey={(v) => v.id} columns={[
              { key: 'c', header: 'Batch', cell: (v) => <BatchLink code={v.batch_code} /> },
              { key: 'a', header: 'Accepted', numeric: true, cell: (v) => num1(q(byId.get(v.batch_id)?.quantities.accepted_kg)) },
              { key: 'o', header: 'Recovered', numeric: true, cell: (v) => num1(q(byId.get(v.batch_id)?.quantities.processed_kg)) },
              { key: 'd', header: 'Decision', cell: (v) => <NgoBadge decision={v.decision} /> },
              { key: 't', header: 'Recorded', cell: (v) => <span className="text-xs">{dateTime(v.created_at)}</span> },
              { key: 'n', header: 'Comments', cell: (v) => <span className="text-xs">{v.comments ?? ''}</span> },
            ]} />
          )}</QueryState>
        </Panel>
      </div>
    </>
  )
}

/* ─────────────── Audit history (shared with admin) ─────────────── */
export function AuditTable() {
  const logs = useAudit()
  return (
    <QueryState query={logs}>{(L) => {
      const sorted = [...L].sort((a, b) => a.id - b.id)
      const broken = new Set(sorted.filter((r, i) => i > 0 && r.prev_hash !== sorted[i - 1].row_hash && sorted[i - 1].id === r.id - 1).map((r) => r.id))
      return (
        <>
          <Note className="m-4" tone={broken.size ? 'bad' : 'ok'}>{broken.size ? `${broken.size} row(s) do not link to the previous row’s hash.` : 'Each consecutive row’s previous-hash matches the prior row’s hash (last 100 rows).'}</Note>
          <DataTable label="Audit log" rows={L} rowKey={(r) => String(r.id)} initialSort={{ key: 'id', dir: -1 }} search={(r) => `${r.action} ${r.entity_type}`} searchPlaceholder="Search action or entity"
            columns={[
              { key: 'id', header: '#', numeric: true, cell: (r) => r.id, sortValue: (r) => r.id },
              { key: 'd', header: 'Time', cell: (r) => <span className="text-xs">{dateTime(r.created_at)}</span> },
              { key: 'a', header: 'Action', cell: (r) => humanize(r.action) },
              { key: 'e', header: 'Entity', cell: (r) => <span className="text-xs">{humanize(r.entity_type)}</span> },
              { key: 'af', header: 'Change', cell: (r) => <span className="font-mono text-[11px] text-fg-2">{r.after ? JSON.stringify(r.after).slice(0, 90) : '—'}</span> },
              { key: 'h', header: 'Row hash', cell: (r) => <span className={`font-mono text-[11px] ${broken.has(r.id) ? 'text-bad' : 'text-fg-3'}`}>{r.row_hash?.slice(0, 16)}…</span> },
            ]} />
        </>
      )
    }}</QueryState>
  )
}
export function NgoAudit() {
  return (
    <>
      <PageHeader title="Audit history" description="Tamper-evident audit log written by the backend for batch creation and EPR allocation events." />
      <Panel flush footer={<SourceLine source="ReLoop API · /audit/logs (last 100 rows)" />}><AuditTable /></Panel>
    </>
  )
}
