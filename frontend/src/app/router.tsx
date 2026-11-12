import { createBrowserRouter } from 'react-router-dom'
import { AppShell } from '@/layouts/AppShell'
import { HomeRedirect, RequireAuth, RequireRole } from './guards'
import { LoginPage } from '@/pages/auth/LoginPage'
import { PassportPage } from '@/pages/shared/PassportPage'
import { ProfilePage } from '@/pages/shared/ProfilePage'
import { NotFound } from '@/pages/shared/NotFound'
import * as G from '@/pages/generator/GeneratorPages'
import * as C from '@/pages/collector/CollectorPages'
import * as R from '@/pages/recycler/RecyclerPages'
import * as N from '@/pages/ngo/NgoPages'
import * as E from '@/pages/epr/EprPages'
import * as A from '@/pages/admin/AdminPages'

export const router = createBrowserRouter([
  { path: '/login', element: <LoginPage /> },
  { element: <RequireAuth />, children: [{ element: <AppShell />, children: [
    { index: true, element: <HomeRedirect /> },
    { path: 'passport/:code', element: <PassportPage /> },
    { path: 'profile', element: <ProfilePage /> },
    { path: 'g', element: <RequireRole allow={['generator']} />, children: [
      { index: true, element: <G.GeneratorOverview /> }, { path: 'listings', element: <G.GeneratorListings /> }, { path: 'listings/new', element: <G.CreateListing /> },
      { path: 'offers', element: <G.GeneratorOffers /> }, { path: 'handover', element: <G.GeneratorHandover /> }, { path: 'batches', element: <G.GeneratorBatches /> },
      { path: 'payments', element: <G.GeneratorPayments /> }, { path: 'statements', element: <G.GeneratorStatements /> }, { path: 'analytics', element: <G.GeneratorAnalytics /> },
    ] },
    { path: 'c', element: <RequireRole allow={['collector']} />, children: [
      { index: true, element: <C.CollectorOverview /> }, { path: 'listings', element: <C.CollectorListings /> }, { path: 'assignments', element: <C.CollectorAssignments /> },
      { path: 'pickup', element: <C.CollectorPickup /> }, { path: 'consignments', element: <C.CollectorConsignments /> }, { path: 'plans', element: <C.CollectorPlans /> },
      { path: 'deliveries', element: <C.CollectorDeliveries /> }, { path: 'transactions', element: <C.CollectorTransactions /> }, { path: 'performance', element: <C.CollectorPerformance /> },
    ] },
    { path: 'r', element: <RequireRole allow={['recycler']} />, children: [
      { index: true, element: <R.RecyclerDashboard /> }, { path: 'requirements', element: <R.RecyclerRequirements /> }, { path: 'suppliers', element: <R.RecyclerSuppliers /> },
      { path: 'planner', element: <R.RecyclerPlanner /> }, { path: 'costs', element: <R.RecyclerCosts /> }, { path: 'outlook', element: <R.RecyclerOutlook /> },
      { path: 'incoming', element: <R.RecyclerIncoming /> }, { path: 'receipts', element: <R.RecyclerReceipts /> }, { path: 'runs', element: <R.RecyclerRuns /> },
      { path: 'yield', element: <R.RecyclerYield /> }, { path: 'allocations', element: <R.RecyclerAllocations /> },
    ] },
    { path: 'n', element: <RequireRole allow={['ngo']} />, children: [
      { index: true, element: <N.NgoDashboard /> }, { path: 'cases', element: <N.NgoCases /> }, { path: 'cases/:id', element: <N.NgoCaseReview /> },
      { path: 'custody', element: <N.NgoCustody /> }, { path: 'reconciliation', element: <N.NgoReconciliation /> }, { path: 'documents', element: <N.NgoDocuments /> },
      { path: 'discrepancies', element: <N.NgoDiscrepancies /> }, { path: 'reports', element: <N.NgoReports /> }, { path: 'audit', element: <N.NgoAudit /> },
    ] },
    { path: 'e', element: <RequireRole allow={['epr']} />, children: [
      { index: true, element: <E.EprOverview /> }, { path: 'obligations', element: <E.EprObligations /> }, { path: 'ledger', element: <E.EprLedger /> },
      { path: 'verified', element: <E.EprVerified /> }, { path: 'trace', element: <E.EprTrace /> }, { path: 'recyclers', element: <E.EprRecyclers /> },
      { path: 'discrepancies', element: <E.EprDiscrepancies /> }, { path: 'reports', element: <E.EprReports /> },
    ] },
    { path: 'a', element: <RequireRole allow={['admin']} />, children: [
      { index: true, element: <A.AdminOverview /> }, { path: 'organisations', element: <A.AdminOrganisations /> }, { path: 'anomalies', element: <A.AdminAnomalies /> },
      { path: 'audit', element: <A.AdminAudit /> }, { path: 'lookup', element: <A.AdminLookup /> },
    ] },
    { path: '*', element: <NotFound /> },
  ] }] },
])
