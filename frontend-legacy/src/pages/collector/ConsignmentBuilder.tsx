import React, { useState } from 'react'
import { useApp } from '../../context/AppContext'
import { StatusBadge } from '../../components/common/StatusBadge'
import {
  CheckCircle2,
  Send,
} from 'lucide-react'

const RECYCLERS = [
  {
    id: 'org-rec-01',
    name: 'Apex Plastic Recovery PWP',
    locality: 'Turbhe, Navi Mumbai',
    acceptedMaterials: 'PET, HDPE, PP',
    ratePerKg: '₹24.50 / kg',
  },
  {
    id: 'org-rec-02',
    name: 'Maharashtra Polymer Recycling Ltd',
    locality: 'Bhiwandi Hub',
    acceptedMaterials: 'PET, PP, LDPE',
    ratePerKg: '₹23.80 / kg',
  },
]

export const CollectorConsignmentBuilder: React.FC = () => {
  const { batches, consignments, createConsignment, currentPersona } = useApp()

  const [selectedBatchIds, setSelectedBatchIds] = useState<string[]>([])
  const [selectedRecyclerId, setSelectedRecyclerId] = useState<string>(RECYCLERS[0].id)
  const [vehicleNo, setVehicleNo] = useState<string>('MH-02-EE-8421 (Tata Ace EV)')
  const [successConsignment, setSuccessConsignment] = useState<string | null>(null)

  // Picked up batches awaiting consignment dispatch
  const readyBatches = batches.filter(
    (b) => b.collector_org_id === currentPersona.org_id && b.status === 'PICKED_UP'
  )

  const selectedRecycler = RECYCLERS.find((r) => r.id === selectedRecyclerId) || RECYCLERS[0]

  const totalSelectedKg = readyBatches
    .filter((b) => selectedBatchIds.includes(b.id))
    .reduce((acc, b) => acc + (b.quantities.collected_kg || 0), 0)

  const handleToggleBatch = (id: string) => {
    setSelectedBatchIds((prev) =>
      prev.includes(id) ? prev.filter((bId) => bId !== id) : [...prev, id]
    )
  }

  const handleDispatch = (e: React.FormEvent) => {
    e.preventDefault()
    if (selectedBatchIds.length === 0) return

    const newCons = createConsignment(
      selectedBatchIds,
      selectedRecycler.id,
      selectedRecycler.name,
      vehicleNo
    )

    setSuccessConsignment(newCons.consignment_code)
    setSelectedBatchIds([])
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl md:text-2xl font-bold text-slate-900">Consignment Dispatch Builder</h1>
        <p className="text-xs text-slate-500">
          Bundle picked-up batches into a vehicle consignment and dispatch to CPCB-registered recyclers
        </p>
      </div>

      {successConsignment && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-2xl p-4 flex items-center justify-between text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
            <div>
              <span className="font-bold text-sm">Consignment Dispatched!</span>
              <p className="text-emerald-700">
                Consignment code <strong className="font-mono">{successConsignment}</strong> is now en route to {selectedRecycler.name}.
              </p>
            </div>
          </div>
          <button
            onClick={() => setSuccessConsignment(null)}
            className="text-emerald-800 font-semibold underline text-xs"
          >
            Dismiss
          </button>
        </div>
      )}

      {/* Main Builder Form */}
      <form onSubmit={handleDispatch} className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Left 2 Cols: Batch Selection */}
        <div className="lg:col-span-2 space-y-4">
          <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h2 className="text-sm font-bold text-slate-900">
                  1. Select Picked-up Batches for Consignment
                </h2>
                <p className="text-xs text-slate-500">
                  Batches currently stored in transit hub awaiting recycler dispatch
                </p>
              </div>
              <span className="text-xs font-mono font-bold text-blue-700 bg-blue-50 px-2.5 py-1 rounded-lg border border-blue-200">
                {readyBatches.length} Batches Ready
              </span>
            </div>

            {readyBatches.length === 0 ? (
              <div className="p-8 text-center text-slate-500 text-xs">
                No picked-up batches awaiting dispatch. Complete active pickups first.
              </div>
            ) : (
              <div className="space-y-2.5">
                {readyBatches.map((batch) => {
                  const isChecked = selectedBatchIds.includes(batch.id)
                  return (
                    <div
                      key={batch.id}
                      onClick={() => handleToggleBatch(batch.id)}
                      className={`p-3.5 rounded-xl border flex items-center justify-between transition-all cursor-pointer ${
                        isChecked
                          ? 'bg-blue-50/70 border-blue-500 ring-2 ring-blue-500/20'
                          : 'bg-slate-50 border-slate-200 hover:border-slate-300'
                      }`}
                    >
                      <div className="flex items-center gap-3">
                        <input
                          type="checkbox"
                          checked={isChecked}
                          onChange={() => {}}
                          className="w-4 h-4 rounded text-blue-600 accent-blue-600"
                        />
                        <div>
                          <div className="flex items-center gap-2">
                            <span className="font-mono font-bold text-xs text-slate-900">
                              {batch.batch_code}
                            </span>
                            <span className="text-[11px] font-bold px-2 py-0.2 rounded bg-slate-200 text-slate-800">
                              {batch.material}
                            </span>
                          </div>
                          <div className="text-[11px] text-slate-500 mt-0.5">
                            {batch.generator_name} • {batch.locality}
                          </div>
                        </div>
                      </div>

                      <div className="text-right">
                        <div className="text-sm font-mono font-extrabold text-slate-900">
                          {batch.quantities.collected_kg?.toFixed(1)}{' '}
                          <span className="text-xs font-sans font-normal text-slate-500">kg</span>
                        </div>
                        <div className="text-[10px] text-emerald-600 font-semibold">Doorstep Weighed</div>
                      </div>
                    </div>
                  )
                })}
              </div>
            )}
          </div>
        </div>

        {/* Right Col: Recycler Destination & Dispatch Details */}
        <div className="space-y-4">
          <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
            <h2 className="text-sm font-bold text-slate-900 border-b border-slate-100 pb-2">
              2. Consignment Target & Vehicle
            </h2>

            {/* Recycler Picker */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Destination Recycler
              </label>
              <div className="space-y-2">
                {RECYCLERS.map((rec) => (
                  <button
                    key={rec.id}
                    type="button"
                    onClick={() => setSelectedRecyclerId(rec.id)}
                    className={`w-full text-left p-3 rounded-xl border transition-all cursor-pointer ${
                      selectedRecyclerId === rec.id
                        ? 'bg-blue-50/70 border-blue-500 ring-2 ring-blue-500/20'
                        : 'bg-white border-slate-200 hover:border-slate-300'
                    }`}
                  >
                    <div className="font-bold text-xs text-slate-900">{rec.name}</div>
                    <div className="text-[11px] text-slate-500">{rec.locality}</div>
                    <div className="flex items-center justify-between text-[11px] font-mono mt-1 text-emerald-700 font-semibold">
                      <span>Rate: {rec.ratePerKg}</span>
                      <span>Accepts {rec.acceptedMaterials}</span>
                    </div>
                  </button>
                ))}
              </div>
            </div>

            {/* Vehicle Number */}
            <div className="space-y-1.5">
              <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Transport Vehicle No.
              </label>
              <input
                type="text"
                value={vehicleNo}
                onChange={(e) => setVehicleNo(e.target.value)}
                className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs font-mono font-bold focus:ring-2 focus:ring-blue-500 focus:outline-hidden"
                required
              />
            </div>

            {/* Summary Box */}
            <div className="bg-slate-50 p-4 rounded-xl border border-slate-200 space-y-2 text-xs">
              <div className="flex justify-between">
                <span className="text-slate-500">Batches Selected:</span>
                <span className="font-mono font-bold text-slate-900">{selectedBatchIds.length}</span>
              </div>
              <div className="flex justify-between">
                <span className="text-slate-500">Total Net Weight:</span>
                <span className="font-mono font-bold text-blue-700 text-sm">
                  {totalSelectedKg.toFixed(1)} kg
                </span>
              </div>
              <div className="flex justify-between border-t border-slate-200 pt-2 font-semibold">
                <span className="text-slate-700">Est. Consignment Value:</span>
                <span className="font-mono font-bold text-emerald-700">
                  ₹{(totalSelectedKg * 24.5).toFixed(0)}
                </span>
              </div>
            </div>

            {/* Dispatch Button */}
            <button
              type="submit"
              disabled={selectedBatchIds.length === 0}
              className={`w-full py-3 rounded-xl font-bold text-xs shadow-md transition-all flex items-center justify-center gap-2 cursor-pointer ${
                selectedBatchIds.length > 0
                  ? 'bg-blue-600 hover:bg-blue-700 text-white'
                  : 'bg-slate-200 text-slate-400 cursor-not-allowed'
              }`}
            >
              <Send className="w-4 h-4" />
              Dispatch Consignment ({selectedBatchIds.length})
            </button>
          </div>
        </div>
      </form>

      {/* Dispatched Consignments History */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
        <h2 className="text-sm font-bold text-slate-900 border-b border-slate-100 pb-2">
          Dispatched Consignments Ledger
        </h2>
        <div className="divide-y divide-slate-100">
          {consignments.map((cons) => (
            <div key={cons.id} className="py-3.5 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <span className="font-mono font-bold text-sm text-slate-900">
                    {cons.consignment_code}
                  </span>
                  <StatusBadge status={cons.status} />
                  <span className="text-xs text-slate-500 font-mono">
                    {cons.vehicle_no}
                  </span>
                </div>
                <div className="text-xs text-slate-600">
                  Destination: <strong>{cons.destination_recycler_name}</strong> •{' '}
                  {cons.batch_ids.length} linked batches
                </div>
              </div>

              <div className="text-xs text-slate-400 font-mono">
                {new Date(cons.created_at).toLocaleString()}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
