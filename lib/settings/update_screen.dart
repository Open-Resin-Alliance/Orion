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

import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/orion_update_provider.dart';
import 'package:orion/util/providers/athena_update_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/settings/update_progress.dart';
import 'package:orion/pubspec.dart';
import 'package:orion/util/markdown_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/safe_set_state_mixin.dart';
import 'package:orion/backend_service/nanodlp/nanodlp_http_client.dart';

class UpdateScreen extends StatefulWidget {
  const UpdateScreen({super.key});

  @override
  UpdateScreenState createState() => UpdateScreenState();
}

class UpdateScreenState extends State<UpdateScreen> with SafeSetStateMixin {
  bool _isLoading = true;
  bool _isUpdateAvailable = false;
  bool _isFirmwareSpoofingEnabled = false;
  bool _betaUpdatesOverride = false;
  bool _rateLimitExceeded = false;
  bool _preRelease = false;

  String _latestVersion = '';
  String _commitDate = '';
  String _releaseDate = '';
  String _releaseNotes = '';
  String _currentVersion = '';
  String _release = 'BRANCH_dev';
  String _assetUrl = '';
  String _repo = 'Open-Resin-Alliance';

  final Logger _logger = Logger('UpdateScreen');
  final OrionConfig _config = OrionConfig();
  final AthenaUpdateProvider _athenaUpdateProvider = AthenaUpdateProvider();
  // Update dialog state is handled by OrionUpdateProvider

  @override
  void initState() {
    super.initState();
    _initUpdateCheck();
    // Start Athena update provider checks if applicable
    _athenaUpdateProvider.addListener(() {
      if (mounted) setState(() {});
    });
    _athenaUpdateProvider.checkForUpdates();
    _isFirmwareSpoofingEnabled =
        _config.getFlag('overrideUpdateCheck', category: 'developer');
    _betaUpdatesOverride =
        _config.getFlag('releaseOverride', category: 'developer');
    _release = _config.getString('overrideRelease', category: 'developer');
    final repoOverride =
        _config.getString('overrideRepo', category: 'developer');
    _repo = repoOverride.trim().isNotEmpty
        ? repoOverride.trim()
        : 'Open-Resin-Alliance';
    _logger.info('Firmware spoofing enabled: $_isFirmwareSpoofingEnabled');
    _logger.info('Beta updates override enabled: $_betaUpdatesOverride');
    _logger.info('Release channel override: $_release');
    _logger.info('Repo: $_repo');
  }

  Future<void> _initUpdateCheck() async {
    await _getCurrentAppVersion();
    await _checkForUpdates(_release);
  }

  Future<void> _getCurrentAppVersion() async {
    try {
      safeSetState(() {
        _currentVersion = Pubspec.versionFull;
        _logger.info('Current version: $_currentVersion');
      });
    } catch (e) {
      _logger.warning('Failed to get current app version');
    }
  }

