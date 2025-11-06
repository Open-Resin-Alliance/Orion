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
import 'package:phosphor_flutter/phosphor_flutter.dart';

class MaterialsScreen extends StatefulWidget {
  const MaterialsScreen({super.key});

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
  }

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Materials'),
        ),
        body: _selectedIndex == 0
            ? const HeaterScreen()
            : _selectedIndex == 1
                ? const ResinsScreen()
                : const CalibrationScreen(),
        bottomNavigationBar: GlassBottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIcons.thermometer()),
              activeIcon: PhosphorIcon(PhosphorIconsFill.thermometer,
                  color: Theme.of(context).colorScheme.primary),
              label: 'Heaters',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIcons.flask()),
              activeIcon: PhosphorIcon(PhosphorIconsFill.flask,
                  color: Theme.of(context).colorScheme.primary),
              label: 'Resins',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIcons.scales()),
              activeIcon: PhosphorIcon(PhosphorIconsFill.scales,
                  color: Theme.of(context).colorScheme.primary),
              label: 'Calibration',
            ),
          ],
          currentIndex: _selectedIndex,
          selectedItemColor: Theme.of(context).colorScheme.primary,
          onTap: _onItemTapped,
          unselectedItemColor: Theme.of(context).colorScheme.secondary,
        ),
      ),
    );
  }
}
