import type {
  DashboardSummary, DataRow, FormulaDetail, FormulaLine, FormulaListItem,
  FormulaRevision, ItemSpec, Material, SpecChild,
} from '@/types/api'

const API_ROOT = import.meta.env.VITE_API_URL ?? '/api/v1'
export type GridOptions = { filters?: Record<string, string>; sort_by?: string; sort_dir?: 'asc' | 'desc' }

async function request<T>(path: string, options?: RequestInit): Promise<T> {
  const response = await fetch(`${API_ROOT}${path}`, {
    headers: { 'Content-Type': 'application/json', ...options?.headers },
    ...options,
  })
  if (!response.ok) {
    const body = await response.json().catch(() => ({ detail: 'Request failed' }))
    throw new Error(body.detail ?? 'Request failed')
  }
  return response.json() as Promise<T>
}

function search(params: Record<string, string | number | undefined>) {
  const values = new URLSearchParams()
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined && value !== '') values.set(key, String(value))
  }
  return `?${values}`
}

function gridSearch(params: Record<string, string | number | undefined>, controls: GridOptions = {}) {
  return search({
    ...params,
    sort_by: controls.sort_by,
    sort_dir: controls.sort_by ? controls.sort_dir ?? 'asc' : undefined,
    filters: controls.filters && Object.keys(controls.filters).length ? JSON.stringify(controls.filters) : undefined,
  })
}

export const api = {
  dashboard: () => request<DashboardSummary>('/dashboard'),
  formulas: (params: { query?: string; limit?: number; offset?: number } = {}, controls: GridOptions = {}) =>
    request<FormulaListItem[]>(`/formulas${gridSearch(params, controls)}`),
  formula: (id: number) => request<FormulaDetail>(`/formulas/${id}`),
  headers: (formulaId: number, limit = 100, offset = 0, controls: GridOptions = {}) =>
    request<FormulaRevision[]>(`/formulas/${formulaId}/headers${gridSearch({ limit, offset }, controls)}`),
  header: (formulaId: number, headerId: number) =>
    request<FormulaRevision>(`/formulas/${formulaId}/headers/${headerId}`),
  lines: (formulaId: number, headerId: number, limit = 100, offset = 0, controls: GridOptions = {}) =>
    request<FormulaLine[]>(`/formulas/${formulaId}/headers/${headerId}/lines${gridSearch({ limit, offset }, controls)}`),
  line: (formulaId: number, headerId: number, lineId: number) =>
    request<FormulaLine>(`/formulas/${formulaId}/headers/${headerId}/lines/${lineId}`),
  materials: (params: { query?: string; branch_code?: string; limit?: number; offset?: number } = {}, controls: GridOptions = {}) =>
    request<Material[]>(`/materials${gridSearch(params, controls)}`),
  material: (id: number) => request<Material>(`/materials/${id}`),
  materialByKey: (branch_code: string, item_number: string) =>
    request<Material>(`/materials/lookup/by-key${search({ branch_code, item_number })}`),
  materialSnapshots: (id: number, kind: string, limit = 100, offset = 0, controls: GridOptions = {}) =>
    request<DataRow[]>(`/materials/${id}/snapshots/${kind}${gridSearch({ limit, offset }, controls)}`),
  materialSnapshot: (id: number, kind: string, rowId: number) =>
    request<DataRow>(`/materials/${id}/snapshots/${kind}/${rowId}`),
  specifications: (material_id: number, limit = 100, offset = 0, controls: GridOptions = {}) =>
    request<ItemSpec[]>(`/specifications${gridSearch({ material_id, limit, offset }, controls)}`),
  specification: (id: number) => request<ItemSpec>(`/specifications/${id}`),
  specificationRecord: (id: number) => request<Record<string, unknown>>(`/specifications/${id}/record`),
  specChildren: (id: number, kind: string, limit = 100, offset = 0, controls: GridOptions = {}) =>
    request<SpecChild[]>(`/specifications/${id}/children/${kind}${gridSearch({ limit, offset }, controls)}`),
  specChild: (id: number, kind: string, rowId: number) =>
    request<SpecChild>(`/specifications/${id}/children/${kind}/${rowId}`),
  createFormula: (payload: Record<string, unknown>) =>
    request('/formulas', { method: 'POST', body: JSON.stringify(payload) }),
  createMaterial: (payload: Record<string, unknown>) =>
    request('/materials', { method: 'POST', body: JSON.stringify(payload) }),
  createSpecification: (payload: Record<string, unknown>) =>
    request('/specifications', { method: 'POST', body: JSON.stringify(payload) }),
  createUser: (payload: Record<string, unknown>) =>
    request('/users', { method: 'POST', body: JSON.stringify(payload) }),
}

