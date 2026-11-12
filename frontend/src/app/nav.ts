import {
  LayoutDashboard, List, PlusSquare, Tag, Hand, Package, Wallet, Award, BarChart3, ClipboardCheck, ScanLine, Truck, Inbox,
  Layers, FlaskConical, Gauge, Users, Link2, Target, Coins, LineChart, ShieldCheck, GitBranch, Scale, FileText, AlertTriangle,
  Factory, Download, Building2, ScrollText, Search,
} from 'lucide-react'
import type { AppRole } from '@/lib/roles'

export interface NavItem { to: string; label: string; icon: React.ComponentType<{ className?: string }>; tab?: boolean; primaryAction?: boolean }
export interface NavGroup { label: string; items: NavItem[] }

export const BASE: Record<AppRole, string> = { generator: '/g', collector: '/c', recycler: '/r', ngo: '/n', epr: '/e', admin: '/a' }

export const NAV: Record<AppRole, NavGroup[]> = {
  generator: [
    { label: 'Operate', items: [
      { to: '/g', label: 'Overview', icon: LayoutDashboard, tab: true },
      { to: '/g/listings', label: 'Waste listings', icon: List, tab: true },
      { to: '/g/listings/new', label: 'Create listing', icon: PlusSquare, tab: true, primaryAction: true },
      { to: '/g/offers', label: 'Offers', icon: Tag },
      { to: '/g/handover', label: 'Handover', icon: Hand },
    ] },
    { label: 'Trace', items: [{ to: '/g/batches', label: 'Batch tracking', icon: Package, tab: true }] },
    { label: 'Finance & impact', items: [
      { to: '/g/payments', label: 'Payments', icon: Wallet },
      { to: '/g/statements', label: 'Contribution statements', icon: Award },
      { to: '/g/analytics', label: 'Contribution analytics', icon: BarChart3 },
    ] },
  ],
  collector: [
    { label: 'Operate', items: [
      { to: '/c', label: 'Operations overview', icon: LayoutDashboard, tab: true },
      { to: '/c/listings', label: 'Available listings', icon: List, tab: true },
      { to: '/c/pickup', label: 'Pickup verification', icon: ScanLine, tab: true, primaryAction: true },
      { to: '/c/assignments', label: 'Collection assignments', icon: ClipboardCheck },
      { to: '/c/plans', label: 'Aggregation plans', icon: Layers },
    ] },
    { label: 'Logistics', items: [
      { to: '/c/consignments', label: 'Transport consignments', icon: Truck, tab: true },
      { to: '/c/deliveries', label: 'Delivery records', icon: Inbox },
    ] },
    { label: 'Finance', items: [
      { to: '/c/transactions', label: 'Payments & earnings', icon: Wallet },
      { to: '/c/performance', label: 'Performance', icon: Gauge },
    ] },
  ],
  recycler: [
    { label: 'Overview', items: [{ to: '/r', label: 'Operations dashboard', icon: LayoutDashboard, tab: true }] },
    { label: 'Procurement', items: [
      { to: '/r/requirements', label: 'Procurement requirements', icon: Target },
      { to: '/r/suppliers', label: 'Suppliers', icon: Users },
      { to: '/r/planner', label: 'Aggregation planner', icon: Layers, tab: true },
      { to: '/r/costs', label: 'Landed cost', icon: Coins },
      { to: '/r/outlook', label: 'Supply outlook', icon: LineChart },
    ] },
    { label: 'Receiving & processing', items: [
      { to: '/r/incoming', label: 'Incoming consignments', icon: Truck, tab: true, primaryAction: true },
      { to: '/r/receipts', label: 'Material receipts', icon: Inbox },
      { to: '/r/runs', label: 'Processing runs', icon: FlaskConical, tab: true },
      { to: '/r/yield', label: 'Material yield', icon: Gauge },
    ] },
    { label: 'EPR', items: [{ to: '/r/allocations', label: 'EPR allocations', icon: Link2 }] },
  ],
  ngo: [
    { label: 'Overview', items: [
      { to: '/n', label: 'Verification dashboard', icon: LayoutDashboard },
      { to: '/n/cases', label: 'Cases', icon: ClipboardCheck },
    ] },
    { label: 'Review', items: [
      { to: '/n/custody', label: 'Chain of custody', icon: GitBranch },
      { to: '/n/reconciliation', label: 'Quantity reconciliation', icon: Scale },
    ] },
    { label: 'Follow-up', items: [
      { to: '/n/documents', label: 'Document requests', icon: FileText },
      { to: '/n/discrepancies', label: 'Discrepancies', icon: AlertTriangle },
      { to: '/n/reports', label: 'Verification reports', icon: Award },
      { to: '/n/audit', label: 'Audit history', icon: ScrollText },
    ] },
  ],
  epr: [
    { label: 'Compliance', items: [
      { to: '/e', label: 'Compliance overview', icon: LayoutDashboard },
      { to: '/e/obligations', label: 'Obligations & targets', icon: Target },
      { to: '/e/ledger', label: 'Allocation ledger', icon: Link2 },
      { to: '/e/verified', label: 'Verified quantities', icon: ShieldCheck },
    ] },
    { label: 'Traceability', items: [
      { to: '/e/trace', label: 'Batch traceability', icon: GitBranch },
      { to: '/e/recyclers', label: 'Recycler records', icon: Factory },
      { to: '/e/discrepancies', label: 'Discrepancy monitoring', icon: AlertTriangle },
    ] },
    { label: 'Reporting', items: [{ to: '/e/reports', label: 'Reports & exports', icon: Download }] },
  ],
  admin: [
    { label: 'Platform', items: [
      { to: '/a', label: 'Platform overview', icon: LayoutDashboard },
      { to: '/a/organisations', label: 'Organisation approvals', icon: Building2 },
      { to: '/a/anomalies', label: 'Anomaly alerts', icon: AlertTriangle },
      { to: '/a/audit', label: 'Audit trail', icon: ScrollText },
      { to: '/a/lookup', label: 'Batch lookup', icon: Search },
    ] },
  ],
}
