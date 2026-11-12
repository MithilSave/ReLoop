import React from 'react'
import { useParams, Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import { MaterialPassportView } from '../../components/common/MaterialPassportView'
import { Recycle, ArrowLeft } from 'lucide-react'

export const PublicPassportPage: React.FC = () => {
  const { batchCode } = useParams<{ batchCode: string }>()
  const { batches } = useApp()

  const targetCode = batchCode || 'RL-MUM-2026-000123'
  const batch = batches.find((b) => b.batch_code === targetCode) || batches[0]

  return (
    <div className="max-w-4xl mx-auto space-y-6">
      {/* Public Header */}
      <div className="flex items-center justify-between">
        <Link
          to="/"
          className="inline-flex items-center gap-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
        >
          <ArrowLeft className="w-4 h-4" /> Return to Platform
        </Link>
        <div className="text-xs text-slate-500 font-mono">
          Public QR Verification Gateway
        </div>
      </div>

      {batch ? (
        <MaterialPassportView batch={batch} />
      ) : (
        <div className="bg-white rounded-2xl border border-slate-200 p-12 text-center text-slate-500">
          <Recycle className="w-12 h-12 text-slate-300 mx-auto mb-3" />
          <div className="text-base font-bold text-slate-800">Batch Not Found</div>
          <p className="text-xs text-slate-500 mt-1">
            No batch found with code <code className="font-mono">{targetCode}</code>.
          </p>
        </div>
      )}
    </div>
  )
}
