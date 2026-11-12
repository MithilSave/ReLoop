import * as React from 'react'
import { useQueryClient } from '@tanstack/react-query'
import { tokenStore } from '@/api/tokens'
import { SESSION_EXPIRED_EVENT } from '@/api/client'
import * as authApi from '@/services/auth'
import { roleOf, type AppRole } from '@/lib/roles'
import type { MeResponse } from '@/types/api'

type Status = 'loading' | 'anonymous' | 'authenticated'
interface AuthState {
  status: Status
  me: MeResponse | null
  role: AppRole | null
  /** Why the user is on the login screen, e.g. session expiry. */
  notice: string | null
  signIn: (login: string, password: string) => Promise<AppRole | null>
  signOut: () => Promise<void>
}
const Ctx = React.createContext<AuthState | null>(null)

export function AuthProvider({ children }: { children: React.ReactNode }) {
  const qc = useQueryClient()
  const [status, setStatus] = React.useState<Status>(tokenStore.access ? 'loading' : 'anonymous')
  const [me, setMe] = React.useState<MeResponse | null>(null)
  const [notice, setNotice] = React.useState<string | null>(null)

  const loadMe = React.useCallback(async () => {
    try {
      const m = await authApi.me()
      setMe(m)
      setStatus('authenticated')
      return m
    } catch {
      tokenStore.clear()
      setMe(null)
      setStatus('anonymous')
      return null
    }
  }, [])

  React.useEffect(() => { if (tokenStore.access) void loadMe() }, [loadMe])

  React.useEffect(() => {
    const onExpired = () => {
      qc.clear()
      setMe(null)
      setStatus('anonymous')
      setNotice('Your session has ended. Sign in again to continue.')
    }
    window.addEventListener(SESSION_EXPIRED_EVENT, onExpired)
    return () => window.removeEventListener(SESSION_EXPIRED_EVENT, onExpired)
  }, [qc])

  const signIn = React.useCallback(async (login: string, password: string) => {
    const res = await authApi.login(login, password)
    tokenStore.set(res.access_token, res.refresh_token)
    qc.clear()
    setNotice(null)
    const m = await loadMe()
    return m ? roleOf(m) : null
  }, [loadMe, qc])

  const signOut = React.useCallback(async () => {
    const rt = tokenStore.refresh
    try { if (rt) await authApi.logout(rt) } catch { /* token already invalid: nothing to revoke */ }
    tokenStore.clear()
    qc.clear()
    setMe(null)
    setStatus('anonymous')
    setNotice('You have signed out.')
  }, [qc])

  const value = React.useMemo<AuthState>(() => ({ status, me, role: me ? roleOf(me) : null, notice, signIn, signOut }), [status, me, notice, signIn, signOut])
  return <Ctx.Provider value={value}>{children}</Ctx.Provider>
}

export function useAuth() {
  const v = React.useContext(Ctx)
  if (!v) throw new Error('useAuth outside AuthProvider')
  return v
}
