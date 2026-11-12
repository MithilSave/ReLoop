import 'batch.dart';

class EPRAllocation {
  final String id;
  final String allocationCode;
  final String processingRunId;
  final String runCode;
  final String eprOrgId;
  final String eprOrgName;
  final String recyclerOrgId;
  final String recyclerName;
  final List<String> batchCodes;
  final PackagingCategory packagingCategory;
  final String reportingPeriod;
  final double quantityKg;
  final String status; // ACTIVE, REVERSED
  final String certificateId;
  final bool isNgoVerified;
  final DateTime createdAt;
  final String? reversalReason;

  const EPRAllocation({
    required this.id,
    required this.allocationCode,
    required this.processingRunId,
    required this.runCode,
    required this.eprOrgId,
    required this.eprOrgName,
    required this.recyclerOrgId,
    required this.recyclerName,
    required this.batchCodes,
    required this.packagingCategory,
    required this.reportingPeriod,
    required this.quantityKg,
    required this.status,
    required this.certificateId,
    required this.isNgoVerified,
    required this.createdAt,
    this.reversalReason,
  });

  EPRAllocation copyWith({
    String? id,
    String? allocationCode,
    String? processingRunId,
    String? runCode,
    String? eprOrgId,
    String? eprOrgName,
    String? recyclerOrgId,
    String? recyclerName,
    List<String>? batchCodes,
    PackagingCategory? packagingCategory,
    String? reportingPeriod,
    double? quantityKg,
    String? status,
    String? certificateId,
    bool? isNgoVerified,
    DateTime? createdAt,
    String? reversalReason,
  }) {
    return EPRAllocation(
      id: id ?? this.id,
      allocationCode: allocationCode ?? this.allocationCode,
      processingRunId: processingRunId ?? this.processingRunId,
      runCode: runCode ?? this.runCode,
      eprOrgId: eprOrgId ?? this.eprOrgId,
      eprOrgName: eprOrgName ?? this.eprOrgName,
      recyclerOrgId: recyclerOrgId ?? this.recyclerOrgId,
      recyclerName: recyclerName ?? this.recyclerName,
      batchCodes: batchCodes ?? this.batchCodes,
      packagingCategory: packagingCategory ?? this.packagingCategory,
      reportingPeriod: reportingPeriod ?? this.reportingPeriod,
      quantityKg: quantityKg ?? this.quantityKg,
      status: status ?? this.status,
      certificateId: certificateId ?? this.certificateId,
      isNgoVerified: isNgoVerified ?? this.isNgoVerified,
      createdAt: createdAt ?? this.createdAt,
      reversalReason: reversalReason ?? this.reversalReason,
    );
  }
}

class EPRTarget {
  final String id;
  final PackagingCategory category;
  final String categoryLabel;
  final String period;
  final double targetKg;
  final double allocatedKg;
  final double verifiedKg;
  final double unverifiedKg;

  const EPRTarget({
    required this.id,
    required this.category,
    required this.categoryLabel,
    required this.period,
    required this.targetKg,
    required this.allocatedKg,
    required this.verifiedKg,
    required this.unverifiedKg,
  });

  EPRTarget copyWith({
    String? id,
    PackagingCategory? category,
    String? categoryLabel,
    String? period,
    double? targetKg,
    double? allocatedKg,
    double? verifiedKg,
    double? unverifiedKg,
  }) {
    return EPRTarget(
      id: id ?? this.id,
      category: category ?? this.category,
      categoryLabel: categoryLabel ?? this.categoryLabel,
      period: period ?? this.period,
      targetKg: targetKg ?? this.targetKg,
      allocatedKg: allocatedKg ?? this.allocatedKg,
      verifiedKg: verifiedKg ?? this.verifiedKg,
      unverifiedKg: unverifiedKg ?? this.unverifiedKg,
    );
  }
}
