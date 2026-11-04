import 'package:flutter/widgets.dart';

/// يبقي [TextEditingController]s حيّة طوال بقاء المسار/الحوار في الشجرة،
/// ثم يتلفها عند إزالته فعلياً.
///
/// الحوارات كثيراً ما تنشئ المتحكّمات خارج الـbuilder وتتلفها عبر
/// `addPostFrameCallback` بعد `await showDialog`. هذا الـcallback قد يعمل
/// بينما المسار لا يزال في حركة الإغلاق، فتُستخدم المتحكّمات بعد إتلافها.
/// ربط الإتلاف بدورة حياة الـWidget يمنع ذلك.
class ControllerScope extends StatefulWidget {
  const ControllerScope({
    super.key,
    required this.controllers,
    required this.builder,
  });

  final List<TextEditingController> controllers;
  final WidgetBuilder builder;

  @override
  State<ControllerScope> createState() => _ControllerScopeState();
}

class _ControllerScopeState extends State<ControllerScope> {
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
