import { q } from '@/lib/quantities'
import type { Batch } from '@/types/api'

/** Collected weight recorded by the collector but not yet confirmed by the generator's OTP. */
export const awaitingConfirmation = (b: Batch) => b.status === 'ASSIGNED' && q(b.quantities.collected_kg) != null
