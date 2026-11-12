import * as React from 'react'
import { ArrowDown, ArrowUp, ArrowUpDown, ChevronLeft, ChevronRight, Search } from 'lucide-react'
import { cn } from '@/lib/utils'
import { Button } from './button'
import { EmptyState } from '../states'

export interface Column<T> {
  key: string
  header: React.ReactNode
  cell: (row: T) => React.ReactNode
  sortValue?: (row: T) => string | number | null | undefined
  numeric?: boolean
  className?: string
  /** Hide this column below 640px (phone layouts). */
  hideOnMobile?: boolean
}
export interface Filter<T> { key: string; label: string; options: { value: string; label: string }[]; get: (row: T) => string }

/**
 * Sort, search, filter and paginate in the browser. The backend returns full lists with no
 * pagination parameters (audit §9), so this is the honest place to do it at pilot volumes.
 */
export function DataTable<T>({
  rows, columns, rowKey, onRowClick, search, searchPlaceholder = 'Search', filters = [], pageSize = 10,
  initialSort, empty, footer, toolbar, label, rowClassName,
}: {
  rows: T[]; columns: Column<T>[]; rowKey: (r: T) => string; onRowClick?: (r: T) => void
  search?: (r: T) => string; searchPlaceholder?: string; filters?: Filter<T>[]; pageSize?: number
  initialSort?: { key: string; dir: 1 | -1 }; empty?: { title: string; body?: React.ReactNode; action?: React.ReactNode }
  footer?: (rows: T[]) => React.ReactNode; toolbar?: React.ReactNode; label: string; rowClassName?: (r: T) => string | undefined
}) {
  const [q, setQ] = React.useState('')
  const [f, setF] = React.useState<Record<string, string>>({})
  const [sort, setSort] = React.useState(initialSort ?? null)
  const [page, setPage] = React.useState(0)

  const filtered = React.useMemo(() => {
    let out = rows
    if (q && search) { const s = q.toLowerCase(); out = out.filter((r) => search(r).toLowerCase().includes(s)) }
    for (const flt of filters) { const v = f[flt.key]; if (v) out = out.filter((r) => flt.get(r) === v) }
    if (sort) {
      const col = columns.find((c) => c.key === sort.key)
      if (col?.sortValue) {
        const g = col.sortValue
        out = [...out].sort((a, b) => {
          const x = g(a), y = g(b)
          if (x == null && y == null) return 0
          if (x == null) return 1
          if (y == null) return -1
          return (x > y ? 1 : x < y ? -1 : 0) * sort.dir
        })
      }
    }
    return out
  }, [rows, q, f, sort, search, filters, columns])

  const pages = Math.max(1, Math.ceil(filtered.length / pageSize))
  const p = Math.min(page, pages - 1)
  const view = filtered.slice(p * pageSize, p * pageSize + pageSize)
  const filtering = !!q || Object.values(f).some(Boolean)

  return (
    <div className="min-w-0">
      {(search || filters.length > 0 || toolbar) && (
        <div className="flex flex-wrap items-center gap-2 border-b border-line px-3 py-2.5">
          {search && (
            <label className="relative min-w-[180px] max-w-xs flex-1">
              <span className="sr-only">{searchPlaceholder}</span>
              <Search className="absolute left-2.5 top-2.5 size-3.5 text-fg-3" />
              <input value={q} onChange={(e) => { setQ(e.target.value); setPage(0) }} placeholder={searchPlaceholder}
                className="h-8 w-full rounded-md border border-line-2 bg-surface pl-8 pr-2 text-[13px]" />
            </label>
          )}
          {filters.map((flt) => (
            <select key={flt.key} aria-label={flt.label} value={f[flt.key] ?? ''} onChange={(e) => { setF({ ...f, [flt.key]: e.target.value }); setPage(0) }}
              className="h-8 max-w-[180px] rounded-md border border-line-2 bg-surface px-2 text-[13px]">
              <option value="">{flt.label}: all</option>
              {flt.options.map((o) => <option key={o.value} value={o.value}>{o.label}</option>)}
            </select>
          ))}
          {toolbar}
          <span className="ml-auto text-xs text-fg-3">{filtered.length} {filtered.length === 1 ? 'record' : 'records'}</span>
        </div>
      )}
      <div className="overflow-x-auto">
        <table className="w-full border-collapse text-[13px]" aria-label={label}>
          <thead>
            <tr>
              {columns.map((c) => {
                const sorted = sort?.key === c.key
                return (
                  <th key={c.key} scope="col" aria-sort={sorted ? (sort!.dir > 0 ? 'ascending' : 'descending') : undefined}
                    className={cn('whitespace-nowrap border-b border-line bg-surface-2 px-3 py-2 text-left text-xs font-medium text-fg-2', c.numeric && 'text-right', c.hideOnMobile && 'max-sm:hidden')}>
                    {c.sortValue ? (
                      <button className={cn('inline-flex items-center gap-1 hover:text-fg', sorted && 'text-fg')}
                        onClick={() => setSort(sorted ? { key: c.key, dir: (sort!.dir * -1) as 1 | -1 } : { key: c.key, dir: 1 })}>
                        {c.header}
                        {sorted ? (sort!.dir > 0 ? <ArrowUp className="size-3" /> : <ArrowDown className="size-3" />) : <ArrowUpDown className="size-3 opacity-40" />}
                      </button>
                    ) : c.header}
                  </th>
                )
              })}
            </tr>
          </thead>
          <tbody>
            {view.map((r) => (
              <tr key={rowKey(r)} onClick={onRowClick ? () => onRowClick(r) : undefined}
                onKeyDown={onRowClick ? (e) => { if (e.key === 'Enter') onRowClick(r) } : undefined}
                tabIndex={onRowClick ? 0 : undefined}
                className={cn(onRowClick && 'cursor-pointer hover:bg-surface-2', rowClassName?.(r))}>
                {columns.map((c) => (
                  <td key={c.key} className={cn('border-b border-line px-3 py-2.5 align-middle', c.numeric && 'tnum text-right', c.hideOnMobile && 'max-sm:hidden', c.className)}>{c.cell(r)}</td>
                ))}
              </tr>
            ))}
            {view.length === 0 && (
              <tr><td colSpan={columns.length}>
                {filtering
                  ? <EmptyState title="No records match these filters" body="Clear the search or change a filter." action={<Button size="sm" variant="outline" onClick={() => { setQ(''); setF({}) }}>Clear filters</Button>} />
                  : <EmptyState title={empty?.title ?? 'Nothing here yet'} body={empty?.body} action={empty?.action} />}
              </td></tr>
            )}
          </tbody>
          {footer && filtered.length > 0 && <tfoot className="bg-surface-2 font-semibold [&_td]:px-3 [&_td]:py-2">{footer(filtered)}</tfoot>}
        </table>
      </div>
      {filtered.length > pageSize && (
        <div className="flex flex-wrap items-center justify-end gap-2 border-t border-line px-3 py-2 text-xs text-fg-3">
          Showing {p * pageSize + 1}–{Math.min(filtered.length, p * pageSize + pageSize)} of {filtered.length}
          <Button size="sm" variant="outline" disabled={p === 0} onClick={() => setPage(p - 1)} aria-label="Previous page"><ChevronLeft /></Button>
          <span>Page {p + 1} of {pages}</span>
          <Button size="sm" variant="outline" disabled={p >= pages - 1} onClick={() => setPage(p + 1)} aria-label="Next page"><ChevronRight /></Button>
        </div>
      )}
    </div>
  )
}
