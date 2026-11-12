enum PolymerType {
  pet,
  hdpe,
  pp,
  ldpe,
  other;

  String get label {
    switch (this) {
      case PolymerType.pet:
        return 'PET';
      case PolymerType.hdpe:
        return 'HDPE';
      case PolymerType.pp:
        return 'PP';
      case PolymerType.ldpe:
        return 'LDPE';
      case PolymerType.other:
        return 'OTHER';
    }
  }

  String get code => label;

  int get ricNumber {
    switch (this) {
      case PolymerType.pet:
        return 1;
      case PolymerType.hdpe:
        return 2;
      case PolymerType.pp:
        return 5;
      case PolymerType.ldpe:
        return 4;
      case PolymerType.other:
        return 7;
    }
  }
}

enum PackagingCategory {
  catI,
  catII,
  catIII,
  catIV;

  String get label {
    switch (this) {
      case PackagingCategory.catI:
        return 'Cat-I (Rigid)';
      case PackagingCategory.catII:
        return 'Cat-II (Flexible)';
      case PackagingCategory.catIII:
        return 'Cat-III (Multilayer)';
      case PackagingCategory.catIV:
        return 'Cat-IV (Compostable)';
    }
  }

  String get shortLabel {
    switch (this) {
      case PackagingCategory.catI:
        return 'Cat-I';
      case PackagingCategory.catII:
        return 'Cat-II';
      case PackagingCategory.catIII:
        return 'Cat-III';
      case PackagingCategory.catIV:
        return 'Cat-IV';
    }
  }
}

enum BatchStatus {
  listed,
  assigned,
  pickedUp,
  inTransit,
  received,
  processed,
  rejectedAtReceipt,
  cancelled;

  String get label {
    switch (this) {
      case BatchStatus.listed:
        return 'LISTED';
      case BatchStatus.assigned:
        return 'ASSIGNED';
      case BatchStatus.pickedUp:
        return 'PICKED_UP';
      case BatchStatus.inTransit:
        return 'IN_TRANSIT';
      case BatchStatus.received:
        return 'RECEIVED';
      case BatchStatus.processed:
        return 'PROCESSED';
      case BatchStatus.rejectedAtReceipt:
        return 'REJECTED_AT_RECEIPT';
      case BatchStatus.cancelled:
        return 'CANCELLED';
    }
  }
}

class BatchQuantities {
  final double estimatedKg;
  final double? collectedKg;
  final double? receivedKg;
  final double? acceptedKg;
  final double? rejectedKg;
  final double? processedKg;
  final double? verifiedKg;
  final double? allocatedKg;

  const BatchQuantities({
    required this.estimatedKg,
    this.collectedKg,
    this.receivedKg,
    this.acceptedKg,
    this.rejectedKg,
    this.processedKg,
    this.verifiedKg,
    this.allocatedKg,
  });

  BatchQuantities copyWith({
    double? estimatedKg,
    double? collectedKg,
    double? receivedKg,
    double? acceptedKg,
    double? rejectedKg,
    double? processedKg,
    double? verifiedKg,
    double? allocatedKg,
  }) {
    return BatchQuantities(
      estimatedKg: estimatedKg ?? this.estimatedKg,
      collectedKg: collectedKg ?? this.collectedKg,
      receivedKg: receivedKg ?? this.receivedKg,
      acceptedKg: acceptedKg ?? this.acceptedKg,
      rejectedKg: rejectedKg ?? this.rejectedKg,
      processedKg: processedKg ?? this.processedKg,
      verifiedKg: verifiedKg ?? this.verifiedKg,
      allocatedKg: allocatedKg ?? this.allocatedKg,
    );
  }
}

class CollectionOffer {
  final String id;
  final String batchId;
  final String collectorOrgId;
  final String collectorName;
  final double ratePerKg;
  final String proposedPickupAt;
  final double matchScore;
  final String status; // PENDING, ACCEPTED, DECLINED, WITHDRAWN
  final List<String> reasons;
  final DateTime createdAt;

  const CollectionOffer({
    required this.id,
    required this.batchId,
    required this.collectorOrgId,
    required this.collectorName,
    required this.ratePerKg,
    required this.proposedPickupAt,
    required this.matchScore,
    required this.status,
    required this.reasons,
    required this.createdAt,
  });
}

class NGOVerification {
  final String id;
  final String batchId;
  final String batchCode;
  final String? processingRunId;
  final String reviewerId;
  final String reviewerName;
  final String decision; // PENDING, UNDER_REVIEW, VERIFIED, FLAGGED, REJECTED, REQUIRES_CORRECTION
  final String comments;
  final List<String> evidenceReviewed;
  final double variancePct;
  final DateTime updatedAt;
  final int version;

  const NGOVerification({
    required this.id,
    required this.batchId,
    required this.batchCode,
    this.processingRunId,
    required this.reviewerId,
    required this.reviewerName,
    required this.decision,
    required this.comments,
    required this.evidenceReviewed,
    required this.variancePct,
    required this.updatedAt,
    this.version = 1,
  });

