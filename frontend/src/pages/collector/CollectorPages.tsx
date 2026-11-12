import * as React from 'react'
import { Link, useNavigate, useSearchParams } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Camera, ClipboardCheck, Hand, Truck, Upload } from 'lucide-react'
import { useAuth } from '@/app/auth'
import { K, useAvailable, useBatches, useConsignments, useMaterials, useOrgs, usePayments, usePerformance, usePlan, usePlans } from '@/hooks/queries'
import { useApiMutation } from '@/hooks/useApiMutation'
import * as colApi from '@/services/collections'
import * as consApi from '@/services/consignments'
import * as intelApi from '@/services/intelligence'
import { markPaid } from '@/services/shared'
import { registerDocument } from '@/services/documents'
import { PageHeader, SourceLine } from '@/components/page'
import { Panel, Kpi, KV } from '@/components/ui/panel'
import { Button } from '@/components/ui/button'
import { Input, Select, Textarea } from '@/components/ui/input'
import { Field } from '@/components/ui/field'
import { Note } from '@/components/ui/note'
import { Badge } from '@/components/ui/badge'
import { Dialog, DialogContent, Drawer } from '@/components/ui/dialog'
import { DataTable } from '@/components/ui/data-table'
import { QueryState, EmptyState, ErrorState, LoadingRows } from '@/components/states'
import { BatchStatusBadge, SimpleStatus } from '@/components/status'
import { BatchLink } from '@/features/batches/PassportView'
import { awaitingConfirmation } from '@/features/batches/status-helpers'
import { consStatus, CONS_STATUS } from '@/features/batches/consignment-status'
import { PaymentsTable } from '@/pages/generator/GeneratorPages'
import { q, sumQ } from '@/lib/quantities'
import { date, dateTime, humanize, inr, kg, num1, pct } from '@/lib/format'
import { kgField, localToIso, toLocalInput } from '@/lib/forms'
import type { AvailableListing, Batch, Consignment, PlanSummary } from '@/types/api'

/** The backend returns the handover OTP only once, in the pickup response (audit §5.3). Keep it on this device until confirmed. */
const OTP_KEY = (batchId: string) => `reloop.otp.${batchId}`
const saveOtp = (id: string, otp: string) => { try { sessionStorage.setItem(OTP_KEY(id), otp) } catch { /* storage unavailable */ } }
const readOtp = (id: string) => { try { return sessionStorage.getItem(OTP_KEY(id)) } catch { return null } }

function useMyBatches() {
  const { me } = useAuth()
  const all = useBatches()
  const mine = React.useMemo(() => (all.data ?? []).filter((b) => b.assigned_collector_org_id === me?.active_org?.id), [all.data, me])
  return { query: all, mine }
}


/* ─────────────── Overview ─────────────── */
export function CollectorOverview() {
  const { query, mine } = useMyBatches()
  const cons = useConsignments()
  const plans = usePlans()
  const nav = useNavigate()
  const assigned = mine.filter((b) => b.status === 'ASSIGNED' && !awaitingConfirmation(b))
  const awaiting = mine.filter(awaitingConfirmation)
  const onHand = mine.filter((b) => b.status === 'PICKED_UP')
  const openCons = (cons.data ?? []).filter((c) => consStatus(c) !== 'RECEIVED')
  return (
    <>
      <PageHeader title="Operations overview" description="Pickups to make, weights awaiting generator confirmation and loads on the road."
        actions={<Button asChild><Link to="/c/pickup"><Hand />Record a pickup</Link></Button>} />
      <QueryState query={query}>{() => (
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
            <Kpi icon={<ClipboardCheck />} label="Pickups to make" value={assigned.length} sub={`${kg(sumQ(assigned, 'estimated_kg'))} listed`} />
            <Kpi icon={<Hand />} label="Awaiting generator code" value={awaiting.length} sub={`${kg(sumQ(awaiting, 'collected_kg'))} weighed`} />
            <Kpi label="On hand, not dispatched" value={kg(sumQ(onHand, 'collected_kg'))} sub={`${onHand.length} batches`} />
            <Kpi icon={<Truck />} label="Consignments open" value={cons.isPending ? '…' : openCons.length} sub="In transit or at recycler" />
          </div>
          {onHand.length > 0 && <Note>{onHand.length} collected batch{onHand.length > 1 ? 'es are' : ' is'} ready to dispatch. <Link className="font-medium text-accent underline" to="/c/consignments">Create consignment</Link></Note>}
          {(plans.data ?? []).filter((p) => p.status === 'PROPOSED').length > 0 && <Note>There are proposed aggregation plans. <Link className="font-medium text-accent underline" to="/c/plans">Review plans</Link></Note>}
          <Panel title="Assigned pickups" flush>
            <DataTable label="Assigned pickups" rows={[...awaiting, ...assigned]} rowKey={(b) => b.id} onRowClick={(b) => nav(`/c/pickup?batch=${b.id}`)}
              empty={{ title: 'No pickups assigned', body: 'Make offers on available listings to get work.', action: <Button size="sm" asChild><Link to="/c/listings">Browse listings</Link></Button> }}
              columns={[
                { key: 'c', header: 'Batch', cell: (b) => <BatchLink code={b.batch_code} /> },
                { key: 'g', header: 'Generator', cell: (b) => <span>{b.generator_name}<span className="block text-xs text-fg-3">{b.locality}</span></span> },
                { key: 'm', header: 'Material', cell: (b) => b.material, hideOnMobile: true },
                { key: 'e', header: 'Listed kg', numeric: true, cell: (b) => num1(q(b.quantities.estimated_kg)) },
                { key: 'w', header: 'Window', cell: (b) => <span className="text-xs">{dateTime(b.available_from)}</span>, hideOnMobile: true },
                { key: 's', header: 'Next step', cell: (b) => (awaitingConfirmation(b) ? <Badge tone="warn">Generator to confirm</Badge> : <Badge tone="info">Weigh & record</Badge>) },
              ]} />
          </Panel>
        </div>
      )}</QueryState>
    </>
  )
}

