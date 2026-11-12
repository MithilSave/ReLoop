import React from 'react'
import { Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import { StatusBadge } from '../../components/common/StatusBadge'
import { ExternalLink } from 'lucide-react'

export const EPRDiscrepancyAlerts: React.FC = () => {
  const { anomalies, resolveAnomaly } = useApp()

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl md:text-2xl font-bold text-slate-900">
          Discrepancy & Algorithmic Anomaly Alerts
        </h1>
        <p className="text-xs text-slate-500">
          Rule-based anomaly flags monitoring weighing tolerance limits, moisture variances, and material classification
        </p>
      </div>

      <div className="space-y-4">
        {anomalies.map((anom) => {
          const isResolved = anom.status === 'RESOLVED'

          return (
            <div
              key={anom.id}
              className={`bg-white rounded-2xl border p-5 space-y-3 transition-all ${
                isResolved ? 'border-slate-200 opacity-80' : 'border-amber-300 shadow-xs'
              }`}
            >
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-100 pb-3">
                <div className="flex items-center gap-2.5">
                  <span className="font-mono font-bold text-xs text-slate-900">{anom.code}</span>
                  <StatusBadge status={anom.severity} type="severity" size="sm" />
                  <span
                    className={`text-[10px] font-bold px-2 py-0.5 rounded ${
                      isResolved ? 'bg-emerald-100 text-emerald-800' : 'bg-amber-100 text-amber-800'
                    }`}
                  >
                    {anom.status}
                  </span>
                </div>
                <span className="text-xs text-slate-400 font-mono">
                  {new Date(anom.created_at).toLocaleString()}
                </span>
              </div>

              <div>
                <h3 className="text-sm font-bold text-slate-900">{anom.title}</h3>
                <p className="text-xs text-slate-600 mt-1 leading-relaxed">{anom.description}</p>
              </div>

              <div className="pt-2 flex items-center justify-between text-xs">
                <div className="flex items-center gap-3">
                  {anom.batch_code && (
                    <Link
                      to={`/b/${anom.batch_code}`}
                      className="font-mono text-teal-700 hover:text-teal-900 font-semibold inline-flex items-center gap-1"
                    >
                      Inspect Batch {anom.batch_code} <ExternalLink className="w-3 h-3" />
                    </Link>
                  )}
                  {anom.org_name && (
                    <span className="text-slate-500">Reporting Facility: {anom.org_name}</span>
                  )}
                </div>

                {!isResolved && (
                  <button
                    onClick={() => resolveAnomaly(anom.id)}
                    className="px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold transition-colors cursor-pointer"
                  >
                    Acknowledge Flag
                  </button>
                )}
              </div>
            </div>
          )
        })}
      </div>
    </div>
  )
}
