import React, { useState } from 'react'
import { useApp } from '../../context/AppContext'
import type { WasteBatch } from '../../types'
import {
  Compass,
  MapPin,
  Sparkles,
  ChevronDown,
  ChevronUp,
  X,
  CheckCircle,
  Send,
} from 'lucide-react'

export const CollectorAvailableListings: React.FC = () => {
  const { batches, makeOffer, currentPersona } = useApp()
  const [selectedMaterial, setSelectedMaterial] = useState<string>('ALL')
  const [selectedLocality, setSelectedLocality] = useState<string>('ALL')
  const [selectedBatchForOffer, setSelectedBatchForOffer] = useState<WasteBatch | null>(null)
  const [offeredRate, setOfferedRate] = useState<number>(16.5)
  const [pickupSlot, setPickupSlot] = useState<string>('Tomorrow, 10:00 AM - 1:00 PM')
  const [openWhyId, setOpenWhyId] = useState<string | null>(null)
  const [offerSuccessMsg, setOfferSuccessMsg] = useState<string | null>(null)

  // Filter only LISTED batches
  const availableBatches = batches.filter((b) => b.status === 'LISTED')

  const filteredBatches = availableBatches.filter((b) => {
    if (selectedMaterial !== 'ALL' && b.material !== selectedMaterial) return false
    if (selectedLocality !== 'ALL' && b.locality !== selectedLocality) return false
    return true
  })

  const handleSendOffer = (e: React.FormEvent) => {
    e.preventDefault()
    if (!selectedBatchForOffer) return

    makeOffer(selectedBatchForOffer.id, offeredRate, pickupSlot)
    setOfferSuccessMsg(`Offer of ₹${offeredRate.toFixed(2)}/kg sent for ${selectedBatchForOffer.batch_code}`)
    setSelectedBatchForOffer(null)
    setTimeout(() => setOfferSuccessMsg(null), 4000)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900">Available Mumbai Listings</h1>
          <p className="text-xs text-slate-500">
            Segregated post-consumer batches broadcast by residential societies and commercial generators
          </p>
        </div>

        {/* Filter controls */}
        <div className="flex flex-wrap items-center gap-2">
          <select
            value={selectedMaterial}
            onChange={(e) => setSelectedMaterial(e.target.value)}
            className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-semibold bg-white"
          >
            <option value="ALL">All Polymers</option>
            <option value="PET">PET (Bottles)</option>
            <option value="HDPE">HDPE (Rigid)</option>
            <option value="PP">PP (Rigid)</option>
            <option value="LDPE">LDPE (Film)</option>
          </select>

          <select
            value={selectedLocality}
            onChange={(e) => setSelectedLocality(e.target.value)}
            className="px-3 py-1.5 rounded-xl border border-slate-300 text-xs font-semibold bg-white"
          >
            <option value="ALL">All Mumbai Localities</option>
            <option value="Andheri West">Andheri West</option>
            <option value="Bandra West">Bandra West</option>
            <option value="Goregaon East">Goregaon East</option>
            <option value="Lower Parel">Lower Parel</option>
            <option value="Powai">Powai</option>
          </select>
        </div>
      </div>

      {offerSuccessMsg && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-xl p-3.5 flex items-center gap-2 text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <CheckCircle className="w-4 h-4 text-emerald-600 shrink-0" />
          <span>{offerSuccessMsg}</span>
        </div>
      )}

      {/* Listings Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {filteredBatches.length === 0 ? (
          <div className="col-span-full bg-white rounded-2xl border border-slate-200 p-12 text-center text-slate-500">
            <Compass className="w-12 h-12 text-slate-300 mx-auto mb-3" />
            <div className="text-sm font-semibold text-slate-700">No active listings match criteria</div>
            <p className="text-xs text-slate-400 mt-1">Try resetting the polymer or locality filters.</p>
          </div>
        ) : (
          filteredBatches.map((batch) => {
            const hasMyOffer = batch.offers?.some((o) => o.collector_org_id === currentPersona.org_id)
            const isWhyOpen = openWhyId === batch.id

            return (
              <div
                key={batch.id}
                className="bg-white rounded-2xl border border-slate-200 shadow-xs hover:border-slate-300 transition-all p-5 flex flex-col justify-between space-y-4"
              >
                <div className="space-y-3">
                  {/* Top Bar */}
                  <div className="flex items-start justify-between gap-2">
                    <div>
                      <div className="flex items-center gap-2">
                        <span className="font-mono font-bold text-sm text-slate-900">
                          {batch.batch_code}
                        </span>
                        <span className="px-2 py-0.5 rounded-full bg-emerald-100 text-emerald-800 text-[11px] font-bold">
                          {batch.material}
                        </span>
                      </div>
                      <div className="text-xs text-slate-500 mt-0.5">{batch.generator_name}</div>
                    </div>

                    <div className="text-right">
                      <div className="text-[10px] uppercase font-bold text-slate-400">Estimated</div>
                      <div className="text-lg font-mono font-extrabold text-slate-900">
                        {batch.quantities.estimated_kg.toFixed(0)} <span className="text-xs font-sans font-normal text-slate-500">kg</span>
                      </div>
                    </div>
                  </div>

                  {/* Location & Availability */}
                  <div className="space-y-1 text-xs text-slate-600 bg-slate-50 p-3 rounded-xl border border-slate-100">
                    <div className="flex items-center gap-1.5 font-medium text-slate-800">
                      <MapPin className="w-3.5 h-3.5 text-blue-600 shrink-0" />
                      {batch.pickup_address}
                    </div>
                    <div className="flex items-center justify-between text-[11px] text-slate-500 pt-1">
                      <span>Locality: <strong>{batch.locality}</strong></span>
                      <span>Window: {batch.available_from} to {batch.available_to}</span>
                    </div>
                  </div>

                  {/* Match Fit Score & "Why?" Algorithmic Explanation */}
                  <div className="pt-1">
                    <button
                      type="button"
                      onClick={() => setOpenWhyId(isWhyOpen ? null : batch.id)}
                      className="text-[11px] font-semibold text-blue-700 hover:text-blue-800 inline-flex items-center gap-1"
                    >
                      <Sparkles className="w-3.5 h-3.5 text-blue-500" />
                      <span>Route Fit: 94% Match</span>
                      <span className="text-[10px] text-slate-400">(Why?)</span>
                      {isWhyOpen ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
                    </button>

                    {isWhyOpen && (
                      <div className="mt-2 p-2.5 rounded-lg bg-slate-50 border border-slate-200 text-[11px] text-slate-600 space-y-1 animate-in fade-in">
                        <div>• Within 2.8 km of current LCV pickup cluster</div>
                        <div>• Compatible with morning EV cargo capacity</div>
                        <div>• Verified segregation history: &lt;5% moisture</div>
                      </div>
                    )}
                  </div>
                </div>

                {/* Offer Action Button */}
                <div className="pt-3 border-t border-slate-100 flex items-center justify-between">
                  <div className="text-[11px] text-slate-500">
                    {batch.offers?.length || 0} offers submitted
                  </div>

                  {hasMyOffer ? (
                    <span className="px-3 py-1.5 rounded-xl bg-blue-50 text-blue-700 text-xs font-bold border border-blue-200">
                      ✓ Offer Sent
                    </span>
                  ) : (
                    <button
                      onClick={() => {
                        setSelectedBatchForOffer(batch)
                        setOfferedRate(batch.material === 'PET' ? 16.5 : batch.material === 'HDPE' ? 18.0 : 14.5)
                      }}
                      className="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold shadow-xs transition-colors cursor-pointer"
                    >
                      Make Offer
                    </button>
                  )}
                </div>
              </div>
            )
          })
        )}
      </div>

      {/* Make Offer Modal */}
      {selectedBatchForOffer && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4">
          <div className="bg-white rounded-2xl max-w-md w-full p-6 shadow-2xl border border-slate-200 space-y-4">
            <div className="flex items-center justify-between border-b border-slate-100 pb-3">
              <div>
                <h3 className="font-bold text-slate-900 text-base">Submit Collection Quote</h3>
                <p className="text-xs text-slate-500">
                  {selectedBatchForOffer.batch_code} • {selectedBatchForOffer.material} (
                  {selectedBatchForOffer.quantities.estimated_kg} kg)
                </p>
              </div>
              <button
                onClick={() => setSelectedBatchForOffer(null)}
                className="text-slate-400 hover:text-slate-600 p-1"
              >
                <X className="w-5 h-5" />
              </button>
            </div>

            <form onSubmit={handleSendOffer} className="space-y-4">
              <div className="space-y-1.5">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                  Offered Rate (₹ / kg)
                </label>
                <div className="relative">
                  <span className="absolute left-3 top-2.5 text-slate-400 font-mono font-bold text-sm">₹</span>
                  <input
                    type="number"
                    step="0.5"
                    min="5"
                    max="50"
                    value={offeredRate}
                    onChange={(e) => setOfferedRate(Number(e.target.value))}
                    className="w-full pl-8 pr-3 py-2 rounded-xl border border-slate-300 text-sm font-mono font-bold focus:ring-2 focus:ring-blue-500 focus:outline-hidden"
                    required
                  />
                </div>
                <div className="flex justify-between text-[11px] text-slate-500 font-mono">
                  <span>Gross Payout: ₹{(offeredRate * selectedBatchForOffer.quantities.estimated_kg).toFixed(0)}</span>
                  <span>Recycler Buyback: ₹{((offeredRate + 3.5) * selectedBatchForOffer.quantities.estimated_kg).toFixed(0)}</span>
                </div>
              </div>

              <div className="space-y-1.5">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                  Proposed Pickup Window
                </label>
                <input
                  type="text"
                  value={pickupSlot}
                  onChange={(e) => setPickupSlot(e.target.value)}
                  className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs font-medium focus:ring-2 focus:ring-blue-500 focus:outline-hidden"
                  placeholder="e.g. Tomorrow, 10:00 AM - 1:00 PM"
                  required
                />
              </div>

              <div className="pt-2 flex items-center justify-end gap-2 border-t border-slate-100">
                <button
                  type="button"
                  onClick={() => setSelectedBatchForOffer(null)}
                  className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
                >
                  Cancel
                </button>
                <button
                  type="submit"
                  className="inline-flex items-center gap-1.5 px-5 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold shadow-xs cursor-pointer"
                >
                  <Send className="w-3.5 h-3.5" />
                  Transmit Offer
                </button>
              </div>
            </form>
          </div>
        </div>
      )}
    </div>
  )
}
