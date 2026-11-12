import { Badge, type Tone } from './ui/badge'
import type { BatchStatus, NgoDecision } from '@/types/api'

const BATCH: Record<string, [Tone, string]> = {
  LISTED: ['info', 'Listed'], ASSIGNED: ['warn', 'Assigned'], PICKED_UP: ['warn', 'Picked up'], IN_TRANSIT: ['warn', 'In transit'],
  RECEIVED: ['ok', 'Received'], REJECTED_AT_RECEIPT: ['bad', 'Rejected at receipt'], PROCESSED: ['ok', 'Processed'], CANCELLED: ['neutral', 'Cancelled'],
}
export const BATCH_STATUS_OPTIONS = Object.entries(BATCH).map(([value, [, label]]) => ({ value, label }))
export function BatchStatusBadge({ status }: { status: BatchStatus | string }) {
  const [t, l] = BATCH[status] ?? ['neutral', status]
  return <Badge tone={t}>{l}</Badge>
}

const NGO: Record<string, [Tone, string]> = {
  PENDING: ['info', 'Pending review'], UNDER_REVIEW: ['warn', 'Under review'], VERIFIED: ['ok', 'Verified'],
  FLAGGED: ['bad', 'Flagged'], REJECTED: ['bad', 'Rejected'], REQUIRES_CORRECTION: ['warn', 'Correction requested'],
}
export const NGO_OPTIONS = Object.entries(NGO).map(([value, [, label]]) => ({ value, label }))
export function NgoBadge({ decision }: { decision: NgoDecision | string | null | undefined }) {
  if (!decision) return <span className="text-xs text-fg-3">Not in review</span>
  const [t, l] = NGO[decision] ?? ['neutral', decision]
  return <Badge tone={t}>{l}</Badge>
}

export function SimpleStatus({ status, map }: { status: string; map: Record<string, [Tone, string]> }) {
  const [t, l] = map[status] ?? ['neutral', status]
  return <Badge tone={t}>{l}</Badge>
}
