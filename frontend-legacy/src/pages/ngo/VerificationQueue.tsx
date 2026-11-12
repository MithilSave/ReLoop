import React, { useState } from 'react'
import { Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import { StatusBadge } from '../../components/common/StatusBadge'
import { SixStageBar } from '../../components/common/SixStageBar'
import {
  ShieldCheck,
  FileText,
  Eye,
} from 'lucide-react'

export const NGOVerificationQueue: React.FC = () => {
  const { batches, currentPersona } = useApp()
  const [filter, setFilter] = useState<'ALL' | 'PENDING' | 'VERIFIED' | 'FLAGGED'>('ALL')

  // Batches that have reached PROCESSED (or have a verification entry)
  const verifiableBatches = batches.filter(
    (b) => b.status === 'PROCESSED' || b.verification !== undefined
  )

  const filteredBatches = verifiableBatches.filter((b) => {
    const decision = b.verification?.decision || 'PENDING'
    if (filter === 'PENDING') return decision === 'PENDING' || decision === 'UNDER_REVIEW'
    if (filter === 'VERIFIED') return decision === 'VERIFIED'
    if (filter === 'FLAGGED') return ['FLAGGED', 'REJECTED', 'REQUIRES_CORRECTION'].includes(decision)
    return true
  })

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="bg-linear-to-r from-amber-950 via-slate-900 to-emerald-950 rounded-2xl text-white p-6 md:p-8 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-amber-500/20 text-amber-300 text-xs font-semibold border border-amber-500/30">
            <span>🛡️</span> Independent Verification Body (Auditor)
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold tracking-tight">
            {currentPersona.org_name}
          </h1>
          <p className="text-sm text-slate-300 max-w-xl">
            Third-party statutory verification of mass balance, weighbridge slips, extrusion yields, and digital product passports.
          </p>
        </div>

        <Link
          to="/ngo/reports"
          className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white text-slate-900 hover:bg-slate-100 font-bold text-xs shadow-md transition-all shrink-0"
        >
          <FileText className="w-4 h-4 text-emerald-600" />
          Impact & Audit Reports
        </Link>
      </div>

      {/* Filter Tabs & Queue Count */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h2 className="text-base font-bold text-slate-900">Verification Audit Queue</h2>
          <p className="text-xs text-slate-500">
            Click any batch to inspect the split-view chain of custody and evidence dossier
          </p>
        </div>

        <div className="flex items-center bg-white border border-slate-200 rounded-xl p-1 text-xs">
          {(['ALL', 'PENDING', 'VERIFIED', 'FLAGGED'] as const).map((tab) => (
            <button
              key={tab}
              onClick={() => setFilter(tab)}
              className={`px-3 py-1.5 rounded-lg font-semibold transition-colors cursor-pointer ${
                filter === tab
                  ? 'bg-amber-600 text-white shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              {tab.charAt(0) + tab.slice(1).toLowerCase()}
            </button>
          ))}
        </div>
      </div>

      {/* Batches Queue Table / Cards */}
      <div className="space-y-4">
        {filteredBatches.length === 0 ? (
          <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center text-slate-500">
            <ShieldCheck className="w-12 h-12 text-slate-300 mx-auto mb-3" />
            <div className="text-sm font-semibold text-slate-700">No batches match this filter</div>
            <p className="text-xs text-slate-400 mt-1">Processed batches from recyclers will queue here automatically.</p>
          </div>
        ) : (
          filteredBatches.map((batch) => {
            const decision = batch.verification?.decision || 'PENDING'

            return (
              <div
                key={batch.id}
                className="bg-white rounded-2xl border border-slate-200 shadow-xs hover:border-slate-300 transition-all p-5 space-y-4"
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3 border-b border-slate-100 pb-3">
                  <div className="flex flex-wrap items-center gap-2.5">
                    <span className="font-mono font-bold text-base text-slate-900">
                      {batch.batch_code}
                    </span>
                    <StatusBadge status={decision} type="verification" />
                    <span className="text-xs font-semibold px-2 py-0.5 rounded bg-slate-100 text-slate-700 border border-slate-200">
                      {batch.material} ({batch.packaging_category})
                    </span>
                  </div>

                  <div className="flex items-center gap-3">
                    <div className="text-right">
                      <div className="text-[10px] uppercase font-bold text-slate-400">Processed Output</div>
                      <div className="text-sm font-mono font-extrabold text-slate-900">
                        {batch.quantities.processed_kg?.toFixed(1) || '—'} kg
                      </div>
                    </div>

                    <Link
                      to={`/ngo/review/${batch.id}`}
                      className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-amber-600 hover:bg-amber-700 text-white text-xs font-bold shadow-xs transition-colors"
                    >
                      <Eye className="w-4 h-4" />
                      <span>Audit Batch (Split View)</span>
                    </Link>
                  </div>
                </div>

                {/* Chain Details */}
                <div className="flex flex-wrap items-center gap-4 text-xs text-slate-600">
                  <span>Generator: <strong>{batch.generator_name}</strong></span>
                  <span>Collector: <strong>{batch.collector_name || 'Mumbai Eco Logistics'}</strong></span>
                  <span>Recycler: <strong>{batch.recycler_name || 'Apex Plastic Recovery PWP'}</strong></span>
                  <span className="text-slate-400 font-mono">
                    Variance: {batch.verification?.variance_pct || 0.5}%
                  </span>
                </div>

                {/* 6-Stage Quantity Bar */}
                <div className="bg-slate-50 p-3 rounded-xl border border-slate-100">
                  <SixStageBar quantities={batch.quantities} compact={false} />
                </div>
              </div>
            )
          })
        )}
      </div>
    </div>
  )
}
