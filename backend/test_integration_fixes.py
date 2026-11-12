"""Tests for the integration patch (directory, receipts list, integrity guards, auth fixes).

Run after seed_data.py, in the same way as test_api_suite.py:
    python seed_data.py && python test_integration_fixes.py
Each test creates its own batches, so it does not depend on the order of the existing suite.
"""

import asyncio
import os
import sys

import httpx

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app.main import app  # noqa: E402

API = "/api/v1"
PASSWORD = "reloop123"


def check(cond, label, resp=None):
    if not cond:
        detail = f" -> {resp.status_code} {resp.text[:300]}" if resp is not None else ""
        raise AssertionError(f"FAIL: {label}{detail}")
    print(f" [PASS] {label}")


async def login(client, who):
    r = await client.post(f"{API}/auth/login", json={"login": f"{who}@reloop.in", "password": PASSWORD})
    assert r.status_code == 200, r.text
    return r.json()


def bearer(tok):
    return {"Authorization": f"Bearer {tok['access_token']}"}


async def new_picked_up_batch(client, gen, col, kg=100.0, material="PET"):
    """Generator lists, collector offers, generator accepts, collector weighs, generator confirms."""
    r = await client.post(f"{API}/batches", headers=bearer(gen), json={
        "material_code": material, "estimated_kg": kg, "pickup_address": "Test dock",
        "locality": "Test", "available_from": "2026-11-12T10:00:00Z", "available_to": "2026-11-20T10:00:00Z",
    })
    assert r.status_code == 201, r.text
    batch = r.json()
    r = await client.post(f"{API}/collections/{batch['id']}/offers", headers=bearer(col),
                          json={"generator_rate_per_kg": 10, "proposed_pickup_at": "2026-11-13T10:00:00Z"})
    offer_id = r.json()["offer_id"]
    await client.post(f"{API}/batches/{batch['id']}/offers/{offer_id}/accept", headers=bearer(gen))
    r = await client.post(f"{API}/collections/{batch['id']}/pickup", headers=bearer(col), json={"collected_kg": kg})
    otp = r.json()["otp"]
    r = await client.post(f"{API}/batches/{batch['id']}/handover/confirm", headers=bearer(gen), json={"otp": otp})
    assert r.json()["batch_status"] == "PICKED_UP", r.text
    return batch


