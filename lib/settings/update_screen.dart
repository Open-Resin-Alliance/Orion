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

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/orion_update_provider.dart';

import 'package:orion/glasser/glasser.dart';
import 'package:orion/pubspec.dart';
import 'package:orion/util/markdown_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/util/safe_set_state_mixin.dart';

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
  // Update dialog state is handled by OrionUpdateProvider

  @override
  void initState() {
    super.initState();
    _initUpdateCheck();
    _isFirmwareSpoofingEnabled =
        _config.getFlag('overrideUpdateCheck', category: 'developer');
    _betaUpdatesOverride =
        _config.getFlag('releaseOverride', category: 'developer');
    _release = _config.getString('overrideRelease', category: 'developer');
    _repo = _config.getString('overrideRepo', category: 'developer');
    _logger.info('Firmware spoofing enabled: $_isFirmwareSpoofingEnabled');
    _logger.info('Beta updates override enabled: $_betaUpdatesOverride');
    _logger.info('Release channel override: $_release');
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
    _logger.info('Current commit SHA: ${_currentVersion.split('+')[1]}');
    _logger.info('Latest commit SHA: $commitSha');
    if (_isFirmwareSpoofingEnabled) return false;
    return commitSha == _currentVersion.split('+')[1];
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.only(
            left: 16.0, right: 16.0, bottom: 16.0, top: 5.0),
        children: [
          GlassCard(
            outlined: true,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_rateLimitExceeded) ...[
                    const Row(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 30),
                        SizedBox(width: 10),
                        Text('Rate Limit Exceeded!',
                            style: TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    const Text('Please try again later.',
                        style: TextStyle(fontSize: 20)),
                  ] else if (_isLoading) ...[
                    const Center(child: CircularProgressIndicator()),
                  ] else if (_isUpdateAvailable) ...[
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
                                        size: 30,
                                      ),
                                      const Positioned(
                                        top: 0,
                                        right: 0,
                                        child: PhosphorIcon(
                                          PhosphorIconsDuotone.knife,
                                          color: Colors.redAccent,
                                          size: 24,
                                        ),
                                      ),
                                      const Positioned(
                                        bottom: 0,
                                        left: 3,
                                        child: PhosphorIcon(
                                          PhosphorIconsFill.dropSimple,
                                          color: Colors.redAccent,
                                          size: 10,
                                        ),
                                      ),
                                    ],
                                  )
                                : PhosphorIcon(
                                    PhosphorIcons.arrowCounterClockwise(),
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 30)
                            : Icon(Icons.system_update,
                                color: Theme.of(context).colorScheme.primary,
                                size: 30),
                        const SizedBox(width: 10),
                        Text(
                          _betaUpdatesOverride
                              ? _preRelease
                                  ? 'Bleeding Edge Available!'
                                  : 'Rollback Available!'
                              : 'UI Update Available!',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const Divider(),
                    Text(
                        _betaUpdatesOverride
                            ? _preRelease
                                ? 'Latest Commit: $_latestVersion'
                                : 'Rollback to: ${_latestVersion.split('(')[1].split(')')[0]}'
                            : 'Latest Version: ${_latestVersion.split('+')[0]}',
                        style: const TextStyle(fontSize: 22)),
                    const SizedBox(height: 10),
                    Text(
                      _betaUpdatesOverride
                          ? 'Commit Date: ${_commitDate.split('T')[0]}' // Display commit date if beta updates are enabled
                          : 'Release Date: ${_releaseDate.split('T')[0]}',
                      style: const TextStyle(fontSize: 20, color: Colors.grey),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: GlassButton(
                            tint: GlassButtonTint.neutral,
                            onPressed: _viewChangelog,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(65),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.article, size: 30),
                                const Expanded(
                                  child: AutoSizeText(
                                    'View Changelog',
                                    style: TextStyle(fontSize: 22),
                                    minFontSize: 22,
                                    maxLines: 1,
                                    overflowReplacement: Padding(
                                      padding: EdgeInsets.only(right: 20.0),
                                      child: Center(
                                        child: AutoSizeText(
                                          'Changes',
                                          style: TextStyle(fontSize: 22),
                                          maxLines: 1,
                                        ),
                                      ),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(
                            width: 12), // Add some space between the buttons
                        Expanded(
                          child: GlassButton(
                            tint: GlassButtonTint.positive,
                            onPressed: () async {
                              launchUpdateDialog();
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(65),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.download, size: 30),
                                const Expanded(
                                  child: AutoSizeText(
                                    'Download Update',
                                    style: TextStyle(fontSize: 24),
                                    minFontSize: 22,
                                    maxLines: 1,
                                    overflowReplacement: Padding(
                                      padding: EdgeInsets.only(right: 20.0),
                                      child: Center(
                                        child: Text(
                                          'Update',
                                          style: TextStyle(fontSize: 22),
                                        ),
                                      ),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Row(
                      children: [
                        const Icon(Icons.check_circle,
                            color: Colors.green, size: 30),
                        const SizedBox(width: 10),
                        Text(
                            _betaUpdatesOverride
                                ? 'Bleeding Edge is up to date!'
                                : 'Orion is up to date!',
                            style: const TextStyle(
                                fontSize: 26, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const Divider(),
                    Text(
                        _betaUpdatesOverride
                            ? 'Current Version: $_currentVersion ($_release)'
                            : 'Current Version: ${_currentVersion.split('+')[0]}',
                        style: const TextStyle(fontSize: 20)),
                  ],
                ],
              ),
            ),
          ),
          // TODO: Placeholder for Backend / OS updater - pending API changes
          GlassCard(
            outlined: true,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      PhosphorIcon(PhosphorIconsFill.info,
                          color: Theme.of(context).colorScheme.primary,
                          size: 30),
                      const SizedBox(width: 10),
                      const Text(
                        'Backend Updater',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const Divider(),
                  // Dummy content, replace with actual data when available
                  const Text('Coming Soon!', style: TextStyle(fontSize: 20)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
  // Update flow is handled by OrionUpdateProvider via
  // `Provider.of<OrionUpdateProvider>(context, listen: false).performUpdate(...)`.
