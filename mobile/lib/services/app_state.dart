import 'package:flutter/foundation.dart';
import '../models/persona.dart';
import '../models/batch.dart';
import '../models/consignment.dart';
import '../models/processing_run.dart';
import '../models/allocation.dart';
import '../models/plan.dart';
import '../models/anomaly.dart';
import 'demo_data.dart';
import 'api_service.dart';

class AppState extends ChangeNotifier {
  DemoPersona _currentPersona = demoPersonas[0];
  List<WasteBatch> _batches = [];
  List<Consignment> _consignments = [];
  List<ProcessingRun> _processingRuns = [];
  List<EPRAllocation> _allocations = [];
  List<EPRTarget> _eprTargets = [];
  List<AggregationPlan> _aggregationPlans = [];
  List<AnomalyFlag> _anomalies = [];
  bool _isBackendConnected = false;
  bool _isSyncing = false;
  String _backendStatusMessage = 'Offline (using local pilot dataset)';

  AppState() {
    _loadInitialData();
    checkBackendConnection();
  }

  void _loadInitialData() {
    _batches = List.from(initialBatches);
    _consignments = List.from(initialConsignments);
    _processingRuns = List.from(initialProcessingRuns);
    _allocations = List.from(initialAllocations);
    _eprTargets = List.from(initialEPRTargets);
    _aggregationPlans = List.from(initialAggregationPlans);
    _anomalies = List.from(initialAnomalies);
  }

  DemoPersona get currentPersona => _currentPersona;
  List<WasteBatch> get batches => _batches;
  List<Consignment> get consignments => _consignments;
  List<ProcessingRun> get processingRuns => _processingRuns;
  List<EPRAllocation> get allocations => _allocations;
  List<EPRTarget> get eprTargets => _eprTargets;
  List<AggregationPlan> get aggregationPlans => _aggregationPlans;
  List<AnomalyFlag> get anomalies => _anomalies;
  bool get isBackendConnected => _isBackendConnected;
  bool get isSyncing => _isSyncing;
  String get backendStatusMessage => _backendStatusMessage;

  Future<bool> checkBackendConnection() async {
    final ok = await ApiService().checkHealth();
    _isBackendConnected = ok;
    if (ok) {
      _backendStatusMessage = 'Connected to FastAPI backend (localhost:8000)';
      await _authenticateCurrentPersona();
    } else {
      _backendStatusMessage = 'Offline (FastAPI server unreachable)';
    }
    notifyListeners();
    return ok;
  }

  Future<void> _authenticateCurrentPersona() async {
    final emailMap = {
      'persona-gen': 'generator@reloop.in',
      'persona-col': 'collector@reloop.in',
      'persona-rec': 'recycler@reloop.in',
      'persona-ngo': 'ngo@reloop.in',
      'persona-epr': 'epr@reloop.in',
      'persona-adm': 'admin@reloop.in',
      'generator-1': 'generator@reloop.in',
      'collector-1': 'collector@reloop.in',
      'recycler-1': 'recycler@reloop.in',
      'ngo-1': 'ngo@reloop.in',
      'epr-1': 'epr@reloop.in',
      'admin-1': 'admin@reloop.in',
    };
    final email = emailMap[_currentPersona.id];
    if (email != null) {
      await ApiService().login(email, 'reloop123');
    }
  }

