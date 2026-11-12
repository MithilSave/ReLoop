import { get } from '@/api/client'
import { API_ORIGIN } from '@/api/config'
import axios from 'axios'
import type { Material, DirectoryOrg, OrgProfileDetail, ImpactSummary } from '@/types/api'

export const listMaterials = () => get<Material[]>('/materials')
export const listOrgs = (org_type?: string) => get<DirectoryOrg[]>('/orgs', { params: org_type ? { org_type } : undefined })
export const myOrg = () => get<OrgProfileDetail>('/orgs/me')
export const impactSummary = () => get<ImpactSummary>('/impact/summary')
export async function health(): Promise<{ status: string; app: string; version: string }> {
  return (await axios.get(`${API_ORIGIN}/health`, { timeout: 5000 })).data
}
