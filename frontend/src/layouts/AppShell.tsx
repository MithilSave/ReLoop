import * as React from 'react'
import { NavLink, Outlet, useLocation, useNavigate } from 'react-router-dom'
import * as DD from '@radix-ui/react-dropdown-menu'
import * as D from '@radix-ui/react-dialog'
import { useQuery } from '@tanstack/react-query'
import { LogOut, Menu, MoreHorizontal, Recycle, Search, WifiOff, X, Building2 } from 'lucide-react'
import { useAuth } from '@/app/auth'
import { NAV, BASE, type NavItem } from '@/app/nav'
import { MOBILE_FIRST, ROLE_LABEL } from '@/lib/roles'
import { health } from '@/services/reference'
import { cn } from '@/lib/utils'

function SideNav({ onNavigate }: { onNavigate?: () => void }) {
  const { role } = useAuth()
  if (!role) return null
  return (
    <nav aria-label="Workspace" className="flex-1 overflow-y-auto px-2 pb-4 pt-2">
      {NAV[role].map((g) => (
        <div key={g.label}>
          <div className="px-2.5 pb-1.5 pt-3.5 text-[10.5px] uppercase tracking-[.08em] text-side-fg opacity-60">{g.label}</div>
          {g.items.map((it) => (
            <NavLink key={it.to} to={it.to} end={it.to === BASE[role]} onClick={onNavigate}
              className={({ isActive }) => cn('flex items-center gap-2.5 rounded-md px-2.5 py-[7px] text-[13.5px] text-side-fg hover:bg-white/5 hover:text-white', isActive && 'bg-side-act text-white')}>
              <it.icon className="size-4" />{it.label}
            </NavLink>
          ))}
        </div>
      ))}
    </nav>
  )
}

function Brand() {
  const { role } = useAuth()
  return (
    <div className="flex h-14 shrink-0 items-center gap-2.5 border-b border-white/10 px-4">
      <span className="grid size-7 place-items-center rounded-md bg-[#2E9B72] text-white"><Recycle className="size-4" /></span>
      <div className="leading-tight"><b className="text-[15px] font-semibold text-white">ReLoop</b><div className="text-[11px] text-side-fg">{role ? ROLE_LABEL[role] : ''}</div></div>
    </div>
  )
}

function BatchSearch() {
  const nav = useNavigate()
  const [v, setV] = React.useState('')
  return (
    <form role="search" className="relative w-full max-w-sm" onSubmit={(e) => { e.preventDefault(); const c = v.trim().toUpperCase(); if (c) { nav(`/passport/${encodeURIComponent(c)}`); setV('') } }}>
      <label htmlFor="global-search" className="sr-only">Open a batch by code</label>
      <Search className="absolute left-2.5 top-2.5 size-3.5 text-fg-3" />
      <input id="global-search" value={v} onChange={(e) => setV(e.target.value)} placeholder="Open batch by code, e.g. RL-MUM-2026-000105"
        className="h-[34px] w-full rounded-md border border-line bg-surface-2 pl-8 pr-2 text-[13px]" />
    </form>
  )
}

function BackendStatus() {
  const q = useQuery({ queryKey: ['health'], queryFn: health, refetchInterval: 30_000, retry: 0 })
  if (!q.isError) return null
  return (
    <div role="status" className="flex items-center gap-2 bg-bad-bg px-4 py-1.5 text-xs text-bad">
      <WifiOff className="size-3.5" />The ReLoop backend is not responding. Records shown may be out of date; changes cannot be saved.
    </div>
  )
}

function UserMenu() {
  const { me, signOut, role } = useAuth()
  const nav = useNavigate()
  if (!me) return null
  const initials = me.user.full_name.split(' ').map((s) => s[0]).slice(0, 2).join('')
  return (
    <DD.Root>
      <DD.Trigger className="flex items-center gap-2 rounded-md px-1.5 py-1 hover:bg-surface-2" aria-label="Account menu">
        <span className="grid size-8 place-items-center rounded-full bg-accent-soft text-xs font-semibold text-brand">{initials}</span>
        <span className="hidden text-left leading-tight md:block"><b className="block text-[13px] font-semibold">{me.user.full_name}</b><span className="text-[11.5px] text-fg-3">{me.active_role ?? ''}{me.user.is_platform_admin ? ' · Platform admin' : ''}</span></span>
      </DD.Trigger>
      <DD.Portal>
        <DD.Content align="end" sideOffset={6} className="z-50 min-w-[240px] rounded-lg border border-line bg-surface p-1 shadow-lg">
          <div className="px-3 py-2 text-xs text-fg-3">{me.user.email}<br />{me.active_org?.legal_name}</div>
          <DD.Separator className="my-1 h-px bg-line" />
          {role !== 'admin' && (
            <DD.Item onSelect={() => nav('/profile')} className="flex cursor-pointer items-center gap-2 rounded-md px-3 py-2 text-[13px] outline-none data-[highlighted]:bg-surface-2"><Building2 className="size-4" />Organisation profile</DD.Item>
          )}
          <DD.Item onSelect={() => void signOut()} className="flex cursor-pointer items-center gap-2 rounded-md px-3 py-2 text-[13px] text-bad outline-none data-[highlighted]:bg-surface-2"><LogOut className="size-4" />Sign out</DD.Item>
        </DD.Content>
      </DD.Portal>
    </DD.Root>
  )
}

