import 'batch.dart';

class ProcessingRunInput {
  final String batchId;
  final String batchCode;
  final String receiptId;
  final double inputKg;

  const ProcessingRunInput({
    required this.batchId,
    required this.batchCode,
    required this.receiptId,
    required this.inputKg,
  });
}

class ProcessingRun {
  final String id;
  final String runCode;
  final String recyclerOrgId;
  final String recyclerName;
  final PolymerType materialCode;
  final PackagingCategory packagingCategory;
  final DateTime runStartedAt;
  final DateTime runEndedAt;
  final List<ProcessingRunInput> inputs;
  final double inputKg;
  final double outputKg;
  final double residueKg;
  final String outputForm; // Pellets, Flakes, Granules
  final double eligibleKg;
  final double allocatedKg;
  final String measurementStatus; // COMPLETE, INCOMPLETE
  final double yieldPct;
  final List<String> certificateRefs;
  final DateTime createdAt;

  const ProcessingRun({
    required this.id,
    required this.runCode,
    required this.recyclerOrgId,
    required this.recyclerName,
    required this.materialCode,
    required this.packagingCategory,
    required this.runStartedAt,
    required this.runEndedAt,
    required this.inputs,
    required this.inputKg,
    required this.outputKg,
    required this.residueKg,
    required this.outputForm,
    required this.eligibleKg,
    required this.allocatedKg,
    required this.measurementStatus,
    required this.yieldPct,
    required this.certificateRefs,
    required this.createdAt,
  });

  ProcessingRun copyWith({
    String? id,
    String? runCode,
    String? recyclerOrgId,
    String? recyclerName,
    PolymerType? materialCode,
    PackagingCategory? packagingCategory,
    DateTime? runStartedAt,
    DateTime? runEndedAt,
    List<ProcessingRunInput>? inputs,
    double? inputKg,
    double? outputKg,
    double? residueKg,
    String? outputForm,
    double? eligibleKg,
    double? allocatedKg,
    String? measurementStatus,
    double? yieldPct,
    List<String>? certificateRefs,
    DateTime? createdAt,
  }) {
    return ProcessingRun(
      id: id ?? this.id,
      runCode: runCode ?? this.runCode,
      recyclerOrgId: recyclerOrgId ?? this.recyclerOrgId,
      recyclerName: recyclerName ?? this.recyclerName,
      materialCode: materialCode ?? this.materialCode,
      packagingCategory: packagingCategory ?? this.packagingCategory,
      runStartedAt: runStartedAt ?? this.runStartedAt,
      runEndedAt: runEndedAt ?? this.runEndedAt,
      inputs: inputs ?? this.inputs,
      inputKg: inputKg ?? this.inputKg,
      outputKg: outputKg ?? this.outputKg,
      residueKg: residueKg ?? this.residueKg,
      outputForm: outputForm ?? this.outputForm,
      eligibleKg: eligibleKg ?? this.eligibleKg,
      allocatedKg: allocatedKg ?? this.allocatedKg,
      measurementStatus: measurementStatus ?? this.measurementStatus,
      yieldPct: yieldPct ?? this.yieldPct,
      certificateRefs: certificateRefs ?? this.certificateRefs,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
