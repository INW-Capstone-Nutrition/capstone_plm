import { useQuery } from '@tanstack/react-query'
import { motion } from 'motion/react'
import { ArrowRight, Boxes, CircleAlert, Clock3, FileCheck2, FlaskConical, PackageOpen, Plus, TrendingUp } from 'lucide-react'
import { Link } from 'react-router-dom'
import { api } from '@/lib/api'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader } from '@/components/ui/card'

const metrics = [
  { key: 'active_formulas', label: 'Active formulas', icon: FlaskConical, note: '+8 this month', tone: 'orange' },
  { key: 'in_review', label: 'Awaiting review', icon: Clock3, note: '4 due today', tone: 'amber' },
  { key: 'development', label: 'In development', icon: Boxes, note: 'Across 3 branches', tone: 'blue' },
  { key: 'material_alerts', label: 'Material alerts', icon: CircleAlert, note: 'Needs attention', tone: 'red' },
] as const

export function DashboardPage() {
  const { data, error, isPending } = useQuery({ queryKey: ['dashboard'], queryFn: api.dashboard, retry: 1 })
  if (isPending) return <p className="text-sm text-slate-500">Loading PLM data…</p>
  if (error || !data) return <p className="text-sm font-semibold text-red-600" role="alert">Unable to load PLM_DEV data: {error instanceof Error ? error.message : 'No response from the API'}</p>
  const totalWorkflow = Object.values(data.workflow_counts).reduce((sum, value) => sum + value, 0) || 1
  return <div className="space-y-6">
    <div className="flex flex-col justify-between gap-4 sm:flex-row sm:items-end">
      <div><p className="max-w-xl text-sm leading-6 text-slate-500">Here’s what’s happening across formulations, reviews, and raw materials today.</p></div>
      <div className="flex gap-2"><Button variant="secondary" asChild><Link to="/materials"><PackageOpen className="size-4" /> Find material</Link></Button><Button asChild><Link to="/formulas"><Plus className="size-4" /> New formula</Link></Button></div>
    </div>

    <div className="grid gap-4 sm:grid-cols-2 xl:grid-cols-4">
      {metrics.map((metric, index) => { const Icon = metric.icon; const value = data[metric.key]; return <motion.div key={metric.key} initial={{ opacity: 0, y: 12 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: index * .055 }}><Card className="group overflow-hidden"><CardContent className="relative p-5"><div className="absolute inset-x-0 top-0 h-[2px] bg-gradient-to-r from-[#e57b3a] to-transparent opacity-0 transition group-hover:opacity-100" /><div className="flex items-start justify-between"><div><p className="text-xs font-semibold text-slate-500">{metric.label}</p><p className="mt-2 text-[30px] font-extrabold leading-none tracking-[-.04em] text-[#1b2926]">{value}</p></div><div className="grid size-10 place-items-center rounded-xl bg-[#f1f3ef] text-[#53645f]"><Icon className="size-[18px]" /></div></div><p className="mt-4 flex items-center gap-1.5 text-[11px] font-semibold text-slate-400"><TrendingUp className="size-3 text-emerald-500" />{metric.note}</p></CardContent></Card></motion.div> })}
    </div>

    <div className="grid gap-5 xl:grid-cols-[1.55fr_.75fr]">
      <Card className="overflow-hidden">
        <CardHeader><div><h2 className="text-sm font-extrabold text-[#1b2926]">Recent formulas</h2><p className="mt-1 text-xs text-slate-400">Latest activity across your branches</p></div><Button variant="ghost" size="sm" asChild><Link to="/formulas">View all <ArrowRight className="size-3.5" /></Link></Button></CardHeader>
        <CardContent className="px-0 pb-0"><div className="overflow-x-auto"><table className="w-full min-w-[680px] text-left"><thead><tr className="border-y border-slate-100 bg-[#fafbf8] text-[10px] font-bold uppercase tracking-[.1em] text-slate-400"><th className="px-5 py-3">Formula</th><th className="px-4 py-3">Customer</th><th className="px-4 py-3">Rev</th><th className="px-4 py-3">Branch</th><th className="px-5 py-3">Status</th></tr></thead><tbody>{data.recent_formulas.map((formula) => <tr key={formula.id} className="border-b border-slate-100 last:border-0 hover:bg-orange-50/30"><td className="px-5 py-4"><p className="text-[13px] font-bold text-slate-800">{formula.name}</p><p className="mt-0.5 font-mono text-[10px] text-slate-400">{formula.parent_item_number} · {formula.latest_revision.blend_item_number}</p></td><td className="px-4 py-4 text-xs text-slate-600">{formula.latest_revision.customer_name ?? '—'}</td><td className="px-4 py-4 text-xs font-bold text-slate-700">{formula.latest_revision.revision_label}</td><td className="px-4 py-4"><span className="rounded bg-slate-100 px-2 py-1 font-mono text-[10px] font-bold text-slate-600">BP{formula.latest_revision.branch_code}</span></td><td className="px-5 py-4"><Badge value={formula.latest_revision.workflow_status} /></td></tr>)}</tbody></table></div></CardContent>
      </Card>

      <div className="space-y-5">
        <Card><CardHeader><div><h2 className="text-sm font-extrabold text-[#1b2926]">Workflow pulse</h2><p className="mt-1 text-xs text-slate-400">Formula lifecycle distribution</p></div><FileCheck2 className="size-4 text-slate-400" /></CardHeader><CardContent><div className="mb-5 flex h-3 overflow-hidden rounded-full bg-slate-100">{Object.entries(data.workflow_counts).map(([label, value], i) => <motion.div key={label} initial={{ width: 0 }} animate={{ width: `${value / totalWorkflow * 100}%` }} transition={{ delay: .25, duration: .7 }} className={['bg-emerald-500','bg-amber-400','bg-blue-500','bg-violet-500'][i % 4]} />)}</div><div className="grid grid-cols-2 gap-3">{Object.entries(data.workflow_counts).map(([label, value], i) => <div key={label} className="flex items-center gap-2 text-xs"><span className={['bg-emerald-500','bg-amber-400','bg-blue-500','bg-violet-500'][i % 4] + ' size-2 rounded-full'} /><span className="text-slate-500">{label}</span><strong className="ml-auto text-slate-800">{value}</strong></div>)}</div></CardContent></Card>
        <Card className="border-0 bg-[#1d2926] text-white"><CardContent><div className="flex items-start justify-between"><div><p className="text-[10px] font-bold uppercase tracking-[.14em] text-[#91a29d]">Material library</p><p className="mt-2 text-3xl font-extrabold tracking-tight">{data.total_materials.toLocaleString()}</p><p className="mt-1 text-xs text-[#91a29d]">branch-qualified items</p></div><div className="grid size-10 place-items-center rounded-xl bg-white/10"><PackageOpen className="size-5 text-[#f39a61]" /></div></div><Button variant="secondary" size="sm" className="mt-5 border-white/10 bg-white/10 text-white hover:bg-white/15" asChild><Link to="/materials">Open catalog <ArrowRight className="size-3.5" /></Link></Button></CardContent></Card>
      </div>
    </div>
  </div>
}
