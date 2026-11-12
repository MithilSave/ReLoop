import React, { useState } from 'react'
import { useApp } from '../../context/AppContext'
import {
  Download,
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

export const NGOAuditReports: React.FC = () => {
  const { batches, currentPersona } = useApp()
  const [downloadSuccess, setDownloadSuccess] = useState(false)

  // Chart data: verified vs pending by polymer
  const impactData = [
    { polymer: 'PET', verified: 82.0, pending: 0.0 },
    { polymer: 'HDPE', verified: 125.0, pending: 110.0 },
    { polymer: 'PP', verified: 68.0, pending: 74.0 },
  ]

  const handleDownload = () => {
    setDownloadSuccess(true)
    setTimeout(() => setDownloadSuccess(false), 4000)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900">
            Audit Dossiers & Verified Impact Reports
          </h1>
          <p className="text-xs text-slate-500">
            Independent CPCB statutory verification summaries for Maharashtra State Pollution Control Board
          </p>
        </div>

        <button
          onClick={handleDownload}
          className="inline-flex items-center gap-2 px-5 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-md transition-all cursor-pointer"
        >
          <Download className="w-4 h-4" />
          <span>Generate CPCB Audit PDF</span>
        </button>
      </div>

      {downloadSuccess && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-xl p-4 flex items-center gap-2 text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          <span>
            CPCB Statutory Verification Dossier (PDF) generated with SHA-256 digital signature of {currentPersona.name}.
          </span>
        </div>
      )}

      {/* Verified vs Pending kg by Polymer Chart */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 md:p-8 space-y-4">
        <div className="flex items-center justify-between border-b border-slate-100 pb-3">
          <div>
            <h2 className="text-sm font-bold text-slate-900">
              Verified vs Pending Extrusion Volume by Polymer (kg)
            </h2>
            <p className="text-xs text-slate-500">
              Independent audit status across mechanical processing facilities in Mumbai Region
            </p>
          </div>
          <span className="text-xs font-mono font-bold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-lg border border-emerald-200">
            Total Audited: 275.0 kg
          </span>
        </div>

        <div className="h-64 w-full pt-4">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={impactData} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis dataKey="polymer" tick={{ fontSize: 11, fill: '#64748b' }} />
              <YAxis tick={{ fontSize: 11, fill: '#64748b' }} unit=" kg" />
              <Tooltip
                formatter={(val: any) => [`${val} kg`, 'Quantity']}
                contentStyle={{ backgroundColor: '#0f172a', color: '#fff', borderRadius: '8px', fontSize: '12px' }}
              />
              <Legend wrapperStyle={{ fontSize: '12px' }} />
              <Bar dataKey="verified" name="Verified Output (kg)" fill="#10b981" radius={[4, 4, 0, 0]} />
              <Bar dataKey="pending" name="Pending Review (kg)" fill="#f59e0b" radius={[4, 4, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Audit Decision History Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="p-5 border-b border-slate-100">
          <h2 className="text-sm font-bold text-slate-900">Historical Auditor Decisions</h2>
          <p className="text-xs text-slate-500">Append-only log of independent verifications</p>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse font-mono">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50 text-slate-600 font-sans font-semibold">
                <th className="py-3 px-4">Batch Code</th>
                <th className="py-3 px-4">Auditor</th>
                <th className="py-3 px-4">Material</th>
                <th className="py-3 px-4">Decision</th>
                <th className="py-3 px-4">Variance</th>
                <th className="py-3 px-4">Timestamp</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              {batches
                .filter((b) => b.verification && b.verification.decision !== 'PENDING')
                .map((b) => (
                  <tr key={b.id} className="hover:bg-slate-50/50">
                    <td className="py-3 px-4 font-bold text-slate-900">{b.batch_code}</td>
                    <td className="py-3 px-4 font-sans text-slate-700">{b.verification?.reviewer_name}</td>
                    <td className="py-3 px-4">{b.material}</td>
                    <td className="py-3 px-4 font-sans">
                      <span className="px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800">
                        {b.verification?.decision}
                      </span>
                    </td>
                    <td className="py-3 px-4 text-emerald-700 font-bold">{b.verification?.variance_pct}%</td>
                    <td className="py-3 px-4 text-slate-500">
                      {b.verification?.updated_at
                        ? new Date(b.verification.updated_at).toLocaleDateString()
                        : 'Today'}
                    </td>
                  </tr>
                ))}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