  Future<void> _checkForUpdates(String release) async {
    if (_isFirmwareSpoofingEnabled) {
      // Force update: always allow install, skip version check
      // Respect branch override: fetch releases for the selected branch
      if (release.isNotEmpty && release != 'BRANCH_dev') {
        await _checkForBERUpdates(release);
        return;
      }
      final String url =
          'https://api.github.com/repos/$_repo/orion/releases/latest';
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body);
          final String latestVersion =
              jsonResponse['tag_name'].replaceAll('v', '');
          final String releaseNotes = jsonResponse['body'];
          final String releaseDate = jsonResponse['published_at'];
          // Find the asset URL for orion_armv7.tar.gz
          final asset = jsonResponse['assets'].firstWhere(
              (asset) => asset['name'] == 'orion_armv7.tar.gz',
              orElse: () => null);
          final String assetUrl =
              asset != null ? asset['browser_download_url'] : '';
          safeSetState(() {
            _latestVersion = latestVersion;
            _releaseNotes = releaseNotes;
            _releaseDate = releaseDate;
            _isLoading = false;
            _isUpdateAvailable = true;
            _assetUrl = assetUrl;
          });
        } else {
          safeSetState(() {
            _logger.warning('Failed to fetch updates');
            _isLoading = false;
          });
        }
      } catch (e) {
        _logger.warning(e.toString());
        safeSetState(() {
          _isLoading = false;
        });
      }
      return;
    }
    if (_betaUpdatesOverride) {
      await _checkForBERUpdates(release);
    } else {
      final String url =
          'https://api.github.com/repos/$_repo/orion/releases/latest';
      int retryCount = 0;
      const int maxRetries = 3;
      const int initialDelay = 750;
      while (retryCount < maxRetries) {
        try {
          final response = await http.get(Uri.parse(url));
          if (response.statusCode == 200) {
            final jsonResponse = json.decode(response.body);
            final String latestVersion = jsonResponse['tag_name']
                .replaceAll('v', ''); // Remove 'v' prefix if present
            final String releaseNotes = jsonResponse['body'];
            final String releaseDate = jsonResponse['published_at'];
            _logger.info('Latest version: $latestVersion');
            if (_isNewerVersion(latestVersion, _currentVersion)) {
              // Find the asset URL for orion_armv7.tar.gz
              final asset = jsonResponse['assets'].firstWhere(
                  (asset) => asset['name'] == 'orion_armv7.tar.gz',
                  orElse: () => null);
              final String assetUrl =
                  asset != null ? asset['browser_download_url'] : '';
              safeSetState(() {
                _latestVersion = latestVersion;
                _releaseNotes = releaseNotes;
                _releaseDate = releaseDate;
                _isLoading = false;
                _isUpdateAvailable = true;
                _assetUrl = assetUrl; // Set the asset URL
              });
            } else {
              safeSetState(() {
                _isLoading = false;
                _isUpdateAvailable = false;
              });
            }
            return; // Exit the function after successful fetch
          } else if (response.statusCode == 403 &&
              response.headers['x-ratelimit-remaining'] == '0') {
            _logger.warning('Rate limit exceeded, retrying...');
            safeSetState(() {
              _rateLimitExceeded = true;
            });
            await Future.delayed(Duration(
                milliseconds: initialDelay * pow(2, retryCount).toInt()));
            retryCount++;
          } else {
            safeSetState(() {
              _logger.warning('Failed to fetch updates');
              _isLoading = false;
            });
            return; // Exit the function after failure
          }
        } catch (e) {
          _logger.warning(e.toString());
          safeSetState(() {
            _isLoading = false;
          });
          return; // Exit the function after failure
        }
      }
    }
  }

  bool isCurrentCommitUpToDate(String commitSha) {
    final parts = _currentVersion.split('+');
    final currentCommit = parts.length > 1 ? parts[1] : '';
    _logger.info('Current commit SHA: $currentCommit');
    _logger.info('Latest commit SHA: $commitSha');
    if (_isFirmwareSpoofingEnabled) return false;
    return commitSha == currentCommit;
  }

  Future<void> _checkForBERUpdates(String release) async {
    if (release.isEmpty) {
      _logger.warning('release name is empty');
      release = 'BRANCH_dev';
    }
    String url = 'https://api.github.com/repos/$_repo/orion/releases';
    int retryCount = 0;
    const int maxRetries = 3;
    const int initialDelay = 750; // Initial delay in milliseconds
    while (retryCount < maxRetries) {
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final jsonResponse = json.decode(response.body) as List;
          final releaseItem = jsonResponse.firstWhere(
              (releaseItem) => releaseItem['tag_name'] == release,
              orElse: () => null);

          if (releaseItem != null) {
            final String latestVersion = releaseItem['tag_name'];
            final String commitSha = releaseItem['target_commitish'];
            final commitUrl =
                'https://api.github.com/repos/$_repo/orion/commits/$commitSha';
            final commitResponse = await http.get(Uri.parse(commitUrl));
            if (commitResponse.statusCode == 200) {
              final commitJson = json.decode(commitResponse.body);
              final String shortCommitSha =
                  commitJson['sha'].substring(0, 7); // Get short commit SHA
              final String commitMessage = commitJson['commit']['message'];
              final String commitDate = commitJson['commit']['committer']
                  ['date']; // Fetch commit date

              if (_isFirmwareSpoofingEnabled) {
                // Force update: always allow install, skip version check
                _logger.info('Force update enabled, skipping version check.');
              } else if (isCurrentCommitUpToDate(shortCommitSha)) {
                _logger.info(
                    'Current version is up-to-date with the latest pre-release.');
                safeSetState(() {
                  _isLoading = false;
                  _isUpdateAvailable = false;
                  _rateLimitExceeded = false;
                });
                return; // Exit the function if the current version is up-to-date
              }

              // Find the asset URL for orion_armv7.tar.gz
              final asset = releaseItem['assets'].firstWhere(
                  (asset) => asset['name'] == 'orion_armv7.tar.gz',
                  orElse: () => null);
              final String assetUrl =
                  asset != null ? asset['browser_download_url'] : '';
              _logger.info('Latest pre-release version: $latestVersion');
              final bool preRelease = releaseItem['prerelease'];
              _logger.info('Pre-release: $preRelease');
              safeSetState(() {
                _latestVersion =
                    '$shortCommitSha ($release)'; // Append release name
                _releaseNotes =
                    preRelease ? commitMessage : releaseItem['body'];
                _commitDate = commitDate; // Store commit date
                _isLoading = false;
                _isUpdateAvailable = true;
                _rateLimitExceeded = false;
                _assetUrl = assetUrl; // Set the asset URL
                _preRelease = preRelease;
              });
              return; // Exit the function after successful fetch
            } else {
              _logger.warning(
                  'Failed to fetch commit details, status code: ${commitResponse.statusCode}');
              safeSetState(() {
                _isLoading = false;
                _rateLimitExceeded = false;
              });
              return; // Exit the function after failure
            }
          } else {
            _logger.warning('No release found named $release');
            safeSetState(() {
              _isLoading = false;
              _rateLimitExceeded = false;
            });
            return; // Exit the function after no pre-release found
          }
        } else if (response.statusCode == 403 &&
            response.headers['x-ratelimit-remaining'] == '0') {
          _logger.warning('Rate limit exceeded, retrying...');
          safeSetState(() {
            _rateLimitExceeded = true;
          });
          await Future.delayed(Duration(
              milliseconds: initialDelay * pow(2, retryCount).toInt()));
          retryCount++;
        } else {
          _logger.warning(
              'Failed to fetch updates, status code: ${response.statusCode}');
          safeSetState(() {
            _isLoading = false;
            _rateLimitExceeded = false;
          });
          return; // Exit the function after failure
        }
      } catch (e) {
        _logger.warning(e.toString());
        safeSetState(() {
          _isLoading = false;
          _rateLimitExceeded = false;
        });

        return; // Exit the function after failure
      }
    }
  }

  bool _isNewerVersion(String latestVersion, String currentVersion) {
    _logger.info('Firmware spoofing enabled: $_isFirmwareSpoofingEnabled');
    if (_isFirmwareSpoofingEnabled) return true;

    // Split the version and build numbers
    List<String> latestVersionParts = latestVersion.split('+')[0].split('.');
    List<String> currentVersionParts = currentVersion.split('+')[0].split('.');

    // Convert version parts to integers for comparison
    List<int> latestNumbers = latestVersionParts.map(int.parse).toList();
    List<int> currentNumbers = currentVersionParts.map(int.parse).toList();

    // Compare major, minor, and patch numbers
    for (int i = 0; i < min(latestNumbers.length, currentNumbers.length); i++) {
      if (latestNumbers[i] > currentNumbers[i]) {
        return true;
      } else if (latestNumbers[i] < currentNumbers[i]) {
        return false;
      }
    }

    if (latestVersion.contains('+') && currentVersion.contains('+')) {
      String latestBuild = latestVersion;
      String currentBuild = currentVersion.split('+')[1];
      // Attempt to compare build numbers as integers if possible
      try {
        int latestBuildNumber = int.parse(latestBuild);
        int currentBuildNumber = int.parse(currentBuild);
        return latestBuildNumber > currentBuildNumber;
      } catch (e) {
        // If build numbers are not integers, compare them as strings
        return latestBuild.compareTo(currentBuild) > 0;
      }
    }

    // Versions are equal and no build number to compare
    return false;
  }

  void _viewChangelog() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MarkdownScreen(changelog: _releaseNotes),
      ),
    );
  }

  Future<void> launchUpdateDialog() async {
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
      final provider = Provider.of<OrionUpdateProvider>(context, listen: false);
      await provider.performUpdate(context, _assetUrl);
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        children: [
                          _betaUpdatesOverride
                              ? _preRelease
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
                                  : PhosphorIcon(
                                      PhosphorIcons.arrowCounterClockwise(),
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      size: 24)
                              : PhosphorIcon(PhosphorIconsFill.info,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 24),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Orion HMI',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
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
                        child: _buildOrionContent(),
                      ),
                    ],
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Builder(builder: (ctx) {
                        final cfg = _config;
                        final isNano = cfg.isNanoDlpMode();
                        final model = cfg.getMachineModelName().toLowerCase();
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
                                  color: Theme.of(context).colorScheme.primary,
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
                        child: _buildBackendContent(),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrionContent() {
    if (_rateLimitExceeded) {
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

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_isUpdateAvailable) {
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
              _betaUpdatesOverride
                  ? (_preRelease ? 'BLEEDING EDGE' : 'ROLLBACK')
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
            _betaUpdatesOverride
                ? 'Latest: $_latestVersion'
                : (_latestVersion.contains('+')
                    ? 'Version ${_latestVersion.split('+')[0]}'
                    : 'Version $_latestVersion'),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            _betaUpdatesOverride
                ? (_commitDate.contains('T')
                    ? 'Committed ${_commitDate.split('T')[0]}'
                    : 'Committed $_commitDate')
                : (_releaseDate.contains('T')
                    ? 'Released ${_releaseDate.split('T')[0]}'
                    : 'Released $_releaseDate'),
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
                  onPressed: _viewChangelog,
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
                  onPressed: launchUpdateDialog,
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
          _betaUpdatesOverride
              ? '$_currentVersion ($_release)'
              : 'Version ${_currentVersion.split('+')[0]}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 6),
        Text(
          _betaUpdatesOverride
              ? 'Running latest bleeding edge build'
              : 'Running latest stable release',
          style: const TextStyle(fontSize: 18, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildBackendContent() {
    final cfg = _config;
    final isNano = cfg.isNanoDlpMode();
    final model = cfg.getMachineModelName().toLowerCase();
    final isAthena = model.contains('athena');

    if (isNano && isAthena) {
      final ap = _athenaUpdateProvider;

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
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                    color: Colors.orangeAccent.withValues(alpha: 0.5)),
              ),
              child: const Text(
                'UPDATE AVAILABLE',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.orangeAccent,
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
                tint: GlassButtonTint.positive,
                onPressed: () async {
                  await _triggerAthenaUpdate(context);
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(65),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.system_update_alt, size: 24),
                    SizedBox(width: 20),
                    Text('Update AthenaOS', style: TextStyle(fontSize: 20)),
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
  // Update flow is handled by OrionUpdateProvider via
  // `Provider.of<OrionUpdateProvider>(context, listen: false).performUpdate(...)`.
