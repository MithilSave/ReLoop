import { expect, type Page, type APIRequestContext } from '@playwright/test'

export const API = (process.env.VITE_API_BASE_URL ?? 'http://localhost:8000') + '/api/v1'
export const PASSWORD = 'reloop123'

export async function login(page: Page, who: string) {
  await page.goto('/login')
  await page.getByLabel('Email or phone').fill(`${who}@reloop.in`)
  await page.getByLabel('Password').fill(PASSWORD)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await expect(page).not.toHaveURL(/\/login/)
}

export async function apiToken(request: APIRequestContext, who: string) {
  const r = await request.post(`${API}/auth/login`, { data: { login: `${who}@reloop.in`, password: PASSWORD } })
  expect(r.ok()).toBeTruthy()
  return (await r.json()).access_token as string
}
export async function apiGet(request: APIRequestContext, token: string, path: string) {
  const r = await request.get(`${API}${path}`, { headers: { Authorization: `Bearer ${token}` } })
  return { status: r.status(), body: await r.json() }
}
export async function apiPost(request: APIRequestContext, token: string, path: string, data: unknown) {
  const r = await request.post(`${API}${path}`, { headers: { Authorization: `Bearer ${token}` }, data })
  return { status: r.status(), body: await r.json() }
}
/** Select the <option> whose visible text contains `text`. */
export async function selectByText(page: Page, selector: string, text: string) {
  const value = await page.locator(selector).evaluate((el, t) => {
    const o = Array.from((el as HTMLSelectElement).options).find((x) => x.text.includes(t))
    return o?.value ?? null
  }, text)
  if (value == null) throw new Error(`No option containing "${text}" in ${selector}`)
  await page.selectOption(selector, value)
}
export const PNG = { name: 'scale.png', mimeType: 'image/png', buffer: Buffer.from('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==', 'base64') }
