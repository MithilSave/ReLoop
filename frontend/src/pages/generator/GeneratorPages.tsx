import * as React from 'react'
import { Link, useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Bar, BarChart, CartesianGrid, Legend, ResponsiveContainer, Tooltip, XAxis, YAxis } from 'recharts'
import { Camera, Hand, Plus, Recycle, ShieldCheck, Wallet, Package, Upload } from 'lucide-react'
import { useBatches, useMaterials, useMyOrg, useOffers, usePayments } from '@/hooks/queries'
import { K } from '@/hooks/queries'
import { useApiMutation } from '@/hooks/useApiMutation'
import * as batchesApi from '@/services/batches'
import { registerDocument } from '@/services/documents'
import { PageHeader, SourceLine } from '@/components/page'
import { Panel, Kpi, KV } from '@/components/ui/panel'
import { Button } from '@/components/ui/button'
import { Input, Select, Textarea } from '@/components/ui/input'
import { Field } from '@/components/ui/field'
import { Note } from '@/components/ui/note'
import { Badge } from '@/components/ui/badge'
import { Dialog, DialogContent } from '@/components/ui/dialog'
import { DataTable, type Column } from '@/components/ui/data-table'
import { QueryState, EmptyState } from '@/components/states'
import { BatchStatusBadge, NgoBadge, BATCH_STATUS_OPTIONS } from '@/components/status'
import { BatchLink } from '@/features/batches/PassportView'
import { awaitingConfirmation } from '@/features/batches/status-helpers'
import { q, sumQ, verifiedKg } from '@/lib/quantities'
import { date, dateTime, inr, kg, num1, pct } from '@/lib/format'
import { kgField, localToIso, toLocalInput } from '@/lib/forms'
import type { Batch, CollectionOffer, Payment } from '@/types/api'
import { ApiError } from '@/api/errors'

const SOURCE = 'ReLoop API · /batches'

const batchColumns: Column<Batch>[] = [
  { key: 'code', header: 'Batch', cell: (b) => <BatchLink code={b.batch_code} />, sortValue: (b) => b.batch_code },
  { key: 'mat', header: 'Material', cell: (b) => b.material, sortValue: (b) => b.material },
  { key: 'listed', header: 'Listed', cell: (b) => <span className="text-xs">{date(b.created_at)}</span>, sortValue: (b) => b.created_at },
  { key: 'est', header: 'Listed kg', numeric: true, cell: (b) => num1(q(b.quantities.estimated_kg)), sortValue: (b) => q(b.quantities.estimated_kg) },
  { key: 'col', header: 'Collected kg', numeric: true, cell: (b) => num1(q(b.quantities.collected_kg)), sortValue: (b) => q(b.quantities.collected_kg) },
  { key: 'acc', header: 'Accepted kg', numeric: true, cell: (b) => num1(q(b.quantities.accepted_kg)), sortValue: (b) => q(b.quantities.accepted_kg) },
  { key: 'out', header: 'Recovered kg', numeric: true, cell: (b) => num1(q(b.quantities.processed_kg)), sortValue: (b) => q(b.quantities.processed_kg) },
  { key: 'st', header: 'Status', cell: (b) => (awaitingConfirmation(b) ? <Badge tone="warn">Confirm handover</Badge> : <BatchStatusBadge status={b.status} />), sortValue: (b) => b.status },
  { key: 'ngo', header: 'NGO review', cell: (b) => <NgoBadge decision={b.verification?.decision} />, sortValue: (b) => b.verification?.decision ?? '' },
]

