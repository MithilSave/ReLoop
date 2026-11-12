import * as React from 'react'
import * as D from '@radix-ui/react-dialog'
import { X } from 'lucide-react'
import { cn } from '@/lib/utils'

export const Dialog = D.Root
export const DialogTrigger = D.Trigger
export const DialogClose = D.Close

/** Centred modal on desktop; bottom sheet on phones. */
export function DialogContent({ title, description, children, footer, wide, className }: {
  title: string; description?: React.ReactNode; children: React.ReactNode; footer?: React.ReactNode; wide?: boolean; className?: string
}) {
  return (
    <D.Portal>
      <D.Overlay className="fixed inset-0 z-50 bg-black/40" />
      <D.Content
        className={cn(
          'fixed z-50 flex max-h-[92dvh] flex-col border border-line bg-surface shadow-lg',
          'inset-x-0 bottom-0 rounded-t-xl sm:inset-auto sm:left-1/2 sm:top-1/2 sm:-translate-x-1/2 sm:-translate-y-1/2 sm:rounded-xl',
          wide ? 'sm:w-[min(880px,calc(100vw-32px))]' : 'sm:w-[min(600px,calc(100vw-32px))]',
          className,
        )}
      >
        <div className="flex items-start gap-3 px-5 pb-1 pt-4">
          <div className="min-w-0 flex-1">
            <D.Title className="text-base font-semibold">{title}</D.Title>
            {description ? <D.Description className="mt-1 text-[13px] text-fg-2">{description}</D.Description> : <D.Description className="sr-only">{title}</D.Description>}
          </div>
          <D.Close className="rounded-md p-1.5 text-fg-2 hover:bg-surface-2" aria-label="Close"><X className="size-4" /></D.Close>
        </div>
        <div className="flex min-h-0 flex-col gap-4 overflow-y-auto px-5 py-3">{children}</div>
        {footer && <div className="safe-b flex flex-wrap justify-end gap-2 border-t border-line px-5 py-3 max-sm:[&>*]:flex-1">{footer}</div>}
      </D.Content>
    </D.Portal>
  )
}

/** Right-hand drawer (full height) for record detail; full-screen sheet on phones. */
export function Drawer({ open, onOpenChange, title, sub, children }: { open: boolean; onOpenChange: (o: boolean) => void; title: string; sub?: string; children: React.ReactNode }) {
  return (
    <D.Root open={open} onOpenChange={onOpenChange}>
      <D.Portal>
        <D.Overlay className="fixed inset-0 z-50 bg-black/40" />
        <D.Content className="safe-t fixed inset-y-0 right-0 z-50 flex w-full flex-col border-l border-line bg-bg shadow-lg sm:w-[min(720px,100vw)]">
          <div className="flex items-center gap-3 border-b border-line bg-surface px-5 py-3.5">
            <div className="min-w-0 flex-1">
              <D.Title className="truncate text-base font-semibold">{title}</D.Title>
              <D.Description className={sub ? 'truncate text-xs text-fg-3' : 'sr-only'}>{sub ?? title}</D.Description>
            </div>
            <D.Close className="rounded-md p-1.5 text-fg-2 hover:bg-surface-2" aria-label="Close"><X className="size-4" /></D.Close>
          </div>
          <div className="flex min-h-0 flex-1 flex-col gap-4 overflow-y-auto p-5">{children}</div>
        </D.Content>
      </D.Portal>
    </D.Root>
  )
}
