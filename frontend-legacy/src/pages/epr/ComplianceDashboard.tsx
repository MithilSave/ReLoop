import React from 'react'
import { Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import {
  FileSpreadsheet,
  ShieldCheck,
  TrendingUp,
  AlertTriangle,
  Calendar,
  CheckCircle2,
} from 'lucide-react'
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
  Legend,
} from 'recharts'

export const EPRComplianceDashboard: React.FC = () => {
  const { eprTargets, currentPersona } = useApp()

  // Calculate totals across categories
  const totalTargetKg = eprTargets.reduce((acc, t) => acc + t.target_kg, 0)
  const totalAllocatedKg = eprTargets.reduce((acc, t) => acc + t.allocated_kg, 0)
  const totalVerifiedKg = eprTargets.reduce((acc, t) => acc + t.verified_kg, 0)
  const totalUnverifiedKg = eprTargets.reduce((acc, t) => acc + t.unverified_kg, 0)

  const overallCompliancePct = totalTargetKg > 0 ? Math.round((totalAllocatedKg / totalTargetKg) * 100) : 0

  const chartData = eprTargets.map((t) => ({
    name: t.category,
    label: t.category_label,
    target: t.target_kg / 1000, // MT
    verified: t.verified_kg / 1000,
    unverified: t.unverified_kg / 1000,
  }))

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="bg-linear-to-r from-teal-950 via-slate-900 to-emerald-950 rounded-2xl text-white p-6 md:p-8 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-teal-500/20 text-teal-300 text-xs font-semibold border border-teal-500/30">
            <span>📦</span> Brand Owner / PIBO (Producer, Importer, Brand Owner)
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold tracking-tight">
            {currentPersona.org_name}
          </h1>
          <p className="text-sm text-teal-100 max-w-xl">
            CPCB Extended Producer Responsibility (EPR) compliance tracker with verified mechanical recycling certificates.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <Link
            to="/epr/allocations"
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-teal-600 hover:bg-teal-500 text-white font-bold text-xs shadow-md transition-all"
          >
            <FileSpreadsheet className="w-4 h-4" />
            Allocations Ledger
          </Link>
          <Link
            to="/epr/discrepancies"
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white text-slate-900 hover:bg-slate-100 font-bold text-xs shadow-md transition-all"
          >
            <AlertTriangle className="w-4 h-4 text-amber-600" />
            Discrepancies
          </Link>
        </div>
      </div>

      {/* KPI Overview Strip */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Overall Fulfillment</span>
            <TrendingUp className="w-4 h-4 text-teal-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {overallCompliancePct}%
          </div>
          <div className="text-[11px] text-teal-700 font-medium mt-1">
            {(totalAllocatedKg / 1000).toFixed(0)} of {(totalTargetKg / 1000).toFixed(0)} MT target
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Verified Allocated</span>
            <ShieldCheck className="w-4 h-4 text-emerald-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-emerald-700">
            {(totalVerifiedKg / 1000).toFixed(1)}{' '}
            <span className="text-sm font-sans font-normal text-slate-500">MT</span>
          </div>
          <div className="text-[11px] text-emerald-700 font-medium mt-1 flex items-center gap-1">
            <CheckCircle2 className="w-3.5 h-3.5" /> NGO Audit Signed
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Pending Verification</span>
            <Calendar className="w-4 h-4 text-amber-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-amber-700">
            {(totalUnverifiedKg / 1000).toFixed(1)}{' '}
            <span className="text-sm font-sans font-normal text-slate-500">MT</span>
          </div>
          <div className="text-[11px] text-amber-700 font-medium mt-1">Under NGO review</div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Reporting Period</span>
            <Calendar className="w-4 h-4 text-slate-500" />
          </div>
          <div className="text-xl font-extrabold font-mono text-slate-900 mt-1">
            FY 2026-27
          </div>
          <div className="text-[11px] text-slate-500 mt-1">CPCB Portal Deadline: 31 Mar</div>
        </div>
      </div>

      {/* Compliance Target Rings / Bars per Category */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 md:p-8 space-y-6">
        <div className="flex items-center justify-between border-b border-slate-100 pb-3">
          <div>
            <h2 className="text-sm font-bold text-slate-900">
              Statutory Packaging Targets vs Fulfillments (CPCB Categories)
            </h2>
            <p className="text-xs text-slate-500">
              Breakdown across Rigid (Cat-I), Flexible (Cat-II), and Multi-layered (Cat-III)
            </p>
          </div>
          <span className="text-xs font-mono font-bold text-teal-700 bg-teal-50 px-2.5 py-1 rounded-lg border border-teal-200">
            CPCB Registration: MH/EPR/2026/0491
          </span>
        </div>

        {/* Individual Category Progress Bars */}
        <div className="space-y-5">
          {eprTargets.map((target) => {
            const pct = Math.round((target.allocated_kg / target.target_kg) * 100)
            const verifiedPct = Math.round((target.verified_kg / target.target_kg) * 100)
            const unverifiedPct = Math.round((target.unverified_kg / target.target_kg) * 100)

            return (
              <div
                key={target.id}
                className="p-4 rounded-xl border border-slate-200 bg-slate-50/50 space-y-2.5"
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-1">
                  <div>
                    <span className="font-bold text-sm text-slate-900">
                      {target.category_label}
                    </span>
                  </div>
                  <div className="text-right text-xs font-mono">
                    <span className="font-bold text-slate-900 text-sm">
                      {(target.allocated_kg / 1000).toFixed(1)} MT
                    </span>
                    <span className="text-slate-400"> / {(target.target_kg / 1000).toFixed(1)} MT ({pct}%)</span>
                  </div>
                </div>

                {/* Stacked Progress Bar: Verified (Green) + Unverified (Amber) */}
                <div className="w-full bg-slate-200 h-3 rounded-full overflow-hidden flex">
                  <div
                    className="bg-emerald-600 h-full transition-all duration-500"
                    style={{ width: `${verifiedPct}%` }}
                    title={`Verified: ${(target.verified_kg / 1000).toFixed(1)} MT`}
                  />
                  <div
                    className="bg-amber-500 h-full transition-all duration-500"
                    style={{ width: `${unverifiedPct}%` }}
                    title={`Unverified: ${(target.unverified_kg / 1000).toFixed(1)} MT`}
                  />
                </div>

                <div className="flex justify-between text-[11px] text-slate-500 font-mono">
                  <span className="text-emerald-700 flex items-center gap-1">
                    <span className="w-2 h-2 rounded-full bg-emerald-600" />
                    Verified: {(target.verified_kg / 1000).toFixed(1)} MT
                  </span>
                  <span className="text-amber-700 flex items-center gap-1">
                    <span className="w-2 h-2 rounded-full bg-amber-500" />
                    Unverified / In Review: {(target.unverified_kg / 1000).toFixed(1)} MT
                  </span>
                  <span>Gap: {((target.target_kg - target.allocated_kg) / 1000).toFixed(1)} MT</span>
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* Target vs Fulfillment Chart */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 md:p-8 space-y-4">
        <h2 className="text-sm font-bold text-slate-900 border-b border-slate-100 pb-2">
          Category Volume Comparison (Metric Tonnes)
        </h2>
        <div className="h-64 w-full pt-4">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={chartData} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis dataKey="name" tick={{ fontSize: 11, fill: '#64748b' }} />
              <YAxis tick={{ fontSize: 11, fill: '#64748b' }} unit=" MT" />
              <Tooltip
                formatter={(val: any) => [`${val} MT`, 'Quantity']}
                contentStyle={{ backgroundColor: '#0f172a', color: '#fff', borderRadius: '8px', fontSize: '12px' }}
              />
              <Legend wrapperStyle={{ fontSize: '12px' }} />
              <Bar dataKey="target" name="Mandatory Target (MT)" fill="#94a3b8" radius={[4, 4, 0, 0]} />
              <Bar dataKey="verified" name="Verified Credit (MT)" fill="#10b981" radius={[4, 4, 0, 0]} />
              <Bar dataKey="unverified" name="Unverified Credit (MT)" fill="#f59e0b" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>
    </div>
  )
}
