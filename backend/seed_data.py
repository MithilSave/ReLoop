"""Seed realistic Mumbai pilot demo data for ReLoop."""

import asyncio
import os
import sys
import uuid
from datetime import date, datetime, timezone, timedelta

# Ensure backend directory is in sys.path
sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from sqlalchemy import select
from app.core.database import async_session, init_db
from app.core.security import hash_password
from app.models import (
    MaterialCategory,
    User,
    Organisation,
    OrgMembership,
    GeneratorProfile,
    CollectorProfile,
    RecyclerProfile,
    NGOProfile,
    EPRClientProfile,
    NGOScope,
    EPRTarget,
    WasteBatch,
    BatchEvent,
    CollectionOffer,
    RecyclerOffer,
    PickupRecord,
    RecyclerReceipt,
    ProcessingRecord,
    ProcessingInput,
    Certificate,
    EPRAllocation,
    NGOVerification,
    Payment,
    PricingAssumption,
    RecyclerDemandProfile,
    GeneratorSupplyProfile,
    AggregationPlan,
    AggregationPlanItem,
    TransportConsignment,
    ConsignmentItem,
    CostEstimate,
    SupplierPerformanceMetric,
    Forecast,
    AnomalyFlag,
    AIPrediction,
)


def utcnow():
    return datetime.now(timezone.utc)


