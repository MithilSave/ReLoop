import { describe, expect, it } from 'vitest'
import { physicalStages, q, receiptBalances, variances, verifiedKg } from './quantities'
import type { BatchQuantities } from '@/types/api'

const base: BatchQuantities = { estimated_kg: '100.000', collected_kg: null, received_kg: null, accepted_kg: null, rejected_kg: null, processed_kg: null, ngo_verified_kg: null, epr_allocated_kg: null }

describe('quantities', () => {
  it('parses backend strings and nulls', () => {
    expect(q('12.500')).toBe(12.5)
    expect(q(null)).toBeNull()
    expect(q('abc')).toBeNull()
  })
  it('takes processing input from trace and recovered output from processed_kg', () => {
    const Q = { ...base, collected_kg: '98.000', received_kg: '97.000', accepted_kg: '90.000', rejected_kg: '7.000', processed_kg: '81.000' }
    const s = physicalStages(Q, { batch_id: 'x', batch_code: 'c', status: 'PROCESSED', pickup: null, receipt: null, processing_runs: [{ record_code: 'PR', run_started_at: '', input_kg: 90, apportioned_output_kg: 81, yield_pct: 90, measurement_status: 'COMPLETE' }] })
    expect(s.find((x) => x.key === 'input')!.value).toBe(90)
    expect(s.find((x) => x.key === 'output')!.value).toBe(81)
  })
  it('never shows the backend fallback as NGO-verified kg', () => {
    const Q = { ...base, accepted_kg: '90.000', ngo_verified_kg: '90.000' }
    expect(verifiedKg(Q, 'VERIFIED')).toBeNull() // no measured output yet
    expect(verifiedKg({ ...Q, processed_kg: '80.000', ngo_verified_kg: '80.000' }, 'VERIFIED')).toBe(80)
    expect(verifiedKg({ ...Q, processed_kg: '80.000', ngo_verified_kg: '80.000' }, 'FLAGGED')).toBeNull()
  })
  it('enforces accepted + rejected = received', () => {
    expect(receiptBalances(148.5, 143.5, 5)).toBe(true)
    expect(receiptBalances(148.5, 140, 5)).toBe(false)
  })
  it('flags variances outside tolerance', () => {
    const v = variances({ quantities: { ...base, collected_kg: '125.000', received_kg: '120.000' } })
    expect(v[0].outOfTolerance).toBe(true) // +25% vs estimate
    expect(v[1].outOfTolerance).toBe(true) // -4% transit
  })
  it('marks collected as provisional until the generator confirms', () => {
    const s = physicalStages({ ...base, collected_kg: '99.000' }, null, { pickupConfirmed: false })
    expect(s[1].provisional).toBe(true)
  })
})
