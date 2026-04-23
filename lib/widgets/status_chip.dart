import 'package:flutter/material.dart';
import '../app_theme.dart';

class StatusChip extends StatelessWidget {
  final bool isGood;
  final String? customLabel;

  const StatusChip({super.key, required this.isGood, this.customLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isGood ? kGreenLight : kRedLight,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isGood ? Icons.check_circle : Icons.warning_rounded,
            size: 14,
            color: isGood ? kGreen : kRed,
          ),
          const SizedBox(width: 4),
          Text(
            customLabel ?? (isGood ? 'OK' : 'Shortfall'),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isGood ? kGreen : kRed,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentBadge extends StatelessWidget {
  final String method;

  const PaymentBadge({super.key, required this.method});

  @override
  Widget build(BuildContext context) {
    final isMpesa = method.toLowerCase() == 'mpesa';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isMpesa ? const Color(0xFFE8F5E9) : const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isMpesa ? 'M-Pesa' : 'Cash',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isMpesa ? const Color(0xFF1B5E20) : const Color(0xFFF57F17),
        ),
      ),
    );
  }
}

class TypeBadge extends StatelessWidget {
  final String productType;

  const TypeBadge({super.key, required this.productType});

  @override
  Widget build(BuildContext context) {
    final isWeight = productType == 'weight';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isWeight ? const Color(0xFFE3F2FD) : const Color(0xFFF3E5F5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        isWeight ? 'KG' : 'UNITS',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isWeight ? const Color(0xFF0D47A1) : const Color(0xFF4A148C),
        ),
      ),
    );
  }
}
