import 'batch.dart';

class AggregationPlanItem {
  final String batchId;
  final String batchCode;
  final String locality;
  final String address;
  final double kg;
  final int sequenceNo;
  final List<String> reasons;

  const AggregationPlanItem({
    required this.batchId,
    required this.batchCode,
    required this.locality,
    required this.address,
    required this.kg,
    required this.sequenceNo,
    required this.reasons,
  });
}

class AggregationPlanExcluded {
  final String batchId;
  final String batchCode;
  final String locality;
  final double kg;
  final String reason;

  const AggregationPlanExcluded({
    required this.batchId,
    required this.batchCode,
    required this.locality,
    required this.kg,
    required this.reason,
  });
}

class AggregationPlan {
  final String id;
  final String planCode;
  final String recyclerOrgId;
  final PolymerType materialCode;
  final double targetKg;
  final String suggestedCollectorId;
  final String suggestedCollectorName;
  final List<AggregationPlanItem> items;
  final List<AggregationPlanExcluded> excluded;
  final String status; // PROPOSED, ACCEPTED, ACTIVE, COMPLETED, CANCELLED
  final double totalEstimatedKg;
  final double expectedUsableKg;
  final double collectionCost;
  final double landedCostPerUsableKg;
  final int stopsCount;
  final String needBy;
  final DateTime createdAt;

  const AggregationPlan({
    required this.id,
    required this.planCode,
    required this.recyclerOrgId,
    required this.materialCode,
    required this.targetKg,
    required this.suggestedCollectorId,
    required this.suggestedCollectorName,
    required this.items,
    required this.excluded,
    required this.status,
    required this.totalEstimatedKg,
    required this.expectedUsableKg,
    required this.collectionCost,
    required this.landedCostPerUsableKg,
    required this.stopsCount,
    required this.needBy,
    required this.createdAt,
  });

  AggregationPlan copyWith({
    String? id,
    String? planCode,
    String? recyclerOrgId,
    PolymerType? materialCode,
    double? targetKg,
    String? suggestedCollectorId,
    String? suggestedCollectorName,
    List<AggregationPlanItem>? items,
    List<AggregationPlanExcluded>? excluded,
    String? status,
    double? totalEstimatedKg,
    double? expectedUsableKg,
    double? collectionCost,
    double? landedCostPerUsableKg,
    int? stopsCount,
    String? needBy,
    DateTime? createdAt,
  }) {
    return AggregationPlan(
      id: id ?? this.id,
      planCode: planCode ?? this.planCode,
      recyclerOrgId: recyclerOrgId ?? this.recyclerOrgId,
      materialCode: materialCode ?? this.materialCode,
      targetKg: targetKg ?? this.targetKg,
      suggestedCollectorId: suggestedCollectorId ?? this.suggestedCollectorId,
      suggestedCollectorName: suggestedCollectorName ?? this.suggestedCollectorName,
      items: items ?? this.items,
      excluded: excluded ?? this.excluded,
      status: status ?? this.status,
      totalEstimatedKg: totalEstimatedKg ?? this.totalEstimatedKg,
      expectedUsableKg: expectedUsableKg ?? this.expectedUsableKg,
      collectionCost: collectionCost ?? this.collectionCost,
      landedCostPerUsableKg: landedCostPerUsableKg ?? this.landedCostPerUsableKg,
      stopsCount: stopsCount ?? this.stopsCount,
      needBy: needBy ?? this.needBy,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
