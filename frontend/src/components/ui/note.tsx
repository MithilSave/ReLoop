import { AlertTriangle, CheckCircle2, Info, XCircle } from 'lucide-react'
import { cn } from '@/lib/utils'

const STYLE = {
  info: ['bg-surface-2 border-line text-fg', Info, 'text-fg-3'],
  warn: ['bg-warn-bg border-transparent text-fg', AlertTriangle, 'text-warn'],
  bad: ['bg-bad-bg border-transparent text-fg', XCircle, 'text-bad'],
  ok: ['bg-ok-bg border-transparent text-fg', CheckCircle2, 'text-ok'],
} as const
export function Note({ tone = 'info', title, children, className }: { tone?: keyof typeof STYLE; title?: string; children?: React.ReactNode; className?: string }) {
  const [box, Icon, ic] = STYLE[tone]
  return (
    <div role={tone === 'bad' ? 'alert' : undefined} className={cn('flex items-start gap-2 rounded-md border px-3 py-2.5 text-[12.5px] leading-relaxed', box, className)}>
      <Icon className={cn('mt-0.5 size-4 shrink-0', ic)} />
      <div className="min-w-0">{title && <p className="font-semibold">{title}</p>}{children}</div>
    </div>
  )
}
