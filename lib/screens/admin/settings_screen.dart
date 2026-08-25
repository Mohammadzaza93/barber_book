import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/strings.dart';
import '../../models/booking_settings.dart';
import '../../providers/shop_provider.dart';
import '../../services/shop_manager.dart';
import '../../theme/app_theme.dart';
import '../../widgets/color_picker.dart';
import '../../widgets/confirm.dart';
import '../../widgets/labeled_field.dart';
import '../../widgets/work_hours_editor.dart';
import '../customer/booking_flow_screen.dart';

class SettingsScreen extends StatefulWidget {
  final bool openShare;
  const SettingsScreen({super.key, this.openShare = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late BookingSettings _draft;
  late final TextEditingController _shopName;
  late final TextEditingController _about;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _currency;
  late final TextEditingController _seoTitle;
  late final TextEditingController _seoDescription;
  late final TextEditingController _seoKeywords;
  late final TextEditingController _instagram;
  late final TextEditingController _facebook;
  late final TextEditingController _google;

  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final s = context.read<ShopProvider>().settings;
    _draft = s ?? const BookingSettings();
    _shopName = TextEditingController(text: _draft.shopName);
    _about = TextEditingController(text: _draft.about);
    _address = TextEditingController(text: _draft.address);
    _phone = TextEditingController(text: _draft.phone);
    _email = TextEditingController(text: _draft.email);
    _currency = TextEditingController(text: _draft.currency);
    _seoTitle = TextEditingController(text: _draft.seoTitle);
    _seoDescription = TextEditingController(text: _draft.seoDescription);
    _seoKeywords = TextEditingController(text: _draft.seoKeywords);
    _instagram =
        TextEditingController(text: _draft.socialLinks['instagram'] ?? '');
    _facebook =
        TextEditingController(text: _draft.socialLinks['facebook'] ?? '');
    _google =
        TextEditingController(text: _draft.socialLinks['google'] ?? '');

    if (widget.openShare) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _shareLink());
    }
  }

  @override
  void dispose() {
    _shopName.dispose();
    _about.dispose();
    _address.dispose();
    _phone.dispose();
    _email.dispose();
    _currency.dispose();
    _seoTitle.dispose();
    _seoDescription.dispose();
    _seoKeywords.dispose();
    _instagram.dispose();
    _facebook.dispose();
    _google.dispose();
    super.dispose();
  }

  String get _link =>
      'https://barberbook.app/${_draft.slug.isEmpty ? 'book' : _draft.slug}';

  void _set(BuildingSettingsBuilder fn) {
    setState(() => _draft = fn(_draft));
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final updated = _draft.copyWith(
      shopName: _shopName.text.trim(),
      about: _about.text.trim(),
      address: _address.text.trim(),
      phone: _phone.text.trim(),
      email: _email.text.trim(),
      currency: _currency.text.trim(),
      seoTitle: _seoTitle.text.trim(),
      seoDescription: _seoDescription.text.trim(),
      seoKeywords: _seoKeywords.text.trim(),
      socialLinks: {
        'instagram': _instagram.text.trim(),
        'facebook': _facebook.text.trim(),
        'google': _google.text.trim(),
      },
    );
    final shop = context.read<ShopProvider>();
    await shop.saveSettings(updated, ShopManager.shopId!);
    if (!mounted) return;
    setState(() => _busy = false);
    showSnack(context, t(context).settingsSaved);
  }

  Future<void> _uploadLogo() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;
    final bytes = File(file.path);
    final ref = FirebaseStorage.instance
        .ref('shops/${ShopManager.shopId}/logo');
    await ref.putFile(bytes);
    final url = await ref.getDownloadURL();
    _set((s) => s.copyWith(logoUrl: url));
  }

  Future<void> _shareLink() async {
    await Share.share(
      '${t(context).appName} - ${_draft.shopName}\n$_link',
      subject: _draft.shopName,
    );
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _link));
    if (mounted) showSnack(context, t(context).linkCopied);
  }

  @override
  Widget build(BuildContext context) {
    final shop = context.watch<ShopProvider>();
    if (shop.settings == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return Scaffold(
      appBar: AppBar(title: Text(t(context).bookingPageSettings)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ---- Booking link ----
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 92,
                    decoration: BoxDecoration(
                      color: appBrandBackground,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(18),
                    child: Image.asset('assets/brand/app_icon.png'),
                  ),
                  const SizedBox(height: 12),
                  Text(t(context).shareBookingLink,
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(t(context).shareLinkHint,
                      style: TextStyle(
                          color: Colors.grey.shade600, fontSize: 12)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.link_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_link,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                        ),
                        IconButton(
                          onPressed: _copyLink,
                          icon: const Icon(Icons.copy_rounded, size: 18),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _shareLink,
                          icon: const Icon(Icons.share_rounded, size: 18),
                          label: Text(t(context).shareBookingLink),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const BookingFlowScreen()),
                          ),
                          icon: const Icon(Icons.visibility_rounded, size: 18),
                          label: Text(t(context).openBookingPage),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _card(t(context).brandingSettings, [
            LabeledField(
              label: t(context).shopName,
              child: TextField(controller: _shopName),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: t(context).aboutUs,
              child: TextField(controller: _about, maxLines: 2),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: LabeledField(
                    label: t(context).phone,
                    child: TextField(
                        controller: _phone,
                        keyboardType: TextInputType.phone),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LabeledField(
                    label: t(context).currency,
                    child: TextField(controller: _currency),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: t(context).address,
              child: TextField(controller: _address),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: Text(t(context).logo,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                IconButton(
                  onPressed: _uploadLogo,
                  icon: const Icon(Icons.image_outlined),
                ),
                if (_draft.logoUrl != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _draft.logoUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            ColorPicker(
              label: t(context).primaryColor,
              selectedHex: _draft.primaryColorHex,
              onChanged: (h) => _set((s) => s.copyWith(primaryColorHex: h)),
            ),
            const SizedBox(height: 16),
            ColorPicker(
              label: t(context).accentColor,
              selectedHex: _draft.accentColorHex,
              onChanged: (h) => _set((s) => s.copyWith(accentColorHex: h)),
            ),
          ]),
          const SizedBox(height: 12),

          _card(t(context).bookingOptions, [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t(context).autoConfirm),
              value: _draft.autoConfirm,
              onChanged: (v) => _set((s) => s.copyWith(autoConfirm: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t(context).allowOutOfHours),
              value: _draft.allowOutOfHours,
              onChanged: (v) => _set((s) => s.copyWith(allowOutOfHours: v)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t(context).reviews),
              value: _draft.showRatings,
              onChanged: (v) => _set((s) => s.copyWith(showRatings: v)),
            ),
            LabeledField(
              label: t(context).maxAdvanceDays,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.event_available_rounded),
                  hintText: '${_draft.maxAdvanceDays}',
                ),
                onChanged: (v) => _set(
                    (s) => s.copyWith(maxAdvanceDays: int.tryParse(v) ?? 60)),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          _card(t(context).cancellationPolicy, [
            LabeledField(
              label: t(context).cancelFreeHours,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.timer_outlined),
                  hintText: '${_draft.cancelFreeHours}',
                ),
                onChanged: (v) => _set((s) => s
                    .copyWith(cancelFreeHours: int.tryParse(v) ?? 6)),
              ),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: t(context).cancelFeePercent,
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.percent_rounded),
                  hintText: '${_draft.cancelFeePercent}',
                ),
                onChanged: (v) => _set((s) => s
                    .copyWith(cancelFeePercent: double.tryParse(v) ?? 20)),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _draft.whoPaysFees,
              decoration:
                  InputDecoration(labelText: t(context).whoPaysFee),
              items: [
                DropdownMenuItem(
                    value: 'customer', child: Text(t(context).customerPays)),
                DropdownMenuItem(
                    value: 'shop', child: Text(t(context).shopPays)),
              ],
              onChanged: (v) =>
                  _set((s) => s.copyWith(whoPaysFees: v ?? 'customer')),
            ),
          ]),
          const SizedBox(height: 12),

          _card(t(context).depositSettings, [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t(context).enableDeposits),
              value: _draft.depositsEnabled,
              onChanged: (v) => _set((s) => s.copyWith(depositsEnabled: v)),
            ),
            if (_draft.depositsEnabled) ...[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t(context).depositHighDemandOnly),
                value: _draft.depositHighDemandOnly,
                onChanged: (v) => _set(
                    (s) => s.copyWith(depositHighDemandOnly: v)),
              ),
              LabeledField(
                label: t(context).depositPercent,
                child: TextField(
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.percent_rounded),
                    hintText: '${_draft.depositPercent}',
                  ),
                  onChanged: (v) => _set((s) => s
                      .copyWith(depositPercent: double.tryParse(v) ?? 20)),
                ),
              ),
            ],
          ]),
          const SizedBox(height: 12),

          _card(t(context).reminderSettings, [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(t(context).enableReminders),
              value: _draft.remindersEnabled,
              onChanged: (v) =>
                  _set((s) => s.copyWith(remindersEnabled: v)),
            ),
            const SizedBox(height: 8),
            Text(t(context).channels,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                _channelChip('email', t(context).channelEmail, Icons.email_outlined),
                _channelChip('sms', t(context).channelSms, Icons.sms_outlined),
                _channelChip('whatsapp', t(context).channelWhatsapp, Icons.chat_rounded),
              ],
            ),
            const SizedBox(height: 12),
            Text(t(context).reminderTimings,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final h in _draft.reminderTimings)
                  InputChip(
                    label: Text('$h h'),
                    onDeleted: () => _set((s) => s.copyWith(
                        reminderTimings: s.reminderTimings
                            .where((x) => x != h)
                            .toList())),
                  ),
                ActionChip(
                  avatar: const Icon(Icons.add_rounded, size: 16),
                  label: Text(t(context).addTiming),
                  onPressed: () async {
                    final picked = await showDialog<int>(
                      context: context,
                      builder: (ctx) => _TimingDialog(),
                    );
                    if (picked != null) {
                      _set((s) => s.copyWith(
                          reminderTimings: [...s.reminderTimings, picked]
                            ..sort()));
                    }
                  },
                ),
              ],
            ),
          ]),
          const SizedBox(height: 12),

          _card(t(context).workingHours, [
            WorkHoursEditor(
              value: _draft.workingHours,
              onChanged: (m) => _set((s) => s.copyWith(workingHours: m)),
            ),
          ]),
          const SizedBox(height: 12),

          _card(t(context).policies, [
            for (var i = 0; i < _draft.policies.length; i++)
              Row(
                children: [
                  const Icon(Icons.check_circle_outline_rounded, size: 16, color: Color(0xFF059669)),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_draft.policies[i], style: const TextStyle(fontSize: 13))),
                  IconButton(
                    onPressed: () => _set((s) => s.copyWith(
                        policies: s.policies.where((x) => x != _draft.policies[i]).toList())),
                    icon: const Icon(Icons.close_rounded, size: 16),
                  ),
                ],
              ),
            OutlinedButton.icon(
              onPressed: () async {
                final c = TextEditingController();
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(t(ctx).addPolicy),
                    content: TextField(controller: c),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(t(ctx).cancel)),
                      FilledButton(
                          onPressed: () {
                            if (c.text.trim().isNotEmpty) {
                              _set((s) =>
                                  s.copyWith(policies: [...s.policies, c.text.trim()]));
                            }
                            Navigator.pop(ctx);
                          },
                          child: Text(t(ctx).add)),
                    ],
                  ),
                );
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(t(context).addPolicy),
            ),
          ]),
          const SizedBox(height: 12),

          _card(t(context).seoSettings, [
            LabeledField(
              label: t(context).seoTitle,
              child: TextField(controller: _seoTitle),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: t(context).seoDescription,
              child: TextField(controller: _seoDescription, maxLines: 3),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: t(context).seoKeywords,
              child: TextField(controller: _seoKeywords),
            ),
          ]),
          const SizedBox(height: 12),

          _card(t(context).socialLinks, [
            LabeledField(
              label: t(context).instagram,
              child: TextField(
                  controller: _instagram,
                  decoration: const InputDecoration(hintText: 'instagram.com/...')),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: t(context).facebook,
              child: TextField(
                  controller: _facebook,
                  decoration: const InputDecoration(hintText: 'facebook.com/...')),
            ),
            const SizedBox(height: 12),
            LabeledField(
              label: t(context).googleProfile,
              child: TextField(
                  controller: _google,
                  decoration: const InputDecoration(hintText: 'google.com/...')),
            ),
          ]),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text(t(context).saveSettings),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _channelChip(String value, String label, IconData icon) {
    final selected = _draft.reminderChannels.contains(value);
    return FilterChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      selected: selected,
      onSelected: (v) {
        final channels = List<String>.from(_draft.reminderChannels);
        if (v && !channels.contains(value)) {
          channels.add(value);
        } else if (!v) {
          channels.remove(value);
        }
        _set((s) => s.copyWith(reminderChannels: channels));
      },
    );
  }

  Widget _card(String title, List<Widget> children) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A))),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

typedef BuildingSettingsBuilder = BookingSettings Function(BookingSettings);

class _TimingDialog extends StatefulWidget {
  @override
  State<_TimingDialog> createState() => _TimingDialogState();
}

class _TimingDialogState extends State<_TimingDialog> {
  int _hours = 2;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(t(context).reminderTimings),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$_hours h'),
          Slider(
            value: _hours.toDouble(),
            min: 1,
            max: 72,
            divisions: 71,
            label: '$_hours',
            onChanged: (v) => setState(() => _hours = v.round()),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(t(context).cancel)),
        FilledButton(
            onPressed: () => Navigator.pop(context, _hours),
            child: Text(t(context).add)),
      ],
    );
  }
}