/* ─────────────── Overview ─────────────── */
export function GeneratorOverview() {
  const batches = useBatches()
  const payments = usePayments()
  const nav = useNavigate()
  return (
    <>
      <PageHeader title="Overview" description="Your plastic listings, handovers and what happened to every kilogram after it left your premises."
        actions={<Button asChild><Link to="/g/listings/new"><Plus />Create listing</Link></Button>} />
      <QueryState query={batches}>{(B) => {
        const confirm = B.filter(awaitingConfirmation)
        const open = B.filter((b) => b.status === 'LISTED')
        const paid = (payments.data ?? []).filter((p) => p.status === 'PAID').reduce((s, p) => s + p.amount, 0)
        const pending = (payments.data ?? []).filter((p) => p.status === 'PENDING').reduce((s, p) => s + p.amount, 0)
        const verified = B.reduce((s, b) => s + (verifiedKg(b.quantities, b.verification?.decision) ?? 0), 0)
        const chart = [
          { stage: 'Listed', kg: sumQ(B.filter((b) => b.status !== 'CANCELLED'), 'estimated_kg') }, { stage: 'Collected', kg: sumQ(B, 'collected_kg') },
          { stage: 'Received', kg: sumQ(B, 'received_kg') }, { stage: 'Accepted', kg: sumQ(B, 'accepted_kg') }, { stage: 'Recovered', kg: sumQ(B, 'processed_kg') },
        ]
        return (
          <div className="flex flex-col gap-4">
            {confirm.map((b) => (
              <Note key={b.id} tone="warn" title={`Confirm handover for ${b.batch_code}`}>
                {b.assigned_collector_name} recorded {kg(q(b.quantities.collected_kg))}. Enter the code the collector gives you to confirm. <Link className="font-medium text-accent underline" to="/g/handover">Open handover</Link>
              </Note>
            ))}
            {open.length > 0 && <Note>You have {open.length} open listing{open.length > 1 ? 's' : ''}. <Link className="font-medium text-accent underline" to="/g/offers">Review collector offers</Link></Note>}
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
              <Kpi icon={<Wallet />} label="Paid to you" value={payments.isPending ? '…' : inr(paid, false)} sub={pending ? `${inr(pending, false)} pending` : 'Nothing pending'} />
              <Kpi icon={<Hand />} label="Collected" value={kg(sumQ(B, 'collected_kg'))} sub={`of ${kg(sumQ(B.filter((b) => b.status !== 'CANCELLED'), 'estimated_kg'))} listed`} />
              <Kpi icon={<Recycle />} label="Recovered output" value={kg(sumQ(B, 'processed_kg'))} sub="Measured by recycler, pro rata" />
              <Kpi icon={<ShieldCheck />} label="NGO-verified" value={kg(verified)} sub="Independent review, non-statutory" />
            </div>
            <Panel title="Where your plastic went" sub="All your batches · each stage weighed separately" footer={<SourceLine source={SOURCE} />}>
              <div className="h-56"><ResponsiveContainer><BarChart data={chart} margin={{ left: 8, right: 8 }}>
                <CartesianGrid vertical={false} stroke="var(--line)" /><XAxis dataKey="stage" tick={{ fill: 'var(--fg-3)', fontSize: 11 }} axisLine={false} tickLine={false} />
                <YAxis tick={{ fill: 'var(--fg-3)', fontSize: 11 }} axisLine={false} tickLine={false} width={48} /><Tooltip formatter={(v: number) => kg(v)} contentStyle={{ background: 'var(--surface)', border: '1px solid var(--line)', fontSize: 12 }} />
                <Bar dataKey="kg" name="Quantity (kg)" fill="var(--c2)" radius={[3, 3, 0, 0]} /></BarChart></ResponsiveContainer></div>
              <Note className="mt-3">{kg(sumQ(B, 'rejected_kg'))} was rejected at the recycler gate and remains on record. Listed kg that has not been collected is not counted as recycled.</Note>
            </Panel>
            <Panel title="Recent batches" flush actions={<Button size="sm" variant="outline" asChild><Link to="/g/batches">View all</Link></Button>}>
              <DataTable label="Recent batches" rows={B.slice(0, 6)} columns={batchColumns.slice(0, 8)} rowKey={(b) => b.id} onRowClick={(b) => nav(`/passport/${b.batch_code}`)}
                empty={{ title: 'No batches yet', body: 'Create your first listing to get collector offers.', action: <Button size="sm" asChild><Link to="/g/listings/new">Create listing</Link></Button> }} />
            </Panel>
          </div>
        )
      }}</QueryState>
    </>
  )
}

