/* ── ReLoop Domain & UI TypeScript Interfaces ─────────────────── */

export type UserRole =
  | 'generator'
  | 'collector'
  | 'recycler'
  | 'ngo'
  | 'epr_body'
  | 'admin'

export interface User {
  id: string
  email: string
  name: string
  role: UserRole
  org_id: string
  org_name: string
  phone?: string
  avatar?: string
}

export interface DemoPersona {
  id: string
  name: string
  role: UserRole
  org_id: string
  org_name: string
  org_type_label: string
  email: string
  avatar: string
  badge_color: string
  description: string
}

export type BatchStatus =
  | 'LISTED'
  | 'ASSIGNED'
  | 'PICKED_UP'
  | 'IN_TRANSIT'
  | 'RECEIVED'
  | 'PROCESSED'
  | 'REJECTED_AT_RECEIPT'
  | 'CANCELLED'

export type PolymerType = 'PET' | 'HDPE' | 'PP' | 'LDPE' | 'OTHER'

export type PackagingCategory = 'Cat-I' | 'Cat-II' | 'Cat-III' | 'Cat-IV'

export interface BatchQuantities {
  estimated_kg: number
  collected_kg?: number
  received_kg?: number
  accepted_kg?: number
  rejected_kg?: number
  processed_kg?: number
  verified_kg?: number
  allocated_kg?: number
}

export interface BatchEvent {
  id: string
  stage: string
  title: string
  description: string
  timestamp: string
  actor: string
  actor_role: string
  metadata?: Record<string, any>
}

export interface CollectionOffer {
  id: string
  batch_id: string
  collector_org_id: string
  collector_name: string
  rate_per_kg: number
  proposed_pickup_at: string
  match_score: number
  status: 'PENDING' | 'ACCEPTED' | 'DECLINED' | 'WITHDRAWN'
  score_breakdown: {
    distance_score: number
    reliability_score: number
    capacity_score: number
    reasons: string[]
  }
  created_at: string
}

export interface NGOVerification {
  id: string
  batch_id: string
  batch_code: string
  processing_run_id?: string
  reviewer_id?: string
  reviewer_name?: string
  decision: 'PENDING' | 'UNDER_REVIEW' | 'VERIFIED' | 'FLAGGED' | 'REJECTED' | 'REQUIRES_CORRECTION'
  comments?: string
  evidence_reviewed: string[]
  variance_pct: number
  updated_at: string
  version: number
}

export interface WasteBatch {
  id: string
  batch_code: string
  generator_org_id: string
  generator_name: string
  material: PolymerType
  packaging_category: PackagingCategory
  quantities: BatchQuantities
  status: BatchStatus
  pickup_address: string
  locality: string
  lat: number
  lng: number
  available_from: string
  available_to: string
  photos: string[]
  qr_code_url: string
  created_at: string
  offers?: CollectionOffer[]
  current_offer_id?: string
  pickup_otp?: string
  collector_org_id?: string
  collector_name?: string
  consignment_id?: string
  recycler_org_id?: string
  recycler_name?: string
  verification?: NGOVerification
  quality_grade?: 'A' | 'B' | 'C'
  contamination_pct?: number
  rejection_reason?: string
}

export interface Consignment {
  id: string
  consignment_code: string
  collector_org_id: string
  collector_name: string
  destination_recycler_id: string
  destination_recycler_name: string
  vehicle_no: string
  batch_ids: string[]
  status: 'CREATED' | 'IN_TRANSIT' | 'ARRIVED' | 'RECEIVED'
  created_at: string
}

export interface RecyclerReceipt {
  id: string
  batch_id: string
  batch_code: string
  recycler_org_id: string
  received_kg: number
  accepted_kg: number
  rejected_kg: number
  quality_grade: 'A' | 'B' | 'C'
  contamination_pct: number
  rejection_disposition: string
  documents: string[]
  timestamp: string
  version: number
}

export interface ProcessingRunInput {
  batch_id: string
  batch_code: string
  receipt_id: string
  input_kg: number
}

export interface ProcessingRun {
  id: string
  run_code: string
  recycler_org_id: string
  recycler_name: string
  material_code: PolymerType
  packaging_category: PackagingCategory
  run_started_at: string
  run_ended_at: string
  inputs: ProcessingRunInput[]
  input_kg: number
  output_kg: number
  residue_kg: number
  output_form: 'Pellets' | 'Flakes' | 'Granules'
  eligible_kg: number
  allocated_kg: number
  measurement_status: 'COMPLETE' | 'INCOMPLETE'
  yield_pct: number
  certificate_refs: string[]
  created_at: string
}

export interface EPRAllocation {
  id: string
  allocation_code: string
  processing_run_id: string
  run_code: string
  epr_org_id: string
  epr_org_name: string
  recycler_org_id: string
  recycler_name: string
  batch_codes: string[]
  packaging_category: PackagingCategory
  reporting_period: string
  quantity_kg: number
  status: 'ACTIVE' | 'REVERSED'
  certificate_id: string
  is_ngo_verified: boolean
  created_at: string
  reversal_reason?: string
}

export interface EPRTarget {
  id: string
  category: PackagingCategory
  category_label: string
  period: string
  target_kg: number
  allocated_kg: number
  verified_kg: number
  unverified_kg: number
}

export interface AggregationPlanItem {
  batch_id: string
  batch_code: string
  locality: string
  address: string
  kg: number
  sequence_no: number
  reasons: string[]
}

export interface AggregationPlanExcluded {
  batch_id: string
  batch_code: string
  locality: string
  kg: number
  reason: string
}

export interface AggregationPlan {
  id: string
  plan_code: string
  recycler_org_id: string
  material_code: PolymerType
  target_kg: number
  suggested_collector_id: string
  suggested_collector_name: string
  items: AggregationPlanItem[]
  excluded: AggregationPlanExcluded[]
  status: 'PROPOSED' | 'ACCEPTED' | 'ACTIVE' | 'COMPLETED' | 'CANCELLED'
  total_estimated_kg: number
  expected_usable_kg: number
  collection_cost: number
  landed_cost_per_usable_kg: number
  stops_count: number
  need_by: string
  created_at: string
}

export interface CostBreakdownItem {
  option_name: string
  type: 'Single Supplier' | 'Collector Direct' | 'Aggregation Plan' | 'Spot Market'
  purchase_cost: number
  collection_cost: number
  transport_cost: number
  sorting_cost: number
  storage_cost: number
  rejection_cost: number
  total_cost: number
  usable_kg: number
  cost_per_usable_kg: number
}

export interface AnomalyFlag {
  id: string
  code: string
  severity: 'LOW' | 'MEDIUM' | 'HIGH' | 'CRITICAL'
  title: string
  description: string
  batch_code?: string
  org_name?: string
  status: 'OPEN' | 'RESOLVED'
  created_at: string
}
