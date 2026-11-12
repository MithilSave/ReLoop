import { Info } from 'lucide-react'

export function PageHeader({ title, description, actions }: { title: string; description?: React.ReactNode; actions?: React.ReactNode }) {
  return (
    <div className="mb-5 flex flex-wrap items-end justify-between gap-4">
      <div className="min-w-0">
        <h1 className="text-[21px] font-semibold tracking-tight [text-wrap:balance] max-sm:text-lg">{title}</h1>
        {description && <p className="mt-1 max-w-[75ch] text-[13.5px] text-fg-2">{description}</p>}
      </div>
      {actions && <div className="flex flex-wrap gap-2 max-sm:w-full max-sm:[&>*]:flex-1">{actions}</div>}
    </div>
  )
}
export function SourceLine({ source, period }: { source: string; period?: string }) {
  return (
    <span className="inline-flex flex-wrap items-center gap-1.5 text-[11.5px] text-fg-3">
      <Info className="size-3.5" />Source: {source}{period && <> · Period: {period}</>}
    </span>
  )
}
