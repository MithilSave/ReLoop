import { get, post } from '@/api/client'
import type { CompareResult, CostEstimate, DemandProfile, Forecast, PlanDetail, PlanSummary, PricingAssumptions, ProposePlanResult, Shortage } from '@/types/api'

export const listDemand = () => get<DemandProfile[]>('/recycler/demand-profiles')
export const createDemand = (body: { material_code: string; recurrence: string; quantity_kg: number; min_quality_grade: string; max_contamination_pct: number; need_by?: string | null }) =>
  post<DemandProfile>('/recycler/demand-profiles', body)
export const listPlans = () => get<PlanSummary[]>('/aggregation/plans')
export const getPlan = (id: string) => get<PlanDetail>(`/aggregation/plans/${id}`)
export const proposePlan = (body: { material_code: string; target_kg: number; need_by?: string | null } | { demand_profile_id: string }) =>
  post<ProposePlanResult>('/aggregation/plans/propose', body)
export const acceptPlan = (id: string) => post<{ plan_status: string }>(`/aggregation/plans/${id}/accept`)
export const cancelPlan = (id: string) => post<{ message: string }>(`/aggregation/plans/${id}/cancel`)
export const estimateCost = (body: { est_kg: number; material_code: string; distance_km: number }) => post<CostEstimate>('/costs/estimate', body)
export const compareCosts = (options: { type: string; name: string; est_kg: number; material_code: string; distance_km: number }[]) => post<CompareResult>('/costs/compare', { options })
export const pricingAssumptions = () => get<PricingAssumptions>('/pricing-assumptions')
export const supplyForecasts = () => get<Forecast[]>('/forecasts/supply')
export const demandForecasts = () => get<Forecast[]>('/forecasts/demand')
export const shortages = (material: string) => get<Shortage>('/forecasts/shortages', { params: { material } })
