import { get, post } from '@/api/client'
import type { Allocation, AllocationCreateInput, EprCertificate, EprDashboard, EprDiscrepancy, EprTarget } from '@/types/api'

export const eprDashboard = (period: string) => get<EprDashboard>('/epr/dashboard', { params: { period } })
export const listTargets = (period?: string) => get<EprTarget[]>('/epr/targets', { params: period ? { period } : undefined })
export const upsertTarget = (body: { reporting_period: string; packaging_category: string; target_kg: number; source_note?: string }) => post<EprTarget>('/epr/targets', body)
export const listAllocations = (status?: string) => get<Allocation[]>('/epr/allocations', { params: status ? { status } : undefined })
export const createAllocation = (body: AllocationCreateInput) => post<{ allocation_id: string; quantity_kg: number; remaining_available_kg: number }>('/epr/allocations', body)
export const reverseAllocation = (id: string, reason: string) => post<{ reversal_id: string }>(`/epr/allocations/${id}/reverse`, { reason })
export const eprCertificates = () => get<EprCertificate[]>('/epr/certificates')
export const eprDiscrepancies = () => get<EprDiscrepancy[]>('/epr/discrepancies')