async def run():
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://testserver") as client:
        gen, col, rec, ngo, epr, admin = [await login(client, w) for w in
                                         ("generator", "collector", "recycler", "ngo", "epr", "admin")]

        print("\n== #4 Auth ==")
        r = await client.post(f"{API}/auth/refresh", json={"refresh_token": gen["refresh_token"]})
        check(r.status_code == 200 and r.json()["access_token"], "refresh returns new tokens (no 500 on SQLite)", r)
        gen = r.json()
        r = await client.get(f"{API}/auth/me", headers={"Authorization": f"Bearer {gen['refresh_token']}"})
        check(r.status_code == 401, "refresh token is rejected as a bearer access token", r)
        r = await client.post(f"{API}/auth/refresh", json={"refresh_token": gen["access_token"]})
        check(r.status_code == 401, "access token is rejected by /auth/refresh", r)
        r = await client.get(f"{API}/auth/me", headers={"Authorization": "Bearer not-a-token"})
        check(r.status_code == 401 and r.json()["error"]["code"] == "UNAUTHENTICATED", "malformed token reports UNAUTHENTICATED, not TOKEN_EXPIRED", r)
        throwaway = await login(client, "generator")
        r = await client.post(f"{API}/auth/logout", headers=bearer(throwaway), json={"refresh_token": throwaway["refresh_token"]})
        check(r.status_code == 200 and r.json()["refresh_token_revoked"] is True, "logout revokes the refresh token", r)
        r = await client.post(f"{API}/auth/refresh", json={"refresh_token": throwaway["refresh_token"]})
        check(r.status_code == 401, "revoked refresh token can no longer refresh", r)

        print("\n== #1 Directory ==")
        r = await client.get(f"{API}/orgs?org_type=RECYCLER", headers=bearer(col))
        check(r.status_code == 200 and any(o["legal_name"] == "Ecoplas Circular Solutions Ltd" for o in r.json()), "collector can list approved recyclers", r)
        check(all(o["org_type"] == "RECYCLER" for o in r.json()), "type filter applied")
        r = await client.get(f"{API}/orgs?org_type=EPR_CLIENT", headers=bearer(rec))
        check(r.status_code == 200 and any(o["legal_name"].startswith("Hindustan") for o in r.json()), "recycler can list EPR clients", r)
        r = await client.get(f"{API}/orgs", headers=bearer(rec))
        check(all(o["org_type"] != "GENERATOR" for o in r.json()), "generators are never listed in the directory")
        check(all("address" not in o for o in r.json()), "directory omits addresses for non-admins")
        r = await client.get(f"{API}/admin/orgs", headers=bearer(col))
        check(r.status_code == 403, "non-admin cannot list all organisations", r)
        r = await client.get(f"{API}/admin/orgs?status=APPROVED", headers=bearer(admin))
        check(r.status_code == 200 and len(r.json()) >= 5, "admin lists organisations by status", r)

        print("\n== #3 Pickup guard ==")
        r = await client.post(f"{API}/batches", headers=bearer(gen), json={
            "material_code": "PET", "estimated_kg": 50, "pickup_address": "x", "available_from": "2026-11-12T10:00:00Z", "available_to": "2026-11-20T10:00:00Z"})
        b = r.json()
        r = await client.post(f"{API}/collections/{b['id']}/offers", headers=bearer(col), json={"generator_rate_per_kg": 9, "proposed_pickup_at": "2026-11-13T10:00:00Z"})
        await client.post(f"{API}/batches/{b['id']}/offers/{r.json()['offer_id']}/accept", headers=bearer(gen))
        r = await client.post(f"{API}/collections/{b['id']}/pickup", headers=bearer(col), json={"collected_kg": 49})
        check(r.status_code == 200, "first pickup recorded", r)
        r = await client.post(f"{API}/collections/{b['id']}/pickup", headers=bearer(col), json={"collected_kg": 55})
        check(r.status_code == 409 and r.json()["error"]["code"] == "PICKUP_ALREADY_RECORDED", "second pickup refused", r)
        r = await client.get(f"{API}/batches/{b['id']}", headers=bearer(col))
        check(r.status_code == 200 and r.json()["quantities"]["collected_kg"] == "49.000", "batch detail still readable with single pickup", r)

        print("\n== #3 Receipt guards ==")
        r = await client.post(f"{API}/batches", headers=bearer(gen), json={
            "material_code": "PET", "estimated_kg": 40, "pickup_address": "x", "available_from": "2026-11-12T10:00:00Z", "available_to": "2026-11-20T10:00:00Z"})
        listed = r.json()
        r = await client.post(f"{API}/recycler/receipts", headers=bearer(rec), json={"batch_id": listed["id"], "received_kg": 40, "accepted_kg": 40, "rejected_kg": 0})
        check(r.status_code == 409 and r.json()["error"]["code"] == "INVALID_STATE_TRANSITION", "receipt refused for a batch never collected (LISTED)", r)

        b1 = await new_picked_up_batch(client, gen, col, kg=100.0)
        r = await client.post(f"{API}/recycler/receipts", headers=bearer(rec), json={"batch_id": b1["id"], "received_kg": 99, "accepted_kg": 90, "rejected_kg": 9})
        check(r.status_code == 201, "receipt for a picked-up batch", r)
        receipt_id = r.json()["receipt_id"]
        r = await client.post(f"{API}/recycler/receipts", headers=bearer(rec), json={"batch_id": b1["id"], "received_kg": 99, "accepted_kg": 95, "rejected_kg": 4})
        check(r.status_code == 409 and r.json()["error"]["code"] in ("RECEIPT_EXISTS", "INVALID_STATE_TRANSITION"), "second receipt refused (use correction)", r)
        r = await client.post(f"{API}/recycler/receipts", headers=bearer(rec), json={"batch_id": b1["id"], "received_kg": 99, "accepted_kg": 90, "rejected_kg": 5})
        check(r.status_code == 422, "accepted + rejected = received still enforced first", r)

        print("\n== #2 Receipts list ==")
        r = await client.get(f"{API}/recycler/receipts", headers=bearer(rec))
        mine = [x for x in r.json() if x["id"] == receipt_id]
        check(r.status_code == 200 and mine and mine[0]["available_kg"] == 90.0, "receipt listed with available kg = accepted", r)
        r = await client.get(f"{API}/recycler/receipts", headers=bearer(col))
        check(r.status_code == 403, "receipts list is recycler-only", r)

        print("\n== #3 Processing guards ==")
        run_body = lambda kg, out, mat="PET", rid=receipt_id: {
            "material_code": mat, "run_started_at": "2026-11-13T08:00:00Z", "run_ended_at": "2026-11-13T10:00:00Z",
            "inputs": [{"recycler_receipt_id": rid, "input_kg": kg}], "output_kg": out, "residue_kg": 1, "eligible_kg": out}
        r = await client.post(f"{API}/recycler/processing-records", headers=bearer(rec), json=run_body(500, 400))
        check(r.status_code == 409 and r.json()["error"]["code"] == "INPUT_EXCEEDS_AVAILABLE", "input above accepted kg refused", r)
        check(r.json()["error"]["details"]["available_kg"] == "90.000", "error carries available kg")
        r = await client.post(f"{API}/recycler/processing-records", headers=bearer(rec), json=run_body(50, 40, mat="HDPE"))
        check(r.status_code == 422 and r.json()["error"]["code"] == "MATERIAL_MISMATCH", "material mismatch refused", r)
        r = await client.post(f"{API}/recycler/processing-records", headers=bearer(rec), json=run_body(60, 54))
        check(r.status_code == 201, "partial run of 60 kg accepted", r)
        r = await client.post(f"{API}/recycler/processing-records", headers=bearer(rec), json=run_body(40, 36))
        check(r.status_code == 409, "second run above remaining 30 kg refused", r)
        r = await client.post(f"{API}/recycler/processing-records", headers=bearer(rec), json=run_body(30, 27))
        check(r.status_code == 201, "second run within remaining 30 kg accepted", r)
        r = await client.get(f"{API}/recycler/receipts", headers=bearer(rec))
        mine = [x for x in r.json() if x["id"] == receipt_id][0]
        check(mine["available_kg"] == 0.0 and mine["processed_input_kg"] == 90.0, "receipt shows fully processed")
        r = await client.post(f"{API}/recycler/receipts/{receipt_id}/corrections", headers=bearer(rec),
                              json={"received_kg": 99, "accepted_kg": 80, "rejected_kg": 19, "reason": "test"})
        check(r.status_code == 409 and r.json()["error"]["code"] == "ACCEPTED_BELOW_PROCESSED", "correction cannot drop accepted below processed", r)

        print("\n== #3 NGO decision on current record only ==")
        r = await client.get(f"{API}/ngo/verifications", headers=bearer(ngo))
        target = next(v for v in r.json() if v["batch_id"] == b1["id"])
        r = await client.post(f"{API}/ngo/verifications/{target['id']}/decision", headers=bearer(ngo), json={"decision": "VERIFIED", "comments": "ok"})
        check(r.status_code == 200, "decision on current verification", r)
        r = await client.post(f"{API}/ngo/verifications/{target['id']}/decision", headers=bearer(ngo), json={"decision": "REJECTED", "comments": "stale"})
        check(r.status_code == 409 and r.json()["error"]["code"] == "NOT_CURRENT", "decision on superseded verification refused", r)

        print("\nALL INTEGRATION-PATCH TESTS PASSED")


if __name__ == "__main__":
    asyncio.run(run())
