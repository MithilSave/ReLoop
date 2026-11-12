import React, { createContext, useContext, useState, useEffect } from 'react'
import type {
  User,
  DemoPersona,
  WasteBatch,
  Consignment,
  ProcessingRun,
  EPRAllocation,
  EPRTarget,
  AggregationPlan,
  AnomalyFlag,
  PolymerType,
  PackagingCategory,
  NGOVerification,
} from '../types'
import {
  DEMO_PERSONAS,
  INITIAL_BATCHES,
  INITIAL_CONSIGNMENTS,
  INITIAL_PROCESSING_RUNS,
  INITIAL_ALLOCATIONS,
  INITIAL_EPR_TARGETS,
  INITIAL_AGGREGATION_PLANS,
  INITIAL_ANOMALIES,
} from './demoData'

interface AppContextType {
  currentPersona: DemoPersona
  setPersona: (personaId: string) => void
  user: User
  batches: WasteBatch[]
  consignments: Consignment[]
  processingRuns: ProcessingRun[]
  allocations: EPRAllocation[]
  eprTargets: EPRTarget[]
  aggregationPlans: AggregationPlan[]
  anomalies: AnomalyFlag[]
  
  // Actions
  createBatch: (data: {
    material: PolymerType
    packaging_category: PackagingCategory
    estimated_kg: number
    pickup_address: string
    locality: string
    available_from: string
    available_to: string
    photos?: string[]
  }) => WasteBatch
  acceptOffer: (batchId: string, offerId: string) => void
  makeOffer: (batchId: string, rate_per_kg: number, proposed_pickup_at: string) => void
  completePickup: (batchId: string, collected_kg: number, otp: string) => { success: boolean; error?: string }
  createConsignment: (batchIds: string[], destinationRecyclerId: string, destinationRecyclerName: string, vehicleNo: string) => Consignment
  receiveBatch: (
    batchId: string,
    received_kg: number,
    accepted_kg: number,
    rejected_kg: number,
    quality_grade: 'A' | 'B' | 'C',
    contamination_pct: number,
    rejection_disposition?: string
  ) => void
  createProcessingRun: (data: {
    material_code: PolymerType
    packaging_category: PackagingCategory
    batch_ids: string[]
    output_kg: number
    residue_kg: number
    output_form: 'Pellets' | 'Flakes' | 'Granules'
    certificate_ref: string
  }) => ProcessingRun
  submitNGOVerification: (
    batchId: string,
    decision: 'VERIFIED' | 'FLAGGED' | 'REJECTED' | 'REQUIRES_CORRECTION',
    comments: string,
    evidenceDocs?: string[]
  ) => void
  createEPRAllocation: (
    processingRunId: string,
    eprOrgId: string,
    eprOrgName: string,
    quantity_kg: number,
    period: string
  ) => { success: boolean; error?: string }
  reverseEPRAllocation: (allocationId: string, reason: string) => void
  acceptAggregationPlan: (planId: string) => void
  resolveAnomaly: (anomalyId: string) => void
  resetDemoData: () => void
}

const AppContext = createContext<AppContextType | undefined>(undefined)

