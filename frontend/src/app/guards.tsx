import { Navigate, Outlet, useLocation } from 'react-router-dom'
import { ShieldOff } from 'lucide-react'
import { useAuth } from './auth'
import { BASE } from './nav'
import { ROLE_LABEL, type AppRole } from '@/lib/roles'
import { LoadingRows } from '@/components/states'
import { Button } from '@/components/ui/button'
import { Link } from 'react-router-dom'

export function RequireAuth() {
  const { status } = useAuth()
  const loc = useLocation()
  if (status === 'loading') return <div className="mx-auto max-w-md pt-24"><LoadingRows rows={3} /></div>
  if (status === 'anonymous') return <Navigate to="/login" replace state={{ from: loc.pathname }} />
  return <Outlet />
}

/** Frontend visibility only; the backend still enforces every permission and returns 403 otherwise. */
export function RequireRole({ allow }: { allow: AppRole[] }) {
  const { role } = useAuth()
  if (!role || !allow.includes(role)) return <Unauthorised needs={allow} />
  return <Outlet />
}

export function Unauthorised({ needs }: { needs?: AppRole[] }) {
  const { role } = useAuth()
  return (
    <div className="mx-auto flex max-w-md flex-col items-center py-20 text-center">
      <ShieldOff className="mb-3 size-7 text-bad" />
      <h1 className="text-lg font-semibold">This area is not available to your organisation</h1>
      <p className="mt-1 text-sm text-fg-2">{needs ? `It is for ${needs.map((r) => ROLE_LABEL[r]).join(' or ')} accounts. ` : ''}You are signed in as {role ? ROLE_LABEL[role] : 'an account without a role'}.</p>
      {role && <Button asChild className="mt-4"><Link to={BASE[role]}>Go to my workspace</Link></Button>}
    </div>
  )
}

export function HomeRedirect() {
  const { role } = useAuth()
  return role ? <Navigate to={BASE[role]} replace /> : <Unauthorised />
}
