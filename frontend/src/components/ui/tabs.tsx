import * as T from '@radix-ui/react-tabs'
import { cn } from '@/lib/utils'

export const Tabs = T.Root
export const TabsContent = T.Content
export function TabsList({ items, className }: { items: { value: string; label: React.ReactNode }[]; className?: string }) {
  return (
    <T.List className={cn('mb-4 flex gap-0.5 overflow-x-auto border-b border-line', className)}>
      {items.map((i) => (
        <T.Trigger key={i.value} value={i.value}
          className="-mb-px whitespace-nowrap border-b-2 border-transparent px-3 py-2 text-[13px] font-medium text-fg-2 data-[state=active]:border-brand data-[state=active]:text-fg">
          {i.label}
        </T.Trigger>
      ))}
    </T.List>
  )
}
