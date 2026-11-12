import * as React from 'react'
import { cn } from '@/lib/utils'

export const Input = React.forwardRef<HTMLInputElement, React.InputHTMLAttributes<HTMLInputElement>>(({ className, ...props }, ref) => (
  <input ref={ref} className={cn('h-9 w-full rounded-md border border-line-2 bg-surface px-2.5 text-[13px] placeholder:text-fg-3 aria-[invalid=true]:border-bad disabled:opacity-60', className)} {...props} />
))
Input.displayName = 'Input'

export const Textarea = React.forwardRef<HTMLTextAreaElement, React.TextareaHTMLAttributes<HTMLTextAreaElement>>(({ className, ...props }, ref) => (
  <textarea ref={ref} className={cn('min-h-[72px] w-full rounded-md border border-line-2 bg-surface px-2.5 py-2 text-[13px] placeholder:text-fg-3 aria-[invalid=true]:border-bad', className)} {...props} />
))
Textarea.displayName = 'Textarea'

export const Select = React.forwardRef<HTMLSelectElement, React.SelectHTMLAttributes<HTMLSelectElement>>(({ className, ...props }, ref) => (
  <select ref={ref} className={cn('h-9 w-full rounded-md border border-line-2 bg-surface px-2 text-[13px] aria-[invalid=true]:border-bad', className)} {...props} />
))
Select.displayName = 'Select'
