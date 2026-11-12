"""All ReLoop database models."""

from app.models.reference import MaterialCategory
from app.models.identity import User, Organisation, OrgMembership, RefreshToken
from app.models.profiles import (
    GeneratorProfile,
    CollectorProfile,
    CollectorMaterial,
    RecyclerProfile,
    NGOProfile,
    EPRClientProfile,
    NGOScope,
    EPRTarget,
)
from app.models.batches import WasteBatch, BatchEvent
from app.models.offers import CollectionOffer, RecyclerOffer
from app.models.custody import (
    PickupRecord,
    RecyclerReceipt,
    ProcessingRecord,
    ProcessingInput,
)
from app.models.allocations import Certificate, EPRAllocation
from app.models.ngo import NGOVerification
from app.models.payments import Payment
from app.models.documents import Document, DocumentLink
from app.models.audit import AnomalyFlag, AIPrediction, AuditLog
from app.models.intelligence import (
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
)

__all__ = [
    "MaterialCategory",
    "User",
    "Organisation",
    "OrgMembership",
    "RefreshToken",
    "GeneratorProfile",
    "CollectorProfile",
    "CollectorMaterial",
    "RecyclerProfile",
    "NGOProfile",
    "EPRClientProfile",
    "NGOScope",
    "EPRTarget",
    "WasteBatch",
    "BatchEvent",
    "CollectionOffer",
    "RecyclerOffer",
    "PickupRecord",
    "RecyclerReceipt",
    "ProcessingRecord",
    "ProcessingInput",
    "Certificate",
    "EPRAllocation",
    "NGOVerification",
    "Payment",
    "Document",
    "DocumentLink",
    "AnomalyFlag",
    "AIPrediction",
    "AuditLog",
    "PricingAssumption",
    "RecyclerDemandProfile",
    "GeneratorSupplyProfile",
    "AggregationPlan",
    "AggregationPlanItem",
    "TransportConsignment",
    "ConsignmentItem",
    "CostEstimate",
    "SupplierPerformanceMetric",
    "Forecast",
]
