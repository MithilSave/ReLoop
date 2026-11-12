import { cn } from '@/lib/utils'
export const Skeleton = ({ className }: { className?: string }) => <div className={cn('animate-pulse rounded bg-surface-2', className)} />
