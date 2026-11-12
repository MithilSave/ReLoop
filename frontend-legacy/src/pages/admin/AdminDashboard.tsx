import React, { useState } from 'react'
import { useApp } from '../../context/AppContext'
import { StatusBadge } from '../../components/common/StatusBadge'
import { SixStageBar } from '../../components/common/SixStageBar'

interface OrgApproval {
  id: string
  name: string
  orgType: string
  cpcbNumber: string
  submittedAt: string
  status: 'PENDING' | 'APPROVED' | 'REJECTED'
}

export const AdminDashboard: React.FC = () => {
  const { batches, anomalies, resolveAnomaly } = useApp()

  const [orgApprovals, setOrgApprovals] = useState<OrgApproval[]>([
    {
      id: 'app-01',
      name: 'Sahyadri Bio-Polymers PWP',
      orgType: 'Plastic Waste Processor (Recycler)',
      cpcbNumber: 'CPCB/PWP/MH/2026/8910',
      submittedAt: '2026-11-10',
      status: 'PENDING',
    },
    {
      id: 'app-02',
      name: 'Vanguard Environmental Auditors',
      orgType: 'Independent NGO Auditor',
      cpcbNumber: 'NABCB/AUDIT/2026/112',
      submittedAt: '2026-11-11',
      status: 'PENDING',
    },
  ])

  // Aggregate 6 stages across all batches in the platform
  const totalPlatformQuantities = {
    estimated_kg: batches.reduce((a, b) => a + (b.quantities.estimated_kg || 0), 0),
    collected_kg: batches.reduce((a, b) => a + (b.quantities.collected_kg || 0), 0),
    received_kg: batches.reduce((a, b) => a + (b.quantities.received_kg || 0), 0),
    accepted_kg: batches.reduce((a, b) => a + (b.quantities.accepted_kg || 0), 0),
    rejected_kg: batches.reduce((a, b) => a + (b.quantities.rejected_kg || 0), 0),
    processed_kg: batches.reduce((a, b) => a + (b.quantities.processed_kg || 0), 0),
    verified_kg: batches.reduce((a, b) => a + (b.quantities.verified_kg || 0), 0),
    allocated_kg: batches.reduce((a, b) => a + (b.quantities.allocated_kg || 0), 0),
  }

  const handleApprove = (id: string) => {
    setOrgApprovals((prev) =>
      prev.map((o) => (o.id === id ? { ...o, status: 'APPROVED' } : o))
    )
  }

  const handleReject = (id: string) => {
    setOrgApprovals((prev) =>
      prev.map((o) => (o.id === id ? { ...o, status: 'REJECTED' } : o))
    )
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="bg-linear-to-r from-slate-900 via-slate-800 to-slate-950 rounded-2xl text-white p-6 md:p-8 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-slate-700 text-slate-200 text-xs font-semibold">
            <span>⚙️</span> Platform Governance & Trust Operations
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold tracking-tight">
            ReLoop System Administration
          </h1>
          <p className="text-sm text-slate-400 max-w-xl">
            Live platform telemetry, KYB organization approvals, and network anomaly surveillance.
          </p>
        </div>
      </div>

      {/* Platform-Wide 6-Stage Quantity Bar */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
        <div className="flex items-center justify-between border-b border-slate-100 pb-3">
          <div>
            <h2 className="text-sm font-bold text-slate-900">
              Platform-Wide Circular Mass Balance (6-Stage Quantity Bar)
            </h2>
            <p className="text-xs text-slate-500">
              Cumulative aggregate kg circulating across all Mumbai nodes
            </p>
          </div>
          <span className="text-xs font-mono font-bold text-slate-800 bg-slate-100 px-3 py-1 rounded-lg">
            {batches.length} Tracked Batches
          </span>
        </div>

        <SixStageBar quantities={totalPlatformQuantities} compact={false} />
      </div>

      {/* KYB Organization Approvals */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
        <h2 className="text-sm font-bold text-slate-900 border-b border-slate-100 pb-2">
          KYB Organization Onboarding Queue (CPCB Vetting)
        </h2>

        <div className="divide-y divide-slate-100">
          {orgApprovals.map((org) => (
            <div key={org.id} className="py-4 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <span className="font-bold text-sm text-slate-900">{org.name}</span>
                  <span className="text-[11px] font-semibold px-2 py-0.2 rounded bg-slate-100 text-slate-700">
                    {org.orgType}
                  </span>
                  <span
                    className={`text-[10px] font-bold px-2 py-0.2 rounded ${
                      org.status === 'APPROVED'
                        ? 'bg-emerald-100 text-emerald-800'
                        : org.status === 'REJECTED'
                        ? 'bg-rose-100 text-rose-800'
                        : 'bg-amber-100 text-amber-800'
                    }`}
                  >
                    {org.status}
                  </span>
                </div>
                <div className="text-xs text-slate-500 font-mono">
                  CPCB License: <strong>{org.cpcbNumber}</strong> • Submitted: {org.submittedAt}
                </div>
              </div>

              {org.status === 'PENDING' ? (
                <div className="flex items-center gap-2">
                  <button
                    onClick={() => handleReject(org.id)}
                    className="px-3 py-1.5 rounded-lg border border-slate-300 hover:bg-slate-100 text-slate-700 text-xs font-semibold cursor-pointer"
                  >
                    Reject
                  </button>
                  <button
                    onClick={() => handleApprove(org.id)}
                    className="px-4 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold cursor-pointer"
                  >
                    Approve KYB
                  </button>
                </div>
              ) : (
                <span className="text-xs font-semibold text-slate-500">Processed</span>
              )}
            </div>
          ))}
        </div>
      </div>

      {/* Platform Anomaly Flags Monitor */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
        <h2 className="text-sm font-bold text-slate-900 border-b border-slate-100 pb-2">
          Network Anomaly Flags Surveillance
        </h2>

        <div className="divide-y divide-slate-100">
          {anomalies.map((a) => (
            <div key={a.id} className="py-3 flex items-center justify-between text-xs">
              <div className="space-y-0.5">
                <div className="flex items-center gap-2">
                  <span className="font-mono font-bold text-slate-900">{a.code}</span>
                  <StatusBadge status={a.severity} type="severity" size="sm" />
                  <span className="font-medium text-slate-700">{a.title}</span>
                </div>
                <div className="text-slate-500">{a.description}</div>
              </div>

              {a.status === 'OPEN' ? (
                <button
                  onClick={() => resolveAnomaly(a.id)}
                  className="px-3 py-1 rounded bg-slate-100 hover:bg-slate-200 text-slate-700 font-medium cursor-pointer shrink-0 ml-4"
                >
                  Resolve
                </button>
              ) : (
                <span className="text-emerald-600 font-bold shrink-0 ml-4">✓ Resolved</span>
              )}
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
