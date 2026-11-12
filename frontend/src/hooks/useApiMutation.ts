import { useMutation, useQueryClient, type QueryKey } from '@tanstack/react-query'
import { toast } from 'sonner'
import { ApiError, describeError } from '@/api/errors'

/**
 * Mutation wrapper: invalidates every query that shows the affected records, so one action
 * updates all screens. Errors are shown with the backend's own message; nothing is retried
 * with altered values (e.g. an over-allocation is never silently reduced).
 */
export function useApiMutation<TVars, TData>(
  fn: (v: TVars) => Promise<TData>,
  opts: { invalidate: QueryKey[]; success?: string | ((d: TData, v: TVars) => string); onSuccess?: (d: TData, v: TVars) => void; toastErrors?: boolean },
) {
  const qc = useQueryClient()
  return useMutation<TData, ApiError, TVars>({
    mutationFn: fn,
    onSuccess: async (d, v) => {
      await Promise.all(opts.invalidate.map((k) => qc.invalidateQueries({ queryKey: k })))
      if (opts.success) toast.success(typeof opts.success === 'function' ? opts.success(d, v) : opts.success)
      opts.onSuccess?.(d, v)
    },
    onError: (e) => {
      if (opts.toastErrors !== false && e.status !== 422 && e.status !== 409) {
        const d = describeError(e)
        toast.error(d.title, { description: d.body })
      }
    },
  })
}
