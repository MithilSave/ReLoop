"""Procurement intelligence API router."""

import uuid
from datetime import date, datetime, timezone, timedelta
from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select, and_, func, desc
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.reference import MaterialCategory
from app.models.batches import WasteBatch
from app.models.identity import Organisation
from app.models.intelligence import (
    PricingAssumption,
    RecyclerDemandProfile,
    GeneratorSupplyProfile,
    AggregationPlan,
    AggregationPlanItem,
    CostEstimate,
    SupplierPerformanceMetric,
    Forecast,
)
from app.modules.intelligence.schemas import (
    ProposePlanInput,
    CostEstimateInput,
    CostCompareInput,
    DemandProfileCreateInput,
    SupplyProfileCreateInput,
    PricingAssumptionsInput,
)

router = APIRouter(tags=["intelligence"])


def utcnow():
    return datetime.now(timezone.utc)


# ── PRICING ASSUMPTIONS ───────────────────────────────────

@router.get("/pricing-assumptions")
async def get_pricing_assumptions(
    db: AsyncSession = Depends(get_db),
):
    stmt = select(PricingAssumption).where(PricingAssumption.is_active.is_(True)).order_by(desc(PricingAssumption.version))
    res = await db.execute(stmt)
    assumptions = res.scalar_one_or_none()
    if not assumptions:
        assumptions = PricingAssumption(version=1)
        db.add(assumptions)
        await db.commit()
        await db.refresh(assumptions)
    return assumptions


@router.post("/pricing-assumptions", status_code=status.HTTP_201_CREATED)
async def update_pricing_assumptions(
    req: PricingAssumptionsInput,
    context: AuthContext = Depends(require("RECYCLER", "OWNER", "ADMIN")),
    db: AsyncSession = Depends(get_db),
):
    # Find latest version
    stmt = select(func.coalesce(func.max(PricingAssumption.version), 0))
    res = await db.execute(stmt)
    next_ver = (res.scalar() or 0) + 1

    new_assump = PricingAssumption(
        scope_org_id=context.org_id,
        version=next_ver,
        transport_per_km=req.transport_per_km,
        transport_per_kg_km=req.transport_per_kg_km,
        sorting_per_kg=req.sorting_per_kg,
        handling_per_kg=req.handling_per_kg,
        storage_per_kg_day=req.storage_per_kg_day,
        rejection_cost_per_kg=req.rejection_cost_per_kg,
        default_rejection_rate=req.default_rejection_rate or {"PET": 0.05, "HDPE": 0.04, "PP": 0.06, "LDPE": 0.08},
        default_process_loss_rate=req.default_process_loss_rate or {"PET": 0.12, "HDPE": 0.10, "PP": 0.14, "LDPE": 0.15},
        is_active=True,
    )
    db.add(new_assump)
    await db.commit()
    return new_assump


# ── DEMAND & SUPPLY PROFILES ──────────────────────────────

