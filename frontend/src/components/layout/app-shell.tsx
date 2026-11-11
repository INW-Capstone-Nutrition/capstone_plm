import { AnimatePresence, motion } from 'motion/react'
import {
  Bell,
  BookOpenCheck,
  ChevronDown,
  ClipboardList,
  FlaskConical,
  Gauge,
  HelpCircle,
  Menu,
  PackageSearch,
  PanelLeftClose,
  Search,
  ShieldCheck,
  Sparkles,
  Users,
  X,
} from 'lucide-react'
import { useState } from 'react'
import { NavLink, Outlet, useLocation } from 'react-router-dom'
import { cn } from '@/lib/utils'

const navigation = [
  { label: 'Overview', to: '/', icon: Gauge },
  { label: 'Formulas', to: '/formulas', icon: FlaskConical },
  { label: 'Materials', to: '/materials', icon: PackageSearch },
  { label: 'Specifications', to: '/specifications', icon: BookOpenCheck },
  { label: 'Reports', to: '/reports', icon: ClipboardList },
]

function SidebarContent({ onNavigate }: { onNavigate?: () => void }) {
  return (
    <>
      <div className="flex h-[76px] items-center gap-3 border-b border-white/8 px-5">
        <div className="grid size-10 place-items-center rounded-xl bg-[#e57b3a] text-white shadow-lg shadow-orange-950/20">
          <FlaskConical className="size-5" strokeWidth={2.4} />
        </div>
        <div>
          <div className="text-[15px] font-extrabold tracking-tight text-white">Foundry PLM</div>
          <div className="mt-0.5 text-[10px] font-bold uppercase tracking-[.18em] text-[#91a29d]">Formulation OS</div>
        </div>
      </div>

      <nav className="flex-1 px-3 py-6">
        <p className="px-3 pb-2 text-[10px] font-bold uppercase tracking-[.18em] text-[#71837e]">Workspace</p>
        <div className="space-y-1">
          {navigation.map(({ label, to, icon: Icon }) => (
            <NavLink
              key={to}
              to={to}
              onClick={onNavigate}
              className={({ isActive }) => cn(
                'group flex items-center gap-3 rounded-lg px-3 py-2.5 text-[13px] font-semibold transition',
                isActive ? 'bg-white/10 text-white' : 'text-[#aebbb7] hover:bg-white/6 hover:text-white',
              )}
            >
              {({ isActive }) => <><Icon className={cn('size-[18px]', isActive ? 'text-[#f39a61]' : 'text-[#71837e] group-hover:text-[#aebbb7]')} /><span>{label}</span>{isActive && <motion.span layoutId="nav-dot" className="ml-auto size-1.5 rounded-full bg-[#e57b3a]" />}</>}
            </NavLink>
          ))}
        </div>
        <p className="mt-7 px-3 pb-2 text-[10px] font-bold uppercase tracking-[.18em] text-[#71837e]">Manage</p>
        <NavLink
          to="/administration"
          onClick={onNavigate}
          className={({ isActive }) => cn('flex items-center gap-3 rounded-lg px-3 py-2.5 text-[13px] font-semibold transition', isActive ? 'bg-white/10 text-white' : 'text-[#aebbb7] hover:bg-white/6 hover:text-white')}
        >
          <Users className="size-[18px] text-[#71837e]" /><span>Access control</span>
        </NavLink>
      </nav>

      <div className="m-3 rounded-xl border border-white/8 bg-white/[.045] p-3.5">
        <div className="flex items-center gap-2 text-xs font-bold text-white"><ShieldCheck className="size-4 text-emerald-400" /> JDE connection</div>
        <div className="mt-2 flex items-center gap-2 text-[11px] text-[#91a29d]"><span className="size-1.5 rounded-full bg-emerald-400 shadow-[0_0_0_3px_rgba(52,211,153,.12)]" /> Last sync 8 minutes ago</div>
      </div>
      <div className="flex items-center gap-3 border-t border-white/8 p-4">
        <div className="grid size-9 place-items-center rounded-full bg-[#f3dfcc] text-xs font-extrabold text-[#8a4a25]">AC</div>
        <div className="min-w-0 flex-1"><p className="truncate text-xs font-bold text-white">Alex Chen</p><p className="truncate text-[11px] text-[#71837e]">Formulation Lead</p></div>
        <ChevronDown className="size-4 text-[#71837e]" />
      </div>
    </>
  )
}

