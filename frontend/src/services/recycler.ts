import { get, post } from '@/api/client'
import type { Capacity, IncomingBatch, ProcessingRecord, ProcessingRecordInput, Receipt, ReceiptInput, RecyclerOffer, YieldAnalytics } from '@/types/api'

export const incoming = () => get<IncomingBatch[]>('/recycler/incoming')
export const listReceipts = (include_history = false) => get<Receipt[]>('/recycler/receipts', { params: { include_history } })
export const createReceipt = (body: ReceiptInput) =>
  post<{ receipt_id: string; batch_code: string; batch_status: string; accepted_kg: number; rejected_kg: number }>('/recycler/receipts', body)
export const correctReceipt = (id: string, body: { received_kg: number; accepted_kg: number; rejected_kg: number; quality_grade: string; contamination_pct: number; reason: string }) =>
  post<{ new_receipt_id: string; version: number }>(`/recycler/receipts/${id}/corrections`, body)
export const listProcessing = () => get<ProcessingRecord[]>('/recycler/processing-records')
export const createProcessing = (body: ProcessingRecordInput) =>
  post<{ processing_record_id: string; record_code: string; yield_pct: number; eligible_kg: number }>('/recycler/processing-records', body)
export const addCertificate = (recordId: string, body: { certificate_ref: string; packaging_category: string; certificate_kg: number; issued_on?: string }) =>
  post<{ certificate_id: string; certificate_ref: string }>(`/recycler/processing-records/${recordId}/certificates`, body)
export const capacity = () => get<Capacity>('/recycler/capacity')
export const yieldAnalytics = (material?: string) => get<YieldAnalytics>('/yield', { params: material ? { material } : undefined })
export const myOffers = () => get<RecyclerOffer[]>('/recycler/offers')
export const createOffer = (body: { material_code: string; price_per_kg: number; min_kg: number; max_contamination_pct: number; quality_spec?: string; valid_to: string }) =>
  post<{ offer_id: string }>('/recycler/offers', body)