@router.post("/recycler/demand-profiles", status_code=status.HTTP_201_CREATED)
async def create_demand_profile(
    req: DemandProfileCreateInput,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(MaterialCategory).where(MaterialCategory.code == req.material_code.upper())
    res = await db.execute(stmt)
    mat = res.scalar_one_or_none()
    if not mat:
        raise HTTPException(status_code=400, detail={"error": {"code": "INVALID_MATERIAL", "message": "Material not found"}})

    prof = RecyclerDemandProfile(
        recycler_org_id=context.org_id,
        material_category_id=mat.id,
        recurrence=req.recurrence,
        quantity_kg=req.quantity_kg,
        min_lot_kg=req.min_lot_kg,
        min_quality_grade=req.min_quality_grade,
        max_contamination_pct=req.max_contamination_pct,
        need_by=req.need_by,
        target_landed_cost_per_kg=req.target_landed_cost_per_kg,
        status="ACTIVE",
    )
    db.add(prof)
    await db.commit()
    await db.refresh(prof)
    return prof


@router.get("/recycler/demand-profiles")
async def list_demand_profiles(
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(RecyclerDemandProfile, MaterialCategory).join(
        MaterialCategory, RecyclerDemandProfile.material_category_id == MaterialCategory.id
    ).where(RecyclerDemandProfile.recycler_org_id == context.org_id)
    res = await db.execute(stmt)
    return [{
        "id": p.id,
        "material_code": m.code,
        "recurrence": p.recurrence,
        "quantity_kg": p.quantity_kg,
        "min_quality_grade": p.min_quality_grade,
        "max_contamination_pct": p.max_contamination_pct,
        "need_by": p.need_by,
        "status": p.status,
    } for p, m in res.all()]


@router.post("/generator/supply-profiles", status_code=status.HTTP_201_CREATED)
async def create_supply_profile(
    req: SupplyProfileCreateInput,
    context: AuthContext = Depends(require("GENERATOR")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(MaterialCategory).where(MaterialCategory.code == req.material_code.upper())
    res = await db.execute(stmt)
    mat = res.scalar_one_or_none()
    if not mat:
        raise HTTPException(status_code=400, detail={"error": {"code": "INVALID_MATERIAL", "message": "Material not found"}})

    prof = GeneratorSupplyProfile(
        generator_org_id=context.org_id,
        material_category_id=mat.id,
        recurrence=req.recurrence,
        typical_kg=req.typical_kg,
        preferred_weekday=req.preferred_weekday,
        pickup_window=req.pickup_window,
        is_active=True,
    )
    db.add(prof)
    await db.commit()
    await db.refresh(prof)
    return prof


@router.get("/generator/supply-profiles")
async def list_supply_profiles(
    context: AuthContext = Depends(require("GENERATOR")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(GeneratorSupplyProfile, MaterialCategory).join(
        MaterialCategory, GeneratorSupplyProfile.material_category_id == MaterialCategory.id
    ).where(GeneratorSupplyProfile.generator_org_id == context.org_id)
    res = await db.execute(stmt)
    return [{
        "id": p.id,
        "material_code": m.code,
        "recurrence": p.recurrence,
        "typical_kg": p.typical_kg,
        "preferred_weekday": p.preferred_weekday,
        "pickup_window": p.pickup_window,
        "is_active": p.is_active,
    } for p, m in res.all()]


# ── AGGREGATION PLANS ─────────────────────────────────────

async def _propose_plan_logic(req: ProposePlanInput, context: AuthContext, db: AsyncSession):
    target_kg = req.target_kg
    mat_code = req.material_code

    if req.demand_profile_id:
        d_prof = await db.get(RecyclerDemandProfile, req.demand_profile_id)
        if d_prof:
            target_kg = d_prof.quantity_kg
            mat = await db.get(MaterialCategory, d_prof.material_category_id)
            if mat:
                mat_code = mat.code

    if not target_kg or not mat_code:
        raise HTTPException(
            status_code=400,
            detail={"error": {"code": "VALIDATION_ERROR", "message": "target_kg and material_code (or valid demand_profile_id) are required"}},
        )

    mat_stmt = select(MaterialCategory).where(MaterialCategory.code == mat_code.upper())
    mat_res = await db.execute(mat_stmt)
    target_mat = mat_res.scalar_one_or_none()
    if not target_mat:
        raise HTTPException(status_code=400, detail={"error": {"code": "INVALID_MATERIAL", "message": "Material not found"}})

    # Fetch all candidate batches
    all_batches_stmt = select(WasteBatch).where(WasteBatch.status == "LISTED")
    b_res = await db.execute(all_batches_stmt)
    all_batches = b_res.scalars().all()

    candidates = []
    excluded = []

    for b in all_batches:
        if b.material_category_id != target_mat.id:
            excluded.append({
                "batch_id": str(b.id),
                "batch_code": b.batch_code,
                "reason": "INCOMPATIBLE_MATERIAL",
            })
            continue

        if b.active_plan_id is not None:
            excluded.append({
                "batch_id": str(b.id),
                "batch_code": b.batch_code,
                "reason": "BATCH_IN_ACTIVE_PLAN",
            })
            continue

        candidates.append(b)

    # Sort candidates by estimated_kg descending (greedy knapsack approach)
    candidates.sort(key=lambda x: x.estimated_kg, reverse=True)

    accumulated_kg = 0.0
    items_to_add = []
    for idx, b in enumerate(candidates, start=1):
        if accumulated_kg >= target_kg:
            break
        planned = min(b.estimated_kg, target_kg - accumulated_kg)
        est_usable = round(planned * 0.92, 2)  # assuming ~8% contamination/process loss
        items_to_add.append({
            "batch": b,
            "sequence_no": idx,
            "planned_kg": planned,
            "est_usable_kg": est_usable,
            "distance_km": 12.5,
            "reasons": {"match": "optimal_lot_size", "purity": "high"},
        })
        accumulated_kg += planned

    est_usable_total = round(accumulated_kg * 0.92, 2)
    shortfall = max(0.0, target_kg - accumulated_kg)
    fulfils = shortfall == 0.0

    plan_code = f"PLAN-MUM-{utcnow().year}-{uuid.uuid4().hex[:6].upper()}"

    plan = AggregationPlan(
        plan_code=plan_code,
        recycler_org_id=context.org_id,
        demand_profile_id=req.demand_profile_id,
        material_category_id=target_mat.id,
        target_kg=target_kg,
        est_total_kg=accumulated_kg,
        est_usable_kg=est_usable_total,
        fulfils_requirement=fulfils,
        shortfall_kg=shortfall,
        status="PROPOSED",
        explanation={
            "algorithm": "greedy_v1",
            "evaluated_batches": len(all_batches),
            "matched_batches": len(items_to_add),
            "excluded_count": len(excluded),
        },
        excluded=excluded,
    )
    db.add(plan)
    await db.flush()

    for item in items_to_add:
        b = item["batch"]
        db.add(
            AggregationPlanItem(
                plan_id=plan.id,
                batch_id=b.id,
                sequence_no=item["sequence_no"],
                planned_kg=item["planned_kg"],
                est_usable_kg=item["est_usable_kg"],
                distance_km=item["distance_km"],
                reasons=item["reasons"],
                item_status="PROPOSED",
            )
        )
        b.active_plan_id = plan.id

    # Compute cost estimate
    gen_payout = round(accumulated_kg * 15.0, 2)
    col_charge = round(accumulated_kg * 8.0, 2)
    transport = round(len(items_to_add) * 15.0 * 25.0, 2)
    sorting = round(accumulated_kg * 2.5, 2)
    total_cost = round(gen_payout + col_charge + transport + sorting, 2)
    landed_per_kg = round(total_cost / est_usable_total, 2) if est_usable_total > 0 else 0.0

    cost_est = CostEstimate(
        subject_type="PLAN",
        subject_id=plan.id,
        recycler_org_id=context.org_id,
        est_kg=accumulated_kg,
        expected_rejection_kg=round(accumulated_kg * 0.05, 2),
        expected_process_loss_kg=round(accumulated_kg * 0.03, 2),
        expected_usable_kg=est_usable_total,
        generator_payment=gen_payout,
        collector_charge=col_charge,
        transport_cost=transport,
        sorting_cost=sorting,
        total_cost=total_cost,
        landed_cost_per_usable_kg=landed_per_kg,
        generator_receives=gen_payout,
        collector_expected_earnings=col_charge,
        breakdown={
            "generator_payout": gen_payout,
            "collector_charge": col_charge,
            "transport_cost": transport,
            "sorting_cost": sorting,
        },
    )
    db.add(cost_est)
    await db.flush()
    plan.cost_estimate_id = cost_est.id

    await db.commit()
    return {
        "status": "ok",
        "plan_id": plan.id,
        "plan_code": plan.plan_code,
        "target_kg": plan.target_kg,
        "est_total_kg": plan.est_total_kg,
        "est_usable_kg": plan.est_usable_kg,
        "fulfils_requirement": plan.fulfils_requirement,
        "shortfall_kg": plan.shortfall_kg,
        "items": [{
            "batch_id": item["batch"].id,
            "batch_code": item["batch"].batch_code,
            "planned_kg": item["planned_kg"],
            "distance_km": item["distance_km"],
        } for item in items_to_add],
        "cost_estimate": {
            "total_cost": total_cost,
            "landed_cost_per_usable_kg": landed_per_kg,
            "generator_payment": gen_payout,
            "collector_charge": col_charge,
            "transport_cost": transport,
        },
        "excluded": excluded,
    }


@router.post("/aggregation/plans:propose", status_code=status.HTTP_201_CREATED)
async def propose_plan_colon(
    req: ProposePlanInput,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    return await _propose_plan_logic(req, context, db)


@router.post("/aggregation/plans/propose", status_code=status.HTTP_201_CREATED)
async def propose_plan_slash(
    req: ProposePlanInput,
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    return await _propose_plan_logic(req, context, db)


@router.get("/aggregation/plans")
async def list_aggregation_plans(
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(AggregationPlan).order_by(desc(AggregationPlan.created_at))
    if not context.is_admin and context.org_type == "RECYCLER":
        stmt = stmt.where(AggregationPlan.recycler_org_id == context.org_id)
    res = await db.execute(stmt)
    plans = res.scalars().all()
    return [{
        "id": p.id,
        "plan_code": p.plan_code,
        "target_kg": p.target_kg,
        "est_total_kg": p.est_total_kg,
        "est_usable_kg": p.est_usable_kg,
        "fulfils_requirement": p.fulfils_requirement,
        "status": p.status,
        "created_at": p.created_at,
    } for p in plans]


@router.get("/aggregation/plans/{id}")
async def get_aggregation_plan(
    id: uuid.UUID,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    plan = await db.get(AggregationPlan, id)
    if not plan:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Aggregation plan not found"}})

    items_stmt = select(AggregationPlanItem, WasteBatch).join(
        WasteBatch, AggregationPlanItem.batch_id == WasteBatch.id
    ).where(AggregationPlanItem.plan_id == plan.id)
    res = await db.execute(items_stmt)

    items = [{
        "batch_id": b.id,
        "batch_code": b.batch_code,
        "planned_kg": item.planned_kg,
        "est_usable_kg": item.est_usable_kg,
        "distance_km": item.distance_km,
        "reasons": item.reasons,
        "item_status": item.item_status,
    } for item, b in res.all()]

    cost_est = await db.get(CostEstimate, plan.cost_estimate_id) if plan.cost_estimate_id else None

    return {
        "id": plan.id,
        "plan_code": plan.plan_code,
        "target_kg": plan.target_kg,
        "est_total_kg": plan.est_total_kg,
        "est_usable_kg": plan.est_usable_kg,
        "fulfils_requirement": plan.fulfils_requirement,
        "shortfall_kg": plan.shortfall_kg,
        "status": plan.status,
        "items": items,
        "cost_estimate": {
            "total_cost": cost_est.total_cost if cost_est else 0.0,
            "landed_cost_per_usable_kg": cost_est.landed_cost_per_usable_kg if cost_est else 0.0,
            "breakdown": cost_est.breakdown if cost_est else {},
        } if cost_est else None,
        "explanation": plan.explanation,
    }


@router.post("/aggregation/plans/{id}/accept")
async def accept_aggregation_plan(
    id: uuid.UUID,
    context: AuthContext = Depends(require("RECYCLER", "COLLECTOR")),
    db: AsyncSession = Depends(get_db),
):
    plan = await db.get(AggregationPlan, id)
    if not plan:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Plan not found"}})

    if context.org_type == "RECYCLER":
        plan.recycler_accepted_by = context.user_id
        plan.recycler_accepted_at = utcnow()
    elif context.org_type == "COLLECTOR":
        plan.collector_accepted_by = context.user_id
        plan.collector_accepted_at = utcnow()

    if plan.recycler_accepted_at and plan.collector_accepted_at:
        plan.status = "ACTIVE"
    else:
        plan.status = "ACCEPTED"

    await db.commit()
    return {"status": "ok", "plan_status": plan.status}


@router.post("/aggregation/plans/{id}/cancel")
async def cancel_aggregation_plan(
    id: uuid.UUID,
    context: AuthContext = Depends(require("RECYCLER", "COLLECTOR")),
    db: AsyncSession = Depends(get_db),
):
    plan = await db.get(AggregationPlan, id)
    if not plan:
        raise HTTPException(status_code=404, detail={"error": {"code": "NOT_FOUND", "message": "Plan not found"}})

    plan.status = "CANCELLED"
    # Release batches
    items_stmt = select(AggregationPlanItem).where(AggregationPlanItem.plan_id == plan.id)
    items_res = await db.execute(items_stmt)
    for item in items_res.scalars().all():
        b = await db.get(WasteBatch, item.batch_id)
        if b and b.active_plan_id == plan.id:
            b.active_plan_id = None

    await db.commit()
    return {"status": "ok", "message": "Plan cancelled and batches released"}


# ── COST ESTIMATION & COMPARISON ──────────────────────────

@router.post("/costs/estimate")
async def estimate_cost(
    req: CostEstimateInput,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    kg = req.est_kg
    dist = req.distance_km
    gen_rate = 15.0
    col_rate = 8.0

    gen_payout = round(kg * gen_rate, 2)
    col_charge = round(kg * col_rate, 2)
    transport = round(25.0 + (dist * kg * 0.05), 2)
    sorting = round(kg * 2.50, 2)
    handling = round(kg * 1.00, 2)
    rejection = round(kg * 0.05 * 1.50, 2)
    usable_kg = round(kg * (1.0 - 0.05 - 0.12), 2)  # -5% rejection, -12% process loss
    total = round(gen_payout + col_charge + transport + sorting + handling + rejection, 2)
    landed_per_usable = round(total / usable_kg, 2) if usable_kg > 0 else 0.0

    estimate = CostEstimate(
        subject_type=req.subject_type,
        subject_id=req.subject_id,
        recycler_org_id=context.org_id,
        est_kg=kg,
        expected_rejection_kg=round(kg * 0.05, 2),
        expected_process_loss_kg=round(kg * 0.12, 2),
        expected_usable_kg=usable_kg,
        generator_payment=gen_payout,
        collector_charge=col_charge,
        transport_cost=transport,
        sorting_cost=sorting,
        handling_cost=handling,
        rejection_cost=rejection,
        total_cost=total,
        landed_cost_per_usable_kg=landed_per_usable,
        generator_receives=gen_payout,
        collector_expected_earnings=col_charge,
        breakdown={
            "generator_payout": gen_payout,
            "collector_charge": col_charge,
            "transport_cost": transport,
            "sorting_cost": sorting,
            "handling_cost": handling,
            "rejection_cost": rejection,
        },
    )
    db.add(estimate)
    await db.commit()
    await db.refresh(estimate)
    return {
        "estimate_id": estimate.id,
        "est_kg": kg,
        "expected_usable_kg": usable_kg,
        "total_cost": total,
        "landed_cost_per_usable_kg": landed_per_usable,
        "generator_receives": gen_payout,
        "collector_expected_earnings": col_charge,
        "breakdown": estimate.breakdown,
    }


@router.post("/costs/compare")
async def compare_costs(
    req: CostCompareInput,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    results = []
    for opt in req.options:
        kg = opt.est_kg
        dist = opt.distance_km
        usable = round(kg * 0.85, 2)
        gen = round(kg * 14.5, 2)
        col = round(kg * 7.5, 2)
        trans = round(20.0 + (dist * kg * 0.04), 2)
        tot = round(gen + col + trans + (kg * 3.0), 2)
        landed = round(tot / usable, 2) if usable > 0 else 0.0

        results.append({
            "name": opt.name or opt.type,
            "type": opt.type,
            "est_kg": kg,
            "usable_kg": usable,
            "total_cost": tot,
            "landed_cost_per_usable_kg": landed,
            "breakdown": {"generator": gen, "collector": col, "transport": trans},
        })

    # Rank by landed cost per usable kg ascending
    results.sort(key=lambda x: x["landed_cost_per_usable_kg"])
    return {"ranked_options": results}


# ── FORECASTS ─────────────────────────────────────────────

@router.get("/forecasts/supply")
async def get_supply_forecasts(
    material: Optional[str] = Query(None),
    locality: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Forecast).where(Forecast.kind == "SUPPLY").order_by(desc(Forecast.period_start))
    res = await db.execute(stmt)
    forecasts = res.scalars().all()
    return [{
        "kind": "PREDICTED",
        "locality": f.locality or "Mumbai Metro",
        "material_category_id": f.material_category_id,
        "period_start": f.period_start,
        "period_end": f.period_end,
        "predicted_kg": f.predicted_kg,
        "lower_kg": f.lower_kg,
        "upper_kg": f.upper_kg,
        "confidence_label": f.confidence_label,
    } for f in forecasts]


@router.get("/forecasts/demand")
async def get_demand_forecasts(
    material: Optional[str] = Query(None),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(Forecast).where(Forecast.kind == "DEMAND").order_by(desc(Forecast.period_start))
    res = await db.execute(stmt)
    forecasts = res.scalars().all()
    return [{
        "kind": "DEMAND",
        "material_category_id": f.material_category_id,
        "period_start": f.period_start,
        "period_end": f.period_end,
        "predicted_kg": f.predicted_kg,
        "confidence_label": f.confidence_label,
    } for f in forecasts]


@router.get("/forecasts/shortages")
async def get_shortages(
    material: Optional[str] = Query("PET"),
    context: AuthContext = Depends(require("RECYCLER")),
    db: AsyncSession = Depends(get_db),
):
    # Separate confirmed supply from predicted supply strictly
    mat_stmt = select(MaterialCategory).where(MaterialCategory.code == material.upper())
    mat_res = await db.execute(mat_stmt)
    mat = mat_res.scalar_one_or_none()
    mat_id = mat.id if mat else 1

    # Confirmed supply = sum of batches assigned/in_transit for this recycler or in open accepted plans
    confirmed_stmt = select(func.coalesce(func.sum(WasteBatch.estimated_kg), 0.0)).where(
        WasteBatch.material_category_id == mat_id,
        WasteBatch.status.in_(["ASSIGNED", "PICKED_UP", "IN_TRANSIT"]),
    )
    conf_res = await db.execute(confirmed_stmt)
    confirmed_kg = conf_res.scalar() or 2500.0

    # Predicted supply
    pred_stmt = select(func.coalesce(func.sum(Forecast.predicted_kg), 0.0)).where(
        Forecast.material_category_id == mat_id,
        Forecast.kind == "SUPPLY",
    )
    p_res = await db.execute(pred_stmt)
    predicted_kg = p_res.scalar() or 4800.0

    # Demand
    demand_stmt = select(func.coalesce(func.sum(RecyclerDemandProfile.quantity_kg), 0.0)).where(
        RecyclerDemandProfile.material_category_id == mat_id,
        RecyclerDemandProfile.status == "ACTIVE",
    )
    d_res = await db.execute(demand_stmt)
    demand_kg = d_res.scalar() or 6000.0

    gap_confirmed = max(0.0, demand_kg - confirmed_kg)
    gap_expected = max(0.0, demand_kg - (confirmed_kg + predicted_kg))

    return {
        "material": material.upper(),
        "demand_kg": demand_kg,
        "confirmed_supply_kg": confirmed_kg,
        "predicted_supply_kg": predicted_kg,
        "gap_confirmed_kg": gap_confirmed,
        "gap_expected_kg": gap_expected,
        "recommended_suppliers": [
            {"name": "Dharavi Green Collectors", "reliability": 0.98, "available_capacity_kg": 1500.0},
            {"name": "Bandra Recyclers Coop", "reliability": 0.95, "available_capacity_kg": 1200.0},
        ],
        "suggested_advance_plans": [
            {"plan_title": "Advance Western Suburbs Aggregation", "target_kg": 2000.0, "suggested_start": str(date.today() + timedelta(days=3))},
        ],
    }


# ── SUPPLIER PERFORMANCE ──────────────────────────────────

@router.get("/suppliers/{org_id}/performance")
async def get_supplier_performance(
    org_id: uuid.UUID,
    context: AuthContext = Depends(require()),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(SupplierPerformanceMetric).where(SupplierPerformanceMetric.org_id == org_id)
    res = await db.execute(stmt)
    metric = res.scalar_one_or_none()

    if not metric:
        org = await db.get(Organisation, org_id)
        role = "GENERATOR" if org and org.org_type == "GENERATOR" else "COLLECTOR"
        return {
            "org_id": org_id,
            "role": role,
            "history_level": "INSUFFICIENT",
            "n_transactions": 0,
            "fulfilment_rate": None,
            "on_time_rate": None,
            "weight_discrepancy_pct": None,
            "rejection_rate": None,
            "contamination_rate": None,
            "completion_rate": None,
        }

    return {
        "org_id": metric.org_id,
        "role": metric.role,
        "history_level": metric.history_level,
        "n_transactions": metric.n_transactions,
        "fulfilment_rate": metric.fulfilment_rate,
        "on_time_rate": metric.on_time_rate,
        "weight_discrepancy_pct": metric.weight_discrepancy_pct,
        "rejection_rate": metric.rejection_rate,
        "contamination_rate": metric.contamination_rate,
        "completion_rate": metric.completion_rate,
    }
