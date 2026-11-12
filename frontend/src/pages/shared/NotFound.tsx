import { Link } from 'react-router-dom'
import { Button } from '@/components/ui/button'
export function NotFound() {
  return (
    <div className="mx-auto flex max-w-md flex-col items-center py-20 text-center">
      <h1 className="text-lg font-semibold">Page not found</h1>
      <p className="mt-1 text-sm text-fg-2">The address does not match any screen in ReLoop.</p>
      <Button asChild className="mt-4"><Link to="/">Go to my workspace</Link></Button>
    </div>
  )
}
