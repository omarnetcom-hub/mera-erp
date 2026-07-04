class PaymentAllocation {
  const PaymentAllocation({
    required this.cash,
    required this.bank,
    required this.credit,
  });

  final double cash;
  final double bank;
  final double credit;

  double get total => cash + bank + credit;
}

class PaymentPolicy {
  const PaymentPolicy._();

  static bool isBankMethod(String method) {
    final normalized = method.toUpperCase().trim();
    return normalized == 'TRANSFERENCIA' ||
        normalized == 'TARJETA' ||
        normalized == 'NEQUI' ||
        normalized == 'DAVIPLATA';
  }

  static bool isCreditMethod(String method) {
    return method.toUpperCase().trim() == 'CREDITO';
  }

  static String cashOriginForSale(String method) {
    final normalized = method.toUpperCase().trim();
    if (isBankMethod(normalized)) return 'banco';
    if (isCreditMethod(normalized)) return 'cartera';
    return 'caja';
  }

  static PaymentAllocation allocatePurchase({
    required double total,
    required String method,
    double manualCash = 0,
    double manualBank = 0,
    double manualCredit = 0,
  }) {
    final normalized = method.toUpperCase().trim();
    if (total < 0) {
      throw Exception('El total no puede ser negativo.');
    }

    if (normalized == 'PAGO MIXTO') {
      final distributed = manualCash + manualBank + manualCredit;
      if (distributed - total > 0.01) {
        throw Exception('La distribucion del pago supera el total.');
      }
      return PaymentAllocation(
        cash: manualCash,
        bank: manualBank,
        credit: manualCredit + (distributed < total ? total - distributed : 0),
      );
    }

    if (normalized == 'EFECTIVO') {
      return PaymentAllocation(cash: total, bank: 0, credit: 0);
    }

    if (isCreditMethod(normalized)) {
      return PaymentAllocation(cash: 0, bank: 0, credit: total);
    }

    return PaymentAllocation(cash: 0, bank: total, credit: 0);
  }
}