async def seed():
    print("Initializing database tables...")
    await init_db()

    async with async_session() as db:
        # Check if already seeded
        chk = await db.execute(select(MaterialCategory))
        if chk.scalars().first():
            print("Database already contains data. Cleaning and re-seeding...")
            # For idempotent seeding in dev, continue

        # ── 1. Reference Data: 8 Material Categories ───────────
        print("Seeding material categories...")
        materials_data = [
            {"id": 1, "code": "PET", "name": "Polyethylene Terephthalate", "resin_code": 1, "default_packaging_category": "CAT_I", "description": "Beverage bottles, transparent food containers, blister packs"},
            {"id": 2, "code": "HDPE", "name": "High-Density Polyethylene", "resin_code": 2, "default_packaging_category": "CAT_I", "description": "Milk bottles, detergent jugs, drums, shampoo containers"},
            {"id": 3, "code": "PVC", "name": "Polyvinyl Chloride", "resin_code": 3, "default_packaging_category": "CAT_I", "description": "Rigid pipes, fittings, medical tubing, profiles"},
            {"id": 4, "code": "LDPE", "name": "Low-Density Polyethylene", "resin_code": 4, "default_packaging_category": "CAT_II", "description": "Squeeze bottles, stretch wrap, flexible pouches, carry bags"},
            {"id": 5, "code": "PP", "name": "Polypropylene", "resin_code": 5, "default_packaging_category": "CAT_I", "description": "Bottle caps, food tubs, straws, automotive parts"},
            {"id": 6, "code": "PS", "name": "Polystyrene", "resin_code": 6, "default_packaging_category": "CAT_I", "description": "Cutlery, foam food containers, electronics packaging"},
            {"id": 7, "code": "OTHER", "name": "Other / Engineered Plastics", "resin_code": 7, "default_packaging_category": "CAT_I", "description": "Polycarbonate, acrylic, multi-polymer blends"},
            {"id": 8, "code": "MLP", "name": "Multi-Layered Plastic Packaging", "resin_code": None, "default_packaging_category": "CAT_III", "description": "Snack foil packets, chips pouches, laminates"},
        ]
        for m in materials_data:
            existing_m = await db.get(MaterialCategory, m["id"])
            if not existing_m:
                db.add(MaterialCategory(**m))
        await db.flush()

        # ── 2. Users and Organisations ─────────────────────────
        print("Seeding users, organisations, and profiles...")
        common_pass = hash_password("reloop123")

        # Admin
        admin_user = (await db.execute(select(User).where(User.email == "admin@reloop.in"))).scalar_one_or_none()
        if not admin_user:
            admin_user = User(
                full_name="Platform Administrator",
                email="admin@reloop.in",
                phone="+919900000001",
                password_hash=common_pass,
                is_platform_admin=True,
                status="ACTIVE",
            )
            db.add(admin_user)
            await db.flush()

            admin_org = Organisation(
                org_type="NGO",
                legal_name="ReLoop Platform Governance",
                display_name="ReLoop Admin",
                city_id="MUM",
                address="Bandra Kurla Complex, Mumbai 400051",
                approval_status="APPROVED",
            )
            db.add(admin_org)
            await db.flush()
            db.add(OrgMembership(user_id=admin_user.id, org_id=admin_org.id, org_role="OWNER"))

        # Generator
        gen_user = (await db.execute(select(User).where(User.email == "generator@reloop.in"))).scalar_one_or_none()
        if not gen_user:
            gen_user = User(
                full_name="Godrej Facilities Management",
                email="generator@reloop.in",
                phone="+919900000002",
                password_hash=common_pass,
                status="ACTIVE",
            )
            db.add(gen_user)
            await db.flush()

            gen_org = Organisation(
                org_type="GENERATOR",
                legal_name="Godrej Green Towers Housing Society",
                display_name="Godrej Green Towers",
                city_id="MUM",
                address="Eastern Express Highway, Vikhroli East, Mumbai 400079",
                lat=19.1025,
                lng=72.9324,
                gstin="27AABCG1234F1ZQ",
                approval_status="APPROVED",
            )
            db.add(gen_org)
            await db.flush()
            db.add(OrgMembership(user_id=gen_user.id, org_id=gen_org.id, org_role="OWNER"))
            db.add(GeneratorProfile(org_id=gen_org.id, generator_kind="SOCIETY", payout_upi_ref_masked="godrej***@okhdfcbank"))
        else:
            gen_mem = (await db.execute(select(OrgMembership).where(OrgMembership.user_id == gen_user.id))).scalars().first()
            gen_org = await db.get(Organisation, gen_mem.org_id)

        # Collector
        col_user = (await db.execute(select(User).where(User.email == "collector@reloop.in"))).scalar_one_or_none()
        if not col_user:
            col_user = User(
                full_name="Dharavi Green Collect Team",
                email="collector@reloop.in",
                phone="+919900000003",
                password_hash=common_pass,
                status="ACTIVE",
            )
            db.add(col_user)
            await db.flush()

            col_org = Organisation(
                org_type="COLLECTOR",
                legal_name="Dharavi Waste Collectors Welfare Society",
                display_name="Dharavi Green Collect",
                city_id="MUM",
                address="90 Feet Road, Dharavi, Mumbai 400017",
                lat=19.0435,
                lng=72.8567,
                gstin="27AABCD5678K1Z5",
                approval_status="APPROVED",
            )
            db.add(col_org)
            await db.flush()
            db.add(OrgMembership(user_id=col_user.id, org_id=col_org.id, org_role="OWNER"))
            db.add(CollectorProfile(
                org_id=col_org.id,
                service_radius_km=30.0,
                daily_capacity_kg=5000.0,
                min_pickup_kg=50.0,
                vehicle_types=["Tata Ace EV", "Piaggio Ape E-City", "Mahindra Bolero Maxi Truck"],
                reliability_score=0.985,
            ))
        else:
            col_mem = (await db.execute(select(OrgMembership).where(OrgMembership.user_id == col_user.id))).scalars().first()
            col_org = await db.get(Organisation, col_mem.org_id)

        # Recycler
        rec_user = (await db.execute(select(User).where(User.email == "recycler@reloop.in"))).scalar_one_or_none()
        if not rec_user:
            rec_user = User(
                full_name="Ecoplas Recycling Operations",
                email="recycler@reloop.in",
                phone="+919900000004",
                password_hash=common_pass,
                status="ACTIVE",
            )
            db.add(rec_user)
            await db.flush()

            rec_org = Organisation(
                org_type="RECYCLER",
                legal_name="Ecoplas Circular Solutions Ltd",
                display_name="Ecoplas Taloja Plant",
                city_id="MUM",
                address="Plot C-14, MIDC Industrial Area, Taloja, Navi Mumbai 410208",
                lat=19.0812,
                lng=73.1235,
                gstin="27AABCE9012L1ZX",
                approval_status="APPROVED",
            )
            db.add(rec_org)
            await db.flush()
            db.add(OrgMembership(user_id=rec_user.id, org_id=rec_org.id, org_role="OWNER"))
            db.add(RecyclerProfile(
                org_id=rec_org.id,
                pwp_registration_no="PWP-MPCB-MUM-2024-8841",
                registration_valid_until=date(2028, 12, 31),
                spcb="MPCB",
                processing_type="RECYCLING",
                monthly_capacity_kg=100000.0,
                facility_address="Plot C-14, MIDC Taloja, Navi Mumbai",
            ))
        else:
            rec_mem = (await db.execute(select(OrgMembership).where(OrgMembership.user_id == rec_user.id))).scalars().first()
            rec_org = await db.get(Organisation, rec_mem.org_id)

        # NGO
        ngo_user = (await db.execute(select(User).where(User.email == "ngo@reloop.in"))).scalar_one_or_none()
        if not ngo_user:
            ngo_user = User(
                full_name="Green Ledger Audit Director",
                email="ngo@reloop.in",
                phone="+919900000005",
                password_hash=common_pass,
                status="ACTIVE",
            )
            db.add(ngo_user)
            await db.flush()

            ngo_org = Organisation(
                org_type="NGO",
                legal_name="Green Ledger Foundation India",
                display_name="Green Ledger Foundation",
                city_id="MUM",
                address="12th Floor, Express Towers, Nariman Point, Mumbai 400021",
                lat=18.9256,
                lng=72.8242,
                approval_status="APPROVED",
            )
            db.add(ngo_org)
            await db.flush()
            db.add(OrgMembership(user_id=ngo_user.id, org_id=ngo_org.id, org_role="OWNER"))
            db.add(NGOProfile(
                org_id=ngo_org.id,
                registration_no="GLF-SEC8-MUM-2023-102",
                registration_type="Section 8",
                agreement_valid_until=date(2029, 6, 30),
            ))
            db.add(NGOScope(
                ngo_org_id=ngo_org.id,
                material_category_id=None,  # All materials
                locality=None,  # All localities
                valid_from=utcnow() - timedelta(days=90),
            ))
        else:
            ngo_mem = (await db.execute(select(OrgMembership).where(OrgMembership.user_id == ngo_user.id))).scalars().first()
            ngo_org = await db.get(Organisation, ngo_mem.org_id)

        # EPR Client
        epr_user = (await db.execute(select(User).where(User.email == "epr@reloop.in"))).scalar_one_or_none()
        if not epr_user:
            epr_user = User(
                full_name="Hindustan Consumer Goods Compliance Lead",
                email="epr@reloop.in",
                phone="+919900000006",
                password_hash=common_pass,
                status="ACTIVE",
            )
            db.add(epr_user)
            await db.flush()

            epr_org = Organisation(
                org_type="EPR_CLIENT",
                legal_name="Hindustan Consumer Goods Ltd",
                display_name="Hindustan Consumer Goods",
                city_id="MUM",
                address="Hindustan House, G Block, BKC, Mumbai 400051",
                lat=19.0667,
                lng=72.8667,
                gstin="27AABCH3456N1ZR",
                approval_status="APPROVED",
            )
            db.add(epr_org)
            await db.flush()
            db.add(OrgMembership(user_id=epr_user.id, org_id=epr_org.id, org_role="OWNER"))
            db.add(EPRClientProfile(
                org_id=epr_org.id,
                epr_registration_no="CPCB-EPR-BO-2024-00451",
                pibo_type="BRAND_OWNER",
                compliance_contact="epr-compliance@hindustanconsumer.com",
            ))

            # EPR Targets
            db.add(EPRTarget(
                epr_org_id=epr_org.id,
                reporting_period="FY2026-27",
                packaging_category="CAT_I",
                target_kg=15000.0,
                source_note="Statutory target for Cat I Rigid Plastic Packaging",
            ))
            db.add(EPRTarget(
                epr_org_id=epr_org.id,
                reporting_period="FY2026-27",
                packaging_category="CAT_II",
                target_kg=8000.0,
                source_note="Statutory target for Cat II Flexible Plastic Packaging",
            ))
        else:
            epr_mem = (await db.execute(select(OrgMembership).where(OrgMembership.user_id == epr_user.id))).scalars().first()
            epr_org = await db.get(Organisation, epr_mem.org_id)

        await db.commit()

        # ── 3. Recycler Offers & Pricing Assumptions ──────────
        print("Seeding offers and pricing assumptions...")
        rec_offer = (await db.execute(select(RecyclerOffer).where(RecyclerOffer.recycler_org_id == rec_org.id))).scalar_one_or_none()
        if not rec_offer:
            rec_offer = RecyclerOffer(
                recycler_org_id=rec_org.id,
                material_category_id=1,  # PET
                price_per_kg=28.50,
                min_kg=100.0,
                quality_spec="Post-consumer clean PET bottles, transparent/light blue",
                max_contamination_pct=5.0,
                valid_from=utcnow() - timedelta(days=30),
                valid_to=utcnow() + timedelta(days=365),
                is_active=True,
            )
            db.add(rec_offer)

        p_assump = (await db.execute(select(PricingAssumption))).scalars().first()
        if not p_assump:
            p_assump = PricingAssumption(
                scope_org_id=None,
                version=1,
                transport_per_km=25.0,
                transport_per_kg_km=0.05,
                sorting_per_kg=2.50,
                handling_per_kg=1.00,
                storage_per_kg_day=0.20,
                rejection_cost_per_kg=1.50,
                default_rejection_rate={"PET": 0.05, "HDPE": 0.04, "PP": 0.06, "LDPE": 0.08},
                default_process_loss_rate={"PET": 0.12, "HDPE": 0.10, "PP": 0.14, "LDPE": 0.15},
                is_active=True,
            )
            db.add(p_assump)

        # ── 4. Sample Batches across all 6 Stages ──────────────
        print("Seeding sample batches across life-cycle stages...")

        # Batch 1: LISTED
        b1_chk = (await db.execute(select(WasteBatch).where(WasteBatch.batch_code == "RL-MUM-2026-000101"))).scalar_one_or_none()
        if not b1_chk:
            b1 = WasteBatch(
                batch_code="RL-MUM-2026-000101",
                qr_token="qr-listed-token-vikhroli-001",
                generator_org_id=gen_org.id,
                material_category_id=1,  # PET
                estimated_kg=250.0,
                pickup_address="Gate 3, Godrej Green Towers, Vikhroli East, Mumbai 400079",
                lat=19.1025,
                lng=72.9324,
                locality="Vikhroli East",
                available_from=utcnow(),
                available_to=utcnow() + timedelta(days=3),
                status="LISTED",
            )
            db.add(b1)
            await db.flush()
            db.add(BatchEvent(
                batch_id=b1.id,
                event_type="CREATED",
                to_status="LISTED",
                actor_user_id=gen_user.id,
                actor_org_id=gen_org.id,
                payload={"estimated_kg": 250.0, "material": "PET"},
            ))

        # Batch 2: ASSIGNED
        b2_chk = (await db.execute(select(WasteBatch).where(WasteBatch.batch_code == "RL-MUM-2026-000102"))).scalar_one_or_none()
        if not b2_chk:
            b2 = WasteBatch(
                batch_code="RL-MUM-2026-000102",
                qr_token="qr-assigned-token-vikhroli-002",
                generator_org_id=gen_org.id,
                material_category_id=2,  # HDPE
                estimated_kg=400.0,
                pickup_address="Clubhouse Bin Yard, Godrej Green Towers, Vikhroli East, Mumbai",
                lat=19.1025,
                lng=72.9324,
                locality="Vikhroli East",
                available_from=utcnow() - timedelta(days=1),
                available_to=utcnow() + timedelta(days=2),
                status="ASSIGNED",
                assigned_collector_org_id=col_org.id,
            )
            db.add(b2)
            await db.flush()

            off2 = CollectionOffer(
                batch_id=b2.id,
                collector_org_id=col_org.id,
                generator_rate_per_kg=16.50,
                proposed_pickup_at=utcnow() + timedelta(hours=4),
                status="ACCEPTED",
                expires_at=utcnow() + timedelta(days=1),
            )
            db.add(off2)
            await db.flush()
            b2.accepted_offer_id = off2.id

            db.add(BatchEvent(
                batch_id=b2.id,
                event_type="OFFER_ACCEPTED",
                from_status="LISTED",
                to_status="ASSIGNED",
                actor_user_id=gen_user.id,
                actor_org_id=gen_org.id,
                payload={"offer_id": str(off2.id), "rate": 16.50},
            ))

        # Batch 3: PICKED_UP
        b3_chk = (await db.execute(select(WasteBatch).where(WasteBatch.batch_code == "RL-MUM-2026-000103"))).scalar_one_or_none()
        if not b3_chk:
            b3 = WasteBatch(
                batch_code="RL-MUM-2026-000103",
                qr_token="qr-pickedup-token-vikhroli-003",
                generator_org_id=gen_org.id,
                material_category_id=1,  # PET
                estimated_kg=320.0,
                pickup_address="Basement Segregation Area, Godrej Towers, Mumbai",
                lat=19.1025,
                lng=72.9324,
                locality="Vikhroli East",
                available_from=utcnow() - timedelta(days=2),
                available_to=utcnow() + timedelta(days=1),
                status="PICKED_UP",
                assigned_collector_org_id=col_org.id,
            )
            db.add(b3)
            await db.flush()

            pickup3 = PickupRecord(
                batch_id=b3.id,
                collector_org_id=col_org.id,
                collector_user_id=col_user.id,
                collected_kg=315.0,
                generator_rate_per_kg=15.00,
                handover_method="OTP",
                otp_code="482910",
                generator_confirmed_by_user_id=gen_user.id,
                confirmed_at=utcnow() - timedelta(hours=6),
                is_current=True,
            )
            db.add(pickup3)

            db.add(BatchEvent(
                batch_id=b3.id,
                event_type="PICKED_UP",
                from_status="ASSIGNED",
                to_status="PICKED_UP",
                actor_user_id=gen_user.id,
                actor_org_id=gen_org.id,
                payload={"collected_kg": 315.0, "rate": 15.0},
            ))

            db.add(Payment(
                batch_id=b3.id,
                payment_type="GENERATOR_PAYOUT",
                payer_org_id=col_org.id,
                payee_org_id=gen_org.id,
                quantity_kg=315.0,
                rate=15.00,
                amount=4725.0,
                status="PAID",
                external_ref="UPI/20261112/98372091",
            ))

        # Batch 4: RECEIVED (at recycler)
        b4_chk = (await db.execute(select(WasteBatch).where(WasteBatch.batch_code == "RL-MUM-2026-000104"))).scalar_one_or_none()
        if not b4_chk:
            b4 = WasteBatch(
                batch_code="RL-MUM-2026-000104",
                qr_token="qr-received-token-004",
                generator_org_id=gen_org.id,
                material_category_id=1,  # PET
                estimated_kg=500.0,
                pickup_address="Commercial Block C, Godrej Campus, Vikhroli",
                lat=19.1025,
                lng=72.9324,
                locality="Vikhroli East",
                available_from=utcnow() - timedelta(days=4),
                available_to=utcnow() - timedelta(days=2),
                status="RECEIVED",
                assigned_collector_org_id=col_org.id,
                destination_recycler_org_id=rec_org.id,
            )
            db.add(b4)
            await db.flush()

            db.add(PickupRecord(
                batch_id=b4.id,
                collector_org_id=col_org.id,
                collector_user_id=col_user.id,
                collected_kg=495.0,
                generator_rate_per_kg=15.0,
                handover_method="OTP",
                otp_code="112233",
                generator_confirmed_by_user_id=gen_user.id,
                confirmed_at=utcnow() - timedelta(days=3),
                is_current=True,
            ))

            db.add(RecyclerReceipt(
                batch_id=b4.id,
                recycler_org_id=rec_org.id,
                received_kg=495.0,
                accepted_kg=480.0,
                rejected_kg=15.0,
                quality_grade="A",
                contamination_pct=3.0,
                price_per_kg=28.50,
                rejection_disposition="Unwashable adhesive labels and non-PET closures",
                received_at=utcnow() - timedelta(days=2),
                is_current=True,
            ))

            db.add(BatchEvent(
                batch_id=b4.id,
                event_type="RECEIVED",
                from_status="IN_TRANSIT",
                to_status="RECEIVED",
                actor_user_id=rec_user.id,
                actor_org_id=rec_org.id,
                payload={"received_kg": 495.0, "accepted_kg": 480.0, "rejected_kg": 15.0},
            ))

        # Batch 5: PROCESSED, NGO VERIFIED, and EPR ALLOCATED (The complete end-to-end golden journey)
        b5_chk = (await db.execute(select(WasteBatch).where(WasteBatch.batch_code == "RL-MUM-2026-000105"))).scalar_one_or_none()
        if not b5_chk:
            b5 = WasteBatch(
                batch_code="RL-MUM-2026-000105",
                qr_token="qr-processed-golden-token-005",
                generator_org_id=gen_org.id,
                material_category_id=1,  # PET
                estimated_kg=1000.0,
                pickup_address="Central Sorting Area, Godrej Campus, Vikhroli East, Mumbai",
                lat=19.1025,
                lng=72.9324,
                locality="Vikhroli East",
                available_from=utcnow() - timedelta(days=10),
                available_to=utcnow() - timedelta(days=8),
                status="PROCESSED",
                assigned_collector_org_id=col_org.id,
                destination_recycler_org_id=rec_org.id,
            )
            db.add(b5)
            await db.flush()

            # Pickup
            db.add(PickupRecord(
                batch_id=b5.id,
                collector_org_id=col_org.id,
                collector_user_id=col_user.id,
                collected_kg=980.0,
                generator_rate_per_kg=15.0,
                handover_method="OTP",
                otp_code="998877",
                generator_confirmed_by_user_id=gen_user.id,
                confirmed_at=utcnow() - timedelta(days=9),
                is_current=True,
            ))

            # Receipt
            rcpt5 = RecyclerReceipt(
                batch_id=b5.id,
                recycler_org_id=rec_org.id,
                received_kg=980.0,
                accepted_kg=950.0,
                rejected_kg=30.0,
                quality_grade="A",
                contamination_pct=3.0,
                price_per_kg=28.50,
                received_at=utcnow() - timedelta(days=8),
                is_current=True,
            )
            db.add(rcpt5)
            await db.flush()

            # Processing Run (PR-2026-00001)
            proc_run = ProcessingRecord(
                record_code="PR-2026-00001",
                recycler_org_id=rec_org.id,
                material_category_id=1,
                run_started_at=utcnow() - timedelta(days=7),
                run_ended_at=utcnow() - timedelta(days=6),
                input_kg=950.0,
                output_kg=855.0,
                residue_kg=57.0,
                output_form="rPET Hot-Washed Flakes",
                eligible_kg=855.0,
                eligibility_basis="Registration PWP-MPCB-MUM-2024-8841. Continuous wash & granulate run.",
                measurement_status="COMPLETE",
                yield_pct=90.0,
                unaccounted_kg=38.0,
                version=1,
                is_current=True,
            )
            db.add(proc_run)
            await db.flush()

            # Processing Input Lineage
            db.add(ProcessingInput(
                processing_record_id=proc_run.id,
                recycler_receipt_id=rcpt5.id,
                batch_id=b5.id,
                input_kg=950.0,
                apportioned_output_kg=855.0,
            ))

            # Statutory Certificate
            cert = Certificate(
                recycler_org_id=rec_org.id,
                processing_record_id=proc_run.id,
                certificate_ref="CPCB-MPCB-MUM-2026-PET-009182",
                packaging_category="CAT_I",
                certificate_kg=855.0,
                issued_on=date.today() - timedelta(days=5),
                status="RECORDED",
            )
            db.add(cert)
            await db.flush()

            # EPR Allocation to Hindustan Consumer Goods
            db.add(EPRAllocation(
                processing_record_id=proc_run.id,
                epr_org_id=epr_org.id,
                certificate_id=cert.id,
                packaging_category="CAT_I",
                reporting_period="FY2026-27",
                quantity_kg=600.0,
                status="ACTIVE",
                created_by_user_id=rec_user.id,
            ))

            # NGO Verification
            db.add(NGOVerification(
                batch_id=b5.id,
                ngo_org_id=ngo_org.id,
                reviewer_user_id=ngo_user.id,
                decision="VERIFIED",
                reviewed_record_versions={"processing_record_id": str(proc_run.id), "version": 1},
                comments="Physical weighbridge slip, energy logs and CPCB portal certificate cross-checked. Yield within thermodynamic threshold (90.0%). Fully verified.",
                is_current=True,
            ))

            db.add(BatchEvent(
                batch_id=b5.id,
                event_type="PROCESSED",
                from_status="RECEIVED",
                to_status="PROCESSED",
                actor_user_id=rec_user.id,
                actor_org_id=rec_org.id,
                payload={"record_code": "PR-2026-00001", "output_kg": 855.0, "yield_pct": 90.0},
            ))

            db.add(BatchEvent(
                batch_id=b5.id,
                event_type="NGO_VERIFIED",
                from_status="PROCESSED",
                to_status="PROCESSED",
                actor_user_id=ngo_user.id,
                actor_org_id=ngo_org.id,
                payload={"decision": "VERIFIED", "reviewer": "Green Ledger Foundation"},
            ))

        # ── 5. Consignments & Aggregation Plan ─────────────────
        cons_chk = (await db.execute(select(TransportConsignment).where(TransportConsignment.consignment_code == "TC-MUM-2026-00001"))).scalar_one_or_none()
        if not cons_chk:
            cons = TransportConsignment(
                consignment_code="TC-MUM-2026-00001",
                collector_org_id=col_org.id,
                destination_recycler_org_id=rec_org.id,
                vehicle_no="MH-03-CP-9812",
                dispatched_at=utcnow() - timedelta(days=2),
                arrived_at=utcnow() - timedelta(days=2, hours=-3),
                status="ARRIVED",
            )
            db.add(cons)
            await db.flush()
            # Link to batch 4
            db.add(ConsignmentItem(consignment_id=cons.id, batch_id=b4_chk.id if b4_chk else b4.id))

        # ── 6. Intelligence: Demand, Supply, Forecasts, Metrics ───
        dem_chk = (await db.execute(select(RecyclerDemandProfile))).scalars().first()
        if not dem_chk:
            db.add(RecyclerDemandProfile(
                recycler_org_id=rec_org.id,
                material_category_id=1,  # PET
                recurrence="WEEKLY",
                quantity_kg=5000.0,
                min_lot_kg=100.0,
                min_quality_grade="B",
                max_contamination_pct=6.0,
                target_landed_cost_per_kg=32.0,
                status="ACTIVE",
            ))

        sup_chk = (await db.execute(select(GeneratorSupplyProfile))).scalars().first()
        if not sup_chk:
            db.add(GeneratorSupplyProfile(
                generator_org_id=gen_org.id,
                material_category_id=1,
                recurrence="WEEKLY",
                typical_kg=600.0,
                preferred_weekday=2,  # Wednesday
                pickup_window="10:00 - 13:00",
                is_active=True,
            ))

        # Forecasts
        fc_chk = (await db.execute(select(Forecast))).scalars().first()
        if not fc_chk:
            db.add(Forecast(
                kind="SUPPLY",
                locality="Mumbai Eastern Suburbs",
                material_category_id=1,
                period_start=utcnow(),
                period_end=utcnow() + timedelta(days=30),
                predicted_kg=8500.0,
                lower_kg=7800.0,
                upper_kg=9200.0,
                method="ARIMA_pilot_v1",
                n_history_points=42,
                confidence_label="HIGH",
            ))
            db.add(Forecast(
                kind="DEMAND",
                material_category_id=1,
                period_start=utcnow(),
                period_end=utcnow() + timedelta(days=30),
                predicted_kg=12000.0,
                lower_kg=11000.0,
                upper_kg=13500.0,
                method="buyer_orders_rolling",
                n_history_points=30,
                confidence_label="HIGH",
            ))

        # Supplier Performance Metric
        met_chk = (await db.execute(select(SupplierPerformanceMetric))).scalars().first()
        if not met_chk:
            db.add(SupplierPerformanceMetric(
                org_id=col_org.id,
                role="COLLECTOR",
                material_category_id=1,
                window="ALL",
                n_transactions=28,
                fulfilment_rate=0.985,
                on_time_rate=0.964,
                weight_discrepancy_pct=0.018,
                rejection_rate=0.025,
                contamination_rate=0.032,
                completion_rate=0.990,
                history_level="SUFFICIENT",
                computed_at=utcnow(),
            ))

        await db.commit()
        print("Demo seed completed successfully!")


if __name__ == "__main__":
    asyncio.run(seed())
