import { get, post, patch, http } from '@/api/client'
import type { Batch, BatchCreateInput, BatchCreated, BatchEvent, BatchTrace, Passport, CollectionOffer } from '@/types/api'

export const listBatches = (params?: { status?: string; material?: string; locality?: string }) => get<Batch[]>('/batches', { params })
export const getBatch = (idOrCode: string) => get<Batch>(`/batches/${encodeURIComponent(idOrCode)}`)
export const createBatch = (body: BatchCreateInput) => post<BatchCreated>('/batches', body)
export const updateBatch = (id: string, body: Partial<BatchCreateInput>) => patch<{ status: string }>(`/batches/${id}`, body)
export const cancelBatch = (id: string) => post<{ status: string; new_status: string }>(`/batches/${id}/cancel`)
export const batchEvents = (id: string) => get<BatchEvent[]>(`/batches/${id}/events`)
export const batchTrace = (id: string) => get<BatchTrace>(`/batches/${id}/trace`)
export const passport = (code: string) => get<Passport>(`/passports/${encodeURIComponent(code)}`)
export const batchOffers = (id: string) => get<CollectionOffer[]>(`/batches/${id}/offers`)
export const acceptOffer = (batchId: string, offerId: string) => post<{ batch_status: string }>(`/batches/${batchId}/offers/${offerId}/accept`)
export const confirmHandover = (batchId: string, body: { otp?: string; qr_token?: string }) =>
  post<{ batch_status: string; collected_kg: number; payment_generated: number }>(`/batches/${batchId}/handover/confirm`, body)
/** QR image is a protected PNG; fetched as a blob and shown via an object URL. */
export async function batchQrBlob(id: string): Promise<Blob> {
  return (await http.get(`/batches/${id}/qr`, { responseType: 'blob' })).data as Blob
}