/* ─────────────── Listings ─────────────── */
export function GeneratorListings() {
  const batches = useBatches()
  const nav = useNavigate()
  const [cancel, setCancel] = React.useState<Batch | null>(null)
  const cancelM = useApiMutation((id: string) => batchesApi.cancelBatch(id), { invalidate: [K.batches], success: 'Listing withdrawn', onSuccess: () => setCancel(null) })
  const cols: Column<Batch>[] = [
    batchColumns[0], batchColumns[1],
    { key: 'win', header: 'Pickup window', cell: (b) => <span className="text-xs">{dateTime(b.available_from)} – {dateTime(b.available_to)}</span>, sortValue: (b) => b.available_from },
    batchColumns[3], { key: 'loc', header: 'Locality', cell: (b) => b.locality ?? '—', sortValue: (b) => b.locality ?? '' },
    batchColumns[7],
    { key: 'x', header: '', cell: (b) => (['LISTED', 'ASSIGNED'].includes(b.status) && !awaitingConfirmation(b)
      ? <Button size="sm" variant="ghost" onClick={(e) => { e.stopPropagation(); setCancel(b) }}>Withdraw</Button> : null) },
  ]
  return (
    <>
      <PageHeader title="Waste listings" description="Plastic you have declared for collection. A listing can be withdrawn while it is open or assigned and not yet weighed."
        actions={<Button asChild><Link to="/g/listings/new"><Plus />Create listing</Link></Button>} />
      <Panel flush footer={<SourceLine source={SOURCE} />}>
        <QueryState query={batches}>{(B) => (
          <DataTable label="Waste listings" rows={B} columns={cols} rowKey={(b) => b.id} onRowClick={(b) => nav(`/passport/${b.batch_code}`)}
            search={(b) => `${b.batch_code} ${b.locality ?? ''}`} searchPlaceholder="Search batch code or locality"
            filters={[{ key: 'st', label: 'Status', options: BATCH_STATUS_OPTIONS, get: (b) => b.status }, { key: 'm', label: 'Material', options: [...new Set(B.map((b) => b.material))].map((m) => ({ value: m, label: m })), get: (b) => b.material }]}
            initialSort={{ key: 'listed', dir: -1 }} empty={{ title: 'No listings yet', action: <Button size="sm" asChild><Link to="/g/listings/new">Create listing</Link></Button> }} />
        )}</QueryState>
      </Panel>
      <Dialog open={!!cancel} onOpenChange={(o) => !o && setCancel(null)}>
        {cancel && <DialogContent title="Withdraw listing?" description={`${cancel.batch_code} · ${kg(q(cancel.quantities.estimated_kg))} ${cancel.material}`}
          footer={<><Button variant="outline" onClick={() => setCancel(null)}>Keep listing</Button><Button variant="destructive" loading={cancelM.isPending} onClick={() => cancelM.mutate(cancel.id)}>Withdraw listing</Button></>}>
          <Note tone="warn">The batch is marked cancelled. This cannot be undone; you can list the material again.</Note>
          {cancelM.error && <Note tone="bad">{cancelM.error.message}</Note>}
        </DialogContent>}
      </Dialog>
    </>
  )
}

/* ─────────────── Create listing ─────────────── */
const listingSchema = z.object({
  material_code: z.string().min(1, 'Choose a material'),
  estimated_kg: kgField('Estimated weight').refine((v) => Number(v) <= 50000, 'Listings above 50,000 kg need a bulk contract'),
  pickup_address: z.string().trim().min(5, 'Enter the pickup address'),
  locality: z.string().trim().max(128).optional(),
  available_from: z.string().min(1, 'Choose a start time'),
  available_to: z.string().min(1, 'Choose an end time'),
  notes: z.string().max(500).optional(),
}).refine((v) => new Date(v.available_to) > new Date(v.available_from), { path: ['available_to'], message: 'End must be after start' })
type ListingForm = z.infer<typeof listingSchema>

