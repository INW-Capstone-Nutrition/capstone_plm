import { useMutation } from '@tanstack/react-query'
import { ShieldCheck, UserPlus } from 'lucide-react'
import { FormEvent } from 'react'
import { api } from '@/lib/api'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { Field, Input, Select } from '@/components/ui/form-controls'

const permissions = [
  ['Formulation Lead', 'Create drafts, review, activate, and see cost'],
  ['Formulator', 'Create and edit development formulas'],
  ['Quality Reviewer', 'Review specifications and formula compliance'],
  ['Report Viewer', 'Run permitted non-confidential reports'],
]

export function AdministrationPage() {
  const mutation = useMutation({ mutationFn: api.createUser })
  function submit(event: FormEvent<HTMLFormElement>) { event.preventDefault(); mutation.mutate(Object.fromEntries(new FormData(event.currentTarget))) }
  return <div className="grid gap-6 lg:grid-cols-[.9fr_1fr]"><Card><CardHeader><div><h2 className="text-base font-extrabold">Add user access</h2><p className="mt-1 text-xs text-slate-400">Capability roles replace UI-only PowerBuilder flags</p></div><UserPlus className="size-5 text-[#e57b3a]" /></CardHeader><CardContent><form className="space-y-4" onSubmit={submit}><Field label="User name"><Input name="user_name" placeholder="a.chen" required /></Field><Field label="Display name"><Input name="display_name" placeholder="Alex Chen" required /></Field><Field label="Email"><Input name="email" type="email" placeholder="name@company.com" /></Field><div className="grid grid-cols-2 gap-4"><Field label="Role"><Select name="role"><option value="formulation_lead">Formulation Lead</option><option value="formulator">Formulator</option><option value="quality_reviewer">Quality Reviewer</option><option value="report_viewer">Report Viewer</option></Select></Field><Field label="Branch"><Select name="branch_code"><option value="">All permitted</option><option value="05">BP05</option><option value="10">BP10</option><option value="15">BP15</option></Select></Field></div>{mutation.isSuccess && <p className="text-sm font-semibold text-emerald-700">User access created.</p>}<Button className="w-full" disabled={mutation.isPending}>Create access</Button></form></CardContent></Card><Card className="self-start"><CardHeader><div><h2 className="text-base font-extrabold">Role policy</h2><p className="mt-1 text-xs text-slate-400">Authorization is enforced by the API boundary</p></div><ShieldCheck className="size-5 text-emerald-600" /></CardHeader><CardContent className="space-y-3">{permissions.map(([role, description])=><div key={role} className="rounded-xl border border-slate-100 bg-[#fafbf8] p-4"><p className="text-xs font-extrabold text-slate-800">{role}</p><p className="mt-1 text-xs leading-5 text-slate-500">{description}</p></div>)}</CardContent></Card></div>
}

