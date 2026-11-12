import type { MeResponse, OrgType } from '@/types/api'

export type AppRole = 'generator' | 'collector' | 'recycler' | 'ngo' | 'epr' | 'admin'
export const ROLE_LABEL: Record<AppRole, string> = {
  generator: 'Generator', collector: 'Collector', recycler: 'Recycler', ngo: 'NGO verification', epr: 'EPR company', admin: 'Platform admin',
}
const BY_ORG_TYPE: Record<OrgType, AppRole> = { GENERATOR: 'generator', COLLECTOR: 'collector', RECYCLER: 'recycler', NGO: 'ngo', EPR_CLIENT: 'epr' }

/** Admin is a user flag (is_platform_admin), not an org type; it takes precedence. */
export function roleOf(me: Pick<MeResponse, 'user' | 'active_org'>): AppRole | null {
  if (me.user.is_platform_admin) return 'admin'
  return me.active_org ? BY_ORG_TYPE[me.active_org.org_type] ?? null : null
}
export const MOBILE_FIRST: AppRole[] = ['generator', 'collector', 'recycler']
