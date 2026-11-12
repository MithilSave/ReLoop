import React, { useState } from 'react'
import { COST_COMPARISON_OPTIONS } from '../../context/demoData'
import type { CostBreakdownItem } from '../../types'
import {
  CheckCircle,
} from 'lucide-react'
import {
  ResponsiveContainer,
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from 'recharts'

export const RecyclerLandedCostComparison: React.FC = () => {
  const [perspective, setPerspective] = useState<'RECYCLER' | 'COLLECTOR' | 'GENERATOR'>('RECYCLER')
  const [selectedOption, setSelectedOption] = useState<CostBreakdownItem>(COST_COMPARISON_OPTIONS[0])

  // Waterfall dataset for the selected option
  const waterfallData = [
    { name: 'Purchase', cost: selectedOption.purchase_cost, fill: '#3b82f6' },
    { name: 'Collection', cost: selectedOption.collection_cost, fill: '#6366f1' },
    { name: 'Transport', cost: selectedOption.transport_cost, fill: '#8b5cf6' },
    { name: 'Sorting', cost: selectedOption.sorting_cost, fill: '#a855f7' },
    { name: 'Storage', cost: selectedOption.storage_cost, fill: '#d946ef' },
    { name: 'Rejection', cost: selectedOption.rejection_cost, fill: '#f43f5e' },
    { name: 'Landed/Usable kg', cost: selectedOption.cost_per_usable_kg, fill: '#10b981' },
  ]

  return (
    <div className="space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4">
        <div>
          <h1 className="text-xl md:text-2xl font-bold text-slate-900">
            Landed Cost Estimation & Comparison
          </h1>
          <p className="text-xs text-slate-500">
            End-to-end cost line itemization from doorstep purchase to net usable kg inside extrusion line
          </p>
        </div>

        {/* Three Perspectives Toggle (Docs/09 requirement) */}
        <div className="flex items-center bg-white border border-slate-200 rounded-xl p-1 text-xs">
          {(
            [
              { id: 'RECYCLER', label: 'Recycler Landed' },
              { id: 'COLLECTOR', label: 'Collector Margin' },
              { id: 'GENERATOR', label: 'Generator Net' },
            ] as const
          ).map((tab) => (
            <button
              key={tab.id}
              onClick={() => setPerspective(tab.id)}
              className={`px-3 py-1.5 rounded-lg font-semibold transition-colors cursor-pointer ${
                perspective === tab.id
                  ? 'bg-purple-600 text-white shadow-xs'
                  : 'text-slate-600 hover:text-slate-900'
              }`}
            >
              {tab.label}
            </button>
          ))}
        </div>
      </div>

      {/* Comparison Options Cards */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        {COST_COMPARISON_OPTIONS.map((opt) => {
          const isSelected = selectedOption.option_name === opt.option_name
          return (
            <div
              key={opt.option_name}
              onClick={() => setSelectedOption(opt)}
              className={`p-5 rounded-2xl border transition-all cursor-pointer ${
                isSelected
                  ? 'bg-purple-50/80 border-purple-500 ring-2 ring-purple-500/20 shadow-md'
                  : 'bg-white border-slate-200 hover:border-slate-300 shadow-xs'
              }`}
            >
              <div className="flex items-center justify-between">
                <span className="text-[11px] font-bold uppercase tracking-wider text-purple-700 bg-purple-100/60 px-2 py-0.5 rounded">
                  {opt.type}
                </span>
                {isSelected && (
                  <span className="text-[11px] font-bold text-purple-700 flex items-center gap-1">
                    <CheckCircle className="w-3.5 h-3.5" /> Selected
                  </span>
                )}
              </div>
              <h3 className="font-bold text-sm text-slate-900 mt-2">{opt.option_name}</h3>
              <div className="mt-3 flex items-baseline justify-between border-t border-slate-100 pt-3">
                <span className="text-xs text-slate-500">Landed / Usable kg</span>
                <span className="text-xl font-mono font-extrabold text-slate-900">
                  ₹{opt.cost_per_usable_kg.toFixed(2)}
                </span>
              </div>
              <div className="text-[11px] text-slate-500 mt-1 flex justify-between font-mono">
                <span>Usable Yield: {opt.usable_kg} kg</span>
                <span>Gross Cost: ₹{opt.total_cost.toFixed(1)}/kg</span>
              </div>
            </div>
          )
        })}
      </div>

      {/* Waterfall Line-Item Bar Chart */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 md:p-8 space-y-4">
        <div className="flex items-center justify-between border-b border-slate-100 pb-3">
          <div>
            <h2 className="text-sm font-bold text-slate-900">
              Landed Cost Waterfall Breakdown: {selectedOption.option_name}
            </h2>
            <p className="text-xs text-slate-500">
              Step-by-step cost accumulation in ₹ per kg of plastic
            </p>
          </div>
          <span className="text-xs font-mono font-bold text-emerald-700 bg-emerald-50 px-3 py-1 rounded-lg border border-emerald-200">
            Effective: ₹{selectedOption.cost_per_usable_kg.toFixed(2)} / usable kg
          </span>
        </div>

        <div className="h-64 w-full pt-4">
          <ResponsiveContainer width="100%" height="100%">
            <BarChart data={waterfallData} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
              <XAxis dataKey="name" tick={{ fontSize: 11, fill: '#64748b' }} />
              <YAxis tick={{ fontSize: 11, fill: '#64748b' }} unit="₹" />
              <Tooltip
                formatter={(val: any) => [`₹${val}`, 'Cost Line (₹/kg)']}
                contentStyle={{ backgroundColor: '#0f172a', color: '#fff', borderRadius: '8px', fontSize: '12px' }}
              />
              <Bar dataKey="cost" radius={[6, 6, 0, 0]} />
            </BarChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Detailed Side-by-Side Cost Comparison Table */}
      <div className="bg-white rounded-2xl border border-slate-200 shadow-xs overflow-hidden">
        <div className="p-5 border-b border-slate-100">
          <h2 className="text-sm font-bold text-slate-900">Comprehensive Line Item Matrix</h2>
          <p className="text-xs text-slate-500">Comparative economics across procurement models</p>
        </div>

        <div className="overflow-x-auto">
          <table className="w-full text-left text-xs border-collapse font-mono">
            <thead>
              <tr className="border-b border-slate-200 bg-slate-50 text-slate-600 font-sans font-semibold">
                <th className="py-3 px-4">Cost Element</th>
                {COST_COMPARISON_OPTIONS.map((o) => (
                  <th key={o.option_name} className="py-3 px-4">
                    {o.option_name}
                  </th>
                ))}
              </tr>
            </thead>
            <tbody className="divide-y divide-slate-100">
              <tr>
                <td className="py-3 px-4 font-sans font-medium text-slate-800">1. Raw Material Purchase</td>
                {COST_COMPARISON_OPTIONS.map((o) => (
                  <td key={o.option_name} className="py-3 px-4">₹{o.purchase_cost.toFixed(2)}</td>
                ))}
              </tr>
              <tr>
                <td className="py-3 px-4 font-sans font-medium text-slate-800">2. Collection Fee (Logistics)</td>
                {COST_COMPARISON_OPTIONS.map((o) => (
                  <td key={o.option_name} className="py-3 px-4">₹{o.collection_cost.toFixed(2)}</td>
                ))}
              </tr>
              <tr>
                <td className="py-3 px-4 font-sans font-medium text-slate-800">3. Transportation Corridor</td>
                {COST_COMPARISON_OPTIONS.map((o) => (
                  <td key={o.option_name} className="py-3 px-4">₹{o.transport_cost.toFixed(2)}</td>
                ))}
              </tr>
              <tr>
                <td className="py-3 px-4 font-sans font-medium text-slate-800">4. Optical & Manual Sorting</td>
                {COST_COMPARISON_OPTIONS.map((o) => (
                  <td key={o.option_name} className="py-3 px-4">₹{o.sorting_cost.toFixed(2)}</td>
                ))}
              </tr>
              <tr>
                <td className="py-3 px-4 font-sans font-medium text-slate-800">5. Warehouse Storage Buffer</td>
                {COST_COMPARISON_OPTIONS.map((o) => (
                  <td key={o.option_name} className="py-3 px-4">₹{o.storage_cost.toFixed(2)}</td>
                ))}
              </tr>
              <tr>
                <td className="py-3 px-4 font-sans font-medium text-slate-800">6. Contamination / Rejection Loss</td>
                {COST_COMPARISON_OPTIONS.map((o) => (
                  <td key={o.option_name} className="py-3 px-4 text-rose-600 font-bold">₹{o.rejection_cost.toFixed(2)}</td>
                ))}
              </tr>
              <tr className="bg-slate-50 font-bold text-slate-900 border-t border-slate-200">
                <td className="py-3 px-4 font-sans">Total Gross Cost (₹ / kg)</td>
                {COST_COMPARISON_OPTIONS.map((o) => (
                  <td key={o.option_name} className="py-3 px-4">₹{o.total_cost.toFixed(2)}</td>
                ))}
              </tr>
              <tr className="bg-emerald-50/60 font-extrabold text-emerald-950 border-t border-emerald-200">
                <td className="py-3.5 px-4 font-sans text-emerald-900">Effective ₹ / Usable kg</td>
                {COST_COMPARISON_OPTIONS.map((o) => (
                  <td key={o.option_name} className="py-3.5 px-4 text-sm text-emerald-700">
                    ₹{o.cost_per_usable_kg.toFixed(2)}
                  </td>
                ))}
              </tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  )
}
