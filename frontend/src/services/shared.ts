import { get, post } from '@/api/client'
import type { Anomaly, AuditLog, Payment, SupplierPerformance, DirectoryOrg } from '@/types/api'

export const listAnomalies = (params?: { status?: string; severity?: string }) => get<Anomaly[]>('/anomalies', { params })
export const resolveAnomaly = (id: string, body: { status: string; note: string }) => post<{ flag_status: string }>(`/anomalies/${id}/resolve`, body)
export const auditLogs = (entity_type?: string) => get<AuditLog[]>('/audit/logs', { params: entity_type ? { entity_type } : undefined })
export const listPayments = (status?: string) => get<Payment[]>('/payments', { params: status ? { status } : undefined })
export const markPaid = (id: string, external_ref: string) => post<{ payment_status: string }>(`/payments/${id}/mark-paid`, { external_ref })
export const supplierPerformance = (orgId: string) => get<SupplierPerformance>(`/suppliers/${orgId}/performance`)
export const adminListOrgs = (status?: string) => get<DirectoryOrg[]>('/admin/orgs', { params: status ? { status } : undefined })
export const approveOrg = (id: string, decision: string, note?: string) => post<{ approval_status: string }>(`/admin/orgs/${id}/approve`, { decision, note })
