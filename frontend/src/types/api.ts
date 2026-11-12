/**
 * Types mirror the FastAPI schemas and router return shapes in backend/app/modules
 * (audited at commit 55f9ce4 + integration patch). Field names are kept exactly as the API sends them.
 * Quantities in BatchQuantities arrive as strings with three decimals; parse them via lib/quantities.ts.
 */

export type OrgType = 'GENERATOR' | 'COLLECTOR' | 'RECYCLER' | 'NGO' | 'EPR_CLIENT'
export type OrgRole = 'OWNER' | 'ADMIN' | 'MEMBER' | 'VIEWER'
export type Uuid = string
export type IsoDate = string

export type BatchStatus =
  | 'LISTED' | 'ASSIGNED' | 'PICKED_UP' | 'IN_TRANSIT' | 'RECEIVED'
  | 'REJECTED_AT_RECEIPT' | 'PROCESSED' | 'CANCELLED'

export type NgoDecision = 'PENDING' | 'UNDER_REVIEW' | 'VERIFIED' | 'FLAGGED' | 'REJECTED' | 'REQUIRES_CORRECTION'

/* ── Auth ─────────────────────────────────────────────── */
export interface UserOut { id: Uuid; full_name: string; email: string | null; phone: string | null; is_platform_admin: boolean; status: string }
export interface OrgOut {
  id: Uuid; org_type: OrgType; legal_name: string; display_name: string | null; city_id: string; address: string
  lat: number | null; lng: number | null; gstin: string | null; approval_status: string
}
export interface AuthResponse { user: UserOut; org: OrgOut | null; role: OrgRole | null; access_token: string; refresh_token: string; token_type: string }
export interface MembershipOut { org_id: Uuid; org_name: string; org_type: OrgType; org_role: OrgRole; approval_status: string }
export interface MeResponse { user: UserOut; active_org: OrgOut | null; active_role: OrgRole | null; memberships: MembershipOut[] }

/* ── Orgs ─────────────────────────────────────────────── */
export interface OrgProfileDetail extends OrgOut { profile: Record<string, unknown> | null }
export interface DirectoryOrg {
  id: Uuid; org_type: OrgType; legal_name: string; display_name: string | null; city_id: string; approval_status: string
  registration?: Record<string, string | null>; address?: string; gstin?: string | null
}

/* ── Reference ───────────────────────────────────────── */
export interface Material { id: number; code: string; name: string; resin_code: number | null; default_packaging_category: string | null; description: string | null }

/* ── Batches ─────────────────────────────────────────── */
export interface BatchQuantities {
  estimated_kg: string; collected_kg: string | null; received_kg: string | null; accepted_kg: string | null
  rejected_kg: string | null; processed_kg: string | null; ngo_verified_kg: string | null; epr_allocated_kg: string | null
}
export interface VerificationSummary { decision: NgoDecision; ngo: string | null; at: IsoDate | null; comments: string | null }
export interface Batch {
  id: Uuid; batch_code: string; qr_token: string; status: BatchStatus; material: string; material_name: string | null
  generator_org_id: Uuid; generator_name: string | null; pickup_address: string; locality: string | null
  lat: number | null; lng: number | null; available_from: IsoDate; available_to: IsoDate
  assigned_collector_org_id: Uuid | null; assigned_collector_name: string | null
  destination_recycler_org_id: Uuid | null; destination_recycler_name: string | null
  quantities: BatchQuantities; verification: VerificationSummary | null; created_at: IsoDate
}
export interface BatchCreateInput {
  material_code: string; estimated_kg: number; pickup_address: string; lat?: number | null; lng?: number | null
  locality?: string | null; available_from: IsoDate; available_to: IsoDate; document_ids?: Uuid[]; ai_prediction_id?: Uuid | null
}
export interface BatchCreated { id: Uuid; batch_code: string; qr_token: string; status: BatchStatus; qr_url: string }
export interface BatchEvent {
  id: number; batch_id: Uuid; event_type: string; from_status: string | null; to_status: string | null
  actor_user_id: Uuid | null; actor_org_id: Uuid | null; payload: Record<string, unknown>; created_at: IsoDate
}
export interface BatchTrace {
  batch_id: Uuid; batch_code: string; status: BatchStatus
  pickup: { collected_kg: number; confirmed_at: IsoDate | null; handover_method: string } | null
  receipt: { received_kg: number; accepted_kg: number; rejected_kg: number; quality_grade: string } | null
  processing_runs: { record_code: string; run_started_at: IsoDate; input_kg: number; apportioned_output_kg: number; yield_pct: number | null; measurement_status: string }[]
}

