import React from 'react'
import type { BatchQuantities } from '../../types'
import { Check, Clock, AlertCircle } from 'lucide-react'

interface SixStageBarProps {
  quantities: BatchQuantities
  compact?: boolean
  showLabels?: boolean
}

interface StageConfig {
  key: keyof BatchQuantities
  label: string
  shortLabel: string
  color: string
  activeBg: string
  border: string
}

const STAGES: StageConfig[] = [
  {
    key: 'collected_kg',
    label: '1. Collected',
    shortLabel: 'Coll',
    color: 'text-blue-700',
    activeBg: 'bg-blue-500',
    border: 'border-blue-300',
  },
  {
    key: 'received_kg',
    label: '2. Received',
    shortLabel: 'Recv',
    color: 'text-indigo-700',
    activeBg: 'bg-indigo-500',
    border: 'border-indigo-300',
  },
  {
    key: 'accepted_kg',
    label: '3. Accepted',
    shortLabel: 'Acpt',
    color: 'text-emerald-700',
    activeBg: 'bg-emerald-500',
    border: 'border-emerald-300',
  },
  {
    key: 'processed_kg',
    label: '4. Processed',
    shortLabel: 'Proc',
    color: 'text-teal-700',
    activeBg: 'bg-teal-500',
    border: 'border-teal-300',
  },
  {
    key: 'verified_kg',
    label: '5. Verified',
    shortLabel: 'Verf',
    color: 'text-emerald-800',
    activeBg: 'bg-emerald-600',
    border: 'border-emerald-400',
  },
  {
    key: 'allocated_kg',
    label: '6. Allocated',
    shortLabel: 'Aloc',
    color: 'text-purple-700',
    activeBg: 'bg-purple-600',
    border: 'border-purple-300',
  },
]

export const SixStageBar: React.FC<SixStageBarProps> = ({
  quantities,
  compact = false,
  showLabels = true,
}) => {
  const estKg = quantities.estimated_kg || 100

  return (
    <div className="w-full">
      {/* Visual Bar segments */}
      <div className="grid grid-cols-6 gap-1.5 md:gap-2">
        {STAGES.map((stg) => {
          const val = quantities[stg.key]
          const isComplete = val !== undefined && val > 0
          const displayKg = val !== undefined ? `${val.toFixed(1)} kg` : '—'
          
          // Calculate percentage relative to estimate or initial collected
          const widthPct = val !== undefined ? Math.min(100, Math.round((val / estKg) * 100)) : 0

          if (compact) {
            return (
              <div
                key={stg.key}
                title={`${stg.label}: ${displayKg}`}
                className={`relative flex flex-col items-center justify-center py-1 px-1 rounded border text-xs ${
                  isComplete
                    ? 'bg-slate-50 border-slate-300 shadow-xs'
                    : 'bg-gray-50 border-dashed border-gray-200 text-gray-400'
                }`}
              >
                <span className="font-semibold text-[10px] text-gray-500">{stg.shortLabel}</span>
                <span className={`font-mono text-[11px] font-bold ${isComplete ? stg.color : 'text-gray-400'}`}>
                  {isComplete ? `${val.toFixed(0)}k` : '—'}
                </span>
                {isComplete && (
                  <div
                    className={`h-1 w-full mt-0.5 rounded-full ${stg.activeBg}`}
                    style={{ opacity: Math.max(0.4, widthPct / 100) }}
                  />
                )}
              </div>
            )
          }

          return (
            <div
              key={stg.key}
              className={`flex flex-col p-2.5 rounded-lg border transition-all ${
                isComplete
                  ? 'bg-white border-slate-200 shadow-xs hover:border-slate-300'
                  : 'bg-slate-50/70 border-dashed border-slate-200 text-slate-400'
              }`}
            >
              <div className="flex items-center justify-between text-xs mb-1">
                <span className="font-medium text-slate-600 truncate">{stg.label}</span>
                {isComplete ? (
                  <Check className="w-3.5 h-3.5 text-emerald-600 shrink-0" />
                ) : (
                  <Clock className="w-3.5 h-3.5 text-slate-300 shrink-0" />
                )}
              </div>
              <div className="flex items-baseline justify-between mt-0.5">
                <span
                  className={`text-sm md:text-base font-bold font-mono tracking-tight ${
                    isComplete ? 'text-slate-900' : 'text-slate-400 font-normal'
                  }`}
                >
                  {displayKg}
                </span>
                {isComplete && estKg > 0 && (
                  <span className="text-[10px] font-mono text-slate-400">
                    {Math.round((val / estKg) * 100)}%
                  </span>
                )}
              </div>
              {/* Progress sliver */}
              <div className="w-full bg-slate-100 h-1.5 rounded-full overflow-hidden mt-1.5">
                <div
                  className={`h-full rounded-full transition-all duration-300 ${isComplete ? stg.activeBg : 'bg-transparent'}`}
                  style={{ width: `${widthPct}%` }}
                />
              </div>
            </div>
          )
        })}
      </div>

      {showLabels && !compact && quantities.rejected_kg !== undefined && quantities.rejected_kg > 0 && (
        <div className="mt-1.5 flex items-center gap-1.5 text-xs text-amber-700 bg-amber-50 px-2.5 py-1 rounded border border-amber-200">
          <AlertCircle className="w-3.5 h-3.5 shrink-0" />
          <span>
            Weighbridge rejection: <strong className="font-mono">{quantities.rejected_kg.toFixed(1)} kg</strong> (contaminated/non-conforming fraction separated at receipt).
          </span>
        </div>
      )}
    </div>
  )
}
