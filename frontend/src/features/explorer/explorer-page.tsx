import { useQuery } from '@tanstack/react-query'
import { Search } from 'lucide-react'
import { useState } from 'react'
import { Badge } from '@/components/ui/badge'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/form-controls'
import { ReadGrid, ReadOnlyForm, type DetailField, type GridColumn } from '@/components/ui/read-grid'
import { api, type GridOptions } from '@/lib/api'
import type { DataRow, FormulaLine, FormulaListItem, FormulaRevision, ItemSpec, Material, SpecChild } from '@/types/api'

type Tab = 'formulas' | 'headers' | 'lines' | 'materials' | 'assistant' | 'jde-original' | 'item-cost' | 'specifications' |
  'regulatory' | 'allergens' | 'countries' | 'properties' | 'solvents' | 'vendor-parts'

const childTabs: Tab[] = ['regulatory', 'allergens', 'countries', 'properties', 'solvents', 'vendor-parts']
const snapshotTabs: Tab[] = ['assistant', 'jde-original', 'item-cost']
const tabs: { key: Tab; label: string }[] = [
  { key: 'formulas', label: 'Formula' }, { key: 'headers', label: 'Formula header' },
  { key: 'lines', label: 'Formula line' }, { key: 'materials', label: 'Material' },
  { key: 'assistant', label: 'Assistant snapshot' }, { key: 'jde-original', label: 'JDE original' },
  { key: 'item-cost', label: 'Item cost' },
  { key: 'specifications', label: 'Item spec' }, { key: 'regulatory', label: 'Regulatory' },
  { key: 'allergens', label: 'Allergen' }, { key: 'countries', label: 'Country' },
  { key: 'properties', label: 'Property' }, { key: 'solvents', label: 'Solvent' },
  { key: 'vendor-parts', label: 'Vendor part' },
]
const PAGE_SIZE = 50
const childFields: Record<string, string[]> = {
  regulatory: ['halal_status', 'gmo_status', 'kosher_status', 'gluten_status'],
  allergens: ['allergen_name', 'present_status', 'specific_allergen', 'comments'],
  countries: ['country_name', 'country_abbv', 'material_type'],
  properties: ['specification_type', 'property_name', 'target_value', 'unit_of_measure'],
  solvents: ['solvent_name', 'solvent_type', 'ratio', 'solvent_number'],
  'vendor-parts': ['vendor_name', 'vendor_number', 'vendor_part_number', 'manufacturer_name'],
}
const snapshotFields: Record<string, string[]> = {
  assistant: ['source_table', 'branch_code', 'item_number', 'item_description'],
  'jde-original': ['source_branch_code', 'source_item_number', 'source_julian_date', 'unit_cost'],
  'item-cost': ['item_number', 'run_julian_date', 'item_cost'],
}

const formulaColumns: GridColumn<FormulaListItem>[] = [
  { key: 'name', label: 'Formula', render: (row) => <strong>{row.name}</strong> },
  { key: 'parent_item_number', label: 'Parent item', render: (row) => row.parent_item_number || '—' },
  { key: 'branch_code', label: 'Branch', render: (row) => row.latest_revision.branch_code || '—' },
  { key: 'revision_label', label: 'Revision', render: (row) => row.latest_revision.revision_label },
  { key: 'workflow_status', label: 'Status', render: (row) => <Badge value={row.latest_revision.workflow_status} /> },
]
const headerColumns: GridColumn<FormulaRevision>[] = [
  { key: 'sequence', label: 'Sequence', render: (row) => row.sequence },
  { key: 'revision_label', label: 'Revision', render: (row) => row.revision_label },
  { key: 'formula_name', label: 'Name', render: (row) => row.formula_name },
  { key: 'branch_code', label: 'Branch', render: (row) => row.branch_code || '—' },
  { key: 'workflow_status', label: 'Status', render: (row) => <Badge value={row.workflow_status} /> },
]
const lineColumns: GridColumn<FormulaLine>[] = [
  { key: 'line_number', label: 'Line', render: (row) => row.line_number },
  { key: 'material_item_number', label: 'Material item', render: (row) => <strong>{row.material_item_number}</strong> },
  { key: 'material_description', label: 'Description', render: (row) => row.material_description || '—' },
  { key: 'material_branch_code', label: 'Branch', render: (row) => row.material_branch_code || '—' },
  { key: 'potency', label: 'Potency', render: (row) => row.potency ? `${row.potency} ${row.potency_unit}` : '—' },
]
const materialColumns: GridColumn<Material>[] = [
  { key: 'item_number', label: 'Item', render: (row) => <strong>{row.item_number}</strong> },
  { key: 'branch_code', label: 'Branch', render: (row) => row.branch_code },
  { key: 'description', label: 'Description', render: (row) => row.description || '—' },
  { key: 'category', label: 'Category', render: (row) => row.category || '—' },
  { key: 'is_active', label: 'Active', render: (row) => row.is_active ? 'Yes' : 'No' },
]
const specColumns: GridColumn<ItemSpec>[] = [
  { key: 'revision', label: 'Revision', render: (row) => row.revision },
  { key: 'review_status', label: 'Review', render: (row) => row.review_status || '—' },
  { key: 'is_released', label: 'Released', render: (row) => row.is_released ? 'Yes' : 'No' },
  { key: 'appearance', label: 'Appearance', render: (row) => row.appearance || '—' },
  { key: 'physical_form', label: 'Physical form', render: (row) => row.physical_form || '—' },
]