/* ─────────────── Available listings ─────────────── */
const offerSchema = z.object({
  rate: z.string().trim().refine((v) => /^\d+(\.\d{1,2})?$/.test(v) && Number(v) > 0 && Number(v) < 200, 'Enter a rate between ₹0 and ₹200 per kg'),
  when: z.string().min(1, 'Choose a pickup time'),
})
function OfferDialog({ listing, material, onClose }: { listing: AvailableListing; material: string; onClose: () => void }) {
  const form = useForm<z.infer<typeof offerSchema>>({ resolver: zodResolver(offerSchema), defaultValues: { rate: '', when: toLocalInput(new Date(Math.max(Date.now() + 3600_000, new Date(listing.available_from).getTime()))) } })
  const m = useApiMutation((v: { rate: string; when: string }) => colApi.makeOffer(listing.id, { generator_rate_per_kg: Number(v.rate), proposed_pickup_at: localToIso(v.when) }), {
    invalidate: [K.available, K.offers(listing.id)], success: 'Offer sent to the generator', onSuccess: onClose,
  })
  const rate = Number(form.watch('rate'))
  return (
    <DialogContent title="Make an offer" description={`${listing.batch_code} · ${kg(listing.estimated_kg)} ${material} · ${listing.locality ?? ''}`}
      footer={<><Button variant="outline" onClick={onClose}>Cancel</Button><Button loading={m.isPending} onClick={form.handleSubmit((v) => m.mutate(v))}>Send offer</Button></>}>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Rate paid to generator (₹/kg)" htmlFor="rate" required error={form.formState.errors.rate?.message}><Input id="rate" inputMode="decimal" {...form.register('rate')} /></Field>
        <Field label="Proposed pickup" htmlFor="when" required error={form.formState.errors.when?.message}><Input id="when" type="datetime-local" {...form.register('when')} /></Field>
      </div>
      <KV rows={[['Generator payment at listed weight', rate > 0 ? inr(rate * listing.estimated_kg) : '—'], ['Pickup window', `${dateTime(listing.available_from)} – ${dateTime(listing.available_to)}`]]} />
      <Note>The generator is paid on the weight you record at pickup. Rejections at the recycler are your risk.</Note>
      {m.error && <Note tone="bad" title={m.error.code === 'DUPLICATE_OFFER' ? 'You already have an open offer on this listing' : 'Offer not sent'}>{m.error.message}</Note>}
    </DialogContent>
  )
}
export function CollectorListings() {
  const listings = useAvailable()
  const materials = useMaterials()
  const [offerFor, setOfferFor] = React.useState<AvailableListing | null>(null)
  const matCode = (id: number) => materials.data?.find((m) => m.id === id)?.code ?? `#${id}`
  return (
    <>
      <PageHeader title="Available listings" description="Open listings from generators. Every row is a declared listing; predicted supply never appears here." />
      <Panel flush footer={<><SourceLine source="ReLoop API · /collections/available" /><span>Distance is shown only when both locations have coordinates.</span></>}>
        <QueryState query={listings}>{(L) => (
          <DataTable label="Available listings" rows={L} rowKey={(l) => l.id} onRowClick={setOfferFor} initialSort={{ key: 'from', dir: 1 }}
            search={(l) => `${l.batch_code} ${l.locality ?? ''} ${l.pickup_address}`} searchPlaceholder="Search area or batch"
            filters={[{ key: 'm', label: 'Material', options: [...new Set(L.map((l) => l.material_category_id))].map((id) => ({ value: String(id), label: matCode(id) })), get: (l) => String(l.material_category_id) }]}
            empty={{ title: 'No open listings', body: 'New listings appear here as generators publish them.' }}
            columns={[
              { key: 'c', header: 'Listing', cell: (l) => <span className="font-mono text-xs" title={l.batch_code}>…{l.batch_code.slice(-6)}</span>, sortValue: (l) => l.batch_code },
              { key: 'loc', header: 'Area', cell: (l) => <span>{l.locality ?? '—'}<span className="block max-w-[260px] truncate text-xs text-fg-3">{l.pickup_address}</span></span>, sortValue: (l) => l.locality ?? '' },
              { key: 'm', header: 'Material', cell: (l) => matCode(l.material_category_id), sortValue: (l) => matCode(l.material_category_id) },
              { key: 'kg', header: 'Listed kg', numeric: true, cell: (l) => num1(l.estimated_kg), sortValue: (l) => l.estimated_kg },
              { key: 'd', header: 'Distance', numeric: true, cell: (l) => (l.distance_km ? `${num1(l.distance_km)} km` : '—'), sortValue: (l) => l.distance_km, hideOnMobile: true },
              { key: 'from', header: 'Available', cell: (l) => <span className="text-xs">{dateTime(l.available_from)}</span>, sortValue: (l) => l.available_from, hideOnMobile: true },
              { key: 'x', header: '', cell: () => <Button size="sm" variant="outline">Make offer</Button>, hideOnMobile: true },
            ]} />
        )}</QueryState>
      </Panel>
      <Dialog open={!!offerFor} onOpenChange={(o) => !o && setOfferFor(null)}>
        {offerFor && <OfferDialog listing={offerFor} material={matCode(offerFor.material_category_id)} onClose={() => setOfferFor(null)} />}
      </Dialog>
    </>
  )
}

