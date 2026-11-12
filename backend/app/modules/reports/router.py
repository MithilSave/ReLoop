"""Reports and Impact Summary API router."""

from fastapi import APIRouter, Depends
from sqlalchemy import select, func
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.database import get_db
from app.core.permissions import require, AuthContext
from app.models.batches import WasteBatch
from app.models.custody import PickupRecord, RecyclerReceipt, ProcessingRecord
from app.models.allocations import EPRAllocation
from app.models.ngo import NGOVerification

router = APIRouter(tags=["reports"])


@router.get("/impact/summary")
async def get_impact_summary(
    db: AsyncSession = Depends(get_db),
):
    # Total batches
    b_count_res = await db.execute(select(func.count(WasteBatch.id)))
    total_batches = b_count_res.scalar() or 0

    # Total collected
    col_res = await db.execute(select(func.coalesce(func.sum(PickupRecord.collected_kg), 0.0)).where(PickupRecord.is_current.is_(True)))
    total_collected_kg = col_res.scalar() or 0.0

    # Total received & accepted
    rec_res = await db.execute(select(func.coalesce(func.sum(RecyclerReceipt.received_kg), 0.0), func.coalesce(func.sum(RecyclerReceipt.accepted_kg), 0.0)).where(RecyclerReceipt.is_current.is_(True)))
    received_row = rec_res.first()
    total_received_kg = received_row[0] if received_row else 0.0
    total_accepted_kg = received_row[1] if received_row else 0.0

    # Total processed output
    proc_res = await db.execute(select(func.coalesce(func.sum(ProcessingRecord.output_kg), 0.0)).where(ProcessingRecord.is_current.is_(True)))
    total_processed_kg = proc_res.scalar() or 0.0

    # Total EPR allocated
    alloc_res = await db.execute(select(func.coalesce(func.sum(EPRAllocation.quantity_kg), 0.0)).where(EPRAllocation.status == "ACTIVE"))
    total_allocated_kg = alloc_res.scalar() or 0.0

    # Total NGO verified
    ngo_res = await db.execute(select(func.count(NGOVerification.id)).where(NGOVerification.decision == "VERIFIED", NGOVerification.is_current.is_(True)))
    verified_batches_count = ngo_res.scalar() or 0

    co2_saved = round(total_processed_kg * 1.5, 2)
    trees_saved = int(total_processed_kg * 0.08)

    return {
        "pilot_city": "Mumbai (MUM)",
        "total_batches": total_batches,
        "stages": {
            "collected_kg": round(total_collected_kg, 2),
            "received_kg": round(total_received_kg, 2),
            "accepted_kg": round(total_accepted_kg, 2),
            "processed_output_kg": round(total_processed_kg, 2),
            "epr_allocated_kg": round(total_allocated_kg, 2),
            "verified_batches_count": verified_batches_count,
        },
        "environmental_impact": {
            "co2_avoided_kg": co2_saved,
            "trees_equivalent": trees_saved,
            "landfill_diverted_kg": round(total_accepted_kg, 2),
        },
    }


@router.get("/generator/certificates")
async def get_generator_certificates(
    context: AuthContext = Depends(require("GENERATOR")),
    db: AsyncSession = Depends(get_db),
):
    stmt = select(WasteBatch).where(
        WasteBatch.generator_org_id == context.org_id,
        WasteBatch.status.in_(["PICKED_UP", "RECEIVED", "PROCESSED"]),
    )
    res = await db.execute(stmt)
    batches = res.scalars().all()

    certificates = []
    for b in batches:
        certificates.append({
            "certificate_id": b.id,
            "certificate_title": f"Green Contribution Certificate – {b.batch_code}",
            "batch_code": b.batch_code,
            "kg_contributed": b.estimated_kg,
            "date": b.created_at.date(),
            "download_url": f"https://reloop-storage.local/certificates/{b.batch_code}.pdf",
        })
    return certificates
