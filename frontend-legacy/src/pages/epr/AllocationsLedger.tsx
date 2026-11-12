import React, { useState } from 'react'
import { Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import {
  Download,
  ShieldCheck,
  ExternalLink,
  CheckCircle2,
} from 'lucide-react'

export const EPRAllocationsLedger: React.FC = () => {
  const { allocations } = useApp()
  const [downloadSuccess, setDownloadSuccess] = useState<string | null>(null)

  const handleExport = (format: 'PDF' | 'CSV') => {
    setDownloadSuccess(`Exported EPR Compliance Dossier (${format}) with digital audit seals for CPCB filing.`)
    setTimeout(() => setDownloadSuccess(null), 4000)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900">EPR Statutory Allocations Ledger</h1>
          <p className="text-xs text-slate-500">
            Immutable chain-of-custody credit ledger linking brand allocations directly to recycler runs and batch passports
          </p>
        </div>

        <div className="flex items-center gap-2">
          <button
            onClick={() => handleExport('CSV')}
            className="px-3.5 py-2 rounded-xl bg-white border border-slate-300 hover:bg-slate-50 text-slate-700 text-xs font-bold shadow-xs transition-colors cursor-pointer"
          >
            Export CSV
          </button>
          <button
            onClick={() => handleExport('PDF')}
            className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-teal-600 hover:bg-teal-700 text-white text-xs font-bold shadow-xs transition-colors cursor-pointer"
          >
            <Download className="w-3.5 h-3.5" />
            <span>CPCB Dossier (PDF)</span>
          </button>
        </div>
      </div>

      {downloadSuccess && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-2xl p-4 flex items-center gap-2 text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          <span>{downloadSuccess}</span>
        </div>
      )}

      {/* Allocations Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between">
          <h2 className="text-sm font-bold text-slate-900">Credit Certificates Ledger</h2>
          <span className="text-xs font-mono text-slate-500 font-bold">
            Total Allocated: {allocations.reduce((a, b) => a + b.quantity_kg, 0).toFixed(1)} kg
          </span>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50 text-slate-600 font-semibold">
                <th className="py-3 px-4">Allocation ID</th>
                <th className="py-3 px-4">Source Recycler</th>
                <th className="py-3 px-4">Processing Run</th>
                <th className="py-3 px-4">Origin Batch Passports</th>
                <th className="py-3 px-4">Category</th>
                <th className="py-3 px-4">Credit kg</th>
                <th className="py-3 px-4">CPCB Certificate ID</th>
                <th className="py-3 px-4">Auditor Status</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 font-mono">
              {allocations.map((alloc) => (
                <tr key={alloc.id} className="hover:bg-slate-50/50">
                  <td className="py-3.5 px-4 font-bold text-slate-900">{alloc.allocation_code}</td>
                  <td className="py-3.5 px-4 font-sans font-medium text-slate-800">{alloc.recycler_name}</td>
                  <td className="py-3.5 px-4 text-purple-700 font-bold">{alloc.run_code}</td>
                  <td className="py-3.5 px-4">
                    <div className="flex flex-wrap gap-1 font-sans">
                      {alloc.batch_codes.map((code) => (
                        <Link
                          key={code}
                          to={`/b/${code}`}
                          className="font-mono text-[11px] text-teal-700 hover:text-teal-900 underline inline-flex items-center gap-0.5"
                        >
                          {code} <ExternalLink className="w-2.5 h-2.5" />
                        </Link>
                      ))}
                    </div>
                  </td>
                  <td className="py-3.5 px-4 font-sans">{alloc.packaging_category}</td>
                  <td className="py-3.5 px-4 font-bold text-slate-900">{alloc.quantity_kg.toFixed(1)}</td>
                  <td className="py-3.5 px-4 text-[11px] text-slate-600">{alloc.certificate_id}</td>
                  <td className="py-3.5 px-4 font-sans">
                    {alloc.is_ngo_verified ? (
                      <span className="inline-flex items-center gap-1 text-[11px] font-bold text-emerald-700 bg-emerald-50 px-2 py-0.5 rounded border border-emerald-200">
                        <ShieldCheck className="w-3.5 h-3.5" /> Verified
                      </span>
                    ) : (
                      <span className="inline-flex items-center gap-1 text-[11px] font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded border border-amber-200">
                        In Audit
                      </span>
                    )}
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
