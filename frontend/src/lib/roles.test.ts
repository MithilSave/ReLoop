import { describe, expect, it } from 'vitest'
import { roleOf } from './roles'

const user = { id: '1', full_name: 'x', email: null, phone: null, is_platform_admin: false, status: 'ACTIVE' }
const org = (t: string) => ({ id: 'o', org_type: t, legal_name: 'L', display_name: null, city_id: 'MUM', address: '', lat: null, lng: null, gstin: null, approval_status: 'APPROVED' }) as never

describe('roleOf', () => {
  it('maps org types', () => {
    expect(roleOf({ user, active_org: org('EPR_CLIENT') })).toBe('epr')
    expect(roleOf({ user, active_org: org('NGO') })).toBe('ngo')
  })
  it('treats platform admin as admin even though the seeded admin org is NGO-typed', () => {
    expect(roleOf({ user: { ...user, is_platform_admin: true }, active_org: org('NGO') })).toBe('admin')
  })
})
