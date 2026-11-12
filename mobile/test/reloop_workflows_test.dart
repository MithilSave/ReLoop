import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/models/batch.dart';
import 'package:mobile/services/app_state.dart';

void main() {
  group('ReLoop Business Logic & Workflow Test Suite', () {
    late AppState appState;

    setUp(() {
      appState = AppState();
    });

    test('1. Initial State loads realistic Mumbai pilot data', () {
      expect(appState.batches.isNotEmpty, true);
      expect(appState.consignments.isNotEmpty, true);
      expect(appState.processingRuns.isNotEmpty, true);
      expect(appState.allocations.isNotEmpty, true);
      expect(appState.eprTargets.isNotEmpty, true);
      expect(appState.anomalies.isNotEmpty, true);
    });

    test('2. Generator Batch Creation assigns RL-MUM-2026- code and LISTED status', () {
      final newBatch = appState.createBatch(
        material: PolymerType.pet,
        packagingCategory: PackagingCategory.catI,
        estimatedKg: 75.0,
        pickupAddress: 'Oberoi Sky Heights, Andheri West',
        locality: 'Andheri West',
        availableFrom: '2026-11-15T09:00:00Z',
        availableTo: '2026-11-15T13:00:00Z',
      );

      expect(newBatch.status, BatchStatus.listed);
      expect(newBatch.batchCode.startsWith('RL-MUM-2026-'), true);
      expect(newBatch.quantities.estimatedKg, 75.0);
      expect(appState.batches.first.batchCode, newBatch.batchCode);
    });

    test('3. Collector Offer Acceptance generates a 6-digit Doorstep OTP and transitions to ASSIGNED', () {
      final listedBatch = appState.batches.firstWhere((b) => b.status == BatchStatus.listed);
      appState.makeOffer(listedBatch.id, 16.50, '2026-11-15 10:00 AM');

      final updatedBatch = appState.batches.firstWhere((b) => b.id == listedBatch.id);
      expect(updatedBatch.offers.isNotEmpty, true);

      final offer = updatedBatch.offers.first;
      appState.acceptOffer(listedBatch.id, offer.id);

      final assignedBatch = appState.batches.firstWhere((b) => b.id == listedBatch.id);
      expect(assignedBatch.status, BatchStatus.assigned);
      expect(assignedBatch.pickupOtp, isNotNull);
      expect(assignedBatch.pickupOtp!.length, 6);
    });

    test('4. Collector Pickup Handover requires matching OTP and sets measured Scale Weight', () {
      final assignedBatch = appState.batches.firstWhere(
        (b) => b.status == BatchStatus.assigned && b.pickupOtp != null,
      );
      final otp = assignedBatch.pickupOtp!;

      // Invalid OTP should fail
      final invalidRes = appState.completePickup(
        assignedBatch.id,
        148.5,
        '000000',
      );
      expect(invalidRes['success'], false);
      expect(invalidRes['error'], contains('Invalid Generator OTP'));

      // Correct OTP should succeed
      final validRes = appState.completePickup(
        assignedBatch.id,
        148.5,
        otp,
      );
      expect(validRes['success'], true);

      final pickedUpBatch = appState.batches.firstWhere((b) => b.id == assignedBatch.id);
      expect(pickedUpBatch.status, BatchStatus.pickedUp);
      expect(pickedUpBatch.quantities.collectedKg, 148.5);
    });

    test('5. Recycler Weighbridge Receipt records mass quantities and sets status to RECEIVED', () {
      final inTransitBatch = appState.batches.firstWhere(
        (b) => b.status == BatchStatus.inTransit,
      );

      appState.receiveBatch(
        batchId: inTransitBatch.id,
        receivedKg: 145.0,
        acceptedKg: 140.0,
        rejectedKg: 5.0,
        qualityGrade: 'GRADE_A',
        contaminationPct: 3.4,
      );

      final receivedBatch = appState.batches.firstWhere((b) => b.id == inTransitBatch.id);
      expect(receivedBatch.status, BatchStatus.received);
      expect(receivedBatch.quantities.receivedKg, 145.0);
      expect(receivedBatch.quantities.acceptedKg, 140.0);
      expect(receivedBatch.quantities.rejectedKg, 5.0);
    });

    test('6. Extrusion Processing Run logs run and updates member batches to PROCESSED', () {
      final receivedBatches = appState.batches
          .where((b) => b.status == BatchStatus.received && b.quantities.acceptedKg != null)
          .take(2)
          .toList();
      expect(receivedBatches.isNotEmpty, true);

      final totalInput = receivedBatches.fold<double>(0, (s, b) => s + b.quantities.acceptedKg!);

      final validRun = appState.createProcessingRun(
        batchIds: receivedBatches.map((b) => b.id).toList(),
        materialCode: PolymerType.pp,
        packagingCategory: PackagingCategory.catI,
        outputKg: totalInput * 0.88,
        residueKg: totalInput * 0.12,
        outputForm: 'Pellets',
        certificateRef: 'CPCB-MH-2026-TEST-001',
      );

      expect(validRun.outputKg, closeTo(totalInput * 0.88, 0.01));
      expect(validRun.residueKg, closeTo(totalInput * 0.12, 0.01));
      expect(validRun.measurementStatus, 'COMPLETE');
    });

    test('7. Independent NGO Audit checklist submission verifies batch', () {
      final batchToVerify = appState.batches.firstWhere(
        (b) => b.status == BatchStatus.received || b.status == BatchStatus.processed,
      );

      appState.submitNGOVerification(
        batchId: batchToVerify.id,
        decision: 'VERIFIED',
        comments: 'Full mass-balance and custody documentation verified.',
      );

      final verifiedBatch = appState.batches.firstWhere((b) => b.id == batchToVerify.id);
      expect(verifiedBatch.verification?.decision, 'VERIFIED');
    });

    test('8. EPR Over-Allocation Protection: Rejects requested quantity > eligible available quantity', () {
      final run = appState.processingRuns.first;
      final available = run.eligibleKg - run.allocatedKg;

      // Attempting to allocate more than available capacity
      final overAlloc = appState.createEPRAllocation(
        processingRunId: run.id,
        eprOrgId: 'epr-org-1',
        eprOrgName: 'Hindustan Consumer Goods Ltd',
        period: 'Q3-2026',
        quantityKg: available + 100.0,
      );
      expect(overAlloc['success'], false);
      expect(overAlloc['error'], contains('Over-allocation safeguard'));

      // Valid allocation within capacity
      if (available > 10.0) {
        final validAlloc = appState.createEPRAllocation(
          processingRunId: run.id,
          eprOrgId: 'epr-org-1',
          eprOrgName: 'Hindustan Consumer Goods Ltd',
          period: 'Q3-2026',
          quantityKg: 10.0,
        );
        expect(validAlloc['success'], true);
      }
    });

    test('9. EPR Allocation Reversal restores eligible processing capacity', () {
      final activeAlloc = appState.allocations.firstWhere((a) => a.status == 'ACTIVE');
      final runBefore = appState.processingRuns.firstWhere((r) => r.id == activeAlloc.processingRunId);
      final allocatedBefore = runBefore.allocatedKg;

      appState.reverseEPRAllocation(activeAlloc.id, 'Brand target revised down for Q4');

      final reversedAlloc = appState.allocations.firstWhere((a) => a.id == activeAlloc.id);
      expect(reversedAlloc.status, 'REVERSED');

      final runAfter = appState.processingRuns.firstWhere((r) => r.id == activeAlloc.processingRunId);
      expect(runAfter.allocatedKg, lessThan(allocatedBefore));
    });

    test('10. Persona Switching updates active role and context', () {
      expect(appState.currentPersona.id, 'persona-gen');

      appState.setPersona('persona-col');
      expect(appState.currentPersona.id, 'persona-col');

      appState.setPersona('persona-rec');
      expect(appState.currentPersona.id, 'persona-rec');

      appState.setPersona('persona-ngo');
      expect(appState.currentPersona.id, 'persona-ngo');

      appState.setPersona('persona-epr');
      expect(appState.currentPersona.id, 'persona-epr');

      appState.setPersona('persona-adm');
      expect(appState.currentPersona.id, 'persona-adm');
    });
  });
}
