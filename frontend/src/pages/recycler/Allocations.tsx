import React, { useState } from 'react'
import { useApp } from '../../context/AppContext'
import { StatusBadge } from '../../components/common/StatusBadge'
import {
  PlusCircle,
  CheckCircle2,
  AlertTriangle,
  X,
} from 'lucide-react'

export const RecyclerAllocations: React.FC = () => {
  const {
    processingRuns,
    allocations,
    createEPRAllocation,
    reverseEPRAllocation,
  } = useApp()

  const [isModalOpen, setIsModalOpen] = useState(false)
  const [selectedRunId, setSelectedRunId] = useState<string>(processingRuns[0]?.id || '')
  const [eprOrgName, setEprOrgName] = useState<string>('EcoConsumer Brands India')
  const eprOrgId = 'org-epr-01'
  const [quantityKg, setQuantityKg] = useState<number>(20.0)
  const [period, setPeriod] = useState<string>('FY 2026-27 (Q3)')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  // Reversal modal state
  const [reversingAllocId, setReversingAllocId] = useState<string | null>(null)
  const [reversalReason, setReversalReason] = useState<string>('Commercial client order amendment')

  const selectedRun = processingRuns.find((r) => r.id === selectedRunId) || processingRuns[0]
  const remainingEligible = selectedRun ? selectedRun.eligible_kg - selectedRun.allocated_kg : 0

  const handleOpenModal = () => {
    setIsModalOpen(true)
    setErrorMessage(null)
    if (selectedRun) {
      setQuantityKg(Math.min(20, remainingEligible > 0 ? remainingEligible : 10))
    }
  }

  const handleCreateAllocation = (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedRun) return

    const result = createEPRAllocation(selectedRun.id, eprOrgId, eprOrgName, quantityKg, period)
    if (!result.success) {
      setErrorMessage(result.error || 'Allocation failed')
      return
    }

    setSuccessMessage(`Successfully allocated ${quantityKg} kg to ${eprOrgName}!`)
    setIsModalOpen(false)
    setTimeout(() => setSuccessMessage(null), 5000)
  }

  const handleConfirmReversal = () => {
    if (!reversingAllocId) return
    reverseEPRAllocation(reversingAllocId, reversalReason)
    setReversingAllocId(null)
    setSuccessMessage('Allocation reversed. Audit journal entry recorded.')
    setTimeout(() => setSuccessMessage(null), 5000)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900">EPR Statutory Credit Allocations</h1>
          <p className="text-xs text-slate-500">
            Allocate CPCB-eligible processed quantities to brand owners against statutory EPR obligations
          </p>
        </div>

        <button
          onClick={handleOpenModal}
          className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white text-xs font-bold shadow-xs transition-colors cursor-pointer"
        >
          <PlusCircle className="w-4 h-4" />
          <span>Allocate to Brand Owner</span>
        </button>
      </div>

      {successMessage && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-2xl p-4 flex items-center justify-between text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
            <span className="font-semibold">{successMessage}</span>
          </div>
          <button
            onClick={() => setSuccessMessage(null)}
            className="text-emerald-800 font-semibold underline text-xs"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* Eligible Balance Safeguard Summary */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
        <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
          CPCB Eligible Balance by Processing Run
        </h2>

        <div className="space-y-3">
          {processingRuns.map((run) => {
            const avail = run.eligible_kg - run.allocated_kg
            const allocPct = Math.round((run.allocated_kg / run.eligible_kg) * 100)

            return (
              <div
                key={run.id}
                className="p-4 rounded-xl border border-slate-200 bg-slate-50/50 space-y-2 text-xs"
              >
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                  <div className="flex items-center gap-2">
                    <span className="font-mono font-bold text-slate-900">{run.run_code}</span>
                    <span className="font-semibold px-2 py-0.2 rounded bg-purple-100 text-purple-800">
                      {run.material_code} ({run.packaging_category})
                    </span>
                    <span className="text-slate-500 font-mono">
                      Cert: {run.certificate_refs[0]}
                    </span>
                  </div>

                  <div className="text-right">
                    <span className="text-slate-500">Remaining Available: </span>
                    <strong className="font-mono text-emerald-700 text-sm">{avail.toFixed(1)} kg</strong>
                    <span className="text-slate-400 font-mono"> / {run.eligible_kg.toFixed(1)} kg</span>
                  </div>
                </div>

                <div className="w-full bg-slate-200 h-2 rounded-full overflow-hidden">
                  <div
                    className="bg-purple-600 h-full rounded-full transition-all duration-300"
                    style={{ width: `${allocPct}%` }}
                  />
                </div>
              </div>
            )
          })}
        </div>
      </div>

      {/* Allocations Ledger */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="p-5 border-b border-slate-100">
          <h2 className="text-sm font-bold text-slate-900">Active Allocations Ledger</h2>
          <p className="text-xs text-slate-500">
            Traceable to source batches and verified extrusion runs
          </p>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50 text-slate-600 font-semibold">
                <th className="py-3 px-4">Allocation Code</th>
                <th className="py-3 px-4">Brand Client</th>
                <th className="py-3 px-4">Processing Run</th>
                <th className="py-3 px-4">Category</th>
                <th className="py-3 px-4">Period</th>
                <th className="py-3 px-4">Quantity (kg)</th>
                <th className="py-3 px-4">Status</th>
                <th className="py-3 px-4 text-right">Action</th>
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100 font-mono">
              {allocations.map((alloc) => (
                <tr key={alloc.id} className="hover:bg-slate-50/50">
                  <td className="py-3 px-4 font-bold text-slate-900">{alloc.allocation_code}</td>
                  <td className="py-3 px-4 font-sans font-medium text-slate-800">{alloc.epr_org_name}</td>
                  <td className="py-3 px-4 text-purple-700 font-bold">{alloc.run_code}</td>
                  <td className="py-3 px-4 font-sans">{alloc.packaging_category}</td>
                  <td className="py-3 px-4 font-sans text-slate-500">{alloc.reporting_period}</td>
                  <td className="py-3 px-4 font-bold text-slate-900">{alloc.quantity_kg.toFixed(1)}</td>
                  <td className="py-3 px-4 font-sans">
                    <StatusBadge status={alloc.status} type="allocation" size="sm" />
                  </td>
                  <td className="py-3 px-4 text-right font-sans">
                    {alloc.status === 'ACTIVE' ? (
                      <button
                        onClick={() => setReversingAllocId(alloc.id)}
                        className="text-xs text-rose-600 hover:text-rose-700 font-semibold cursor-pointer"
                      >
                        Reverse
                      </button>
                    ) : (
                      <span className="text-xs text-slate-400 italic">Reversed</span>
                    )}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </div>

      {/* Create Allocation Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-5 animate-in fade-in">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h3 className="font-bold text-slate-900 text-base">Allocate CPCB Credit</h3>
                <p className="text-xs text-slate-500">
                  Draws from eligible mechanical extrusion volume
                </p>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 p-1"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {errorMessage && (
              <div className="bg-rose-50 border border-rose-300 rounded-xl p-3 flex items-center gap-2 text-xs text-rose-800 font-medium">
                <AlertTriangle className="w-4 h-4 shrink-0" />
                <span>{errorMessage}</span>
              </div>
            )}

            <form onSubmit={handleCreateAllocation} className="space-y-4">
              <div className="space-y-1">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                  Source Processing Run
                </label>
                <select
                  value={selectedRunId}
                  onChange={(e) => setSelectedRunId(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs font-mono font-bold"
                >
                  {processingRuns.map((r) => (
                    <option key={r.id} value={r.id}>
                      {r.run_code} • {r.material_code} ({r.eligible_kg - r.allocated_kg} kg available)
                    </option>
                  ))}
                </select>
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                  Target EPR Brand Owner
                </label>
                <input
                  type="text"
                  value={eprOrgName}
                  onChange={(e) => setEprOrgName(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs font-medium"
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700 flex justify-between">
                  <span>Allocation Quantity (kg)</span>
                  <span className="text-[11px] font-mono text-emerald-700 font-bold">
                    Max: {remainingEligible.toFixed(1)} kg
                  </span>
                </label>
                <input
                  type="number"
                  step="0.1"
                  max={remainingEligible}
                  value={quantityKg}
                  onChange={(e) => setQuantityKg(Number(e.target.value))}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 text-lg font-mono font-bold"
                  required
                />
              </div>

              <div className="space-y-1">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                  Reporting Period
                </label>
                <input
                  type="text"
                  value={period}
                  onChange={(e) => setPeriod(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs font-medium"
                  required
                />
              </div>

              <div className="pt-2 flex items-center justify-end gap-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={quantityKg > remainingEligible || quantityKg <= 0}
                  className={`px-6 py-2.5 rounded-xl text-xs font-bold shadow-md transition-all cursor-pointer ${
                    quantityKg <= remainingEligible && quantityKg > 0
                      ? 'bg-purple-600 hover:bg-purple-700 text-white'
                      : 'bg-slate-200 text-slate-400 cursor-not-allowed'
                  }`}
                >
                  Confirm Allocation
                </button>
              </div>
            </form>
          </div>
        </div>
      )}

      {/* Reversal Confirmation Modal */}
      {reversingAllocId && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-4">
            <h3 className="font-bold text-slate-900 text-base flex items-center gap-2 text-rose-600">
              <AlertTriangle className="w-5 h-5" />
              Reverse Statutory Allocation
            </h3>
            <p className="text-xs text-slate-600">
              Allocations are never deleted in place. Reversing creates an audited journal entry and releases eligible volume back to the processing run.
            </p>
            <div className="space-y-1.5">
              <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Mandatory Reversal Reason
              </label>
              <input
                type="text"
                value={reversalReason}
                onChange={(e) => setReversalReason(e.target.value)}
                className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs"
                required
              />
            </div>
            <div className="pt-2 flex items-center justify-end gap-2 border-t border-slate-100">
              <button
                type="button"
                onClick={() => setReversingAllocId(null)}
                className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
              >
                Cancel
              </button>
              <button
                type="button"
                onClick={handleConfirmReversal}
                className="px-5 py-2.5 rounded-xl bg-rose-600 hover:bg-rose-700 text-white text-xs font-bold shadow-md cursor-pointer"
              >
                Confirm Reversal
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
