import * as React from 'react'
import * as LabelPrimitive from '@radix-ui/react-label'
import { cn } from '@/lib/utils'

export function Field({ label, htmlFor, hint, error, required, className, children }: {
  label: string; htmlFor: string; hint?: React.ReactNode; error?: string; required?: boolean; className?: string; children: React.ReactNode
}) {
  return (
    <div className={cn('flex min-w-0 flex-col gap-1.5', className)}>
      <LabelPrimitive.Root htmlFor={htmlFor} className="text-[12.5px] font-medium text-fg-2">
        {label}{required && <span className="text-bad"> *</span>}
      </LabelPrimitive.Root>
      {children}
      {hint && !error && <p className="text-[11.5px] text-fg-3">{hint}</p>}
      {error && <p role="alert" className="text-[11.5px] text-bad">{error}</p>}
    </div>
  )
}
