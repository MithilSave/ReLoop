import axios, { type AxiosRequestConfig, type InternalAxiosRequestConfig } from 'axios'
import { API_BASE_URL } from './config'
import { tokenStore } from './tokens'
import { toApiError } from './errors'
import type { AuthResponse } from '@/types/api'

/** The only HTTP client in the app. UI code never calls axios directly; it calls services/*. */
export const http = axios.create({ baseURL: API_BASE_URL, timeout: 20000 })

http.interceptors.request.use((config) => {
  const t = tokenStore.access
  if (t) config.headers.Authorization = `Bearer ${t}`
  return config
})

// Single-flight refresh: concurrent 401s wait for one /auth/refresh call.
let refreshing: Promise<string | null> | null = null
async function refreshAccessToken(): Promise<string | null> {
  const rt = tokenStore.refresh
  if (!rt) return null
  try {
    const { data } = await axios.post<AuthResponse>(`${API_BASE_URL}/auth/refresh`, { refresh_token: rt }, { timeout: 15000 })
    tokenStore.set(data.access_token, data.refresh_token)
    return data.access_token
  } catch {
    return null
  }
}

export const SESSION_EXPIRED_EVENT = 'reloop:session-expired'

http.interceptors.response.use(
  (res) => res,
  async (error) => {
    const cfg = error.config as (InternalAxiosRequestConfig & { _retried?: boolean }) | undefined
    const status = error.response?.status
    const isAuthCall = cfg?.url?.includes('/auth/login') || cfg?.url?.includes('/auth/refresh')
    if (status === 401 && cfg && !cfg._retried && !isAuthCall && tokenStore.refresh) {
      cfg._retried = true
      refreshing ??= refreshAccessToken().finally(() => { refreshing = null })
      const fresh = await refreshing
      if (fresh) {
        cfg.headers.Authorization = `Bearer ${fresh}`
        return http.request(cfg)
      }
    }
    if (status === 401 && !isAuthCall) {
      tokenStore.clear()
      window.dispatchEvent(new CustomEvent(SESSION_EXPIRED_EVENT))
    }
    return Promise.reject(toApiError(error))
  },
)

export async function get<T>(url: string, config?: AxiosRequestConfig): Promise<T> {
  return (await http.get<T>(url, config)).data
}
export async function post<T>(url: string, body?: unknown, config?: AxiosRequestConfig): Promise<T> {
  return (await http.post<T>(url, body ?? {}, config)).data
}
export async function patch<T>(url: string, body?: unknown): Promise<T> {
  return (await http.patch<T>(url, body ?? {})).data
}
