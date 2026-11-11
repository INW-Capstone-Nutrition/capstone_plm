"""add material and item spec model

Revision ID: 74661cdc5fba
Revises: 63ac2f4b0d71
Create Date: 2026-11-05 19:30:24.134382
"""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import mssql

from alembic import op

revision: str = "74661cdc5fba"
down_revision: str | Sequence[str] | None = "63ac2f4b0d71"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None

LINE_MATERIAL_FK = "fk_form_formula_line_material"
LINE_ITEM_SPEC_FK = "fk_form_formula_line_item_spec"


def _drop_line_material_fk() -> None:
    inspector = sa.inspect(op.get_bind())
    for foreign_key in inspector.get_foreign_keys("formula_line", schema="form"):
        if foreign_key["constrained_columns"] == ["material_id"]:
            op.drop_constraint(
                foreign_key["name"], "formula_line", schema="form", type_="foreignkey"
            )
            return
    raise RuntimeError("Expected form.formula_line.material_id foreign key was not found")


def upgrade() -> None:
    bind = op.get_bind()
    if bind.dialect.name == "mssql":
        if bind.scalar(sa.text("SELECT COUNT_BIG(*) FROM dbo.material")):
            raise RuntimeError("dbo.material is populated; migration cannot replace it")
        if bind.scalar(
            sa.text("SELECT COUNT_BIG(*) FROM form.formula_line WHERE material_id IS NOT NULL")
        ):
            raise RuntimeError("formula_line.material_id contains references to dbo.material")
        for old_table in ("material_branch", "material_specification"):
            if bind.scalar(
                sa.text("SELECT OBJECT_ID(:name, :kind)"), {"name": f"dbo.{old_table}", "kind": "U"}
            ):
                raise RuntimeError(f"dbo.{old_table} still exists; remove or migrate it first")
        if not bind.scalar(sa.text("SELECT SCHEMA_ID('spec')")):
            op.execute(sa.text("CREATE SCHEMA spec"))
    _drop_line_material_fk()
    if bind.dialect.name == "mssql":
        op.drop_table("material", schema="dbo")
    op.create_table(
        "formula_wt_and_cost",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("run_julian_date", sa.BigInteger(), nullable=False),
        sa.Column("branch_code", sa.Unicode(length=12), nullable=False),
        sa.Column("parent_item_number", sa.Unicode(length=64), nullable=False),
        sa.Column("blend_item_number", sa.Unicode(length=64), nullable=False),
        sa.Column("total_daily_dose_mg_weight", sa.Numeric(precision=20, scale=8), nullable=True),
        sa.Column("total_mg_per_unit_weight", sa.Numeric(precision=20, scale=8), nullable=True),
        sa.Column(
            "total_mg_per_unit_weight_with_mo", sa.Numeric(precision=20, scale=8), nullable=True
        ),
        sa.Column("total_formula", sa.Numeric(precision=20, scale=8), nullable=True),
        sa.Column("raw_materials", sa.Integer(), nullable=True),
        sa.Column("formula_cost", sa.Numeric(precision=20, scale=8), nullable=True),
        sa.Column("last_active_julian_date", sa.BigInteger(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        schema="form",
    )
    op.create_table(
        "formula_item_cost",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("run_julian_date", sa.BigInteger(), nullable=False),
        sa.Column("item_number", sa.Unicode(length=40), nullable=False),
        sa.Column("item_cost", sa.Numeric(precision=20, scale=8), nullable=True),
        sa.PrimaryKeyConstraint("id"),
        schema="mat",
    )
    op.create_table(
        "material",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("branch_code", sa.Unicode(length=12), nullable=False),
        sa.Column("item_number", sa.Unicode(length=40), nullable=False),
        sa.Column("description", sa.Unicode(length=200), nullable=True),
        sa.Column("category", sa.Unicode(length=80), nullable=True),
        sa.Column("base_uom", sa.Unicode(length=12), nullable=True),
        sa.Column("stocking_type", sa.Unicode(length=20), nullable=True),
        sa.Column("tier_level", sa.Unicode(length=20), nullable=True),
        sa.Column("source_system", sa.Unicode(length=20), nullable=True),
        sa.Column(
            "created_by", sa.Unicode(length=100), server_default=sa.text("'SYSTEM'"), nullable=False
        ),
        sa.Column(
            "created_dt",
            sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql"),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.Column(
            "updated_by", sa.Unicode(length=100), server_default=sa.text("'SYSTEM'"), nullable=False
        ),
        sa.Column(
            "updated_dt",
            sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql"),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("branch_code", "item_number", name="uq_mat_material_branch_item"),
        schema="mat",
    )
    op.create_table(
        "formulation_assistant",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("material_id", sa.Integer(), nullable=True),
        sa.Column("source_table", sa.Unicode(length=64), nullable=False),
        sa.Column("branch_code", sa.Unicode(length=12), nullable=True),
        sa.Column("item_number", sa.Unicode(length=40), nullable=True),
        sa.Column("ext_branch_code", sa.Unicode(length=12), nullable=True),
        sa.Column("ext_item_number", sa.Unicode(length=40), nullable=True),
        sa.Column("preference_code", sa.Unicode(length=40), nullable=True),
        sa.Column("last_in_cost", sa.Numeric(precision=20, scale=8), nullable=True),
        sa.Column("last_in_cost_v2", sa.Numeric(precision=20, scale=8), nullable=True),
        sa.Column("potency", sa.Numeric(precision=18, scale=8), nullable=True),
        sa.Column("potency_uom", sa.Unicode(length=20), nullable=True),
        sa.Column("item_status", sa.Unicode(length=40), nullable=True),
        sa.Column("stocking_type", sa.Unicode(length=20), nullable=True),
        sa.Column("tier_level", sa.Unicode(length=20), nullable=True),
        sa.Column("vendor_name", sa.Unicode(length=160), nullable=True),
        sa.Column("quantity_available", sa.Numeric(precision=20, scale=4), nullable=True),
        sa.Column("total_last_12_months", sa.Numeric(precision=20, scale=4), nullable=True),
        sa.Column("trademark", sa.Unicode(length=160), nullable=True),
        sa.Column("item_description_1", sa.Unicode(length=200), nullable=True),
        sa.Column("item_description_2", sa.Unicode(length=200), nullable=True),
        sa.Column("item_description", sa.Unicode(length=200), nullable=True),
        sa.Column("primary_uom", sa.Unicode(length=12), nullable=True),
        sa.Column("purchasing_uom", sa.Unicode(length=12), nullable=True),
        sa.Column("category", sa.Unicode(length=80), nullable=True),
        sa.Column("primary_plm_vendor", sa.Unicode(length=160), nullable=True),
        sa.Column("secondary_plm_vendor", sa.Unicode(length=160), nullable=True),
        sa.Column("unclassified_plm_vendor", sa.Unicode(length=160), nullable=True),
        sa.Column("has_allergen", sa.Boolean(), nullable=True),
        sa.Column(
            "source_built_at",
            sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql"),
            nullable=True,
        ),
        sa.Column(
            "refreshed_at",
            sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql"),
            nullable=False,
        ),
        sa.ForeignKeyConstraint(
            ["material_id"],
            ["mat.material.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        schema="mat",
    )
    op.create_index(
        "ix_mat_formulation_assistant_branch_item",
        "formulation_assistant",
        ["branch_code", "item_number"],
        unique=False,
        schema="mat",
    )
    op.create_index(
        op.f("ix_mat_formulation_assistant_material_id"),
        "formulation_assistant",
        ["material_id"],
        unique=False,
        schema="mat",
    )
    op.create_table(
        "item_jde_original",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("material_id", sa.Integer(), nullable=True),
        sa.Column("source_branch_code", sa.Unicode(length=12), nullable=False),
        sa.Column("source_item_number", sa.Unicode(length=40), nullable=False),
        sa.Column("source_julian_date", sa.BigInteger(), nullable=False),
        sa.Column("description_3", sa.Unicode(length=200), nullable=True),
        sa.Column("gl_posting_code", sa.Unicode(length=40), nullable=True),
        sa.Column("stocking_type", sa.Unicode(length=20), nullable=True),
        sa.Column("primary_uom", sa.Unicode(length=12), nullable=True),
        sa.Column("category_code", sa.Unicode(length=40), nullable=True),
        sa.Column("sld_value", sa.Integer(), nullable=True),
        sa.Column("ltlv_value", sa.Integer(), nullable=True),
        sa.Column("warr_value", sa.Unicode(length=80), nullable=True),
        sa.Column("unit_cost", sa.Numeric(precision=20, scale=8), nullable=True),
        sa.Column("lrgn_value", sa.Unicode(length=80), nullable=True),
        sa.ForeignKeyConstraint(
            ["material_id"],
            ["mat.material.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint(
            "source_branch_code",
            "source_item_number",
            "source_julian_date",
            name="uq_mat_item_jde_original_source",
        ),
        schema="mat",
    )
    op.create_index(
        op.f("ix_mat_item_jde_original_material_id"),
        "item_jde_original",
        ["material_id"],
        unique=False,
        schema="mat",
    )
    op.create_table(
        "item_spec",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("material_id", sa.Integer(), nullable=False),
        sa.Column("revision", sa.Integer(), nullable=False),
        sa.Column("review_status", sa.Unicode(length=40), nullable=True),
        sa.Column("allergen_status", sa.Unicode(length=20), nullable=True),
        sa.Column("appearance", sa.Unicode(length=200), nullable=True),
        sa.Column("color", sa.Unicode(length=100), nullable=True),
        sa.Column("item_type", sa.Unicode(length=80), nullable=True),
        sa.Column("physical_form", sa.Unicode(length=80), nullable=True),
        sa.Column("plm_item_status", sa.Unicode(length=40), nullable=True),
        sa.Column("item_class", sa.Unicode(length=80), nullable=True),
        sa.Column("icnt_code", sa.Unicode(length=40), nullable=True),
        sa.Column("major_rev", sa.Unicode(length=20), nullable=True),
        sa.Column("minor_rev", sa.Unicode(length=20), nullable=True),
        sa.Column("is_released", sa.Boolean(), nullable=True),
        sa.Column("plant_type", sa.Unicode(length=100), nullable=True),
        sa.Column("plant_extract_ratio", sa.Unicode(length=100), nullable=True),
        sa.Column("reference_note", sa.UnicodeText(), nullable=True),
        sa.Column("herbal_component_product_name", sa.Unicode(length=200), nullable=True),
        sa.Column("latin_name", sa.Unicode(length=200), nullable=True),
        sa.Column("trademark", sa.Unicode(length=160), nullable=True),
        sa.Column("analyte", sa.Unicode(length=160), nullable=True),
        sa.Column("potency", sa.Numeric(precision=18, scale=8), nullable=True),
        sa.Column("potency_uom", sa.Unicode(length=20), nullable=True),
        sa.Column("cas", sa.Unicode(length=80), nullable=True),
        sa.Column("minimum_capsule_wt", sa.Integer(), nullable=True),
        sa.Column("maximum_capsule_wt", sa.Integer(), nullable=True),
        sa.Column("average_capsule_wt", sa.Integer(), nullable=True),
        sa.Column("special_handling", sa.UnicodeText(), nullable=True),
        sa.Column("special_storage", sa.UnicodeText(), nullable=True),
        sa.Column("safety_information", sa.UnicodeText(), nullable=True),
        sa.Column("other_information", sa.UnicodeText(), nullable=True),
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql"),
            nullable=True,
        ),
        sa.Column("created_by", sa.Unicode(length=100), nullable=True),
        sa.Column(
            "modified_at",
            sa.DateTime(timezone=True).with_variant(mssql.DATETIME2(precision=3), "mssql"),
            nullable=True,
        ),
        sa.Column("modified_by", sa.Unicode(length=100), nullable=True),
        sa.ForeignKeyConstraint(
            ["material_id"],
            ["mat.material.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("material_id", "revision", name="uq_spec_item_spec_material_revision"),
        schema="spec",
    )
    op.create_index(
        op.f("ix_spec_item_spec_material_id"),
        "item_spec",
        ["material_id"],
        unique=False,
        schema="spec",
    )
    op.create_table(
        "item_allergen",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_spec_id", sa.Integer(), nullable=False),
        sa.Column("allergen_name", sa.Unicode(length=160), nullable=True),
        sa.Column("present_status", sa.Unicode(length=40), nullable=True),
        sa.Column("specific_allergen", sa.UnicodeText(), nullable=True),
        sa.Column("comments", sa.UnicodeText(), nullable=True),
        sa.ForeignKeyConstraint(
            ["item_spec_id"],
            ["spec.item_spec.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        schema="spec",
    )
    op.create_index(
        op.f("ix_spec_item_allergen_item_spec_id"),
        "item_allergen",
        ["item_spec_id"],
        unique=False,
        schema="spec",
    )
    op.create_table(
        "item_country",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_spec_id", sa.Integer(), nullable=False),
        sa.Column("country_name", sa.Unicode(length=160), nullable=True),
        sa.Column("country_abbv", sa.Unicode(length=40), nullable=True),
        sa.Column("material_type", sa.Unicode(length=80), nullable=True),
        sa.ForeignKeyConstraint(
            ["item_spec_id"],
            ["spec.item_spec.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        schema="spec",
    )
    op.create_index(
        op.f("ix_spec_item_country_item_spec_id"),
        "item_country",
        ["item_spec_id"],
        unique=False,
        schema="spec",
    )
    op.create_table(
        "item_property",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_spec_id", sa.Integer(), nullable=False),
        sa.Column("specification_type", sa.Unicode(length=120), nullable=True),
        sa.Column("property_type", sa.Unicode(length=120), nullable=True),
        sa.Column("property_name", sa.Unicode(length=200), nullable=True),
        sa.Column("minimum_value", sa.Unicode(length=120), nullable=True),
        sa.Column("target_value", sa.Unicode(length=120), nullable=True),
        sa.Column("maximum_value", sa.Unicode(length=120), nullable=True),
        sa.Column("unit_of_measure", sa.Unicode(length=40), nullable=True),
        sa.Column("result_value", sa.Unicode(length=120), nullable=True),
        sa.Column("test_frequency", sa.Unicode(length=120), nullable=True),
        sa.Column("test_method", sa.Unicode(length=200), nullable=True),
        sa.Column("report_status", sa.Unicode(length=20), nullable=True),
        sa.Column("coa_status", sa.Unicode(length=20), nullable=True),
        sa.Column("lab_status", sa.Unicode(length=20), nullable=True),
        sa.ForeignKeyConstraint(
            ["item_spec_id"],
            ["spec.item_spec.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        schema="spec",
    )
    op.create_index(
        op.f("ix_spec_item_property_item_spec_id"),
        "item_property",
        ["item_spec_id"],
        unique=False,
        schema="spec",
    )
    op.create_table(
        "item_regulatory_req",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_spec_id", sa.Integer(), nullable=False),
        sa.Column("halal_status", sa.Unicode(length=80), nullable=True),
        sa.Column("gmo_status", sa.Unicode(length=80), nullable=True),
        sa.Column("kosher_status", sa.Unicode(length=80), nullable=True),
        sa.Column("usp_pest_status", sa.Unicode(length=80), nullable=True),
        sa.Column("preservative_status", sa.Unicode(length=80), nullable=True),
        sa.Column("gluten_status", sa.Unicode(length=80), nullable=True),
        sa.Column("bse_status", sa.Unicode(length=80), nullable=True),
        sa.Column("non_novel_status", sa.Unicode(length=80), nullable=True),
        sa.Column("gras_status", sa.Unicode(length=80), nullable=True),
        sa.Column("vegetarian_status", sa.Unicode(length=80), nullable=True),
        sa.Column("vegan_status", sa.Unicode(length=80), nullable=True),
        sa.Column("organic_status", sa.Unicode(length=80), nullable=True),
        sa.Column("wada_status", sa.Unicode(length=80), nullable=True),
        sa.Column("ndi_status", sa.Unicode(length=80), nullable=True),
        sa.Column("synthetic_status", sa.Unicode(length=80), nullable=True),
        sa.Column("nsf_value", sa.Numeric(precision=18, scale=8), nullable=True),
        sa.Column("gluten_free_certified_status", sa.Unicode(length=80), nullable=True),
        sa.Column("fragrance_status", sa.Unicode(length=80), nullable=True),
        sa.Column("preference_code", sa.Unicode(length=80), nullable=True),
        sa.Column("bioengineered_status", sa.Unicode(length=80), nullable=True),
        sa.ForeignKeyConstraint(
            ["item_spec_id"],
            ["spec.item_spec.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        sa.UniqueConstraint("item_spec_id", name="uq_spec_item_regulatory_req_spec"),
        schema="spec",
    )
    op.create_table(
        "item_solvent",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_spec_id", sa.Integer(), nullable=False),
        sa.Column("ratio", sa.Unicode(length=80), nullable=True),
        sa.Column("solvent_type", sa.Unicode(length=80), nullable=True),
        sa.Column("solvent_name", sa.Unicode(length=160), nullable=True),
        sa.Column("solvent_number", sa.Unicode(length=80), nullable=True),
        sa.ForeignKeyConstraint(
            ["item_spec_id"],
            ["spec.item_spec.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        schema="spec",
    )
    op.create_index(
        op.f("ix_spec_item_solvent_item_spec_id"),
        "item_solvent",
        ["item_spec_id"],
        unique=False,
        schema="spec",
    )
    op.create_table(
        "item_vendor_part",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("item_spec_id", sa.Integer(), nullable=False),
        sa.Column("vendor_number", sa.Integer(), nullable=True),
        sa.Column("vendor_name", sa.Unicode(length=160), nullable=True),
        sa.Column("vendor_priority", sa.Unicode(length=40), nullable=True),
        sa.Column("vendor_part_number", sa.Unicode(length=100), nullable=True),
        sa.Column("manufacturer_part_number", sa.Unicode(length=100), nullable=True),
        sa.Column("manufacturer_part_name", sa.Unicode(length=200), nullable=True),
        sa.Column("manufacturer_name", sa.Unicode(length=160), nullable=True),
        sa.Column("country_name", sa.Unicode(length=160), nullable=True),
        sa.ForeignKeyConstraint(
            ["item_spec_id"],
            ["spec.item_spec.id"],
        ),
        sa.PrimaryKeyConstraint("id"),
        schema="spec",
    )
    op.create_index(
        op.f("ix_spec_item_vendor_part_item_spec_id"),
        "item_vendor_part",
        ["item_spec_id"],
        unique=False,
        schema="spec",
    )
    op.add_column(
        "formula_line", sa.Column("item_spec_id", sa.Integer(), nullable=True), schema="form"
    )
    op.create_foreign_key(
        LINE_ITEM_SPEC_FK,
        "formula_line",
        "item_spec",
        ["item_spec_id"],
        ["id"],
        source_schema="form",
        referent_schema="spec",
    )
    op.create_foreign_key(
        LINE_MATERIAL_FK,
        "formula_line",
        "material",
        ["material_id"],
        ["id"],
        source_schema="form",
        referent_schema="mat",
    )


def downgrade() -> None:
    raise RuntimeError("Downgrade requires an explicit data migration back to dbo.material")
