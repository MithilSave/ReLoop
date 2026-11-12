import React from 'react'
import { Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import { SixStageBar } from '../../components/common/SixStageBar'
import { StatusBadge } from '../../components/common/StatusBadge'
import {
  Package,
  TrendingUp,
  DollarSign,
  PlusCircle,
  Truck,
  ArrowRight,
  ShieldCheck,
  MapPin,
} from 'lucide-react'

export const GeneratorOverview: React.FC = () => {
  const { batches, currentPersona } = useApp()

  // Filter batches created by this generator
  const myBatches = batches.filter(
    (b) => b.generator_org_id === currentPersona.org_id || b.generator_name.includes('Green Society')
  )

  const activeBatches = myBatches.filter((b) => !['PROCESSED', 'CANCELLED'].includes(b.status))
  const completedBatches = myBatches.filter((b) => b.status === 'PROCESSED')

  // Calculate total kg recycled and estimated earnings (at avg ₹15/kg)
  const totalKgRecycled = myBatches.reduce((acc, b) => acc + (b.quantities.collected_kg || 0), 0)
  const totalEarnings = totalKgRecycled * 15.5

  const assignedBatchWithOtp = myBatches.find((b) => b.status === 'ASSIGNED' && b.pickup_otp)

  return (
    <div className="space-y-6">
      {/* Welcome Banner */}
      <div className="bg-linear-to-r from-emerald-800 to-teal-900 rounded-2xl text-white p-6 md:p-8 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-emerald-500/20 text-emerald-300 text-xs font-semibold border border-emerald-500/30">
            <span>🌱</span> Household & Society Generator Portal
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold tracking-tight">
            {currentPersona.org_name}
          </h1>
          <p className="text-sm text-emerald-100 max-w-xl">
            Track your segregated post-consumer plastic waste from doorstep collection to CPCB-verified recycling.
          </p>
        </div>

        <Link
          to="/generator/create"
          className="inline-flex items-center gap-2 px-5 py-3 rounded-xl bg-white text-emerald-900 hover:bg-emerald-50 font-bold text-sm shadow-md transition-all shrink-0 hover:scale-[1.02]"
        >
          <PlusCircle className="w-5 h-5 text-emerald-600" />
          List New Plastic
          <span className="text-[10px] uppercase font-mono px-1.5 py-0.5 rounded bg-emerald-100 text-emerald-800">
            AI Assist
          </span>
        </Link>
      </div>

      {/* Handover OTP Alert Banner (if any batch is ASSIGNED) */}
      {assignedBatchWithOtp && (
        <div className="bg-amber-50 border-2 border-amber-300 rounded-2xl p-5 shadow-xs flex flex-col sm:flex-row sm:items-center justify-between gap-4">
          <div className="flex items-start gap-3">
            <div className="w-10 h-10 rounded-xl bg-amber-200 text-amber-900 flex items-center justify-center shrink-0">
              <Truck className="w-6 h-6" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <span className="font-bold text-amber-900 text-sm">
                  Collector En Route for Pickup!
                </span>
                <span className="font-mono text-xs text-amber-700 bg-amber-100 px-2 py-0.5 rounded">
                  {assignedBatchWithOtp.batch_code}
                </span>
              </div>
              <p className="text-xs text-amber-800 mt-0.5">
                Collector <strong>{assignedBatchWithOtp.collector_name}</strong> is arriving. Share this OTP after they weigh your batch:
              </p>
            </div>
          </div>
          <div className="bg-white px-5 py-3 rounded-xl border border-amber-300 shadow-xs flex items-center gap-3 shrink-0">
            <div className="text-right">
              <div className="text-[10px] uppercase font-bold text-slate-500">Handover OTP</div>
              <div className="text-2xl font-mono font-extrabold text-amber-600 tracking-widest">
                {assignedBatchWithOtp.pickup_otp}
              </div>
            </div>
          </div>
        </div>
      )}

      {/* KPI Cards */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Total Recycled</span>
            <Package className="w-4 h-4 text-emerald-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {totalKgRecycled.toFixed(1)} <span className="text-sm font-sans font-normal text-slate-500">kg</span>
          </div>
          <div className="text-[11px] text-emerald-700 font-medium mt-1 flex items-center gap-1">
            <ShieldCheck className="w-3.5 h-3.5" /> 100% CPCB Circular Credit
          </div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>₹ Earned (Est.)</span>
            <DollarSign className="w-4 h-4 text-blue-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            ₹{totalEarnings.toLocaleString('en-IN', { maximumFractionDigits: 0 })}
          </div>
          <div className="text-[11px] text-slate-500 mt-1">Direct collector bank transfer</div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Active Listings</span>
            <TrendingUp className="w-4 h-4 text-purple-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {activeBatches.length} <span className="text-sm font-sans font-normal text-slate-500">batches</span>
          </div>
          <div className="text-[11px] text-purple-700 font-medium mt-1">Pending pickup / offers</div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Verified Batches</span>
            <ShieldCheck className="w-4 h-4 text-emerald-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {completedBatches.length} <span className="text-sm font-sans font-normal text-slate-500">closed-loop</span>
          </div>
          <div className="text-[11px] text-slate-500 mt-1">With Digital Product Passport</div>
        </div>
      </div>

      {/* Recent Batches with Six-Stage Quantity Bar */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="p-5 border-b border-slate-100 flex items-center justify-between">
          <div>
            <h2 className="text-base font-bold text-slate-900">My Waste Batches</h2>
            <p className="text-xs text-slate-500">Live custody tracking with the 6-stage quantity bar</p>
          </div>
          <Link
            to="/generator/batches"
            className="text-xs font-semibold text-emerald-600 hover:text-emerald-700 inline-flex items-center gap-1"
          >
            View all batches <ArrowRight className="w-3.5 h-3.5" />
          </Link>
        </div>

        <div className="divide-y divide-slate-100">
          {myBatches.slice(0, 3).map((batch) => (
            <div key={batch.id} className="p-5 space-y-3 hover:bg-slate-50/50 transition-colors">
              <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
                <div className="flex items-center gap-2.5">
                  <span className="font-mono font-bold text-sm text-slate-900">
                    {batch.batch_code}
                  </span>
                  <StatusBadge status={batch.status} />
                  <span className="text-xs font-semibold px-2 py-0.5 rounded bg-slate-100 text-slate-700 border border-slate-200">
                    {batch.material} ({batch.packaging_category})
                  </span>
                </div>
                <div className="text-xs text-slate-500 flex items-center gap-3">
                  <span className="flex items-center gap-1">
                    <MapPin className="w-3.5 h-3.5 text-slate-400" /> {batch.locality}
                  </span>
                  <Link
                    to={`/b/${batch.batch_code}`}
                    className="text-emerald-600 hover:text-emerald-700 font-semibold inline-flex items-center gap-1"
                  >
                    View Passport <ArrowRight className="w-3 h-3" />
                  </Link>
                </div>
              </div>

              {/* The Signature Six-Stage Quantity Bar */}
              <div className="pt-1">
                <SixStageBar quantities={batch.quantities} compact={false} />
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  )
}
