# 13 — Hackathon Presentation

Suggested length: 8 minutes of pitch plus 4 minutes of demo. One idea per slide.

## Slide flow

1. **Hook.** "Collected is not recycled." Show one Mumbai society's 100 kg of PET: 98 collected, 90 accepted, 82 recycled. Most systems report 100.
2. **Problem.** Informal flows; weak, fragmented EPR evidence; double-claim risk; recyclers buy feedstock on price, not on usable kg.
3. **Why existing workflows fall short.** Collection apps stop at pickup. EPR paperwork starts at the recycler. Nothing links the two with independent review. Procurement is one phone call per small supplier.
4. **ReLoop.** A marketplace plus a material passport for every batch, connecting five participants (3 operational, 1 independent verifier, 1 corporate customer).
5. **Material passport.** A QR-linked journey with six quantity stages that are never merged (03 §2).
6. **Procurement intelligence.** The aggregation engine turns 12 small PP listings into one 500 kg sourcing plan. Landed cost per *usable* kg beats purchase price (10 §4.4: ₹14.27 vs ₹17.05).
7. **Trust layer.** The NGO reviews evidence read-only, and its decisions are append-only. Yield is computed only from measured runs.
8. **EPR layer.** Allocation ledger: Σ allocations ≤ eligible kg, enforced by the database. Certificates stay with the registered recycler, and ReLoop stores references only.
9. **Architecture.** Modular monolith: React → FastAPI → Postgres + S3 (04 §1 diagram).
10. **Business model.** Marketplace fee, EPR subscription, reporting, verification coordination. No certificate trading.
11. **Impact metrics.** Kg processed (not just collected), acceptance rate, yield, % verified, zero duplicate allocations, ₹ paid to generators.
12. **Scalability and limits.** City partitioning, worker queue. Limits: no portal integration, NGO review is not statutory, forecasts are advisory.

## Live demo script (4 min, seeded data)

1. **Recycler:** "Need 500 kg PP by 30 Nov" → Propose plan → show items, the excluded batch ("material unconfirmed, AI 0.46"), shortfall 1.6 kg, and the cost waterfall. Accept.
2. **Collector (phone view):** Accept plan → pickup at stop 1: enter 58 kg, generator OTP → dispatch a consignment of 3 batches.
3. **Recycler:** Scan each QR → receipt for one batch: 57.5 received, 52 accepted, 5.5 rejected → processing run with 3 inputs: input 160, output 141, residue 13 → yield 88.1%, unaccounted 6 kg = 3.75% (mass-balance flag AN-10 shown).
4. **NGO:** Queue → split-view passport → VERIFIED.
5. **EPR client:** Request 100 kg → recycler allocates → try another 60 kg → **409 exceeds available**. Download the evidence report.
6. **Recycler supply outlook:** HDPE next month: demand 5 t, confirmed 3 t (solid), predicted 1.2 t (hatched), gap 2 t → recommended suppliers.

## AI contribution (honest framing)
Photo-based polymer suggestion with confidence and a manual fallback; explainable matching; heuristic aggregation; statistical forecasts. Everything is advisory and versioned.

## Judges' likely questions
- *Can't a recycler double-sell off-platform?* Yes. We declare this as a residual risk, mitigated by the NGO, declarations and reconciliation. The official portal remains the authority.
- *Why trust the NGO?* Its fee is per period, not per approval; it has a COI declaration, named reviewers, and append-only decisions.
- *Is the yield real?* It is computed only from measured input and output, and an incomplete run shows "incomplete", never 100%.
- *Does aggregation merge batches?* No. Each batch keeps its QR, its OTP pickup and its own receipt. Only the truck is shared.