export function CreateListing() {
  const materials = useMaterials()
  const org = useMyOrg()
  const nav = useNavigate()
  const [photos, setPhotos] = React.useState<{ name: string; id: string; sha: string }[]>([])
  const [uploading, setUploading] = React.useState(false)
  const now = new Date(); const later = new Date(now.getTime() + 2 * 86400_000)
  const form = useForm<ListingForm>({ resolver: zodResolver(listingSchema), defaultValues: { material_code: '', estimated_kg: '', pickup_address: '', locality: '', available_from: toLocalInput(now), available_to: toLocalInput(later) } })
  React.useEffect(() => { if (org.data && !form.getValues('pickup_address')) form.setValue('pickup_address', org.data.address) }, [org.data, form])
  const create = useApiMutation(batchesApi.createBatch, {
    invalidate: [K.batches], success: (d) => `Listing ${d.batch_code} published`, onSuccess: (d) => nav(`/passport/${d.batch_code}`),
  })
  const onFiles = async (files: FileList | null) => {
    if (!files?.length) return
    setUploading(true)
    try {
      for (const f of Array.from(files)) {
        const r = await registerDocument(f, 'PHOTO_LISTING')
        setPhotos((p) => [...p, { name: f.name, id: r.document_id, sha: r.sha256 }])
      }
    } finally { setUploading(false) }
  }
  const onSubmit = form.handleSubmit((v) => create.mutate({
    material_code: v.material_code, estimated_kg: Number(v.estimated_kg), pickup_address: v.pickup_address, locality: v.locality || null,
    available_from: localToIso(v.available_from), available_to: localToIso(v.available_to), document_ids: photos.map((p) => p.id),
  }))
  const fe = create.error instanceof ApiError ? create.error.fieldErrors() : {}
  const err = (k: keyof ListingForm) => form.formState.errors[k]?.message ?? fe[k]
  return (
    <>
      <PageHeader title="Create listing" description="Declare sorted plastic for collection. Your estimate is compared with the weight the collector records at pickup." />
      <div className="grid gap-4 lg:grid-cols-[minmax(0,2fr)_minmax(0,1fr)]">
        <form onSubmit={onSubmit} noValidate>
          <Panel title="Listing details" sub="Fields marked * are required"
            footer={<div className="flex w-full justify-end gap-2"><Button type="button" variant="outline" onClick={() => nav(-1)}>Cancel</Button><Button type="submit" loading={create.isPending}>Publish listing</Button></div>}>
            <div className="grid gap-4 sm:grid-cols-2">
              <Field label="Material" htmlFor="material_code" required error={err('material_code')} className="sm:col-span-2"
                hint="Choose the polymer. AI photo detection is offered in the ReLoop Flutter app once the team’s model is connected on the backend.">
                <Select id="material_code" {...form.register('material_code')} aria-invalid={!!err('material_code')} disabled={materials.isPending}>
                  <option value="">{materials.isPending ? 'Loading materials…' : 'Select material'}</option>
                  {materials.data?.map((m) => <option key={m.code} value={m.code}>{m.code} · {m.name}{m.resin_code ? ` (RIC ${m.resin_code})` : ''}</option>)}
                </Select>
              </Field>
              <Field label="Estimated weight (kg)" htmlFor="estimated_kg" required error={err('estimated_kg')} hint="The collector notes any difference above ±20% at pickup.">
                <Input id="estimated_kg" inputMode="decimal" {...form.register('estimated_kg')} aria-invalid={!!err('estimated_kg')} />
              </Field>
              <Field label="Locality" htmlFor="locality" error={err('locality')}><Input id="locality" placeholder="e.g. Vikhroli East" {...form.register('locality')} /></Field>
              <Field label="Pickup address" htmlFor="pickup_address" required error={err('pickup_address')} className="sm:col-span-2" hint="Shared only with the assigned collector and recycler.">
                <Textarea id="pickup_address" rows={2} {...form.register('pickup_address')} aria-invalid={!!err('pickup_address')} />
              </Field>
              <Field label="Available from" htmlFor="available_from" required error={err('available_from')}><Input id="available_from" type="datetime-local" {...form.register('available_from')} /></Field>
              <Field label="Available until" htmlFor="available_to" required error={err('available_to')}><Input id="available_to" type="datetime-local" {...form.register('available_to')} aria-invalid={!!err('available_to')} /></Field>
              <Field label="Photos" htmlFor="photos" className="sm:col-span-2" hint="Each file’s SHA-256 is computed on this device and recorded. File storage is not yet connected on the backend, so the image itself is not uploaded.">
                <label htmlFor="photos" className="flex cursor-pointer flex-wrap items-center gap-2 rounded-md border border-dashed border-line-2 px-3 py-3 text-[13px] text-fg-2 hover:bg-surface-2">
                  <Camera className="size-4" />{uploading ? 'Registering…' : photos.length ? `${photos.length} photo${photos.length > 1 ? 's' : ''} recorded` : 'Add photos of the bags or bales'}
                  <span className="ml-auto inline-flex items-center gap-1 text-accent"><Upload className="size-3.5" />Choose files</span>
                </label>
                <input id="photos" type="file" accept="image/*" capture="environment" multiple className="sr-only" onChange={(e) => void onFiles(e.target.files)} />
                {photos.length > 0 && <ul className="mt-1 text-[11px] text-fg-3">{photos.map((p) => <li key={p.id} className="truncate font-mono">{p.name} · sha256 {p.sha.slice(0, 16)}…</li>)}</ul>}
              </Field>
            </div>
            {create.error && !Object.keys(fe).length && <Note tone="bad" className="mt-4" title="Listing not published">{create.error.message}</Note>}
          </Panel>
        </form>
        <div className="flex flex-col gap-4">
          <Panel title="What happens next">
            <ol className="flex list-decimal flex-col gap-1.5 pl-4 text-[13px] text-fg-2">
              <li>Collectors see the listing and make per-kg offers.</li>
              <li>You accept one offer. Other offers are declined.</li>
              <li>The collector weighs the material and gives you a 6-digit code.</li>
              <li>You enter the code to confirm. You are paid on the <b>collected</b> weight.</li>
              <li>The recycler records receipt, rejection and processing; you can follow every stage.</li>
            </ol>
          </Panel>
        </div>
      </div>
    </>
  )
}

