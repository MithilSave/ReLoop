import React, { useState } from 'react'
import { useApp } from '../../context/AppContext'
import type { PolymerType } from '../../types'
import {
  Truck,
  CheckCircle2,
  ShieldAlert,
  Sparkles,
} from 'lucide-react'

export const RecyclerSourcingPlanner: React.FC = () => {
  const { aggregationPlans, acceptAggregationPlan } = useApp()
  const selectedPlanId = aggregationPlans[0]?.id || ''
  const [demandMaterial, setDemandMaterial] = useState<PolymerType>('PP')
  const [targetKg, setTargetKg] = useState<number>(500)
  const [needBy, setNeedBy] = useState<string>('2026-11-30')
  const [planAcceptedMsg, setPlanAcceptedMsg] = useState<string | null>(null)

  const activePlan = aggregationPlans.find((p) => p.id === selectedPlanId) || aggregationPlans[0]

  const handleAcceptPlan = (id: string) => {
    acceptAggregationPlan(id)
    setPlanAcceptedMsg(`Aggregation Plan ${activePlan.plan_code} accepted! Collection dispatch requests issued to ${activePlan.suggested_collector_name}.`)
    setTimeout(() => setPlanAcceptedMsg(null), 5000)
  }

  return (
    <div className="space-y-6">
      {/* Header */}
      <div>
        <h1 className="text-xl md:text-2xl font-bold text-slate-900">
          Smart Feedstock Sourcing & Aggregation Planner
        </h1>
        <p className="text-xs text-slate-500">
          Greedy spatial clustering engine proposing optimal collection multi-stop corridors to meet plant demand
        </p>
      </div>

      {planAcceptedMsg && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-2xl p-4 flex items-center gap-2 text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          <span className="font-semibold">{planAcceptedMsg}</span>
        </div>
      )}

      {/* Demand Declaration Card */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
        <div className="flex items-center justify-between border-b border-slate-100 pb-3">
          <div className="flex items-center gap-2">
            <Sparkles className="w-4 h-4 text-purple-600" />
            <h2 className="text-xs font-bold uppercase tracking-wider text-slate-800">
              Plant Raw Material Demand Profile
            </h2>
          </div>
          <span className="text-xs font-mono text-purple-700 font-bold bg-purple-50 px-2.5 py-0.5 rounded-lg border border-purple-200">
            Engine: Greedy K-Means + Spatial Routing
          </span>
        </div>

        <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 text-xs">
          <div className="space-y-1">
            <label className="font-bold text-slate-700">Target Polymer</label>
            <select
              value={demandMaterial}
              onChange={(e) => setDemandMaterial(e.target.value as PolymerType)}
              className="w-full px-3 py-2 rounded-xl border border-slate-300 font-bold text-xs"
            >
              <option value="PP">Polypropylene (PP) — Pellets Line</option>
              <option value="PET">PET (Bottles & Flakes Line)</option>
              <option value="HDPE">HDPE (Blow Molding Line)</option>
            </select>
          </div>

          <div className="space-y-1">
            <label className="font-bold text-slate-700">Target Feedstock Weight (kg)</label>
            <input
              type="number"
              value={targetKg}
              onChange={(e) => setTargetKg(Number(e.target.value))}
              className="w-full px-3 py-2 rounded-xl border border-slate-300 font-mono font-bold text-xs"
            />
          </div>

          <div className="space-y-1">
            <label className="font-bold text-slate-700">Need-by Delivery Date</label>
            <input
              type="date"
              value={needBy}
              onChange={(e) => setNeedBy(e.target.value)}
              className="w-full px-3 py-2 rounded-xl border border-slate-300 font-mono font-bold text-xs"
            />
          </div>
        </div>
      </div>

      {/* Proposed Aggregation Plan Card */}
      {activePlan && (
        <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 md:p-8 space-y-6">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 border-b border-slate-100 pb-4">
            <div>
              <div className="flex items-center gap-2.5">
                <span className="font-mono font-bold text-lg text-slate-900">
                  {activePlan.plan_code}
                </span>
                <span
                  className={`text-xs font-bold px-2.5 py-0.5 rounded-full ${
                    activePlan.status === 'ACCEPTED'
                      ? 'bg-emerald-100 text-emerald-800'
                      : 'bg-purple-100 text-purple-800'
                  }`}
                >
                  {activePlan.status}
                </span>
                <span className="text-xs font-semibold px-2 py-0.5 rounded bg-slate-100 text-slate-700">
                  {activePlan.material_code}
                </span>
              </div>
              <p className="text-xs text-slate-500 mt-1 flex items-center gap-1.5">
                <Truck className="w-3.5 h-3.5 text-blue-600" />
                Assigned Aggregator Fleet: <strong>{activePlan.suggested_collector_name}</strong>
              </p>
            </div>

            <div className="flex items-center gap-3">
              {activePlan.status === 'PROPOSED' ? (
                <button
                  onClick={() => handleAcceptPlan(activePlan.id)}
                  className="px-5 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-700 text-white text-xs font-bold shadow-md transition-all cursor-pointer"
                >
                  Accept Aggregation Plan
                </button>
              ) : (
                <span className="px-4 py-2 rounded-xl bg-emerald-50 text-emerald-800 text-xs font-bold border border-emerald-300 inline-flex items-center gap-1.5">
                  <CheckCircle2 className="w-4 h-4 text-emerald-600" /> Plan Accepted & Dispatched
                </span>
              )}
            </div>
          </div>

          {/* Aggregation Metrics Strip */}
          <div className="grid grid-cols-2 sm:grid-cols-4 gap-4 bg-slate-50 p-4 rounded-xl border border-slate-200 font-mono text-xs">
            <div>
              <div className="text-[10px] text-slate-400 uppercase font-sans">Total Estimated</div>
              <div className="text-lg font-bold text-slate-900 mt-0.5">{activePlan.total_estimated_kg} kg</div>
            </div>
            <div>
              <div className="text-[10px] text-emerald-600 uppercase font-sans">Expected Usable</div>
              <div className="text-lg font-bold text-emerald-700 mt-0.5">{activePlan.expected_usable_kg} kg</div>
            </div>
            <div>
              <div className="text-[10px] text-slate-500 uppercase font-sans">Corridor Collection Fee</div>
              <div className="text-lg font-bold text-slate-800 mt-0.5">₹{activePlan.collection_cost}</div>
            </div>
            <div>
              <div className="text-[10px] text-purple-700 uppercase font-sans">Landed Cost / Usable kg</div>
              <div className="text-lg font-bold text-purple-700 mt-0.5">₹{activePlan.landed_cost_per_usable_kg}</div>
            </div>
          </div>

          {/* Route Sequence & Stops */}
          <div className="space-y-3">
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center justify-between">
              <span>Proposed Route Stops ({activePlan.items.length} Stops)</span>
              <span className="text-[11px] font-mono text-slate-500 font-normal">
                Multi-Stop Sequential Optimization
              </span>
            </h3>

            <div className="space-y-2.5">
              {activePlan.items.map((item) => (
                <div
                  key={item.batch_id}
                  className="p-3.5 rounded-xl border border-slate-200 bg-slate-50/50 flex flex-col sm:flex-row sm:items-center justify-between gap-3 text-xs"
                >
                  <div className="flex items-start gap-3">
                    <span className="w-6 h-6 rounded-full bg-purple-100 text-purple-800 font-bold font-mono text-xs flex items-center justify-center shrink-0">
                      {item.sequence_no}
                    </span>
                    <div className="space-y-0.5">
                      <div className="flex items-center gap-2">
                        <span className="font-mono font-bold text-slate-900">{item.batch_code}</span>
                        <span className="text-[11px] font-bold text-slate-600 bg-white px-2 py-0.2 rounded border border-slate-200">
                          {item.locality}
                        </span>
                      </div>
                      <div className="text-slate-500">{item.address}</div>
                      <div className="flex flex-wrap gap-1.5 pt-1">
                        {item.reasons.map((r, i) => (
                          <span
                            key={i}
                            className="text-[10px] bg-purple-50 text-purple-700 px-2 py-0.5 rounded border border-purple-200 font-medium"
                          >
                            ✓ {r}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>

                  <div className="text-right shrink-0">
                    <div className="text-sm font-mono font-bold text-slate-900">{item.kg} kg</div>
                  </div>
                </div>
              ))}
            </div>
          </div>

          {/* Excluded Batches with Explicit Algorithmic Reasons (Docs/09 requirement) */}
          <div className="space-y-3 pt-3 border-t border-slate-100">
            <h3 className="text-xs font-bold uppercase tracking-wider text-rose-800 flex items-center gap-1.5">
              <ShieldAlert className="w-4 h-4 text-rose-600" />
              <span>Excluded Batches & Algorithmic Elimination Explanations</span>
            </h3>

            <div className="space-y-2">
              {activePlan.excluded.map((ex) => (
                <div
                  key={ex.batch_id}
                  className="p-3 rounded-xl border border-rose-200 bg-rose-50/40 flex items-start justify-between text-xs gap-3"
                >
                  <div>
                    <div className="flex items-center gap-2 font-mono font-bold text-slate-800">
                      <span>{ex.batch_code}</span>
                      <span className="text-slate-500 font-normal">({ex.locality}, {ex.kg} kg)</span>
                    </div>
                    <div className="text-[11px] text-rose-800 mt-1 font-medium">
                      Exclusion Reason: {ex.reason}
                    </div>
                  </div>
                  <span className="px-2 py-0.5 rounded bg-rose-100 text-rose-800 font-bold text-[10px] shrink-0">
                    EXCLUDED
                  </span>
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </div>
  )
}
