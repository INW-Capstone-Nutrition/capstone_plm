from __future__ import annotations

from datetime import datetime
from decimal import Decimal

from sqlalchemy import Boolean, ForeignKey, Numeric, Unicode, UnicodeText, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column

from api.database import AUDIT_DATETIME, Base


class ItemSpec(Base):
    __tablename__ = "item_spec"
    __table_args__ = (
        UniqueConstraint("material_id", "revision", name="uq_spec_item_spec_material_revision"),
        {"schema": "spec"},
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    material_id: Mapped[int] = mapped_column(ForeignKey("mat.material.id"), index=True)
    revision: Mapped[int] = mapped_column(default=1)
    review_status: Mapped[str | None] = mapped_column(Unicode(40))
    allergen_status: Mapped[str | None] = mapped_column(Unicode(20))
    appearance: Mapped[str | None] = mapped_column(Unicode(200))
    color: Mapped[str | None] = mapped_column(Unicode(100))
    item_type: Mapped[str | None] = mapped_column(Unicode(80))
    physical_form: Mapped[str | None] = mapped_column(Unicode(80))
    plm_item_status: Mapped[str | None] = mapped_column(Unicode(40))
    item_class: Mapped[str | None] = mapped_column(Unicode(80))
    icnt_code: Mapped[str | None] = mapped_column(Unicode(40))
    major_rev: Mapped[str | None] = mapped_column(Unicode(20))
    minor_rev: Mapped[str | None] = mapped_column(Unicode(20))
    is_released: Mapped[bool | None] = mapped_column(Boolean)
    plant_type: Mapped[str | None] = mapped_column(Unicode(100))
    plant_extract_ratio: Mapped[str | None] = mapped_column(Unicode(100))
    reference_note: Mapped[str | None] = mapped_column(UnicodeText)
    herbal_component_product_name: Mapped[str | None] = mapped_column(Unicode(200))
    latin_name: Mapped[str | None] = mapped_column(Unicode(200))
    trademark: Mapped[str | None] = mapped_column(Unicode(160))
    analyte: Mapped[str | None] = mapped_column(Unicode(160))
    potency: Mapped[Decimal | None] = mapped_column(Numeric(24, 8))
    potency_uom: Mapped[str | None] = mapped_column(Unicode(20))
    cas: Mapped[str | None] = mapped_column(Unicode(80))
    minimum_capsule_wt: Mapped[int | None]
    maximum_capsule_wt: Mapped[int | None]
    average_capsule_wt: Mapped[int | None]
    special_handling: Mapped[str | None] = mapped_column(UnicodeText)
    special_storage: Mapped[str | None] = mapped_column(UnicodeText)
    safety_information: Mapped[str | None] = mapped_column(UnicodeText)
    other_information: Mapped[str | None] = mapped_column(UnicodeText)
    created_at: Mapped[datetime | None] = mapped_column(AUDIT_DATETIME)
    created_by: Mapped[str | None] = mapped_column(Unicode(100))
    modified_at: Mapped[datetime | None] = mapped_column(AUDIT_DATETIME)
    modified_by: Mapped[str | None] = mapped_column(Unicode(100))

class ItemRegulatoryReq(Base):
    __tablename__ = "item_regulatory_req"
    __table_args__ = (
        UniqueConstraint("item_spec_id", name="uq_spec_item_regulatory_req_spec"),
        {"schema": "spec"},
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    item_spec_id: Mapped[int] = mapped_column(ForeignKey("spec.item_spec.id"))
    halal_status: Mapped[str | None] = mapped_column(Unicode(80))
    gmo_status: Mapped[str | None] = mapped_column(Unicode(80))
    kosher_status: Mapped[str | None] = mapped_column(Unicode(80))
    usp_pest_status: Mapped[str | None] = mapped_column(Unicode(80))
    preservative_status: Mapped[str | None] = mapped_column(Unicode(80))
    gluten_status: Mapped[str | None] = mapped_column(Unicode(80))
    bse_status: Mapped[str | None] = mapped_column(Unicode(80))
    non_novel_status: Mapped[str | None] = mapped_column(Unicode(80))
    gras_status: Mapped[str | None] = mapped_column(Unicode(80))
    vegetarian_status: Mapped[str | None] = mapped_column(Unicode(80))
    vegan_status: Mapped[str | None] = mapped_column(Unicode(80))
    organic_status: Mapped[str | None] = mapped_column(Unicode(80))
    wada_status: Mapped[str | None] = mapped_column(Unicode(80))
    ndi_status: Mapped[str | None] = mapped_column(Unicode(80))
    synthetic_status: Mapped[str | None] = mapped_column(Unicode(80))
    nsf_value: Mapped[Decimal | None] = mapped_column(Numeric(18, 8))
    gluten_free_certified_status: Mapped[str | None] = mapped_column(Unicode(80))
    fragrance_status: Mapped[str | None] = mapped_column(Unicode(80))
    preference_code: Mapped[str | None] = mapped_column(Unicode(80))
    bioengineered_status: Mapped[str | None] = mapped_column(Unicode(80))


class ItemAllergen(Base):
    __tablename__ = "item_allergen"
    __table_args__ = {"schema": "spec"}

    id: Mapped[int] = mapped_column(primary_key=True)
    item_spec_id: Mapped[int] = mapped_column(ForeignKey("spec.item_spec.id"), index=True)
    allergen_name: Mapped[str | None] = mapped_column(Unicode(160))
    present_status: Mapped[str | None] = mapped_column(Unicode(40))
    specific_allergen: Mapped[str | None] = mapped_column(UnicodeText)
    comments: Mapped[str | None] = mapped_column(UnicodeText)


class ItemCountry(Base):
    __tablename__ = "item_country"
    __table_args__ = {"schema": "spec"}

    id: Mapped[int] = mapped_column(primary_key=True)
    item_spec_id: Mapped[int] = mapped_column(ForeignKey("spec.item_spec.id"), index=True)
    country_name: Mapped[str | None] = mapped_column(Unicode(160))
    country_abbv: Mapped[str | None] = mapped_column(Unicode(40))
    material_type: Mapped[str | None] = mapped_column(Unicode(80))


class ItemProperty(Base):
    __tablename__ = "item_property"
    __table_args__ = {"schema": "spec"}

    id: Mapped[int] = mapped_column(primary_key=True)
    item_spec_id: Mapped[int] = mapped_column(ForeignKey("spec.item_spec.id"), index=True)
    specification_type: Mapped[str | None] = mapped_column(Unicode(120))
    property_type: Mapped[str | None] = mapped_column(Unicode(120))
    property_name: Mapped[str | None] = mapped_column(Unicode(200))
    minimum_value: Mapped[str | None] = mapped_column(Unicode(120))
    target_value: Mapped[str | None] = mapped_column(Unicode(120))
    maximum_value: Mapped[str | None] = mapped_column(Unicode(120))
    unit_of_measure: Mapped[str | None] = mapped_column(Unicode(40))
    result_value: Mapped[str | None] = mapped_column(Unicode(120))
    test_frequency: Mapped[str | None] = mapped_column(Unicode(120))
    test_method: Mapped[str | None] = mapped_column(Unicode(200))
    report_status: Mapped[str | None] = mapped_column(Unicode(20))
    coa_status: Mapped[str | None] = mapped_column(Unicode(20))
    lab_status: Mapped[str | None] = mapped_column(Unicode(20))


class ItemSolvent(Base):
    __tablename__ = "item_solvent"
    __table_args__ = {"schema": "spec"}

    id: Mapped[int] = mapped_column(primary_key=True)
    item_spec_id: Mapped[int] = mapped_column(ForeignKey("spec.item_spec.id"), index=True)
    ratio: Mapped[str | None] = mapped_column(Unicode(80))
    solvent_type: Mapped[str | None] = mapped_column(Unicode(80))
    solvent_name: Mapped[str | None] = mapped_column(Unicode(160))
    solvent_number: Mapped[str | None] = mapped_column(Unicode(80))


class ItemVendorPart(Base):
    __tablename__ = "item_vendor_part"
    __table_args__ = {"schema": "spec"}

    id: Mapped[int] = mapped_column(primary_key=True)
    item_spec_id: Mapped[int] = mapped_column(ForeignKey("spec.item_spec.id"), index=True)
    vendor_number: Mapped[int | None]
    vendor_name: Mapped[str | None] = mapped_column(Unicode(160))
    vendor_priority: Mapped[str | None] = mapped_column(Unicode(40))
    vendor_part_number: Mapped[str | None] = mapped_column(Unicode(100))
    manufacturer_part_number: Mapped[str | None] = mapped_column(Unicode(100))
    manufacturer_part_name: Mapped[str | None] = mapped_column(Unicode(200))
    manufacturer_name: Mapped[str | None] = mapped_column(Unicode(160))
    country_name: Mapped[str | None] = mapped_column(Unicode(160))
