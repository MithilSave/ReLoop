"""Dump real API responses from the seeded backend as JSON fixtures for test/screens_smoke_test.dart.

Run from the backend folder:  python seed_data.py && python ../mobile_v2/tool/dump_fixtures.py ../mobile_v2/test/fixtures/api.json
"""
import asyncio, json, os, sys
import httpx
sys.path.insert(0, os.getcwd())
from app.main import app

API = "/api/v1"
ROLES = ["generator", "collector", "recycler", "ngo", "epr", "admin"]
COMMON = ["/auth/me", "/materials", "/orgs", "/orgs?org_type=RECYCLER", "/orgs?org_type=COLLECTOR", "/orgs?org_type=EPR_CLIENT", "/orgs/me",
          "/batches", "/batches?status=LISTED", "/batches?status=PROCESSED", "/payments", "/anomalies", "/audit/logs", "/impact/summary", "/ai/status"]
PER_ROLE = {
    "generator": [],
    "collector": ["/collections/available", "/collections/jobs", "/consignments", "/aggregation/plans"],
    "recycler": ["/consignments", "/recycler/incoming", "/recycler/receipts?include_history=false", "/recycler/receipts?include_history=true",
                 "/recycler/processing-records", "/recycler/capacity", "/yield", "/recycler/offers", "/recycler/demand-profiles",
                 "/aggregation/plans", "/pricing-assumptions", "/forecasts/supply", "/forecasts/demand", "/forecasts/shortages?material=PET",
                 "/epr/allocations"],
    "ngo": ["/ngo/verifications", "/ngo/reports", "/ngo/impact", "/yield"],
    "epr": ["/epr/allocations", "/epr/targets", "/epr/certificates", "/epr/discrepancies", "/epr/dashboard?period=FY2026-27"],
    "admin": ["/admin/orgs?status=PENDING", "/admin/orgs"],
}

async def main():
    out = {}
    t = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=t, base_url="http://t") as c:
        for role in ROLES:
            r = await c.post(f"{API}/auth/login", json={"login": f"{role}@reloop.in", "password": "reloop123"})
            h = {"Authorization": f"Bearer {r.json()['access_token']}"}
            fx = {}
            async def get(p):
                if p in fx: return fx[p]["body"]
                rr = await c.get(API + p, headers=h)
                try: body = rr.json()
                except Exception: body = None
                fx[p] = {"status": rr.status_code, "body": body}
                return body
            for p in COMMON + PER_ROLE[role]:
                await get(p)
            me = fx["/auth/me"]["body"]
            await get(f"/suppliers/{me['active_org']['id']}/performance")
            batches = fx["/batches"]["body"] if isinstance(fx["/batches"]["body"], list) else []
            for b in batches[:8]:
                await get(f"/batches/{b['batch_code']}")
                await get(f"/passports/{b['batch_code']}")
                await get(f"/batches/{b['id']}/trace")
                await get(f"/batches/{b['id']}/events")
                await get(f"/batches/{b['id']}/offers")
            for p in ["/batches?status=PROCESSED"]:
                for b in (fx.get(p, {}).get("body") or [])[:8]:
                    await get(f"/passports/{b['batch_code']}")
            if role == "ngo":
                for v in (fx["/ngo/verifications"]["body"] or [])[:4]:
                    await get(f"/ngo/verifications/{v['id']}")
                    await get(f"/batches/{v['batch_id']}")
                    await get(f"/batches/{v['batch_id']}/trace")
                    await get(f"/batches/{v['batch_id']}/events")
            for pl in (fx.get("/aggregation/plans", {}).get("body") or [])[:3]:
                await get(f"/aggregation/plans/{pl['id']}")
            if role == "recycler":
                for col in (fx["/orgs?org_type=COLLECTOR"]["body"] or [])[:4]:
                    await get(f"/suppliers/{col['id']}/performance")
            bad = {k: v["status"] for k, v in fx.items() if v["status"] >= 400}
            print(role, len(fx), "responses;", "errors:", bad)
            out[role] = fx
    json.dump(out, open(sys.argv[1], "w"), separators=(",", ":"))

asyncio.run(main())
