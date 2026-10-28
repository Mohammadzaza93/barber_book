import 'package:flutter/material.dart';

import '../../l10n/strings.dart';
import 'business_management_tabs.dart';
import 'chair_operations_tab.dart';

class BusinessToolsScreen extends StatelessWidget {
  const BusinessToolsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabs: [
                Tab(
                    text: t(context).tabCustomers,
                    icon: const Icon(Icons.people_alt_outlined)),
                Tab(
                    text: t(context).tabLoyalty,
                    icon: const Icon(Icons.stars_outlined)),
                Tab(
                    text: t(context).tabChairs,
                    icon: const Icon(Icons.event_seat_outlined)),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                CustomerManagementTab(),
                LoyaltyProgramTab(),
                ChairOperationsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