/* ─────────────── Offers ─────────────── */
function OffersForBatch({ batch }: { batch: Batch }) {
  const offers = useOffers(batch.id)
  const [accepting, setAccepting] = React.useState<CollectionOffer | null>(null)
  const accept = useApiMutation((o: CollectionOffer) => batchesApi.acceptOffer(batch.id, o.id), {
    invalidate: [K.batches, K.offers(batch.id)], success: (_, o) => `Offer accepted. ${o.collector_name} is assigned.`, onSuccess: () => setAccepting(null),
  })
  const est = q(batch.quantities.estimated_kg) ?? 0
  return (
    <Panel title={<span><span className="font-mono">{batch.batch_code}</span> · {batch.material} · {kg(est)}</span>} sub={`Available ${dateTime(batch.available_from)} – ${dateTime(batch.available_to)}`} flush>
      <QueryState query={offers} empty={{ title: 'No offers yet', body: 'Collectors serving your area have been notified. Offers expire after two days.' }}
        isEmpty={(o) => o.filter((x) => x.status === 'OPEN').length === 0}>{(O) => (
        <DataTable label={`Offers for ${batch.batch_code}`} rows={O.filter((o) => o.status === 'OPEN')} rowKey={(o) => o.id} initialSort={{ key: 'rate', dir: -1 }}
          columns={[
            { key: 'c', header: 'Collector', cell: (o) => <b className="font-medium">{o.collector_name}</b>, sortValue: (o) => o.collector_name ?? '' },
            { key: 'rate', header: 'Rate', numeric: true, cell: (o) => `${inr(o.generator_rate_per_kg)}/kg`, sortValue: (o) => o.generator_rate_per_kg },
            { key: 'pay', header: 'Est. payment', numeric: true, cell: (o) => inr(o.generator_rate_per_kg * est), sortValue: (o) => o.generator_rate_per_kg },
            { key: 'when', header: 'Proposed pickup', cell: (o) => <span className="text-xs">{dateTime(o.proposed_pickup_at)}</span>, sortValue: (o) => o.proposed_pickup_at },
            { key: 'exp', header: 'Expires', cell: (o) => <span className="text-xs">{dateTime(o.expires_at)}</span>, sortValue: (o) => o.expires_at },
            { key: 'x', header: '', cell: (o) => <Button size="sm" onClick={() => setAccepting(o)}>Accept</Button> },
          ]} />
      )}</QueryState>
      <p className="border-t border-line px-4 py-2 text-xs text-fg-3">Estimated payment uses your listed weight. You are paid on the weight recorded at pickup. Declining a single offer is not supported by the backend; offers you don’t accept are declined when you accept another.</p>
      <Dialog open={!!accepting} onOpenChange={(o) => !o && setAccepting(null)}>
        {accepting && <DialogContent title="Accept offer?" description={`${accepting.collector_name} · ${inr(accepting.generator_rate_per_kg)}/kg`}
          footer={<><Button variant="outline" onClick={() => setAccepting(null)}>Cancel</Button><Button loading={accept.isPending} onClick={() => accept.mutate(accepting)}>Accept offer</Button></>}>
          <KV rows={[['Listed weight', kg(est)], ['Estimated payment', inr(accepting.generator_rate_per_kg * est)], ['Proposed pickup', dateTime(accepting.proposed_pickup_at)], ['Other open offers', 'Declined automatically']]} />
          {accept.error && <Note tone="bad">{accept.error.message}</Note>}
        </DialogContent>}
      </Dialog>
    </Panel>
  )
}
export function GeneratorOffers() {
  const batches = useBatches({ status: 'LISTED' })
  return (
    <>
      <PageHeader title="Offers" description="Collector offers on your open listings. You choose; nothing is accepted automatically." />
      <QueryState query={batches} empty={{ title: 'No open listings', body: 'Create a listing to receive offers.', action: <Button size="sm" asChild><Link to="/g/listings/new">Create listing</Link></Button> }}>
        {(B) => <div className="flex flex-col gap-4">{B.map((b) => <OffersForBatch key={b.id} batch={b} />)}</div>}
      </QueryState>
    </>
  )
}

