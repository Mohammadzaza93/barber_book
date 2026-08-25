import 'employee.dart';

class BookingSettings {
  final String shopName;
  final String about;
  final String address;
  final String phone;
  final String email;
  final String currency;
  final String? logoUrl;
  final String primaryColorHex;
  final String accentColorHex;
  final String slug;
  final Map<int, List<WorkSlot>> workingHours;
  final List<String> policies;

  // Cancellation
  final int cancelFreeHours;
  final double cancelFeePercent;
  final String whoPaysFees; // customer | shop

  // Deposits
  final bool depositsEnabled;
  final double depositPercent;
  final bool depositHighDemandOnly;

  // Reminders
  final bool remindersEnabled;
  final List<int> reminderTimings; // hours before
  final List<String> reminderChannels; // email | sms | whatsapp

  // Booking options
  final bool allowOutOfHours;
  final int maxAdvanceDays;
  final bool autoConfirm;
  final bool showRatings;

  // SEO
  final String seoTitle;
  final String seoDescription;
  final String seoKeywords;

  // Social
  final Map<String, String> socialLinks;

  const BookingSettings({
    this.shopName = '',
    this.about = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.currency = 'SAR',
    this.logoUrl,
    this.primaryColorHex = '0xFF121316',
    this.accentColorHex = '0xFFC6CBD4',
    this.slug = '',
    this.workingHours = const {},
    this.policies = const [],
    this.cancelFreeHours = 6,
    this.cancelFeePercent = 20,
    this.whoPaysFees = 'customer',
    this.depositsEnabled = false,
    this.depositPercent = 20,
    this.depositHighDemandOnly = true,
    this.remindersEnabled = true,
    this.reminderTimings = const [2, 24],
    this.reminderChannels = const ['whatsapp', 'email'],
    this.allowOutOfHours = true,
    this.maxAdvanceDays = 60,
    this.autoConfirm = false,
    this.showRatings = true,
    this.seoTitle = '',
    this.seoDescription = '',
    this.seoKeywords = '',
    this.socialLinks = const {},
  });

  BookingSettings copyWith({
    String? shopName,
    String? about,
    String? address,
    String? phone,
    String? email,
    String? currency,
    String? logoUrl,
    String? primaryColorHex,
    String? accentColorHex,
    String? slug,
    Map<int, List<WorkSlot>>? workingHours,
    List<String>? policies,
    int? cancelFreeHours,
    double? cancelFeePercent,
    String? whoPaysFees,
    bool? depositsEnabled,
    double? depositPercent,
    bool? depositHighDemandOnly,
    bool? remindersEnabled,
    List<int>? reminderTimings,
    List<String>? reminderChannels,
    bool? allowOutOfHours,
    int? maxAdvanceDays,
    bool? autoConfirm,
    bool? showRatings,
    String? seoTitle,
    String? seoDescription,
    String? seoKeywords,
    Map<String, String>? socialLinks,
  }) {
    return BookingSettings(
      shopName: shopName ?? this.shopName,
      about: about ?? this.about,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      currency: currency ?? this.currency,
      logoUrl: logoUrl ?? this.logoUrl,
      primaryColorHex: primaryColorHex ?? this.primaryColorHex,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      slug: slug ?? this.slug,
      workingHours: workingHours ?? this.workingHours,
      policies: policies ?? this.policies,
      cancelFreeHours: cancelFreeHours ?? this.cancelFreeHours,
      cancelFeePercent: cancelFeePercent ?? this.cancelFeePercent,
      whoPaysFees: whoPaysFees ?? this.whoPaysFees,
      depositsEnabled: depositsEnabled ?? this.depositsEnabled,
      depositPercent: depositPercent ?? this.depositPercent,
      depositHighDemandOnly: depositHighDemandOnly ?? this.depositHighDemandOnly,
      remindersEnabled: remindersEnabled ?? this.remindersEnabled,
      reminderTimings: reminderTimings ?? this.reminderTimings,
      reminderChannels: reminderChannels ?? this.reminderChannels,
      allowOutOfHours: allowOutOfHours ?? this.allowOutOfHours,
      maxAdvanceDays: maxAdvanceDays ?? this.maxAdvanceDays,
      autoConfirm: autoConfirm ?? this.autoConfirm,
      showRatings: showRatings ?? this.showRatings,
      seoTitle: seoTitle ?? this.seoTitle,
      seoDescription: seoDescription ?? this.seoDescription,
      seoKeywords: seoKeywords ?? this.seoKeywords,
      socialLinks: socialLinks ?? this.socialLinks,
    );
  }

