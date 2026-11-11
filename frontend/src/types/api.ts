export type WorkflowStatus = string

export interface FormulaLine {
  id: number
  material_id: number | null
  item_spec_id: number | null
  line_number: number
  material_item_number: string
  material_branch_code: string | null
  material_description: string
  material_category: string | null
  selected_vendor_name: string | null
  potency: string | null
  potency_unit: string
  active_percent: string | null
  mg_per_capsule_percent: string | null
  cost_snapshot: string
}

export interface FormulaRevision {
  id: number
  sequence: number
  revision_number: string
  revision_label: string
  workflow_status: WorkflowStatus
  branch_code: string | null
  parent_item_number: string | null
  blend_item_number: string | null
  formula_name: string
  category: string | null
  customer_name: string | null
  unit_type: string | null
  notes: string | null
  version: number
  created_by: string
  created_dt: string
  updated_by: string
  updated_dt: string
  lines: FormulaLine[]
}

export interface FormulaDetail {
  id: number
  parent_item_number: string | null
  name: string
  category: string | null
  description: string | null
  record_origin: string
  is_voided: boolean
  is_active: boolean
  is_production: boolean
  revisions: FormulaRevision[]
}

export interface FormulaListItem {
  id: number
  parent_item_number: string
  name: string
  category: string | null
  latest_revision: FormulaRevision
}

export interface DashboardSummary {
  active_formulas: number
  in_review: number
  development: number
  material_alerts: number
  total_materials: number
  workflow_counts: Record<string, number>
  recent_formulas: FormulaListItem[]
}

export interface Material {
  id: number
  item_number: string
  description: string | null
  category: string | null
  base_uom: string | null
  branch_code: string
  stocking_type: string | null
  tier_level: string | null
  source_system: string | null
  is_active: boolean
}

export interface ItemSpec {
  id: number
  material_id: number
  revision: number
  review_status: string | null
  is_released: boolean | null
  appearance: string | null
  color: string | null
  item_type: string | null
  physical_form: string | null
}

export type DataRow = { id: number; [key: string]: unknown }
export type SpecChild = DataRow & { item_spec_id: number }