/* ─────────────── Handover ─────────────── */
const otpSchema = z.object({ otp: z.string().trim().regex(/^\d{6}$/, 'Enter the 6-digit code') })
function HandoverCard({ batch }: { batch: Batch }) {
  const form = useForm<{ otp: string }>({ resolver: zodResolver(otpSchema), defaultValues: { otp: '' } })
  const confirm = useApiMutation((otp: string) => batchesApi.confirmHandover(batch.id, { otp }), {
    invalidate: [K.batches, K.payments], toastErrors: false, success: (d) => `Handover confirmed: ${kg(d.collected_kg)}. Payment of ${inr(d.payment_generated)} recorded.`,
  })
  const col = q(batch.quantities.collected_kg)!, est = q(batch.quantities.estimated_kg)!
  const dev = est ? ((col - est) / est) * 100 : 0
  return (
    <Panel title={<span className="font-mono">{batch.batch_code}</span>} sub={`${batch.material} · collector ${batch.assigned_collector_name}`}>
      <div className="grid gap-4 md:grid-cols-2">
        <KV rows={[['Listed weight', kg(est)], ['Weighed by collector', <b>{kg(col)}</b>], ['Difference', <span className={Math.abs(dev) > 20 ? 'text-bad' : ''}>{dev >= 0 ? '+' : ''}{pct(dev)}</span>]]} />
        <form noValidate onSubmit={form.handleSubmit((v) => confirm.mutate(v.otp))} className="flex flex-col gap-2">
          <Field label="Code from the collector" htmlFor={`otp-${batch.id}`} required error={form.formState.errors.otp?.message ?? (confirm.error?.code === 'OTP_INVALID' ? 'That code does not match. Ask the collector to read it again.' : undefined)}
            hint="Only confirm if the weight shown matches what you saw on the scale.">
            <Input id={`otp-${batch.id}`} inputMode="numeric" maxLength={6} autoComplete="one-time-code" className="h-11 font-mono text-lg tracking-[.3em]" {...form.register('otp')} />
          </Field>
          {confirm.error && confirm.error.code !== 'OTP_INVALID' && <Note tone="bad">{confirm.error.message}</Note>}
          <Button type="submit" loading={confirm.isPending}>Confirm {kg(col)}</Button>
        </form>
      </div>
      {Math.abs(dev) > 20 && <Note tone="warn" className="mt-3">The weighed amount differs from your estimate by more than 20%. If it is wrong, do not confirm; ask the collector to re-weigh.</Note>}
    </Panel>
  )
}
export function GeneratorHandover() {
  const batches = useBatches()
  return (
    <>
      <PageHeader title="Handover confirmation" description="The collector weighs your material and reads you a 6-digit code. Entering the code confirms the collected weight and records your payment." />
      <QueryState query={batches}>{(B) => {
        const confirm = B.filter(awaitingConfirmation)
        const scheduled = B.filter((b) => b.status === 'ASSIGNED' && !awaitingConfirmation(b))
        return (
          <div className="flex flex-col gap-4">
            {confirm.length ? confirm.map((b) => <HandoverCard key={b.id} batch={b} />) : <Panel title="Waiting for your confirmation"><EmptyState title="Nothing to confirm" body="When a collector records a weight at your premises, it appears here." /></Panel>}
            <Panel title="Scheduled pickups" flush>
              <DataTable label="Scheduled pickups" rows={scheduled} rowKey={(b) => b.id} empty={{ title: 'No pickups scheduled', body: 'Accept an offer to schedule a pickup.' }}
                columns={[batchColumns[0], batchColumns[1], batchColumns[3], { key: 'c', header: 'Collector', cell: (b) => b.assigned_collector_name ?? '—' }, { key: 'w', header: 'Window', cell: (b) => <span className="text-xs">{dateTime(b.available_from)} – {dateTime(b.available_to)}</span> }]} />
            </Panel>
          </div>
        )
      }}</QueryState>
    </>
  )
}

/* ─────────────── Batch tracking ─────────────── */
export function GeneratorBatches() {
  const batches = useBatches()
  const nav = useNavigate()
  return (
    <>
      <PageHeader title="Batch tracking" description="Every batch from listing to recovered output. Each quantity is recorded by a different party and shown separately." />
      <Panel flush footer={<><SourceLine source={SOURCE} /><span>Recovered kg is a pro rata share of measured run output.</span></>}>
        <QueryState query={batches}>{(B) => (
          <DataTable label="Batches" rows={B} columns={batchColumns} rowKey={(b) => b.id} onRowClick={(b) => nav(`/passport/${b.batch_code}`)}
            search={(b) => b.batch_code} searchPlaceholder="Search batch code" initialSort={{ key: 'listed', dir: -1 }}
            filters={[{ key: 'st', label: 'Status', options: BATCH_STATUS_OPTIONS, get: (b) => b.status }]}
            footer={(R) => <tr><td colSpan={3}>Total ({R.length})</td><td className="tnum text-right">{num1(sumQ(R, 'estimated_kg'))}</td><td className="tnum text-right">{num1(sumQ(R, 'collected_kg'))}</td><td className="tnum text-right">{num1(sumQ(R, 'accepted_kg'))}</td><td className="tnum text-right">{num1(sumQ(R, 'processed_kg'))}</td><td colSpan={2} /></tr>}
            empty={{ title: 'No batches yet' }} />
        )}</QueryState>
      </Panel>
    </>
  )
}