function MobileNavSheet({ open, onOpenChange }: { open: boolean; onOpenChange: (o: boolean) => void }) {
  return (
    <D.Root open={open} onOpenChange={onOpenChange}>
      <D.Portal>
        <D.Overlay className="fixed inset-0 z-50 bg-black/40 lg:hidden" />
        <D.Content className="safe-t fixed inset-y-0 left-0 z-50 flex w-[272px] flex-col bg-side lg:hidden">
          <D.Title className="sr-only">Navigation</D.Title><D.Description className="sr-only">All screens in this workspace</D.Description>
          <div className="flex items-center"><div className="flex-1"><Brand /></div><D.Close className="mr-2 p-2 text-side-fg" aria-label="Close navigation"><X className="size-4" /></D.Close></div>
          <SideNav onNavigate={() => onOpenChange(false)} />
        </D.Content>
      </D.Portal>
    </D.Root>
  )
}

function BottomTabs({ onMore }: { onMore: () => void }) {
  const { role } = useAuth()
  const loc = useLocation()
  if (!role) return null
  const tabs: NavItem[] = NAV[role].flatMap((g) => g.items).filter((i) => i.tab).slice(0, 4)
  const inTabs = tabs.some((t) => (t.to === BASE[role] ? loc.pathname === t.to : loc.pathname.startsWith(t.to)))
  return (
    <nav aria-label="Primary" className="safe-b fixed inset-x-0 bottom-0 z-40 grid grid-cols-5 border-t border-line bg-surface px-1 pt-1 lg:hidden">
      {tabs.map((t) => (
        <NavLink key={t.to} to={t.to} end={t.to === BASE[role] || t.to.endsWith('/new')}
          className={({ isActive }) => cn('flex flex-col items-center gap-0.5 py-1.5 text-[10.5px] font-medium text-fg-3', isActive && 'text-brand')}>
          {t.primaryAction
            ? <span className="-mt-4 grid size-11 place-items-center rounded-xl bg-brand text-brand-fg shadow-lg"><t.icon className="size-5" /></span>
            : <t.icon className="size-5" />}
          <span className="max-w-full truncate px-1">{t.label.split(' ')[0]}</span>
        </NavLink>
      ))}
      <button onClick={onMore} className={cn('flex flex-col items-center gap-0.5 py-1.5 text-[10.5px] font-medium text-fg-3', !inTabs && 'text-brand')}>
        <MoreHorizontal className="size-5" /><span>More</span>
      </button>
    </nav>
  )
}

export function AppShell() {
  const { role, me } = useAuth()
  const [navOpen, setNavOpen] = React.useState(false)
  const loc = useLocation()
  React.useEffect(() => { setNavOpen(false) }, [loc.pathname])
  const mobileTabs = role != null && MOBILE_FIRST.includes(role)
  return (
    <div className="grid h-full lg:grid-cols-[240px_minmax(0,1fr)]">
      <aside className="hidden min-h-0 flex-col bg-side lg:flex"><Brand /><SideNav />
        <div className="border-t border-white/10 px-4 py-3 text-[11px] text-side-fg">Connected to ReLoop API</div>
      </aside>
      <div className="flex min-h-0 min-w-0 flex-col">
        <header className="safe-t flex h-14 shrink-0 items-center gap-3 border-b border-line bg-surface px-4">
          <button className={cn('rounded-md p-2 hover:bg-surface-2 lg:hidden', mobileTabs && 'hidden')} onClick={() => setNavOpen(true)} aria-label="Open navigation"><Menu className="size-4" /></button>
          <div className="flex min-w-0 items-center gap-2">
            <span className="grid size-7 shrink-0 place-items-center rounded-md bg-brand text-[11px] font-semibold text-brand-fg">{me?.active_org?.legal_name.slice(0, 2).toUpperCase()}</span>
            <div className="min-w-0 leading-tight"><b className="block truncate text-[13px] font-semibold">{me?.active_org?.legal_name}</b><span className="text-[11.5px] text-fg-3">{role ? ROLE_LABEL[role] : ''}</span></div>
          </div>
          <div className="ml-auto hidden flex-1 justify-end sm:flex"><BatchSearch /></div>
          <div className="ml-auto sm:ml-0"><UserMenu /></div>
        </header>
        <BackendStatus />
        <main id="main" className={cn('min-h-0 flex-1 overflow-y-auto', mobileTabs && 'max-lg:pb-24')}>
          <div className="mx-auto w-full max-w-[1440px] px-4 pb-12 pt-5 lg:px-7">
            <div className="mb-4 sm:hidden"><BatchSearch /></div>
            <Outlet />
          </div>
        </main>
      </div>
      {mobileTabs && <BottomTabs onMore={() => setNavOpen(true)} />}
      <MobileNavSheet open={navOpen} onOpenChange={setNavOpen} />
    </div>
  )
}