/* ── Passport ────────────────────────────────────────── */
export interface Passport {
  batch_code: string; qr_token: string; status: BatchStatus
  material: { code: string; name: string | null; resin_code: number | null }
  generator: { generator_type: string; locality: string | null; city_id: string; legal_name?: string | null; address?: string }
  quantities: BatchQuantities
  custody: {
    pickup_records: { version: number; is_current: boolean; collected_kg: number; rate: number; confirmed_at: IsoDate | null; handover_method: string }[]
    consignment: { consignment_code: string; vehicle_no: string | null; status: string } | null
    receipts: { version: number; is_current: boolean; received_kg: number; accepted_kg: number; rejected_kg: number; quality_grade: string; contamination_pct: number; received_at: IsoDate }[]
    processing_runs: { record_code: string; input_kg: number; apportioned_output_kg: number; run_yield_pct: number | null; measurement_status: string; output_form: string | null; run_started_at: IsoDate; run_ended_at: IsoDate | null }[]
  }
  statutory_certificates: { certificate_ref: string; packaging_category: string; certificate_kg: number; issued_on: string | null; status: string }[]
  verifications: { decision: NgoDecision; ngo_name: string | null; comments: string | null; is_current: boolean; created_at: IsoDate }[]
  epr_allocations: { allocation_id: Uuid; reporting_period: string; packaging_category: string; quantity_kg: number; status: string; is_reversal: boolean; created_at: IsoDate }[]
  documents: { doc_type: string; sha256: string | null; mime_type: string | null; created_at: IsoDate }[]
  anomalies: { rule_code: string; severity: string; status: string; created_at: IsoDate }[]
}

/* ── Collections ─────────────────────────────────────── */
export interface AvailableListing {
  id: Uuid; batch_code: string; material_category_id: number; estimated_kg: number; pickup_address: string
  locality: string | null; lat: number | null; lng: number | null; distance_km: number; available_from: IsoDate; available_to: IsoDate
}
export interface CollectionOffer {
  id: Uuid; batch_id: Uuid; collector_org_id: Uuid; collector_name: string | null; generator_rate_per_kg: number
  proposed_pickup_at: IsoDate; status: 'OPEN' | 'ACCEPTED' | 'DECLINED' | 'EXPIRED' | string; expires_at: IsoDate; created_at: IsoDate
}
export interface PickupResult { pickup_record_id: Uuid; otp_required: boolean; otp: string; message: string }
export interface CollectorJob { batch_id: Uuid; batch_code: string; status: BatchStatus; estimated_kg: number; pickup_address: string; locality: string | null; created_at: IsoDate }

/* ── Consignments ────────────────────────────────────── */
export interface Consignment {
  id: Uuid; consignment_code: string; collector_org_id: Uuid; destination_recycler_org_id: Uuid; vehicle_no: string | null
  dispatched_at: IsoDate; arrived_at: IsoDate | null; status: 'IN_TRANSIT' | 'ARRIVED' | string
  items: { batch_id: Uuid; batch_code: string; status: BatchStatus; estimated_kg: number }[]
}

