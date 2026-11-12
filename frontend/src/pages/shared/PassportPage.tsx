import { useParams, useNavigate } from 'react-router-dom'
import { ArrowLeft } from 'lucide-react'
import { PageHeader } from '@/components/page'
import { Button } from '@/components/ui/button'
import { PassportView } from '@/features/batches/PassportView'

export function PassportPage() {
  const { code = '' } = useParams()
  const nav = useNavigate()
  return (
    <>
      <PageHeader title="Material passport" description="Every recorded stage of this batch, with custody, verification and allocation history."
        actions={<Button variant="outline" onClick={() => nav(-1)}><ArrowLeft />Back</Button>} />
      <PassportView code={decodeURIComponent(code)} />
    </>
  )
}
