import React, { useState, useEffect } from 'react'
import type { PolymerType } from '../../types'
import { RefreshCw, CheckCircle, X, Cpu } from 'lucide-react'

interface AICameraModalProps {
  isOpen: boolean
  onClose: () => void
  onSelectPolymer: (polymer: PolymerType, confidence: number) => void
}

interface ScanTarget {
  id: string
  name: string
  image: string
  detectedPolymer: PolymerType
  confidence: number
  ricNumber: number
  description: string
  features: string[]
}

const SAMPLE_TARGETS: ScanTarget[] = [
  {
    id: 't-1',
    name: 'Mineral Water Bottle Bale',
    image: 'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=600&q=80',
    detectedPolymer: 'PET',
    confidence: 96.4,
    ricNumber: 1,
    description: 'Polyethylene Terephthalate — clear bottle body with standard injection gate at bottom center.',
    features: ['High optical clarity', 'Gate mark on base', 'Rigid thin-wall structure'],
  },
  {
    id: 't-2',
    name: 'Detergent & Milk Containers',
    image: 'https://images.unsplash.com/photo-1595278069441-2cf29f8005a4?auto=format&fit=crop&w=600&q=80',
    detectedPolymer: 'HDPE',
    confidence: 94.1,
    ricNumber: 2,
    description: 'High-Density Polyethylene — opaque rigid blow-molded bottles with bottom pinch-off seam.',
    features: ['Matte surface finish', 'Continuous base seam', 'Impact & chemical resistant'],
  },
  {
    id: 't-3',
    name: 'Food Takeaway Tubs & Caps',
    image: 'https://images.unsplash.com/photo-1618477461853-cf6ed80faba5?auto=format&fit=crop&w=600&q=80',
    detectedPolymer: 'PP',
    confidence: 91.8,
    ricNumber: 5,
    description: 'Polypropylene — translucent heat-tolerant containers with living hinge capability.',
    features: ['Semi-gloss finish', 'High stiffness-to-weight', 'Low density float characteristic'],
  },
]

