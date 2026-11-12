/**
 * Token persistence. localStorage keeps sessions across reloads (the brief asks for session persistence);
 * the trade-off is exposure to XSS, which is why the app renders no untrusted HTML.
 */
const ACCESS = 'reloop.access_token'
const REFRESH = 'reloop.refresh_token'

function safe<T>(fn: () => T, fallback: T): T {
  try { return fn() } catch { return fallback }
}

export const tokenStore = {
  get access() { return safe(() => localStorage.getItem(ACCESS), null) },
  get refresh() { return safe(() => localStorage.getItem(REFRESH), null) },
  set(access: string, refresh: string) {
    safe(() => { localStorage.setItem(ACCESS, access); localStorage.setItem(REFRESH, refresh) }, undefined)
  },
  clear() {
    safe(() => { localStorage.removeItem(ACCESS); localStorage.removeItem(REFRESH) }, undefined)
  },
}