export const AppProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [personaId, setPersonaId] = useState<string>(() => {
    return localStorage.getItem('reloop_persona_id') || 'persona-gen'
  })

  const [batches, setBatches] = useState<WasteBatch[]>(() => {
    const saved = localStorage.getItem('reloop_batches')
    return saved ? JSON.parse(saved) : INITIAL_BATCHES
  })

  const [consignments, setConsignments] = useState<Consignment[]>(() => {
    const saved = localStorage.getItem('reloop_consignments')
    return saved ? JSON.parse(saved) : INITIAL_CONSIGNMENTS
  })

  const [processingRuns, setProcessingRuns] = useState<ProcessingRun[]>(() => {
    const saved = localStorage.getItem('reloop_processing_runs')
    return saved ? JSON.parse(saved) : INITIAL_PROCESSING_RUNS
  })

  const [allocations, setAllocations] = useState<EPRAllocation[]>(() => {
    const saved = localStorage.getItem('reloop_allocations')
    return saved ? JSON.parse(saved) : INITIAL_ALLOCATIONS
  })

  const [eprTargets, setEprTargets] = useState<EPRTarget[]>(() => {
    const saved = localStorage.getItem('reloop_epr_targets')
    return saved ? JSON.parse(saved) : INITIAL_EPR_TARGETS
  })

  const [aggregationPlans, setAggregationPlans] = useState<AggregationPlan[]>(() => {
    const saved = localStorage.getItem('reloop_aggregation_plans')
    return saved ? JSON.parse(saved) : INITIAL_AGGREGATION_PLANS
  })

  const [anomalies, setAnomalies] = useState<AnomalyFlag[]>(() => {
    const saved = localStorage.getItem('reloop_anomalies')
    return saved ? JSON.parse(saved) : INITIAL_ANOMALIES
  })

  useEffect(() => {
    localStorage.setItem('reloop_batches', JSON.stringify(batches))
  }, [batches])

  useEffect(() => {
    localStorage.setItem('reloop_consignments', JSON.stringify(consignments))
  }, [consignments])

  useEffect(() => {
    localStorage.setItem('reloop_processing_runs', JSON.stringify(processingRuns))
  }, [processingRuns])

  useEffect(() => {
    localStorage.setItem('reloop_allocations', JSON.stringify(allocations))
  }, [allocations])

  useEffect(() => {
    localStorage.setItem('reloop_aggregation_plans', JSON.stringify(aggregationPlans))
  }, [aggregationPlans])

  useEffect(() => {
    localStorage.setItem('reloop_anomalies', JSON.stringify(anomalies))
  }, [anomalies])

  useEffect(() => {
    localStorage.setItem('reloop_persona_id', personaId)
  }, [personaId])

  const currentPersona = DEMO_PERSONAS.find((p) => p.id === personaId) || DEMO_PERSONAS[0]

  const user: User = {
    id: currentPersona.id,
    email: currentPersona.email,
    name: currentPersona.name,
    role: currentPersona.role,
    org_id: currentPersona.org_id,
    org_name: currentPersona.org_name,
    avatar: currentPersona.avatar,
  }

  const setPersona = (id: string) => {
    setPersonaId(id)
  }

  const createBatch = (data: {
    material: PolymerType
    packaging_category: PackagingCategory
    estimated_kg: number
    pickup_address: string
    locality: string
    available_from: string
    available_to: string
    photos?: string[]
  }): WasteBatch => {
    const nextNum = 130 + batches.length
    const batchCode = `RL-MUM-2026-000${nextNum}`
    const newBatch: WasteBatch = {
      id: `batch-${Date.now()}`,
      batch_code: batchCode,
      generator_org_id: currentPersona.org_id,
      generator_name: currentPersona.org_name,
      material: data.material,
      packaging_category: data.packaging_category,
      quantities: {
        estimated_kg: data.estimated_kg,
      },
      status: 'LISTED',
      pickup_address: data.pickup_address,
      locality: data.locality,
      lat: 19.1197 + (Math.random() - 0.5) * 0.05,
      lng: 72.8464 + (Math.random() - 0.5) * 0.05,
      available_from: data.available_from,
      available_to: data.available_to,
      photos: data.photos && data.photos.length > 0 ? data.photos : [
        'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=600&q=80',
      ],
      qr_code_url: `/b/${batchCode}`,
      created_at: new Date().toISOString(),
      offers: [],
    }

    setBatches((prev) => [newBatch, ...prev])
    return newBatch
  }

  const acceptOffer = (batchId: string, offerId: string) => {
    setBatches((prev) =>
      prev.map((b) => {
        if (b.id !== batchId) return b
        const chosenOffer = b.offers?.find((o) => o.id === offerId)
        if (!chosenOffer) return b

        const updatedOffers = b.offers?.map((o) => ({
          ...o,
          status: o.id === offerId ? ('ACCEPTED' as const) : ('DECLINED' as const),
        }))

        // Generate 6-digit OTP for generator pickup verification
        const generatedOtp = Math.floor(100000 + Math.random() * 900000).toString()

        return {
          ...b,
          status: 'ASSIGNED',
          current_offer_id: offerId,
          collector_org_id: chosenOffer.collector_org_id,
          collector_name: chosenOffer.collector_name,
          pickup_otp: generatedOtp,
          offers: updatedOffers,
        }
      })
    )
  }

  const makeOffer = (batchId: string, rate_per_kg: number, proposed_pickup_at: string) => {
    setBatches((prev) =>
      prev.map((b) => {
        if (b.id !== batchId) return b
        const newOffer = {
          id: `off-${Date.now()}`,
          batch_id: b.id,
          collector_org_id: currentPersona.org_id,
          collector_name: currentPersona.org_name,
          rate_per_kg,
          proposed_pickup_at,
          match_score: 95,
          status: 'PENDING' as const,
          score_breakdown: {
            distance_score: 94,
            reliability_score: 98,
            capacity_score: 92,
            reasons: ['Fast route corridor pickup', 'Verified weighing scales', 'High historical acceptance'],
          },
          created_at: new Date().toISOString(),
        }
        return {
          ...b,
          offers: [...(b.offers || []), newOffer],
        }
      })
    )
  }

  const completePickup = (batchId: string, collected_kg: number, otp: string) => {
    const target = batches.find((b) => b.id === batchId)
    if (!target) return { success: false, error: 'Batch not found' }
    if (target.pickup_otp && target.pickup_otp !== otp.trim()) {
      return { success: false, error: 'Invalid 6-digit OTP provided by generator' }
    }

    setBatches((prev) =>
      prev.map((b) => {
        if (b.id !== batchId) return b
        return {
          ...b,
          status: 'PICKED_UP',
          quantities: {
            ...b.quantities,
            collected_kg,
          },
        }
      })
    )
    return { success: true }
  }

  const createConsignment = (
    batchIds: string[],
    destinationRecyclerId: string,
    destinationRecyclerName: string,
    vehicleNo: string
  ): Consignment => {
    const code = `CS-MUM-2026-00${42 + consignments.length}`
    const newConsignment: Consignment = {
      id: `cons-${Date.now()}`,
      consignment_code: code,
      collector_org_id: currentPersona.org_id,
      collector_name: currentPersona.org_name,
      destination_recycler_id: destinationRecyclerId,
      destination_recycler_name: destinationRecyclerName,
      vehicle_no: vehicleNo,
      batch_ids: batchIds,
      status: 'IN_TRANSIT',
      created_at: new Date().toISOString(),
    }

    setConsignments((prev) => [newConsignment, ...prev])

    // Update batch statuses to IN_TRANSIT
    setBatches((prev) =>
      prev.map((b) => {
        if (batchIds.includes(b.id)) {
          return {
            ...b,
            status: 'IN_TRANSIT',
            consignment_id: newConsignment.id,
            recycler_org_id: destinationRecyclerId,
            recycler_name: destinationRecyclerName,
          }
        }
        return b
      })
    )

    return newConsignment
  }

  const receiveBatch = (
    batchId: string,
    received_kg: number,
    accepted_kg: number,
    rejected_kg: number,
    quality_grade: 'A' | 'B' | 'C',
    contamination_pct: number,
    rejection_disposition?: string
  ) => {
    setBatches((prev) =>
      prev.map((b) => {
        if (b.id !== batchId) return b
        return {
          ...b,
          status: accepted_kg > 0 ? 'RECEIVED' : 'REJECTED_AT_RECEIPT',
          quality_grade,
          contamination_pct,
          rejection_reason: rejection_disposition,
          quantities: {
            ...b.quantities,
            received_kg,
            accepted_kg,
            rejected_kg,
          },
        }
      })
    )
  }

  const createProcessingRun = (data: {
    material_code: PolymerType
    packaging_category: PackagingCategory
    batch_ids: string[]
    output_kg: number
    residue_kg: number
    output_form: 'Pellets' | 'Flakes' | 'Granules'
    certificate_ref: string
  }): ProcessingRun => {
    const runCode = `PR-APEX-2026-00${44 + processingRuns.length}`
    const selectedBatches = batches.filter((b) => data.batch_ids.includes(b.id))
    const totalInputKg = selectedBatches.reduce((acc, b) => acc + (b.quantities.accepted_kg || 0), 0)
    const yieldPct = totalInputKg > 0 ? Number(((data.output_kg / totalInputKg) * 100).toFixed(1)) : 0

    const runInputs = selectedBatches.map((b) => ({
      batch_id: b.id,
      batch_code: b.batch_code,
      receipt_id: `rcpt-${b.id}`,
      input_kg: b.quantities.accepted_kg || 0,
    }))

    const newRun: ProcessingRun = {
      id: `run-${Date.now()}`,
      run_code: runCode,
      recycler_org_id: currentPersona.org_id,
      recycler_name: currentPersona.org_name,
      material_code: data.material_code,
      packaging_category: data.packaging_category,
      run_started_at: new Date(Date.now() - 3600000 * 8).toISOString(),
      run_ended_at: new Date().toISOString(),
      inputs: runInputs,
      input_kg: totalInputKg,
      output_kg: data.output_kg,
      residue_kg: data.residue_kg,
      output_form: data.output_form,
      eligible_kg: data.output_kg,
      allocated_kg: 0,
      measurement_status: 'COMPLETE',
      yield_pct: yieldPct,
      certificate_refs: [data.certificate_ref],
      created_at: new Date().toISOString(),
    }

    setProcessingRuns((prev) => [newRun, ...prev])

    // Update batch statuses to PROCESSED and calculate pro-rata output kg
    setBatches((prev) =>
      prev.map((b) => {
        if (data.batch_ids.includes(b.id)) {
          const accepted = b.quantities.accepted_kg || 0
          const proRataProcessed = totalInputKg > 0 ? Number(((accepted / totalInputKg) * data.output_kg).toFixed(1)) : accepted
          return {
            ...b,
            status: 'PROCESSED',
            quantities: {
              ...b.quantities,
              processed_kg: proRataProcessed,
            },
            verification: {
              id: `ver-${Date.now()}-${b.id}`,
              batch_id: b.id,
              batch_code: b.batch_code,
              processing_run_id: newRun.id,
              decision: 'PENDING',
              comments: 'Enqueued for NGO auditor review post-pelletizing.',
              evidence_reviewed: ['weighbridge_slip.pdf', 'run_yield_log.pdf'],
              variance_pct: 0.4,
              updated_at: new Date().toISOString(),
              version: 1,
            },
          }
        }
        return b
      })
    )

    return newRun
  }

  const submitNGOVerification = (
    batchId: string,
    decision: 'VERIFIED' | 'FLAGGED' | 'REJECTED' | 'REQUIRES_CORRECTION',
    comments: string,
    evidenceDocs?: string[]
  ) => {
    setBatches((prev) =>
      prev.map((b) => {
        if (b.id !== batchId) return b
        const currentVer = b.verification
        const processedKg = b.quantities.processed_kg || 0
        const verifiedKg = decision === 'VERIFIED' ? processedKg : 0

        const newVerification: NGOVerification = {
          id: currentVer?.id || `ver-${Date.now()}`,
          batch_id: b.id,
          batch_code: b.batch_code,
          processing_run_id: currentVer?.processing_run_id,
          reviewer_id: currentPersona.id,
          reviewer_name: currentPersona.name,
          decision,
          comments,
          evidence_reviewed: evidenceDocs || currentVer?.evidence_reviewed || ['audit_report.pdf'],
          variance_pct: currentVer?.variance_pct || 0.5,
          updated_at: new Date().toISOString(),
          version: (currentVer?.version || 0) + 1,
        }

        return {
          ...b,
          verification: newVerification,
          quantities: {
            ...b.quantities,
            verified_kg: verifiedKg,
          },
        }
      })
    )
  }

  const createEPRAllocation = (
    processingRunId: string,
    eprOrgId: string,
    eprOrgName: string,
    quantity_kg: number,
    period: string
  ) => {
    const run = processingRuns.find((r) => r.id === processingRunId)
    if (!run) return { success: false, error: 'Processing run not found' }

    const remainingEligible = run.eligible_kg - run.allocated_kg
    if (quantity_kg > remainingEligible) {
      return {
        success: false,
        error: `Requested ${quantity_kg.toFixed(1)} kg exceeds remaining eligible ${remainingEligible.toFixed(1)} kg`,
      }
    }

    const allocCode = `AL-EPR-2026-00${91 + allocations.length}`
    const inputBatchCodes = run.inputs.map((inp) => inp.batch_code)

    const newAlloc: EPRAllocation = {
      id: `alloc-${Date.now()}`,
      allocation_code: allocCode,
      processing_run_id: run.id,
      run_code: run.run_code,
      epr_org_id: eprOrgId,
      epr_org_name: eprOrgName,
      recycler_org_id: run.recycler_org_id,
      recycler_name: run.recycler_name,
      batch_codes: inputBatchCodes,
      packaging_category: run.packaging_category,
      reporting_period: period,
      quantity_kg,
      status: 'ACTIVE',
      certificate_id: run.certificate_refs[0] || 'CPCB/PWM/2026/MH/GEN',
      is_ngo_verified: true,
      created_at: new Date().toISOString(),
    }

    setAllocations((prev) => [newAlloc, ...prev])

    // Update processing run allocated balance
    setProcessingRuns((prev) =>
      prev.map((r) => {
        if (r.id === processingRunId) {
          return {
            ...r,
            allocated_kg: r.allocated_kg + quantity_kg,
          }
        }
        return r
      })
    )

    // Update targets
    setEprTargets((prev) =>
      prev.map((tgt) => {
        if (tgt.category === run.packaging_category) {
          return {
            ...tgt,
            allocated_kg: tgt.allocated_kg + quantity_kg,
            verified_kg: tgt.verified_kg + quantity_kg,
          }
        }
        return tgt
      })
    )

    // Update batches allocated quantity
    setBatches((prev) =>
      prev.map((b) => {
        if (inputBatchCodes.includes(b.batch_code)) {
          return {
            ...b,
            quantities: {
              ...b.quantities,
              allocated_kg: (b.quantities.allocated_kg || 0) + quantity_kg / inputBatchCodes.length,
            },
          }
        }
        return b
      })
    )

    return { success: true }
  }

  const reverseEPRAllocation = (allocationId: string, reason: string) => {
    setAllocations((prev) =>
      prev.map((a) => {
        if (a.id !== allocationId) return a
        return {
          ...a,
          status: 'REVERSED',
          reversal_reason: reason,
        }
      })
    )
  }

  const acceptAggregationPlan = (planId: string) => {
    setAggregationPlans((prev) =>
      prev.map((p) => {
        if (p.id !== planId) return p
        return {
          ...p,
          status: 'ACCEPTED',
        }
      })
    )
  }

  const resolveAnomaly = (anomalyId: string) => {
    setAnomalies((prev) =>
      prev.map((a) => {
        if (a.id !== anomalyId) return a
        return { ...a, status: 'RESOLVED' }
      })
    )
  }

  const resetDemoData = () => {
    localStorage.clear()
    setBatches(INITIAL_BATCHES)
    setConsignments(INITIAL_CONSIGNMENTS)
    setProcessingRuns(INITIAL_PROCESSING_RUNS)
    setAllocations(INITIAL_ALLOCATIONS)
    setEprTargets(INITIAL_EPR_TARGETS)
    setAggregationPlans(INITIAL_AGGREGATION_PLANS)
    setAnomalies(INITIAL_ANOMALIES)
    setPersonaId('persona-gen')
  }

  return (
    <AppContext.Provider
      value={{
        currentPersona,
        setPersona,
        user,
        batches,
        consignments,
        processingRuns,
        allocations,
        eprTargets,
        aggregationPlans,
        anomalies,
        createBatch,
        acceptOffer,
        makeOffer,
        completePickup,
        createConsignment,
        receiveBatch,
        createProcessingRun,
        submitNGOVerification,
        createEPRAllocation,
        reverseEPRAllocation,
        acceptAggregationPlan,
        resolveAnomaly,
        resetDemoData,
      }}
    >
      {children}
    </AppContext.Provider>
  )
}

export const useApp = () => {
  const context = useContext(AppContext)
  if (!context) {
    throw new Error('useApp must be used within an AppProvider')
  }
  return context
}

