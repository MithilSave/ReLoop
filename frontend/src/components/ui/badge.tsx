import { cn } from '@/lib/utils'

export type Tone = 'ok' | 'warn' | 'bad' | 'info' | 'neutral'
const TONE: Record<Tone, string> = {
  ok: 'bg-ok-bg text-ok', warn: 'bg-warn-bg text-warn', bad: 'bg-bad-bg text-bad', info: 'bg-info-bg text-info', neutral: 'bg-neu text-fg-2',
}
export function Badge({ tone = 'neutral', dot = true, className, children }: { tone?: Tone; dot?: boolean; className?: string; children: React.ReactNode }) {
  return (
    <span className={cn('inline-flex h-[21px] items-center gap-1.5 whitespace-nowrap rounded-full px-2 text-[11.5px] font-medium', TONE[tone], className)}>
      {dot && <span className="h-1.5 w-1.5 rounded-full bg-current opacity-85" />}{children}
    </span>
  )
}
export function Tag({ className, children, title }: { className?: string; children: React.ReactNode; title?: string }) {
  return <span title={title} className={cn('inline-flex h-5 items-center whitespace-nowrap rounded border border-line bg-surface px-1.5 text-[11.5px] font-medium text-fg-2', className)}>{children}</span>
}