/* ─────────────── Assignments ─────────────── */
export function CollectorAssignments() {
  const { query, mine } = useMyBatches()
  const nav = useNavigate()
  return (
    <>
      <PageHeader title="Collection assignments" description="Every batch assigned to you, from accepted offer to delivery." />
      <Panel flush>
        <QueryState query={query}>{() => (
          <DataTable label="Assignments" rows={mine} rowKey={(b) => b.id} onRowClick={(b) => nav(`/passport/${b.batch_code}`)} initialSort={{ key: 'c', dir: -1 }}
            search={(b) => `${b.batch_code} ${b.generator_name ?? ''}`} searchPlaceholder="Search batch or generator"
            filters={[{ key: 's', label: 'Status', options: ['ASSIGNED', 'PICKED_UP', 'IN_TRANSIT', 'RECEIVED', 'PROCESSED'].map((s) => ({ value: s, label: humanize(s) })), get: (b) => b.status }]}
            empty={{ title: 'No assignments yet' }}
            columns={[
              { key: 'c', header: 'Batch', cell: (b) => <BatchLink code={b.batch_code} />, sortValue: (b) => b.created_at },
              { key: 'g', header: 'Generator', cell: (b) => b.generator_name ?? '—', sortValue: (b) => b.generator_name ?? '' },
              { key: 'm', header: 'Material', cell: (b) => b.material },
              { key: 'e', header: 'Listed', numeric: true, cell: (b) => num1(q(b.quantities.estimated_kg)) },
              { key: 'col', header: 'Collected', numeric: true, cell: (b) => num1(q(b.quantities.collected_kg)), sortValue: (b) => q(b.quantities.collected_kg) },
              { key: 'r', header: 'Received', numeric: true, cell: (b) => num1(q(b.quantities.received_kg)) },
              { key: 'a', header: 'Accepted', numeric: true, cell: (b) => num1(q(b.quantities.accepted_kg)) },
              { key: 's', header: 'Status', cell: (b) => (awaitingConfirmation(b) ? <Badge tone="warn">Awaiting generator code</Badge> : <BatchStatusBadge status={b.status} />), sortValue: (b) => b.status },
            ]} />
        )}</QueryState>
      </Panel>
    </>
  )
}

/* ─────────────── Pickup verification ─────────────── */
const pickupSchema = (est: number) => z.object({ collected_kg: kgField('Weight'), notes: z.string().max(500).optional() })
  .refine((v) => { const d = Math.abs((Number(v.collected_kg) - est) / est) * 100; return d <= 20 || (v.notes ?? '').trim().length >= 5 }, { path: ['notes'], message: 'Explain why the weight differs from the listing by more than 20%' })

