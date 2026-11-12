# 00 — Project Overview

## 1. What ReLoop is

ReLoop is a digital marketplace and traceability platform for post-consumer plastic waste in one Indian city. It connects five participants around a single traceable unit, the **waste batch**:

1. **Generators**: households, housing societies, shops, offices and institutions that produce plastic waste.
2. **Collectors**: commercial collection and transport businesses.
3. **Recyclers**: registered Plastic Waste Processors (PWPs) that receive and process plastic.
4. **Independent NGOs**: verification partners that review the evidence trail.
5. **EPR companies**: Producers, Importers and Brand Owners (PIBOs) with Extended Producer Responsibility obligations. They are the paying corporate customers.

The first three are the only **operational** roles. The NGO is an independent reviewer, and the EPR company is a customer and observer. No other core roles exist. See 14 for definitions.

## 2. Problem statement

- **Leakage and informality.** Much urban plastic moves through informal, unrecorded channels. Generators earn little and have no visibility into where the plastic goes.
- **Collection is not recycling.** Most programmes count kilograms *collected*. They rarely track how much was *accepted*, *processed*, or lost as residue.
- **Weak evidence for EPR.** PIBOs depend on processing evidence from recyclers. When the paper trail is fragmented, it is hard to show where material came from, and the same quantity could be claimed twice.
- **No independent check.** Records are self-reported by the parties who are paid for them.

## 3. Vision

Every kilogram of plastic that ReLoop reports as recycled can be traced to its source. It is backed by evidence at each handover, reviewed by an independent party, and claimed by at most one EPR client.

## 4. Objectives

| ID | Objective | Measure |
|---|---|---|
| O-A | Plastic waste management: move waste efficiently from source to recycler | Pickup completion time, kg collected, rejection rate |
| O-B | EPR traceability and monitoring: an auditable chain of custody | % processed kg with full evidence, % NGO-verified, zero duplicate allocations |
| O-C | Procurement intelligence: make small, scattered supply economically viable for recyclers | Plans fulfilled, landed ₹ per usable kg, forecast shortage lead time |

## 5. Target users and value proposition

| Participant | Pain today | ReLoop value |
|---|---|---|
| Generator | Low or no payment, no visibility | Transparent payment per kg, tracking, contribution certificate |
| Collector | Irregular supply, price uncertainty, late payment | Steady listings, posted recycler rates, faster settlement, transaction records (**no loyalty points**) |
| Recycler | Unreliable feedstock quality, manual paperwork, fragmented small supply | Pre-declared material and quality, QR receipt, aggregated sourcing plans, landed-cost comparison, shortage alerts, organised evidence for its own compliance |
| NGO | Hard to audit scattered records | One evidence view per batch, reconciliation tools, read-only access to source data |
| EPR company | Fragmented evidence, double-claim risk | Allocation ledger with safeguards, certificate references, exportable evidence reports |

## 6. Business model (summary)

ReLoop earns from marketplace service fees, EPR dashboard subscriptions, reporting and verification coordination. It **does not issue or sell statutory EPR certificates**. Details are in [02_BUSINESS_MODEL.md](02_BUSINESS_MODEL.md).

## 7. Scope and limitations

**In scope (MVP, EPR-first):** batch traceability and material passport, QR, pickup/delivery, recycler receipt and processing records with measured yield, NGO verification, audit trail, EPR dashboard, allocation safeguards and evidence reports, basic feedstock aggregation, and basic landed cost. Forecasting and supplier indicators are P1 (12).

**Out of scope / limitations:**

- ReLoop is **not** the CPCB EPR portal and does not integrate with it in the MVP. See 08.
- NGO verification is supporting evidence only. It is **not** a statutory certification.
- AI plastic identification is an aid. It is not a material or chemical analysis.
- A single city only. Real payments and real registrations are [SIMULATED] in the hackathon build. See 12 §5.

## 8. What makes ReLoop different

1. **Six-stage quantity ledger.** The stages are collected, received, accepted, processed, NGO-verified and EPR-allocated. They are never assumed equal. See 03 §2.
2. **Allocation ledger with database-level double-counting safeguards.** See 05 §6.
3. **Lineage across mixed processing runs.** Many batches can feed one run, and each run's output is traced back to its source batches. See 05 §5.
4. **Structurally independent NGO review.** The NGO has its own records and cannot write to operational data. See 07.
5. **Material passport.** Every batch has a persistent identity and a complete history, from listing through processing to allocation, with measured yield. See 05 §4.10.
6. **Procurement intelligence** (10). This includes:
   - an aggregation engine that groups small compatible listings into recycler-sized plans without erasing batch identities;
   - landed cost per *usable* kg rather than purchase price;
   - explainable supplier indicators shown with their sample size;
   - forecasts that are always kept separate from confirmed supply.
7. **Honest boundaries.** Every regulatory statement is labelled with its source or marked as needing validation.
