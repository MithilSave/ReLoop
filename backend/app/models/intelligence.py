"""Procurement intelligence and consignment models."""

import uuid
from datetime import date, datetime, timezone
from sqlalchemy import (
    Boolean,
    Column,
    Date,
    DateTime,
    Float,
    ForeignKey,
    Integer,
    JSON,
    SmallInteger,
    String,
    Text,
    UniqueConstraint,
    Uuid,
)
from sqlalchemy.orm import relationship

from app.core.database import Base


def utcnow():
    return datetime.now(timezone.utc)


class PricingAssumption(Base):
    __tablename__ = "pricing_assumptions"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    scope_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="SET NULL"), nullable=True)
    version = Column(Integer, default=1, nullable=False)
    transport_per_km = Column(Float, default=25.0, nullable=False)
    transport_per_kg_km = Column(Float, default=0.05, nullable=False)
    sorting_per_kg = Column(Float, default=2.50, nullable=False)
    handling_per_kg = Column(Float, default=1.00, nullable=False)
    storage_per_kg_day = Column(Float, default=0.20, nullable=False)
    default_rejection_rate = Column(JSON, default=lambda: {"PET": 0.05, "HDPE": 0.04, "PP": 0.06, "LDPE": 0.08}, nullable=False)
    default_process_loss_rate = Column(JSON, default=lambda: {"PET": 0.12, "HDPE": 0.10, "PP": 0.14, "LDPE": 0.15}, nullable=False)
    rejection_cost_per_kg = Column(Float, default=1.50, nullable=False)
    effective_from = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)


class RecyclerDemandProfile(Base):
    __tablename__ = "recycler_demand_profiles"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), nullable=False, index=True)
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="RESTRICT"), nullable=False, index=True)
    recurrence = Column(String(32), default="ONE_OFF", nullable=False)  # ONE_OFF, WEEKLY, MONTHLY
    quantity_kg = Column(Float, nullable=False)
    min_lot_kg = Column(Float, default=50.0, nullable=False)
    min_quality_grade = Column(String(16), default="B", nullable=False)
    max_contamination_pct = Column(Float, default=10.0, nullable=False)
    period_start = Column(DateTime(timezone=True), nullable=True)
    period_end = Column(DateTime(timezone=True), nullable=True)
    need_by = Column(Date, nullable=True)
    current_inventory_kg = Column(Float, nullable=True)
    storage_headroom_kg = Column(Float, nullable=True)
    target_landed_cost_per_kg = Column(Float, nullable=True)
    status = Column(String(32), default="ACTIVE", nullable=False)  # ACTIVE, PAUSED, CLOSED
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    recycler_org = relationship("Organisation")
    material_category = relationship("MaterialCategory")


class GeneratorSupplyProfile(Base):
    __tablename__ = "generator_supply_profiles"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    generator_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), nullable=False, index=True)
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="RESTRICT"), nullable=False, index=True)
    recurrence = Column(String(32), default="WEEKLY", nullable=False)  # WEEKLY, FORTNIGHTLY, MONTHLY
    typical_kg = Column(Float, nullable=False)
    preferred_weekday = Column(SmallInteger, nullable=True)  # 0=Monday ... 6=Sunday
    pickup_window = Column(String(64), nullable=True)
    is_active = Column(Boolean, default=True, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    generator_org = relationship("Organisation")
    material_category = relationship("MaterialCategory")


class AggregationPlan(Base):
    __tablename__ = "aggregation_plans"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    plan_code = Column(String(64), unique=True, nullable=False, index=True)
    recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    demand_profile_id = Column(Uuid, ForeignKey("recycler_demand_profiles.id", ondelete="SET NULL"), nullable=True)
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="RESTRICT"), nullable=False, index=True)
    target_kg = Column(Float, nullable=False)
    suggested_collector_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="SET NULL"), nullable=True, index=True)
    est_total_kg = Column(Float, default=0.0, nullable=False)
    est_usable_kg = Column(Float, default=0.0, nullable=False)
    fulfils_requirement = Column(Boolean, default=False, nullable=False)
    shortfall_kg = Column(Float, default=0.0, nullable=False)
    cost_estimate_id = Column(Uuid, nullable=True)
    status = Column(String(32), default="PROPOSED", nullable=False, index=True)  # DRAFT, PROPOSED, ACCEPTED, ACTIVE, COMPLETED, CANCELLED
    recycler_accepted_by = Column(Uuid, nullable=True)
    recycler_accepted_at = Column(DateTime(timezone=True), nullable=True)
    collector_accepted_by = Column(Uuid, nullable=True)
    collector_accepted_at = Column(DateTime(timezone=True), nullable=True)
    explanation = Column(JSON, default=dict, nullable=False)
    excluded = Column(JSON, default=list, nullable=False)
    algorithm_version = Column(String(32), default="greedy_v1", nullable=False)
    assumptions_version = Column(Integer, default=1, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    recycler_org = relationship("Organisation", foreign_keys=[recycler_org_id])
    collector_org = relationship("Organisation", foreign_keys=[suggested_collector_org_id])
    material_category = relationship("MaterialCategory")
    items = relationship("AggregationPlanItem", back_populates="plan", cascade="all, delete-orphan")


class AggregationPlanItem(Base):
    __tablename__ = "aggregation_plan_items"

    plan_id = Column(Uuid, ForeignKey("aggregation_plans.id", ondelete="CASCADE"), primary_key=True)
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="RESTRICT"), primary_key=True)
    sequence_no = Column(Integer, default=1, nullable=False)
    planned_kg = Column(Float, nullable=False)
    est_usable_kg = Column(Float, nullable=False)
    distance_km = Column(Float, default=0.0, nullable=False)
    reasons = Column(JSON, default=dict, nullable=False)
    item_status = Column(String(32), default="PROPOSED", nullable=False)  # PROPOSED, GENERATOR_ACCEPTED, DECLINED, COLLECTED, DROPPED

    plan = relationship("AggregationPlan", back_populates="items")
    batch = relationship("WasteBatch")