function PickupForm({ batch }: { batch: Batch }) {
  const est = q(batch.quantities.estimated_kg)!
  const form = useForm<{ collected_kg: string; notes?: string }>({ resolver: zodResolver(pickupSchema(est)), defaultValues: { collected_kg: '', notes: '' } })
  const [photo, setPhoto] = React.useState<{ id: string; name: string } | null>(null)
  const [photoErr, setPhotoErr] = React.useState<string | null>(null)
  const [otp, setOtp] = React.useState<string | null>(readOtp(batch.id))
  const m = useApiMutation((v: { collected_kg: string; notes?: string }) => colApi.recordPickup(batch.id, { collected_kg: Number(v.collected_kg), notes: v.notes || undefined, document_ids: photo ? [photo.id] : [] }), {
    invalidate: [K.batches, K.jobs], toastErrors: false, success: 'Weight recorded. Read the code to the generator.',
    onSuccess: (d) => { saveOtp(batch.id, d.otp); setOtp(d.otp) },
  })
  const kgv = Number(form.watch('collected_kg'))
  const dev = kgv > 0 ? ((kgv - est) / est) * 100 : null
  if (otp || awaitingConfirmation(batch)) {
    return (
      <Panel title="Handover code" sub={`${batch.batch_code} · ${batch.generator_name}`}>
        <div className="flex flex-col items-center gap-2 py-4 text-center">
          <p className="text-[13px] text-fg-2">Weight recorded: <b>{kg(q(batch.quantities.collected_kg) ?? kgv)}</b>. Read this code to the generator. They enter it in their app to confirm the weight.</p>
          {otp ? <div className="font-mono text-4xl font-semibold tracking-[.35em] text-brand" aria-label={`Handover code ${otp.split('').join(' ')}`}>{otp}</div>
            : <Note tone="warn">The code was shown once, on the device that recorded the weight. The backend has no endpoint to show it again, so use that device to read it to the generator.</Note>}
          <Badge tone="warn">Awaiting generator confirmation</Badge>
        </div>
        <Note>Recording a second weight is blocked until the generator confirms (backend guard). The collected quantity becomes final when they enter the code.</Note>
      </Panel>
    )
  }
  return (
    <form noValidate onSubmit={form.handleSubmit((v) => { if (!photo) { setPhotoErr('Add a photo that shows the scale reading'); return } m.mutate(v) }, () => { if (!photo) setPhotoErr('Add a photo that shows the scale reading') })}>
      <Panel title="Record handover" sub={`${batch.batch_code} · ${batch.generator_name} · ${batch.locality ?? ''}`}
        footer={<div className="flex w-full justify-end"><Button type="submit" loading={m.isPending}>Record weight & get code</Button></div>}>
        <div className="grid gap-4 sm:grid-cols-2">
          <Field label="Weight on your scale (kg)" htmlFor="collected_kg" required error={form.formState.errors.collected_kg?.message}
            hint={dev != null ? `${dev >= 0 ? '+' : ''}${pct(dev)} vs listed ${kg(est)} · ${Math.abs(dev) > 20 ? 'note required' : 'within ±20%'}` : `Listed ${kg(est)}`}>
            <Input id="collected_kg" inputMode="decimal" className="h-12 text-xl" {...form.register('collected_kg')} />
          </Field>
          <Field label="Scale photo" htmlFor="scale-photo" required error={photoErr ?? undefined} hint="SHA-256 recorded; the image file is not stored by the backend yet.">
            <label htmlFor="scale-photo" className="flex h-12 cursor-pointer items-center gap-2 rounded-md border border-dashed border-line-2 px-3 text-[13px] text-fg-2 hover:bg-surface-2">
              <Camera className="size-4" /><span className="truncate">{photo ? photo.name : 'Take or choose a photo'}</span><Upload className="ml-auto size-3.5 text-accent" />
            </label>
            <input id="scale-photo" type="file" accept="image/*" capture="environment" className="sr-only"
              onChange={async (e) => { const f = e.target.files?.[0]; if (!f) return; setPhotoErr(null); try { const r = await registerDocument(f, 'PHOTO_PICKUP'); setPhoto({ id: r.document_id, name: f.name }) } catch { setPhotoErr('Could not register the photo. Try again.') } }} />
          </Field>
          <Field label="Notes" htmlFor="notes" className="sm:col-span-2" required={dev != null && Math.abs(dev) > 20} error={form.formState.errors.notes?.message}>
            <Textarea id="notes" rows={2} placeholder="e.g. generator added two extra bags" {...form.register('notes')} />
          </Field>
        </div>
        {m.error && <Note tone="bad" className="mt-4" title="Weight not recorded">{m.error.message}</Note>}
      </Panel>
    </form>
  )
}
export function CollectorPickup() {
  const { query, mine } = useMyBatches()
  const [params, setParams] = useSearchParams()
  const candidates = mine.filter((b) => b.status === 'ASSIGNED')
  const sel = candidates.find((b) => b.id === params.get('batch')) ?? candidates[0]
  return (
    <>
      <PageHeader title="Pickup verification" description="Weigh the material, photograph the scale, then read the handover code to the generator." />
      <QueryState query={query}>{() => candidates.length === 0
        ? <Panel><EmptyState title="No pickups waiting" body="Batches assigned to you appear here until the generator confirms the handover." action={<Button size="sm" asChild><Link to="/c/listings">Browse listings</Link></Button>} /></Panel>
        : (
          <div className="flex flex-col gap-4">
            <Field label="Batch" htmlFor="pick-batch">
              <Select id="pick-batch" value={sel?.id} onChange={(e) => setParams({ batch: e.target.value })}>
                {candidates.map((b) => <option key={b.id} value={b.id}>{b.batch_code} · {b.generator_name} · {awaitingConfirmation(b) ? 'awaiting confirmation' : `${kg(q(b.quantities.estimated_kg))} listed`}</option>)}
              </Select>
            </Field>
            {sel && <PickupForm key={sel.id} batch={sel} />}
          </div>
        )}
      </QueryState>
    </>
  )
}

