import React, { useState } from 'react'
import { Link, useSearchParams } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import { SixStageBar } from '../../components/common/SixStageBar'
import { StatusBadge } from '../../components/common/StatusBadge'
import { MaterialPassportView } from '../../components/common/MaterialPassportView'
import type { WasteBatch } from '../../types'
import {
  Package,
  MapPin,
  Calendar,
  PlusCircle,
  Truck,
  CheckCircle2,
  DollarSign,
  Eye,
  KeyRound,
} from 'lucide-react'

export const GeneratorMyBatches: React.FC = () => {
  const { batches, currentPersona } = useApp()
  const [searchParams] = useSearchParams()
  const createdCode = searchParams.get('created')

  const [filter, setFilter] = useState<'ALL' | 'ACTIVE' | 'ASSIGNED' | 'PROCESSED'>('ALL')
  const [selectedBatchForPassport, setSelectedBatchForPassport] = useState<WasteBatch | null>(null)

  // Filter batches for this generator
  const myBatches = batches.filter(
    (b) => b.generator_org_id === currentPersona.org_id || b.generator_name.includes('Green Society')
  )

  const filteredBatches = myBatches.filter((b) => {
    if (filter === 'ACTIVE') return !['PROCESSED', 'CANCELLED'].includes(b.status)
    if (filter === 'ASSIGNED') return b.status === 'ASSIGNED'
    if (filter === 'PROCESSED') return b.status === 'PROCESSED'
    return true
  })

  return (
    <div className="space-y-6">
      {/* Newly created batch banner alert */}
      {createdCode && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-2xl p-4 flex items-center justify-between text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <div className="flex items-center gap-2">
            <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
            <div>
              <span className="font-bold text-sm">Batch Successfully Listed!</span>
              <p className="text-emerald-700">
                Batch code <strong className="font-mono">{createdCode}</strong> is now broadcast to verified Mumbai collectors.
              </p>
            </div>
          </div>
          <Link
            to="/generator/offers"
            className="px-3 py-1.5 rounded-lg bg-emerald-600 text-white font-semibold hover:bg-emerald-700 transition-colors"
          >
            Check Offers
          </Link>
        </div>
      )}

      {/* Header & Filter Controls */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900">My Plastic Batches</h1>
          <p className="text-xs text-slate-500">
            Real-time custody ledger tracking kg across all 6 circular stages
          </p>
        </div>

        <div className="flex items-center gap-2">
          <div className="flex items-center bg-white border border-slate-200 rounded-xl p-1 text-xs">
            {(['ALL', 'ACTIVE', 'ASSIGNED', 'PROCESSED'] as const).map((tab) => (
              <button
                key={tab}
                onClick={() => setFilter(tab)}
                className={`px-3 py-1.5 rounded-lg font-medium transition-colors ${
                  filter === tab
                    ? 'bg-slate-900 text-white shadow-xs'
                    : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                {tab.charAt(0) + tab.slice(1).toLowerCase()}
              </button>
            ))}
          </div>

          <Link
            to="/generator/create"
            className="inline-flex items-center gap-1.5 px-3.5 py-2 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold transition-all shadow-xs shrink-0"
          >
            <PlusCircle className="w-4 h-4" />
            <span>List Plastic</span>
          </Link>
        </div>
      </div>

      {/* Batch Cards Grid */}
      <div className="space-y-4">
        {filteredBatches.length === 0 ? (
          <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center text-slate-500">
            <Package className="w-12 h-12 text-slate-300 mx-auto mb-3" />
            <div className="text-sm font-semibold text-slate-700">No batches in this view</div>
            <p className="text-xs text-slate-400 mt-1">Try switching filters or list a new batch.</p>
          </div>
        ) : (
          filteredBatches.map((batch) => {
            const hasPendingOffers = batch.offers && batch.offers.length > 0 && batch.status === 'LISTED'
            const isAssigned = batch.status === 'ASSIGNED'

            return (
              <div
                key={batch.id}
                className="bg-white rounded-2xl border border-slate-200 shadow-xs hover:border-slate-300 transition-all p-5 space-y-4"
              >
                {/* Top Row: Code, Material, Locality, Status */}
                <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2 border-b border-slate-100 pb-3">
                  <div className="flex flex-wrap items-center gap-2.5">
                    <span className="font-mono font-bold text-base text-slate-900">
                      {batch.batch_code}
                    </span>
                    <StatusBadge status={batch.status} />
                    <span className="text-xs font-semibold px-2 py-0.5 rounded bg-slate-100 text-slate-700 border border-slate-200">
                      {batch.material} ({batch.packaging_category})
                    </span>
                  </div>

                  <div className="flex items-center gap-2 text-xs">
                    {/* Handover OTP badge if Assigned */}
                    {isAssigned && batch.pickup_otp && (
                      <div className="flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-amber-50 text-amber-900 border border-amber-300 font-mono font-bold">
                        <KeyRound className="w-3.5 h-3.5 text-amber-600" />
                        <span>Pickup OTP: {batch.pickup_otp}</span>
                      </div>
                    )}

                    {/* Pending Offers Link */}
                    {hasPendingOffers && (
                      <Link
                        to="/generator/offers"
                        className="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg bg-blue-50 text-blue-700 border border-blue-200 font-bold hover:bg-blue-100 transition-colors"
                      >
                        <DollarSign className="w-3.5 h-3.5" />
                        {batch.offers?.length} Offers Available
                      </Link>
                    )}

                    <button
                      onClick={() => setSelectedBatchForPassport(batch)}
                      className="inline-flex items-center gap-1 px-3 py-1.5 rounded-lg bg-slate-100 hover:bg-slate-200 text-slate-700 font-semibold transition-colors"
                    >
                      <Eye className="w-3.5 h-3.5" />
                      Passport
                    </button>
                  </div>
                </div>

                {/* Location and Metadata */}
                <div className="flex flex-wrap items-center gap-4 text-xs text-slate-500">
                  <span className="flex items-center gap-1 text-slate-700">
                    <MapPin className="w-3.5 h-3.5 text-slate-400" />
                    {batch.pickup_address}
                  </span>
                  <span className="flex items-center gap-1 font-mono text-slate-600">
                    <Calendar className="w-3.5 h-3.5 text-slate-400" />
                    Available: {batch.available_from} to {batch.available_to}
                  </span>
                  {batch.collector_name && (
                    <span className="flex items-center gap-1 text-slate-700">
                      <Truck className="w-3.5 h-3.5 text-slate-400" />
                      Collector: <strong>{batch.collector_name}</strong>
                    </span>
                  )}
                </div>

                {/* Signature Six-Stage Quantity Bar */}
                <div className="bg-slate-50 p-3.5 rounded-xl border border-slate-100">
                  <div className="flex items-center justify-between text-[11px] font-bold uppercase tracking-wider text-slate-600 mb-1.5">
                    <span>6-Stage Traceability Progress</span>
                    <span className="font-mono text-slate-500">
                      Estimate: {batch.quantities.estimated_kg.toFixed(1)} kg
                    </span>
                  </div>
                  <SixStageBar quantities={batch.quantities} compact={false} />
                </div>
              </div>
            )
          })
        )}
      </div>

      {/* Material Passport Modal when clicked */}
      {selectedBatchForPassport && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4 overflow-y-auto">
          <div className="max-w-4xl w-full my-8">
            <MaterialPassportView
              batch={selectedBatchForPassport}
              onClose={() => setSelectedBatchForPassport(null)}
            />
          </div>
        </div>
      )}
    </div>
  )
}
