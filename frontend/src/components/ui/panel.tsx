import { cn } from '@/lib/utils'

export function Panel({ title, sub, actions, footer, flush, className, children, id }: {
  title?: React.ReactNode; sub?: React.ReactNode; actions?: React.ReactNode; footer?: React.ReactNode; flush?: boolean; className?: string; children: React.ReactNode; id?: string
}) {
  return (
    <section id={id} className={cn('min-w-0 rounded-lg border border-line bg-surface', className)}>
      {(title || actions) && (
        <header className="flex flex-wrap items-center justify-between gap-2 border-b border-line px-4 py-3">
          <div className="min-w-0">
            {title && <h3 className="text-sm font-semibold">{title}</h3>}
            {sub && <p className="text-xs text-fg-3">{sub}</p>}
          </div>
          {actions && <div className="flex flex-wrap items-center gap-2">{actions}</div>}
        </header>
      )}
      <div className={cn(flush ? '' : 'p-4', 'min-w-0 overflow-x-auto')}>{children}</div>
      {footer && <footer className="flex flex-wrap justify-between gap-3 border-t border-line px-4 py-2.5 text-xs text-fg-3">{footer}</footer>}
    </section>
  )
}

export function Kpi({ label, value, sub, icon }: { label: string; value: React.ReactNode; sub?: React.ReactNode; icon?: React.ReactNode }) {
  return (
    <div className="min-w-0 rounded-lg border border-line bg-surface px-4 py-3.5">
      <div className="flex items-center gap-1.5 text-xs text-fg-2 [&_svg]:size-3.5">{icon}{label}</div>
      <div className="tnum mt-1 text-[22px] font-semibold tracking-tight max-sm:text-lg">{value}</div>
      {sub && <div className="mt-0.5 text-xs text-fg-3">{sub}</div>}
    </div>
  )
}

export function KV({ rows }: { rows: [React.ReactNode, React.ReactNode, boolean?][] }) {
  return (
    <dl className="grid grid-cols-[minmax(0,1fr)_auto] gap-x-4 gap-y-1.5 text-[13px]">
      {rows.map(([k, v, total], i) => (
        <div key={i} className={cn('contents', total && '[&>*]:border-t [&>*]:border-line [&>*]:pt-1.5 [&>*]:font-semibold [&>*]:text-fg')}>
          <dt className="text-fg-2">{k}</dt>
          <dd className="tnum text-right font-medium">{v}</dd>
        </div>
      ))}
    </dl>
  )
}