/* ─────────────── Consignments ─────────────── */
const consSchema = z.object({ destination: z.string().min(1, 'Choose a recycler'), vehicle_no: z.string().trim().max(32).optional() })
function NewConsignmentDialog({ batches, onClose }: { batches: Batch[]; onClose: () => void }) {
  const recyclers = useOrgs('RECYCLER')
  const [selected, setSelected] = React.useState<string[]>(batches.map((b) => b.id))
  const form = useForm<z.infer<typeof consSchema>>({ resolver: zodResolver(consSchema), defaultValues: { destination: '', vehicle_no: '' } })
  const m = useApiMutation((v: z.infer<typeof consSchema>) => consApi.createConsignment({ batch_ids: selected, destination_recycler_org_id: v.destination, vehicle_no: v.vehicle_no || undefined }), {
    invalidate: [K.consignments, K.batches, K.incoming], success: (c) => `${c.consignment_code} dispatched with ${c.items.length} batches`, onSuccess: onClose,
  })
  return (
    <DialogContent wide title="New consignment" description="Select the batches loaded on this vehicle. Each batch keeps its own record and is weighed separately at receipt."
      footer={<><Button variant="outline" onClick={onClose}>Cancel</Button><Button loading={m.isPending} disabled={!selected.length} onClick={form.handleSubmit((v) => m.mutate(v))}>Dispatch {selected.length} batch{selected.length === 1 ? '' : 'es'}</Button></>}>
      <div className="overflow-x-auto rounded-md border border-line">
        <table className="w-full text-[13px]"><thead><tr className="text-left text-xs text-fg-2 [&>th]:bg-surface-2 [&>th]:px-3 [&>th]:py-2"><th></th><th>Batch</th><th>Material</th><th className="text-right">Collected kg</th></tr></thead>
          <tbody>{batches.map((b) => (
            <tr key={b.id} className="[&>td]:border-t [&>td]:border-line [&>td]:px-3 [&>td]:py-2">
              <td><input type="checkbox" aria-label={`Include ${b.batch_code}`} checked={selected.includes(b.id)} onChange={(e) => setSelected(e.target.checked ? [...selected, b.id] : selected.filter((x) => x !== b.id))} /></td>
              <td className="font-mono text-xs">{b.batch_code}</td><td>{b.material}</td><td className="tnum text-right">{num1(q(b.quantities.collected_kg))}</td>
            </tr>))}</tbody></table>
      </div>
      <div className="grid gap-4 sm:grid-cols-2">
        <Field label="Destination recycler" htmlFor="destination" required error={form.formState.errors.destination?.message} hint="Approved recyclers from the ReLoop directory">
          <Select id="destination" {...form.register('destination')} disabled={recyclers.isPending}>
            <option value="">{recyclers.isPending ? 'Loading…' : 'Select recycler'}</option>
            {recyclers.data?.map((r) => <option key={r.id} value={r.id}>{r.legal_name}{r.registration?.pwp_registration_no ? ` · ${r.registration.pwp_registration_no}` : ''}</option>)}
          </Select>
        </Field>
        <Field label="Vehicle number" htmlFor="vehicle_no"><Input id="vehicle_no" placeholder="MH-02-AB-1234" {...form.register('vehicle_no')} /></Field>
      </div>
      {recyclers.isError && <ErrorState error={recyclers.error} />}
      {m.error && <Note tone="bad" title="Not dispatched">{m.error.message}</Note>}
    </DialogContent>
  )
}
export function ConsignmentDetail({ consignment, recyclerName }: { consignment: Consignment; recyclerName?: string }) {
  const batches = useBatches()
  return (
    <div className="flex flex-col gap-4">
      <KV rows={[['Consignment', consignment.consignment_code], ['Destination', recyclerName ?? '—'], ['Vehicle', consignment.vehicle_no ?? '—'], ['Dispatched', dateTime(consignment.dispatched_at)], ['Arrived', dateTime(consignment.arrived_at)], ['Status', <SimpleStatus status={consStatus(consignment)} map={CONS_STATUS} />]]} />
      <Note>Batches travel together but are weighed and recorded individually at receipt. They are never merged.</Note>
      <Panel title="Batches" flush>
        {batches.isPending ? <LoadingRows /> : (
          <table className="w-full text-[13px]"><thead><tr className="text-left text-xs text-fg-2 [&>th]:bg-surface-2 [&>th]:px-3 [&>th]:py-2"><th>Batch</th><th className="text-right">Collected</th><th className="text-right">Received</th><th className="text-right">Accepted</th><th>Status</th></tr></thead>
            <tbody>{consignment.items.map((it) => { const b = batches.data?.find((x) => x.id === it.batch_id); return (
              <tr key={it.batch_id} className="[&>td]:border-t [&>td]:border-line [&>td]:px-3 [&>td]:py-2">
                <td><BatchLink code={it.batch_code} /></td><td className="tnum text-right">{num1(b ? q(b.quantities.collected_kg) : null)}</td>
                <td className="tnum text-right">{num1(b ? q(b.quantities.received_kg) : null)}</td><td className="tnum text-right">{num1(b ? q(b.quantities.accepted_kg) : null)}</td><td><BatchStatusBadge status={b?.status ?? it.status} /></td>
              </tr>) })}</tbody></table>
        )}
      </Panel>
    </div>
  )
}
export function CollectorConsignments() {
  const cons = useConsignments()
  const { mine } = useMyBatches()
  const recyclers = useOrgs('RECYCLER')
  const [creating, setCreating] = React.useState(false)
  const [open, setOpen] = React.useState<Consignment | null>(null)
  const onHand = mine.filter((b) => b.status === 'PICKED_UP')
  const recName = (id: string) => recyclers.data?.find((r) => r.id === id)?.legal_name ?? '—'
  return (
    <>
      <PageHeader title="Transport consignments" description="Group collected batches into one vehicle trip. Only batches whose handover the generator has confirmed can be dispatched."
        actions={<Button disabled={!onHand.length} onClick={() => setCreating(true)} title={onHand.length ? undefined : 'No confirmed pickups to dispatch'}><Truck />New consignment</Button>} />
      {onHand.length === 0 && <Note className="mb-4">No batches are ready to dispatch. A batch becomes dispatchable after the generator confirms the handover.</Note>}
      <Panel flush>
        <QueryState query={cons}>{(C) => (
          <DataTable label="Consignments" rows={C} rowKey={(c) => c.id} onRowClick={setOpen} initialSort={{ key: 'd', dir: -1 }}
            filters={[{ key: 's', label: 'Status', options: Object.entries(CONS_STATUS).map(([value, [, label]]) => ({ value, label })), get: (c) => consStatus(c) }]}
            empty={{ title: 'No consignments yet' }}
            columns={[
              { key: 'c', header: 'Consignment', cell: (c) => <span className="font-mono text-xs">{c.consignment_code}</span>, sortValue: (c) => c.consignment_code },
              { key: 'd', header: 'Dispatched', cell: (c) => <span className="text-xs">{dateTime(c.dispatched_at)}</span>, sortValue: (c) => c.dispatched_at },
              { key: 'to', header: 'Destination', cell: (c) => recName(c.destination_recycler_org_id) },
              { key: 'n', header: 'Batches', numeric: true, cell: (c) => c.items.length, sortValue: (c) => c.items.length },
              { key: 'v', header: 'Vehicle', cell: (c) => <span className="font-mono text-xs">{c.vehicle_no ?? '—'}</span> },
              { key: 's', header: 'Status', cell: (c) => <SimpleStatus status={consStatus(c)} map={CONS_STATUS} />, sortValue: (c) => consStatus(c) },
            ]} />
        )}</QueryState>
      </Panel>
      <Dialog open={creating} onOpenChange={setCreating}>{creating && <NewConsignmentDialog batches={onHand} onClose={() => setCreating(false)} />}</Dialog>
      <Drawer open={!!open} onOpenChange={(o) => !o && setOpen(null)} title={open ? `Consignment ${open.consignment_code}` : ''}>
        {open && <ConsignmentDetail consignment={open} recyclerName={recName(open.destination_recycler_org_id)} />}
      </Drawer>
    </>
  )
}

