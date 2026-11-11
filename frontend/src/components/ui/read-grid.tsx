import { useState, type ReactNode } from 'react'
import { ArrowDown, ArrowUp, ArrowUpDown, ChevronLeft, ChevronRight } from 'lucide-react'
import { Button } from '@/components/ui/button'
import { Card, CardContent, CardHeader } from '@/components/ui/card'
import { Input } from '@/components/ui/form-controls'
import { Table, TableBody, TableCell, TableHead, TableHeader, TableRow } from '@/components/ui/table'

export type GridColumn<T> = { key: string; label: string; render: (row: T) => ReactNode }
export type DetailField = { label: string; value: unknown }

function display(value: unknown): string {
  if (value === null || value === undefined || value === '') return '—'
  if (typeof value === 'boolean') return value ? 'Yes' : 'No'
  return String(value)
}

export function ReadOnlyForm({ title, subtitle, fields }: {
  title: string; subtitle: string; fields: DetailField[]
}) {
  return <Card>
    <CardHeader><div><h2 className="text-base font-extrabold">{title}</h2><p className="mt-1 text-xs text-slate-500">{subtitle}</p></div><span className="rounded-full bg-slate-100 px-3 py-1 text-[10px] font-bold uppercase tracking-wide text-slate-500">Read only</span></CardHeader>
    <CardContent><form className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4" onSubmit={(event) => event.preventDefault()}>
      {fields.map((field) => <label key={field.label} className="block min-w-0"><span className="mb-2 block text-[11px] font-bold uppercase tracking-wide text-slate-500">{field.label}</span><Input readOnly value={display(field.value)} className="bg-slate-50 text-slate-700" /></label>)}
    </form></CardContent>
  </Card>
}

export function ReadGrid<T extends { id: number }>({
  title, subtitle, rows, columns, selectedId, onSelect, loading, error,
  offset, limit, onPage, filters, onFilters, sortBy, sortDir, onSort,
}: {
  title: string; subtitle: string; rows: T[]; columns: GridColumn<T>[]
  selectedId?: number | null; onSelect: (row: T) => void
  loading: boolean; error?: Error | null; offset: number; limit: number
  onPage: (offset: number) => void
  filters: Record<string, string>; onFilters: (filters: Record<string, string>) => void
  sortBy?: string; sortDir?: 'asc' | 'desc'; onSort: (key: string) => void
}) {
  const [draftFilters, setDraftFilters] = useState(filters)
  function applyFilters() {
    const cleaned = Object.fromEntries(Object.entries(draftFilters).filter(([, value]) => value.trim()))
    if (JSON.stringify(cleaned) !== JSON.stringify(filters)) onFilters(cleaned)
  }
  return <Card className="overflow-hidden">
    <CardHeader><div><h2 className="text-base font-extrabold">{title}</h2><p className="mt-1 text-xs text-slate-500">{subtitle}</p></div><span className="text-xs font-semibold text-slate-500">{rows.length} on this page</span></CardHeader>
    <CardContent className="px-0 pb-0"><div className="overflow-x-auto"><Table>
      <TableHeader><TableRow>{columns.map((column) => <TableHead key={column.key} className="min-w-36 align-top"><button type="button" onClick={() => onSort(column.key)} className="mb-2 flex w-full items-center justify-between gap-2 text-left hover:text-slate-900" aria-label={`Sort by ${column.label}`}>{column.label}{sortBy === column.key ? sortDir === 'desc' ? <ArrowDown className="size-3.5" /> : <ArrowUp className="size-3.5" /> : <ArrowUpDown className="size-3.5 opacity-50" />}</button><Input aria-label={`Search ${column.label}`} value={draftFilters[column.key] ?? ''} onChange={(event) => setDraftFilters((current) => ({ ...current, [column.key]: event.target.value }))} onBlur={applyFilters} onKeyDown={(event) => { if (event.key === 'Enter') { event.preventDefault(); applyFilters() } }} placeholder="Search…" className="h-8 bg-white text-xs font-normal normal-case tracking-normal" /></TableHead>)}</TableRow></TableHeader>
      <TableBody>{rows.map((row) => <TableRow key={row.id} tabIndex={0} role="button" aria-selected={selectedId === row.id} onClick={() => onSelect(row)} onKeyDown={(event) => { if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); onSelect(row) } }} className={`cursor-pointer hover:bg-orange-50/60 focus:bg-orange-50 focus:outline-none ${selectedId === row.id ? 'bg-orange-50' : ''}`}>{columns.map((column) => <TableCell key={column.key}>{column.render(row)}</TableCell>)}</TableRow>)}</TableBody>
    </Table></div>
    <div className="px-5 py-8 text-center text-sm text-slate-500" hidden={rows.length > 0 || loading || !!error}>{offset ? 'No more records.' : 'No records found for this selection.'}</div>
    {loading && <div className="px-5 py-8 text-center text-sm text-slate-500">Loading records…</div>}
    {error && <div className="px-5 py-8 text-center text-sm text-red-700">{error.message}</div>}
    <div className="flex items-center justify-between border-t border-slate-100 px-5 py-3"><span className="text-xs text-slate-500">Rows {rows.length ? offset + 1 : 0}–{offset + rows.length}</span><div className="flex gap-2"><Button type="button" variant="secondary" size="sm" onClick={() => onPage(Math.max(0, offset - limit))} disabled={offset === 0 || loading}><ChevronLeft className="size-3.5" /> Previous</Button><Button type="button" variant="secondary" size="sm" onClick={() => onPage(offset + limit)} disabled={rows.length < limit || loading}>Next <ChevronRight className="size-3.5" /></Button></div></div>
    </CardContent>
  </Card>
}
