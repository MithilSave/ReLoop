import type { Consignment } from '@/types/api'

/**
 * The backend keeps a consignment at ARRIVED forever (no closed state). Derive the operational status
 * from the current status of its batches: received once every batch has a receipt.
 */
export type ConsStatus = 'IN_TRANSIT' | 'ARRIVED' | 'RECEIVED'
export function consStatus(c: Consignment): ConsStatus {
  const waiting = c.items.some((i) => i.status === 'IN_TRANSIT' || i.status === 'PICKED_UP')
  if (!waiting) return 'RECEIVED'
  return c.status === 'ARRIVED' ? 'ARRIVED' : 'IN_TRANSIT'
}
export const CONS_STATUS: Record<ConsStatus, ['ok' | 'warn' | 'info', string]> = {
  IN_TRANSIT: ['info', 'In transit'], ARRIVED: ['warn', 'At recycler · awaiting receipt'], RECEIVED: ['ok', 'Received'],
}