/* ─────────────── Aggregation plans ─────────────── */
export function PlanDetailView({ id, canAct }: { id: string; canAct: boolean }) {
  const plan = usePlan(id)
  const accept = useApiMutation(() => intelApi.acceptPlan(id), { invalidate: [K.plans], success: (d) => `Plan ${humanize(d.plan_status).toLowerCase()}` })
  const cancel = useApiMutation(() => intelApi.cancelPlan(id), { invalidate: [K.plans, K.batches, K.available], success: 'Plan cancelled; batches released' })
  return (
    <QueryState query={plan}>{(p) => (
      <div className="flex flex-col gap-4">
        <div className="flex flex-wrap items-center gap-2"><span className="font-mono font-semibold">{p.plan_code}</span><SimpleStatus status={p.status} map={PLAN_STATUS} /></div>
        <div className="grid grid-cols-2 gap-3 sm:grid-cols-4">
          <Kpi label="Target" value={kg(p.target_kg)} /><Kpi label="Listed in plan" value={kg(p.est_total_kg)} />
          <Kpi label="Expected usable" value={kg(p.est_usable_kg)} sub="Backend model: fixed 92%" /><Kpi label="Shortfall" value={kg(p.shortfall_kg)} sub={p.fulfils_requirement ? 'Listed kg meets target' : 'Not enough listings'} />
        </div>
        {p.fulfils_requirement && p.est_usable_kg < p.target_kg && <Note tone="warn">The backend marks this plan as meeting the target because listed kg ≥ target. Expected usable kg ({kg(p.est_usable_kg)}) is below target.</Note>}
        <Panel title="Source batches" sub="Each batch stays individually traceable" flush>
          <DataTable label="Plan items" rows={p.items} rowKey={(i) => i.batch_id} columns={[
            { key: 'c', header: 'Batch', cell: (i) => <BatchLink code={i.batch_code} /> },
            { key: 'p', header: 'Planned kg', numeric: true, cell: (i) => num1(i.planned_kg) },
            { key: 'u', header: 'Est. usable kg', numeric: true, cell: (i) => num1(i.est_usable_kg) },
            { key: 'd', header: 'Distance', numeric: true, cell: (i) => `${num1(i.distance_km)} km` },
            { key: 's', header: 'Item status', cell: (i) => humanize(i.item_status) },
          ]} />
        </Panel>
        {p.cost_estimate && <Panel title="Cost estimate" sub="Backend model with fixed rates; not based on your pricing assumptions">
          <KV rows={[...Object.entries(p.cost_estimate.breakdown).map(([k, v]) => [humanize(k), inr(v)] as [string, string]), ['Total', inr(p.cost_estimate.total_cost), true], ['Per usable kg', inr(p.cost_estimate.landed_cost_per_usable_kg), true]]} />
        </Panel>}
        {canAct && ['PROPOSED', 'ACCEPTED'].includes(p.status) && (
          <div className="flex flex-wrap gap-2">
            <Button loading={accept.isPending} onClick={() => accept.mutate(undefined)}>Accept plan</Button>
            <Button variant="destructive" loading={cancel.isPending} onClick={() => cancel.mutate(undefined)}>Cancel plan</Button>
          </div>
        )}
        <Note>Accepting a plan records your agreement. It does not assign the batches to you; each batch is still collected through the normal offer and handover flow (backend behaviour).</Note>
      </div>
    )}</QueryState>
  )
}
export const PLAN_STATUS: Record<string, ['ok' | 'warn' | 'info' | 'neutral' | 'bad', string]> = {
  PROPOSED: ['info', 'Proposed'], ACCEPTED: ['warn', 'Accepted by one party'], ACTIVE: ['ok', 'Active'], CANCELLED: ['neutral', 'Cancelled'], COMPLETED: ['ok', 'Completed'],
}
export function PlansTable({ rows, onOpen }: { rows: PlanSummary[]; onOpen: (p: PlanSummary) => void }) {
  return (
    <DataTable label="Aggregation plans" rows={rows} rowKey={(p) => p.id} onRowClick={onOpen} initialSort={{ key: 'd', dir: -1 }}
      filters={[{ key: 's', label: 'Status', options: Object.entries(PLAN_STATUS).map(([value, [, label]]) => ({ value, label })), get: (p) => p.status }]}
      empty={{ title: 'No aggregation plans' }}
      columns={[
        { key: 'c', header: 'Plan', cell: (p) => <span className="font-mono text-xs">{p.plan_code}</span>, sortValue: (p) => p.plan_code },
        { key: 'd', header: 'Created', cell: (p) => <span className="text-xs">{date(p.created_at)}</span>, sortValue: (p) => p.created_at },
        { key: 't', header: 'Target kg', numeric: true, cell: (p) => num1(p.target_kg), sortValue: (p) => p.target_kg },
        { key: 'e', header: 'Listed kg', numeric: true, cell: (p) => num1(p.est_total_kg) },
        { key: 'u', header: 'Expected usable', numeric: true, cell: (p) => num1(p.est_usable_kg) },
        { key: 's', header: 'Status', cell: (p) => <SimpleStatus status={p.status} map={PLAN_STATUS} />, sortValue: (p) => p.status },
      ]} />
  )
}
export function CollectorPlans() {
  const plans = usePlans()
  const [open, setOpen] = React.useState<PlanSummary | null>(null)
  return (
    <>
      <PageHeader title="Aggregation plans" description="Recyclers group small listings into one feedstock order. A plan becomes active once both the recycler and a collector accept it." />
      <Note className="mb-4">Plans do not name a collector in the backend, so every plan is visible here (audit §3).</Note>
      <Panel flush><QueryState query={plans}>{(P) => <PlansTable rows={P} onOpen={setOpen} />}</QueryState></Panel>
      <Drawer open={!!open} onOpenChange={(o) => !o && setOpen(null)} title={open ? `Plan ${open.plan_code}` : ''}>{open && <PlanDetailView id={open.id} canAct />}</Drawer>
    </>
  )
}

