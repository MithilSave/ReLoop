import React, { useState } from 'react'
import { useNavigate } from 'react-router-dom'
import { useApp } from '../../context/AppContext'
import { DEMO_PERSONAS } from '../../context/demoData'
import { Recycle, Lock, Mail, ArrowRight } from 'lucide-react'

export const LoginPage: React.FC = () => {
  const navigate = useNavigate()
  const { setPersona } = useApp()

  const [email, setEmail] = useState('rajesh@greensociety.in')
  const [password, setPassword] = useState('reloop123')

  const handleStandardLogin = (e: React.FormEvent) => {
    e.preventDefault()
    // Match by email or default to generator
    const matched = DEMO_PERSONAS.find((p) => p.email.toLowerCase() === email.toLowerCase())
    if (matched) {
      setPersona(matched.id)
      redirectToRole(matched.role)
    } else {
      setPersona('persona-gen')
      navigate('/generator')
    }
  }

  const handleQuickPersonaSelect = (personaId: string, role: string) => {
    setPersona(personaId)
    redirectToRole(role)
  }

  const redirectToRole = (role: string) => {
    switch (role) {
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
      default:
        navigate('/')
    }
  }

  return (
    <div className="min-h-screen bg-slate-50 flex flex-col justify-center py-12 sm:px-6 lg:px-8 font-sans antialiased">
      <div className="sm:mx-auto sm:w-full sm:max-w-md text-center">
        <div className="w-12 h-12 rounded-2xl bg-emerald-600 text-white flex items-center justify-center mx-auto shadow-md mb-3">
          <Recycle className="w-7 h-7" />
        </div>
        <h1 className="text-2xl font-extrabold text-slate-900 tracking-tight">
          Welcome to ReLoop
        </h1>
        <p className="text-xs text-slate-500 mt-1 max-w-sm mx-auto">
          Circular plastic waste marketplace & six-stage traceability ledger under CPCB EPR Rules
        </p>
      </div>

      <div className="mt-8 sm:mx-auto sm:w-full sm:max-w-xl px-4">
        <div className="bg-white py-8 px-6 sm:px-10 rounded-3xl border border-slate-200/80 shadow-lg space-y-6">
          {/* Quick One-Click Demo Persona Picker */}
          <div className="space-y-3">
            <div className="flex items-center justify-between border-b border-slate-100 pb-2">
              <h2 className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Instant Demo Personas (1-Click Login)
              </h2>
              <span className="text-[10px] font-mono font-bold text-emerald-800 bg-emerald-100 px-2 py-0.5 rounded-full">
                Interactive Multi-Role
              </span>
            </div>

            <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
              {DEMO_PERSONAS.map((p) => (
                <button
                  key={p.id}
                  type="button"
                  onClick={() => handleQuickPersonaSelect(p.id, p.role)}
                  className="p-3 rounded-2xl border border-slate-200 hover:border-emerald-500 hover:bg-emerald-50/50 transition-all text-left flex items-start gap-2.5 cursor-pointer group shadow-2xs"
                >
                  <span className="text-2xl mt-0.5 group-hover:scale-110 transition-transform">
                    {p.avatar}
                  </span>
                  <div className="flex-1 min-w-0">
                    <div className="flex items-center justify-between">
                      <span className="font-bold text-xs text-slate-900 truncate">
                        {p.name}
                      </span>
                      <ArrowRight className="w-3.5 h-3.5 text-slate-400 group-hover:text-emerald-600 group-hover:translate-x-0.5 transition-all" />
                    </div>
                    <div className="text-[11px] font-medium text-emerald-700 truncate">
                      {p.org_type_label}
                    </div>
                    <div className="text-[10px] text-slate-400 truncate mt-0.5">
                      {p.org_name}
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>

          <div className="relative flex py-1 items-center">
            <div className="grow border-t border-slate-200"></div>
            <span className="shrink mx-4 text-[11px] uppercase tracking-wider text-slate-400 font-bold">
              Or Sign In with Credentials
            </span>
            <div className="grow border-t border-slate-200"></div>
          </div>

          {/* Standard Form */}
          <form onSubmit={handleStandardLogin} className="space-y-4">
            <div className="space-y-1">
              <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                Email Address
              </label>
              <div className="relative">
                <Mail className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                <input
                  type="email"
                  value={email}
                  onChange={(e) => setEmail(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 rounded-xl border border-slate-300 text-xs focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
                  placeholder="e.g. rajesh@greensociety.in"
                  required
                />
              </div>
            </div>

            <div className="space-y-1">
              <div className="flex items-center justify-between">
                <label className="text-xs font-bold uppercase tracking-wider text-slate-700">
                  Password
                </label>
                <span className="text-[10px] text-slate-400 font-mono">Demo: reloop123</span>
              </div>
              <div className="relative">
                <Lock className="w-4 h-4 text-slate-400 absolute left-3 top-3" />
                <input
                  type="password"
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full pl-9 pr-3 py-2 rounded-xl border border-slate-300 text-xs focus:ring-2 focus:ring-emerald-500 focus:outline-hidden"
                  required
                />
              </div>
            </div>

            <button
              type="submit"
              className="w-full py-2.5 rounded-xl bg-emerald-600 hover:bg-emerald-700 text-white text-xs font-bold shadow-md transition-all cursor-pointer"
            >
              Log In to Portal
            </button>
          </form>
        </div>
      </div>
    </div>
  )
}
