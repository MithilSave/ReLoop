import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import {
  DollarSign,
  Truck,
  CheckCircle,
  HelpCircle,
  ChevronDown,
  ChevronUp,
  Clock,
  MapPin,
} from 'lucide-react'

export const GeneratorCollectorOffers: React.FC = () => {
  const navigate = useNavigate()
  const { batches, acceptOffer } = useApp()
  const [openWhyId, setOpenWhyId] = useState<string | null>('off-002')

  // Collect batches with offers
  const batchesWithOffers = batches.filter((b) => b.offers && b.offers.length > 0)

  const handleAccept = (batchId: string, offerId: string) => {
    acceptOffer(batchId, offerId)
    navigate('/generator/batches')
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-xl md:text-2xl font-bold text-slate-900">Collector Offers</h1>
        <p className="text-xs text-slate-500">
          Ranked quotes from registered collectors matching your material category and Mumbai locality
        </p>
      </div>

      {batchesWithOffers.length === 0 ? (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center text-slate-500">
          <DollarSign className="w-12 h-12 text-slate-300 mx-auto mb-3" />
          <div className="text-sm font-semibold text-slate-700">No active offers received yet</div>
          <p className="text-xs text-slate-400 mt-1">
            Offers will appear here once verified collectors review your listed batches.
          </p>
        </div>
      ) : (
        batchesWithOffers.map((batch) => (
          <div key={batch.id} className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
            {/* Batch Header */}
            <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-100 pb-3">
              <div className="flex items-center gap-2.5">
                <span className="font-mono font-bold text-sm text-slate-900">
                  {batch.batch_code}
                </span>
                <span className="text-xs font-semibold px-2.5 py-0.5 rounded-full bg-emerald-100 text-emerald-800">
                  {batch.material} ({batch.quantities.estimated_kg} kg)
                </span>
                <span className="text-xs text-slate-500 flex items-center gap-1">
                  <MapPin className="w-3.5 h-3.5" /> {batch.locality}
                </span>
              </div>
              <div className="text-xs font-medium text-slate-500">
                Status: <strong className="text-slate-800">{batch.status}</strong>
              </div>
            </div>

            {/* Offers List */}
            <div className="space-y-3">
              {batch.offers?.map((offer) => {
                const isWhyOpen = openWhyId === offer.id
                const isAccepted = offer.status === 'ACCEPTED'

                return (
                  <div
                    key={offer.id}
                    className={`rounded-xl border p-4 transition-all ${
                      isAccepted
                        ? 'bg-emerald-50/60 border-emerald-300 ring-2 ring-emerald-500/20'
                        : 'bg-slate-50/70 border-slate-200 hover:border-slate-300'
                    }`}
                  >
                    <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                      {/* Left: Collector info */}
                      <div className="space-y-1">
                        <div className="flex items-center gap-2">
                          <Truck className="w-4 h-4 text-slate-600" />
                          <span className="text-sm font-bold text-slate-900">
                            {offer.collector_name}
                          </span>
                          <span className="px-2 py-0.5 rounded-full bg-blue-100 text-blue-800 text-[11px] font-mono font-bold">
                            {offer.match_score}% Match
                          </span>
                        </div>
                        <div className="text-xs text-slate-600 flex items-center gap-2">
                          <Clock className="w-3.5 h-3.5 text-slate-400" />
                          Proposed Pickup: <strong className="text-slate-800">{offer.proposed_pickup_at}</strong>
                        </div>
                      </div>

                      {/* Right: Rate & Action */}
                      <div className="flex items-center gap-4">
                        <div className="text-right">
                          <div className="text-[10px] uppercase font-bold text-slate-600">Offered Rate</div>
                          <div className="text-xl font-mono font-extrabold text-emerald-800">
                            ₹{offer.rate_per_kg.toFixed(2)}
                            <span className="text-xs font-sans font-normal text-slate-500"> /kg</span>
                          </div>
                          <div className="text-[11px] text-slate-500 font-mono">
                            Est. Payout: ₹{(offer.rate_per_kg * batch.quantities.estimated_kg).toFixed(0)}
                          </div>
                        </div>

                        {batch.status === 'LISTED' ? (
                          <button
                            onClick={() => handleAccept(batch.id, offer.id)}
                            className="px-4 py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-xs transition-all cursor-pointer"
                          >
                            Accept Offer
                          </button>
                        ) : isAccepted ? (
                          <span className="px-3 py-1.5 rounded-xl bg-emerald-600 text-white text-xs font-bold inline-flex items-center gap-1">
                            <CheckCircle className="w-3.5 h-3.5" /> Accepted
                          </span>
                        ) : (
                          <span className="text-xs text-slate-400 font-medium">Declined</span>
                        )}
                      </div>
                    </div>

                    {/* "Why?" Disclosure (Docs/09 requirement) */}
                    <div className="mt-3 pt-2.5 border-t border-slate-200/80">
                      <button
                        type="button"
                        onClick={() => setOpenWhyId(isWhyOpen ? null : offer.id)}
                        className="text-[11px] font-semibold text-emerald-700 hover:text-emerald-800 inline-flex items-center gap-1 cursor-pointer"
                      >
                        <HelpCircle className="w-3.5 h-3.5" />
                        <span>Why this match score? ({offer.match_score}/100)</span>
                        {isWhyOpen ? <ChevronUp className="w-3 h-3" /> : <ChevronDown className="w-3 h-3" />}
                      </button>

                      {isWhyOpen && (
                        <div className="mt-2.5 p-3 rounded-lg bg-white border border-slate-200 text-xs space-y-2 animate-in fade-in">
                          <div className="grid grid-cols-3 gap-2 text-center border-b border-slate-100 pb-2">
                            <div>
                              <div className="text-[10px] text-slate-400 uppercase font-bold">Proximity</div>
                              <div className="font-mono font-bold text-slate-800">
                                {offer.score_breakdown.distance_score}/100
                              </div>
                            </div>
                            <div>
                              <div className="text-[10px] text-slate-400 uppercase font-bold">Reliability (n=48)</div>
                              <div className="font-mono font-bold text-slate-800">
                                {offer.score_breakdown.reliability_score}/100
                              </div>
                            </div>
                            <div>
                              <div className="text-[10px] text-slate-400 uppercase font-bold">Capacity Fit</div>
                              <div className="font-mono font-bold text-slate-800">
                                {offer.score_breakdown.capacity_score}/100
                              </div>
                            </div>
                          </div>
                          <div>
                            <span className="text-[11px] font-bold text-slate-600 block mb-1">
                              Match Factors & Algorithmic Notes:
                            </span>
                            <ul className="list-disc list-inside space-y-0.5 text-slate-600 text-[11px]">
                              {offer.score_breakdown.reasons.map((r, i) => (
                                <li key={i}>{r}</li>
                              ))}
                            </ul>
                          </div>
                        </div>
                      )}
                    </div>
                  </div>
                )
              })}
            </div>
          </div>
        ))
      )}
    </div>
  )
}