export const AICameraModal: React.FC<AICameraModalProps> = ({
  isOpen,
  onClose,
  onSelectPolymer,
}) => {
  const [selectedTargetIdx, setSelectedTargetIdx] = useState(0)
  const [isScanning, setIsScanning] = useState(true)
  const [scanComplete, setScanComplete] = useState(false)

  const activeTarget = SAMPLE_TARGETS[selectedTargetIdx]

  useEffect(() => {
    if (!isOpen) return

    const scanStart = setTimeout(() => {
      setIsScanning(true)
      setScanComplete(false)
    }, 0)

    const timer = setTimeout(() => {
      setIsScanning(false)
      setScanComplete(true)
    }, 1200)

    return () => {
      clearTimeout(scanStart)
      clearTimeout(timer)
    }
  }, [isOpen, selectedTargetIdx])

  if (!isOpen) return null

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/60 backdrop-blur-xs p-4">
      <div className="bg-white rounded-2xl max-w-lg w-full overflow-hidden shadow-2xl border border-slate-200">
        {/* Header */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-slate-100 bg-slate-50">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-emerald-100 flex items-center justify-center text-emerald-700">
              <Cpu className="w-5 h-5" />
            </div>
            <div>
              <h3 className="font-semibold text-slate-900 text-sm md:text-base flex items-center gap-2">
                Edge-AI Polymer Identification
                <span className="text-[10px] font-mono bg-emerald-100 text-emerald-800 px-2 py-0.5 rounded-full font-bold">
                  YOLOv8 + MobileNet
                </span>
              </h3>
              <p className="text-xs text-slate-500">Resin Identification Code (RIC) Computer Vision</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="text-slate-400 hover:text-slate-600 p-1 rounded-lg hover:bg-slate-200/50 transition-colors"
          >
            <X className="w-5 h-5" />
          </button>
        </div>

        {/* Viewfinder Simulator */}
        <div className="relative bg-slate-950 aspect-4/3 flex items-center justify-center overflow-hidden">
          <img
            src={activeTarget.image}
            alt={activeTarget.name}
            className={`w-full h-full object-cover transition-opacity duration-300 ${isScanning ? 'opacity-70 blur-2xs' : 'opacity-90'}`}
          />

          {/* Camera overlay corners */}
          <div className="absolute inset-6 border-2 border-dashed border-emerald-400/70 rounded-xl pointer-events-none flex flex-col justify-between p-3">
            <div className="flex justify-between items-start text-[11px] font-mono text-emerald-300 bg-black/40 px-2 py-1 rounded backdrop-blur-xs">
              <span className="flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-emerald-400 animate-ping" />
                CAM_STREAM // 1080p 60fps
              </span>
              <span>FOV: 84°</span>
            </div>

            {isScanning && (
              <div className="w-full text-center py-2 bg-emerald-950/80 text-emerald-200 border border-emerald-500/40 rounded-lg backdrop-blur-md animate-pulse">
                <div className="flex items-center justify-center gap-2 text-xs font-mono">
                  <RefreshCw className="w-4 h-4 animate-spin text-emerald-400" />
                  Extracting Optical Surface Features & RIC Markings...
                </div>
              </div>
            )}

            {!isScanning && scanComplete && (
              <div className="bg-slate-900/90 text-white p-3 rounded-xl border border-emerald-500/50 backdrop-blur-md shadow-lg">
                <div className="flex items-center justify-between">
                  <div className="flex items-center gap-2">
                    <span className="w-7 h-7 rounded-full bg-emerald-500 text-slate-950 font-bold font-mono text-sm flex items-center justify-center">
                      ♳ {activeTarget.ricNumber}
                    </span>
                    <div>
                      <div className="text-sm font-bold text-emerald-400 font-mono">
                        {activeTarget.detectedPolymer} (RIC #{activeTarget.ricNumber})
                      </div>
                      <div className="text-[11px] text-slate-300">{activeTarget.name}</div>
                    </div>
                  </div>
                  <div className="text-right">
                    <span className="inline-block px-2 py-0.5 bg-emerald-500/20 text-emerald-300 text-xs font-mono font-bold rounded-full border border-emerald-500/30">
                      {activeTarget.confidence}% confidence
                    </span>
                  </div>
                </div>
              </div>
            )}
          </div>

          {/* Sample target switch buttons */}
          <div className="absolute bottom-2 left-2 right-2 flex gap-1.5 z-10">
            {SAMPLE_TARGETS.map((t, idx) => (
              <button
                key={t.id}
                onClick={() => setSelectedTargetIdx(idx)}
                className={`flex-1 py-1 px-2 text-[11px] font-mono rounded transition-colors ${
                  idx === selectedTargetIdx
                    ? 'bg-emerald-600 text-white font-bold shadow-xs'
                    : 'bg-black/60 text-slate-300 hover:bg-black/80'
                }`}
              >
                Sample {idx + 1}: {t.detectedPolymer}
              </button>
            ))}
          </div>
        </div>

        {/* Detection Details */}
        <div className="p-5 space-y-4">
          <div>
            <h4 className="text-xs font-semibold uppercase tracking-wider text-slate-500 mb-1">
              Visual AI Detection Analysis
            </h4>
            <p className="text-xs text-slate-700 leading-relaxed">{activeTarget.description}</p>
          </div>

          <div>
            <span className="text-[11px] font-semibold text-slate-500 block mb-1.5">
              Detected Micro-Characteristics:
            </span>
            <div className="flex flex-wrap gap-1.5">
              {activeTarget.features.map((feat, i) => (
                <span
                  key={i}
                  className="text-[11px] bg-slate-100 text-slate-700 px-2.5 py-1 rounded-md border border-slate-200"
                >
                  ✓ {feat}
                </span>
              ))}
            </div>
          </div>

          {/* Action Footer */}
          <div className="pt-2 flex items-center justify-between border-t border-slate-100">
            <button
              onClick={() => {
                setIsScanning(true)
                setScanComplete(false)
                setTimeout(() => {
                  setIsScanning(false)
                  setScanComplete(true)
                }, 1000)
              }}
              className="inline-flex items-center gap-1.5 text-xs text-slate-600 hover:text-slate-900 font-medium px-3 py-2 rounded-lg hover:bg-slate-100 transition-colors"
            >
              <RefreshCw className="w-3.5 h-3.5" />
              Re-scan frame
            </button>

            <button
              onClick={() => {
                onSelectPolymer(activeTarget.detectedPolymer, activeTarget.confidence)
                onClose()
              }}
              disabled={isScanning}
              className="inline-flex items-center gap-2 px-5 py-2.5 bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-semibold rounded-lg shadow-sm transition-all hover:shadow cursor-pointer"
            >
              <CheckCircle className="w-4 h-4" />
              Apply {activeTarget.detectedPolymer} to Batch
            </button>
          </div>
        </div>
      </div>
    </div>
  )
}
