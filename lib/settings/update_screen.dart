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
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/backend_service/backend_registry.dart';
import 'package:orion/util/providers/theme_provider.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  UpdateScreenState createState() => UpdateScreenState();
}

class UpdateScreenState extends State<UpdateScreen>
    with TickerProviderStateMixin {
  final Logger _logger = Logger('UpdateScreen');
  final OrionConfig _config = OrionConfig();
  final BackendService _backendService = BackendService();
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
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

  @override
  void dispose() {
    _backendService.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _viewChangelog(String releaseNotes) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownScreen(changelog: releaseNotes),
      ),
    );
  }

  Widget _buildPulsingDialog(Widget dialog) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = Curves.easeInOut.transform(_pulseController.value);
        return DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.red.withOpacity(0.1 + (pulseValue * 0.2)),
                blurRadius: 20 + (pulseValue * 10),
                spreadRadius: -15,
                offset: const Offset(0, 0),
              ),
            ],
            borderRadius: BorderRadius.circular(12),
          ),
          child: dialog,
        );
      },
    );
  }

  Future<void> _offerResetChannel(BuildContext ctx) async {
    final resetConfirmed = await showDialog<bool>(
          context: ctx,
          barrierDismissible: false,
          builder: (dctx) => GlassAlertDialog(
            title: Row(
              children: [
                PhosphorIcon(
                  PhosphorIcons.arrowClockwise(),
                  color: Colors.greenAccent,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Reset Update Channel',
                    style: const TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            content: const Text(
              'Would you like to switch back to the stable update channel?\n\n'
              'This is recommended for production builds.',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
            ),
            actions: [
              GlassButton(
                tint: GlassButtonTint.neutral,
                onPressed: () => Navigator.of(dctx).pop(false),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60)),
                child: const Text('Keep Development Channel'),
              ),
              GlassButton(
                tint: GlassButtonTint.positive,
                onPressed: () => Navigator.of(dctx).pop(true),
                style: ElevatedButton.styleFrom(minimumSize: const Size(0, 60)),
                child: const Text('Reset to Stable'),
              ),
            ],
          ),
        ) ??
        false;

    if (resetConfirmed) {
      try {
        final backend = BackendService();
        await backend
            .manualCommand('[[Exec echo "stable" > /home/pi/channel]]');
        _logger.info('Update channel reset to stable');

        // Refresh AthenaOS update status to reflect the new channel
        if (ctx.mounted) {
          final athenaProvider =
              Provider.of<AthenaUpdateProvider>(ctx, listen: false);
          await athenaProvider.checkForUpdates();
        }
      } catch (e) {
        _logger.warning('Failed to reset channel: $e');
      }
    }
  }

  Future<bool> _showDevelopmentFirmwareWarning(BuildContext ctx) async {
    _pulseController.repeat(reverse: true);
    try {
      final confirmed = await showDialog<bool>(
            context: ctx,
            barrierDismissible: false,
            barrierColor: Colors.red.withOpacity(0.15),
            builder: (dctx) => _buildPulsingDialog(
              GlassAlertDialog(
                title: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.warning(),
                      color: Colors.redAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Development Firmware Ahead',
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'This is an unstable development build.\n'
                  'Unexpected behavior may occur.\n'
                  'Hardware damage is possible.\n\n'
                  'You accept all consequences.',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
                ),
                actions: [
                  GlassButton(
                    tint: GlassButtonTint.negative,
                    onPressed: () => Navigator.of(dctx).pop(true),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 60)),
                    child: const Text('I Accept'),
                  ),
                  GlassButton(
                    tint: GlassButtonTint.positive,
                    onPressed: () => Navigator.of(dctx).pop(false),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 60)),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ) ??
          false;
      return confirmed;
    } finally {
      _pulseController.stop();
    }
  }

  Future<bool> _showSecondConfirmation(BuildContext ctx) async {
    _pulseController.repeat(reverse: true);
    try {
      final confirmed = await showDialog<bool>(
            context: ctx,
            barrierDismissible: false,
            barrierColor: Colors.red.withOpacity(0.15),
            builder: (dctx) => _buildPulsingDialog(
              GlassAlertDialog(
                title: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.warning(),
                      color: Colors.redAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Confirm Update',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'Are you certain you want to proceed\nwith this development firmware?\n\n'
                  'The system may become unstable or inoperable.',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),
                ),
                actions: [
                  GlassButton(
                    tint: GlassButtonTint.positive,
                    onPressed: () => Navigator.of(dctx).pop(false),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 60)),
                    child: const Text('Cancel'),
                  ),
                  GlassButton(
                    tint: GlassButtonTint.negative,
                    onPressed: () => Navigator.of(dctx).pop(true),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 60)),
                    child: const Text('Continue'),
                  ),
                ],
              ),
            ),
          ) ??
          false;
      return confirmed;
    } finally {
      _pulseController.stop();
    }
  }

  Future<bool> _showFinalConfirmation(BuildContext ctx) async {
    _pulseController.repeat(reverse: true);
    try {
      final confirmed = await showDialog<bool>(
            context: ctx,
            barrierDismissible: false,
            barrierColor: Colors.red.withOpacity(0.15),
            builder: (dctx) => _buildPulsingDialog(
              GlassAlertDialog(
                title: Row(
                  children: [
                    PhosphorIcon(
                      PhosphorIcons.warning(),
                      color: Colors.redAccent,
                      size: 32,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Final Warning',
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                content: const Text(
                  'This is your final warning.\n\n'
                  'Proceeding may result in permanent hardware damage\n'
                  'and system failure. You will not be able to recover.\n\n'
                  'Click Cancel unless you fully accept this risk.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                ),
                actions: [
                  GlassButton(
                    tint: GlassButtonTint.negative,
                    onPressed: () => Navigator.of(dctx).pop(true),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 60)),
                    child: const Text('Update Now'),
                  ),
                  GlassButton(
                    tint: GlassButtonTint.positive,
                    onPressed: () => Navigator.of(dctx).pop(false),
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 60)),
                    child: const Text('Cancel'),
                  ),
                ],
              ),
            ),
          ) ??
          false;
      return confirmed;
    } finally {
      _pulseController.stop();
    }
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
              child: const Text('Dismiss'),
            ),
            GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: () {
                Navigator.of(context).pop(true);
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(0, 60),
              ),
              child: const Text('Update Now'),
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
    final athenaProvider =
        Provider.of<AthenaUpdateProvider>(ctx, listen: false);
    final isMasterBranch = athenaProvider.channel == 'master';

    bool confirmed = false;

    if (isMasterBranch) {
      // Triple confirmation for development firmware
      if (!await _showDevelopmentFirmwareWarning(ctx)) {
        await _offerResetChannel(ctx);
        return;
      }
      if (!await _showSecondConfirmation(ctx)) {
        await _offerResetChannel(ctx);
        return;
      }
      if (!await _showFinalConfirmation(ctx)) {
        await _offerResetChannel(ctx);
        return;
      }
      confirmed = true;
    } else {
      // Regular confirmation for stable/beta channels
      confirmed = await showDialog<bool>(
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
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(0, 60)),
                  child: const Text('Dismiss'),
                ),
                GlassButton(
                  tint: GlassButtonTint.positive,
                  onPressed: () => Navigator.of(dctx).pop(true),
                  style:
                      ElevatedButton.styleFrom(minimumSize: const Size(0, 60)),
                  child: const Text('Update Now'),
                ),
              ],
            ),
          ) ??
          false;
    }

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
      final backend = BackendService();
      await backend.updateBackend();
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
        padding: EdgeInsets.only(
          left: OrionSpacing.settingsScreenHorizontal,
          right: OrionSpacing.settingsScreenHorizontal,
          top: OrionSpacing.screenTop,
          bottom: OrionSpacing.screenBottomNavClearance,
        ),
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
                            final model =
                                _config.getMachineModelName().toLowerCase();
                            final supportsAthena =
                                _backendService.supportsCapability(
                                    BackendCapabilities.supportsAthena);
                            final supportsAthenaUpdates =
                                _backendService.supportsCapability(
                                    BackendCapabilities.supportsAthenaUpdates);
                            final isAthena =
                                supportsAthena && model.contains('athena');
                            final isMasterBranch = supportsAthenaUpdates &&
                                isAthena &&
                                athenaProvider.channel == 'master';

                            String headerText;
                            if (supportsAthenaUpdates && isAthena) {
                              headerText = isMasterBranch
                                  ? 'AthenaOS Internal'
                                  : 'AthenaOS';
                            } else {
                              headerText = 'Backend';
                            }

                            return Row(
                              children: [
                                PhosphorIcon(
                                  isMasterBranch
                                      ? PhosphorIcons.warning()
                                      : (supportsAthenaUpdates && isAthena
                                          ? PhosphorIconsFill.info
                                          : PhosphorIconsFill.info),
                                  color: isMasterBranch
                                      ? Colors.redAccent
                                      : Theme.of(context).colorScheme.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    headerText,
                                    style: TextStyle(
                                      fontSize: 26,
                                      fontWeight: FontWeight.bold,
                                      color: isMasterBranch
                                          ? Colors.redAccent
                                          : Theme.of(context)
                                              .colorScheme
                                              .primary,
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

  Widget _buildStatusChip({
    required BuildContext context,
    required String label,
    required Color accent,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isGlassTheme = context.watch<ThemeProvider>().isGlassTheme;

    final materialFill = Color.alphaBlend(
      accent.withValues(alpha: isDark ? 0.14 : 0.07),
      theme.colorScheme.surface,
    );

    Widget chipChild = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: accent,
        ),
      ),
    );

    if (!isGlassTheme) {
      return DecoratedBox(
        decoration: BoxDecoration(
          color: materialFill,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: accent.withValues(alpha: 0.22),
            width: 1.2,
          ),
        ),
        child: chipChild,
      );
    }

    final glassFill = Color.alphaBlend(
      accent.withValues(alpha: 0.75),
      Colors.white,
    );

    return GlassEffect(
      borderRadius: BorderRadius.circular(6),
      sigma: glassBlurSigma,
      opacity: GlassPlatformConfig.surfaceOpacity(
        0.12,
        emphasize: true,
      ),
      color: glassFill,
      borderWidth: 1.5,
      borderColor: accent,
      borderAlpha: 0.45,
      useRawBorderAlpha: true,
      emphasizeBorder: true,
      interactiveSurface: false,
      floatingSurface: false,
      child: chipChild,
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
          _buildStatusChip(
            context: context,
            accent: Colors.orangeAccent,
            label: provider.betaUpdatesOverride
                ? (provider.preRelease ? 'BLEEDING EDGE' : 'ROLLBACK')
                : 'UPDATE AVAILABLE',
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
        _buildStatusChip(
          context: context,
          accent: Colors.greenAccent,
          label: 'UP TO DATE',
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
    final model = _config.getMachineModelName().toLowerCase();
    final supportsAthena =
        _backendService.supportsCapability(BackendCapabilities.supportsAthena);
    final supportsAthenaUpdates = _backendService
        .supportsCapability(BackendCapabilities.supportsAthenaUpdates);
    final isAthena = supportsAthena && model.contains('athena');

    if (supportsAthenaUpdates && isAthena) {
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
        final bool isMasterBranch = ap.channel == 'master';
        final bool isSameVersion = ap.latestVersion.isNotEmpty &&
            ap.currentVersion.isNotEmpty &&
            ap.latestVersion == ap.currentVersion;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatusChip(
              context: context,
              accent: (isMasterBranch || (isBetaChannel && isSameVersion))
                  ? Colors.redAccent
                  : Colors.orangeAccent,
              label: isMasterBranch
                  ? 'INTERNAL BUILD'
                  : (isBetaChannel && isSameVersion
                      ? 'BETA VERSION'
                      : 'UPDATE AVAILABLE'),
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
                tint: isMasterBranch
                    ? GlassButtonTint.negative
                    : (isBetaChannel && isSameVersion
                        ? GlassButtonTint.negative
                        : GlassButtonTint.positive),
                onPressed: () async {
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
                      isMasterBranch
                          ? 'Update Internal Build'
                          : (isBetaChannel && isSameVersion
                              ? 'Force Update'
                              : 'Update AthenaOS'),
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
            _buildStatusChip(
              context: context,
              accent: Colors.greenAccent,
              label: 'UP TO DATE',
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