/* ─────────────── Delivery records ─────────────── */
export function CollectorDeliveries() {
  const { query, mine } = useMyBatches()
  const delivered = mine.filter((b) => q(b.quantities.received_kg) != null)
  return (
    <>
      <PageHeader title="Delivery records" description="What recyclers recorded for each batch you delivered. Differences above 2% between collected and received weight are highlighted." />
      <Panel flush footer={<SourceLine source="ReLoop API · /batches (receipt quantities)" />}>
        <QueryState query={query}>{() => (
          <DataTable label="Delivery records" rows={delivered} rowKey={(b) => b.id} empty={{ title: 'No deliveries recorded yet' }}
            columns={[
              { key: 'c', header: 'Batch', cell: (b) => <BatchLink code={b.batch_code} />, sortValue: (b) => b.batch_code },
              { key: 'r', header: 'Recycler', cell: (b) => b.destination_recycler_name ?? '—' },
              { key: 'col', header: 'Collected', numeric: true, cell: (b) => num1(q(b.quantities.collected_kg)) },
              { key: 'rec', header: 'Received', numeric: true, cell: (b) => num1(q(b.quantities.received_kg)) },
              { key: 'v', header: 'Transit variance', numeric: true, sortValue: (b) => Math.abs((q(b.quantities.received_kg)! - q(b.quantities.collected_kg)!) / q(b.quantities.collected_kg)!),
                cell: (b) => { const c = q(b.quantities.collected_kg)!, r = q(b.quantities.received_kg)!; const v = ((r - c) / c) * 100; return <span className={Math.abs(v) > 2 ? 'font-semibold text-bad' : ''}>{v >= 0 ? '+' : ''}{pct(v)}</span> } },
              { key: 'a', header: 'Accepted', numeric: true, cell: (b) => num1(q(b.quantities.accepted_kg)) },
              { key: 'x', header: 'Rejected', numeric: true, cell: (b) => num1(q(b.quantities.rejected_kg)) },
              { key: 's', header: 'Status', cell: (b) => <BatchStatusBadge status={b.status} /> },
            ]} />
        )}</QueryState>
      </Panel>
    </>
  )
}

