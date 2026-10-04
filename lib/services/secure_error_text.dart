import 'package:flutter/widgets.dart';

import '../l10n/strings.dart';
import 'secure_api.dart';

/// Maps a server rejection to a localized message.
///
/// The callable layer answers with a stable code, so the mapping lives in one
/// place instead of being re-derived at every call site.
String describeSecureError(BuildContext context, SecureApiException error) {
  final s = t(context);
  switch (error.code) {
    case 'appointment-conflict':
      return s.secureErrorConflict;
    case 'permission-denied':
    case 'not-a-member':
      return s.secureErrorDenied;
    case 'unauthenticated':
      return s.secureErrorUnauthenticated;
    case 'coupon-expired':
      return s.secureErrorCouponExpired;
    case 'coupon-exhausted':
      return s.secureErrorCouponExhausted;
    case 'coupon-not-applicable':
      return s.secureErrorCouponNotApplicable;
    case 'invalid-coupon':
      return s.secureErrorInvalidCoupon;
    case 'outside-working-hours':
      return s.secureErrorOutsideHours;
    case 'out-of-hours-not-allowed':
      return s.secureErrorOutOfHoursNotAllowed;
    case 'appointment-in-past':
      return s.secureErrorInPast;
    case 'out-of-range':
      return s.secureErrorOutOfRange;
    case 'invalid-transition':
      return s.secureErrorTransition;
    case 'invalid-payment-method':
      return s.secureErrorInvalidPaymentMethod;
    case 'invalid-rating':
      return s.secureErrorInvalidRating;
    case 'already-member':
      return s.secureErrorAlreadyMember;
    case 'invalid-join-code':
      return s.secureErrorJoinCode;
    case 'appointment-not-found':
    case 'payment-not-found':
    case 'service-not-found':
    case 'employee-not-found':
    case 'chair-not-found':
    case 'shop-not-found':
      return s.secureErrorNotFound;
    case 'service-inactive':
    case 'employee-inactive':
    case 'chair-inactive':
      return s.secureErrorInactive;
    case 'service-mismatch':
      return s.secureErrorServiceMismatch;
    case 'invalid-input':
      return s.secureErrorInvalidInput;
    case 'unavailable':
    case 'deadline-exceeded':
    case 'network-unavailable':
      return s.secureErrorNetwork;
    default:
      return s.secureErrorGeneric;
  }
}