/* ── Recycler ────────────────────────────────────────── */
export interface IncomingBatch { batch_id: Uuid; batch_code: string; qr_token: string; estimated_kg: number; status: BatchStatus; locality: string | null; pickup_address: string }
export interface ReceiptInput {
  batch_id?: Uuid; qr_token?: string; received_kg: number; accepted_kg: number; rejected_kg: number
  quality_grade: string; contamination_pct: number; rejection_disposition?: string | null; document_ids?: Uuid[]
}
export interface Receipt {
  id: Uuid; batch_id: Uuid; batch_code: string; batch_status: BatchStatus; material_code: string; version: number; is_current: boolean
  supersedes_id: Uuid | null; received_kg: number; accepted_kg: number; rejected_kg: number; quality_grade: string
  contamination_pct: number; rejection_disposition: string | null; received_at: IsoDate
  processed_input_kg: number | null; available_kg: number | null
}
export interface ProcessingRecordInput {
  material_code: string; run_started_at: IsoDate; run_ended_at: IsoDate
  inputs: { recycler_receipt_id: Uuid; input_kg: number }[]
  output_kg: number; residue_kg: number; output_form?: string | null; eligible_kg: number; eligibility_basis?: string | null; document_ids?: Uuid[]
}
export interface ProcessingRecord {
  id: Uuid; record_code: string; material_code: string; run_started_at: IsoDate; run_ended_at: IsoDate | null
  input_kg: number; output_kg: number; residue_kg: number; eligible_kg: number; allocated_kg: number; available_kg: number
  yield_pct: number | null; measurement_status: string
}
export interface RecyclerOffer { id: Uuid; recycler_org_id: Uuid; material_code: string; price_per_kg: number; min_kg: number; quality_spec: string | null; max_contamination_pct: number; valid_from: IsoDate; valid_to: IsoDate; is_active: boolean }
export interface Capacity { monthly_capacity_kg: number; processed_this_month_kg: number; utilization_pct: number; remaining_capacity_kg: number }
export interface YieldAnalytics {
  average_yield_pct: number; completed_runs_count: number; incomplete_runs_count: number
  completed_runs: { record_code: string; material: string; input_kg: number; output_kg: number; residue_kg: number; yield_pct: number; run_started_at: IsoDate }[]
  incomplete_runs: YieldAnalytics['completed_runs']
}

/* ── EPR ─────────────────────────────────────────────── */
export interface EprTarget { id: Uuid; epr_org_id: Uuid; reporting_period: string; packaging_category: string; target_kg: number; source_note: string | null }
export interface Allocation {
  id: Uuid; processing_record_id: Uuid; epr_org_id: Uuid; certificate_id: Uuid | null; packaging_category: string
  reporting_period: string; quantity_kg: number; status: 'ACTIVE' | 'REVERSED' | string; reverses_allocation_id: Uuid | null; reason: string | null; created_at: IsoDate
}
export interface AllocationCreateInput { processing_record_id: Uuid; epr_org_id: Uuid; certificate_id?: Uuid | null; packaging_category: string; reporting_period: string; quantity_kg: number }
export interface EprDashboard {
  reporting_period: string; total_target_kg: number; total_allocated_kg: number; verified_allocated_kg: number
  unverified_allocated_kg: number; pending_kg: number; compliance_pct: number; targets_by_category: { category: string; target_kg: number }[]
}
export interface EprCertificate { certificate_id: Uuid; certificate_ref: string; packaging_category: string; certificate_kg: number; issued_on: string | null; status: string }
export interface EprDiscrepancy { flag_id: Uuid; batch_id: Uuid | null; rule_code: string; severity: string; status: string; details: Record<string, unknown>; created_at: IsoDate }

/* ── NGO ─────────────────────────────────────────────── */
export interface VerificationListItem {
  id: Uuid; batch_id: Uuid; batch_code: string; material_category_id: number; estimated_kg: number; status: BatchStatus
  decision: NgoDecision; reviewer_user_id: Uuid | null; comments: string | null; created_at: IsoDate
}
export interface VerificationDetail {
  verification: { id: Uuid; batch_id: Uuid; decision: NgoDecision; reviewer_user_id: Uuid | null; comments: string | null; follow_up_required: string | null; created_at: IsoDate }
  batch: { batch_code: string; status: BatchStatus; estimated_kg: number; locality: string | null; pickup_address: string }
  custody: {
    pickup_records: { id: Uuid; version: number; is_current: boolean; collected_kg: number; rate: number; confirmed_at: IsoDate | null }[]
    recycler_receipts: { id: Uuid; version: number; is_current: boolean; received_kg: number; accepted_kg: number; rejected_kg: number; quality_grade: string; contamination_pct: number }[]
  }
  anomalies: { id: Uuid; rule_code: string; severity: string; status: string; details: Record<string, unknown> }[]
  documents: { id: Uuid; doc_type: string; sha256: string | null; mime_type: string | null }[]
}
export interface NgoImpact { total_verified_kg: number; verified_batch_count: number; co2_saved_kg_est: number; fossil_fuel_offset_liters_est: number }

