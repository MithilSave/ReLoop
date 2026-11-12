"""Tests for the AI polymer classification plug-in point.

Run after seed_data.py:
    python seed_data.py && python test_ai_classifier.py

1. With no model connected, /ai/classify answers 503 AI_MODEL_NOT_CONFIGURED (no placeholder prediction).
2. With a stand-in model plugged into classifier.py, labels are mapped to material codes, the prediction is
   stored, and the material the generator finally chooses is recorded against it.
"""

import asyncio
import base64
import os
import sys

import httpx

sys.path.insert(0, os.path.abspath(os.path.dirname(__file__)))

from app.main import app  # noqa: E402
from app.modules.ai import classifier  # noqa: E402

API = "/api/v1"
IMG = base64.b64encode(b"\x89PNG\r\n\x1a\nnot-a-real-image").decode()


def check(cond, label, resp=None):
    if not cond:
        detail = f" -> {resp.status_code} {resp.text[:300]}" if resp is not None else ""
        raise AssertionError(f"FAIL: {label}{detail}")
    print(f" [PASS] {label}")


async def main():
    transport = httpx.ASGITransport(app=app)
    async with httpx.AsyncClient(transport=transport, base_url="http://t") as c:
        r = await c.post(f"{API}/auth/login", json={"login": "generator@reloop.in", "password": "reloop123"})
        h = {"Authorization": f"Bearer {r.json()['access_token']}"}

        # 1. Not configured
        classifier.MODEL_PATH = None
        classifier._model = None
        r = await c.get(f"{API}/ai/status", headers=h)
        check(r.status_code == 200 and r.json()["configured"] is False, "status reports no model connected", r)
        r = await c.post(f"{API}/ai/classify", json={"image_base64": IMG}, headers=h)
        check(r.status_code == 503 and r.json()["error"]["code"] == "AI_MODEL_NOT_CONFIGURED", "classify refuses with 503 when no model", r)
        r = await c.post(f"{API}/ai/classify", json={}, headers=h)
        check(r.status_code == 422 and r.json()["error"]["code"] == "IMAGE_REQUIRED", "classify requires an image", r)
        r = await c.post(f"{API}/ai/classify", json={"image_base64": "%%%"}, headers=h)
        check(r.status_code == 422 and r.json()["error"]["code"] == "IMAGE_INVALID", "classify rejects invalid base64", r)

        # 2. Stand-in model (what the team's notebook code will replace)
        classifier.MODEL_PATH = __file__
        classifier.MODEL_VERSION = "test-model"
        classifier.load_model = lambda path: "stand-in"
        classifier.predict = lambda model, b: [("Hdpe", 0.71), ("pet", 0.2), ("bottle_cap_pp", 0.09)]
        r = await c.get(f"{API}/ai/status", headers=h)
        check(r.json()["configured"] is True, "status reports model connected", r)
        r = await c.post(f"{API}/ai/classify", json={"image_base64": IMG}, headers=h)
        check(r.status_code == 200, "classify returns a prediction", r)
        d = r.json()
        check(d["predicted_code"] == "HDPE" and d["resin_code"] == 2 and d["low_confidence"] is False, "label mapped to HDPE with resin code 2", r)
        check([k["code"] for k in d["top_k"]] == ["HDPE", "PET", "OTHER"], "unmapped label reported as OTHER", r)
        check(len(d["image_sha256"]) == 64 and d["model_version"] == "test-model", "hash and model version returned", r)

        classifier.predict = lambda model, b: [("pp", 0.4), ("ps", 0.35), ("pet", 0.25)]
        r = await c.post(f"{API}/ai/classify", json={"image_base64": IMG}, headers=h)
        check(r.json()["low_confidence"] is True, "confidence below threshold is flagged low", r)

        # Generator overrides the suggestion: the chosen material is recorded on the prediction
        pid = d["prediction_id"]
        r = await c.post(f"{API}/batches", headers=h, json={
            "material_code": "PET", "estimated_kg": 40, "pickup_address": "Test address, Mumbai",
            "available_from": "2026-12-01T09:00:00Z", "available_to": "2026-12-02T18:00:00Z", "ai_prediction_id": pid,
        })
        check(r.status_code in (200, 201), "listing created with ai_prediction_id", r)
        from app.core import database  # noqa: E402
        from app.models.audit import AIPrediction  # noqa: E402
        import uuid
        async with database.async_session() as s:
            p = await s.get(AIPrediction, uuid.UUID(pid))
            check(p is not None and p.predicted_code == "HDPE" and p.user_confirmed_code == "PET", "generator's final choice stored against the prediction")
    print("All AI classifier checks passed.")


if __name__ == "__main__":
    asyncio.run(main())
