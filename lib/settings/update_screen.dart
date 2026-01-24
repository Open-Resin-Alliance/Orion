/*
* Orion - Update Screen
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

// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/orion_update_provider.dart';
import 'package:orion/util/providers/athena_update_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:orion/util/update_manager.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/settings/update_progress.dart';
import 'package:orion/util/markdown_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_http_client.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  UpdateScreenState createState() => UpdateScreenState();
}

class UpdateScreenState extends State<UpdateScreen> {
  final Logger _logger = Logger('UpdateScreen');
  final OrionConfig _config = OrionConfig();

  @override
  void initState() {
    super.initState();
    // Updates are now managed by background providers (UpdateManager),
    // so we don't need to trigger checks here manually unless we want a "Refresh" button.
    // However, to ensure fresh data when visiting the screen, we can trigger a check if not already checking.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orionProvider =
          Provider.of<OrionUpdateProvider>(context, listen: false);
      if (!orionProvider.isLoading) {
        orionProvider.checkForUpdates();
      }
      final athenaProvider =
          Provider.of<AthenaUpdateProvider>(context, listen: false);
      if (!athenaProvider.isChecking) {
        athenaProvider.checkForUpdates();
      }
    });
  }

  void _viewChangelog(String releaseNotes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownScreen(changelog: releaseNotes),
      ),
    );
  }

  Future<void> launchUpdateDialog(
      OrionUpdateProvider provider, String assetUrl) async {
    bool shouldUpdate = await showDialog(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return GlassAlertDialog(
          title: Row(
            children: [
              PhosphorIcon(
                PhosphorIcons.download(),
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                'Update Orion',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ),
          content: const Text(
              'Do you want to update the Orion HMI?\nThis will download the latest version from GitHub.'),
          actions: [
            GlassButton(
              tint: GlassButtonTint.negative,
              onPressed: () {
                Navigator.of(context).pop(false);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 60),
              ),
              child: const Text(
                'Dismiss',
                style: TextStyle(fontSize: 20),
              ),
            ),
            GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 60),
              ),
              child: const Text(
                'Update Now',
                style: TextStyle(fontSize: 20),
              ),
            )
          ],
        );
      },
    );

    if (shouldUpdate) {
      // Clear pending Orion updates before starting, in case Orion exits during process
      final updateManager = Provider.of<UpdateManager>(context, listen: false);
      updateManager.clearPendingUpdates(components: {UpdateComponent.orion});
      await provider.performUpdate(context, assetUrl);
    }
  }

  Future<void> _triggerAthenaUpdate(BuildContext ctx) async {
    // Confirm again with the user
    final confirmed = await showDialog<bool>(
          context: ctx,
          barrierDismissible: false,
          builder: (dctx) => GlassAlertDialog(
            title: Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.download(),
                  color: Theme.of(context).colorScheme.primary,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Text(
                  'Update AthenaOS',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
            content: const Text(
                'Do you want to update AthenaOS?\nThis will trigger an update on the connected Athena printer.'),
            actions: [
              GlassButton(
                tint: GlassButtonTint.negative,
                onPressed: () => Navigator.of(dctx).pop(false),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60)),
                child: const Text('Dismiss', style: TextStyle(fontSize: 20)),
              ),
              GlassButton(
                tint: GlassButtonTint.positive,
                onPressed: () => Navigator.of(dctx).pop(true),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60)),
                child: const Text('Update Now', style: TextStyle(fontSize: 20)),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    // Clear pending updates (both Orion and Athena, as AthenaOS may update both)
    final updateManager = Provider.of<UpdateManager>(ctx, listen: false);
    updateManager.clearPendingUpdates(
        components: {UpdateComponent.orion, UpdateComponent.athena});

    // Pause polling to prevent connection error dialogs during update/reboot
    final statusProvider = Provider.of<StatusProvider>(ctx, listen: false);
    statusProvider.pausePolling();

    // Create notifiers for the progress overlay (indeterminate progress)
    final progressNotifier = ValueNotifier<double>(-1.0); // -1 = indeterminate
    final messageNotifier =
        ValueNotifier<String>('Triggering AthenaOS update...');

    // Navigate to the update progress overlay
    Navigator.of(ctx).push(
      MaterialPageRoute(
        builder: (context) => UpdateProgressOverlay(
          progress: progressNotifier,
          message: messageNotifier,
          icon: PhosphorIcons.warningDiamond(),
        ),
      ),
    );

    // Trigger the update in the background
    // The system will reboot, so we don't need to dismiss the overlay
    try {
      final nano = NanoDlpHttpClient();
      await nano.updateBackend();
      messageNotifier.value = 'AthenaOS Update intitiated!';
    } catch (e) {
      _logger.warning('AthenaOS update error: $e');
      messageNotifier.value = 'AthenaOS Update initiated. System will reboot!';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Orion HMI Updater Card
            Expanded(
              child: GlassCard(
                outlined: true,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Consumer<OrionUpdateProvider>(
                    builder: (context, orionProvider, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Row(
                            children: [
                              orionProvider.betaUpdatesOverride
                                  ? orionProvider.preRelease
                                      ? Stack(
                                          alignment: Alignment.center,
                                          children: [
                                            PhosphorIcon(
                                              PhosphorIcons.knife(),
                                              color: Colors.transparent,
                                              size: 24,
                                            ),
                                            const Positioned(
                                              top: 0,
                                              right: 0,
                                              child: PhosphorIcon(
                                                PhosphorIconsDuotone.knife,
                                                color: Colors.redAccent,
                                                size: 20,
                                              ),
                                            ),
                                            const Positioned(
                                              bottom: 0,
                                              left: 3,
                                              child: PhosphorIcon(
                                                PhosphorIconsFill.dropSimple,
                                                color: Colors.redAccent,
                                                size: 8,
                                              ),
                                            ),
                                          ],
                                        )
                                      : PhosphorIcon(PhosphorIconsFill.info,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .primary,
                                          size: 24)
                                  : PhosphorIcon(PhosphorIconsFill.info,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 24),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Orion HMI',
                                  style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Status content
                          Expanded(
                            child: _buildOrionContent(orionProvider),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Backend/AthenaOS Updater Card
            Expanded(
              child: GlassCard(
                outlined: true,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Consumer<AthenaUpdateProvider>(
                    builder: (context, athenaProvider, child) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Header
                          Builder(builder: (ctx) {
                            final cfg = _config;
                            final isNano = cfg.isNanoDlpMode();
                            final model =
                                cfg.getMachineModelName().toLowerCase();
                            final isAthena = model.contains('athena');

                            String headerText;
                            if (isNano && isAthena) {
                              headerText = 'AthenaOS';
                            } else {
                              headerText = 'Backend';
                            }

                            return Row(
                              children: [
                                PhosphorIcon(
                                  isNano && isAthena
                                      ? PhosphorIconsFill.info
                                      : PhosphorIconsFill.info,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    headerText,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Status content
                          Expanded(
                            child: _buildBackendContent(athenaProvider),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrionContent(OrionUpdateProvider provider) {
    if (provider.rateLimitExceeded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error, color: Colors.red, size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Rate Limit Exceeded',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'GitHub API rate limit reached. Please try again later.',
            style: TextStyle(fontSize: 16),
          ),
        ],
      );
    }

    if (provider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.isUpdateAvailable) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(6),
              border:
                  Border.all(color: Colors.orangeAccent.withValues(alpha: 0.5)),
            ),
            child: Text(
              provider.betaUpdatesOverride
                  ? (provider.preRelease ? 'BLEEDING EDGE' : 'ROLLBACK')
                  : 'UPDATE AVAILABLE',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.orangeAccent,
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Version info
          Text(
            provider.betaUpdatesOverride
                ? 'Latest: ${provider.latestVersion}'
                : (provider.latestVersion.contains('+')
                    ? 'Version ${provider.latestVersion.split('+')[0]}'
                    : 'Version ${provider.latestVersion}'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            provider.betaUpdatesOverride
                ? (provider.commitDate.contains('T')
                    ? 'Committed ${provider.commitDate.split('T')[0]}'
                    : 'Committed ${provider.commitDate}')
                : (provider.releaseDate.contains('T')
                    ? 'Released ${provider.releaseDate.split('T')[0]}'
                    : 'Released ${provider.releaseDate}'),
            style: const TextStyle(fontSize: 18, color: Colors.grey),
          ),

          const Spacer(),

          // Action buttons
          Row(
            children: [
              Expanded(
                flex: 1,
                child: GlassButton(
                  tint: GlassButtonTint.neutral,
                  onPressed: () => _viewChangelog(provider.releaseNotes),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(65),
                  ),
                  child: const Icon(Icons.article, size: 20),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 4,
                child: GlassButton(
                  tint: GlassButtonTint.positive,
                  onPressed: () =>
                      launchUpdateDialog(provider, provider.assetUrl),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(65),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.download, size: 24),
                      SizedBox(width: 20),
                      Text('Download & Install',
                          style: TextStyle(fontSize: 20)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    // Up to date
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(6),
            border:
                Border.all(color: Colors.greenAccent.withValues(alpha: 0.5)),
          ),
          child: const Text(
            'UP TO DATE',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.greenAccent,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          provider.betaUpdatesOverride
              ? '${provider.currentVersion} (${provider.release})'
              : 'Version ${provider.currentVersion.split('+')[0]}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          provider.betaUpdatesOverride
              ? 'Running latest bleeding edge build'
              : 'Running latest stable release',
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBackendContent(AthenaUpdateProvider ap) {
    final cfg = _config;
    final isNano = cfg.isNanoDlpMode();
    final model = cfg.getMachineModelName().toLowerCase();
    final isAthena = model.contains('athena');

    if (isNano && isAthena) {
      if (ap.isChecking) {
        return const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Checking for updates...', style: TextStyle(fontSize: 13)),
          ],
        );
      }

      if (ap.updateAvailable) {
        final bool isBetaChannel =
            ap.channel.isNotEmpty && ap.channel != 'stable';
        final bool isSameVersion = ap.latestVersion.isNotEmpty &&
            ap.currentVersion.isNotEmpty &&
            ap.latestVersion == ap.currentVersion;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: isBetaChannel && isSameVersion
                    ? Colors.redAccent.withValues(alpha: 0.12)
                    : Colors.orangeAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: isBetaChannel && isSameVersion
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : Colors.orangeAccent.withValues(alpha: 0.5)),
              ),
              child: Text(
                isBetaChannel && isSameVersion
                    ? 'BETA VERSION'
                    : 'UPDATE AVAILABLE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isBetaChannel && isSameVersion
                      ? Colors.redAccent
                      : Colors.orangeAccent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Version ${ap.latestVersion}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            if (ap.channel.isNotEmpty)
              Text(
                'Channel: ${ap.channel}',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: GlassButton(
                tint: isBetaChannel && isSameVersion
                    ? GlassButtonTint.negative
                    : GlassButtonTint.positive,
                onPressed: () async {
                  // For beta channels where the latest == current we label this
                  // a "Force Update" to make it clear this isn't a normal update.
                  await _triggerAthenaUpdate(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(65),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.system_update_alt, size: 24),
                    const SizedBox(width: 20),
                    Text(
                      isBetaChannel && isSameVersion
                          ? 'Force Update'
                          : 'Update AthenaOS',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      }

      if (ap.currentVersion.isNotEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.greenAccent.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'UP TO DATE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.greenAccent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Version ${ap.currentVersion}',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 6),
            if (ap.channel.isNotEmpty)
              Text(
                'Channel: ${ap.channel}',
                style: const TextStyle(fontSize: 18, color: Colors.grey),
              ),
          ],
        );
      }

      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.info_outline, size: 40, color: Colors.grey),
          SizedBox(height: 12),
          Text(
            'No version information available',
            style: TextStyle(fontSize: 14, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      );
    }

    // Non-Athena backendxw
    return const Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.construction, size: 40, color: Colors.grey),
        SizedBox(height: 12),
        Text(
          'Coming Soon!',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 6),
        Text(
          'Backend updater will be available in a future release',
          style: TextStyle(fontSize: 12, color: Colors.grey),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
