/*
* Orion - Debug Options Screen
* Copyright (C) 2026 Open Resin Alliance
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
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/orion_list_tile.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/thumbnail_cache.dart';
import 'package:orion/util/widgets/system_status_widget.dart';
import 'package:orion/widgets/orion_app_bar.dart';

class DebugOptionsScreen extends StatefulWidget {
  const DebugOptionsScreen({super.key});

  @override
  State<DebugOptionsScreen> createState() => _DebugOptionsScreenState();
}

class _DebugOptionsScreenState extends State<DebugOptionsScreen> {
  final OrionConfig config = OrionConfig();

  late bool overrideRawForceSensorValues;
  late bool reuseCalibrationPlate;
  late bool forceMechanicalSkew;
  late bool forceObstruction;

  @override
  void initState() {
    super.initState();
    overrideRawForceSensorValues =
        config.getFlag('overrideRawForceSensorValues', category: 'developer');
    reuseCalibrationPlate =
        config.getFlag('reuseCalibrationPlate', category: 'developer');
    forceMechanicalSkew =
        config.getFlag('forceMechanicalSkew', category: 'developer');
    forceObstruction =
        config.getFlag('forceObstruction', category: 'developer');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      child: GlassApp(
        child: Scaffold(
          appBar: OrionAppBar(
            title: Text(
                FlutterI18n.translate(context, 'generalSettings.debugOptions')),
            toolbarHeight: Theme.of(context).appBarTheme.toolbarHeight,
            actions: <Widget>[
              SystemStatusWidget(),
            ],
          ),
          body: Padding(
            padding: OrionSpacing.settingsScreenPadding,
            child: ListView(
              children: [
                GlassCard(
                  outlined: true,
                  elevation: 1,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          FlutterI18n.translate(
                              context, 'generalSettings.debugOptions'),
                          style: const TextStyle(
                            fontSize: 28.0,
                          ),
                        ),
                        const SizedBox(height: 20.0),
                        OrionListTile(
                          title: FlutterI18n.translate(context, 'update.rawForceSensor'),
                          icon: PhosphorIcons.scales(),
                          value: overrideRawForceSensorValues,
                          onChanged: (bool value) {
                            setState(() {
                              overrideRawForceSensorValues = value;
                              config.setFlag('overrideRawForceSensorValues',
                                  overrideRawForceSensorValues,
                                  category: 'developer');
                            });
                          },
                        ),
                        const SizedBox(height: 20.0),
                        OrionListTile(
                          title: FlutterI18n.translate(context, 'update.reuseCalPlate'),
                          icon: PhosphorIcons.flask(),
                          value: reuseCalibrationPlate,
                          onChanged: (bool value) {
                            setState(() {
                              reuseCalibrationPlate = value;
                              config.setFlag('reuseCalibrationPlate', value,
                                  category: 'developer');
                            });
                          },
                        ),
                        const SizedBox(height: 20.0),
                        OrionListTile(
                          title: FlutterI18n.translate(
                              context, 'update.forceMechanicalSkew'),
                          icon: PhosphorIcons.warning(),
                          value: forceMechanicalSkew,
                          onChanged: (bool value) {
                            setState(() {
                              forceMechanicalSkew = value;
                              config.setFlag('forceMechanicalSkew', value,
                                  category: 'developer');
                            });
                          },
                        ),
                        const SizedBox(height: 20.0),
                        OrionListTile(
                          title: FlutterI18n.translate(
                              context, 'update.forceObstruction'),
                          icon: PhosphorIcons.warningOctagon(),
                          value: forceObstruction,
                          onChanged: (bool value) {
                            setState(() {
                              forceObstruction = value;
                              config.setFlag('forceObstruction', value,
                                  category: 'developer');
                            });
                          },
                        ),
                        const SizedBox(height: 20.0),
                        Row(
                          children: [
                            Expanded(
                              child: GlassButton(
                                style: ElevatedButton.styleFrom(
                                  minimumSize: const Size(0, 60),
                                ),
                                tint: GlassButtonTint.warn,
                                onPressed: () async {
                                  final nav = Navigator.of(context);
                                  final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (ctx) => GlassAlertDialog(
                                          title: Text(FlutterI18n.translate(context,
                                              'generalSettings.clearThumbnailCache')),
                                          content: Text(
                                              FlutterI18n.translate(
                                                  context, 'generalSettings.cacheClearMsg'),
                                              style: const TextStyle(fontSize: 20.0)),
                                          actions: [
                                            GlassButton(
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize: const Size(0, 60),
                                                ),
                                                tint: GlassButtonTint.neutral,
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(false),
                                                child: Text(FlutterI18n.translate(
                                                    context, 'common.cancel'))),
                                            GlassButton(
                                                tint: GlassButtonTint.warn,
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize: const Size(0, 60),
                                                ),
                                                onPressed: () =>
                                                    Navigator.of(ctx).pop(true),
                                                child: Text(FlutterI18n.translate(
                                                    context, 'common.clear'))),
                                          ],
                                        ),
                                      ) ??
                                      false;

                                  if (confirmed) {
                                    try {
                                      // Show clearing message
                                      final navCtx = nav.context;
                                      if (!navCtx.mounted) return;
                                      showDialog(
                                        context: navCtx,
                                        barrierDismissible: false,
                                        builder: (ctx) => GlassAlertDialog(
                                          title: Text(FlutterI18n.translate(
                                              context, 'generalSettings.clearingCache')),
                                          content: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const CircularProgressIndicator(),
                                              const SizedBox(height: 16),
                                              Text(
                                                  FlutterI18n.translate(context,
                                                      'generalSettings.cacheClearing'),
                                                  style: const TextStyle(fontSize: 20)),
                                            ],
                                          ),
                                        ),
                                      );

                                      // Clear the cache
                                      await ThumbnailCache.instance.clearAll();

                                      // Close progress dialog
                                      if (mounted) nav.pop();

                                      // Show success message
                                      if (mounted) {
                                        showDialog(
                                          context: nav.context,
                                          builder: (ctx) => GlassAlertDialog(
                                            title: Text(FlutterI18n.translate(
                                                context, 'common.success')),
                                            content: Text(
                                                FlutterI18n.translate(context,
                                                    'generalSettings.cacheCleared'),
                                                style: const TextStyle(fontSize: 20)),
                                            actions: [
                                              GlassButton(
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize: const Size(0, 60),
                                                ),
                                                onPressed: () => Navigator.of(ctx).pop(),
                                                child: Text(FlutterI18n.translate(
                                                    context, 'common.ok')),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      // Close progress dialog if still showing
                                      if (mounted) nav.pop();

                                      // Show error message
                                      if (mounted) {
                                        showDialog(
                                          context: nav.context,
                                          builder: (ctx) => GlassAlertDialog(
                                            title: Text(FlutterI18n.translate(
                                                context, 'common.error')),
                                            content: Text(
                                                '${FlutterI18n.translate(context, 'generalSettings.failedToClearCache')}$e',
                                                style: const TextStyle(fontSize: 20)),
                                            actions: [
                                              GlassButton(
                                                style: ElevatedButton.styleFrom(
                                                  minimumSize: const Size(0, 60),
                                                ),
                                                onPressed: () => Navigator.of(ctx).pop(),
                                                child: Text(FlutterI18n.translate(
                                                    context, 'common.ok')),
                                              ),
                                            ],
                                          ),
                                        );
                                      }
                                    }
                                  }
                                },
                                child: Text(
                                  FlutterI18n.translate(
                                      context, 'generalSettings.clearThumbnailCache'),
                                  style: const TextStyle(fontSize: 22),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}
