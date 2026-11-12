import { z } from 'zod'

/** <input type="datetime-local"> value ↔ ISO string (UTC) for the API. */
export const toLocalInput = (d: Date) => {
  const p = (n: number) => String(n).padStart(2, '0')
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}T${p(d.getHours())}:${p(d.getMinutes())}`
}
export const localToIso = (v: string) => new Date(v).toISOString()

/** Positive kilogram amount with up to 3 decimals, entered as text. */
export const kgField = (label = 'Quantity') =>
  z.string().trim().min(1, `Enter ${label.toLowerCase()} in kg`)
    .refine((v) => /^\d+(\.\d{1,3})?$/.test(v), 'Use a number with up to 3 decimals')
    .refine((v) => Number(v) > 0, 'Must be greater than 0')
export const kgFieldAllowZero = (label = 'Quantity') =>
  z.string().trim().min(1, `Enter ${label.toLowerCase()} in kg`)
    .refine((v) => /^\d+(\.\d{1,3})?$/.test(v), 'Use a number with up to 3 decimals')
