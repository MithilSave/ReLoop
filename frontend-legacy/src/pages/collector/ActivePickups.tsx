import React, { useState } from 'react'
import { Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import type { WasteBatch } from '../../types'
import {
  Truck,
  Scale,
  KeyRound,
  MapPin,
  CheckCircle2,
  AlertCircle,
  X,
  ShieldCheck,
  Package,
} from 'lucide-react'

export const CollectorActivePickups: React.FC = () => {
  const { batches, completePickup, currentPersona } = useApp()

  const [activeBatchForPickup, setActiveBatchForPickup] = useState<WasteBatch | null>(null)
  const [actualWeight, setActualWeight] = useState<number>(108.5)
  const [enteredOtp, setEnteredOtp] = useState<string>('')
  const [errorMessage, setErrorMessage] = useState<string | null>(null)
  const [successMessage, setSuccessMessage] = useState<string | null>(null)

  // Assigned batches for this collector
  const assignedBatches = batches.filter(
    (b) => b.collector_org_id === currentPersona.org_id && b.status === 'ASSIGNED'
  )

  const pickedUpBatches = batches.filter(
    (b) => b.collector_org_id === currentPersona.org_id && b.status === 'PICKED_UP'
  )

  const handleStartPickup = (batch: WasteBatch) => {
    setActiveBatchForPickup(batch)
    // Suggest weight near the estimate
    setActualWeight(batch.quantities.estimated_kg ? batch.quantities.estimated_kg - 1.5 : 100)
    setEnteredOtp(batch.pickup_otp || '') // Pre-fill with demo convenience or allow manual typing
    setErrorMessage(null)
  }

  const handleVerifyAndComplete = (e: React.FormEvent) => {
    e.preventDefault()
    if (!activeBatchForPickup) return

    const result = completePickup(activeBatchForPickup.id, actualWeight, enteredOtp)
    if (!result.success) {
      setErrorMessage(result.error || 'Verification failed')
      return
    }

    setSuccessMessage(`Successfully picked up ${actualWeight.toFixed(1)} kg from ${activeBatchForPickup.generator_name}! Batch is now ready for consignment dispatch.`)
    setActiveBatchForPickup(null)
    setEnteredOtp('')
    setTimeout(() => setSuccessMessage(null), 5000)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900">Active Route Pickups</h1>
          <p className="text-xs text-slate-500">
            Verify actual collected weights and obtain generator OTP for immutable custody transfer
          </p>
        </div>

        <Link
          to="/collector/consignments"
          className="inline-flex items-center gap-1.5 px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold shadow-xs transition-colors"
        >
          <Package className="w-4 h-4" />
          <span>Consignment Builder ({pickedUpBatches.length} Ready)</span>
        </Link>
      </div>

      {successMessage && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-2xl p-4 flex items-center justify-between text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
            <span className="font-medium">{successMessage}</span>
          </div>
          <Link
            to="/collector/consignments"
            className="px-3 py-1.5 rounded-lg bg-emerald-600 text-white font-bold hover:bg-emerald-700 transition-colors"
          >
            Create Consignment →
          </Link>
        </div>
      )}

      {/* Stop Sequence List */}
      <div className="space-y-4">
        <h2 className="text-xs font-bold uppercase tracking-wider text-slate-400">
          Pending Stops ({assignedBatches.length})
        </h2>

        {assignedBatches.length === 0 ? (
          <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center text-slate-500">
            <Truck className="w-12 h-12 text-slate-300 mx-auto mb-3" />
            <div className="text-sm font-semibold text-slate-700">All assigned stops complete!</div>
            <p className="text-xs text-slate-400 mt-1">
              Browse available listings or head to the Consignment Builder to dispatch picked-up batches to a recycler.
            </p>
          </div>
        ) : (
          assignedBatches.map((batch, index) => (
            <div
              key={batch.id}
              className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 flex flex-col md:flex-row md:items-center justify-between gap-4"
            >
              <div className="flex items-start gap-4">
                <div className="w-10 h-10 rounded-xl bg-blue-100 text-blue-700 font-bold font-mono text-sm flex items-center justify-center shrink-0">
                  Stop {index + 1}
                </div>
                <div className="space-y-1.5">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-mono font-bold text-base text-slate-900">
                      {batch.batch_code}
                    </span>
                    <span className="text-xs font-semibold px-2 py-0.5 rounded bg-blue-50 text-blue-700 border border-blue-200">
                      {batch.material} ({batch.quantities.estimated_kg} kg est.)
                    </span>
                    <span className="text-xs font-bold text-amber-700 bg-amber-50 px-2 py-0.5 rounded border border-amber-200">
                      OTP Handover Required
                    </span>
                  </div>

                  <div className="text-xs font-semibold text-slate-800">
                    {batch.generator_name}
                  </div>
                  <div className="text-xs text-slate-500 flex items-center gap-1">
                    <MapPin className="w-3.5 h-3.5 text-slate-400" />
                    {batch.pickup_address}
                  </div>
                </div>
              </div>

              {/* Action Button */}
              <button
                onClick={() => handleStartPickup(batch)}
                className="px-5 py-3 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold shadow-md transition-all shrink-0 cursor-pointer flex items-center justify-center gap-2"
              >
                <Scale className="w-4 h-4" />
                Record Weight & Enter OTP
              </button>
            </div>
          ))
        )}
      </div>

      {/* Weight Recording & OTP Verification Modal */}
      {activeBatchForPickup && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-5 animate-in fade-in zoom-in-95">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h3 className="font-bold text-slate-900 text-base flex items-center gap-2">
                  <Scale className="w-5 h-5 text-blue-600" />
                  Doorstep Weight & OTP Verification
                </h3>
                <p className="text-xs text-slate-500">
                  {activeBatchForPickup.batch_code} • {activeBatchForPickup.generator_name}
                </p>
              </div>
              <button
                onClick={() => setActiveBatchForPickup(null)}
                className="text-slate-400 hover:text-slate-600 p-1"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            {errorMessage && (
              <div className="bg-rose-50 border border-rose-200 rounded-xl p-3 flex items-center gap-2 text-xs text-rose-800">
                <AlertCircle className="w-4 h-4 shrink-0" />
                <span>{errorMessage}</span>
              </div>
            )}

            <form onSubmit={handleVerifyAndComplete} className="space-y-4">
              {/* Actual Weight Recording with Digital Scale Indicator */}
              <div className="space-y-1.5 bg-slate-50 p-4 rounded-xl border border-slate-200">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center justify-between">
                  <span>Actual Weighed Weight (kg)</span>
                  <span className="text-[10px] text-emerald-600 font-mono font-bold">
                    IoT Bluetooth Scale Connected
                  </span>
                </label>
                <div className="relative">
                  <input
                    type="number"
                    step="0.1"
                    min="1"
                    max="1000"
                    value={actualWeight}
                    onChange={(e) => setActualWeight(Number(e.target.value))}
                    className="w-full px-3 py-3 rounded-xl border border-slate-300 text-2xl font-mono font-extrabold text-slate-900 focus:ring-2 focus:ring-blue-500 focus:outline-hidden"
                    required
                  />
                  <span className="absolute right-3 top-3.5 text-xs font-bold text-slate-400 font-mono">
                    KG
                  </span>
                </div>
                <div className="flex justify-between text-[11px] text-slate-500 font-mono mt-1">
                  <span>Estimated: {activeBatchForPickup.quantities.estimated_kg.toFixed(1)} kg</span>
                  <span>
                    Variance: {(actualWeight - activeBatchForPickup.quantities.estimated_kg).toFixed(1)} kg
                  </span>
                </div>
              </div>

              {/* 6-Digit Generator OTP */}
              <div className="space-y-1.5">
                <div className="flex items-center justify-between">
                  <label className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-1.5">
                    <KeyRound className="w-3.5 h-3.5 text-amber-600" />
                    Generator 6-Digit Handover OTP
                  </label>
                  {activeBatchForPickup.pickup_otp && (
                    <span className="text-[10px] font-mono text-slate-600 bg-slate-100 px-1.5 py-0.5 rounded">
                      Demo OTP: {activeBatchForPickup.pickup_otp}
                    </span>
                  )}
                </div>
                <input
                  type="text"
                  maxLength={6}
                  value={enteredOtp}
                  onChange={(e) => setEnteredOtp(e.target.value)}
                  placeholder="Ask generator for 6-digit code"
                  className="w-full px-3 py-2.5 rounded-xl border border-slate-300 text-lg font-mono font-bold tracking-widest text-center focus:ring-2 focus:ring-blue-500 focus:outline-hidden"
                  required
                />
                <p className="text-[11px] text-slate-500">
                  The generator views this OTP on their ReLoop dashboard upon collector arrival.
                </p>
              </div>

              {/* Submit Button */}
              <div className="pt-2 flex items-center justify-end gap-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setActiveBatchForPickup(null)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="inline-flex items-center gap-1.5 px-6 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold shadow-xs cursor-pointer"
                >
                  <ShieldCheck className="w-4 h-4" />
                  Confirm Handover & Pickup
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
