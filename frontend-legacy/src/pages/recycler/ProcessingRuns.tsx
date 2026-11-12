import React, { useState } from 'react'
import { useApp } from '../../context/AppContext'
import type { PolymerType, PackagingCategory, WasteBatch } from '../../types'
import {
  RotateCcw,
  PlusCircle,
  CheckCircle2,
  AlertTriangle,
  X,
} from 'lucide-react'

export const RecyclerProcessingRuns: React.FC = () => {
  const { batches, processingRuns, createProcessingRun } = useApp()

  const [isModalOpen, setIsModalOpen] = useState(false)
  const [selectedBatchIds, setSelectedBatchIds] = useState<string[]>([])
  const [materialCode, setMaterialCode] = useState<PolymerType>('PP')
  const [packagingCategory, setPackagingCategory] = useState<PackagingCategory>('Cat-I')
  const [outputKg, setOutputKg] = useState<number>(68.0)
  const [residueKg, setResidueKg] = useState<number>(6.0)
  const [outputForm, setOutputForm] = useState<'Pellets' | 'Flakes' | 'Granules'>('Pellets')
  const [certificateRef, setCertificateRef] = useState<string>('CPCB/PWM/2026/MH/7802')
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  // Batches received at this plant with accepted kg available for processing
  const availableBatches = batches.filter(
    (b) => b.status === 'RECEIVED' && (b.quantities.accepted_kg || 0) > 0
  )

  const selectedBatches = availableBatches.filter((b) => selectedBatchIds.includes(b.id))
  const totalInputKg = selectedBatches.reduce((acc, b) => acc + (b.quantities.accepted_kg || 0), 0)

  const isMassBalanceValid = outputKg + residueKg <= totalInputKg && totalInputKg > 0
  const computedYield = totalInputKg > 0 ? ((outputKg / totalInputKg) * 100).toFixed(1) : '0.0'

  const handleToggleBatch = (batch: WasteBatch) => {
    setSelectedBatchIds((prev) => {
      const next = prev.includes(batch.id) ? prev.filter((id) => id !== batch.id) : [...prev, batch.id]
      if (next.length > 0 && prev.length === 0) {
        setMaterialCode(batch.material)
        setPackagingCategory(batch.packaging_category)
      }
      return next
    })
  }

  const handleCreateRun = (e: React.FormEvent) => {
    e.preventDefault()
    if (selectedBatchIds.length === 0 || !isMassBalanceValid) return

    const newRun = createProcessingRun({
      material_code: materialCode,
      packaging_category: packagingCategory,
      batch_ids: selectedBatchIds,
      output_kg: outputKg,
      residue_kg: residueKg,
      output_form: outputForm,
      certificate_ref: certificateRef,
    })

    setSuccessMessage(`Processing Run ${newRun.run_code} successfully finalized! Batch has been submitted to NGO verification queue.`)
    setIsModalOpen(false)
    setSelectedBatchIds([])
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900">Extrusion Processing & Yield Records</h1>
          <p className="text-xs text-slate-500">
            Convert accepted raw receipts into recycled pellets with immutable mass balance accounting
          </p>
        </div>

        <button
          onClick={() => {
            setIsModalOpen(true)
            if (availableBatches.length > 0 && selectedBatchIds.length === 0) {
              const first = availableBatches[0]
              setSelectedBatchIds([first.id])
              setMaterialCode(first.material)
              setPackagingCategory(first.packaging_category)
              const inp = first.quantities.accepted_kg || 74
              setOutputKg(Number((inp * 0.91).toFixed(1)))
              setResidueKg(Number((inp * 0.09).toFixed(1)))
            }
          }}
          className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white text-xs font-bold shadow-xs transition-colors cursor-pointer"
        >
          <PlusCircle className="w-4 h-4" />
          <span>New Processing Run</span>
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

      {/* Processing Runs Ledger */}
      <div className="space-y-4">
        {processingRuns.map((run) => {
          const remainingEligible = run.eligible_kg - run.allocated_kg
          return (
            <div
              key={run.id}
              className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4 hover:border-slate-300 transition-all"
            >
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-100 pb-3">
                <div className="flex items-center gap-3">
                  <div className="w-10 h-10 rounded-xl bg-purple-100 text-purple-700 flex items-center justify-center font-bold">
                    <RotateCcw className="w-5 h-5" />
                  </div>
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-mono font-bold text-base text-slate-900">
                        {run.run_code}
                      </span>
                      <span className="text-xs font-bold px-2 py-0.5 rounded bg-purple-50 text-purple-700 border border-purple-200">
                        {run.material_code} ({run.packaging_category})
                      </span>
                      <span className="text-xs font-semibold px-2 py-0.5 rounded bg-emerald-50 text-emerald-700 border border-emerald-200">
                        Yield {run.yield_pct}%
                      </span>
                    </div>
                    <div className="text-xs text-slate-500 mt-0.5">
                      Statutory CPCB Ref: <strong className="font-mono">{run.certificate_refs[0]}</strong>
                    </div>
                  </div>
                </div>

                <div className="text-right">
                  <div className="text-[10px] uppercase font-bold text-slate-400">CPCB Eligible Balance</div>
                  <div className="text-lg font-mono font-extrabold text-emerald-700">
                    {remainingEligible.toFixed(1)} / {run.eligible_kg.toFixed(1)}{' '}
                    <span className="text-xs font-sans font-normal text-slate-500">kg</span>
                  </div>
                </div>
              </div>

              {/* Mass Balance Breakdown Cards */}
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-3 bg-slate-50 p-3.5 rounded-xl border border-slate-100 font-mono text-xs">
                <div>
                  <div className="text-[10px] text-slate-400 uppercase font-sans">Input Accepted</div>
                  <div className="font-bold text-slate-900 text-sm mt-0.5">{run.input_kg.toFixed(1)} kg</div>
                </div>
                <div>
                  <div className="text-[10px] text-purple-600 uppercase font-sans">Output ({run.output_form})</div>
                  <div className="font-bold text-purple-700 text-sm mt-0.5">{run.output_kg.toFixed(1)} kg</div>
                </div>
                <div>
                  <div className="text-[10px] text-slate-500 uppercase font-sans">Residue / Purge</div>
                  <div className="font-bold text-slate-700 text-sm mt-0.5">{run.residue_kg.toFixed(1)} kg</div>
                </div>
                <div>
                  <div className="text-[10px] text-teal-600 uppercase font-sans">Allocated to EPR</div>
                  <div className="font-bold text-teal-700 text-sm mt-0.5">{run.allocated_kg.toFixed(1)} kg</div>
                </div>
              </div>

              {/* Linked Batches Pill List */}
              <div className="flex flex-wrap items-center gap-2 text-xs">
                <span className="text-slate-500 font-medium">Source Batches:</span>
                {run.inputs.map((inp) => (
                  <span
                    key={inp.batch_id}
                    className="font-mono text-[11px] bg-white px-2 py-0.5 rounded border border-slate-200 text-slate-700 font-medium"
                  >
                    {inp.batch_code} ({inp.input_kg} kg)
                  </span>
                ))}
              </div>
            </div>
          )
        })}
      </div>

      {/* Create Processing Run Modal */}
      {isModalOpen && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 overflow-y-auto">
          <div className="bg-white rounded-2xl max-w-2xl w-full p-6 md:p-8 shadow-2xl border border-slate-200 space-y-6 my-8 animate-in fade-in">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h3 className="font-bold text-slate-900 text-base">New Mechanical Extrusion Run</h3>
                <p className="text-xs text-slate-500">
                  Select accepted batch inputs, record output pellets, and calculate true yield
                </p>
              </div>
              <button
                onClick={() => setIsModalOpen(false)}
                className="text-slate-400 hover:text-slate-600 p-1"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleCreateRun} className="space-y-5">
              {/* Batch Inputs Selector */}
              <div className="space-y-2">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700 flex justify-between">
                  <span>1. Select Accepted Raw Batch Inputs</span>
                  <span className="font-mono text-purple-700 font-bold">
                    Total Input: {totalInputKg.toFixed(1)} kg
                  </span>
                </label>

                {availableBatches.length === 0 ? (
                  <div className="p-4 bg-slate-50 rounded-xl text-xs text-slate-500 text-center">
                    No accepted batches in inventory. Record weighbridge receipts first.
                  </div>
                ) : (
                  <div className="grid grid-cols-1 sm:grid-cols-2 gap-2 max-h-40 overflow-y-auto">
                    {availableBatches.map((b) => {
                      const isSelected = selectedBatchIds.includes(b.id)
                      return (
                        <div
                          key={b.id}
                          onClick={() => handleToggleBatch(b)}
                          className={`p-3 rounded-xl border transition-all cursor-pointer text-xs ${
                            isSelected
                              ? 'bg-purple-50/80 border-purple-500 ring-2 ring-purple-500/20'
                              : 'bg-slate-50 border-slate-200 hover:border-slate-300'
                          }`}
                        >
                          <div className="flex items-center justify-between font-mono font-bold">
                            <span>{b.batch_code}</span>
                            <span className="text-purple-700">{b.quantities.accepted_kg} kg</span>
                          </div>
                          <div className="text-[11px] text-slate-500 mt-0.5">
                            {b.material} • {b.packaging_category} • Grade {b.quality_grade || 'A'}
                          </div>
                        </div>
                      )
                    })}
                  </div>
                )}
              </div>

              {/* Mass Balance Inputs */}
              <div className="space-y-3 bg-slate-50 p-4 rounded-xl border border-slate-200">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700 flex justify-between">
                  <span>2. Extrusion Output & Residue Accounting</span>
                  <span className="text-emerald-700 font-mono font-bold">Yield: {computedYield}%</span>
                </label>

                <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                  <div className="space-y-1">
                    <label className="text-[11px] font-bold text-slate-700">Output Pellets (kg)</label>
                    <input
                      type="number"
                      step="0.1"
                      value={outputKg}
                      onChange={(e) => setOutputKg(Number(e.target.value))}
                      className="w-full font-mono font-bold text-base px-3 py-2 rounded-xl border border-slate-300 focus:ring-2 focus:ring-purple-500 focus:outline-hidden"
                      required
                    />
                  </div>

                  <div className="space-y-1">
                    <label className="text-[11px] font-bold text-slate-700">Residue / Moisture Loss (kg)</label>
                    <input
                      type="number"
                      step="0.1"
                      value={residueKg}
                      onChange={(e) => setResidueKg(Number(e.target.value))}
                      className="w-full font-mono font-bold text-base px-3 py-2 rounded-xl border border-slate-300 focus:ring-2 focus:ring-purple-500 focus:outline-hidden"
                      required
                    />
                  </div>
                </div>

                {!isMassBalanceValid && totalInputKg > 0 && (
                  <div className="text-xs text-rose-700 bg-rose-50 p-2.5 rounded-lg border border-rose-200 flex items-center gap-2">
                    <AlertTriangle className="w-4 h-4 shrink-0" />
                    <span>
                      Mass Balance Violation: Output ({outputKg} kg) + Residue ({residueKg} kg) exceeds Input ({totalInputKg} kg).
                    </span>
                  </div>
                )}
              </div>

              {/* Certificate & Output Form */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-1">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Extrusion Product Form
                  </label>
                  <select
                    value={outputForm}
                    onChange={(e) => setOutputForm(e.target.value as any)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs font-medium"
                  >
                    <option value="Pellets">Recycled Pellets (Extruded)</option>
                    <option value="Granules">Shredded Granules (Regrind)</option>
                    <option value="Flakes">Hot-Washed Flakes</option>
                  </select>
                </div>

                <div className="space-y-1">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Statutory CPCB Ref Code
                  </label>
                  <input
                    type="text"
                    value={certificateRef}
                    onChange={(e) => setCertificateRef(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs font-mono font-bold"
                    required
                  />
                </div>
              </div>

              {/* Actions */}
              <div className="pt-4 border-t border-slate-100 flex items-center justify-end gap-2">
                <button
                  type="button"
                  onClick={() => setIsModalOpen(false)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={!isMassBalanceValid || selectedBatchIds.length === 0}
                  className={`px-6 py-2.5 rounded-xl text-xs font-bold shadow-md transition-all cursor-pointer ${
                    isMassBalanceValid && selectedBatchIds.length > 0
                      ? 'bg-purple-600 hover:bg-purple-700 text-white'
                      : 'bg-slate-200 text-slate-400 cursor-not-allowed'
                  }`}
                >
                  Finalize Processing Run
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
