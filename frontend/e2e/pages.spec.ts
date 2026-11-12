import { test, expect } from '@playwright/test'
import { login } from './helpers'

/** Every route renders for its role without crashing, without an error state and without horizontal overflow. */
const ROUTES: Record<string, string[]> = {
  generator: ['/g', '/g/listings', '/g/listings/new', '/g/offers', '/g/handover', '/g/batches', '/g/payments', '/g/statements', '/g/analytics', '/profile', '/passport/RL-MUM-2026-000105'],
  collector: ['/c', '/c/listings', '/c/assignments', '/c/pickup', '/c/consignments', '/c/plans', '/c/deliveries', '/c/transactions', '/c/performance'],
  recycler: ['/r', '/r/requirements', '/r/suppliers', '/r/planner', '/r/costs', '/r/outlook', '/r/incoming', '/r/receipts', '/r/runs', '/r/yield', '/r/allocations'],
  ngo: ['/n', '/n/cases', '/n/custody', '/n/reconciliation', '/n/documents', '/n/discrepancies', '/n/reports', '/n/audit'],
  epr: ['/e', '/e/obligations', '/e/ledger', '/e/verified', '/e/trace', '/e/recyclers', '/e/discrepancies', '/e/reports'],
  admin: ['/a', '/a/organisations', '/a/anomalies', '/a/audit', '/a/lookup'],
}

for (const [who, routes] of Object.entries(ROUTES)) {
  for (const width of [1400, 390]) {
    test(`${who} screens render at ${width}px`, async ({ page }) => {
      const errors: string[] = []
      page.on('pageerror', (e) => errors.push(`pageerror: ${e.message}`))
      page.on('console', (m) => { if (m.type() === 'error' && !/fonts\.g|Failed to load resource|ERR_/.test(m.text())) errors.push(m.text()) })
      await page.setViewportSize({ width, height: 860 })
      await login(page, who)
      for (const r of routes) {
        await page.goto(r)
        await expect(page.locator('h1').first()).toBeVisible()
        await page.waitForLoadState('networkidle')
        await expect(page.getByRole('alert').filter({ hasText: /Server error|could not be rendered|Backend unavailable|Not permitted/ })).toHaveCount(0)
        await expect(page.getByText('This area is not available')).toHaveCount(0)
        const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth)
        expect(overflow, `horizontal overflow on ${r}`).toBeLessThanOrEqual(1)
      }
      expect(errors, errors.join('\n')).toEqual([])
    })
  }
}
