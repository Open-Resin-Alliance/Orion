/*
* Orion - Materials Screen
* Copyright (C) 2025 Open Resin Alliance
*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
*     http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

import 'package:flutter/material.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/materials/heater_screen.dart';
import 'package:orion/materials/resins_screen.dart';
import 'package:orion/materials/calibration_screen.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/widgets/orion_app_bar.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MaterialsScreen extends StatefulWidget {
  // Make initialIndex nullable to be defensive against hot-reload/runtime
  // instances where the field might temporarily be null. We'll default to 0
  // in initState.
  final int? initialIndex;
  const MaterialsScreen({super.key, this.initialIndex});

  @override
  MaterialsScreenState createState() => MaterialsScreenState();
}

class MaterialsScreenState extends State<MaterialsScreen> {
  int _selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex ?? 0;
  }

  @override
  Widget build(BuildContext context) {
    final cfg = OrionConfig();
    final hasVat = cfg.hasHeatedVat();
    final hasChamber = cfg.hasHeatedChamber();

    // Build tabs dynamically. If neither heater is present, hide the
    // Heaters tab entirely.
    final List<Widget> screens = [];
    final List<BottomNavigationBarItem> items = [];

    if (hasVat || hasChamber) {
      screens.add(const HeaterScreen());
      items.add(BottomNavigationBarItem(
        icon: PhosphorIcon(PhosphorIcons.thermometer()),
        activeIcon: PhosphorIcon(PhosphorIconsFill.thermometer,
            color: Theme.of(context).colorScheme.primary),
        label: 'Heaters',
      ));
    }

    screens.add(const ResinsScreen());
    items.add(BottomNavigationBarItem(
      icon: PhosphorIcon(PhosphorIcons.flask()),
      activeIcon: PhosphorIcon(PhosphorIconsFill.flask,
          color: Theme.of(context).colorScheme.primary),
      label: 'Resins',
    ));

    screens.add(const CalibrationScreen());
    items.add(BottomNavigationBarItem(
      icon: PhosphorIcon(PhosphorIcons.scales()),
      activeIcon: PhosphorIcon(PhosphorIconsFill.scales,
          color: Theme.of(context).colorScheme.primary),
      label: 'Calibration',
    ));

    // Ensure selected index is within bounds
    if (_selectedIndex >= screens.length) _selectedIndex = 0;

    return GlassApp(
      child: Scaffold(
        appBar: OrionAppBar(
          title: const Text('Materials'),
          toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
          actions: const [SystemStatusWidget()],
        ),
        body: screens[_selectedIndex],
        bottomNavigationBar: GlassBottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: items,
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          onTap: (idx) => _onItemTapped(idx),
          unselectedItemColor: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