const pageMeta: Record<string, { eyebrow: string; title: string }> = {
  '/': { eyebrow: 'Command center', title: 'Good morning, Alex' },
  '/formulas': { eyebrow: 'Formula workspace', title: 'Formula management' },
  '/materials': { eyebrow: 'Raw material library', title: 'Material management' },
  '/specifications': { eyebrow: 'Quality & compliance', title: 'Material specifications' },
  '/reports': { eyebrow: 'Output center', title: 'Reports & worksheets' },
  '/administration': { eyebrow: 'Administration', title: 'Access control' },
}

export function AppShell() {
  const [mobileOpen, setMobileOpen] = useState(false)
  const location = useLocation()
  const meta = pageMeta[location.pathname] ?? pageMeta['/']

  return (
    <div className="min-h-screen bg-[#f5f6f3] text-slate-950">
      <aside className="fixed inset-y-0 left-0 z-30 hidden w-[232px] flex-col bg-[#17211f] lg:flex"><SidebarContent /></aside>
      <AnimatePresence>
        {mobileOpen && <>
          <motion.button aria-label="Close navigation" initial={{ opacity: 0 }} animate={{ opacity: 1 }} exit={{ opacity: 0 }} className="fixed inset-0 z-40 bg-slate-950/40 backdrop-blur-sm lg:hidden" onClick={() => setMobileOpen(false)} />
          <motion.aside initial={{ x: -260 }} animate={{ x: 0 }} exit={{ x: -260 }} transition={{ type: 'spring', stiffness: 360, damping: 34 }} className="fixed inset-y-0 left-0 z-50 flex w-[250px] flex-col bg-[#17211f] lg:hidden">
            <button aria-label="Close navigation" className="absolute right-3 top-4 rounded-lg p-2 text-[#91a29d] hover:bg-white/10 hover:text-white" onClick={() => setMobileOpen(false)}><X className="size-4" /></button>
            <SidebarContent onNavigate={() => setMobileOpen(false)} />
          </motion.aside>
        </>}
      </AnimatePresence>

      <div className="lg:pl-[232px]">
        <header className="sticky top-0 z-20 flex h-[76px] items-center gap-4 border-b border-slate-200/80 bg-[#f5f6f3]/90 px-5 backdrop-blur-xl sm:px-8">
          <button className="rounded-lg p-2 text-slate-600 hover:bg-white lg:hidden" onClick={() => setMobileOpen(true)}><Menu className="size-5" /></button>
          <div className="hidden lg:block"><PanelLeftClose className="size-4 text-slate-400" /></div>
          <div className="hidden h-6 w-px bg-slate-200 lg:block" />
          <div className="min-w-0 flex-1"><p className="text-[10px] font-bold uppercase tracking-[.16em] text-[#d56d31]">{meta.eyebrow}</p><h1 className="truncate text-lg font-extrabold tracking-tight text-[#1b2926]">{meta.title}</h1></div>
          <div className="hidden items-center gap-2 rounded-lg border border-slate-200 bg-white px-3 py-2 text-slate-400 shadow-sm md:flex"><Search className="size-4" /><span className="w-40 text-xs">Search anything...</span><kbd className="rounded bg-slate-100 px-1.5 py-0.5 text-[10px] font-bold text-slate-400">⌘ K</kbd></div>
          <button className="relative rounded-lg border border-slate-200 bg-white p-2.5 text-slate-500 shadow-sm hover:text-slate-900"><Bell className="size-4" /><span className="absolute right-2 top-2 size-1.5 rounded-full bg-[#e57b3a] ring-2 ring-white" /></button>
          <button className="hidden rounded-lg border border-slate-200 bg-white p-2.5 text-slate-500 shadow-sm hover:text-slate-900 sm:block"><HelpCircle className="size-4" /></button>
        </header>
        <main className="mx-auto max-w-[1500px] px-5 py-7 sm:px-8 sm:py-9">
          <AnimatePresence mode="wait">
            <motion.div key={location.pathname} initial={{ opacity: 0, y: 6 }} animate={{ opacity: 1, y: 0 }} exit={{ opacity: 0, y: -4 }} transition={{ duration: .24 }}><Outlet /></motion.div>
          </AnimatePresence>
        </main>
        <footer className="mx-auto flex max-w-[1500px] items-center justify-between px-8 pb-8 text-[11px] text-slate-400"><span>Foundry PLM · Migration workspace</span><span className="flex items-center gap-1.5"><Sparkles className="size-3" /> Modernized from PowerBuilder</span></footer>
      </div>
    </div>
  )
}

