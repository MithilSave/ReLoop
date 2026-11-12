import { defineConfig, devices } from '@playwright/test'

/**
 * End-to-end tests against a running backend (VITE_API_BASE_URL, default http://localhost:8000)
 * seeded with backend/seed_data.py, and the Vite dev server on :5173.
 *   cd backend && rm -f reloop.db && python seed_data.py && uvicorn app.main:app --port 8000
 *   cd frontend && npm run dev
 *   npm run e2e
 */
export default defineConfig({
  testDir: './e2e',
  fullyParallel: false,
  workers: 1,
  timeout: 60_000,
  expect: { timeout: 10_000 },
  reporter: [['list']],
  use: { baseURL: 'http://localhost:5173', trace: 'retain-on-failure', screenshot: 'only-on-failure' },
  projects: [
    { name: 'desktop', use: { ...devices['Desktop Chrome'], viewport: { width: 1400, height: 900 } } },
  ],
})