  NGOVerification copyWith({
    String? id,
    String? batchId,
    String? batchCode,
    String? processingRunId,
    String? reviewerId,
    String? reviewerName,
    String? decision,
    String? comments,
    List<String>? evidenceReviewed,
    double? variancePct,
    DateTime? updatedAt,
    int? version,
  }) {
    return NGOVerification(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      batchCode: batchCode ?? this.batchCode,
      processingRunId: processingRunId ?? this.processingRunId,
      reviewerId: reviewerId ?? this.reviewerId,
      reviewerName: reviewerName ?? this.reviewerName,
      decision: decision ?? this.decision,
      comments: comments ?? this.comments,
      evidenceReviewed: evidenceReviewed ?? this.evidenceReviewed,
      variancePct: variancePct ?? this.variancePct,
      updatedAt: updatedAt ?? this.updatedAt,
      version: version ?? this.version,
    );
  }
}

class WasteBatch {
  final String id;
  final String batchCode;
  final String generatorOrgId;
  final String generatorName;
  final PolymerType material;
  final PackagingCategory packagingCategory;
  final BatchQuantities quantities;
  final BatchStatus status;
  final String pickupAddress;
  final String locality;
  final double lat;
  final double lng;
  final String availableFrom;
  final String availableTo;
  final List<String> photos;
  final String qrCodeUrl;
  final DateTime createdAt;
  final List<CollectionOffer> offers;
  final String? currentOfferId;
  final String? pickupOtp;
  final String? collectorOrgId;
  final String? collectorName;
  final String? consignmentId;
  final String? recyclerOrgId;
  final String? recyclerName;
  final NGOVerification? verification;
  final String? qualityGrade; // A, B, C
  final double? contaminationPct;
  final String? rejectionReason;

  const WasteBatch({
    required this.id,
    required this.batchCode,
    required this.generatorOrgId,
    required this.generatorName,
    required this.material,
    required this.packagingCategory,
    required this.quantities,
    required this.status,
    required this.pickupAddress,
    required this.locality,
    required this.lat,
    required this.lng,
    required this.availableFrom,
    required this.availableTo,
    required this.photos,
    required this.qrCodeUrl,
    required this.createdAt,
    this.offers = const [],
    this.currentOfferId,
    this.pickupOtp,
    this.collectorOrgId,
    this.collectorName,
    this.consignmentId,
    this.recyclerOrgId,
    this.recyclerName,
    this.verification,
    this.qualityGrade,
    this.contaminationPct,
    this.rejectionReason,
  });

  WasteBatch copyWith({
    String? id,
    String? batchCode,
    String? generatorOrgId,
    String? generatorName,
    PolymerType? material,
    PackagingCategory? packagingCategory,
    BatchQuantities? quantities,
    BatchStatus? status,
    String? pickupAddress,
    String? locality,
    double? lat,
    double? lng,
    String? availableFrom,
    String? availableTo,
    List<String>? photos,
    String? qrCodeUrl,
    DateTime? createdAt,
    List<CollectionOffer>? offers,
    String? currentOfferId,
    String? pickupOtp,
    String? collectorOrgId,
    String? collectorName,
    String? consignmentId,
    String? recyclerOrgId,
    String? recyclerName,
    NGOVerification? verification,
    String? qualityGrade,
    double? contaminationPct,
    String? rejectionReason,
  }) {
    return WasteBatch(
      id: id ?? this.id,
      batchCode: batchCode ?? this.batchCode,
      generatorOrgId: generatorOrgId ?? this.generatorOrgId,
      generatorName: generatorName ?? this.generatorName,
      material: material ?? this.material,
      packagingCategory: packagingCategory ?? this.packagingCategory,
      quantities: quantities ?? this.quantities,
      status: status ?? this.status,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      locality: locality ?? this.locality,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      availableFrom: availableFrom ?? this.availableFrom,
      availableTo: availableTo ?? this.availableTo,
      photos: photos ?? this.photos,
      qrCodeUrl: qrCodeUrl ?? this.qrCodeUrl,
      createdAt: createdAt ?? this.createdAt,
      offers: offers ?? this.offers,
      currentOfferId: currentOfferId ?? this.currentOfferId,
      pickupOtp: pickupOtp ?? this.pickupOtp,
      collectorOrgId: collectorOrgId ?? this.collectorOrgId,
      collectorName: collectorName ?? this.collectorName,
      consignmentId: consignmentId ?? this.consignmentId,
      recyclerOrgId: recyclerOrgId ?? this.recyclerOrgId,
      recyclerName: recyclerName ?? this.recyclerName,
      verification: verification ?? this.verification,
      qualityGrade: qualityGrade ?? this.qualityGrade,
      contaminationPct: contaminationPct ?? this.contaminationPct,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
