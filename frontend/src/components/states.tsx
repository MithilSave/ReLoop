import { AlertTriangle, Inbox, RefreshCw, ShieldOff, WifiOff } from 'lucide-react'
import type { UseQueryResult } from '@tanstack/react-query'
import { ApiError, describeError, toApiError } from '@/api/errors'
import { Button } from './ui/button'
import { Skeleton } from './ui/skeleton'

export function EmptyState({ title, body, action, icon }: { title: string; body?: React.ReactNode; action?: React.ReactNode; icon?: React.ReactNode }) {
  return (
    <div className="flex flex-col items-center px-4 py-9 text-center text-fg-2">
      <div className="mb-2 text-fg-3 [&_svg]:size-6">{icon ?? <Inbox />}</div>
      <p className="font-semibold text-fg">{title}</p>
      {body && <div className="mt-0.5 max-w-md text-[13px]">{body}</div>}
      {action && <div className="mt-3">{action}</div>}
    </div>
  )
}

export function ErrorState({ error, onRetry }: { error: unknown; onRetry?: () => void }) {
  const e = error instanceof ApiError ? error : toApiError(error)
  const d = describeError(e)
  const Icon = e.status === 0 ? WifiOff : e.status === 403 ? ShieldOff : AlertTriangle
  return (
    <div role="alert" className="flex flex-col items-center px-4 py-9 text-center">
      <Icon className="mb-2 size-6 text-bad" />
      <p className="font-semibold">{d.title}</p>
      <p className="mt-0.5 max-w-md text-[13px] text-fg-2">{d.body}</p>
      {e.code && e.status > 0 && <p className="mt-1 font-mono text-[11px] text-fg-3">{e.status} · {e.code}</p>}
      {onRetry && e.status !== 403 && <Button className="mt-3" size="sm" variant="outline" onClick={onRetry}><RefreshCw />Retry</Button>}
    </div>
  )
}

export function LoadingRows({ rows = 4 }: { rows?: number }) {
  return (
    <div className="flex flex-col gap-3 p-4" aria-busy="true" aria-label="Loading">
      {Array.from({ length: rows }).map((_, i) => <Skeleton key={i} className="h-4" />)}
    </div>
  )
}

/** Renders loading / error / empty / data for a TanStack query. */
export function QueryState<T>({ query, children, empty, isEmpty, loading }: {
  query: UseQueryResult<T>; children: (data: T) => React.ReactNode
  empty?: { title: string; body?: React.ReactNode; action?: React.ReactNode }; isEmpty?: (d: T) => boolean; loading?: React.ReactNode
}) {
  if (query.isPending) return <>{loading ?? <LoadingRows />}</>
  if (query.isError) return <ErrorState error={query.error} onRetry={() => query.refetch()} />
  const data = query.data as T
  if (empty && (isEmpty ? isEmpty(data) : Array.isArray(data) && data.length === 0)) return <EmptyState {...empty} />
  return <>{children(data)}</>
}
