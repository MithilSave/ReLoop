import { test, expect } from '@playwright/test'
import { API, apiGet, apiPost, apiToken, login, PNG, selectByText } from './helpers'

/**
 * One batch through the whole chain, driven through the UI as each role,
 * with backend state checked through the API after each step.
 */
test.describe.serial('Full traceability workflow', () => {
  let code = ''
  let batchId = ''
  let otp = ''
  const last6 = () => code.slice(-6)

  test('Generator creates a listing', async ({ page, request }) => {
    await login(page, 'generator')
    await page.goto('/g/listings/new')
    await page.getByLabel('Material').selectOption('PET')
    await page.getByLabel('Estimated weight (kg)').fill('120')
    await page.getByLabel('Locality').fill('Vikhroli East')
    await page.locator('#photos').setInputFiles(PNG)
    await expect(page.getByText('1 photo recorded')).toBeVisible()
    await page.getByRole('button', { name: 'Publish listing' }).click()
    await expect(page).toHaveURL(/\/passport\/RL-/)
    code = decodeURIComponent(page.url().split('/passport/')[1])
    await expect(page.getByText(code).first()).toBeVisible()
    const t = await apiToken(request, 'generator')
    const b = await apiGet(request, t, `/batches/${code}`)
    expect(b.status).toBe(200)
    expect(b.body.status).toBe('LISTED')
    expect(b.body.quantities.estimated_kg).toBe('120.000')
    batchId = b.body.id
  })

  test('Collector makes an offer', async ({ page }) => {
    await login(page, 'collector')
    await page.goto('/c/listings')
    await page.getByRole('row', { name: new RegExp(last6()) }).click()
    await page.getByLabel('Rate paid to generator (₹/kg)').fill('12')
    await page.getByRole('button', { name: 'Send offer' }).click()
    await expect(page.getByText('Offer sent to the generator')).toBeVisible()
    // Duplicate offer is refused by the backend and explained
    await page.getByRole('row', { name: new RegExp(last6()) }).click()
    await page.getByLabel('Rate paid to generator (₹/kg)').fill('13')
    await page.getByRole('button', { name: 'Send offer' }).click()
    await expect(page.getByText('You already have an open offer on this listing')).toBeVisible()
  })

  test('Generator accepts the offer', async ({ page, request }) => {
    await login(page, 'generator')
    await page.goto('/g/offers')
    const panel = page.locator('section', { hasText: code })
    await panel.getByRole('button', { name: 'Accept' }).click()
    await page.getByRole('button', { name: 'Accept offer' }).click()
    await expect(page.getByText(/Offer accepted/)).toBeVisible()
    const b = await apiGet(request, await apiToken(request, 'generator'), `/batches/${batchId}`)
    expect(b.body.status).toBe('ASSIGNED')
  })

  test('Collector weighs at pickup and receives the handover code', async ({ page, request }) => {
    await login(page, 'collector')
    await page.goto(`/c/pickup?batch=${batchId}`)
    await page.getByLabel('Weight on your scale (kg)').fill('160')
    await expect(page.getByText(/note required/)).toBeVisible()
    await page.getByRole('button', { name: 'Record weight & get code' }).click()
    await expect(page.getByText('Explain why the weight differs from the listing by more than 20%')).toBeVisible()
    await expect(page.getByText('Add a photo that shows the scale reading')).toBeVisible()
    await page.getByLabel('Weight on your scale (kg)').fill('118')
    await page.locator('#scale-photo').setInputFiles(PNG)
    await expect(page.getByText('scale.png')).toBeVisible()
    await page.getByRole('button', { name: 'Record weight & get code' }).click()
    const code6 = page.getByLabel(/^Handover code/)
    await expect(code6).toBeVisible()
    otp = (await code6.textContent())!.trim()
    expect(otp).toMatch(/^\d{6}$/)
    // Backend guard: a second weigh-in is refused, and the batch stays readable
    const t = await apiToken(request, 'collector')
    const again = await apiPost(request, t, `/collections/${batchId}/pickup`, { collected_kg: 130 })
    expect(again.status).toBe(409)
    expect(again.body.error.code).toBe('PICKUP_ALREADY_RECORDED')
    const b = await apiGet(request, t, `/batches/${batchId}`)
    expect(b.status).toBe(200)
    expect(b.body.quantities.collected_kg).toBe('118.000')
  })

  test('Generator confirms the handover with the code', async ({ page, request }) => {
    await login(page, 'generator')
    await page.goto('/g/handover')
    await page.getByLabel('Code from the collector').fill('000000')
    await page.getByRole('button', { name: /^Confirm/ }).click()
    await expect(page.getByText('That code does not match')).toBeVisible()
    await page.getByLabel('Code from the collector').fill(otp)
    await page.getByRole('button', { name: /^Confirm/ }).click()
    await expect(page.getByText(/Handover confirmed: 118\.0 kg/)).toBeVisible()
    const t = await apiToken(request, 'generator')
    expect((await apiGet(request, t, `/batches/${batchId}`)).body.status).toBe('PICKED_UP')
    const pay = (await apiGet(request, t, '/payments')).body.find((p: { batch_id: string }) => p.batch_id === batchId)
    expect(pay.amount).toBeCloseTo(118 * 12, 2)
    await page.goto('/g/payments')
    await expect(page.getByRole('row', { name: new RegExp(last6()) })).toContainText('₹1,416.00')
  })

  test('Collector dispatches a consignment to the recycler', async ({ page, request }) => {
    await login(page, 'collector')
    await page.goto('/c/consignments')
    await page.getByRole('button', { name: 'New consignment' }).click()
    const dialog = page.getByRole('dialog')
    for (const cb of await dialog.getByRole('checkbox').all()) {
      const label = await cb.getAttribute('aria-label')
      if (label?.includes(code)) await cb.check(); else await cb.uncheck()
    }
    await selectByText(page, '#destination', 'Ecoplas')
    await dialog.getByLabel('Vehicle number').fill('MH-02-TT-4242')
    await dialog.getByRole('button', { name: /^Dispatch 1 batch$/ }).click()
    await expect(page.getByText(/dispatched with 1 batches/)).toBeVisible()
    expect((await apiGet(request, await apiToken(request, 'collector'), `/batches/${batchId}`)).body.status).toBe('IN_TRANSIT')
  })

  test('Recycler marks arrival and records a balanced receipt', async ({ page, request }) => {
    await login(page, 'recycler')
    await page.goto('/r/incoming')
    const row = page.getByRole('row', { name: /MH-02|TC-MUM/ }).filter({ hasText: /In transit/ }).first()
    await row.getByRole('button', { name: 'Mark arrived' }).click()
    await expect(page.getByText('Marked as arrived')).toBeVisible()
    await page.getByRole('row').filter({ hasText: 'awaiting receipt' }).filter({ hasText: 'TC-' }).last().getByRole('button', { name: 'Receive batches' }).click()
    const drawer = page.getByRole('dialog')
    await drawer.locator('div', { hasText: code }).getByRole('button', { name: 'Record receipt' }).last().click()
    await page.getByLabel('Received (kg)').fill('117')
    await page.getByLabel('Accepted (kg)').fill('110')
    await expect(page.getByLabel('Rejected (kg)')).toHaveValue('7')
    await page.getByLabel('Rejected (kg)').fill('5')
    await expect(page.getByText('Accepted + rejected must equal received. The server rejects unbalanced receipts.')).toBeVisible()
    await page.getByRole('button', { name: 'Save receipt' }).click()
    await expect(page.getByText('Accepted + rejected must equal received').first()).toBeVisible()
    await page.getByLabel('Rejected (kg)').fill('7')
    await page.getByLabel('Rejected material goes to').fill('Co-processing')
    await page.getByRole('button', { name: 'Save receipt' }).click()
    await expect(page.getByText('Receipt recorded')).toBeVisible()
    const t = await apiToken(request, 'recycler')
    const b = (await apiGet(request, t, `/batches/${batchId}`)).body
    expect(b.status).toBe('RECEIVED')
    expect(b.quantities.received_kg).toBe('117.000')
    expect(b.quantities.accepted_kg).toBe('110.000')
    expect(b.quantities.rejected_kg).toBe('7.000')
    // Backend guards: no second receipt, unbalanced receipts refused
    const again = await apiPost(request, t, '/recycler/receipts', { batch_id: batchId, received_kg: 117, accepted_kg: 117, rejected_kg: 0 })
    expect(again.status).toBe(409)
  })

  test('Recycler records a processing run within accepted stock', async ({ page, request }) => {
    await login(page, 'recycler')
    await page.goto('/r/runs')
    await page.getByRole('button', { name: 'Record processing run' }).click()
    await page.getByLabel('Material').selectOption('PET')
    await page.getByRole('checkbox', { name: `Use ${code}` }).check()
    await page.getByLabel(`Input kg for ${code}`).fill('200')
    await page.getByLabel('Recovered output (kg)').fill('99')
    await page.getByLabel('Residue (kg)').fill('9')
    await page.getByLabel('Declared EPR-eligible (kg)').fill('95')
    await page.getByRole('button', { name: 'Save run' }).click()
    await expect(page.getByText(/exceeds its available 110\.0 kg/)).toBeVisible()
    await page.getByLabel(`Input kg for ${code}`).fill('110')
    await expect(page.getByText(/Yield 90\.0% · unaccounted 2\.0 kg/)).toBeVisible()
    await page.getByRole('button', { name: 'Save run' }).click()
    await expect(page.getByText(/recorded: yield 90\.0%/)).toBeVisible()
    const t = await apiToken(request, 'recycler')
    const b = (await apiGet(request, t, `/batches/${batchId}`)).body
    expect(b.status).toBe('PROCESSED')
    expect(b.quantities.processed_kg).toBe('99.000')
    const trace = (await apiGet(request, t, `/batches/${batchId}/trace`)).body
    expect(trace.processing_runs[0].input_kg).toBe(110)
    // Backend guard: the same stock cannot be processed again
    const rc = (await apiGet(request, t, '/recycler/receipts')).body.find((r: { batch_id: string }) => r.batch_id === batchId)
    expect(rc.available_kg).toBe(0)
    const dup = await apiPost(request, t, '/recycler/processing-records', { material_code: 'PET', run_started_at: '2026-11-12T08:00:00Z', run_ended_at: '2026-11-12T09:00:00Z', inputs: [{ recycler_receipt_id: rc.id, input_kg: 10 }], output_kg: 9, residue_kg: 1, eligible_kg: 9 })
    expect(dup.status).toBe(409)
    expect(dup.body.error.code).toBe('INPUT_EXCEEDS_AVAILABLE')
    // Passport shows the six stages separately
    await page.goto(`/passport/${code}`)
    const ladder = page.getByRole('list', { name: 'Quantity progression' })
    for (const v of ['120.0 kg', '118.0 kg', '117.0 kg', '110.0 kg', '99.0 kg']) await expect(ladder).toContainText(v)
    await expect(ladder).toContainText('7.0 kg rejected')
  })

  test('NGO reviews the evidence and verifies', async ({ page, request }) => {
    await login(page, 'ngo')
    await page.goto('/n/cases')
    await page.getByRole('row', { name: new RegExp(last6()) }).click()
    await expect(page.getByText('Accepted + rejected = received')).toBeVisible()
    await expect(page.getByText(/11 pass · 0 review · 0 fail/)).toBeVisible()
    // Non-verified decisions require a written reason
    await page.getByRole('button', { name: 'Flag concern' }).click()
    await page.getByRole('button', { name: 'Record decision' }).click()
    await expect(page.getByText(/Explain the decision/)).toBeVisible()
    await page.getByRole('button', { name: 'Cancel' }).click()
    await page.getByRole('button', { name: 'Verify' }).click()
    await page.getByLabel('Reviewer comments').fill('Scale photo, OTP handover, receipt balance and run mass balance are consistent.')
    await page.getByRole('button', { name: 'Record decision' }).click()
    await expect(page.getByText('Decision recorded: Verified')).toBeVisible()
    const b = (await apiGet(request, await apiToken(request, 'ngo'), `/batches/${batchId}`)).body
    expect(b.verification.decision).toBe('VERIFIED')
    expect(b.quantities.ngo_verified_kg).toBe('99.000')
  })

  test('Recycler allocation: over-allocation refused with details, valid allocation saved', async ({ page, request }) => {
    await login(page, 'recycler')
    await page.goto('/r/allocations')
    await page.getByRole('button', { name: 'Allocate' }).click()
    await selectByText(page, '#a-run', '95.0 kg free')
    await selectByText(page, '#a-client', 'Hindustan')
    await page.getByLabel('Quantity (kg)').fill('200')
    await page.getByRole('dialog').getByRole('button', { name: 'Allocate' }).click()
    await expect(page.getByText('Allocation refused: it would double-count output')).toBeVisible()
    await expect(page.getByText(/available 95\.000 kg/)).toBeVisible()
    await page.getByLabel('Quantity (kg)').fill('50')
    await page.getByRole('dialog').getByRole('button', { name: 'Allocate' }).click()
    await expect(page.getByText(/50\.0 kg allocated\. 45\.0 kg remains free/)).toBeVisible()
    const b = (await apiGet(request, await apiToken(request, 'recycler'), `/batches/${batchId}`)).body
    expect(Number(b.quantities.epr_allocated_kg)).toBeCloseTo(50, 3)
  })

  test('EPR company sees the allocation, attributed to the verified source batch', async ({ page }) => {
    await login(page, 'epr')
    await page.goto('/e/verified')
    const row = page.getByRole('row', { name: new RegExp(last6()) })
    await expect(row).toContainText('50.0')
    await expect(row).toContainText('Verified')
    await page.goto('/e/trace')
    await expect(page.getByText('Lineage')).toBeVisible()
    await page.goto(`/passport/${code}`)
    await expect(page.getByText('identity withheld')).toBeVisible()
  })
})

