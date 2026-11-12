import { useQuery } from '@tanstack/react-query'
import * as batches from '@/services/batches'
import * as ref from '@/services/reference'
import * as col from '@/services/collections'
import * as cons from '@/services/consignments'
import * as rec from '@/services/recycler'
import * as epr from '@/services/epr'
import * as ngo from '@/services/ngo'
import * as shared from '@/services/shared'
import * as intel from '@/services/intelligence'

/** Query keys are grouped by record type so mutations can invalidate whole groups. */
export const K = {
  batches: ['batches'] as const, batch: (id: string) => ['batches', 'one', id] as const,
  passport: (code: string) => ['batches', 'passport', code] as const, trace: (id: string) => ['batches', 'trace', id] as const,
  events: (id: string) => ['batches', 'events', id] as const, offers: (id: string) => ['batches', 'offers', id] as const,
  materials: ['materials'] as const, orgs: (t?: string) => ['orgs', t ?? 'all'] as const, myOrg: ['orgs', 'me'] as const,
  available: ['collections', 'available'] as const, jobs: ['collections', 'jobs'] as const,
  consignments: ['consignments'] as const,
  incoming: ['recycler', 'incoming'] as const, receipts: (h = false) => ['recycler', 'receipts', h] as const,
  processing: ['recycler', 'processing'] as const, capacity: ['recycler', 'capacity'] as const, yield: ['recycler', 'yield'] as const,
  recOffers: ['recycler', 'offers'] as const,
  allocations: ['epr', 'allocations'] as const, eprDash: (p: string) => ['epr', 'dashboard', p] as const, targets: ['epr', 'targets'] as const,
  eprCerts: ['epr', 'certificates'] as const, eprDisc: ['epr', 'discrepancies'] as const,
  verifications: ['ngo', 'verifications'] as const, verification: (id: string) => ['ngo', 'verifications', id] as const,
  ngoReports: ['ngo', 'reports'] as const, ngoImpact: ['ngo', 'impact'] as const,
  anomalies: ['anomalies'] as const, audit: ['audit'] as const, payments: ['payments'] as const,
  perf: (id: string) => ['performance', id] as const, impact: ['impact'] as const, adminOrgs: (s?: string) => ['admin', 'orgs', s ?? 'all'] as const,
  demand: ['intel', 'demand'] as const, plans: ['intel', 'plans'] as const, plan: (id: string) => ['intel', 'plans', id] as const,
  pricing: ['intel', 'pricing'] as const, supplyFc: ['intel', 'supply'] as const, demandFc: ['intel', 'demandfc'] as const,
  shortage: (m: string) => ['intel', 'shortage', m] as const,
}

const STATIC = { staleTime: 5 * 60_000 }

export const useMaterials = () => useQuery({ queryKey: K.materials, queryFn: ref.listMaterials, ...STATIC })
export const useOrgs = (t?: string) => useQuery({ queryKey: K.orgs(t), queryFn: () => ref.listOrgs(t), ...STATIC })
export const useMyOrg = () => useQuery({ queryKey: K.myOrg, queryFn: ref.myOrg })
export const useImpact = () => useQuery({ queryKey: K.impact, queryFn: ref.impactSummary })

export const useBatches = (params?: { status?: string }) => useQuery({ queryKey: [...K.batches, 'list', params ?? {}], queryFn: () => batches.listBatches(params) })
export const useBatch = (idOrCode?: string) => useQuery({ queryKey: K.batch(idOrCode ?? ''), queryFn: () => batches.getBatch(idOrCode!), enabled: !!idOrCode })
export const usePassport = (code?: string) => useQuery({ queryKey: K.passport(code ?? ''), queryFn: () => batches.passport(code!), enabled: !!code })
export const useTrace = (id?: string) => useQuery({ queryKey: K.trace(id ?? ''), queryFn: () => batches.batchTrace(id!), enabled: !!id })
export const useEvents = (id?: string) => useQuery({ queryKey: K.events(id ?? ''), queryFn: () => batches.batchEvents(id!), enabled: !!id })
export const useOffers = (id?: string) => useQuery({ queryKey: K.offers(id ?? ''), queryFn: () => batches.batchOffers(id!), enabled: !!id })

