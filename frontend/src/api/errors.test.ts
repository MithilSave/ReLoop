import { describe, expect, it } from 'vitest'
import { AxiosError, AxiosHeaders } from 'axios'
import { toApiError } from './errors'

function axiosErr(status: number | null, data?: unknown) {
  const e = new AxiosError('x')
  if (status != null) e.response = { status, data, statusText: '', headers: {}, config: { headers: new AxiosHeaders() } }
  return e
}

describe('toApiError', () => {
  it('reads the backend error envelope including details', () => {
    const e = toApiError(axiosErr(409, { error: { code: 'ALLOCATION_EXCEEDS_AVAILABLE', message: 'Requested 200 kg exceeds available 130 kg', details: { available_kg: '130.000' } } }))
    expect(e.status).toBe(409)
    expect(e.code).toBe('ALLOCATION_EXCEEDS_AVAILABLE')
    expect((e.details as { available_kg: string }).available_kg).toBe('130.000')
  })
  it('maps pydantic 422 details to field errors', () => {
    const e = toApiError(axiosErr(422, { error: { code: 'VALIDATION_ERROR', message: 'Request validation failed', details: [{ loc: ['body', 'estimated_kg'], msg: 'Field required' }] } }))
    expect(e.fieldErrors()).toEqual({ estimated_kg: 'Field required' })
  })
  it('reports network failures as status 0', () => {
    expect(toApiError(axiosErr(null)).status).toBe(0)
  })
})
