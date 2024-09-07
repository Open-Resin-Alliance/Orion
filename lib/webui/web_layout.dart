// ignore_for_file: use_build_context_synchronously

/*
* Orion - Web Layout
* Copyright (C) 2024 TheContrappostoShop
*
* This program is free software: you can redistribute it and/or modify
* it under the terms of the GNU General Public License as published by
* the Free Software Foundation, either version 3 of the License, or
* (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
* GNU General Public License for more details.
*
* You should have received a copy of the GNU General Public License
* along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/

import 'dart:async';
import 'package:orion/util/error_handling/error_dialog.dart';
import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:orion/api_services/api_services.dart';
import 'package:orion/settings/about_screen.dart';
import 'package:orion/status/status_screen.dart';
import 'package:orion/webui/files/web_files_screen.dart';
import 'package:orion/tools/exposure_screen.dart';
import 'package:orion/tools/move_z_screen.dart';
import 'package:orion/settings/general_screen.dart';

class WebLayout extends StatefulWidget {
  const WebLayout({super.key});

  @override
  WebLayoutState createState() => WebLayoutState();
}

class WebLayoutState extends State<WebLayout>
    with SingleTickerProviderStateMixin {
  // State variable to track the current screen
  String currentScreen = 'main';

  late AnimationController _controller;
  late Animation<Color?> _animation;
  final Logger _logger = Logger('WebLayout');
  final _api = ApiService();
  Timer? _timer;

  bool isBusy = false;
  bool isOnline = false;
  bool hasShownError = false;
  String statusMessage = '';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);
    _updateAnimation();
    getConnectionStatus();
    _timer = Timer.periodic(const Duration(seconds: 2), (timer) {
      checkConnectionStatus();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _updateAnimation() {
    _animation = ColorTween(
      begin: isOnline
          ? isBusy
              ? Colors.amber
              : Colors.green
          : Colors.red,
      end: isOnline
          ? isBusy
              ? Colors.amberAccent
              : Colors.greenAccent
          : Colors.redAccent,
    ).animate(_controller);
  }

  Future<void> getConnectionStatus() async {
    try {
      Map<String, dynamic>? status = await _api.getStatus();
      setState(() {
        isOnline = true;

        if (status['status'] == 'Printing') {
          isBusy = true;
          statusMessage = 'Busy';
        } else {
          isBusy = false;
          statusMessage = 'Idle';
        }
        _updateAnimation(); // Update the animation colors
      });
    } catch (e) {
      setState(() {
        isOnline = false;
        statusMessage = 'Offline';
        _updateAnimation(); // Update the animation colors
      });
      _logger.severe('Failed to get config: $e');
    }
  }

  Future<void> checkConnectionStatus() async {
    try {
      Map<String, dynamic>? status = await _api.getStatus();
      bool newIsOnline = status['status'] != 'Offline';
      bool newBusyState = status['status'] == 'Printing';

      if (newBusyState != isBusy || newIsOnline != isOnline) {
        setState(() {
          isBusy = newBusyState;
          isOnline = newIsOnline;
          statusMessage = isBusy ? 'Busy' : 'Idle';
          _updateAnimation(); // Update the animation colors
        });
      }
    } catch (e) {
      if (isOnline) {
        if (!hasShownError) {
          showErrorDialog(context, 'BLUE-BANANA', overrideWeb: true,
              onClosed: () {
            html.window.location.reload();
          });
          hasShownError = true;
        }
      }
      setState(() {
        isOnline = false;
        statusMessage = 'Offline';
        _updateAnimation(); // Update the animation colors
      });
      _logger.severe('Failed to get config: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        scrolledUnderElevation: 0.0,
        title: Row(
          children: [
            const Spacer(),
            Text('Prometheus mSLA - $statusMessage'),
            const SizedBox(width: 8),
            AnimatedBuilder(
              animation: _animation,
              builder: (context, child) {
                return Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: _animation.value,
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
            const Spacer(),
          ],
        ),
        toolbarHeight: 60,
      ),
      body: FutureBuilder<void>(
        future: checkConnectionStatus(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return const Center(child: Text('Error loading status'));
          } else {
            return LayoutBuilder(
              builder: (context, constraints) {
                final screenWidth = MediaQuery.of(context).size.width;
                final screenHeight = MediaQuery.of(context).size.height;

                if (screenWidth > 1800 && screenHeight > 900) {
                  return _buildLargeScreenLayout();
                } else if (screenWidth > 1200 && screenHeight > 900) {
                  return _buildMediumScreenLayout();
                } else if (screenWidth > 800 && screenHeight > 900) {
                  return _buildSlimScreenLayout();
                } else if (screenWidth > 1200 && screenHeight < 900) {
                  return _buildHalfHeightScreenLayout();
                } else if (screenWidth > 100 && screenHeight > 850) {
                  return _buildSmallScreenLayout(true);
                } else if (screenWidth > 600 && screenHeight < 850) {
                  return _buildSmallScreenLayout(false);
                } else {
                  return const Center(
                    child: Text('Sorry, this screen size is not supported.'),
                  );
                }
              },
            );
          }
        },
      ),
    );
  }

  Widget _buildLargeScreenLayout() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Card.outlined(
              child: WebFilesScreen(isBusy: isBusy),
            ),
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: 0.0, bottom: 16.0),
            child: Column(
              children: [
                Expanded(
                  child: Card.outlined(
                    child: StatusScreen(newPrint: false, webView: true),
                  ),
                ),
                SizedBox(height: 16),
                Expanded(
                  child: Card.outlined(
                    child: Padding(
                      padding: EdgeInsets.only(top: 16.0, bottom: 16.0),
                      child: GeneralCfgScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Column(
              children: [
                Expanded(
                  child: Card.outlined(
                    child: MoveZScreen(
                      isBusy: isBusy,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card.outlined(
                    child: ExposureScreen(
                      isBusy: isBusy,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Expanded(
                  child: Card.outlined(
                    child: AboutScreen(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMediumScreenLayout() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Card.outlined(
              child: WebFilesScreen(isBusy: isBusy),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 0.0, bottom: 16.0, right: 16.0),
            child: Column(
              children: [
                const Expanded(
                  child: Card.outlined(
                    child: StatusScreen(
                      newPrint: false,
                      webView: true,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Card.outlined(
                    child: MoveZScreen(
                      isBusy: isBusy,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSlimScreenLayout() {
    return Column(
      children: [
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Card.outlined(
              child: StatusScreen(
                newPrint: false,
                forceHorizontal: true,
              ),
            ),
          ),
        ),
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Card.outlined(
              child: WebFilesScreen(isBusy: isBusy),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHalfHeightScreenLayout() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 16.0, bottom: 16.0),
            child: Card.outlined(
              child: WebFilesScreen(isBusy: isBusy),
            ),
          ),
        ),
        const Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Card.outlined(
              child: StatusScreen(newPrint: false),
            ),
          ),
        )
      ],
    );
  }

  Widget _buildSmallScreenLayout(bool vertical) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding:
                const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 16.0),
            child: Card.outlined(
              child: Column(
                children: [
                  Expanded(
                    child: StatusScreen(
                      newPrint: false,
                      forceVertical: vertical,
                      forceHorizontal: !vertical,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
