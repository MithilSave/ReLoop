# ReLoop Documentation Index

ReLoop is a plastic waste marketplace and traceability platform for a single Indian city (pilot: Mumbai). It also supports EPR compliance work. This folder is the development blueprint. **No application code exists yet.**

## Recommended reading order

| # | File | What it contains | Read if you are… |
|---|------|------------------|------------------|
| 00 | [00_PROJECT_OVERVIEW.md](00_PROJECT_OVERVIEW.md) | What ReLoop is, the problem, participants, scope, limitations | Everyone (start here) |
| 14 | [14_GLOSSARY_AND_ASSUMPTIONS.md](14_GLOSSARY_AND_ASSUMPTIONS.md) | Terms, polymer codes, assumptions, open questions | Everyone (keep open alongside) |
| 01 | [01_PRODUCT_REQUIREMENTS.md](01_PRODUCT_REQUIREMENTS.md) | Functional/non-functional requirements, user stories, acceptance criteria | Product, dev, QA |
| 02 | [02_BUSINESS_MODEL.md](02_BUSINESS_MODEL.md) | Money flows, pricing, revenue streams, partner models | Business, pitch team |
| 03 | [03_END_TO_END_WORKFLOWS.md](03_END_TO_END_WORKFLOWS.md) | Batch lifecycle, state machines, exceptions, flowcharts | Everyone building features |
| 08 | [08_EPR_TRACEABILITY_FRAMEWORK.md](08_EPR_TRACEABILITY_FRAMEWORK.md) | Indian regulatory context, compliance boundaries, allocation and double-counting rules | Anyone touching EPR features |
| 07 | [07_NGO_VERIFICATION_FRAMEWORK.md](07_NGO_VERIFICATION_FRAMEWORK.md) | NGO onboarding, independence, review workflow | NGO module devs |
| 04 | [04_SYSTEM_ARCHITECTURE.md](04_SYSTEM_ARCHITECTURE.md) | Modular monolith, stack, deployment, scaling path | Developers |
| 05 | [05_DATABASE_DESIGN.md](05_DATABASE_DESIGN.md) | Tables, constraints, ER diagram, lineage, allocation design | Backend devs |
| 06 | [06_API_SPECIFICATION.md](06_API_SPECIFICATION.md) | REST endpoints, payloads, permissions, errors | Backend + frontend devs |
| 11 | [11_SECURITY_AND_AUDIT.md](11_SECURITY_AND_AUDIT.md) | AuthN/AuthZ, permission matrix, audit, threats | Backend devs, reviewers |
| 09 | [09_DASHBOARDS_AND_UI.md](09_DASHBOARDS_AND_UI.md) | Screens per role, actions, endpoints used | Frontend devs, designers |
| 10 | [10_AI_AND_INTELLIGENCE.md](10_AI_AND_INTELLIGENCE.md) | Image classification, matching, anomaly rules | ML / backend devs |
| 12 | [12_DEVELOPMENT_ROADMAP.md](12_DEVELOPMENT_ROADMAP.md) | Milestones, P0/P1/P2, testing, demo plan | Team lead |
| 13 | [13_HACKATHON_PRESENTATION.md](13_HACKATHON_PRESENTATION.md) | Pitch narrative, demo script, judges' Q&A | Pitch team |

## Source-of-truth rules

To avoid contradictions, each concept has one owning file. Other files link to it rather than restating it.

| Concept | Owning file |
|---|---|
| Quantity stages (collected → allocated) | 03 §2 |
| Batch and verification status values | 03 §6 |
| Table and column definitions | 05 |
| Endpoint list and payloads | 06 |
| Role-permission matrix | 11 §3 |
| Regulatory facts and their verification status | 08 |
| Assumptions and open questions (IDs `A-xx`, `Q-xx`) | 14 |

## Labels used throughout

- **[REG]**: Regulatory statement. See 08 for its source and verification status.
- **[DESIGN]**: A ReLoop platform design decision. It is not a legal requirement.
- **[ASSUMPTION]**: Needs business or legal validation. Tracked in 14.
- **[ILLUSTRATIVE]**: Example numbers only. Never hard-coded.
- **[SIMULATED]**: Demonstrated with mock data in the MVP/hackathon build.
