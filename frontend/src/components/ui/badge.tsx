import { cn } from '@/lib/utils'

const styles: Record<string, string> = {
  Active: 'bg-emerald-50 text-emerald-700 ring-emerald-600/15',
  Review: 'bg-amber-50 text-amber-700 ring-amber-600/15',
  Development: 'bg-blue-50 text-blue-700 ring-blue-600/15',
  Quote: 'bg-violet-50 text-violet-700 ring-violet-600/15',
  default: 'bg-slate-100 text-slate-700 ring-slate-500/15',
}

export function Badge({ value, className }: { value: string; className?: string }) {
  return <span className={cn('inline-flex items-center rounded-full px-2.5 py-1 text-[11px] font-bold ring-1 ring-inset', styles[value] ?? styles.default, className)}>{value}</span>
}