/* ─────────────── Payments ─────────────── */
export function PaymentsTable({ rows, perspective }: { rows: Payment[]; perspective: 'payee' | 'payer' }) {
  const batches = useBatches()
  const codeOf = (id: string | null) => batches.data?.find((b) => b.id === id)?.batch_code
  return (
    <DataTable label="Payments" rows={rows} rowKey={(p) => p.id} initialSort={{ key: 'at', dir: -1 }}
      filters={[{ key: 'st', label: 'Status', options: [{ value: 'PENDING', label: 'Pending' }, { value: 'PAID', label: 'Paid' }], get: (p) => p.status }]}
      columns={[
        { key: 'at', header: 'Date', cell: (p) => <span className="text-xs">{dateTime(p.created_at)}</span>, sortValue: (p) => p.created_at },
        { key: 'b', header: 'Batch', cell: (p) => (codeOf(p.batch_id) ? <BatchLink code={codeOf(p.batch_id)!} /> : <span className="font-mono text-xs text-fg-3">{p.batch_id?.slice(0, 8) ?? '—'}</span>) },
        { key: 'type', header: 'Type', cell: (p) => (p.payment_type === 'GENERATOR_PAYOUT' ? (perspective === 'payee' ? 'Payout to you' : 'Payout to generator') : p.payment_type) },
        { key: 'kg', header: 'Collected kg', numeric: true, cell: (p) => num1(p.quantity_kg), sortValue: (p) => p.quantity_kg },
        { key: 'rate', header: 'Rate', numeric: true, cell: (p) => (p.rate != null ? `${inr(p.rate)}/kg` : '—') },
        { key: 'amt', header: 'Amount', numeric: true, cell: (p) => inr(p.amount), sortValue: (p) => p.amount },
        { key: 'st', header: 'Status', cell: (p) => (p.status === 'PAID' ? <Badge tone="ok">Paid</Badge> : <Badge tone="warn">Pending</Badge>), sortValue: (p) => p.status },
        { key: 'ref', header: 'Reference', cell: (p) => <span className="font-mono text-xs">{p.external_ref ?? '—'}</span> },
      ]}
      footer={(R) => <tr><td colSpan={5}>Total</td><td className="tnum text-right">{inr(R.reduce((s, p) => s + p.amount, 0))}</td><td colSpan={2} /></tr>}
      empty={{ title: 'No payments yet', body: 'A payment is created when a handover is confirmed.' }} />
  )
}
export function GeneratorPayments() {
  const payments = usePayments()
  return (
    <>
      <PageHeader title="Payments" description="Payments are calculated on the weight recorded at pickup and confirmed by you. The collector bears any later rejection." />
      <QueryState query={payments}>{(P) => (
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-3">
            <Kpi label="Paid" value={inr(P.filter((p) => p.status === 'PAID').reduce((s, p) => s + p.amount, 0))} sub={`${P.filter((p) => p.status === 'PAID').length} payments`} />
            <Kpi label="Pending" value={inr(P.filter((p) => p.status === 'PENDING').reduce((s, p) => s + p.amount, 0))} sub="Marked paid by the collector" />
            <Kpi label="Collected kg paid for" value={kg(P.reduce((s, p) => s + (p.quantity_kg ?? 0), 0))} />
          </div>
          <Panel flush footer={<SourceLine source="ReLoop API · /payments (simulated ledger; no money moves)" />}><PaymentsTable rows={P} perspective="payee" /></Panel>
        </div>
      )}</QueryState>
    </>
  )
}

/* ─────────────── Contribution statements ─────────────── */
export function GeneratorStatements() {
  const batches = useBatches()
  const [open, setOpen] = React.useState<Batch | null>(null)
  return (
    <>
      <PageHeader title="Contribution statements" description="Your share of measured recycling output, per processed batch. Issued from ReLoop records; not statutory EPR certificates." />
      <Note tone="warn" className="mb-4">These statements are not issued by CPCB or any government body and cannot be used for EPR compliance. “Independently reviewed” appears only for batches an NGO has verified. The backend’s own certificate endpoint reports listed kg as contributed (audit §5.2), so it is not used here.</Note>
      <Panel flush>
        <QueryState query={batches}>{(B) => (
          <DataTable label="Contribution statements" rows={B.filter((b) => q(b.quantities.processed_kg) != null)} rowKey={(b) => b.id} onRowClick={setOpen}
            empty={{ title: 'No statements yet', body: 'A statement appears once a recycler measures the output of a run that includes your batch.' }}
            columns={[
              { key: 'id', header: 'Statement', cell: (b) => <span className="font-mono text-xs">RCS-{b.batch_code.slice(-6)}</span> },
              batchColumns[0], batchColumns[1], batchColumns[4], batchColumns[6],
              { key: 'v', header: 'Independent review', cell: (b) => (b.verification?.decision === 'VERIFIED' ? <Badge tone="ok">NGO-verified</Badge> : <NgoBadge decision={b.verification?.decision} />) },
            ]} />
        )}</QueryState>
      </Panel>
      <Dialog open={!!open} onOpenChange={(o) => !o && setOpen(null)}>
        {open && <DialogContent title="Recycling contribution statement" description={`RCS-${open.batch_code.slice(-6)} · generated from ReLoop records`}>
          <p className="text-[13px]"><b>{open.generator_name}</b> contributed the material below, recycled by {open.destination_recycler_name ?? 'the recycler'}.</p>
          <KV rows={[['Batch', <span className="font-mono">{open.batch_code}</span>], ['Material', open.material_name ?? open.material], ['Collected', kg(q(open.quantities.collected_kg))], ['Accepted at recycler', kg(q(open.quantities.accepted_kg))],
            ['Recovered output (pro rata)', kg(q(open.quantities.processed_kg)), true], ['Independently reviewed', open.verification?.decision === 'VERIFIED' ? `${kg(verifiedKg(open.quantities, 'VERIFIED'))} by ${open.verification.ngo}` : 'Not yet']]} />
          <Note tone="warn">Non-statutory. Not an EPR certificate and not valid for regulatory filing.</Note>
        </DialogContent>}
      </Dialog>
    </>
  )
}

