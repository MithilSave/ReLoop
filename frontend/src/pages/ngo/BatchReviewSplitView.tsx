import React, { useState } from 'react'
import { useParams, useNavigate, Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import { SixStageBar } from '../../components/common/SixStageBar'
import { StatusBadge } from '../../components/common/StatusBadge'
import {
  ShieldCheck,
  CheckCircle2,
  FileText,
  ArrowLeft,
  Lock,
} from 'lucide-react'

export const NGOBatchReviewSplitView: React.FC = () => {
  const { batchId } = useParams<{ batchId: string }>()
  const navigate = useNavigate()
  const { batches, submitNGOVerification, currentPersona } = useApp()

  const batch = batches.find((b) => b.id === batchId) || batches[0]
  const currentDecision = batch?.verification?.decision || 'PENDING'

  const [decision, setDecision] = useState<'VERIFIED' | 'FLAGGED' | 'REJECTED' | 'REQUIRES_CORRECTION'>(
    currentDecision === 'PENDING' ? 'VERIFIED' : (currentDecision as any)
  )
  const [comments, setComments] = useState<string>(
    batch?.verification?.comments ||
      'Weighbridge slips and processing yield re-reconciled against CPCB norms. Full traceability intact.'
  )
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [auditSuccess, setAuditSuccess] = useState(false)

  if (!batch) {
    return (
      <div className="p-8 text-center text-slate-500">
        Batch not found.{' '}
        <Link to="/ngo" className="text-emerald-600 underline">
          Return to Queue
        </Link>
      </div>
    )
  }

  const handleDecisionSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)

    setTimeout(() => {
      submitNGOVerification(batch.id, decision, comments)
      setIsSubmitting(false)
      setAuditSuccess(true)
      setTimeout(() => {
        navigate('/ngo')
      }, 1500)
    }, 500)
  }

  return (
    <div className="space-y-6">
      {/* Top Breadcrumb & Read-Only Notice */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
        <div className="flex items-center gap-3">
          <Link
            to="/ngo"
            className="p-2 rounded-xl text-slate-500 hover:bg-white hover:text-slate-800 transition-colors border border-slate-200 bg-white"
          >
            <ArrowLeft className="w-4 h-4" />
          </Link>
          <div>
            <div className="flex items-center gap-2">
              <span className="font-mono font-bold text-lg text-slate-900">{batch.batch_code}</span>
              <StatusBadge status={currentDecision} type="verification" />
            </div>
            <p className="text-xs text-slate-500">
              Auditor: {currentPersona.name} ({currentPersona.org_name})
            </p>
          </div>
        </div>

        {/* Read-Only Protection Badge (Docs/09 requirement) */}
        <div className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-xl bg-slate-100 text-slate-700 text-xs font-semibold border border-slate-200">
          <Lock className="w-3.5 h-3.5 text-slate-500" />
          <span>Operational Data: Strictly Read-Only</span>
        </div>
      </div>

      {/* Success Notification */}
      {auditSuccess && (
        <div className="bg-emerald-50 border border-emerald-300 rounded-xl p-4 flex items-center gap-2 text-xs text-emerald-900 shadow-xs animate-in fade-in">
          <CheckCircle2 className="w-5 h-5 text-emerald-600 shrink-0" />
          <span className="font-bold">
            Audit decision recorded: {decision}! Updating CPCB compliance ledger...
          </span>
        </div>
      )}

      {/* Six-Stage Quantity Bar Banner */}
      <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
        <div className="text-xs font-bold uppercase tracking-wider text-slate-600 mb-2">
          Mass Reconciliation Bar
        </div>
        <SixStageBar quantities={batch.quantities} compact={false} />
      </div>

      {/* ── THE SPLIT VIEW CONTAINER ──────────────────────────── */}
      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6 items-start">
        {/* LEFT PANEL: Passport Timeline, Record Versions & Diffs */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-5">
          <div className="flex items-center justify-between border-b border-slate-100 pb-3">
            <h2 className="text-sm font-bold text-slate-900">
              Left Panel: Chain of Custody & Version Diffs
            </h2>
            <span className="text-[11px] font-mono text-slate-400">Version 1.0</span>
          </div>

          <div className="space-y-4">
            {/* Stage 1 */}
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-1 text-xs">
              <div className="flex justify-between font-semibold text-slate-700">
                <span>1. Generator Declaration</span>
                <span className="font-mono">{new Date(batch.created_at).toLocaleDateString()}</span>
              </div>
              <div className="font-medium text-slate-900">{batch.generator_name}</div>
              <div className="text-slate-500">{batch.pickup_address}</div>
              <div className="font-mono pt-1 text-emerald-800">
                Declared: {batch.quantities.estimated_kg.toFixed(1)} kg • {batch.material} ({batch.packaging_category})
              </div>
            </div>

            {/* Stage 2 */}
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-1 text-xs">
              <div className="flex justify-between font-semibold text-slate-700">
                <span>2. Collector Doorstep Pickup & OTP</span>
                <span className="text-emerald-700 font-semibold">✓ OTP Verified</span>
              </div>
              <div className="font-medium text-slate-900">
                {batch.collector_name || 'Mumbai Eco Logistics'}
              </div>
              <div className="font-mono text-slate-800">
                Actual Weighed: <strong>{batch.quantities.collected_kg?.toFixed(1) || '—'} kg</strong>
                <span className="text-slate-500 font-sans ml-2">
                  (Variance: {((batch.quantities.collected_kg || 100) - batch.quantities.estimated_kg).toFixed(1)} kg)
                </span>
              </div>
            </div>

            {/* Stage 3 */}
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-1 text-xs">
              <div className="flex justify-between font-semibold text-slate-700">
                <span>3. Recycler Weighbridge Gross-Tare</span>
                <span className="text-purple-700 font-semibold">Grade {batch.quality_grade || 'A'}</span>
              </div>
              <div className="font-medium text-slate-900">
                {batch.recycler_name || 'Apex Plastic Recovery PWP'}
              </div>
              <div className="grid grid-cols-3 gap-2 font-mono text-center pt-1">
                <div className="bg-white p-1 rounded border border-slate-200">
                  <div className="text-[10px] text-slate-400">Received</div>
                  <div className="font-bold">{batch.quantities.received_kg?.toFixed(1) || '—'} kg</div>
                </div>
                <div className="bg-white p-1 rounded border border-slate-200">
                  <div className="text-[10px] text-emerald-600">Accepted</div>
                  <div className="font-bold text-emerald-700">{batch.quantities.accepted_kg?.toFixed(1) || '—'} kg</div>
                </div>
                <div className="bg-white p-1 rounded border border-slate-200">
                  <div className="text-[10px] text-rose-500">Rejected</div>
                  <div className="font-bold text-rose-600">{batch.quantities.rejected_kg?.toFixed(1) || '0.0'} kg</div>
                </div>
              </div>
            </div>

            {/* Stage 4 */}
            <div className="p-3.5 rounded-xl bg-slate-50 border border-slate-200 space-y-1 text-xs">
              <div className="flex justify-between font-semibold text-slate-700">
                <span>4. Extrusion Pelletizing & Yield</span>
                <span className="font-mono text-teal-700 font-bold">Yield: 91.1%</span>
              </div>
              <div className="font-mono text-slate-800">
                Pellets Output: <strong>{batch.quantities.processed_kg?.toFixed(1) || '—'} kg</strong>
              </div>
              <div className="text-[11px] text-slate-500">
                Statutory CPCB Reference: CPCB/PWM/2026/MH/7741
              </div>
            </div>
          </div>
        </div>

        {/* RIGHT PANEL: Evidence Viewer & Quantity Reconciliation Table */}
        <div className="space-y-6">
          {/* Evidence Docs & Slips */}
          <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
            <h2 className="text-sm font-bold text-slate-900 border-b border-slate-100 pb-2">
              Right Panel: Audit Evidence Documents & Hashes
            </h2>

            <div className="space-y-2.5">
              <div className="p-3 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between text-xs">
                <div className="flex items-center gap-2.5">
                  <FileText className="w-4 h-4 text-purple-600" />
                  <div>
                    <div className="font-bold text-slate-900">Weighbridge Gross Slip #8912</div>
                    <div className="text-[10px] font-mono text-slate-500">SHA256: 9b2d...471c (Digital Seal OK)</div>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => alert('Simulating viewing weighbridge slip...')}
                  className="text-xs text-emerald-600 hover:text-emerald-700 font-bold"
                >
                  Inspect
                </button>
              </div>

              <div className="p-3 rounded-xl bg-slate-50 border border-slate-200 flex items-center justify-between text-xs">
                <div className="flex items-center gap-2.5">
                  <FileText className="w-4 h-4 text-teal-600" />
                  <div>
                    <div className="font-bold text-slate-900">Extrusion Energy & Yield Log</div>
                    <div className="text-[10px] font-mono text-slate-500">SHA256: 4f1a...883e (Digital Seal OK)</div>
                  </div>
                </div>
                <button
                  type="button"
                  onClick={() => alert('Simulating viewing extrusion log...')}
                  className="text-xs text-emerald-600 hover:text-emerald-700 font-bold"
                >
                  Inspect
                </button>
              </div>
            </div>

            {/* Reconciliation Table with Variance % and Thresholds */}
            <div className="pt-2">
              <div className="text-xs font-bold uppercase tracking-wider text-slate-600 mb-2">
                Variance Reconciliation & Threshold Check
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-left text-[11px] border-collapse font-mono">
                  <thead>
                    <tr className="bg-slate-100 text-slate-600">
                      <th className="p-2">Stage</th>
                      <th className="p-2">kg</th>
                      <th className="p-2">Variance</th>
                      <th className="p-2">CPCB Rule</th>
                    </tr>
                  </thead>
                  <tbody className="divide-y divide-slate-100">
                    <tr>
                      <td className="p-2 font-sans font-medium">1. Declared</td>
                      <td className="p-2">{batch.quantities.estimated_kg.toFixed(1)}</td>
                      <td className="p-2 text-slate-400">—</td>
                      <td className="p-2 text-emerald-700 font-sans">Baseline</td>
                    </tr>
                    <tr>
                      <td className="p-2 font-sans font-medium">2. Collected</td>
                      <td className="p-2">{batch.quantities.collected_kg?.toFixed(1) || '—'}</td>
                      <td className="p-2">-2.0%</td>
                      <td className="p-2 text-emerald-700 font-sans">&lt;20% limit</td>
                    </tr>
                    <tr>
                      <td className="p-2 font-sans font-medium">3. Received</td>
                      <td className="p-2">{batch.quantities.received_kg?.toFixed(1) || '—'}</td>
                      <td className="p-2">-0.5%</td>
                      <td className="p-2 text-emerald-700 font-sans">&lt;2% moisture</td>
                    </tr>
                    <tr>
                      <td className="p-2 font-sans font-medium">4. Accepted</td>
                      <td className="p-2">{batch.quantities.accepted_kg?.toFixed(1) || '—'}</td>
                      <td className="p-2">-7.5 kg</td>
                      <td className="p-2 text-emerald-700 font-sans">Contam. logged</td>
                    </tr>
                    <tr>
                      <td className="p-2 font-sans font-medium">5. Pellets</td>
                      <td className="p-2">{batch.quantities.processed_kg?.toFixed(1) || '—'}</td>
                      <td className="p-2">Yield 91.1%</td>
                      <td className="p-2 text-emerald-700 font-sans">Passes &gt;85%</td>
                    </tr>
                  </tbody>
                </table>
              </div>
            </div>
          </div>

          {/* Decision Action Box */}
          <form
            onSubmit={handleDecisionSubmit}
            className="bg-white rounded-2xl border-2 border-amber-300 shadow-md p-6 space-y-4"
          >
            <div className="flex items-center justify-between border-b border-slate-100 pb-2">
              <h3 className="text-sm font-bold text-slate-900 flex items-center gap-2">
                <ShieldCheck className="w-5 h-5 text-amber-600" />
                Auditor Statutory Decision Action
              </h3>
              <span className="text-[10px] uppercase font-bold tracking-wider text-amber-800 bg-amber-100 px-2 py-0.5 rounded">
                Append-Only Action
              </span>
            </div>

            {/* Decision Radio/Buttons */}
            <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
              {[
                { id: 'VERIFIED', label: 'VERIFIED', color: 'bg-emerald-600 text-white' },
                { id: 'FLAGGED', label: 'FLAGGED', color: 'bg-rose-600 text-white' },
                { id: 'REQUIRES_CORRECTION', label: 'CORRECTION', color: 'bg-amber-600 text-white' },
                { id: 'REJECTED', label: 'REJECTED', color: 'bg-red-700 text-white' },
              ].map((btn) => (
                <button
                  key={btn.id}
                  type="button"
                  onClick={() => setDecision(btn.id as any)}
                  className={`py-2 px-1 rounded-xl text-xs font-bold transition-all cursor-pointer ${
                    decision === btn.id
                      ? `${btn.color} ring-2 ring-slate-900 shadow-xs`
                      : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                  }`}
                >
                  {btn.label}
                </button>
              ))}
            </div>

            {/* Reviewer Comments */}
            <div className="space-y-1">
              <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Auditor Comments & CPCB Compliance Rationale
              </label>
              <textarea
                rows={3}
                value={comments}
                onChange={(e) => setComments(e.target.value)}
                className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs focus:ring-2 focus:ring-amber-500 focus:outline-hidden"
                required
              />
            </div>

            {/* Submit */}
            <div className="pt-2 flex items-center justify-between">
              <button
                type="button"
                onClick={() => navigate('/ngo')}
                className="text-xs font-semibold text-slate-500 hover:text-slate-800"
              >
                Cancel
              </button>
              <button
                type="submit"
                disabled={isSubmitting}
                className="px-6 py-2.5 rounded-xl bg-amber-600 hover:bg-amber-700 text-white text-xs font-bold shadow-md transition-all cursor-pointer"
              >
                {isSubmitting ? 'Recording Audit...' : 'Submit Auditor Decision'}
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
  )
}