test.describe('Access control and sessions', () => {
  test('A generator cannot open recycler screens; the backend also refuses', async ({ page, request }) => {
    await login(page, 'generator')
    await page.goto('/r/runs')
    await expect(page.getByText('This area is not available to your organisation')).toBeVisible()
    const r = await apiGet(request, await apiToken(request, 'generator'), '/recycler/processing-records')
    expect(r.status).toBe(403)
    expect(r.body.error.code).toBe('FORBIDDEN_ROLE')
  })

  test('An expired or invalid session returns to sign-in with a message', async ({ page }) => {
    await login(page, 'collector')
    await page.evaluate(() => { localStorage.setItem('reloop.access_token', 'expired.token.value'); localStorage.setItem('reloop.refresh_token', 'bad') })
    await page.goto('/c/consignments')
    await expect(page).toHaveURL(/\/login/)
    await expect(page.getByText(/sign in again|session has ended/i)).toBeVisible()
  })

  test('Token refresh renews an expired access token transparently', async ({ page }) => {
    await login(page, 'recycler')
    await page.evaluate(() => localStorage.setItem('reloop.access_token', 'expired.token.value'))
    await page.goto('/r/receipts')
    await expect(page.getByRole('heading', { name: 'Material receipts' })).toBeVisible()
    await expect(page.getByRole('table', { name: 'Receipts' })).toBeVisible()
    const t = await page.evaluate(() => localStorage.getItem('reloop.access_token'))
    expect(t).not.toBe('expired.token.value')
  })

  test('Sign out revokes the refresh token', async ({ page, request }) => {
    await login(page, 'epr')
    const rt = await page.evaluate(() => localStorage.getItem('reloop.refresh_token'))
    await page.getByRole('button', { name: 'Account menu' }).click()
    await page.getByRole('menuitem', { name: 'Sign out' }).click()
    await expect(page).toHaveURL(/\/login/)
    const r = await request.post(`${API}/auth/refresh`, { data: { refresh_token: rt } })
    expect(r.status()).toBe(401)
  })

  test('Admin can list organisations and view the audit trail', async ({ page }) => {
    await login(page, 'admin')
    await page.goto('/a/organisations')
    await page.getByLabel('Approval status').selectOption('APPROVED')
    await expect(page.getByRole('row', { name: /Ecoplas/ })).toBeVisible()
    await page.goto('/a/audit')
    await expect(page.getByRole('table', { name: 'Audit log' })).toBeVisible()
  })
})
