import { Routes, Route, Navigate } from 'react-router-dom'
import { AppProvider, useApp } from './context/AppContext'
import { AppShell } from './components/layout/AppShell'

// Pages
import { LoginPage } from './pages/auth/LoginPage'
import { GeneratorOverview } from './pages/generator/Overview'
import { GeneratorMyBatches } from './pages/generator/MyBatches'
import { GeneratorCreateBatch } from './pages/generator/CreateBatch'
import { GeneratorCollectorOffers } from './pages/generator/CollectorOffers'

import { CollectorOverview } from './pages/collector/Overview'
import { CollectorAvailableListings } from './pages/collector/AvailableListings'
import { CollectorActivePickups } from './pages/collector/ActivePickups'
import { CollectorConsignmentBuilder } from './pages/collector/ConsignmentBuilder'

import { RecyclerOverview } from './pages/recycler/Overview'
import { RecyclerInboundReceiving } from './pages/recycler/InboundReceiving'
import { RecyclerProcessingRuns } from './pages/recycler/ProcessingRuns'
import { RecyclerSourcingPlanner } from './pages/recycler/SourcingPlanner'
import { RecyclerLandedCostComparison } from './pages/recycler/LandedCostComparison'
import { RecyclerAllocations } from './pages/recycler/Allocations'

import { NGOVerificationQueue } from './pages/ngo/VerificationQueue'
import { NGOBatchReviewSplitView } from './pages/ngo/BatchReviewSplitView'
import { NGOAuditReports } from './pages/ngo/AuditReports'

import { EPRComplianceDashboard } from './pages/epr/ComplianceDashboard'
import { EPRAllocationsLedger } from './pages/epr/AllocationsLedger'
import { EPRDiscrepancyAlerts } from './pages/epr/DiscrepancyAlerts'

import { AdminDashboard } from './pages/admin/AdminDashboard'
import { PublicPassportPage } from './pages/passport/PublicPassport'

// Root redirect based on active persona role
const RootRedirect = () => {
  const { currentPersona } = useApp()
  switch (currentPersona.role) {
    case 'generator':
      return <Navigate to="/generator" replace />
    case 'collector':
      return <Navigate to="/collector" replace />
    case 'recycler':
      return <Navigate to="/recycler" replace />
    case 'ngo':
      return <Navigate to="/ngo" replace />
    case 'epr_body':
      return <Navigate to="/epr" replace />
    case 'admin':
      return <Navigate to="/admin" replace />
    default:
      return <Navigate to="/generator" replace />
  }
}

function App() {
  return (
    <AppProvider>
      <Routes>
        {/* Public Auth */}
        <Route path="/auth/login" element={<LoginPage />} />
        <Route path="/auth/register" element={<LoginPage />} />

        {/* Public Material Passport Gateway */}
        <Route
          path="/b/:batchCode"
          element={
            <AppShell>
              <PublicPassportPage />
            </AppShell>
          }
        />
        <Route
          path="/passport"
          element={
            <AppShell>
              <PublicPassportPage />
            </AppShell>
          }
        />

        {/* Generator Routes */}
        <Route
          path="/generator"
          element={
            <AppShell>
              <GeneratorOverview />
            </AppShell>
          }
        />
        <Route
          path="/generator/batches"
          element={
            <AppShell>
              <GeneratorMyBatches />
            </AppShell>
          }
        />
        <Route
          path="/generator/create"
          element={
            <AppShell>
              <GeneratorCreateBatch />
            </AppShell>
          }
        />
        <Route
          path="/generator/offers"
          element={
            <AppShell>
              <GeneratorCollectorOffers />
            </AppShell>
          }
        />

        {/* Collector Routes */}
        <Route
          path="/collector"
          element={
            <AppShell>
              <CollectorOverview />
            </AppShell>
          }
        />
        <Route
          path="/collector/available"
          element={
            <AppShell>
              <CollectorAvailableListings />
            </AppShell>
          }
        />
        <Route
          path="/collector/pickups"
          element={
            <AppShell>
              <CollectorActivePickups />
            </AppShell>
          }
        />
        <Route
          path="/collector/consignments"
          element={
            <AppShell>
              <CollectorConsignmentBuilder />
            </AppShell>
          }
        />

        {/* Recycler Routes */}
        <Route
          path="/recycler"
          element={
            <AppShell>
              <RecyclerOverview />
            </AppShell>
          }
        />
        <Route
          path="/recycler/receiving"
          element={
            <AppShell>
              <RecyclerInboundReceiving />
            </AppShell>
          }
        />
        <Route
          path="/recycler/processing"
          element={
            <AppShell>
              <RecyclerProcessingRuns />
            </AppShell>
          }
        />
        <Route
          path="/recycler/sourcing"
          element={
            <AppShell>
              <RecyclerSourcingPlanner />
            </AppShell>
          }
        />
        <Route
          path="/recycler/costing"
          element={
            <AppShell>
              <RecyclerLandedCostComparison />
            </AppShell>
          }
        />
        <Route
          path="/recycler/allocations"
          element={
            <AppShell>
              <RecyclerAllocations />
            </AppShell>
          }
        />

        {/* NGO Auditor Routes */}
        <Route
          path="/ngo"
          element={
            <AppShell>
              <NGOVerificationQueue />
            </AppShell>
          }
        />
        <Route
          path="/ngo/review/:batchId"
          element={
            <AppShell>
              <NGOBatchReviewSplitView />
            </AppShell>
          }
        />
        <Route
          path="/ngo/reports"
          element={
            <AppShell>
              <NGOAuditReports />
            </AppShell>
          }
        />

        {/* EPR Client Routes */}
        <Route
          path="/epr"
          element={
            <AppShell>
              <EPRComplianceDashboard />
            </AppShell>
          }
        />
        <Route
          path="/epr/allocations"
          element={
            <AppShell>
              <EPRAllocationsLedger />
            </AppShell>
          }
        />
        <Route
          path="/epr/discrepancies"
          element={
            <AppShell>
              <EPRDiscrepancyAlerts />
            </AppShell>
          }
        />

        {/* Admin Governance Routes */}
        <Route
          path="/admin"
          element={
            <AppShell>
              <AdminDashboard />
            </AppShell>
          }
        />
        <Route
          path="/admin/orgs"
          element={
            <AppShell>
              <AdminDashboard />
            </AppShell>
          }
        />
        <Route
          path="/admin/anomalies"
          element={
            <AppShell>
              <AdminDashboard />
            </AppShell>
          }
        />

        {/* Root & Fallback */}
        <Route path="/" element={<RootRedirect />} />
        <Route path="*" element={<Navigate to="/" replace />} />
      </Routes>
    </AppProvider>
  )
}

export default App
