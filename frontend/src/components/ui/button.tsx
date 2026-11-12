import * as React from 'react'
import { Slot } from '@radix-ui/react-slot'
import { cva, type VariantProps } from 'class-variance-authority'
import { Loader2 } from 'lucide-react'
import { cn } from '@/lib/utils'

const buttonVariants = cva(
  'inline-flex items-center justify-center gap-2 whitespace-nowrap rounded-md text-[13px] font-medium transition-colors disabled:pointer-events-none disabled:opacity-50 [&_svg]:size-4 [&_svg]:shrink-0',
  {
    variants: {
      variant: {
        default: 'bg-brand text-brand-fg hover:bg-brand-2',
        outline: 'border border-line-2 bg-surface hover:bg-surface-2',
        ghost: 'hover:bg-surface-2',
        destructive: 'border border-bad/40 text-bad bg-surface hover:bg-bad-bg',
        link: 'text-accent underline-offset-4 hover:underline px-0',
      },
      size: { default: 'h-9 px-3.5', sm: 'h-8 px-2.5 text-[12.5px]', lg: 'h-11 px-5 text-sm', icon: 'h-9 w-9' },
    },
    defaultVariants: { variant: 'default', size: 'default' },
  },
)

export interface ButtonProps extends React.ButtonHTMLAttributes<HTMLButtonElement>, VariantProps<typeof buttonVariants> {
  asChild?: boolean
  loading?: boolean
}
export const Button = React.forwardRef<HTMLButtonElement, ButtonProps>(
  ({ className, variant, size, asChild, loading, children, disabled, ...props }, ref) => {
    const Comp = asChild ? Slot : 'button'
    return (
      <Comp ref={ref} className={cn(buttonVariants({ variant, size }), className)} disabled={disabled || loading} {...props}>
        {asChild ? children : <>{loading && <Loader2 className="animate-spin" />}{children}</>}
      </Comp>
    )
  },
)
Button.displayName = 'Button'
