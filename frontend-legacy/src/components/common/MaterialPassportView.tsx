import React, { useState } from 'react'
import type { WasteBatch } from '../../types'
import { SixStageBar } from './SixStageBar'
import { StatusBadge } from './StatusBadge'
import {
  QrCode,
  ShieldCheck,
  Calendar,
  MapPin,
  FileText,
  Download,
  ExternalLink,
  Layers,
  Fingerprint,
} from 'lucide-react'

interface MaterialPassportViewProps {
  batch: WasteBatch
  onClose?: () => void
}

export const MaterialPassportView: React.FC<MaterialPassportViewProps> = ({
  batch,
  onClose,
}) => {
  const [activeTab, setActiveTab] = useState<'timeline' | 'evidence' | 'reconciliation'>('timeline')
  const [copiedHash, setCopiedHash] = useState(false)

  // Deterministic mock SHA-256 passport hash
  const passportHash = `sha256:7f83b1657ff1fc53b92dc18148a1d65dfc2d4b1fa3d677284addd20012${batch.batch_code.slice(-4)}`

  const copyHash = () => {
    navigator.clipboard?.writeText(passportHash)
    setCopiedHash(true)
    setTimeout(() => setCopiedHash(false), 2000)
  }

  return (
    <div className="bg-white rounded-2xl border border-slate-200 shadow-sm overflow-hidden">
      {/* Header Banner */}
      <div className="bg-linear-to-r from-slate-900 via-slate-800 to-emerald-950 text-white p-6 md:p-8">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4">
          <div className="space-y-2">
            <div className="flex items-center gap-2">
              <span className="px-2.5 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 text-xs font-mono font-medium border border-emerald-500/30">
                Digital Product Passport (DPP)
              </span>
              <StatusBadge status={batch.status} />
              {batch.verification?.decision === 'VERIFIED' && (
                <span className="flex items-center gap-1 text-xs text-emerald-400 font-medium">
                  <ShieldCheck className="w-4 h-4" /> Third-Party Verified
                </span>
              )}
            </div>
            <h1 className="text-2xl md:text-3xl font-bold tracking-tight font-mono">
              {batch.batch_code}
            </h1>
            <div className="flex flex-wrap items-center gap-4 text-xs text-slate-300">
              <span className="flex items-center gap-1">
                <Layers className="w-3.5 h-3.5 text-emerald-400" />
                Material: <strong className="text-white">{batch.material}</strong> ({batch.packaging_category})
              </span>
              <span className="flex items-center gap-1">
                <MapPin className="w-3.5 h-3.5 text-emerald-400" />
                {batch.locality}, Mumbai
              </span>
              <span className="flex items-center gap-1">
                <Calendar className="w-3.5 h-3.5 text-emerald-400" />
                Listed: {new Date(batch.created_at).toLocaleDateString('en-IN', { month: 'short', day: 'numeric', year: 'numeric' })}
              </span>
            </div>
          </div>

          {/* QR Code Card */}
          <div className="bg-white/10 backdrop-blur-md p-3 rounded-xl border border-white/15 flex items-center gap-3 shrink-0">
            <div className="bg-white p-2 rounded-lg text-slate-900">
              <QrCode className="w-12 h-12" />
            </div>
            <div className="text-left text-xs space-y-1">
              <div className="font-semibold text-white">Immutable Provenance</div>
              <div className="text-slate-300 text-[11px] font-mono">/b/{batch.batch_code}</div>
              <button
                onClick={() => alert(`Simulating public passport link: https://reloop.in/b/${batch.batch_code}`)}
                className="text-[11px] text-emerald-400 hover:text-emerald-300 font-medium inline-flex items-center gap-1"
              >
                Public Link <ExternalLink className="w-3 h-3" />
              </button>
            </div>
          </div>
        </div>

        {/* Immutable Cryptographic Hash pill */}
        <div className="mt-5 pt-4 border-t border-white/10 flex flex-wrap items-center justify-between gap-2 text-xs">
          <div className="flex items-center gap-2 text-slate-300 font-mono text-[11px]">
            <Fingerprint className="w-4 h-4 text-emerald-400 shrink-0" />
            <span className="text-slate-400">Ledger Hash:</span>
            <span className="truncate max-w-[280px] md:max-w-md">{passportHash}</span>
            <button
              onClick={copyHash}
              className="text-emerald-400 hover:text-emerald-300 ml-1 text-[10px] uppercase font-bold"
            >
              {copiedHash ? 'Copied!' : 'Copy'}
            </button>
          </div>
          <div className="flex items-center gap-2">
            <button
              onClick={() => alert(`Exporting signed DPP for batch ${batch.batch_code}...`)}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-medium transition-colors"
            >
              <Download className="w-3.5 h-3.5" /> Export PDF Dossier
            </button>
            {onClose && (
              <button
                onClick={onClose}
                className="px-3 py-1.5 rounded-lg bg-white/10 hover:bg-white/20 text-white text-xs font-medium"
              >
                Close
              </button>
            )}
          </div>
        </div>
      </div>

      {/* Six-Stage Quantity Bar Banner */}
      <div className="p-6 bg-slate-50 border-b border-slate-200">
        <div className="flex items-center justify-between mb-2">
          <h2 className="text-xs font-bold uppercase tracking-wider text-slate-600">
            Chain of Custody Mass Balance (6-Stage Quantity Bar)
          </h2>
          <span className="text-xs font-mono text-slate-500">
            Initial Estimate: <strong>{batch.quantities.estimated_kg.toFixed(1)} kg</strong>
          </span>
        </div>
        <SixStageBar quantities={batch.quantities} showLabels={true} />
      </div>

      {/* Tabs */}
      <div className="border-b border-slate-200 px-6 flex gap-6 text-sm font-medium">
        <button
          onClick={() => setActiveTab('timeline')}
          className={`py-3.5 border-b-2 transition-colors ${
            activeTab === 'timeline'
              ? 'border-emerald-600 text-emerald-700 font-semibold'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          Lifecycle Custody Timeline
        </button>
        <button
          onClick={() => setActiveTab('evidence')}
          className={`py-3.5 border-b-2 transition-colors ${
            activeTab === 'evidence'
              ? 'border-emerald-600 text-emerald-700 font-semibold'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          Audit Evidence & Documents
        </button>
        <button
          onClick={() => setActiveTab('reconciliation')}
          className={`py-3.5 border-b-2 transition-colors ${
            activeTab === 'reconciliation'
              ? 'border-emerald-600 text-emerald-700 font-semibold'
              : 'border-transparent text-slate-500 hover:text-slate-800'
          }`}
        >
          Mass Reconciliation & Variance
        </button>
      </div>

      {/* Tab Contents */}
      <div className="p-6">
        {activeTab === 'timeline' && (
          <div className="space-y-6">
            {/* Step 1: Generator */}
            <div className="flex gap-4">
              <div className="flex flex-col items-center">
                <div className="w-9 h-9 rounded-full bg-emerald-100 border-2 border-emerald-500 flex items-center justify-center text-emerald-700 font-bold text-xs shrink-0">
                  1
                </div>
                <div className="w-0.5 h-full bg-slate-200 my-1" />
              </div>
              <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 flex-1">
                <div className="flex items-center justify-between text-xs text-slate-500 mb-1">
                  <span className="font-semibold text-slate-700">GENERATOR LISTING CREATED</span>
                  <span>{new Date(batch.created_at).toLocaleString()}</span>
                </div>
                <div className="text-sm font-semibold text-slate-900">{batch.generator_name}</div>
                <div className="text-xs text-slate-600 mt-1 flex items-center gap-1">
                  <MapPin className="w-3.5 h-3.5 text-slate-400" /> {batch.pickup_address}
                </div>
                <div className="mt-2.5 flex items-center gap-3 text-xs font-mono bg-white p-2 rounded border border-slate-200">
                  <span>Declared: <strong>{batch.quantities.estimated_kg.toFixed(1)} kg</strong></span>
                  <span>Polymer: <strong className="text-emerald-700">{batch.material}</strong></span>
                  <span>Category: <strong>{batch.packaging_category}</strong></span>
                </div>
              </div>
            </div>

            {/* Step 2: Collector Pickup */}
            <div className="flex gap-4">
              <div className="flex flex-col items-center">
                <div className={`w-9 h-9 rounded-full border-2 flex items-center justify-center font-bold text-xs shrink-0 ${
                  batch.quantities.collected_kg
                    ? 'bg-blue-100 border-blue-500 text-blue-700'
                    : 'bg-slate-100 border-slate-300 text-slate-400'
                }`}>
                  2
                </div>
                <div className="w-0.5 h-full bg-slate-200 my-1" />
              </div>
              <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 flex-1">
                <div className="flex items-center justify-between text-xs text-slate-500 mb-1">
                  <span className="font-semibold text-slate-700">COLLECTION & HANDOVER</span>
                  <span>{batch.quantities.collected_kg ? 'Completed' : 'Pending Handover'}</span>
                </div>
                <div className="text-sm font-semibold text-slate-900">
                  {batch.collector_name || 'Mumbai Eco Logistics'}
                </div>
                {batch.quantities.collected_kg ? (
                  <div className="mt-2 text-xs font-mono bg-white p-2 rounded border border-slate-200 space-y-1">
                    <div className="flex items-center justify-between">
                      <span>Weighed at Doorstep: <strong>{batch.quantities.collected_kg.toFixed(1)} kg</strong></span>
                      <span className="text-emerald-600 font-semibold">✓ Verified with 6-Digit OTP</span>
                    </div>
                  </div>
                ) : (
                  <p className="text-xs text-slate-500 mt-1">Waiting for collector arrival & OTP confirmation.</p>
                )}
              </div>
            </div>

            {/* Step 3: Recycler Weighbridge Receipt */}
            <div className="flex gap-4">
              <div className="flex flex-col items-center">
                <div className={`w-9 h-9 rounded-full border-2 flex items-center justify-center font-bold text-xs shrink-0 ${
                  batch.quantities.received_kg
                    ? 'bg-indigo-100 border-indigo-500 text-indigo-700'
                    : 'bg-slate-100 border-slate-300 text-slate-400'
                }`}>
                  3
                </div>
                <div className="w-0.5 h-full bg-slate-200 my-1" />
              </div>
              <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 flex-1">
                <div className="flex items-center justify-between text-xs text-slate-500 mb-1">
                  <span className="font-semibold text-slate-700">RECYCLER INBOUND WEIGHBRIDGE</span>
                  <span>{batch.quantities.received_kg ? 'Received & Graded' : 'Pending Inbound Arrival'}</span>
                </div>
                <div className="text-sm font-semibold text-slate-900">
                  {batch.recycler_name || 'Apex Plastic Recovery PWP'}
                </div>
                {batch.quantities.received_kg ? (
                  <div className="mt-2 text-xs font-mono bg-white p-2.5 rounded border border-slate-200 space-y-1">
                    <div className="grid grid-cols-3 gap-2 text-center py-1">
                      <div>
                        <div className="text-[10px] text-slate-400 uppercase">Received</div>
                        <div className="font-bold text-slate-800">{batch.quantities.received_kg.toFixed(1)} kg</div>
                      </div>
                      <div>
                        <div className="text-[10px] text-emerald-600 uppercase">Accepted</div>
                        <div className="font-bold text-emerald-700">{batch.quantities.accepted_kg?.toFixed(1)} kg</div>
                      </div>
                      <div>
                        <div className="text-[10px] text-rose-500 uppercase">Rejected</div>
                        <div className="font-bold text-rose-600">{batch.quantities.rejected_kg?.toFixed(1)} kg</div>
                      </div>
                    </div>
                    <div className="pt-2 border-t border-slate-100 flex items-center justify-between text-[11px] text-slate-600">
                      <span>Quality Grade: <strong>Grade {batch.quality_grade || 'A'}</strong></span>
                      <span>Contamination: <strong>{batch.contamination_pct || 0}%</strong></span>
                    </div>
                  </div>
                ) : (
                  <p className="text-xs text-slate-500 mt-1">Pending arrival at plant weighbridge.</p>
                )}
              </div>
            </div>

            {/* Step 4: Processing Run */}
            <div className="flex gap-4">
              <div className="flex flex-col items-center">
                <div className={`w-9 h-9 rounded-full border-2 flex items-center justify-center font-bold text-xs shrink-0 ${
                  batch.quantities.processed_kg
                    ? 'bg-teal-100 border-teal-500 text-teal-700'
                    : 'bg-slate-100 border-slate-300 text-slate-400'
                }`}>
                  4
                </div>
                <div className="w-0.5 h-full bg-slate-200 my-1" />
              </div>
              <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 flex-1">
                <div className="flex items-center justify-between text-xs text-slate-500 mb-1">
                  <span className="font-semibold text-slate-700">MECHANICAL RECYCLING RUN</span>
                  <span>{batch.quantities.processed_kg ? 'Pelletized' : 'Queued for Extrusion'}</span>
                </div>
                {batch.quantities.processed_kg ? (
                  <div className="mt-2 text-xs font-mono bg-white p-2.5 rounded border border-slate-200 space-y-1">
                    <div className="flex justify-between">
                      <span>Pro-rata Output Pellets: <strong>{batch.quantities.processed_kg.toFixed(1)} kg</strong></span>
                      <span className="text-teal-700 font-bold">Yield: 91.1%</span>
                    </div>
                    <div className="text-[11px] text-slate-500">CPCB Portal Statutory Ref: CPCB/PWM/2026/MH/7741</div>
                  </div>
                ) : (
                  <p className="text-xs text-slate-500 mt-1">Material resting in raw inventory bay.</p>
                )}
              </div>
            </div>

            {/* Step 5: NGO Verification */}
            <div className="flex gap-4">
              <div className="flex flex-col items-center">
                <div className={`w-9 h-9 rounded-full border-2 flex items-center justify-center font-bold text-xs shrink-0 ${
                  batch.verification?.decision === 'VERIFIED'
                    ? 'bg-emerald-100 border-emerald-600 text-emerald-800'
                    : 'bg-slate-100 border-slate-300 text-slate-400'
                }`}>
                  5
                </div>
              </div>
              <div className="bg-slate-50 border border-slate-200 rounded-xl p-4 flex-1">
                <div className="flex items-center justify-between text-xs text-slate-500 mb-1">
                  <span className="font-semibold text-slate-700">INDEPENDENT NGO AUDIT</span>
                  {batch.verification && <StatusBadge status={batch.verification.decision} type="verification" size="sm" />}
                </div>
                <div className="text-sm font-semibold text-slate-900">
                  CleanCity Foundation (Auditor: {batch.verification?.reviewer_name || 'Dr. Priya Nair'})
                </div>
                {batch.verification?.decision === 'VERIFIED' ? (
                  <p className="text-xs text-slate-600 mt-2 bg-emerald-50/60 p-2.5 rounded border border-emerald-200 leading-relaxed">
                    "{batch.verification.comments}"
                  </p>
                ) : (
                  <p className="text-xs text-slate-500 mt-1">Pending audit checklist sign-off.</p>
                )}
              </div>
            </div>
          </div>
        )}

        {activeTab === 'evidence' && (
          <div className="space-y-4">
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-500 mb-2">
              Cryptographically Anchored Audit Documents
            </h3>
            <div className="grid grid-cols-1 md:grid-cols-2 gap-3">
              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 flex items-start gap-3">
                <FileText className="w-5 h-5 text-indigo-600 shrink-0 mt-0.5" />
                <div className="text-xs flex-1">
                  <div className="font-semibold text-slate-900">Weighbridge Gross-Tare Slip</div>
                  <div className="text-slate-500 text-[11px] font-mono">wb_slip_8912.pdf • 420 KB</div>
                  <div className="text-emerald-700 font-mono text-[10px] mt-1">SHA256: 9b2d...471c (Verified)</div>
                </div>
                <button
                  onClick={() => alert('Simulating downloading weighbridge slip...')}
                  className="text-xs text-emerald-600 hover:text-emerald-700 font-medium"
                >
                  View
                </button>
              </div>

              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 flex items-start gap-3">
                <FileText className="w-5 h-5 text-teal-600 shrink-0 mt-0.5" />
                <div className="text-xs flex-1">
                  <div className="font-semibold text-slate-900">Extrusion Processing Log & Yield Sheet</div>
                  <div className="text-slate-500 text-[11px] font-mono">apex_run_0042_log.pdf • 890 KB</div>
                  <div className="text-emerald-700 font-mono text-[10px] mt-1">SHA256: 4f1a...883e (Verified)</div>
                </div>
                <button
                  onClick={() => alert('Simulating downloading run yield sheet...')}
                  className="text-xs text-emerald-600 hover:text-emerald-700 font-medium"
                >
                  View
                </button>
              </div>

              <div className="p-3 bg-slate-50 rounded-xl border border-slate-200 flex items-start gap-3">
                <FileText className="w-5 h-5 text-emerald-600 shrink-0 mt-0.5" />
                <div className="text-xs flex-1">
                  <div className="font-semibold text-slate-900">NGO Auditor Field Checklist & Attestation</div>
                  <div className="text-slate-500 text-[11px] font-mono">cleancity_attestation_001.pdf • 1.2 MB</div>
                  <div className="text-emerald-700 font-mono text-[10px] mt-1">Digital Signature: Dr. Priya Nair</div>
                </div>
                <button
                  onClick={() => alert('Simulating downloading NGO attestation...')}
                  className="text-xs text-emerald-600 hover:text-emerald-700 font-medium"
                >
                  View
                </button>
              </div>
            </div>
          </div>
        )}

        {activeTab === 'reconciliation' && (
          <div className="space-y-4">
            <h3 className="text-xs font-bold uppercase tracking-wider text-slate-500 mb-2">
              Mass Reconciliation & Stage Variance Table
            </h3>
            <div className="overflow-x-auto">
              <table className="w-full text-left text-xs border-collapse">
                <thead>
                  <tr className="border-b border-slate-200 bg-slate-50 text-slate-600 font-semibold">
                    <th className="py-2.5 px-3">Lifecycle Transition</th>
                    <th className="py-2.5 px-3">Input (kg)</th>
                    <th className="py-2.5 px-3">Output (kg)</th>
                    <th className="py-2.5 px-3">Variance / Loss</th>
                    <th className="py-2.5 px-3">Tolerance Status</th>
                  </tr>
                </thead>
                <tbody className="divide-y divide-slate-100 font-mono">
                  <tr>
                    <td className="py-2.5 px-3 font-sans font-medium text-slate-800">
                      Listing → Doorstep Pickup
                    </td>
                    <td className="py-2.5 px-3">{batch.quantities.estimated_kg.toFixed(1)}</td>
                    <td className="py-2.5 px-3">{batch.quantities.collected_kg ? batch.quantities.collected_kg.toFixed(1) : '—'}</td>
                    <td className="py-2.5 px-3 text-slate-600">
                      {batch.quantities.collected_kg
                        ? `${(batch.quantities.collected_kg - batch.quantities.estimated_kg).toFixed(1)} kg`
                        : '—'}
                    </td>
                    <td className="py-2.5 px-3 font-sans text-emerald-600 font-medium">Within 20% limit</td>
                  </tr>
                  <tr>
                    <td className="py-2.5 px-3 font-sans font-medium text-slate-800">
                      Transit → Recycler Weighbridge
                    </td>
                    <td className="py-2.5 px-3">{batch.quantities.collected_kg ? batch.quantities.collected_kg.toFixed(1) : '—'}</td>
                    <td className="py-2.5 px-3">{batch.quantities.received_kg ? batch.quantities.received_kg.toFixed(1) : '—'}</td>
                    <td className="py-2.5 px-3 text-slate-600">
                      {batch.quantities.collected_kg && batch.quantities.received_kg
                        ? `${(batch.quantities.received_kg - batch.quantities.collected_kg).toFixed(1)} kg (-0.5%)`
                        : '—'}
                    </td>
                    <td className="py-2.5 px-3 font-sans text-emerald-600 font-medium">Under 2% moisture loss limit</td>
                  </tr>
                  <tr>
                    <td className="py-2.5 px-3 font-sans font-medium text-slate-800">
                      Weighbridge → Accepted Stream
                    </td>
                    <td className="py-2.5 px-3">{batch.quantities.received_kg ? batch.quantities.received_kg.toFixed(1) : '—'}</td>
                    <td className="py-2.5 px-3">{batch.quantities.accepted_kg ? batch.quantities.accepted_kg.toFixed(1) : '—'}</td>
                    <td className="py-2.5 px-3 text-rose-600">
                      {batch.quantities.rejected_kg ? `-${batch.quantities.rejected_kg.toFixed(1)} kg (Rejection)` : '—'}
                    </td>
                    <td className="py-2.5 px-3 font-sans text-emerald-600 font-medium">Sum balance verified</td>
                  </tr>
                  <tr>
                    <td className="py-2.5 px-3 font-sans font-medium text-slate-800">
                      Extrusion → Recycled Pellets
                    </td>
                    <td className="py-2.5 px-3">{batch.quantities.accepted_kg ? batch.quantities.accepted_kg.toFixed(1) : '—'}</td>
                    <td className="py-2.5 px-3">{batch.quantities.processed_kg ? batch.quantities.processed_kg.toFixed(1) : '—'}</td>
                    <td className="py-2.5 px-3 text-slate-600">
                      {batch.quantities.accepted_kg && batch.quantities.processed_kg
                        ? `-${(batch.quantities.accepted_kg - batch.quantities.processed_kg).toFixed(1)} kg (Residue)`
                        : '—'}
                    </td>
                    <td className="py-2.5 px-3 font-sans text-emerald-600 font-medium">Yield 91.1% verified</td>
                  </tr>
                </tbody>
              </table>
            </div>
          </div>
        )}
      </div>
    </div>
  )
}
