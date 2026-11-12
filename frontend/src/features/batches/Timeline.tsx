import { CheckCircle2, Circle, AlertTriangle, XCircle } from 'lucide-react'
import { dateTime, humanize } from '@/lib/format'
import type { BatchEvent } from '@/types/api'

const ICON: Record<string, [React.ComponentType<{ className?: string }>, string]> = {
  NGO_FLAGGED: [AlertTriangle, 'text-bad bg-bad-bg'], NGO_REJECTED: [XCircle, 'text-bad bg-bad-bg'], CANCELLED: [XCircle, 'text-fg-3 bg-neu'],
  COLLECTOR_WITHDRAWN: [AlertTriangle, 'text-warn bg-warn-bg'], CORRECTION_SUBMITTED: [AlertTriangle, 'text-warn bg-warn-bg'], DOCUMENT_REQUESTED: [Circle, 'text-info bg-info-bg'],
}
function summary(e: BatchEvent): string {
  const p = e.payload ?? {}
  const parts: string[] = []
  for (const [k, v] of Object.entries(p)) {
    if (v == null || typeof v === 'object') continue
    parts.push(`${humanize(k)}: ${v}`)
  }
  return parts.join(' · ')
}
export function EventTimeline({ events }: { events: BatchEvent[] }) {
  if (!events.length) return <p className="text-sm text-fg-3">No events recorded.</p>
  return (
    <ol className="flex flex-col">
      {events.map((e, i) => {
        const [Icon, cls] = ICON[e.event_type] ?? [CheckCircle2, 'text-ok bg-ok-bg']
        return (
          <li key={e.id} className="relative grid grid-cols-[22px_minmax(0,1fr)] gap-2.5 pb-3.5">
            {i < events.length - 1 && <span className="absolute bottom-0 left-[10.5px] top-6 w-px bg-line" />}
            <span className={`grid size-[22px] place-items-center rounded-full ${cls}`}><Icon className="size-3" /></span>
            <div className="min-w-0">
              <div className="flex flex-wrap items-baseline justify-between gap-x-3">
                <b className="text-[13px] font-semibold">{humanize(e.event_type)}{e.to_status ? ` → ${humanize(e.to_status)}` : ''}</b>
                <span className="text-xs text-fg-3">{dateTime(e.created_at)}</span>
              </div>
              {summary(e) && <p className="break-words text-xs text-fg-2">{summary(e)}</p>}
            </div>
          </li>
        )
      })}
    </ol>
  )
}
