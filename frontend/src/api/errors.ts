import axios, { type AxiosError } from 'axios'

/** Normalised form of the backend error envelope: { error: { code, message, details? } }. */
export class ApiError extends Error {
  status: number
  code: string
  details: unknown
  constructor(status: number, code: string, message: string, details?: unknown) {
    super(message)
    this.name = 'ApiError'
    this.status = status
    this.code = code
    this.details = details
  }
  /** Pydantic 422 details mapped to field paths, e.g. { estimated_kg: 'Field required' }. */
  fieldErrors(): Record<string, string> {
    const out: Record<string, string> = {}
    if (this.code === 'VALIDATION_ERROR' && Array.isArray(this.details)) {
      for (const d of this.details as { loc?: (string | number)[]; msg?: string }[]) {
        const key = (d.loc ?? []).filter((p) => p !== 'body').join('.')
        if (key && d.msg) out[key] = d.msg
      }
    }
    return out
  }
}

export const NETWORK_ERROR = 'NETWORK_ERROR'

export function toApiError(err: unknown): ApiError {
  if (err instanceof ApiError) return err
  if (axios.isAxiosError(err)) {
    const ax = err as AxiosError<{ error?: { code?: string; message?: string; details?: unknown }; detail?: unknown }>
    if (!ax.response) {
      return new ApiError(0, NETWORK_ERROR, 'The ReLoop server could not be reached. Check that the backend is running and try again.')
    }
    const body = ax.response.data
    const e = body?.error
    if (e?.code) return new ApiError(ax.response.status, e.code, e.message ?? 'Request failed', e.details)
    return new ApiError(ax.response.status, `HTTP_${ax.response.status}`, typeof body?.detail === 'string' ? body.detail : `Request failed with status ${ax.response.status}`)
  }
  return new ApiError(-1, 'CLIENT_ERROR', err instanceof Error ? err.message : 'Unexpected error')
}

/** Human explanation for the status classes the UI distinguishes. */
export function describeError(e: ApiError): { title: string; body: string } {
  switch (true) {
    case e.status === 0:
      return { title: 'Backend unavailable', body: e.message }
    case e.status === 401:
      return { title: 'Session ended', body: 'Sign in again to continue.' }
    case e.status === 403:
      return { title: 'Not permitted', body: e.message }
    case e.status === 404:
      return { title: 'Not found', body: e.message }
    case e.status === 409:
      return { title: 'Conflict with current records', body: e.message }
    case e.status === 422:
      return { title: 'Check the values entered', body: e.message }
    case e.status >= 500:
      return { title: 'Server error', body: 'The server could not complete this request. Try again; if it persists, report the time and action.' }
    default:
      return { title: 'Request failed', body: e.message }
  }
}