/* ─────────────── Payments & earnings ─────────────── */
export function CollectorTransactions() {
  const payments = usePayments()
  const [paying, setPaying] = React.useState<string | null>(null)
  const [ref, setRef] = React.useState('')
  const m = useApiMutation(() => markPaid(paying!, ref.trim()), { invalidate: [K.payments], success: 'Payment marked as paid', onSuccess: () => { setPaying(null); setRef('') } })
  return (
    <>
      <PageHeader title="Payments & earnings" description="Generator payouts you owe for confirmed handovers. Mark a payout as paid once you have transferred it." />
      <Note tone="warn" className="mb-4">The backend records generator payouts only. Collector earnings from recyclers are not modelled yet, so no earnings figures are shown.</Note>
      <QueryState query={payments}>{(P) => (
        <div className="flex flex-col gap-4">
          <div className="grid grid-cols-2 gap-3 lg:grid-cols-3">
            <Kpi label="Owed to generators" value={inr(P.filter((p) => p.status === 'PENDING').reduce((s, p) => s + p.amount, 0))} sub={`${P.filter((p) => p.status === 'PENDING').length} pending`} />
            <Kpi label="Paid to generators" value={inr(P.filter((p) => p.status === 'PAID').reduce((s, p) => s + p.amount, 0))} />
          </div>
          <Panel flush footer={<SourceLine source="ReLoop API · /payments (simulated ledger; no money moves)" />}>
            <PaymentsTable rows={P} perspective="payer" />
          </Panel>
          {P.some((p) => p.status === 'PENDING') && (
            <Panel title="Settle a payout">
              <div className="flex flex-wrap items-end gap-3">
                <Field label="Payout" htmlFor="pay-id"><Select id="pay-id" value={paying ?? ''} onChange={(e) => setPaying(e.target.value || null)}>
                  <option value="">Select pending payout</option>{P.filter((p) => p.status === 'PENDING').map((p) => <option key={p.id} value={p.id}>{inr(p.amount)} · {num1(p.quantity_kg)} kg · {date(p.created_at)}</option>)}
                </Select></Field>
                <Field label="Transfer reference (UPI / bank)" htmlFor="pay-ref"><Input id="pay-ref" value={ref} onChange={(e) => setRef(e.target.value)} placeholder="UPI ref no." /></Field>
                <Button disabled={!paying || ref.trim().length < 4} loading={m.isPending} onClick={() => m.mutate(undefined)}>Mark as paid</Button>
              </div>
            </Panel>
          )}
        </div>
      )}</QueryState>
    </>
  )
}

/* ─────────────── Performance ─────────────── */
export function CollectorPerformance() {
  const { me } = useAuth()
  const perf = usePerformance(me?.active_org?.id)
  const fmt = (v: number | null) => (v == null ? '—' : pct(v <= 1 ? v * 100 : v))
  return (
    <>
      <PageHeader title="Performance" description="Rule-based indicators recyclers see when they review your work. Each is shown with the number of transactions behind it." />
      <QueryState query={perf}>{(p) => (
        <div className="flex flex-col gap-4">
          <div className="flex items-center gap-2"><Badge tone={p.history_level === 'SUFFICIENT' ? 'ok' : p.history_level === 'LIMITED' ? 'warn' : 'neutral'}>{humanize(p.history_level)} history</Badge><span className="text-sm text-fg-2">n = {p.n_transactions}</span></div>
          {p.n_transactions === 0 ? <Panel><EmptyState title="Not enough history" body="Indicators appear once the backend has computed metrics for your organisation." /></Panel> : (
            <div className="grid grid-cols-2 gap-3 lg:grid-cols-3">
              <Kpi label="Fulfilment" value={fmt(p.fulfilment_rate)} /><Kpi label="On-time pickup" value={fmt(p.on_time_rate)} /><Kpi label="Weight discrepancy" value={fmt(p.weight_discrepancy_pct)} />
              <Kpi label="Rejection at receipt" value={fmt(p.rejection_rate)} /><Kpi label="Contamination" value={fmt(p.contamination_rate)} /><Kpi label="Completion" value={fmt(p.completion_rate)} />
            </div>
          )}
          <SourceLine source="ReLoop API · /suppliers/{org}/performance" />
        </div>
      )}</QueryState>
    </>
  )
}
