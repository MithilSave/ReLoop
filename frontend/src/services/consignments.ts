import { get, post } from '@/api/client'
import type { Consignment } from '@/types/api'

export const listConsignments = () => get<Consignment[]>('/consignments')
export const getConsignment = (id: string) => get<Consignment>(`/consignments/${id}`)
export const createConsignment = (body: { batch_ids: string[]; destination_recycler_org_id: string; vehicle_no?: string; aggregation_plan_id?: string }) =>
  post<Consignment>('/consignments', body)
export const markArrived = (id: string) => post<{ consignment_status: string; arrived_at: string }>(`/consignments/${id}/arrive`)