class TransportConsignment(Base):
    __tablename__ = "transport_consignments"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    consignment_code = Column(String(64), unique=True, nullable=False, index=True)
    collector_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    destination_recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="RESTRICT"), nullable=False, index=True)
    aggregation_plan_id = Column(Uuid, ForeignKey("aggregation_plans.id", ondelete="SET NULL"), nullable=True)
    vehicle_no = Column(String(64), nullable=True)
    dispatched_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)
    arrived_at = Column(DateTime(timezone=True), nullable=True)
    status = Column(String(32), default="IN_TRANSIT", nullable=False, index=True)  # LOADING, IN_TRANSIT, ARRIVED, CLOSED
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    collector_org = relationship("Organisation", foreign_keys=[collector_org_id])
    recycler_org = relationship("Organisation", foreign_keys=[destination_recycler_org_id])
    items = relationship("ConsignmentItem", back_populates="consignment", cascade="all, delete-orphan")


class ConsignmentItem(Base):
    __tablename__ = "consignment_items"

    consignment_id = Column(Uuid, ForeignKey("transport_consignments.id", ondelete="CASCADE"), primary_key=True)
    batch_id = Column(Uuid, ForeignKey("waste_batches.id", ondelete="RESTRICT"), primary_key=True, unique=True)

    consignment = relationship("TransportConsignment", back_populates="items")
    batch = relationship("WasteBatch")


class CostEstimate(Base):
    __tablename__ = "cost_estimates"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    subject_type = Column(String(32), default="PLAN", nullable=False)  # PLAN, BATCH, COMPARISON
    subject_id = Column(Uuid, nullable=True)
    recycler_org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="SET NULL"), nullable=True)
    assumptions_id = Column(Uuid, ForeignKey("pricing_assumptions.id", ondelete="SET NULL"), nullable=True)
    est_kg = Column(Float, nullable=False)
    expected_rejection_kg = Column(Float, default=0.0, nullable=False)
    expected_process_loss_kg = Column(Float, default=0.0, nullable=False)
    expected_usable_kg = Column(Float, nullable=False)
    generator_payment = Column(Float, default=0.0, nullable=False)
    collector_charge = Column(Float, default=0.0, nullable=False)
    transport_cost = Column(Float, default=0.0, nullable=False)
    sorting_cost = Column(Float, default=0.0, nullable=False)
    handling_cost = Column(Float, default=0.0, nullable=False)
    storage_cost = Column(Float, default=0.0, nullable=False)
    rejection_cost = Column(Float, default=0.0, nullable=False)
    total_cost = Column(Float, default=0.0, nullable=False)
    landed_cost_per_usable_kg = Column(Float, default=0.0, nullable=False)
    generator_receives = Column(Float, default=0.0, nullable=False)
    collector_expected_earnings = Column(Float, default=0.0, nullable=False)
    transport_borne_by = Column(String(32), default="RECYCLER", nullable=False)  # COLLECTOR, RECYCLER
    breakdown = Column(JSON, default=dict, nullable=False)
    created_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)


class SupplierPerformanceMetric(Base):
    __tablename__ = "supplier_performance_metrics"
    __table_args__ = (
        UniqueConstraint("org_id", "role", "material_category_id", "window", name="uq_supplier_metric"),
    )

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="CASCADE"), nullable=False, index=True)
    role = Column(String(32), nullable=False)  # GENERATOR, COLLECTOR
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="SET NULL"), nullable=True)
    window = Column(String(16), default="ALL", nullable=False)  # D180, ALL
    n_transactions = Column(Integer, default=0, nullable=False)
    fulfilment_rate = Column(Float, nullable=True)
    on_time_rate = Column(Float, nullable=True)
    weight_discrepancy_pct = Column(Float, nullable=True)
    rejection_rate = Column(Float, nullable=True)
    contamination_rate = Column(Float, nullable=True)
    completion_rate = Column(Float, nullable=True)
    history_level = Column(String(32), default="INSUFFICIENT", nullable=False)  # INSUFFICIENT, LIMITED, SUFFICIENT
    computed_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)

    org = relationship("Organisation")


class Forecast(Base):
    __tablename__ = "forecasts"

    id = Column(Uuid, primary_key=True, default=uuid.uuid4)
    kind = Column(String(32), nullable=False, index=True)  # SUPPLY, DEMAND
    org_id = Column(Uuid, ForeignKey("organisations.id", ondelete="SET NULL"), nullable=True, index=True)
    locality = Column(String(128), nullable=True, index=True)
    material_category_id = Column(SmallInteger, ForeignKey("material_categories.id", ondelete="SET NULL"), nullable=True, index=True)
    period_start = Column(DateTime(timezone=True), nullable=False)
    period_end = Column(DateTime(timezone=True), nullable=False)
    predicted_kg = Column(Float, nullable=False)
    lower_kg = Column(Float, nullable=False)
    upper_kg = Column(Float, nullable=False)
    method = Column(String(64), default="moving_average_v1", nullable=False)
    n_history_points = Column(Integer, default=0, nullable=False)
    confidence_label = Column(String(16), default="MEDIUM", nullable=False)  # LOW, MEDIUM, HIGH
    generated_at = Column(DateTime(timezone=True), default=utcnow, nullable=False)
