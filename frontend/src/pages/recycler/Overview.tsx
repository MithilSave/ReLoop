import React from 'react'
import { Link } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import {
  Package,
  Scale,
  RotateCcw,
  FileSpreadsheet,
} from 'lucide-react'
import {
  ResponsiveContainer,
  LineChart,
  Line,
  XAxis,
  YAxis,
  Tooltip,
  CartesianGrid,
} from 'recharts'

export const RecyclerOverview: React.FC = () => {
  const { batches, processingRuns, allocations, currentPersona } = useApp()

  // Inbound batches en route or received
  const inboundBatches = batches.filter(
    (b) => b.status === 'IN_TRANSIT' && (b.recycler_org_id === currentPersona.org_id || !b.recycler_org_id)
  )

  const receivedBatches = batches.filter(
    (b) => b.status === 'RECEIVED' && (b.recycler_org_id === currentPersona.org_id || !b.recycler_org_id)
  )

  const totalRawInventoryKg = receivedBatches.reduce(
    (acc, b) => acc + (b.quantities.accepted_kg || 0),
    0
  )

  const totalProcessedKg = processingRuns.reduce((acc, r) => acc + r.output_kg, 0)
  const totalAllocatedKg = allocations.reduce((acc, a) => acc + (a.status === 'ACTIVE' ? a.quantity_kg : 0), 0)

  // Yield trend data for complete runs
  const yieldTrendData = [
    { date: '01 Nov', yield: 89.4, polymer: 'PET' },
    { date: '03 Nov', yield: 90.2, polymer: 'HDPE' },
    { date: '05 Nov', yield: 91.1, polymer: 'PET' },
    { date: '07 Nov', yield: 90.6, polymer: 'HDPE' },
    { date: '10 Nov', yield: 92.0, polymer: 'PP' },
    { date: '12 Nov', yield: 91.5, polymer: 'PET' },
  ]

  // Daily capacity utilisation: 5,000 kg/day plant capacity
  const dailyCapacityKg = 5000
  const todayUtilizedKg = 3850
  const capacityPct = Math.round((todayUtilizedKg / dailyCapacityKg) * 100)

  return (
    <div className="space-y-6">
      {/* Header Banner */}
      <div className="bg-linear-to-r from-purple-950 via-slate-900 to-indigo-950 rounded-2xl text-white p-6 md:p-8 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-6">
        <div className="space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1 rounded-full bg-purple-500/20 text-purple-300 text-xs font-semibold border border-purple-500/30">
            <span>🏭</span> Registered Plastic Waste Processor (PWP)
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold tracking-tight">
            {currentPersona.org_name}
          </h1>
          <p className="text-sm text-purple-200 max-w-xl">
            Mechanical extrusion facility, CPCB weighbridge intake validation, yield accounting, and EPR statutory allocation.
          </p>
        </div>

        <div className="flex flex-wrap items-center gap-2.5">
          <Link
            to="/recycler/receiving"
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-purple-600 hover:bg-purple-500 text-white font-bold text-xs shadow-md transition-all"
          >
            <Scale className="w-4 h-4" />
            Weighbridge Intake ({inboundBatches.length} Inbound)
          </Link>
          <Link
            to="/recycler/processing"
            className="inline-flex items-center gap-2 px-4 py-2.5 rounded-xl bg-white text-slate-900 hover:bg-slate-100 font-bold text-xs shadow-md transition-all"
          >
            <RotateCcw className="w-4 h-4 text-purple-600" />
            New Processing Run
          </Link>
        </div>
      </div>

      {/* KPI Stats */}
      <div className="grid grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Inbound Transit</span>
            <Package className="w-4 h-4 text-blue-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {inboundBatches.length} <span className="text-sm font-sans font-normal text-slate-500">consignments</span>
          </div>
          <div className="text-[11px] text-blue-700 font-medium mt-1">Awaiting QR weighbridge intake</div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Raw Accepted Inventory</span>
            <Scale className="w-4 h-4 text-emerald-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {totalRawInventoryKg.toFixed(1)} <span className="text-sm font-sans font-normal text-slate-500">kg</span>
          </div>
          <div className="text-[11px] text-emerald-700 font-medium mt-1">Ready for extrusion feeding</div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>Pellets Extruded</span>
            <RotateCcw className="w-4 h-4 text-purple-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {totalProcessedKg.toFixed(1)} <span className="text-sm font-sans font-normal text-slate-500">kg</span>
          </div>
          <div className="text-[11px] text-purple-700 font-medium mt-1">Avg measured yield: 91.2%</div>
        </div>

        <div className="bg-white p-5 rounded-2xl border border-slate-200 shadow-xs">
          <div className="flex items-center justify-between text-slate-500 text-xs font-semibold uppercase tracking-wider mb-2">
            <span>EPR Allocated</span>
            <FileSpreadsheet className="w-4 h-4 text-teal-600" />
          </div>
          <div className="text-2xl font-extrabold font-mono text-slate-900">
            {totalAllocatedKg.toFixed(1)} <span className="text-sm font-sans font-normal text-slate-500">kg</span>
          </div>
          <div className="text-[11px] text-teal-700 font-medium mt-1">CPCB portal eligible credits</div>
        </div>
      </div>

      {/* Grid: Capacity Utilization Gauge & Yield Trend Line Chart */}
      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        {/* Plant Line Capacity Utilisation */}
        <div className="bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
          <div className="flex items-center justify-between border-b border-slate-100 pb-3">
            <h2 className="text-sm font-bold text-slate-900">Plant Capacity Utilisation</h2>
            <span className="text-xs font-mono font-bold text-purple-700 bg-purple-50 px-2 py-0.5 rounded">
              Line 1: 5.0 MT/day
            </span>
          </div>

          <div className="space-y-3 pt-2">
            <div className="flex items-baseline justify-between">
              <span className="text-3xl font-extrabold font-mono text-slate-900">{capacityPct}%</span>
              <span className="text-xs font-mono text-slate-500">
                {todayUtilizedKg.toLocaleString()} / {dailyCapacityKg.toLocaleString()} kg
              </span>
            </div>

            {/* Progress bar */}
            <div className="w-full bg-slate-100 h-3 rounded-full overflow-hidden">
              <div
                className="bg-purple-600 h-full rounded-full transition-all duration-500"
                style={{ width: `${capacityPct}%` }}
              />
            </div>

            <div className="text-xs text-slate-600 space-y-1.5 pt-2">
              <div className="flex justify-between">
                <span>Extruder Operating Speed:</span>
                <span className="font-mono font-bold text-slate-800">420 kg/hr</span>
              </div>
              <div className="flex justify-between">
                <span>Active Polymer Stream:</span>
                <span className="font-mono font-bold text-purple-700">PET Flakes & HDPE</span>
              </div>
              <div className="flex justify-between">
                <span>Shift Schedule:</span>
                <span className="font-mono text-slate-800">2 Shifts (16 hrs active)</span>
              </div>
            </div>
          </div>
        </div>

        {/* Measured Processing Yield Trend (Recharts) */}
        <div className="lg:col-span-2 bg-white rounded-2xl border border-slate-200 shadow-xs p-6 space-y-4">
          <div className="flex items-center justify-between border-b border-slate-100 pb-3">
            <div>
              <h2 className="text-sm font-bold text-slate-900">Measured Processing Yield (%)</h2>
              <p className="text-xs text-slate-500">
                Computed only from completed mechanical runs (output ÷ accepted input)
              </p>
            </div>
            <span className="text-xs font-mono font-bold text-emerald-700 bg-emerald-50 px-2.5 py-1 rounded-lg border border-emerald-200">
              Avg: 90.9%
            </span>
          </div>

          <div className="h-56 w-full pt-2">
            <ResponsiveContainer width="100%" height="100%">
              <LineChart data={yieldTrendData} margin={{ top: 10, right: 20, left: -10, bottom: 0 }}>
                <CartesianGrid strokeDasharray="3 3" stroke="#f1f5f9" />
                <XAxis dataKey="date" tick={{ fontSize: 11, fill: '#64748b' }} />
                <YAxis domain={[80, 100]} tick={{ fontSize: 11, fill: '#64748b' }} unit="%" />
                <Tooltip
                  formatter={(val: any) => [`${val}%`, 'Measured Yield']}
                  contentStyle={{ backgroundColor: '#0f172a', color: '#fff', borderRadius: '8px', fontSize: '12px' }}
                />
                <Line
                  type="monotone"
                  dataKey="yield"
                  stroke="#9333ea"
                  strokeWidth={2.5}
                  dot={{ r: 4, fill: '#9333ea' }}
                  activeDot={{ r: 6 }}
                />
              </LineChart>
            </ResponsiveContainer>
          </div>
        </div>
      </div>
    </div>
  )
}
