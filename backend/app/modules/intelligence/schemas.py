"""Procurement intelligence schemas."""

import uuid
from datetime import date, datetime
from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field


class ProposePlanInput(BaseModel):
    demand_profile_id: Optional[uuid.UUID] = None
    material_code: Optional[str] = None
    target_kg: Optional[float] = Field(None, gt=0)
    need_by: Optional[date] = None
    max_distance_km: Optional[float] = 30.0


class CostEstimateInput(BaseModel):
    subject_type: str = "BATCH"  # PLAN, BATCH, COMPARISON
    subject_id: Optional[uuid.UUID] = None
    est_kg: float = Field(..., gt=0)
    material_code: str = "PET"
    distance_km: float = 15.0
    assumptions_version: Optional[int] = None


class CompareOption(BaseModel):
    type: str  # BATCH, COLLECTOR, PLAN, COMBINATION
    ids: List[uuid.UUID] = []
    name: Optional[str] = None
    est_kg: float = 100.0
    material_code: str = "PET"
    distance_km: float = 15.0


class CostCompareInput(BaseModel):
    options: List[CompareOption]


class DemandProfileCreateInput(BaseModel):
    material_code: str
    recurrence: str = "ONE_OFF"  # ONE_OFF, WEEKLY, MONTHLY
    quantity_kg: float = Field(..., gt=0)
    min_lot_kg: float = 50.0
    min_quality_grade: str = "B"
    max_contamination_pct: float = 10.0
    need_by: Optional[date] = None
    target_landed_cost_per_kg: Optional[float] = None


class SupplyProfileCreateInput(BaseModel):
    material_code: str
    recurrence: str = "WEEKLY"  # WEEKLY, FORTNIGHTLY, MONTHLY
    typical_kg: float = Field(..., gt=0)
    preferred_weekday: Optional[int] = 1  # 0=Monday ... 6=Sunday
    pickup_window: Optional[str] = "10:00 - 14:00"


class PricingAssumptionsInput(BaseModel):
    transport_per_km: float = 25.0
    transport_per_kg_km: float = 0.05
    sorting_per_kg: float = 2.50
    handling_per_kg: float = 1.00
    storage_per_kg_day: float = 0.20
    rejection_cost_per_kg: float = 1.50
    default_rejection_rate: Optional[Dict[str, float]] = None
    default_process_loss_rate: Optional[Dict[str, float]] = None
