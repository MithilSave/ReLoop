import * as React from 'react'
import { useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { AlertTriangle, Building2, Package } from 'lucide-react'
import { useAdminOrgs, useAnomalies, useBatches, useImpact } from '@/hooks/queries'
import { useApiMutation } from '@/hooks/useApiMutation'
import { approveOrg } from '@/services/shared'
import { PageHeader, SourceLine } from '@/components/page'
import { Panel, Kpi, KV } from '@/components/ui/panel'
import { Button } from '@/components/ui/button'
import { Input, Select, Textarea } from '@/components/ui/input'
import { Field } from '@/components/ui/field'
import { Note } from '@/components/ui/note'
import { Badge } from '@/components/ui/badge'
import { Dialog, DialogContent } from '@/components/ui/dialog'
import { DataTable } from '@/components/ui/data-table'
import { QueryState } from '@/components/states'
import { AnomalyTable, AuditTable } from '@/pages/ngo/NgoPages'
import { humanize, kg } from '@/lib/format'
import type { DirectoryOrg } from '@/types/api'

export function AdminOverview() {
  const impact = useImpact()
  const pending = useAdminOrgs('PENDING')
  const anomalies = useAnomalies()
  const nav = useNavigate()
  return (
    <>
      <PageHeader title="Platform overview" description="Platform-wide totals, organisations awaiting approval and open alerts." />
      <Note className="mb-4">Admin capabilities are limited to what the backend supports: organisation approval, anomaly review and the audit trail. User management is not available.</Note>
      <div className="flex flex-col gap-4">
        <div className="grid grid-cols-2 gap-3 lg:grid-cols-4">
          <Kpi icon={<Building2 />} label="Organisations awaiting approval" value={pending.isPending ? '…' : pending.data?.length ?? '—'} />
          <Kpi icon={<AlertTriangle />} label="Open anomaly flags" value={anomalies.isPending ? '…' : (anomalies.data ?? []).filter((a) => a.status === 'OPEN').length} />
          <Kpi icon={<Package />} label="Batches on platform" value={impact.data?.total_batches ?? '…'} />
          <Kpi label="NGO-verified batches" value={impact.data?.stages.verified_batches_count ?? '…'} />
        </div>
        <Panel title="Quantities across the platform" footer={<SourceLine source="ReLoop API · /impact/summary" />}>
          <QueryState query={impact}>{(i) => (
            <div className="grid gap-6 md:grid-cols-2">
              <KV rows={[['Collected', kg(i.stages.collected_kg)], ['Received', kg(i.stages.received_kg)], ['Accepted', kg(i.stages.accepted_kg)], ['Recovered output', kg(i.stages.processed_output_kg)], ['Allocated to EPR clients', kg(i.stages.epr_allocated_kg)]]} />
              <div><KV rows={[['CO₂ avoided (backend estimate)', kg(i.environmental_impact.co2_avoided_kg)], ['Landfill diverted (accepted kg)', kg(i.environmental_impact.landfill_diverted_kg)]]} />
                <p className="mt-2 text-[11.5px] text-fg-3">Environmental figures use fixed multipliers in the backend and are not measured values.</p></div>
            </div>
          )}</QueryState>
        </Panel>
        {pending.data && pending.data.length > 0 && <Note tone="warn">{pending.data.length} organisation(s) cannot operate until approved. <button className="font-medium underline" onClick={() => nav('/a/organisations')}>Review approvals</button></Note>}
      </div>
    </>
  )
}

export function AdminOrganisations() {
  const [status, setStatus] = React.useState('PENDING')
  const orgs = useAdminOrgs(status || undefined)
  const [acting, setActing] = React.useState<DirectoryOrg | null>(null)
  const form = useForm<{ decision: string; note: string }>({ defaultValues: { decision: 'APPROVED', note: '' } })
  const m = useApiMutation((v: { decision: string; note: string }) => approveOrg(acting!.id, v.decision, v.note || undefined), { invalidate: [['admin'], ['orgs']], success: (d) => `Organisation ${humanize(d.approval_status).toLowerCase()}`, onSuccess: () => setActing(null) })
  return (
    <>
      <PageHeader title="Organisation approvals" description="Collectors, recyclers, NGOs and EPR companies must be approved before they can act. Generators are approved automatically."
        actions={<Select aria-label="Approval status" value={status} onChange={(e) => setStatus(e.target.value)} className="w-40"><option value="PENDING">Pending</option><option value="APPROVED">Approved</option><option value="REJECTED">Rejected</option><option value="SUSPENDED">Suspended</option><option value="">All</option></Select>} />
      <Panel flush footer={<SourceLine source="ReLoop API · /admin/orgs (integration patch #1)" />}>
        <QueryState query={orgs}>{(O) => (
          <DataTable label="Organisations" rows={O} rowKey={(o) => o.id} search={(o) => o.legal_name} searchPlaceholder="Search organisation"
            filters={[{ key: 't', label: 'Type', options: ['GENERATOR', 'COLLECTOR', 'RECYCLER', 'NGO', 'EPR_CLIENT'].map((t) => ({ value: t, label: humanize(t) })), get: (o) => o.org_type }]}
            empty={{ title: status === 'PENDING' ? 'No organisations awaiting approval' : 'No organisations' }}
            columns={[
              { key: 'n', header: 'Organisation', cell: (o) => <span><b className="font-medium">{o.legal_name}</b><span className="block text-xs text-fg-3">{o.address}</span></span>, sortValue: (o) => o.legal_name },
              { key: 't', header: 'Type', cell: (o) => humanize(o.org_type) },
              { key: 'r', header: 'Registration', cell: (o) => <span className="font-mono text-xs">{Object.values(o.registration ?? {}).filter(Boolean).slice(0, 2).join(' · ') || '—'}</span> },
              { key: 'g', header: 'GSTIN', cell: (o) => <span className="font-mono text-xs">{o.gstin ?? '—'}</span> },
              { key: 's', header: 'Status', cell: (o) => <Badge tone={o.approval_status === 'APPROVED' ? 'ok' : o.approval_status === 'PENDING' ? 'warn' : 'bad'}>{humanize(o.approval_status)}</Badge> },
              { key: 'x', header: '', cell: (o) => <Button size="sm" variant="outline" onClick={() => { setActing(o); form.reset({ decision: o.approval_status === 'APPROVED' ? 'SUSPENDED' : 'APPROVED', note: '' }) }}>Change status</Button> },
            ]} />
        )}</QueryState>
      </Panel>
      <Dialog open={!!acting} onOpenChange={(o) => !o && setActing(null)}>
        {acting && <DialogContent title={`Change status · ${acting.legal_name}`} description={`${humanize(acting.org_type)} · currently ${humanize(acting.approval_status)}`}
          footer={<><Button variant="outline" onClick={() => setActing(null)}>Cancel</Button><Button loading={m.isPending} onClick={form.handleSubmit((v) => m.mutate(v))}>Save</Button></>}>
          <Field label="New status" htmlFor="ap-d"><Select id="ap-d" {...form.register('decision')}><option value="APPROVED">Approve</option><option value="REJECTED">Reject</option><option value="SUSPENDED">Suspend</option></Select></Field>
          <Field label="Note" htmlFor="ap-n" hint="The backend does not store this note yet."><Textarea id="ap-n" rows={2} {...form.register('note')} /></Field>
          {m.error && <Note tone="bad">{m.error.message}</Note>}
        </DialogContent>}
      </Dialog>
    </>
  )
}

export function AdminAnomalies() {
  const anomalies = useAnomalies()
  const batches = useBatches()
  const code = (id: string | null) => batches.data?.find((b) => b.id === id)?.batch_code
  return (
    <>
      <PageHeader title="Anomaly alerts" description="All anomaly flags on the platform." />
      <Panel flush footer={<SourceLine source="ReLoop API · /anomalies" />}><QueryState query={anomalies}>{(A) => <AnomalyTable rows={A} canResolve batchCode={code} />}</QueryState></Panel>
    </>
  )
}

export function AdminAudit() {
  return (
    <>
      <PageHeader title="Audit trail" description="Hash-chained audit log written by the backend. The chain check compares each row’s previous hash with the row before it." />
      <Panel flush footer={<SourceLine source="ReLoop API · /audit/logs (last 100 rows)" />}><AuditTable /></Panel>
    </>
  )
}

export function AdminLookup() {
  const batches = useBatches()
  const nav = useNavigate()
  const [q, setQ] = React.useState('')
  return (
    <>
      <PageHeader title="Batch lookup" description="Open any batch’s material passport." />
      <form className="mb-4 flex gap-2" onSubmit={(e) => { e.preventDefault(); if (q.trim()) nav(`/passport/${encodeURIComponent(q.trim().toUpperCase())}`) }}>
        <Input aria-label="Batch code" value={q} onChange={(e) => setQ(e.target.value)} placeholder="RL-MUM-2026-000105" className="max-w-sm" /><Button type="submit">Open passport</Button>
      </form>
      <Panel flush>
        <QueryState query={batches}>{(B) => (
          <DataTable label="All batches" rows={B} rowKey={(b) => b.id} onRowClick={(b) => nav(`/passport/${b.batch_code}`)} search={(b) => `${b.batch_code} ${b.generator_name ?? ''}`}
            columns={[
              { key: 'c', header: 'Batch', cell: (b) => <span className="font-mono text-xs">{b.batch_code}</span>, sortValue: (b) => b.batch_code },
              { key: 'g', header: 'Generator', cell: (b) => b.generator_name ?? '—' },
              { key: 'm', header: 'Material', cell: (b) => b.material },
              { key: 's', header: 'Status', cell: (b) => humanize(b.status), sortValue: (b) => b.status },
            ]} />
        )}</QueryState>
      </Panel>
    </>
  )
}