export const useAvailable = () => useQuery({ queryKey: K.available, queryFn: () => col.availableListings() })
export const useJobs = () => useQuery({ queryKey: K.jobs, queryFn: () => col.collectorJobs() })
export const useConsignments = () => useQuery({ queryKey: K.consignments, queryFn: cons.listConsignments })

export const useIncoming = () => useQuery({ queryKey: K.incoming, queryFn: rec.incoming })
export const useReceipts = (history = false) => useQuery({ queryKey: K.receipts(history), queryFn: () => rec.listReceipts(history) })
export const useProcessing = () => useQuery({ queryKey: K.processing, queryFn: rec.listProcessing })
export const useCapacity = () => useQuery({ queryKey: K.capacity, queryFn: rec.capacity })
export const useYield = () => useQuery({ queryKey: K.yield, queryFn: () => rec.yieldAnalytics() })
export const useRecyclerOffers = () => useQuery({ queryKey: K.recOffers, queryFn: rec.myOffers })

export const useAllocations = () => useQuery({ queryKey: K.allocations, queryFn: () => epr.listAllocations() })
export const useEprDashboard = (p: string) => useQuery({ queryKey: K.eprDash(p), queryFn: () => epr.eprDashboard(p) })
export const useTargets = () => useQuery({ queryKey: K.targets, queryFn: () => epr.listTargets() })
export const useEprCertificates = () => useQuery({ queryKey: K.eprCerts, queryFn: epr.eprCertificates })
export const useEprDiscrepancies = () => useQuery({ queryKey: K.eprDisc, queryFn: epr.eprDiscrepancies })

export const useVerifications = () => useQuery({ queryKey: K.verifications, queryFn: () => ngo.listVerifications() })
export const useVerification = (id?: string) => useQuery({ queryKey: K.verification(id ?? ''), queryFn: () => ngo.getVerification(id!), enabled: !!id })
export const useNgoReports = () => useQuery({ queryKey: K.ngoReports, queryFn: ngo.ngoReports })
export const useNgoImpact = () => useQuery({ queryKey: K.ngoImpact, queryFn: ngo.ngoImpact })

export const useAnomalies = () => useQuery({ queryKey: K.anomalies, queryFn: () => shared.listAnomalies() })
export const useAudit = () => useQuery({ queryKey: K.audit, queryFn: () => shared.auditLogs() })
export const usePayments = () => useQuery({ queryKey: K.payments, queryFn: () => shared.listPayments() })
export const usePerformance = (id?: string) => useQuery({ queryKey: K.perf(id ?? ''), queryFn: () => shared.supplierPerformance(id!), enabled: !!id })
export const useAdminOrgs = (s?: string) => useQuery({ queryKey: K.adminOrgs(s), queryFn: () => shared.adminListOrgs(s) })

export const useDemand = () => useQuery({ queryKey: K.demand, queryFn: intel.listDemand })
export const usePlans = () => useQuery({ queryKey: K.plans, queryFn: intel.listPlans })
export const usePlan = (id?: string) => useQuery({ queryKey: K.plan(id ?? ''), queryFn: () => intel.getPlan(id!), enabled: !!id })
export const usePricing = () => useQuery({ queryKey: K.pricing, queryFn: intel.pricingAssumptions })
export const useSupplyForecasts = () => useQuery({ queryKey: K.supplyFc, queryFn: intel.supplyForecasts })
export const useDemandForecasts = () => useQuery({ queryKey: K.demandFc, queryFn: intel.demandForecasts })
export const useShortage = (m: string) => useQuery({ queryKey: K.shortage(m), queryFn: () => intel.shortages(m) })
