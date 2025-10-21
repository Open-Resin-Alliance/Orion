/*
* Orion - Orion Update Provider
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

import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:orion/settings/update_progress.dart';

/// Provider that encapsulates the Orion update flow.
///
/// Exposes [progress] and [message] ValueNotifiers that the UI can listen to
/// and a single [performUpdate] method to run the update flow. The provider
/// will show a modal update overlay while an update is in progress.

class OrionUpdateProvider extends ChangeNotifier {
  final Logger _logger = Logger('OrionUpdateProvider');

  final ValueNotifier<double> progress = ValueNotifier<double>(0.0);
  final ValueNotifier<String> message = ValueNotifier<String>('');
  bool _isDialogOpen = false;

  void _openUpdateDialog(BuildContext context, String initialMessage) {
    message.value = initialMessage;
    if (_isDialogOpen) return;
    _isDialogOpen = true;
    progress.value = 0.0;

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        return UpdateProgressOverlay(
          progress: progress,
          message: message,
          icon: PhosphorIcons.warningDiamond(),
        );
      },
    ).then((_) {
      _isDialogOpen = false;
      progress.value = 0.0;
      message.value = '';
    });
  }

  /// Locate the Orion installation root. Public for testing.
  String findOrionRoot() {
    final String localUser = Platform.environment['USER'] ?? 'pi';
    final String envRoot = Platform.environment['ORION_ROOT'] ?? '';
    if (envRoot.isNotEmpty) return envRoot;

    // Check current working directory and its ancestors first (pwd)
    try {
      Directory dir = Directory.current;
      while (true) {
        final candidate = dir.path;
        if (File('$candidate/orion.cfg').existsSync() ||
            Directory('$candidate/orion').existsSync() ||
            candidate.endsWith('/orion')) {
          return candidate;
        }
        if (dir.parent.path == dir.path) break;
        dir = dir.parent;
      }
    } catch (_) {}

    // Check ancestors of the running executable (helps packaged installs)
    try {
      final exe = Platform.resolvedExecutable;
      final exeDir = Directory(exe).parent;
      Directory dir = exeDir;
      while (true) {
        final candidate = dir.path;
        if (File('$candidate/orion.cfg').existsSync() ||
            Directory('$candidate/orion').existsSync() ||
            candidate.endsWith('/orion')) {
          return candidate;
        }
        if (dir.parent.path == dir.path) break; // reached root
        dir = dir.parent;
      }
    } catch (_) {
      // ignore
    }

    // Check a few common locations without preferring any single one
    final candidates = [
      '/usr/local/share/orion',
      '/usr/share/orion',
      '/var/lib/orion',
      '/opt/orion',
      '${Platform.environment['HOME'] ?? '/home/$localUser'}/orion'
    ];
    for (final c in candidates) {
      try {
        if (Directory(c).existsSync() || File('$c/orion.cfg').existsSync()) {
          return c;
        }
      } catch (_) {}
    }

    // Last resort: user's home
    return '${Platform.environment['HOME'] ?? '/home/$localUser'}/orion';
  }

  void _dismissUpdateDialog(BuildContext context) {
    if (_isDialogOpen && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      _isDialogOpen = false;
      progress.value = 0.0;
      message.value = '';
    }
  }

  void _updateProgressAndText(String msg, {double step = 0.25}) {
    message.value = msg;
    if (_isDialogOpen) {
      progress.value = min(1.0, progress.value + step);
    }
  }

  Future<void> performUpdate(BuildContext context, String assetUrl) async {
    final String localUser = Platform.environment['USER'] ?? 'pi';

    final String orionRoot = findOrionRoot();

    // Use a temp upgrade workspace to download & extract; this avoids
    // writing into system install directories directly and is safer when
    // the install root is read-only.
    final tempDir = await Directory.systemTemp.createTemp('orion_upgrade_');
    final String upgradeFolder = '${tempDir.path}/';
    final String downloadPath = '$upgradeFolder/orion_armv7.tar.gz';
    final String orionFolder =
        orionRoot.endsWith('/') ? orionRoot : '$orionRoot/';
    final String newOrionFolder = '${upgradeFolder}orion_new/';
    final String backupFolder = '${upgradeFolder}orion_backup/';
    final String scriptPath = '$upgradeFolder/update_orion.sh';

    if (assetUrl.isEmpty) {
      _logger.warning('Asset URL is empty');
      return;
    }

    _logger.info('Downloading from $assetUrl');

    // macOS dev simulation
    if (Platform.isMacOS) {
      _openUpdateDialog(context, 'Starting update...');
      final simSteps = [
        'Downloading update file...',
        'Extracting update file...',
        'Executing update script...',
        'Finalizing update...'
      ];

      final int remaining = simSteps.length - 1;
      final double perStep = remaining > 0 ? (1.0 / remaining) : 1.0;

      for (var i = 0; i < simSteps.length; i++) {
        final m = simSteps[i];
        final step = i == 0 ? 0.0 : perStep;
        _updateProgressAndText(m, step: step);
        await Future.delayed(const Duration(seconds: 3));
      }

      progress.value = 1.0;
      await Future.delayed(const Duration(seconds: 1));
      _dismissUpdateDialog(context);
      return;
    }

    // Normal flow: open dialog and perform streamed download, extract and run
    _openUpdateDialog(context, 'Starting update...');

    try {
      final upgradeDir = Directory(upgradeFolder);
      if (await upgradeDir.exists()) {
        try {
          await upgradeDir.delete(recursive: true);
        } catch (e) {
          _logger.warning('Could not purge upgrade directory');
        }
      }
      await upgradeDir.create(recursive: true);

      final newDir = Directory(newOrionFolder);
      if (await newDir.exists()) {
        try {
          await newDir.delete(recursive: true);
        } catch (e) {
          _logger.warning('Could not purge new Orion directory');
        }
      }
      await newDir.create(recursive: true);

      _updateProgressAndText('Downloading update file...', step: 0.0);
      await Future.delayed(const Duration(seconds: 1));

      final client = http.Client();
      try {
        final req = http.Request('GET', Uri.parse(assetUrl));
        final streamedResp = await client.send(req);
        if (streamedResp.statusCode == 200) {
          final int contentLength = streamedResp.contentLength ?? -1;
          final file = File(downloadPath);
          final sink = file.openWrite();
          int bytesReceived = 0;

          if (contentLength > 0) {
            message.value = 'Downloading update file...';
            progress.value = 0.0;
            await for (final chunk in streamedResp.stream) {
              sink.add(chunk);
              bytesReceived += chunk.length;
              final double raw = bytesReceived / contentLength;
              progress.value = min(1.0, raw * 0.25);
            }
          } else {
            message.value = 'Downloading update file...';
            await for (final chunk in streamedResp.stream) {
              sink.add(chunk);
            }
          }

          await sink.flush();
          await sink.close();

          progress.value = max(progress.value, 0.25);

          _updateProgressAndText('Extracting update file...', step: 0.25);
          await Future.delayed(const Duration(seconds: 1));
        } else {
          _logger.warning(
              'Failed to download update file, status: ${streamedResp.statusCode}');
        }
      } finally {
        client.close();
      }

      final extractResult = await Process.run('sudo',
          ['tar', '--overwrite', '-xzf', downloadPath, '-C', newOrionFolder]);
      if (extractResult.exitCode != 0) {
        _logger
            .warning('Failed to extract update file: ${extractResult.stderr}');
        _dismissUpdateDialog(context);
        return;
      }

      final scriptContent = '''
#!/bin/bash

# Variables
local_user=$localUser
orion_folder=$orionFolder
new_orion_folder=$newOrionFolder
upgrade_folder=$upgradeFolder
backup_folder=$backupFolder

# If previous backup exists, delete it
if [ -d \$backup_folder ]; then
  sudo rm -R \$backup_folder
fi

# Backup the current Orion directory
sudo cp -R \$orion_folder \$backup_folder

# Remove the old Orion directory
sudo rm -R \$orion_folder

# Restore config file
sudo cp \$backup_folder/orion.cfg \$new_orion_folder

# Move the new Orion directory to the original location
sudo mv \$new_orion_folder \$orion_folder

# Delete the upgrade and new folder
sudo rm -R \$upgrade_folder

# Fix permissions
sudo chown -R \$local_user:\$local_user \$orion_folder

# Restart the Orion service
sudo systemctl restart orion.service
''';

      final scriptFile = File(scriptPath);
      await scriptFile.writeAsString(scriptContent);
      await Process.run('chmod', ['+x', scriptPath]);

      _updateProgressAndText('Executing update script...', step: 0.25);

      // Mark complete after executing script
      progress.value = 1.0;
      await Future.delayed(const Duration(seconds: 2));

      final result = await Process.run('nohup', ['sudo', scriptPath]);
      if (result.exitCode == 0) {
        _logger.info('Update script executed successfully');
      } else {
        _logger.warning('Failed to execute update script: ${result.stderr}');
      }
    } catch (e) {
      _logger.warning('Update failed: $e');
    } finally {
      _dismissUpdateDialog(context);
    }
  }
}
