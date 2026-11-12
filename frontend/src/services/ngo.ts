import { get, post } from '@/api/client'
import type { NgoImpact, VerificationDetail, VerificationListItem } from '@/types/api'

export const listVerifications = (decision?: string) => get<VerificationListItem[]>('/ngo/verifications', { params: decision ? { decision } : undefined })
export const getVerification = (id: string) => get<VerificationDetail>(`/ngo/verifications/${id}`)
export const claimVerification = (id: string) => post<{ decision: string }>(`/ngo/verifications/${id}/claim`)
export const decide = (id: string, body: { decision: string; comments?: string; follow_up_required?: string; evidence_doc_ids?: string[] }) =>
  post<{ verification_id: string; decision: string }>(`/ngo/verifications/${id}/decision`, body)
export const requestDocument = (id: string, body: { addressed_to_org_id: string; request_text: string }) => post<{ message: string }>(`/ngo/verifications/${id}/document-requests`, body)
export const ngoReports = () => get<{ counts_by_decision: Record<string, number>; reporting_period: string }>('/ngo/reports')
export const ngoImpact = () => get<NgoImpact>('/ngo/impact')
