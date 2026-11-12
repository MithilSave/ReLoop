import * as React from 'react'
import { Navigate, useLocation, useNavigate } from 'react-router-dom'
import { useForm } from 'react-hook-form'
import { zodResolver } from '@hookform/resolvers/zod'
import { z } from 'zod'
import { Recycle } from 'lucide-react'
import { useAuth } from '@/app/auth'
import { BASE } from '@/app/nav'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Field } from '@/components/ui/field'
import { Note } from '@/components/ui/note'
import { ApiError, describeError } from '@/api/errors'
import { SHOW_DEMO_ACCOUNTS, API_ORIGIN } from '@/api/config'

const schema = z.object({
  login: z.string().trim().min(3, 'Enter your email or phone number'),
  password: z.string().min(1, 'Enter your password'),
})
type Form = z.infer<typeof schema>

// Seeded accounts from backend/seed_data.py. Shown only when VITE_SHOW_DEMO_ACCOUNTS=true (local development).
const DEMO = [
  ['generator@reloop.in', 'Generator', 'Godrej Green Towers Housing Society'],
  ['collector@reloop.in', 'Collector', 'Dharavi Waste Collectors Welfare Society'],
  ['recycler@reloop.in', 'Recycler', 'Ecoplas Circular Solutions Ltd'],
  ['ngo@reloop.in', 'NGO auditor', 'Green Ledger Foundation India'],
  ['epr@reloop.in', 'EPR brand', 'Hindustan Consumer Goods Ltd'],
  ['admin@reloop.in', 'Platform admin', 'ReLoop Platform Governance'],
] as const

export function LoginPage() {
  const { status, role, notice, signIn } = useAuth()
  const nav = useNavigate()
  const loc = useLocation() as { state?: { from?: string } }
  const [error, setError] = React.useState<ApiError | null>(null)
  const form = useForm<Form>({ resolver: zodResolver(schema), defaultValues: { login: '', password: '' } })

  if (status === 'authenticated' && role) return <Navigate to={loc.state?.from && loc.state.from !== '/login' ? loc.state.from : BASE[role]} replace />

  const onSubmit = form.handleSubmit(async (v) => {
    setError(null)
    try {
      const r = await signIn(v.login, v.password)
      nav(r ? (loc.state?.from ?? BASE[r]) : '/', { replace: true })
    } catch (e) {
      setError(e as ApiError)
    }
  })
  const err = error ? (error.status === 401 ? { title: 'Sign-in failed', body: 'The email/phone or password is incorrect.' } : describeError(error)) : null

  return (
    <div className="grid min-h-full place-items-center bg-bg px-4 py-10">
      <div className="w-full max-w-[400px]">
        <div className="mb-6 flex items-center gap-2.5">
          <span className="grid size-9 place-items-center rounded-lg bg-brand text-brand-fg"><Recycle className="size-5" /></span>
          <div><b className="text-lg font-semibold">ReLoop</b><p className="text-xs text-fg-3">Plastic traceability, procurement and EPR records</p></div>
        </div>
        <form onSubmit={onSubmit} noValidate className="rounded-xl border border-line bg-surface p-6">
          <h1 className="mb-4 text-base font-semibold">Sign in</h1>
          <div className="flex flex-col gap-4">
            {notice && !err && <Note>{notice}</Note>}
            {err && <Note tone="bad" title={err.title}>{err.body}</Note>}
            <Field label="Email or phone" htmlFor="login" error={form.formState.errors.login?.message}>
              <Input id="login" autoComplete="username" autoFocus {...form.register('login')} aria-invalid={!!form.formState.errors.login} />
            </Field>
            <Field label="Password" htmlFor="password" error={form.formState.errors.password?.message}>
              <Input id="password" type="password" autoComplete="current-password" {...form.register('password')} aria-invalid={!!form.formState.errors.password} />
            </Field>
            <Button type="submit" size="lg" loading={form.formState.isSubmitting}>Sign in</Button>
          </div>
        </form>
        {SHOW_DEMO_ACCOUNTS && (
          <div className="mt-5 rounded-xl border border-dashed border-line-2 p-4">
            <p className="mb-2 text-xs font-medium text-fg-2">Local demo accounts (seed data, password <span className="font-mono">reloop123</span>)</p>
            <div className="flex flex-col gap-1">
              {DEMO.map(([email, label, org]) => (
                <button key={email} type="button" onClick={() => { form.setValue('login', email); form.setValue('password', 'reloop123') }}
                  className="flex items-baseline justify-between gap-3 rounded-md px-2 py-1.5 text-left text-[12.5px] hover:bg-surface-2">
                  <span><b className="font-medium">{label}</b> <span className="text-fg-3">· {org}</span></span><span className="font-mono text-[11px] text-fg-3">{email}</span>
                </button>
              ))}
            </div>
          </div>
        )}
        <p className="mt-4 text-center text-[11px] text-fg-3">API: {API_ORIGIN}</p>
      </div>
    </div>
  )
}
