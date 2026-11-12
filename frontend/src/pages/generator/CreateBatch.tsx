import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import type { PolymerType, PackagingCategory } from '../../types'
import { AICameraModal } from '../../components/common/AICameraModal'
import {
  Sparkles,
  CheckCircle,
  ArrowLeft,
  Scale,
} from 'lucide-react'

const MUMBAI_LOCALITIES = [
  'Andheri West',
  'Andheri East',
  'Bandra West',
  'Bandra East',
  'Goregaon East',
  'Goregaon West',
  'Lower Parel',
  'Dadar West',
  'Powai',
  'Kurla West',
  'Thane West',
  'Navi Mumbai (Vashi)',
]

export const GeneratorCreateBatch: React.FC = () => {
  const navigate = useNavigate()
  const { createBatch } = useApp()

  const [material, setMaterial] = useState<PolymerType>('PET')
  const [packagingCategory, setPackagingCategory] = useState<PackagingCategory>('Cat-I')
  const [estimatedKg, setEstimatedKg] = useState<number>(85)
  const [locality, setLocality] = useState<string>('Andheri West')
  const [address, setAddress] = useState<string>('Wing A, Green Society CHS, SV Road, Andheri West, Mumbai')
  const [availableFrom, setAvailableFrom] = useState<string>('2026-11-13')
  const [availableTo, setAvailableTo] = useState<string>('2026-11-16')
  const [isAiModalOpen, setIsAiModalOpen] = useState(false)
  const [aiDetectedInfo, setAiDetectedInfo] = useState<{ polymer: PolymerType; confidence: number } | null>(null)
  const [isSubmitting, setIsSubmitting] = useState(false)

  const handleAiDetection = (detectedPolymer: PolymerType, confidence: number) => {
    setMaterial(detectedPolymer)
    setAiDetectedInfo({ polymer: detectedPolymer, confidence })
    if (detectedPolymer === 'PET' || detectedPolymer === 'HDPE') {
      setPackagingCategory('Cat-I')
    } else if (detectedPolymer === 'LDPE') {
      setPackagingCategory('Cat-II')
    }
  }

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setIsSubmitting(true)

    setTimeout(() => {
      const created = createBatch({
        material,
        packaging_category: packagingCategory,
        estimated_kg: estimatedKg,
        pickup_address: address,
        locality,
        available_from: availableFrom,
        available_to: availableTo,
      })
      setIsSubmitting(false)
      navigate(`/generator/batches?created=${created.batch_code}`)
    }, 600)
  }

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      {/* Header */}
      <div className="flex items-center gap-3">
        <button
          onClick={() => navigate('/generator')}
          className="p-2 rounded-xl text-slate-500 hover:bg-white hover:text-slate-800 transition-colors border border-slate-200 bg-white"
        >
          <ArrowLeft className="w-4 h-4" />
        </button>
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900">List Plastic Waste Batch</h1>
          <p className="text-xs text-slate-500">
            Publish segregated plastics to registered collectors for verified CPCB recycling
          </p>
        </div>
      </div>

      <form onSubmit={handleSubmit} className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 md:p-8 space-y-6">
        {/* Polymer Selection with Edge-AI Assistant */}
        <div className="space-y-3">
          <div className="flex items-center justify-between">
            <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
              1. Polymer Type (Resin Identification Code)
            </label>
            <button
              type="button"
              onClick={() => setIsAiModalOpen(true)}
              className="inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-emerald-50 hover:bg-emerald-100 text-emerald-800 text-xs font-bold border border-emerald-300 transition-colors cursor-pointer"
            >
              <Sparkles className="w-3.5 h-3.5 text-emerald-600" />
              <span>Edge-AI Camera Scanner</span>
            </button>
          </div>

          {aiDetectedInfo && (
            <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-3 flex items-center justify-between text-xs text-emerald-900 animate-in fade-in">
              <span className="flex items-center gap-2">
                <CheckCircle className="w-4 h-4 text-emerald-600 shrink-0" />
                <span>
                  AI Identified: <strong>{aiDetectedInfo.polymer}</strong> ({aiDetectedInfo.confidence}% optical confidence)
                </span>
              </span>
              <button
                type="button"
                onClick={() => setAiDetectedInfo(null)}
                className="text-[11px] text-emerald-700 underline font-medium"
              >
                Clear
              </button>
            </div>
          )}

          <div className="grid grid-cols-2 sm:grid-cols-4 gap-3">
            {[
              { code: 'PET', name: 'PET (RIC 1)', desc: 'Bottles, jars, clear containers' },
              { code: 'HDPE', name: 'HDPE (RIC 2)', desc: 'Milk jugs, shampoo bottles, pipes' },
              { code: 'PP', name: 'PP (RIC 5)', desc: 'Food tubs, bottle caps, straws' },
              { code: 'LDPE', name: 'LDPE (RIC 4)', desc: 'Bags, shrink films, squeeze bottles' },
            ].map((p) => {
              const isSelected = material === p.code
              return (
                <button
                  key={p.code}
                  type="button"
                  onClick={() => setMaterial(p.code as PolymerType)}
                  className={`p-3 rounded-xl border text-left transition-all cursor-pointer ${
                    isSelected
                      ? 'bg-emerald-50/80 border-emerald-500 ring-2 ring-emerald-500/20'
                      : 'bg-white border-slate-200 hover:border-slate-300'
                  }`}
                >
                  <div className={`font-mono font-bold text-sm ${isSelected ? 'text-emerald-800' : 'text-slate-800'}`}>
                    {p.name}
                  </div>
                  <div className="text-[11px] text-slate-500 mt-1 line-clamp-2">{p.desc}</div>
                </button>
              )
            })}
          </div>
        </div>

        {/* EPR Packaging Category */}
        <div className="space-y-2">
          <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
            2. CPCB Packaging Category
          </label>
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3">
            {[
              { id: 'Cat-I', label: 'Cat-I: Rigid Plastic', desc: 'Rigid plastic packaging' },
              { id: 'Cat-II', label: 'Cat-II: Flexible Plastic', desc: 'Single or multi-layer flexible' },
              { id: 'Cat-III', label: 'Cat-III: Multi-Layered (MLP)', desc: 'With at least one plastic layer' },
            ].map((cat) => (
              <button
                key={cat.id}
                type="button"
                onClick={() => setPackagingCategory(cat.id as PackagingCategory)}
                className={`p-3 rounded-xl border text-left transition-all cursor-pointer ${
                  packagingCategory === cat.id
                    ? 'bg-emerald-50/80 border-emerald-500 ring-2 ring-emerald-500/20'
                    : 'bg-white border-slate-200 hover:border-slate-300'
                }`}
              >
                <div className="font-semibold text-xs text-slate-900">{cat.label}</div>
                <div className="text-[11px] text-slate-500 mt-0.5">{cat.desc}</div>
              </button>
            ))}
          </div>
        </div>

        {/* Estimated Weight Slider */}
        <div className="space-y-3 bg-slate-50 p-5 rounded-xl border border-slate-200">
          <div className="flex items-center justify-between">
            <label className="text-xs font-bold uppercase tracking-wider text-slate-700 flex items-center gap-2">
              <Scale className="w-4 h-4 text-emerald-600" />
              3. Estimated Batch Weight
            </label>
            <div className="text-xl font-mono font-extrabold text-slate-900">
              {estimatedKg} <span className="text-xs font-sans text-slate-500 font-normal">kg</span>
            </div>
          </div>
          <input
            type="range"
            min={10}
            max={500}
            step={5}
            value={estimatedKg}
            onChange={(e) => setEstimatedKg(Number(e.target.value))}
            className="w-full accent-emerald-600 cursor-pointer"
          />
          <div className="flex justify-between text-[11px] text-slate-600 font-mono">
            <span>10 kg (Minimum)</span>
            <span>250 kg</span>
            <span>500 kg (Commercial Bale)</span>
          </div>
          <p className="text-[11px] text-slate-600 italic">
            *Actual weight will be recorded at pickup with an IoT digital scale and confirmed via OTP.
          </p>
        </div>

        {/* Location & Address */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-1.5">
            <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
              Mumbai Locality
            </label>
            <select
              value={locality}
              onChange={(e) => setLocality(e.target.value)}
              className="w-full px-3 py-2.5 rounded-xl border border-slate-300 text-xs font-medium focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
            >
              {MUMBAI_LOCALITIES.map((loc) => (
                <option key={loc} value={loc}>
                  {loc}
                </option>
              ))}
            </select>
          </div>

          <div className="space-y-1.5">
            <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
              Pickup Time Window
            </label>
            <div className="grid grid-cols-2 gap-2">
              <input
                type="date"
                value={availableFrom}
                onChange={(e) => setAvailableFrom(e.target.value)}
                className="w-full px-2.5 py-2 rounded-xl border border-slate-300 text-xs font-medium"
              />
              <input
                type="date"
                value={availableTo}
                onChange={(e) => setAvailableTo(e.target.value)}
                className="w-full px-2.5 py-2 rounded-xl border border-slate-300 text-xs font-medium"
              />
            </div>
          </div>
        </div>

        <div className="space-y-1.5">
          <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
            Pickup Address & Landmark
          </label>
          <textarea
            rows={2}
            value={address}
            onChange={(e) => setAddress(e.target.value)}
            className="w-full px-3 py-2 rounded-xl border border-slate-300 text-xs focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
            placeholder="Complete building, wing, and landmark details in Mumbai"
            required
          />
        </div>

        {/* Actions */}
        <div className="pt-4 border-t border-slate-100 flex items-center justify-between">
          <button
            type="button"
            onClick={() => navigate('/generator')}
            className="px-4 py-2 text-xs font-semibold text-slate-600 hover:text-slate-900"
          >
            Cancel
          </button>

          <button
            type="submit"
            disabled={isSubmitting}
            className="inline-flex items-center gap-2 px-6 py-3 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-md transition-all cursor-pointer"
          >
            {isSubmitting ? 'Publishing to Marketplace...' : 'Publish Listing & Generate QR'}
          </button>
        </div>
      </form>

      {/* Edge-AI Camera Modal */}
      <AICameraModal
        isOpen={isAiModalOpen}
        onClose={() => setIsAiModalOpen(false)}
        onSelectPolymer={handleAiDetection}
      />
    </div>
  )
}
