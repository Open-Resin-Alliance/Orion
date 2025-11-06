/*
* Orion - Tools Screen
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

import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/tools/move_z_screen.dart';
import 'package:orion/tools/exposure_screen.dart';
import 'package:orion/tools/force_screen.dart';
import 'package:orion/util/widgets/system_status_widget.dart';

class ToolsScreen extends StatefulWidget {
  const ToolsScreen({super.key});

  @override
  ToolsScreenState createState() => ToolsScreenState();
}

class ToolsScreenState extends State<ToolsScreen> {
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
          title: const Text('Tools'),
          actions: const [SystemStatusWidget()],
        ),
        body: _selectedIndex == 0
            ? const MoveZScreen()
            : _selectedIndex == 1
                ? const ExposureScreen()
                : _selectedIndex == 2
                    ? const ForceSensorScreen()
                    : const MoveZScreen(),
        bottomNavigationBar: GlassBottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          items: <BottomNavigationBarItem>[
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIcons.arrowsDownUp()),
              activeIcon: PhosphorIcon(
                PhosphorIconsFill.arrowsDownUp,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Move Z',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIcons.lightbulbFilament()),
              activeIcon: PhosphorIcon(
                PhosphorIconsFill.lightbulbFilament,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Exposure',
            ),
            BottomNavigationBarItem(
              icon: PhosphorIcon(PhosphorIcons.chartLineUp()),
              activeIcon: PhosphorIcon(
                PhosphorIconsFill.chartLineUp,
                color: Theme.of(context).colorScheme.primary,
              ),
              label: 'Force Sensor',
            ),
            // TODO: Implement Self Test
            /*BottomNavigationBarItem(
            icon: Icon(Icons.check),
            label: 'Self Test',
          ),*/
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
