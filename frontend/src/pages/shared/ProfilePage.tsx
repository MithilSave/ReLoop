import { useMyOrg } from '@/hooks/queries'
import { useAuth } from '@/app/auth'
import { PageHeader } from '@/components/page'
import { Panel, KV } from '@/components/ui/panel'
import { Badge } from '@/components/ui/badge'
import { QueryState } from '@/components/states'
import { humanize } from '@/lib/format'

export function ProfilePage() {
  const q = useMyOrg()
  const { me } = useAuth()
  return (
    <>
      <PageHeader title="Organisation profile" description="Registration details held by ReLoop for your organisation." />
      <QueryState query={q}>{(o) => (
        <div className="grid gap-4 lg:grid-cols-2">
          <Panel title={o.legal_name} sub={humanize(o.org_type)} actions={<Badge tone={o.approval_status === 'APPROVED' ? 'ok' : 'warn'}>{humanize(o.approval_status)}</Badge>}>
            <KV rows={[['Display name', o.display_name ?? '—'], ['City', o.city_id], ['Address', o.address], ['GSTIN', o.gstin ?? '—']]} />
          </Panel>
          <Panel title="Profile details" sub="Type-specific registration and capacity fields">
            {o.profile && Object.keys(o.profile).length ? <KV rows={Object.entries(o.profile).map(([k, v]) => [humanize(k), v == null ? '—' : String(v)])} /> : <p className="text-sm text-fg-3">No profile details recorded.</p>}
          </Panel>
          <Panel title="Your access">
            <KV rows={[['Name', me?.user.full_name ?? '—'], ['Email', me?.user.email ?? '—'], ['Role in organisation', me?.active_role ?? '—'],
              ['Memberships', me?.memberships.map((m) => m.org_name).join(', ') ?? '—']]} />
          </Panel>
        </div>
      )}</QueryState>
    </>
  )
}