/* ── Shared ──────────────────────────────────────────── */
export interface Anomaly {
  id: Uuid; rule_code: string; severity: string; batch_id: Uuid | null; entity_type: string | null; entity_id: Uuid | null
  details: Record<string, unknown> | null; status: string; resolved_by_user_id: Uuid | null; resolution_note: string | null; created_at: IsoDate
}
export interface AuditLog { id: number; actor_user_id: Uuid | null; actor_org_id: Uuid | null; action: string; entity_type: string; entity_id: Uuid | null; before: unknown; after: unknown; prev_hash: string | null; row_hash: string | null; created_at: IsoDate }
export interface Payment { id: Uuid; batch_id: Uuid | null; payment_type: string; payer_org_id: Uuid | null; payee_org_id: Uuid | null; quantity_kg: number | null; rate: number | null; amount: number; status: 'PENDING' | 'PAID' | string; external_ref: string | null; created_at: IsoDate }
export interface SupplierPerformance {
  org_id: Uuid; role: string; history_level: string; n_transactions: number; fulfilment_rate: number | null; on_time_rate: number | null
  weight_discrepancy_pct: number | null; rejection_rate: number | null; contamination_rate: number | null; completion_rate: number | null
}
export interface ImpactSummary {
  pilot_city: string; total_batches: number
  stages: { collected_kg: number; received_kg: number; accepted_kg: number; processed_output_kg: number; epr_allocated_kg: number; verified_batches_count: number }
  environmental_impact: { co2_avoided_kg: number; trees_equivalent: number; landfill_diverted_kg: number }
}

/* ── Intelligence ────────────────────────────────────── */
export interface DemandProfile { id: Uuid; material_code: string; recurrence: string; quantity_kg: number; min_quality_grade: string; max_contamination_pct: number; need_by: string | null; status: string }
export interface PlanSummary { id: Uuid; plan_code: string; target_kg: number; est_total_kg: number; est_usable_kg: number; fulfils_requirement: boolean; status: string; created_at: IsoDate }
export interface PlanDetail {
  id: Uuid; plan_code: string; target_kg: number; est_total_kg: number; est_usable_kg: number; fulfils_requirement: boolean; shortfall_kg: number; status: string
  items: { batch_id: Uuid; batch_code: string; planned_kg: number; est_usable_kg: number; distance_km: number; reasons: Record<string, string>; item_status: string }[]
  cost_estimate: { total_cost: number; landed_cost_per_usable_kg: number; breakdown: Record<string, number> } | null
  explanation: Record<string, unknown>
}
export interface ProposePlanResult {
  plan_id: Uuid; plan_code: string; target_kg: number; est_total_kg: number; est_usable_kg: number; fulfils_requirement: boolean; shortfall_kg: number
  items: { batch_id: Uuid; batch_code: string; planned_kg: number; distance_km: number }[]
  cost_estimate: { total_cost: number; landed_cost_per_usable_kg: number; generator_payment: number; collector_charge: number; transport_cost: number }
  excluded: { batch_id: Uuid; batch_code: string; reason: string }[]
}
export interface CostEstimate { estimate_id: Uuid; est_kg: number; expected_usable_kg: number; total_cost: number; landed_cost_per_usable_kg: number; generator_receives: number; collector_expected_earnings: number; breakdown: Record<string, number> }
export interface CompareResult { ranked_options: { name: string; type: string; est_kg: number; usable_kg: number; total_cost: number; landed_cost_per_usable_kg: number; breakdown: Record<string, number> }[] }
export interface PricingAssumptions {
  id: Uuid; version: number; transport_per_km: number; transport_per_kg_km: number; sorting_per_kg: number; handling_per_kg: number
  storage_per_kg_day: number; rejection_cost_per_kg: number; default_rejection_rate: Record<string, number> | null; default_process_loss_rate: Record<string, number> | null; is_active: boolean
}
export interface Forecast { kind: string; locality?: string; material_category_id: number; period_start: string; period_end: string; predicted_kg: number; lower_kg?: number | null; upper_kg?: number | null; confidence_label: string | null }
export interface Shortage { material: string; demand_kg: number; confirmed_supply_kg: number; predicted_supply_kg: number; gap_confirmed_kg: number; gap_expected_kg: number }