  Map<String, dynamic> toMap() => {
        'shopName': shopName,
        'about': about,
        'address': address,
        'phone': phone,
        'email': email,
        'currency': currency,
        'logoUrl': logoUrl,
        'primaryColorHex': primaryColorHex,
        'accentColorHex': accentColorHex,
        'slug': slug,
        'workingHours': workingHours.map((k, v) =>
            MapEntry(k.toString(), v.map((s) => s.toMap()).toList())),
        'policies': policies,
        'cancelFreeHours': cancelFreeHours,
        'cancelFeePercent': cancelFeePercent,
        'whoPaysFees': whoPaysFees,
        'depositsEnabled': depositsEnabled,
        'depositPercent': depositPercent,
        'depositHighDemandOnly': depositHighDemandOnly,
        'remindersEnabled': remindersEnabled,
        'reminderTimings': reminderTimings,
        'reminderChannels': reminderChannels,
        'allowOutOfHours': allowOutOfHours,
        'maxAdvanceDays': maxAdvanceDays,
        'autoConfirm': autoConfirm,
        'showRatings': showRatings,
        'seoTitle': seoTitle,
        'seoDescription': seoDescription,
        'seoKeywords': seoKeywords,
        'socialLinks': socialLinks,
      };

  factory BookingSettings.fromMap(Map<String, dynamic> m) {
    final whRaw = (m['workingHours'] as Map<String, dynamic>?) ?? {};
    final wh = <int, List<WorkSlot>>{};
    whRaw.forEach((k, v) {
      final day = int.tryParse(k);
      if (day != null) {
        wh[day] = (v as List<dynamic>? ?? const [])
            .map((e) => WorkSlot.fromMap((e as Map).cast<String, dynamic>()))
            .toList();
      }
    });
    return BookingSettings(
      shopName: (m['shopName'] as String?) ?? '',
      about: (m['about'] as String?) ?? '',
      address: (m['address'] as String?) ?? '',
      phone: (m['phone'] as String?) ?? '',
      email: (m['email'] as String?) ?? '',
      currency: (m['currency'] as String?) ?? 'SAR',
      logoUrl: m['logoUrl'] as String?,
      primaryColorHex: (m['primaryColorHex'] as String?) ?? '0xFF121316',
      accentColorHex: (m['accentColorHex'] as String?) ?? '0xFFC6CBD4',
      slug: (m['slug'] as String?) ?? '',
      workingHours: wh,
      policies: (m['policies'] as List<dynamic>? ?? const [])
          .map((e) => e.toString())
          .toList(),
      cancelFreeHours: (m['cancelFreeHours'] as num?)?.toInt() ?? 6,
      cancelFeePercent: ((m['cancelFeePercent'] as num?) ?? 20).toDouble(),
      whoPaysFees: (m['whoPaysFees'] as String?) ?? 'customer',
      depositsEnabled: (m['depositsEnabled'] as bool?) ?? false,
      depositPercent: ((m['depositPercent'] as num?) ?? 20).toDouble(),
      depositHighDemandOnly: (m['depositHighDemandOnly'] as bool?) ?? true,
      remindersEnabled: (m['remindersEnabled'] as bool?) ?? true,
      reminderTimings: (m['reminderTimings'] as List<dynamic>? ?? const [2, 24])
          .map((e) => (e as num).toInt())
          .toList(),
      reminderChannels:
          (m['reminderChannels'] as List<dynamic>? ?? const ['whatsapp'])
              .map((e) => e.toString())
              .toList(),
      allowOutOfHours: (m['allowOutOfHours'] as bool?) ?? true,
      maxAdvanceDays: (m['maxAdvanceDays'] as num?)?.toInt() ?? 60,
      autoConfirm: (m['autoConfirm'] as bool?) ?? false,
      showRatings: (m['showRatings'] as bool?) ?? true,
      seoTitle: (m['seoTitle'] as String?) ?? '',
      seoDescription: (m['seoDescription'] as String?) ?? '',
      seoKeywords: (m['seoKeywords'] as String?) ?? '',
      socialLinks:
          ((m['socialLinks'] as Map<String, dynamic>?) ?? const {}).cast(),
    );
  }
}