/* ─────────────── Analytics ─────────────── */
export function GeneratorAnalytics() {
  const batches = useBatches()
  return (
    <>
      <PageHeader title="Contribution analytics" description="How your listings convert into collected, accepted and recovered material, and where losses occur." />
      <QueryState query={batches} empty={{ title: 'No data yet', body: 'Analytics appear after your first collected batch.' }}>{(B) => {
        const live = B.filter((b) => b.status !== 'CANCELLED')
        const picked = live.filter((b) => q(b.quantities.collected_kg) != null)
        const mats = [...new Set(live.map((b) => b.material))]
        const byMat = mats.map((m) => { const X = live.filter((b) => b.material === m); return { m, Listed: sumQ(X, 'estimated_kg'), Collected: sumQ(X, 'collected_kg'), Accepted: sumQ(X, 'accepted_kg'), Recovered: sumQ(X, 'processed_kg') } })
        const months = [...new Set(live.map((b) => b.created_at.slice(0, 7)))].sort()
        const byMonth = months.map((mo) => { const X = live.filter((b) => b.created_at.startsWith(mo)); return { mo: new Date(mo + '-01').toLocaleDateString('en-IN', { month: 'short', year: 'numeric' }), Listed: sumQ(X, 'estimated_kg'), Collected: sumQ(X, 'collected_kg'), Recovered: sumQ(X, 'processed_kg') } })
        const tt = { contentStyle: { background: 'var(--surface)', border: '1px solid var(--line)', fontSize: 12 }, formatter: (v: number) => kg(v) }
        const axis = { tick: { fill: 'var(--fg-3)', fontSize: 11 }, axisLine: false, tickLine: false }
        return (
          <div className="flex flex-col gap-4">
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
              <Kpi icon={<Package />} label="Collection accuracy" value={pct(sumQ(picked, 'estimated_kg') ? (sumQ(picked, 'collected_kg') / sumQ(picked, 'estimated_kg')) * 100 : null)} sub="Collected ÷ listed, collected batches" />
              <Kpi label="Acceptance rate" value={pct(sumQ(B, 'received_kg') ? (sumQ(B, 'accepted_kg') / sumQ(B, 'received_kg')) * 100 : null)} sub="Accepted ÷ received" />
              <Kpi label="Rejected at gate" value={kg(sumQ(B, 'rejected_kg'))} sub="Kept on record, not recycled" />
              <Kpi label="Recovered output" value={kg(sumQ(B, 'processed_kg'))} sub="Pro rata share of runs" />
            </div>
            <div className="grid gap-4 lg:grid-cols-2">
              <Panel title="By listing month" footer={<SourceLine source={SOURCE} />}>
                <div className="h-60"><ResponsiveContainer><BarChart data={byMonth}><CartesianGrid vertical={false} stroke="var(--line)" /><XAxis dataKey="mo" {...axis} /><YAxis {...axis} width={48} /><Tooltip {...tt} /><Legend wrapperStyle={{ fontSize: 12 }} />
                  <Bar dataKey="Listed" fill="var(--c3)" /><Bar dataKey="Collected" fill="var(--c2)" /><Bar dataKey="Recovered" fill="var(--c1)" /></BarChart></ResponsiveContainer></div>
              </Panel>
              <Panel title="By material" footer={<SourceLine source={SOURCE} />}>
                <div className="h-60"><ResponsiveContainer><BarChart data={byMat}><CartesianGrid vertical={false} stroke="var(--line)" /><XAxis dataKey="m" {...axis} /><YAxis {...axis} width={48} /><Tooltip {...tt} /><Legend wrapperStyle={{ fontSize: 12 }} />
                  <Bar dataKey="Listed" fill="var(--c3)" /><Bar dataKey="Collected" fill="var(--c2)" /><Bar dataKey="Accepted" fill="var(--c4)" /><Bar dataKey="Recovered" fill="var(--c1)" /></BarChart></ResponsiveContainer></div>
              </Panel>
            </div>
          </div>
        )
      }}</QueryState>
    </>
  )
}
