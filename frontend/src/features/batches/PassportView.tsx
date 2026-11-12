import { Link } from 'react-router-dom'
import { useBatch, useEvents, usePassport, useTrace } from '@/hooks/queries'
import { useAuth } from '@/app/auth'
import { QueryState, ErrorState, LoadingRows } from '@/components/states'
import { Panel, KV } from '@/components/ui/panel'
import { Badge, Tag } from '@/components/ui/badge'
import { Note } from '@/components/ui/note'
import { Tabs, TabsContent, TabsList } from '@/components/ui/tabs'
import { BatchStatusBadge, NgoBadge } from '@/components/status'
import { QuantityLadder } from './QuantityLadder'
import { BatchQr } from './Qr'
import { EventTimeline } from './Timeline'
import { CATEGORY_LABEL, date, dateTime, humanize, inr, kg, num1, pct } from '@/lib/format'

/** The material passport: everything the backend holds about one batch, read-only. */
export function PassportView({ code }: { code: string }) {
  const { role } = useAuth()
  const passport = usePassport(code)
  const batch = useBatch(code)
  const id = batch.data?.id
  const trace = useTrace(id)
  const events = useEvents(id)

  if (passport.isPending || batch.isPending) return <LoadingRows rows={8} />
  if (passport.isError) return <ErrorState error={passport.error} onRetry={() => passport.refetch()} />
  if (batch.isError) return <ErrorState error={batch.error} onRetry={() => batch.refetch()} />
  const p = passport.data
  const b = batch.data
  const currentPickup = p.custody.pickup_records.find((x) => x.is_current)
  const currentVerification = p.verifications.find((v) => v.is_current)
  const isEpr = role === 'epr'

  return (
    <div className="flex flex-col gap-4">
      <div className="flex flex-wrap items-start gap-4">
        <BatchQr batchId={b.id} code={p.batch_code} />
        <div className="min-w-0 flex-1">
          <div className="break-all font-mono text-[15px] font-semibold">{p.batch_code}</div>
          <div className="mb-2 mt-0.5 text-[13px] text-fg-2">
            {p.material.name ?? p.material.code}{p.material.resin_code ? ` (RIC ${p.material.resin_code})` : ''} · {isEpr ? `${humanize(p.generator.generator_type)} generator, ${p.generator.locality ?? p.generator.city_id}` : `${p.generator.legal_name ?? '—'} · ${p.generator.locality ?? ''}`}
          </div>
          <div className="flex flex-wrap gap-1.5">
            <BatchStatusBadge status={p.status} />
            {currentVerification && <NgoBadge decision={currentVerification.decision} />}
            {p.custody.consignment && <Tag>{p.custody.consignment.consignment_code}</Tag>}
            {p.custody.processing_runs.map((r) => <Tag key={r.record_code}>{r.record_code}</Tag>)}
          </div>
          <p className="mt-2 text-[11.5px] text-fg-3">Read-only record from the ReLoop API. Not a statutory document.</p>
        </div>
      </div>

      <QuantityLadder quantities={p.quantities} trace={trace.data} decision={currentVerification?.decision} pickupConfirmed={currentPickup ? !!currentPickup.confirmed_at : undefined} />

      <Tabs defaultValue="custody">
        <TabsList items={[
          { value: 'custody', label: 'Custody records' }, { value: 'timeline', label: 'Event timeline' },
          { value: 'verification', label: 'NGO verification' }, { value: 'epr', label: 'EPR & certificates' }, { value: 'evidence', label: 'Evidence & flags' },
        ]} />
        <TabsContent value="custody" className="grid gap-4 xl:grid-cols-2">
          <Panel title="Parties">
            <KV rows={[
              ['Generator', isEpr ? `${humanize(p.generator.generator_type)} (identity withheld)` : (p.generator.legal_name ?? '—')],
              ['Pickup locality', p.generator.locality ?? '—'],
              ['Collector', b.assigned_collector_name ?? '—'],
              ['Recycler', b.destination_recycler_name ?? '—'],
              ['Listed', dateTime(b.created_at)],
            ]} />
          </Panel>
          <Panel title="Pickup" sub="Collected quantity is weighed by the collector and confirmed by the generator">
            {p.custody.pickup_records.length ? p.custody.pickup_records.map((r) => (
              <KV key={r.version} rows={[
                [`Version ${r.version}`, r.is_current ? <Badge tone="ok">Current</Badge> : <Badge>Superseded</Badge>],
                ['Collected', kg(r.collected_kg)], ['Generator rate', `${inr(r.rate)}/kg`], ['Handover method', r.handover_method],
                ['Generator confirmed', r.confirmed_at ? dateTime(r.confirmed_at) : <span className="text-warn">Not yet</span>],
              ]} />
            )) : <p className="text-sm text-fg-3">Not collected yet.</p>}
          </Panel>
          <Panel title="Transport">
            {p.custody.consignment
              ? <KV rows={[['Consignment', p.custody.consignment.consignment_code], ['Vehicle', p.custody.consignment.vehicle_no ?? '—'], ['Status', humanize(p.custody.consignment.status)]]} />
              : <p className="text-sm text-fg-3">No consignment recorded.</p>}
          </Panel>
          <Panel title="Recycler receipt" sub="Corrections add versions; earlier versions stay visible" flush>
            {p.custody.receipts.length ? (
              <table className="w-full text-[13px]"><thead><tr className="text-left text-xs text-fg-2 [&>th]:border-b [&>th]:border-line [&>th]:bg-surface-2 [&>th]:px-3 [&>th]:py-2">
                <th>Version</th><th className="text-right">Received</th><th className="text-right">Accepted</th><th className="text-right">Rejected</th><th>Grade</th><th>Recorded</th></tr></thead>
                <tbody>{p.custody.receipts.map((r) => (
                  <tr key={r.version} className="[&>td]:border-b [&>td]:border-line [&>td]:px-3 [&>td]:py-2">
                    <td>v{r.version} {r.is_current ? <Badge tone="ok">Current</Badge> : <Badge>Superseded</Badge>}</td>
                    <td className="tnum text-right">{num1(r.received_kg)}</td><td className="tnum text-right">{num1(r.accepted_kg)}</td><td className="tnum text-right">{num1(r.rejected_kg)}</td>
                    <td>{r.quality_grade} · {pct(r.contamination_pct)}</td><td className="text-xs">{dateTime(r.received_at)}</td>
                  </tr>))}</tbody></table>
            ) : <p className="p-4 text-sm text-fg-3">Not received yet.</p>}
          </Panel>
          <Panel title="Processing" sub="This batch's share of each run; source batches stay individually traceable" flush className="xl:col-span-2">
            {p.custody.processing_runs.length ? (
              <table className="w-full text-[13px]"><thead><tr className="text-left text-xs text-fg-2 [&>th]:border-b [&>th]:border-line [&>th]:bg-surface-2 [&>th]:px-3 [&>th]:py-2">
                <th>Run</th><th>Started</th><th className="text-right">Input from this batch</th><th className="text-right">Recovered output share</th><th className="text-right">Run yield</th><th>Output form</th><th>Measurement</th></tr></thead>
                <tbody>{p.custody.processing_runs.map((r) => (
                  <tr key={r.record_code} className="[&>td]:border-b [&>td]:border-line [&>td]:px-3 [&>td]:py-2">
                    <td className="font-mono">{r.record_code}</td><td className="text-xs">{dateTime(r.run_started_at)}</td>
                    <td className="tnum text-right">{kg(r.input_kg)}</td><td className="tnum text-right">{kg(r.apportioned_output_kg)}</td>
                    <td className="tnum text-right">{pct(r.run_yield_pct)}</td><td>{r.output_form ?? '—'}</td><td>{r.measurement_status === 'COMPLETE' ? <Badge tone="ok">Complete</Badge> : <Badge tone="warn">{humanize(r.measurement_status)}</Badge>}</td>
                  </tr>))}</tbody></table>
            ) : <p className="p-4 text-sm text-fg-3">Not processed yet.</p>}
          </Panel>
        </TabsContent>

        <TabsContent value="timeline">
          <Panel title="Event timeline" sub="Append-only batch events">
            <QueryState query={events}>{(ev) => <EventTimeline events={ev} />}</QueryState>
          </Panel>
        </TabsContent>

        <TabsContent value="verification">
          <Panel title="NGO decision history" sub="Each decision adds a record; earlier decisions remain">
            <Note className="mb-3">NGO verification is an independent, non-statutory review of the evidence on ReLoop. It is not EPR certification and does not make material EPR-eligible.</Note>
            {p.verifications.length ? (
              <ol className="flex flex-col gap-2">
                {p.verifications.map((v, i) => (
                  <li key={i} className="flex flex-wrap items-start justify-between gap-2 rounded-md border border-line px-3 py-2">
                    <div className="min-w-0"><div className="flex items-center gap-2"><NgoBadge decision={v.decision} />{v.is_current && <Tag>Current</Tag>}</div>
                      <p className="mt-1 text-xs text-fg-2">{v.ngo_name ?? '—'}{v.comments ? ` · ${v.comments}` : ''}</p></div>
                    <span className="text-xs text-fg-3">{dateTime(v.created_at)}</span>
                  </li>))}
              </ol>
            ) : <p className="text-sm text-fg-3">No NGO review yet. Batches enter review when a recycler records their processing run.</p>}
          </Panel>
        </TabsContent>

        <TabsContent value="epr" className="grid gap-4 xl:grid-cols-2">
          <Panel title="EPR allocations" sub={isEpr ? 'Only your organisation’s allocations are shown' : 'Contractual attributions recorded by the recycler'} flush>
            {p.epr_allocations.length ? (
              <table className="w-full text-[13px]"><thead><tr className="text-left text-xs text-fg-2 [&>th]:border-b [&>th]:border-line [&>th]:bg-surface-2 [&>th]:px-3 [&>th]:py-2">
                <th>Period</th><th>Category</th><th className="text-right">Run allocation</th><th>Status</th><th>Recorded</th></tr></thead>
                <tbody>{p.epr_allocations.map((a) => (
                  <tr key={a.allocation_id} className="[&>td]:border-b [&>td]:border-line [&>td]:px-3 [&>td]:py-2">
                    <td>{a.reporting_period}</td><td>{CATEGORY_LABEL[a.packaging_category] ?? a.packaging_category}</td><td className="tnum text-right">{kg(a.quantity_kg)}</td>
                    <td>{a.is_reversal ? <Badge tone="warn">Reversal entry</Badge> : a.status === 'ACTIVE' ? <Badge tone="ok">Active</Badge> : <Badge>{humanize(a.status)}</Badge>}</td><td className="text-xs">{date(a.created_at)}</td>
                  </tr>))}</tbody></table>
            ) : <p className="p-4 text-sm text-fg-3">No allocations on this batch’s runs.</p>}
            <p className="border-t border-line px-4 py-2 text-xs text-fg-3">Run-level quantities. This batch’s pro rata share is shown as “Allocated to EPR clients” above.</p>
          </Panel>
          <Panel title="Certificate references" sub="Entered by the recycler; generated on the CPCB portal, not by ReLoop">
            {p.statutory_certificates.length ? p.statutory_certificates.map((c) => (
              <KV key={c.certificate_ref} rows={[['Reference', <span className="font-mono">{c.certificate_ref}</span>], ['Category', CATEGORY_LABEL[c.packaging_category] ?? c.packaging_category], ['Quantity', kg(c.certificate_kg)], ['Issued', c.issued_on ?? '—'], ['Status on ReLoop', humanize(c.status)]]} />
            )) : <p className="text-sm text-fg-3">No certificate references recorded.</p>}
          </Panel>
        </TabsContent>

        <TabsContent value="evidence" className="grid gap-4 xl:grid-cols-2">
          <Panel title="Documents" sub="Metadata and SHA-256 as recorded by the backend">
            {p.documents.length ? (
              <ul className="flex flex-col gap-2 text-[13px]">{p.documents.map((d, i) => (
                <li key={i} className="rounded-md border border-line px-3 py-2"><b>{humanize(d.doc_type)}</b> · {d.mime_type ?? '—'} · {dateTime(d.created_at)}<div className="break-all font-mono text-[11px] text-fg-3">sha256 {d.sha256 ?? 'not recorded'}</div></li>))}</ul>
            ) : <p className="text-sm text-fg-3">No documents linked to this batch.</p>}
            <Note className="mt-3">The backend stores document metadata only; file storage is not connected yet.</Note>
          </Panel>
          <Panel title="Anomaly flags">
            {p.anomalies.length ? (
              <ul className="flex flex-col gap-2 text-[13px]">{p.anomalies.map((a, i) => (
                <li key={i} className="flex items-center justify-between gap-2 rounded-md border border-line px-3 py-2">
                  <span>{humanize(a.rule_code)} <Badge tone={a.severity === 'HIGH' ? 'bad' : 'warn'}>{a.severity}</Badge></span>
                  <span className="text-xs">{a.status === 'OPEN' ? <Badge tone="bad">Open</Badge> : <Badge tone="ok">{humanize(a.status)}</Badge>}</span>
                </li>))}</ul>
            ) : <p className="text-sm text-fg-3">No anomalies raised for this batch.</p>}
          </Panel>
        </TabsContent>
      </Tabs>
    </div>
  )
}

export function BatchLink({ code, className }: { code: string; className?: string }) {
  return <Link to={`/passport/${encodeURIComponent(code)}`} title={code} onClick={(e) => e.stopPropagation()} className={className ?? 'font-mono text-[12.5px] text-fg hover:text-accent hover:underline'}>{code.startsWith('RL-') ? `…${code.slice(-6)}` : code}</Link>
}
