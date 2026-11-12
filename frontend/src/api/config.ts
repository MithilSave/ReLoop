const raw = (import.meta.env.VITE_API_BASE_URL as string | undefined) ?? 'http://localhost:8000'
export const API_ORIGIN = raw.replace(/\/+$/, '')
export const API_BASE_URL = `${API_ORIGIN}/api/v1`
export const SHOW_DEMO_ACCOUNTS = import.meta.env.VITE_SHOW_DEMO_ACCOUNTS === 'true'
