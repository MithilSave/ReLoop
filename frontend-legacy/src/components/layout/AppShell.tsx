import React, { useState } from 'react'
import { Link, useLocation, useNavigate } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import { DEMO_PERSONAS } from '../../context/demoData'
import {
  Recycle,
  LayoutDashboard,
  PlusCircle,
  Package,
  Truck,
  Building2,
  FileCheck,
  ShieldCheck,
  TrendingUp,
  FileSpreadsheet,
  AlertTriangle,
  RotateCcw,
  LogOut,
  ChevronDown,
  MapPin,
  Compass,
  DollarSign,
  Scale,
  Menu,
  X,
} from 'lucide-react'

export const AppShell: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const { currentPersona, setPersona, anomalies, resetDemoData } = useApp()
  const location = useLocation()
  const navigate = useNavigate()
  const [mobileMenuOpen, setMobileMenuOpen] = useState(false)
  const [personaDropdownOpen, setPersonaDropdownOpen] = useState(false)

  const openAnomaliesCount = anomalies.filter((a) => a.status === 'OPEN').length

  const handlePersonaSwitch = (pId: string) => {
    setPersona(pId)
    setPersonaDropdownOpen(false)
    const targetPersona = DEMO_PERSONAS.find((p) => p.id === pId)
    if (targetPersona) {
      switch (targetPersona.role) {
        case 'generator':
          navigate('/generator')
          break
        case 'collector':
          navigate('/collector')
          break
        case 'recycler':
          navigate('/recycler')
          break
        case 'ngo':
          navigate('/ngo')
          break
        case 'epr_body':
          navigate('/epr')
          break
        case 'admin':
          navigate('/admin')
          break
      }
    }
  }

  // Define sidebar links dynamically by active role
  const getNavLinks = () => {
    switch (currentPersona.role) {
      case 'generator':
        return [
          { to: '/generator', label: 'Overview', icon: LayoutDashboard },
          { to: '/generator/batches', label: 'My Plastic Batches', icon: Package },
          { to: '/generator/create', label: 'List Plastic (AI)', icon: PlusCircle },
          { to: '/generator/offers', label: 'Collector Offers', icon: DollarSign },
        ]
      case 'collector':
        return [
          { to: '/collector', label: 'Today\'s Jobs', icon: LayoutDashboard },
          { to: '/collector/available', label: 'Available Listings', icon: Compass },
          { to: '/collector/pickups', label: 'Active Pickups & OTP', icon: Truck },
          { to: '/collector/consignments', label: 'Consignment Builder', icon: Package },
        ]
      case 'recycler':
        return [
          { to: '/recycler', label: 'Plant Overview', icon: LayoutDashboard },
          { to: '/recycler/receiving', label: 'Inbound Weighbridge', icon: Scale },
          { to: '/recycler/processing', label: 'Processing & Yield', icon: RotateCcw },
          { to: '/recycler/sourcing', label: 'Smart Aggregation', icon: Compass },
          { to: '/recycler/costing', label: 'Landed Cost Analysis', icon: TrendingUp },
          { to: '/recycler/allocations', label: 'EPR Allocation Ledger', icon: FileSpreadsheet },
        ]
      case 'ngo':
        return [
          { to: '/ngo', label: 'Verification Queue', icon: ShieldCheck },
          { to: '/ngo/reports', label: 'Impact & Audit Dossiers', icon: FileCheck },
        ]
      case 'epr_body':
        return [
          { to: '/epr', label: 'Compliance Overview', icon: LayoutDashboard },
          { to: '/epr/allocations', label: 'Traceability Ledger', icon: FileSpreadsheet },
          { to: '/epr/discrepancies', label: 'Discrepancy Alerts', icon: AlertTriangle },
        ]
      case 'admin':
        return [
          { to: '/admin', label: 'Platform Health', icon: LayoutDashboard },
          { to: '/admin/orgs', label: 'KYB Approvals', icon: Building2 },
          { to: '/admin/anomalies', label: 'Anomaly Monitor', icon: AlertTriangle },
        ]
      default:
        return []
    }
  }

  const navLinks = getNavLinks()

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col font-sans text-slate-800 antialiased selection:bg-emerald-500 selection:text-white">
      {/* ── Top Navigation Bar ──────────────────────────────────── */}
      <header className="sticky top-0 z-40 bg-white border-b border-slate-200/80 shadow-xs backdrop-blur-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 h-16 flex items-center justify-between gap-4">
          {/* Logo & Mobile Menu Toggle */}
          <div className="flex items-center gap-3">
            <button
              onClick={() => setMobileMenuOpen(!mobileMenuOpen)}
              className="md:hidden p-1.5 rounded-lg text-slate-600 hover:bg-slate-100"
              aria-label="Toggle Navigation"
            >
              {mobileMenuOpen ? <X className="w-5 h-5" /> : <Menu className="w-5 h-5" />}
            </button>
            <Link to="/" className="flex items-center gap-2 group">
              <div className="w-9 h-9 rounded-xl bg-emerald-600 flex items-center justify-center text-white shadow-xs group-hover:bg-emerald-500 transition-colors">
                <Recycle className="w-5 h-5" />
              </div>
              <div className="flex flex-col">
                <span className="font-extrabold text-slate-900 tracking-tight text-lg leading-tight flex items-center gap-1.5">
                  ReLoop
                  <span className="text-[10px] uppercase font-bold tracking-wider px-1.5 py-0.2 bg-emerald-100 text-emerald-800 rounded">
                    MVP
                  </span>
                </span>
                <span className="text-[11px] text-slate-500 font-medium">
                  Traceability & Aggregation
                </span>
              </div>
            </Link>
          </div>

          {/* Quick Persona Switcher (Signature ReLoop Feature) */}
          <div className="relative">
            <div className="flex items-center gap-2">
              <span className="hidden lg:inline text-xs font-semibold uppercase tracking-wider text-slate-600">
                Persona:
              </span>
              <button
                onClick={() => setPersonaDropdownOpen(!personaDropdownOpen)}
                className="flex items-center gap-2.5 px-3 py-1.5 rounded-xl border border-slate-300 bg-white hover:bg-slate-50 shadow-xs transition-all text-left"
              >
                <span className="text-lg leading-none">{currentPersona.avatar}</span>
                <div className="hidden sm:block">
                  <div className="text-xs font-bold text-slate-900 flex items-center gap-1.5">
                    {currentPersona.name}
                    <span className={`text-[10px] px-1.5 py-0.5 rounded border font-medium ${currentPersona.badge_color}`}>
                      {currentPersona.org_type_label}
                    </span>
                  </div>
                  <div className="text-[11px] text-slate-500 truncate max-w-[180px]">
                    {currentPersona.org_name}
                  </div>
                </div>
                <ChevronDown className="w-4 h-4 text-slate-400" />
              </button>
            </div>

            {/* Persona Switcher Dropdown Menu */}
            {personaDropdownOpen && (
              <div className="absolute right-0 mt-2 w-80 sm:w-96 bg-white rounded-2xl shadow-xl border border-slate-200 p-2 z-50 animate-in fade-in zoom-in-95 duration-100">
                <div className="px-3 py-2 border-b border-slate-100 mb-1">
                  <div className="text-xs font-bold uppercase tracking-wider text-slate-700">
                    Switch Live Demo Persona
                  </div>
                  <p className="text-[11px] text-slate-500">
                    Test the complete closed-loop lifecycle across all 5 participant types
                  </p>
                </div>
                <div className="space-y-1 max-h-96 overflow-y-auto">
                  {DEMO_PERSONAS.map((p) => {
                    const isSelected = p.id === currentPersona.id
                    return (
                      <button
                        key={p.id}
                        onClick={() => handlePersonaSwitch(p.id)}
                        className={`w-full text-left p-2.5 rounded-xl flex items-start gap-3 transition-colors ${
                          isSelected
                            ? 'bg-emerald-50/80 border border-emerald-300 text-emerald-950'
                            : 'hover:bg-slate-50 border border-transparent'
                        }`}
                      >
                        <span className="text-2xl mt-0.5">{p.avatar}</span>
                        <div className="flex-1 min-w-0">
                          <div className="flex items-center justify-between gap-1">
                            <span className="text-xs font-bold text-slate-900 truncate">
                              {p.name}
                            </span>
                            <span className={`text-[10px] px-1.5 py-0.2 rounded border font-medium shrink-0 ${p.badge_color}`}>
                              {p.org_type_label}
                            </span>
                          </div>
                          <div className="text-xs text-slate-600 font-medium truncate">
                            {p.org_name}
                          </div>
                          <div className="text-[11px] text-slate-500 line-clamp-1 mt-0.5">
                            {p.description}
                          </div>
                        </div>
                      </button>
                    )
                  })}
                </div>
              </div>
            )}
          </div>

          {/* Action icons & Public links */}
          <div className="flex items-center gap-2">
            {/* Public Passport Lookup Shortcut */}
            <Link
              to="/b/RL-MUM-2026-000123"
              className="hidden md:inline-flex items-center gap-1.5 px-3 py-1.5 rounded-lg text-xs font-medium text-slate-600 hover:text-slate-900 hover:bg-slate-100 transition-colors"
              title="Inspect Digital Product Passport"
            >
              <FileSpreadsheet className="w-3.5 h-3.5 text-emerald-600" />
              <span>Sample Passport</span>
            </Link>

            {/* Anomaly / Alert Bell */}
            <Link
              to={currentPersona.role === 'admin' ? '/admin/anomalies' : '/epr/discrepancies'}
              className="relative p-2 rounded-xl text-slate-600 hover:bg-slate-100 hover:text-slate-900 transition-colors"
              title="System Anomaly Flags"
            >
              <AlertTriangle className="w-5 h-5 text-slate-600" />
              {openAnomaliesCount > 0 && (
                <span className="absolute top-1 right-1 w-4 h-4 rounded-full bg-rose-500 text-white font-mono text-[10px] font-bold flex items-center justify-center">
                  {openAnomaliesCount}
                </span>
              )}
            </Link>

            {/* Reset Demo Data */}
            <button
              onClick={() => {
                if (confirm('Reset all demo batches, offers, and runs to initial state?')) {
                  resetDemoData()
                }
              }}
              className="p-2 rounded-xl text-slate-500 hover:bg-slate-100 hover:text-slate-800 transition-colors"
              title="Reset Demo State"
            >
              <RotateCcw className="w-4 h-4" />
            </button>

            {/* Auth / Logout Link */}
            <Link
              to="/auth/login"
              className="p-2 rounded-xl text-slate-500 hover:bg-slate-100 hover:text-slate-800 transition-colors"
              title="Login Page"
            >
              <LogOut className="w-4 h-4" />
            </Link>
          </div>
        </div>
      </header>

      {/* ── Body Container with Sidebar ────────────────────────── */}
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 w-full flex-1 flex flex-col md:flex-row py-6 gap-6">
        {/* Desktop Sidebar */}
        <aside className="hidden md:block w-60 shrink-0">
          <div className="sticky top-24 bg-white rounded-2xl border border-slate-200/80 p-3 shadow-xs space-y-1">
            <div className="px-3 py-2 text-[11px] font-bold uppercase tracking-wider text-slate-600 border-b border-slate-100 mb-2">
              {currentPersona.org_type_label} Nav
            </div>
            {navLinks.map((link) => {
              const Icon = link.icon
              const isActive = location.pathname === link.to
              return (
                <Link
                  key={link.to}
                  to={link.to}
                  className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-xs font-semibold transition-all ${
                    isActive
                      ? 'bg-emerald-600 text-white shadow-xs'
                      : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
                  }`}
                >
                  <Icon className={`w-4 h-4 ${isActive ? 'text-white' : 'text-slate-600'}`} />
                  <span>{link.label}</span>
                </Link>
              )
            })}

            {/* Persona Quick Card in Sidebar */}
            <div className="pt-4 mt-4 border-t border-slate-100 px-3">
              <div className="text-[11px] text-slate-600 font-medium">Logged in Org</div>
              <div className="text-xs font-bold text-slate-800 truncate mt-0.5">
                {currentPersona.org_name}
              </div>
              <div className="text-[10px] text-slate-600 mt-0.5 flex items-center gap-1 font-mono">
                <MapPin className="w-3 h-3 text-slate-400" /> Mumbai, India
              </div>
            </div>
          </div>
        </aside>

        {/* Mobile Navigation Drawer */}
        {mobileMenuOpen && (
          <div className="md:hidden bg-white rounded-2xl border border-slate-200 p-4 shadow-lg mb-4 space-y-1 animate-in slide-in-from-top-2">
            <div className="text-xs font-bold uppercase tracking-wider text-slate-400 mb-2">
              Navigation Menu
            </div>
            {navLinks.map((link) => {
              const Icon = link.icon
              const isActive = location.pathname === link.to
              return (
                <Link
                  key={link.to}
                  to={link.to}
                  onClick={() => setMobileMenuOpen(false)}
                  className={`flex items-center gap-3 px-3 py-2.5 rounded-xl text-sm font-semibold transition-colors ${
                    isActive
                      ? 'bg-emerald-600 text-white shadow-xs'
                      : 'text-slate-600 hover:bg-slate-100 hover:text-slate-900'
                  }`}
                >
                  <Icon className="w-4 h-4" />
                  <span>{link.label}</span>
                </Link>
              )
            })}
          </div>
        )}

        {/* Main Content Viewport */}
        <main className="flex-1 min-w-0">
          {children}
        </main>
      </div>

      {/* ── Footer ──────────────────────────────────────────────── */}
      <footer className="border-t border-slate-200 bg-white py-6 text-center text-xs text-slate-500">
        <div className="max-w-7xl mx-auto px-4 flex flex-col sm:flex-row items-center justify-between gap-3">
          <div className="flex items-center gap-2">
            <span className="font-bold text-slate-800">ReLoop Circular Platform</span>
            <span>•</span>
            <span>CPCB Packaging Plastic Compliance (EPR Rules 2022)</span>
          </div>
          <div className="flex items-center gap-4 text-[11px] text-slate-400 font-mono">
            <span>Six-Stage Quantity Guarantee</span>
            <span>•</span>
            <span>Zero Unverified Allocations</span>
          </div>
        </div>
      </footer>
    </div>
  )
}
