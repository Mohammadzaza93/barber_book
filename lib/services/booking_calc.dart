import '../models/booking_settings.dart';
import '../models/discount.dart';
import '../models/service.dart';

/// Computes the required deposit for a booking.
double computeDeposit(
    BookingSettings settings, List<Service> services, double total) {
  if (!settings.depositsEnabled) return 0;
  if (settings.depositHighDemandOnly) {
    final hd = services.where((s) => s.highDemand).toList();
    if (hd.isEmpty) return 0;
    final fixed = hd.where((s) => s.depositAmount > 0).toList();
    if (fixed.isNotEmpty) {
      return fixed.fold(0.0, (sum, s) => sum + s.depositAmount);
    }
    return total * settings.depositPercent / 100;
  }
  return total * settings.depositPercent / 100;
}

/// Computes the discount amount for an order total.
double computeDiscount(Discount d, double total) {
  var amount = d.type == 'percent' ? total * d.value / 100 : d.value;
  if (d.maxDiscount > 0 && amount > d.maxDiscount) {
    amount = d.maxDiscount;
  }
  if (amount < 0) amount = 0;
  if (amount > total) amount = total;
  return amount;
}
