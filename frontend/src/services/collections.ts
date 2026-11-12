import { get, post } from '@/api/client'
import type { AvailableListing, CollectorJob, PickupResult } from '@/types/api'

export const availableListings = (params?: { lat?: number; lng?: number; radius_km?: number }) => get<AvailableListing[]>('/collections/available', { params })
export const makeOffer = (batchId: string, body: { generator_rate_per_kg: number; proposed_pickup_at: string }) =>
  post<{ offer_id: string }>(`/collections/${batchId}/offers`, body)
export const collectorJobs = (status?: string) => get<CollectorJob[]>('/collections/jobs', { params: status ? { status } : undefined })
export const recordPickup = (batchId: string, body: { collected_kg: number; notes?: string; document_ids?: string[] }) =>
  post<PickupResult>(`/collections/${batchId}/pickup`, body)
export const withdrawCollection = (batchId: string) => post<{ batch_status: string }>(`/collections/${batchId}/withdraw`)
