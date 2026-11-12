import React, { useState } from 'react'
import { useApp } from '../../context/AppContext'
import type { WasteBatch } from '../../types'
import {
  Scale,
  CheckCircle2,
  AlertTriangle,
} from 'lucide-react'

export const RecyclerInboundReceiving: React.FC = () => {
  const { batches, receiveBatch } = useApp()

  const [selectedBatch, setSelectedBatch] = useState<WasteBatch | null>(null)
  const [receivedKg, setReceivedKg] = useState<number>(77.5)
  const [acceptedKg, setAcceptedKg] = useState<number>(74.0)
  const [rejectedKg, setRejectedKg] = useState<number>(3.5)
  const [qualityGrade, setQualityGrade] = useState<'A' | 'B' | 'C'>('B')
  const [contaminationPct, setContaminationPct] = useState<number>(4.5)
  const [rejectionReason, setRejectionReason] = useState<string>('Non-target polymer film mixed in bale bottom')
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  // Inbound batches
  const inboundBatches = batches.filter(
    (b) => b.status === 'IN_TRANSIT' || (b.status === 'RECEIVED' && b.quantities.accepted_kg)
  )

  const isSumValid = Math.abs(acceptedKg + rejectedKg - receivedKg) < 0.01

  const handleSelectBatch = (batch: WasteBatch) => {
    setSelectedBatch(batch)
    const coll = batch.quantities.collected_kg || 100
    setReceivedKg(coll)
    setAcceptedKg(Number((coll * 0.95).toFixed(1)))
    setRejectedKg(Number((coll * 0.05).toFixed(1)))
    setSuccessMessage(null)
  }

  const handleSubmitReceipt = (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedBatch) return
    if (!isSumValid) return

    receiveBatch(
      selectedBatch.id,
      receivedKg,
      acceptedKg,
      rejectedKg,
      qualityGrade,
      contaminationPct,
      rejectionReason
    )

    setSuccessMessage(
      `Weighbridge receipt created for ${selectedBatch.batch_code}! Accepted: ${acceptedKg} kg, Rejected: ${rejectedKg} kg.`
    )
    setSelectedBatch(null)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl md:text-2xl font-bold text-slate-900">Inbound Weighbridge & Intake</h1>
        <p className="text-xs text-slate-500">
          Gross-Tare weighbridge entry, contamination inspection, and mass balance intake validation
        </p>
      </div>

      {successMessage && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-2xl p-4 flex items-center gap-2 text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          <span className="font-semibold">{successMessage}</span>
        </div>
      )}

      {/* Inbound Queue & Scanner Card */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left: Queue */}
        <div className="lg:col-span-1 space-y-3">
          <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-5 space-y-3">
            <div className="flex items-center justify-between border-b border-slate-100 pb-2">
              <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Inbound Consignments ({inboundBatches.length})
              </h2>
              <span className="text-[11px] font-mono text-purple-700 bg-purple-50 px-2 py-0.5 rounded">
                QR Scanner Active
              </span>
            </div>

            <div className="space-y-2 max-h-[500px] overflow-y-auto">
              {inboundBatches.length === 0 ? (
                <div className="p-6 text-center text-slate-500 text-xs">
                  No inbound consignments currently en route.
                </div>
              ) : (
                inboundBatches.map((b) => {
                  const isSelected = selectedBatch?.id === b.id
                  const isAlreadyReceived = b.status === 'RECEIVED'
                  return (
                    <div
                      key={b.id}
                      onClick={() => handleSelectBatch(b)}
                      className={`p-3 rounded-xl border transition-all cursor-pointer ${
                        isSelected
                          ? 'bg-purple-50/80 border-purple-500 ring-2 ring-purple-500/20'
                          : isAlreadyReceived
                          ? 'bg-slate-50/50 border-slate-200 opacity-80'
                          : 'bg-white border-slate-200 hover:border-slate-300'
                      }`}
                    >
                      <div className="flex items-center justify-between">
                        <span className="font-mono font-bold text-xs text-slate-900">
                          {b.batch_code}
                        </span>
                        <span
                          className={`text-[10px] font-bold px-2 py-0.5 rounded ${
                            isAlreadyReceived
                              ? 'bg-emerald-100 text-emerald-800'
                              : 'bg-blue-100 text-blue-800'
                          }`}
                        >
                          {b.status}
                        </span>
                      </div>
                      <div className="text-[11px] text-slate-500 mt-1">
                        {b.material} • {b.quantities.collected_kg || b.quantities.estimated_kg} kg collected
                      </div>
                      <div className="text-[10px] text-slate-400 truncate mt-0.5">
                        Collector: {b.collector_name || 'Mumbai Eco Logistics'}
                      </div>
                    </div>
                  )
                })
              )}
            </div>
          </div>
        </div>

        {/* Right 2 Cols: Weighbridge Entry Form */}
        <div className="lg:col-span-2">
          {selectedBatch ? (
            <form
              onSubmit={handleSubmitReceipt}
              className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 md:p-8 space-y-6 animate-in fade-in"
            >
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-100 pb-4">
                <div>
                  <div className="flex items-center gap-2">
                    <span className="font-mono font-bold text-lg text-slate-900">
                      {selectedBatch.batch_code}
                    </span>
                    <span className="text-xs font-bold px-2 py-0.5 rounded bg-purple-100 text-purple-800">
                      {selectedBatch.material} ({selectedBatch.packaging_category})
                    </span>
                  </div>
                  <p className="text-xs text-slate-500 mt-0.5">
                    Generator: {selectedBatch.generator_name} • Collector: {selectedBatch.collector_name}
                  </p>
                </div>
                <div className="text-right">
                  <div className="text-[10px] uppercase font-bold text-slate-400">Doorstep Collected</div>
                  <div className="text-lg font-mono font-bold text-slate-800">
                    {selectedBatch.quantities.collected_kg?.toFixed(1) || selectedBatch.quantities.estimated_kg.toFixed(1)} kg
                  </div>
                </div>
              </div>

              {/* Three Weight Inputs */}
              <div className="space-y-3">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center justify-between">
                  <span>Weighbridge Measurement</span>
                  <span className="text-[11px] font-mono font-normal text-slate-500">
                    Rule: Accepted + Rejected = Received
                  </span>
                </label>

                <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
                  {/* Received Kg */}
                  <div className="space-y-1 bg-slate-50 p-3.5 rounded-xl border border-slate-200">
                    <label className="text-[11px] font-bold text-slate-700">Gross Received (kg)</label>
                    <input
                      type="number"
                      step="0.1"
                      value={receivedKg}
                      onChange={(e) => setReceivedKg(Number(e.target.value))}
                      className="w-full text-lg font-mono font-bold px-3 py-2 rounded-lg border border-slate-300 focus:outline-hidden focus:ring-2 focus:ring-purple-500"
                      required
                    />
                    <div className="text-[10px] text-slate-500">Total gross intake on scale</div>
                  </div>

                  {/* Accepted Kg */}
                  <div className="space-y-1 bg-emerald-50/60 p-3.5 rounded-xl border border-emerald-200">
                    <label className="text-[11px] font-bold text-emerald-800">Accepted (kg)</label>
                    <input
                      type="number"
                      step="0.1"
                      value={acceptedKg}
                      onChange={(e) => setAcceptedKg(Number(e.target.value))}
                      className="w-full text-lg font-mono font-bold px-3 py-2 rounded-lg border border-emerald-300 focus:outline-hidden focus:ring-2 focus:ring-emerald-500 text-emerald-900"
                      required
                    />
                    <div className="text-[10px] text-emerald-700">Feeds into processing run</div>
                  </div>

                  {/* Rejected Kg */}
                  <div className="space-y-1 bg-rose-50/60 p-3.5 rounded-xl border border-rose-200">
                    <label className="text-[11px] font-bold text-rose-800">Rejected (kg)</label>
                    <input
                      type="number"
                      step="0.1"
                      value={rejectedKg}
                      onChange={(e) => setRejectedKg(Number(e.target.value))}
                      className="w-full text-lg font-mono font-bold px-3 py-2 rounded-lg border border-rose-300 focus:outline-hidden focus:ring-2 focus:ring-rose-500 text-rose-900"
                      required
                    />
                    <div className="text-[10px] text-rose-700">Contaminated fraction</div>
                  </div>
                </div>

                {/* Validation Status Notice */}
                {!isSumValid ? (
                  <div className="bg-rose-50 border border-rose-300 rounded-xl p-3 flex items-center gap-2 text-xs text-rose-800 font-medium">
                    <AlertTriangle className="w-4 h-4 shrink-0" />
                    <span>
                      Mass Balance Violation: Accepted ({acceptedKg} kg) + Rejected ({rejectedKg} kg) = {(acceptedKg + rejectedKg).toFixed(1)} kg ≠ Received ({receivedKg} kg).
                    </span>
                  </div>
                ) : (
                  <div className="bg-emerald-50 border border-emerald-300 rounded-xl p-2.5 flex items-center gap-2 text-xs text-emerald-800 font-medium">
                    <CheckCircle2 className="w-4 h-4 text-emerald-600 shrink-0" />
                    <span>Weighbridge Mass Balance verified: {acceptedKg} + {rejectedKg} = {receivedKg} kg</span>
                  </div>
                )}
              </div>

              {/* Quality Grade & Contamination % */}
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-4">
                <div className="space-y-1.5">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Quality Grade
                  </label>
                  <div className="grid grid-cols-3 gap-2">
                    {(['A', 'B', 'C'] as const).map((grade) => (
                      <button
                        key={grade}
                        type="button"
                        onClick={() => setQualityGrade(grade)}
                        className={`py-2 rounded-xl border text-xs font-bold transition-all cursor-pointer ${
                          qualityGrade === grade
                            ? 'bg-purple-600 text-white border-purple-600 shadow-xs'
                            : 'bg-white border-slate-200 text-slate-700 hover:border-slate-300'
                        }`}
                      >
                        Grade {grade}
                      </button>
                    ))}
                  </div>
                </div>

                <div className="space-y-1.5">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-700 flex justify-between">
                    <span>Contamination %</span>
                    <span className="font-mono font-bold text-slate-800">{contaminationPct}%</span>
                  </label>
                  <input
                    type="range"
                    min="0"
                    max="20"
                    step="0.5"
                    value={contaminationPct}
                    onChange={(e) => setContaminationPct(Number(e.target.value))}
                    className="w-full accent-purple-600 cursor-pointer"
                  />
                  <div className="flex justify-between text-[10px] text-slate-400 font-mono">
                    <span>0% Clean</span>
                    <span>10% Tolerable</span>
                    <span>20% Heavy</span>
                  </div>
                </div>
              </div>

              {/* Rejection Disposition */}
              {rejectedKg > 0 && (
                <div className="space-y-1.5">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Rejection Disposition & Audit Note
                  </label>
                  <input
                    type="text"
                    value={rejectionReason}
                    onChange={(e) => setRejectionReason(e.target.value)}
                    className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs focus:ring-2 focus:ring-purple-500 focus:outline-hidden"
                    placeholder="e.g. Non-target polymer fraction segregated for energy recovery"
                  />
                </div>
              )}

              {/* Actions */}
              <div className="pt-4 border-t border-slate-100 flex items-center justify-between">
                <button
                  type="button"
                  onClick={() => setSelectedBatch(null)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  disabled={!isSumValid}
                  className={`px-6 py-3 rounded-xl text-xs font-bold shadow-md transition-all cursor-pointer ${
                    isSumValid
                      ? 'bg-purple-600 hover:bg-purple-700 text-white'
                      : 'bg-slate-200 text-slate-400 cursor-not-allowed'
                  }`}
                >
                  Record Weighbridge Receipt
                </button>
              </div>
            </form>
          ) : (
            <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center text-slate-500">
              <Scale className="w-12 h-12 text-slate-300 mx-auto mb-3" />
              <div className="text-sm font-semibold text-slate-700">No consignment selected</div>
              <p className="text-xs text-slate-400 mt-1">
                Select an inbound consignment from the left list to enter weighbridge gross-tare values.
              </p>
            </div>
          )}
        </div>
      </div>
    </div>
  )
}
