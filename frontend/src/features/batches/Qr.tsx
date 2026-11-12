import * as React from 'react'
import { useQuery } from '@tanstack/react-query'
import { batchQrBlob } from '@/services/batches'
import { Skeleton } from '@/components/ui/skeleton'

export function BatchQr({ batchId, code, size = 116 }: { batchId: string; code: string; size?: number }) {
  const q = useQuery({ queryKey: ['batches', 'qr', batchId], queryFn: () => batchQrBlob(batchId), staleTime: Infinity })
  const [url, setUrl] = React.useState<string | null>(null)
  React.useEffect(() => {
    if (!q.data) return
    const u = URL.createObjectURL(q.data)
    setUrl(u)
    return () => URL.revokeObjectURL(u)
  }, [q.data])
  if (q.isError) return <div style={{ width: size, height: size }} className="grid place-items-center rounded border border-line text-center text-[11px] text-fg-3">QR unavailable</div>
  if (!url) return <Skeleton className="shrink-0" />
  return <img src={url} width={size} height={size} alt={`QR code for batch ${code}`} className="shrink-0 rounded border border-line bg-white" />
}