function fields(record: object | null | undefined, keys: { key: string; label: string }[]): DetailField[] {
  if (!record) return [{ label: 'Selection', value: 'Select a row in the grid below' }]
  const values = record as Record<string, unknown>
  return keys.map(({ key, label }) => ({ label, value: values[key] }))
}

export function ExplorerPage({ initialTab = 'formulas' }: { initialTab?: Tab }) {
  const [tab, setTab] = useState<Tab>(initialTab)
  const [formulaId, setFormulaId] = useState<number | null>(null)
  const [headerId, setHeaderId] = useState<number | null>(null)
  const [lineId, setLineId] = useState<number | null>(null)
  const [materialId, setMaterialId] = useState<number | null>(null)
  const [specId, setSpecId] = useState<number | null>(null)
  const [childId, setChildId] = useState<number | null>(null)
  const [snapshotId, setSnapshotId] = useState<number | null>(null)
  const [offsets, setOffsets] = useState<Partial<Record<Tab, number>>>({})
  const [gridOptions, setGridOptions] = useState<Partial<Record<Tab, GridOptions>>>({})
  const [searchDraft, setSearchDraft] = useState('')
  const [search, setSearch] = useState('')
  const offset = offsets[tab] ?? 0
  const page = (next: number) => setOffsets((current) => ({ ...current, [tab]: next }))
  const controls = gridOptions[tab] ?? {}
  const setFilters = (filters: Record<string, string>) => {
    setGridOptions((current) => ({ ...current, [tab]: { ...current[tab], filters } }))
    page(0)
  }
  const setSort = (key: string) => {
    setGridOptions((current) => {
      const previous = current[tab] ?? {}
      const next = previous.sort_by === key
        ? previous.sort_dir === 'desc' ? { sort_by: undefined, sort_dir: undefined } : { sort_by: key, sort_dir: 'desc' as const }
        : { sort_by: key, sort_dir: 'asc' as const }
      return { ...current, [tab]: { ...previous, ...next } }
    })
    page(0)
  }
  const gridProps = { filters: controls.filters ?? {}, onFilters: setFilters, sortBy: controls.sort_by, sortDir: controls.sort_dir, onSort: setSort }

  const formulas = useQuery({ queryKey: ['explorer', 'formulas', search, offsets.formulas ?? 0, gridOptions.formulas], queryFn: () => api.formulas({ query: search, limit: PAGE_SIZE, offset: offsets.formulas ?? 0 }, gridOptions.formulas), enabled: tab === 'formulas' })
  const formula = useQuery({ queryKey: ['explorer', 'formula', formulaId], queryFn: () => api.formula(formulaId!), enabled: formulaId !== null })
  const headers = useQuery({ queryKey: ['explorer', 'headers', formulaId, offsets.headers ?? 0, gridOptions.headers], queryFn: () => api.headers(formulaId!, PAGE_SIZE, offsets.headers ?? 0, gridOptions.headers), enabled: formulaId !== null && tab === 'headers' })
  const header = useQuery({ queryKey: ['explorer', 'header', formulaId, headerId], queryFn: () => api.header(formulaId!, headerId!), enabled: formulaId !== null && headerId !== null })
  const lines = useQuery({ queryKey: ['explorer', 'lines', formulaId, headerId, offsets.lines ?? 0, gridOptions.lines], queryFn: () => api.lines(formulaId!, headerId!, PAGE_SIZE, offsets.lines ?? 0, gridOptions.lines), enabled: formulaId !== null && headerId !== null && tab === 'lines' })
  const line = useQuery({ queryKey: ['explorer', 'line', formulaId, headerId, lineId], queryFn: () => api.line(formulaId!, headerId!, lineId!), enabled: formulaId !== null && headerId !== null && lineId !== null })
  const lineBranch = line.data?.material_branch_code || header.data?.branch_code || ''
  const linkedMaterial = useQuery({ queryKey: ['explorer', 'linked-material', line.data?.material_id, lineBranch, line.data?.material_item_number], queryFn: () => line.data!.material_id ? api.material(line.data!.material_id) : api.materialByKey(lineBranch, line.data!.material_item_number), enabled: !!line.data && (!!line.data.material_id || !!lineBranch) })
  const linkedSpec = useQuery({ queryKey: ['explorer', 'linked-spec', specId], queryFn: () => api.specification(specId!), enabled: specId !== null })
  const selectedMaterialId = materialId ?? linkedMaterial.data?.id ?? linkedSpec.data?.material_id ?? null
  const materialSearch = lineId ? line.data?.material_item_number : search
  const materials = useQuery({ queryKey: ['explorer', 'materials', materialSearch, lineBranch, offsets.materials ?? 0, gridOptions.materials], queryFn: () => api.materials({ query: materialSearch, branch_code: lineId ? lineBranch : undefined, limit: PAGE_SIZE, offset: offsets.materials ?? 0 }, gridOptions.materials), enabled: tab === 'materials' })
  const material = useQuery({ queryKey: ['explorer', 'material', selectedMaterialId], queryFn: () => api.material(selectedMaterialId!), enabled: selectedMaterialId !== null })
  const snapshots = useQuery({ queryKey: ['explorer', 'snapshots', selectedMaterialId, tab, offsets[tab] ?? 0, controls], queryFn: () => api.materialSnapshots(selectedMaterialId!, tab, PAGE_SIZE, offsets[tab] ?? 0, controls), enabled: selectedMaterialId !== null && snapshotTabs.includes(tab) })
  const snapshot = useQuery({ queryKey: ['explorer', 'snapshot', selectedMaterialId, tab, snapshotId], queryFn: () => api.materialSnapshot(selectedMaterialId!, tab, snapshotId!), enabled: selectedMaterialId !== null && snapshotId !== null && snapshotTabs.includes(tab) })
  const specs = useQuery({ queryKey: ['explorer', 'specs', selectedMaterialId, offsets.specifications ?? 0, gridOptions.specifications], queryFn: () => api.specifications(selectedMaterialId!, PAGE_SIZE, offsets.specifications ?? 0, gridOptions.specifications), enabled: selectedMaterialId !== null && tab === 'specifications' })
  const specRecord = useQuery({ queryKey: ['explorer', 'spec-record', specId], queryFn: () => api.specificationRecord(specId!), enabled: specId !== null })
  const children = useQuery({ queryKey: ['explorer', 'children', specId, tab, offsets[tab] ?? 0, controls], queryFn: () => api.specChildren(specId!, tab, PAGE_SIZE, offsets[tab] ?? 0, controls), enabled: specId !== null && childTabs.includes(tab) })
  const child = useQuery({ queryKey: ['explorer', 'child', specId, tab, childId], queryFn: () => api.specChild(specId!, tab, childId!), enabled: specId !== null && childId !== null && childTabs.includes(tab) })

  function chooseFormula(row: FormulaListItem) { setFormulaId(row.id); setHeaderId(null); setLineId(null); setMaterialId(null); setSpecId(null); setTab('headers') }
  function chooseHeader(row: FormulaRevision) { setHeaderId(row.id); setLineId(null); setMaterialId(null); setSpecId(null); setTab('lines') }
  function chooseLine(row: FormulaLine) { setLineId(row.id); setMaterialId(null); setSpecId(row.item_spec_id); setTab('materials') }
  function chooseMaterial(row: Material) { setMaterialId(row.id); if (row.id !== linkedMaterial.data?.id) setSpecId(null); setSnapshotId(null); setTab('specifications') }
  function chooseSpec(row: ItemSpec) { setSpecId(row.id); setChildId(null); setTab('regulatory') }
  function switchTab(next: Tab) { setTab(next); setChildId(null); setSnapshotId(null) }
  const blocked = (key: Tab) => key === 'headers' ? formulaId === null : key === 'lines' ? headerId === null : key === 'specifications' || snapshotTabs.includes(key) ? selectedMaterialId === null : childTabs.includes(key) ? specId === null : false
  const selectionText = tab === 'materials' && lineId && (linkedMaterial.isError || (line.data && !line.data.material_id && !lineBranch)) ? 'Unlinked material: check the line’s branch and item number.' : 'Select a row in the grid below to inspect it and continue.'
  const currentChild = child.data ?? children.data?.find((row) => row.id === childId)
  const currentSnapshot = snapshot.data ?? snapshots.data?.find((row) => row.id === snapshotId)
  const snapshotColumns: GridColumn<DataRow>[] = [
    { key: 'id', label: 'ID', render: (row) => row.id },
    ...(snapshotFields[tab] ?? []).map((key) => ({ key, label: key.replaceAll('_', ' '), render: (row: DataRow) => String(row[key] ?? '—') })),
  ]
  const childColumns: GridColumn<SpecChild>[] = [
    { key: 'id', label: 'ID', render: (row) => row.id },
    ...(childFields[tab] ?? []).map((key) => ({ key, label: key.replaceAll('_', ' '), render: (row: SpecChild) => String(row[key] ?? '—') })),
  ]

  const title = tabs.find((item) => item.key === tab)?.label ?? 'Record'
  let detailFields: DetailField[] = [{ label: 'Selection', value: selectionText }]
  if (tab === 'formulas' && formula.data) detailFields = fields(formula.data, [{ key: 'id', label: 'Formula ID' }, { key: 'name', label: 'Name' }, { key: 'parent_item_number', label: 'Parent item' }, { key: 'category', label: 'Category' }, { key: 'is_active', label: 'Active' }, { key: 'is_production', label: 'Production' }])
  if (tab === 'headers' && header.data) detailFields = fields(header.data, [{ key: 'id', label: 'Header ID' }, { key: 'revision_label', label: 'Revision' }, { key: 'formula_name', label: 'Name' }, { key: 'workflow_status', label: 'Status' }, { key: 'branch_code', label: 'Branch' }, { key: 'customer_name', label: 'Customer' }, { key: 'unit_type', label: 'Unit type' }, { key: 'notes', label: 'Notes' }])
  if (tab === 'lines' && line.data) detailFields = fields(line.data, [{ key: 'id', label: 'Line ID' }, { key: 'line_number', label: 'Line' }, { key: 'material_item_number', label: 'Material item' }, { key: 'material_branch_code', label: 'Branch' }, { key: 'material_description', label: 'Description' }, { key: 'potency', label: 'Potency' }, { key: 'cost_snapshot', label: 'Cost snapshot' }])
  if (tab === 'materials' && material.data) detailFields = fields(material.data, [{ key: 'id', label: 'Material ID' }, { key: 'item_number', label: 'Item' }, { key: 'branch_code', label: 'Branch' }, { key: 'description', label: 'Description' }, { key: 'category', label: 'Category' }, { key: 'base_uom', label: 'UOM' }, { key: 'is_active', label: 'Active' }])
  if (snapshotTabs.includes(tab) && currentSnapshot) detailFields = Object.entries(currentSnapshot).map(([key, value]) => ({ label: key.replaceAll('_', ' '), value }))
  if (tab === 'specifications' && specRecord.data) detailFields = Object.entries(specRecord.data).map(([key, value]) => ({ label: key.replaceAll('_', ' '), value }))
  if (childTabs.includes(tab) && currentChild) detailFields = Object.entries(currentChild).map(([key, value]) => ({ label: key.replaceAll('_', ' '), value }))

  return <div className="space-y-5">
    <div className="flex gap-2 overflow-x-auto pb-1" role="tablist" aria-label="PLM tables">{tabs.map(({ key, label }) => <button key={key} type="button" role="tab" aria-selected={tab === key} disabled={blocked(key)} onClick={() => switchTab(key)} className={`shrink-0 rounded-lg border px-3.5 py-2 text-xs font-bold transition disabled:cursor-not-allowed disabled:opacity-40 ${tab === key ? 'border-[#e57b3a] bg-orange-50 text-[#a85322]' : 'border-slate-200 bg-white text-slate-600 hover:bg-slate-50'}`}>{label}</button>)}</div>
    <ReadOnlyForm title={`${title} details`} subtitle={selectionText} fields={detailFields} />
    {(tab === 'formulas' || (tab === 'materials' && !lineId)) && <form className="flex max-w-md gap-2" onSubmit={(event) => { event.preventDefault(); setSearch(searchDraft); page(0) }}><Input aria-label={`Search ${title}`} value={searchDraft} onChange={(event) => setSearchDraft(event.target.value)} placeholder={`Search ${title.toLowerCase()}…`} /><Button type="submit" variant="secondary"><Search className="size-4" /> Search</Button></form>}
    {tab === 'formulas' && <ReadGrid {...gridProps} key={tab} title="Formula register" subtitle="Select a formula to see its revisions" rows={formulas.data ?? []} columns={formulaColumns} selectedId={formulaId} onSelect={chooseFormula} loading={formulas.isLoading} error={formulas.error} offset={offset} limit={PAGE_SIZE} onPage={page} />}
    {tab === 'headers' && <ReadGrid {...gridProps} key={tab} title="Formula headers" subtitle={formulaId ? `Revisions for formula ${formulaId}` : 'Select a formula first'} rows={headers.data ?? []} columns={headerColumns} selectedId={headerId} onSelect={chooseHeader} loading={headers.isLoading} error={headers.error} offset={offset} limit={PAGE_SIZE} onPage={page} />}
    {tab === 'lines' && <ReadGrid {...gridProps} key={tab} title="Formula lines" subtitle={headerId ? `Ingredients for header ${headerId}` : 'Select a header first'} rows={lines.data ?? []} columns={lineColumns} selectedId={lineId} onSelect={chooseLine} loading={lines.isLoading} error={lines.error} offset={offset} limit={PAGE_SIZE} onPage={page} />}
    {tab === 'materials' && <ReadGrid {...gridProps} key={tab} title="Materials" subtitle={lineId ? 'Matched by linked ID or branch and item number' : 'Select a material to see its item specs'} rows={materials.data ?? []} columns={materialColumns} selectedId={selectedMaterialId} onSelect={chooseMaterial} loading={materials.isLoading || linkedMaterial.isLoading} error={materials.error} offset={offset} limit={PAGE_SIZE} onPage={page} />}
    {snapshotTabs.includes(tab) && <ReadGrid {...gridProps} key={tab} title={`Material ${title.toLowerCase()}`} subtitle={selectedMaterialId ? `Snapshot rows for material ${selectedMaterialId}` : 'Select a material first'} rows={snapshots.data ?? []} columns={snapshotColumns} selectedId={snapshotId} onSelect={(row) => setSnapshotId(row.id)} loading={snapshots.isLoading} error={snapshots.error} offset={offset} limit={PAGE_SIZE} onPage={page} />}
    {tab === 'specifications' && <ReadGrid {...gridProps} key={tab} title="Item specifications" subtitle={selectedMaterialId ? `Revisions for material ${selectedMaterialId}` : 'Select a material first'} rows={specs.data ?? []} columns={specColumns} selectedId={specId} onSelect={chooseSpec} loading={specs.isLoading} error={specs.error} offset={offset} limit={PAGE_SIZE} onPage={page} />}
    {childTabs.includes(tab) && <ReadGrid {...gridProps} key={tab} title={`Item ${title.toLowerCase()}`} subtitle={specId ? `Records for spec ${specId}` : 'Select an item spec first'} rows={children.data ?? []} columns={childColumns} selectedId={childId} onSelect={(row) => setChildId(row.id)} loading={children.isLoading} error={children.error} offset={offset} limit={PAGE_SIZE} onPage={page} />}
  </div>
}
