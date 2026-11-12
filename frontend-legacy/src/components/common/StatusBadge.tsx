import React from 'react'
import type { BatchStatus } from '../../types'

interface StatusBadgeProps {
  status: BatchStatus | string
  type?: 'batch' | 'verification' | 'allocation' | 'severity'
  size?: 'sm' | 'md'
}

export const StatusBadge: React.FC<StatusBadgeProps> = ({
  status,
  type = 'batch',
  size = 'md',
}) => {
  let colorStyles = 'bg-slate-100 text-slate-700 border-slate-200'
  let label = status

  const upper = String(status).toUpperCase()

  if (type === 'verification') {
    switch (upper) {
      case 'VERIFIED':
        colorStyles = 'bg-emerald-50 text-emerald-800 border-emerald-300'
        label = 'Verified'
        break
      case 'UNDER_REVIEW':
        colorStyles = 'bg-blue-50 text-blue-800 border-blue-300'
        label = 'Under Review'
        break
      case 'PENDING':
        colorStyles = 'bg-amber-50 text-amber-800 border-amber-300'
        label = 'Pending Audit'
        break
      case 'REQUIRES_CORRECTION':
        colorStyles = 'bg-orange-50 text-orange-800 border-orange-300'
        label = 'Needs Correction'
        break
      case 'FLAGGED':
        colorStyles = 'bg-rose-50 text-rose-800 border-rose-300'
        label = 'Flagged'
        break
      case 'REJECTED':
        colorStyles = 'bg-red-50 text-red-800 border-red-300'
        label = 'Rejected'
        break
    }
  } else if (type === 'severity') {
    switch (upper) {
      case 'CRITICAL':
        colorStyles = 'bg-red-100 text-red-900 border-red-300'
        break
      case 'HIGH':
        colorStyles = 'bg-rose-100 text-rose-800 border-rose-300'
        break
      case 'MEDIUM':
        colorStyles = 'bg-amber-100 text-amber-800 border-amber-300'
        break
      case 'LOW':
        colorStyles = 'bg-blue-50 text-blue-700 border-blue-200'
        break
    }
  } else {
    // Default Batch Status
    switch (upper) {
      case 'LISTED':
        colorStyles = 'bg-sky-50 text-sky-800 border-sky-300'
        label = 'Listed'
        break
      case 'ASSIGNED':
        colorStyles = 'bg-blue-50 text-blue-800 border-blue-300'
        label = 'Collector Assigned'
        break
      case 'PICKED_UP':
        colorStyles = 'bg-indigo-50 text-indigo-800 border-indigo-300'
        label = 'Picked Up'
        break
      case 'IN_TRANSIT':
        colorStyles = 'bg-purple-50 text-purple-800 border-purple-300'
        label = 'In Transit'
        break
      case 'RECEIVED':
        colorStyles = 'bg-teal-50 text-teal-800 border-teal-300'
        label = 'Received at Plant'
        break
      case 'PROCESSED':
        colorStyles = 'bg-emerald-50 text-emerald-800 border-emerald-300'
        label = 'Processed'
        break
      case 'REJECTED_AT_RECEIPT':
        colorStyles = 'bg-rose-50 text-rose-800 border-rose-300'
        label = 'Rejected at Weighbridge'
        break
      case 'CANCELLED':
        colorStyles = 'bg-slate-100 text-slate-600 border-slate-300'
        label = 'Cancelled'
        break
      case 'ACTIVE':
        colorStyles = 'bg-emerald-50 text-emerald-800 border-emerald-300'
        label = 'Active'
        break
      case 'REVERSED':
        colorStyles = 'bg-rose-50 text-rose-800 border-rose-300'
        label = 'Reversed'
        break
    }
  }

  const sizeStyles = size === 'sm' ? 'px-2 py-0.5 text-[11px]' : 'px-2.5 py-1 text-xs font-medium'

  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border ${sizeStyles} ${colorStyles} font-sans`}
    >
      <span className="w-1.5 h-1.5 rounded-full bg-current opacity-80" />
      {label}
    </span>
  )
}
