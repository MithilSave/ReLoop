import axios from 'axios'
import { get, post } from '@/api/client'
import { API_BASE_URL } from '@/api/config'
import { toApiError } from '@/api/errors'
import type { AuthResponse, MeResponse } from '@/types/api'

export async function login(loginId: string, password: string): Promise<AuthResponse> {
  try {
    // Plain axios: a 401 here is a wrong password, not an expired session.
    const { data } = await axios.post<AuthResponse>(`${API_BASE_URL}/auth/login`, { login: loginId, password }, { timeout: 15000 })
    return data
  } catch (e) {
    throw toApiError(e)
  }
}
export const me = () => get<MeResponse>('/auth/me')
export const logout = (refresh_token: string) => post<{ status: string; refresh_token_revoked: boolean }>('/auth/logout', { refresh_token })
