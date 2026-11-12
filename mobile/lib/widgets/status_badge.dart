import 'package:flutter/material.dart';
import '../models/batch.dart';

class StatusBadge extends StatelessWidget {
  final dynamic status; // BatchStatus or String
  final bool isVerification;
  final bool isSeverity;

  const StatusBadge({
    super.key,
    required this.status,
    this.isVerification = false,
    this.isSeverity = false,
  });

  @override
  Widget build(BuildContext context) {
    Color bg = const Color(0xFFF1F5F9);
    Color border = const Color(0xFFCBD5E1);
    Color text = const Color(0xFF475569);
    IconData icon = Icons.circle;
    String label = '';

    if (status is BatchStatus) {
      final s = status as BatchStatus;
      label = s.label;
      switch (s) {
        case BatchStatus.listed:
          bg = const Color(0xFFF0F9FF);
          border = const Color(0xFFBAE6FD);
          text = const Color(0xFF0369A1);
          icon = Icons.list_alt;
          break;
        case BatchStatus.assigned:
          bg = const Color(0xFFEFF6FF);
          border = const Color(0xFFBFDBFE);
          text = const Color(0xFF1D4ED8);
          icon = Icons.handshake;
          break;
        case BatchStatus.pickedUp:
          bg = const Color(0xFFEEF2FF);
          border = const Color(0xFFC7D2FE);
          text = const Color(0xFF4338CA);
          icon = Icons.scale;
          break;
        case BatchStatus.inTransit:
          bg = const Color(0xFFFAF5FF);
          border = const Color(0xFFE9D5FF);
          text = const Color(0xFF7E22CE);
          icon = Icons.local_shipping;
          break;
        case BatchStatus.received:
          bg = const Color(0xFFF0FDFA);
          border = const Color(0xFF99F6E4);
          text = const Color(0xFF0F766E);
          icon = Icons.warehouse;
          break;
        case BatchStatus.processed:
          bg = const Color(0xFFECFDF5);
          border = const Color(0xFFA7F3D0);
          text = const Color(0xFF047857);
          icon = Icons.recycling;
          break;
        case BatchStatus.rejectedAtReceipt:
          bg = const Color(0xFFFFF1F2);
          border = const Color(0xFFFECDD3);
          text = const Color(0xFFBE123C);
          icon = Icons.cancel;
          break;
        case BatchStatus.cancelled:
          bg = const Color(0xFFF8FAFC);
          border = const Color(0xFFE2E8F0);
          text = const Color(0xFF64748B);
          icon = Icons.block;
          break;
      }
    } else {
      final s = status.toString().toUpperCase();
      label = s;
      if (isVerification) {
        switch (s) {
          case 'VERIFIED':
            bg = const Color(0xFFECFDF5);
            border = const Color(0xFFA7F3D0);
            text = const Color(0xFF047857);
            icon = Icons.verified;
            break;
          case 'UNDER_REVIEW':
            bg = const Color(0xFFEFF6FF);
            border = const Color(0xFFBFDBFE);
            text = const Color(0xFF1D4ED8);
            icon = Icons.rate_review;
            break;
          case 'PENDING':
            bg = const Color(0xFFFFFBEB);
            border = const Color(0xFFFDE68A);
            text = const Color(0xFFB45309);
            icon = Icons.hourglass_empty;
            break;
          case 'REQUIRES_CORRECTION':
            bg = const Color(0xFFFFF7ED);
            border = const Color(0xFFFED7AA);
            text = const Color(0xFFC2410C);
            icon = Icons.warning_amber;
            break;
          case 'FLAGGED':
          case 'REJECTED':
            bg = const Color(0xFFFFF1F2);
            border = const Color(0xFFFECDD3);
            text = const Color(0xFFBE123C);
            icon = Icons.report_problem;
            break;
        }
      } else if (isSeverity) {
        switch (s) {
          case 'CRITICAL':
          case 'HIGH':
            bg = const Color(0xFFFFF1F2);
            border = const Color(0xFFFECDD3);
            text = const Color(0xFFBE123C);
            icon = Icons.error;
            break;
          case 'MEDIUM':
            bg = const Color(0xFFFFFBEB);
            border = const Color(0xFFFDE68A);
            text = const Color(0xFFB45309);
            icon = Icons.warning;
            break;
          case 'LOW':
            bg = const Color(0xFFEFF6FF);
            border = const Color(0xFFBFDBFE);
            text = const Color(0xFF1D4ED8);
            icon = Icons.info;
            break;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: text),
          const SizedBox(width: 4),
          Text(
            label.replaceAll('_', ' '),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: text,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}