  Future<void> syncWithBackend() async {
    _isSyncing = true;
    notifyListeners();
    try {
      final healthy = await ApiService().checkHealth();
      _isBackendConnected = healthy;
      if (!healthy) {
        _backendStatusMessage = 'Sync failed: Backend is offline';
        _isSyncing = false;
        notifyListeners();
        return;
      }

      await _authenticateCurrentPersona();
      final remoteBatches = await ApiService().fetchBatches();
      if (remoteBatches != null && remoteBatches.isNotEmpty) {
        _backendStatusMessage = 'Synced ${remoteBatches.length} batches from live backend';
      } else {
        _backendStatusMessage = 'Backend connected • 0 new records';
      }
    } catch (e) {
      _backendStatusMessage = 'Sync error: $e';
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  void setPersona(String personaId) {
    final found = demoPersonas.firstWhere(
      (p) => p.id == personaId,
      orElse: () => _currentPersona,
    );
    _currentPersona = found;
    if (_isBackendConnected) {
      _authenticateCurrentPersona();
    }
    notifyListeners();
  }

  WasteBatch createBatch({
    required PolymerType material,
    required PackagingCategory packagingCategory,
    required double estimatedKg,
    required String pickupAddress,
    required String locality,
    required String availableFrom,
    required String availableTo,
    List<String>? photos,
  }) {
    final nextNumber = 100 + _batches.length + 1;
    final batchCode = 'RL-MUM-2026-000$nextNumber';
    final id = 'batch-${DateTime.now().millisecondsSinceEpoch}';

    final newBatch = WasteBatch(
      id: id,
      batchCode: batchCode,
      generatorOrgId: _currentPersona.orgId,
      generatorName: _currentPersona.orgName,
      material: material,
      packagingCategory: packagingCategory,
      quantities: BatchQuantities(estimatedKg: estimatedKg),
      status: BatchStatus.listed,
      pickupAddress: pickupAddress,
      locality: locality,
      lat: 19.1334,
      lng: 72.8286,
      availableFrom: availableFrom,
      availableTo: availableTo,
      photos: photos ??
          [
            'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?auto=format&fit=crop&w=600&q=80',
          ],
      qrCodeUrl:
          'https://api.qrserver.com/v1/create-qr-code/?size=250x250&data=$batchCode',
      createdAt: DateTime.now(),
    );

    _batches.insert(0, newBatch);
    notifyListeners();
    return newBatch;
  }

  void makeOffer(String batchId, double ratePerKg, String proposedPickupAt) {
    final idx = _batches.indexWhere((b) => b.id == batchId);
    if (idx == -1) return;

    final batch = _batches[idx];
    final offer = CollectionOffer(
      id: 'off-${DateTime.now().millisecondsSinceEpoch}',
      batchId: batchId,
      collectorOrgId: _currentPersona.orgId,
      collectorName: _currentPersona.orgName,
      ratePerKg: ratePerKg,
      proposedPickupAt: proposedPickupAt,
      matchScore: 0.92,
      status: 'PENDING',
      reasons: [
        'Active LCV operating in ${batch.locality}',
        'Capacity matched for ${batch.quantities.estimatedKg.toStringAsFixed(0)} kg ${batch.material.label}',
      ],
      createdAt: DateTime.now(),
    );

    final updatedOffers = List<CollectionOffer>.from(batch.offers)..add(offer);
    _batches[idx] = batch.copyWith(offers: updatedOffers);
    notifyListeners();
  }

  void acceptOffer(String batchId, String offerId) {
    final idx = _batches.indexWhere((b) => b.id == batchId);
    if (idx == -1) return;

    final batch = _batches[idx];
    final offer = batch.offers.firstWhere((o) => o.id == offerId);
    final otp = (100000 + (DateTime.now().microsecond % 900000)).toString();

    final updatedOffers = batch.offers.map((o) {
      if (o.id == offerId) {
        return CollectionOffer(
          id: o.id,
          batchId: o.batchId,
          collectorOrgId: o.collectorOrgId,
          collectorName: o.collectorName,
          ratePerKg: o.ratePerKg,
          proposedPickupAt: o.proposedPickupAt,
          matchScore: o.matchScore,
          status: 'ACCEPTED',
          reasons: o.reasons,
          createdAt: o.createdAt,
        );
      }
      return CollectionOffer(
        id: o.id,
        batchId: o.batchId,
        collectorOrgId: o.collectorOrgId,
        collectorName: o.collectorName,
        ratePerKg: o.ratePerKg,
        proposedPickupAt: o.proposedPickupAt,
        matchScore: o.matchScore,
        status: 'DECLINED',
        reasons: o.reasons,
        createdAt: o.createdAt,
      );
    }).toList();

    _batches[idx] = batch.copyWith(
      status: BatchStatus.assigned,
      currentOfferId: offerId,
      collectorOrgId: offer.collectorOrgId,
      collectorName: offer.collectorName,
      pickupOtp: otp,
      offers: updatedOffers,
    );
    notifyListeners();
  }

  Map<String, dynamic> completePickup(
      String batchId, double collectedKg, String otp) {
    final idx = _batches.indexWhere((b) => b.id == batchId);
    if (idx == -1) {
      return {'success': false, 'error': 'Batch not found'};
    }

    final batch = _batches[idx];
    if (batch.pickupOtp != null &&
        batch.pickupOtp!.trim() != otp.trim()) {
      return {
        'success': false,
        'error': 'Invalid Generator OTP. Verification failed.'
      };
    }

    _batches[idx] = batch.copyWith(
      status: BatchStatus.pickedUp,
      quantities: batch.quantities.copyWith(collectedKg: collectedKg),
    );
    notifyListeners();
    return {'success': true};
  }

  Consignment createConsignment({
    required List<String> batchIds,
    required String destinationRecyclerId,
    required String destinationRecyclerName,
    required String vehicleNo,
  }) {
    final nextNumber = 40 + _consignments.length + 1;
    final code = 'CON-MUM-2026-00$nextNumber';
    final consignment = Consignment(
      id: 'con-${DateTime.now().millisecondsSinceEpoch}',
      consignmentCode: code,
      collectorOrgId: _currentPersona.orgId,
      collectorName: _currentPersona.orgName,
      destinationRecyclerId: destinationRecyclerId,
      destinationRecyclerName: destinationRecyclerName,
      vehicleNo: vehicleNo,
      batchIds: batchIds,
      status: 'IN_TRANSIT',
      createdAt: DateTime.now(),
    );

    _consignments.insert(0, consignment);

    for (int i = 0; i < _batches.length; i++) {
      if (batchIds.contains(_batches[i].id)) {
        _batches[i] = _batches[i].copyWith(
          status: BatchStatus.inTransit,
          consignmentId: consignment.id,
          recyclerOrgId: destinationRecyclerId,
          recyclerName: destinationRecyclerName,
        );
      }
    }

    notifyListeners();
    return consignment;
  }

  void receiveBatch({
    required String batchId,
    required double receivedKg,
    required double acceptedKg,
    required double rejectedKg,
    required String qualityGrade,
    required double contaminationPct,
    String? rejectionReason,
  }) {
    final idx = _batches.indexWhere((b) => b.id == batchId);
    if (idx == -1) return;

    final batch = _batches[idx];
    final newStatus =
        acceptedKg > 0 ? BatchStatus.received : BatchStatus.rejectedAtReceipt;

    _batches[idx] = batch.copyWith(
      status: newStatus,
      quantities: batch.quantities.copyWith(
        receivedKg: receivedKg,
        acceptedKg: acceptedKg,
        rejectedKg: rejectedKg,
      ),
      qualityGrade: qualityGrade,
      contaminationPct: contaminationPct,
      rejectionReason: rejectionReason,
      verification: NGOVerification(
        id: 'ver-${DateTime.now().millisecondsSinceEpoch}',
        batchId: batch.id,
        batchCode: batch.batchCode,
        reviewerId: 'persona-ngo',
        reviewerName: 'Swachh Mumbai Foundation',
        decision: 'PENDING',
        comments:
            'Awaiting mechanical processing run and mass balance measurement.',
        evidenceReviewed: [
          'Weighbridge Calibration Slip #WB-${batch.batchCode.split('-').last}',
          'Optical Inspection Photo'
        ],
        variancePct: 0.0,
        updatedAt: DateTime.now(),
      ),
    );
    notifyListeners();
  }

  ProcessingRun createProcessingRun({
    required PolymerType materialCode,
    required PackagingCategory packagingCategory,
    required List<String> batchIds,
    required double outputKg,
    required double residueKg,
    required String outputForm,
    required String certificateRef,
  }) {
    final nextNumber = 40 + _processingRuns.length + 1;
    final code = 'PR-2026-00$nextNumber';

    double totalInputKg = 0;
    final runInputs = <ProcessingRunInput>[];

    for (final bid in batchIds) {
      final b = _batches.firstWhere((item) => item.id == bid);
      final inKg = b.quantities.acceptedKg ?? b.quantities.receivedKg ?? 50.0;
      totalInputKg += inKg;
      runInputs.add(ProcessingRunInput(
        batchId: b.id,
        batchCode: b.batchCode,
        receiptId: 'rcpt-${b.id}',
        inputKg: inKg,
      ));
    }

    final yieldPct =
        totalInputKg > 0 ? (outputKg / totalInputKg) * 100 : 0.0;

    final run = ProcessingRun(
      id: 'pr-${DateTime.now().millisecondsSinceEpoch}',
      runCode: code,
      recyclerOrgId: _currentPersona.orgId,
      recyclerName: _currentPersona.orgName,
      materialCode: materialCode,
      packagingCategory: packagingCategory,
      runStartedAt: DateTime.now().subtract(const Duration(hours: 4)),
      runEndedAt: DateTime.now(),
      inputs: runInputs,
      inputKg: totalInputKg,
      outputKg: outputKg,
      residueKg: residueKg,
      outputForm: outputForm,
      eligibleKg: outputKg,
      allocatedKg: 0.0,
      measurementStatus: 'COMPLETE',
      yieldPct: yieldPct,
      certificateRefs: [certificateRef],
      createdAt: DateTime.now(),
    );

    _processingRuns.insert(0, run);

    // Update member batches to PROCESSED
    for (int i = 0; i < _batches.length; i++) {
      if (batchIds.contains(_batches[i].id)) {
        final b = _batches[i];
        final batchAccepted = b.quantities.acceptedKg ?? 50.0;
        final proRataOutput = totalInputKg > 0
            ? (batchAccepted / totalInputKg) * outputKg
            : batchAccepted;

        _batches[i] = b.copyWith(
          status: BatchStatus.processed,
          quantities: b.quantities.copyWith(
            processedKg: proRataOutput,
          ),
          verification: b.verification?.copyWith(
            processingRunId: run.id,
            comments:
                'Processing completed in run $code. Output verified: ${outputKg.toStringAsFixed(1)} kg ($outputForm).',
          ),
        );
      }
    }

    notifyListeners();
    return run;
  }

  void submitNGOVerification({
    required String batchId,
    required String decision,
    required String comments,
    List<String>? evidenceDocs,
  }) {
    final idx = _batches.indexWhere((b) => b.id == batchId);
    if (idx == -1) return;

    final b = _batches[idx];
    final currentVer = b.verification;
    final processedKg = b.quantities.processedKg ?? 0.0;
    final verifiedKg = decision == 'VERIFIED' ? processedKg : 0.0;

    final newVerification = NGOVerification(
      id: currentVer?.id ?? 'ver-${DateTime.now().millisecondsSinceEpoch}',
      batchId: b.id,
      batchCode: b.batchCode,
      processingRunId: currentVer?.processingRunId,
      reviewerId: _currentPersona.id,
      reviewerName: _currentPersona.name,
      decision: decision,
      comments: comments,
      evidenceReviewed: evidenceDocs ??
          currentVer?.evidenceReviewed ??
          ['Audited custody trail and weighbridge data'],
      variancePct: currentVer?.variancePct ?? 0.5,
      updatedAt: DateTime.now(),
      version: (currentVer?.version ?? 0) + 1,
    );

    _batches[idx] = b.copyWith(
      verification: newVerification,
      quantities: b.quantities.copyWith(verifiedKg: verifiedKg),
    );
    notifyListeners();
  }

  Map<String, dynamic> createEPRAllocation({
    required String processingRunId,
    required String eprOrgId,
    required String eprOrgName,
    required double quantityKg,
    required String period,
  }) {
    final runIdx = _processingRuns.indexWhere((r) => r.id == processingRunId);
    if (runIdx == -1) {
      return {'success': false, 'error': 'Processing run not found'};
    }

    final run = _processingRuns[runIdx];
    final available = run.eligibleKg - run.allocatedKg;

    if (quantityKg > available) {
      return {
        'success': false,
        'error':
            'Over-allocation safeguard: Requested ${quantityKg.toStringAsFixed(1)} kg exceeds available ${available.toStringAsFixed(1)} kg.',
      };
    }

    final nextNumber = 90 + _allocations.length + 1;
    final allocCode = 'EPR-ALOC-2026-00$nextNumber';
    final batchCodes = run.inputs.map((inItem) => inItem.batchCode).toList();

    final allocation = EPRAllocation(
      id: 'alloc-${DateTime.now().millisecondsSinceEpoch}',
      allocationCode: allocCode,
      processingRunId: run.id,
      runCode: run.runCode,
      eprOrgId: eprOrgId,
      eprOrgName: eprOrgName,
      recyclerOrgId: run.recyclerOrgId,
      recyclerName: run.recyclerName,
      batchCodes: batchCodes,
      packagingCategory: run.packagingCategory,
      reportingPeriod: period,
      quantityKg: quantityKg,
      status: 'ACTIVE',
      certificateId: run.certificateRefs.isNotEmpty
          ? run.certificateRefs.first
          : 'CPCB/DEMO/CERT',
      isNgoVerified: true,
      createdAt: DateTime.now(),
    );

    _allocations.insert(0, allocation);

    // Update allocated kg on run
    _processingRuns[runIdx] = run.copyWith(
      allocatedKg: run.allocatedKg + quantityKg,
    );

    // Update target allocated kg
    final targetIdx = _eprTargets
        .indexWhere((t) => t.category == run.packagingCategory);
    if (targetIdx != -1) {
      final tgt = _eprTargets[targetIdx];
      _eprTargets[targetIdx] = tgt.copyWith(
        allocatedKg: tgt.allocatedKg + quantityKg,
        verifiedKg: tgt.verifiedKg + quantityKg,
      );
    }

    notifyListeners();
    return {'success': true};
  }

  void reverseEPRAllocation(String allocationId, String reason) {
    final allocIdx =
        _allocations.indexWhere((a) => a.id == allocationId && a.status == 'ACTIVE');
    if (allocIdx == -1) return;

    final alloc = _allocations[allocIdx];
    _allocations[allocIdx] = alloc.copyWith(
      status: 'REVERSED',
      reversalReason: reason,
    );

    // Restore capacity on processing run
    final runIdx =
        _processingRuns.indexWhere((r) => r.id == alloc.processingRunId);
    if (runIdx != -1) {
      final run = _processingRuns[runIdx];
      _processingRuns[runIdx] = run.copyWith(
        allocatedKg: (run.allocatedKg - alloc.quantityKg).clamp(0.0, run.eligibleKg),
      );
    }

    // Restore target allocated kg
    final targetIdx =
        _eprTargets.indexWhere((t) => t.category == alloc.packagingCategory);
    if (targetIdx != -1) {
      final tgt = _eprTargets[targetIdx];
      _eprTargets[targetIdx] = tgt.copyWith(
        allocatedKg: (tgt.allocatedKg - alloc.quantityKg).clamp(0.0, tgt.targetKg),
        verifiedKg: (tgt.verifiedKg - alloc.quantityKg).clamp(0.0, tgt.targetKg),
      );
    }

    notifyListeners();
  }

  void acceptAggregationPlan(String planId) {
    final idx = _aggregationPlans.indexWhere((p) => p.id == planId);
    if (idx == -1) return;

    _aggregationPlans[idx] = _aggregationPlans[idx].copyWith(status: 'ACCEPTED');
    notifyListeners();
  }

  void resolveAnomaly(String anomalyId) {
    final idx = _anomalies.indexWhere((a) => a.id == anomalyId);
    if (idx == -1) return;

    _anomalies[idx] = _anomalies[idx].copyWith(status: 'RESOLVED');
    notifyListeners();
  }

  void resetDemoData() {
    _loadInitialData();
    notifyListeners();
  }
}
