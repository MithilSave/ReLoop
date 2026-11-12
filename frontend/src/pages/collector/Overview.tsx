import React from 'react'
import { Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import {
  Truck,
  Compass,
  Package,
  DollarSign,
  ArrowRight,
  MapPin,
  ShieldCheck,
} from 'lucide-react'

export const CollectorOverview: React.FC = () => {
  const { batches, currentPersona } = useApp()

  // Assigned and picked up batches for this collector
  const assignedJobs = batches.filter(
    (b) => b.collector_org_id === currentPersona.org_id && b.status === 'ASSIGNED'
  )
  const pickedUpBatches = batches.filter(
    (b) => b.collector_org_id === currentPersona.org_id && b.status === 'PICKED_UP'
  )

  const availableListingsCount = batches.filter((b) => b.status === 'LISTED').length

  const totalCollectedKg = batches
    .filter((b) => b.collector_org_id === currentPersona.org_id && b.quantities.collected_kg)
    .reduce((acc, b) => acc + (b.quantities.collected_kg || 0), 0)

  const estimatedEarnings = totalCollectedKg * 3.5 // Collector margin ₹3.50/kg

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="bg-linear-to-r from-blue-900 to-indigo-950 rounded-2xl text-white p-6 md:p-8 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-blue-500/20 text-blue-300 text-xs font-semibold border border-blue-500/30">
            <span>🚚</span> Fleet Aggregator & Logistics Portal
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold tracking-tight">
            {currentPersona.org_name}
          </h1>
          <p className="text-sm text-blue-200 max-w-xl">
            Optimized route pickups, doorstep digital scale verification with OTP handover, and recycler consignments.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <Link
            to="/collector/available"
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-blue-600 hover:bg-blue-500 text-white font-bold text-xs shadow-md transition-all"
          >
            <Compass className="w-4 h-4" />
            Browse Listings ({availableListingsCount})
          </Link>
          <Link
            to="/collector/consignments"
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white text-blue-950 hover:bg-blue-50 font-bold text-xs shadow-md transition-all"
          >
            <Package className="w-4 h-4 text-blue-600" />
            Dispatch Consignment
          </Link>
        </div>
      </div>

      {/* KPI Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Today's Pickups</span>
            <Truck className="w-4 h-4 text-blue-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {assignedJobs.length} <span className="text-sm font-sans font-normal text-slate-500">pending</span>
          </div>
          <div className="text-[11px] text-blue-700 font-medium mt-1">Requires generator OTP verification</div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Collected Today</span>
            <Package className="w-4 h-4 text-emerald-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {totalCollectedKg.toFixed(1)} <span className="text-sm font-sans font-normal text-slate-500">kg</span>
          </div>
          <div className="text-[11px] text-emerald-700 font-medium mt-1 flex items-center gap-1">
            <ShieldCheck className="w-3.5 h-3.5" /> 100% Weighed on Digital Scale
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Ready for Dispatch</span>
            <Package className="w-4 h-4 text-purple-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {pickedUpBatches.length} <span className="text-sm font-sans font-normal text-slate-500">batches</span>
          </div>
          <div className="text-[11px] text-purple-700 font-medium mt-1">Stored at Hub / LCV ready</div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Aggregator Margin</span>
            <DollarSign className="w-4 h-4 text-teal-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            ₹{estimatedEarnings.toLocaleString('en-IN', { maximumFractionDigits: 0 })}
          </div>
          <div className="text-[11px] text-slate-500 mt-1">Landed recycler settlement</div>
        </div>
      </div>

      {/* Active Pickups Requiring Doorstep OTP */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between">
          <div>
            <h2 className="text-base font-bold text-slate-900">Active Stop Sequence</h2>
            <p className="text-xs text-slate-500">
              Assigned pickups requiring doorstep weighing and OTP verification
            </p>
          </div>
          <Link
            to="/collector/pickups"
            className="text-xs font-semibold text-blue-600 hover:text-blue-700 inline-flex items-center gap-1"
          >
            Open Pickup View <ArrowRight className="w-3.5 h-3.5" />
          </Link>
        </div>

        <div className="divide-y divide-slate-100">
          {assignedJobs.length === 0 ? (
            <div className="p-8 text-center text-slate-500 text-xs">
              No pending pickups right now. Browse available listings to make offers.
            </div>
          ) : (
            assignedJobs.map((batch, index) => (
              <div key={batch.id} className="p-5 flex flex-col sm:flex-row sm:items-center justify-between gap-4">
                <div className="flex items-start gap-3">
                  <div className="w-8 h-8 rounded-full bg-blue-100 text-blue-700 font-bold font-mono text-xs flex items-center justify-center shrink-0">
                    {index + 1}
                  </div>
                  <div className="space-y-1">
                    <div className="flex items-center gap-2">
                      <span className="font-mono font-bold text-sm text-slate-900">
                        {batch.batch_code}
                      </span>
                      <span className="text-xs font-semibold px-2 py-0.5 rounded bg-blue-50 text-blue-700 border border-blue-200">
                        {batch.material} ({batch.quantities.estimated_kg} kg)
                      </span>
                    </div>
                    <div className="text-xs text-slate-600 flex items-center gap-1">
                      <MapPin className="w-3.5 h-3.5 text-slate-400" />
                      {batch.pickup_address}
                    </div>
                    <div className="text-[11px] text-slate-500">
                      Generator: <strong>{batch.generator_name}</strong>
                    </div>
                  </div>
                </div>

                <Link
                  to="/collector/pickups"
                  className="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-xs font-bold shadow-xs transition-colors shrink-0 text-center"
                >
                  Weigh & Verify OTP
                </Link>
              </div>
            ))
          )}
        </div>
      </div>
    </div>
  )
}
