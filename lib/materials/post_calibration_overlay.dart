/*
* Orion - Post Calibration Overlay
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
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:provider/provider.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/materials/materials_screen.dart';
import 'package:orion/util/orion_config.dart';
import 'package:orion/backend_service/nanodlp/models/nano_profiles.dart';
import 'package:qr_flutter/qr_flutter.dart';

/// Overlay shown after a calibration print completes
/// Guides user through evaluation and saving optimal exposure settings
class PostCalibrationOverlay extends StatefulWidget {
  final String calibrationModelName;
  final String? resinProfileName;
  final double startExposure;
  final double exposureIncrement;
  final int profileId;
  final int calibrationModelId;
  final String? evaluationGuideUrl;
  final VoidCallback onComplete;

  const PostCalibrationOverlay({
    super.key,
    required this.calibrationModelName,
    this.resinProfileName,
    required this.startExposure,
    required this.exposureIncrement,
    required this.profileId,
    required this.calibrationModelId,
    this.evaluationGuideUrl,
    required this.onComplete,
  });

  @override
  State<PostCalibrationOverlay> createState() => _PostCalibrationOverlayState();
}

class _PostCalibrationOverlayState extends State<PostCalibrationOverlay> {
  final _logger = Logger('PostCalibrationOverlay');
  final _backendService = BackendService();
  final _config = OrionConfig();
  int _currentStep = 0; // 0 = QR code, 1 = evaluation
  // Allow up to two selected pieces for fine-tuning
  final List<int> _selectedPieces = [];
  bool _doNotShowAgain = false;

  @override
  void initState() {
    super.initState();
    try {
      _doNotShowAgain = _config.getFlag(
        'skip_calibration_${widget.calibrationModelId}',
        category: 'calibration',
      );
      // If user previously opted to skip the guide for this model, go
      // straight to the evaluation step.
      if (_doNotShowAgain) {
        _currentStep = 1;
      }
    } catch (e) {
      _logger.fine('Failed to read skip flag: $e');
      _doNotShowAgain = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _currentStep == 0
                    ? PhosphorIcons.checkCircle()
                    : PhosphorIconsFill.magnifyingGlass,
                size: 36,
                color: _currentStep == 0
                    ? Colors.greenAccent
                    : Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _currentStep == 0
                        ? 'Calibration Complete!'
                        : 'Evaluate Test Print',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeInOut,
            switchOutCurve: Curves.easeInOut,
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0.1, 0),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child:
                _currentStep == 0 ? _buildQrCodeView() : _buildEvaluationView(),
          ),
        ),
        floatingActionButton: _buildFloatingActionButtons(),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      ),
    );
  }

  Widget _buildFloatingActionButtons() {
    if (_currentStep == 0) {
      // QR code screen: only show next button
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Left: Do Not Show Again toggle
            GlassFloatingActionButton.extended(
              heroTag: 'do_not_show',
              onPressed: () {
                // Toggle and persist; if enabling skip, immediately show
                // the evaluation screen so user doesn't have to press
                // Next.
                final newValue = !_doNotShowAgain;
                try {
                  _config.setFlag(
                    'skip_calibration_${widget.calibrationModelId}',
                    newValue,
                    category: 'calibration',
                  );
                } catch (e) {
                  _logger.warning('Failed to persist skip flag: $e');
                }
                setState(() {
                  _doNotShowAgain = newValue;
                  if (_doNotShowAgain) _currentStep = 1;
                });
              },
              label: 'Skip Guide',
              icon: Icon(_doNotShowAgain
                  ? PhosphorIcons.checkSquare()
                  : PhosphorIcons.square()),
              scale: 1.3,
              iconAfterLabel: false,
            ),
            GlassFloatingActionButton.extended(
              tint: GlassButtonTint.positive,
              heroTag: 'next',
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              label: 'Next',
              icon: Icon(PhosphorIcons.caretRight()),
              scale: 1.3,
              iconAfterLabel: true,
            ),
          ],
        ),
      );
    } else {
      // Evaluation screen: back, reconfigure, and save buttons
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GlassFloatingActionButton.extended(
              tint: GlassButtonTint.neutral,
              heroTag: 'back',
              onPressed: () {
                // If the guide was skipped by default, this button acts as
                // a direct link to the guide. Otherwise it behaves as a
                // regular Back button to return to the QR guide screen.
                setState(() {
                  _currentStep = 0;
                });
              },
              label: _doNotShowAgain ? 'Guide' : 'Back',
              icon: Icon(_doNotShowAgain
                  ? PhosphorIcons.info()
                  : PhosphorIcons.caretLeft()),
              scale: 1.3,
              iconAfterLabel: false,
            ),
            const SizedBox(width: 12),
            GlassFloatingActionButton.extended(
              tint: GlassButtonTint.negative,
              heroTag: 'reconfigure',
              onPressed: () {
                // Pop overlay and navigate to MaterialsScreen on the Calibration tab
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) =>
                        const MaterialsScreen(initialIndex: 2),
                  ),
                );
              },
              label: 'Reconfigure',
              icon: Icon(PhosphorIconsFill.arrowCounterClockwise),
              scale: 1.3,
              iconAfterLabel: false,
            ),
            const Spacer(),
            // When two pieces are selected allow fine-tuning between them.
            if (_selectedPieces.length == 2)
              GlassFloatingActionButton.extended(
                tint: GlassButtonTint.positive,
                heroTag: 'fine_tune',
                onPressed: () {
                  _showFineTuneDialog();
                },
                label: 'Fine-Tune',
                icon: Icon(PhosphorIcons.slidersHorizontal()),
                scale: 1.3,
                iconAfterLabel: true,
              )
            else
              GlassFloatingActionButton.extended(
                tint: GlassButtonTint.positive,
                heroTag: 'save',
                onPressed: _selectedPieces.length != 1
                    ? null
                    : () {
                        _saveOptimalExposure();
                      },
                label: 'Save',
                icon: Icon(PhosphorIcons.check()),
                scale: 1.3,
                iconAfterLabel: true,
              ),
          ],
        ),
      );
    }
  }

  Widget _buildQrCodeView() {
    // Hardcoded evaluation guide URLs for NanoDLP calibration models
    // TODO: Make these configurable via backend when support is added
    String evaluationGuideUrl;
    switch (widget.calibrationModelId) {
      case 1:
        evaluationGuideUrl =
            'https://docs.google.com/document/d/1aoMSE6GBGMcoYXNGfPP9s_Jg8vr1wQmmZuvqP3suago/edit?tab=t.0#heading=h.bvm0ca3vxmwr';
        break;
      case 2:
        evaluationGuideUrl =
            'https://docs.google.com/document/d/1aoMSE6GBGMcoYXNGfPP9s_Jg8vr1wQmmZuvqP3suago/edit?tab=t.0#heading=h.bj4wz2wzngny';
        break;
      default:
        // Fallback URL if calibration model ID is unknown
        evaluationGuideUrl = widget.evaluationGuideUrl ??
            'https://docs.openresin.org/calibration/${widget.calibrationModelName.toLowerCase().replaceAll(' ', '-')}';
    }

    return Padding(
      key: const ValueKey('qr'),
      padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Scan the QR code for the ${widget.calibrationModelName} evaluation guide.',
                style: const TextStyle(
                  fontSize: 21,
                  color: Colors.white70,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Center(
                child: GlassCard(
                  elevation: 1.0,
                  outlined: true,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: QrImageView(
                      data: evaluationGuideUrl,
                      version: QrVersions.auto,
                      size: 260,
                      gapless: true,
                      errorCorrectionLevel: QrErrorCorrectLevel.M,
                      eyeStyle: QrEyeStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      dataModuleStyle: QrDataModuleStyle(
                        color: Theme.of(context).colorScheme.onSurface,
                        dataModuleShape: QrDataModuleShape.circle,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildEvaluationView() {
    return Padding(
      key: const ValueKey('evaluation'),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // 3x2 Grid
          Expanded(
            child: Center(
              child: GridView.builder(
                shrinkWrap: true,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 2.2,
                ),
                itemCount: 6,
                itemBuilder: (context, index) {
                  final pieceNumber = index + 1;
                  final exposure =
                      widget.startExposure + (widget.exposureIncrement * index);
                  final isSelected = _selectedPieces.contains(pieceNumber);

                  return GlassButton(
                    tint: isSelected
                        ? GlassButtonTint.positive
                        : GlassButtonTint.neutral,
                    onPressed: () {
                      setState(() {
                        if (isSelected) {
                          // Deselect if already selected
                          _selectedPieces.remove(pieceNumber);
                          return;
                        }

                        if (_selectedPieces.isEmpty) {
                          // First selection
                          _selectedPieces.add(pieceNumber);
                          return;
                        }

                        if (_selectedPieces.length == 1) {
                          final existing = _selectedPieces.first;
                          if ((existing - pieceNumber).abs() == 1) {
                            // Adjacent — select as second
                            _selectedPieces.add(pieceNumber);
                          } else {
                            // Non-adjacent selection replaces prior choice
                            _selectedPieces.clear();
                            _selectedPieces.add(pieceNumber);
                          }
                          return;
                        }

                        // If two are already selected, replace the oldest with
                        // the new selection, but ensure resulting pair are
                        // adjacent; otherwise leave only the new selection.
                        _selectedPieces.removeAt(0);
                        _selectedPieces.add(pieceNumber);
                        final a = _selectedPieces[0];
                        final b = _selectedPieces[1];
                        if ((a - b).abs() != 1) {
                          // Not adjacent — clear other and keep only the new
                          _selectedPieces.clear();
                          _selectedPieces.add(pieceNumber);
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          '#$pieceNumber',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${exposure.toStringAsFixed(1)}s',
                          style: TextStyle(
                            fontSize: 24,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          const SizedBox(height: 12),
          const Text(
            'Select the test piece that matches the evaluation guide.\n If unsure, select the two pieces that look best.',
            style: TextStyle(
              fontSize: 18,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          // Space for floating action buttons
          const SizedBox(height: 85),
        ],
      ),
    );
  }

  void _saveOptimalExposure() async {
    if (_selectedPieces.isEmpty) return;

    final pieceNumber = _selectedPieces.first;
    final optimalExposure =
        widget.startExposure + (widget.exposureIncrement * (pieceNumber - 1));

    // Fetch current profile to get the actual previous exposure time
    double previousExposure = widget.startExposure;
    try {
      final profileJson =
          await _backendService.getProfileJson(widget.profileId);
      final normalized = NanoProfile.normalizeForEdit(profileJson);
      previousExposure = (normalized['normal_cure_time'] as num?)?.toDouble() ??
          widget.startExposure;
    } catch (e) {
      _logger.warning('Failed to fetch current profile for comparison: $e');
      // Continue with widget.startExposure as fallback
    }

    try {
      _logger.info(
          'Saving optimal exposure ${optimalExposure}s to profile ${widget.profileId}');

      // Normalize to the canonical key and convert to backend fields
      final normalized = {'normal_cure_time': optimalExposure};
      final backendFields = NanoProfile.denormalizeForBackend(normalized);

      await _backendService.editProfile(widget.profileId, backendFields);
      _logger.info('Successfully saved optimal exposure to profile');
    } catch (e) {
      _logger.warning('Failed to save optimal exposure to profile: $e');
      // Continue to show success dialog even if save fails
      // The user can manually adjust settings if needed
    }

    showDialog(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('Calibration Complete',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.resinProfileName ?? 'Resin Profile',
              style: TextStyle(
                fontSize: 22,
                color: Colors.grey.shade400,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Text(
                      'Previous',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${previousExposure.toStringAsFixed(1)}s',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Theme.of(context).colorScheme.primary,
                    size: 40,
                  ),
                ),
                Column(
                  children: [
                    Text(
                      'Optimal',
                      style: TextStyle(
                        fontSize: 18,
                        color: Colors.grey.shade400,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${optimalExposure.toStringAsFixed(1)}s',
                      style: TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Layer exposure time updated',
              style: TextStyle(
                fontSize: 20,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
        actions: [
          GlassButton(
            tint: GlassButtonTint.positive,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(120, 65),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              widget.onComplete(); // Close overlay
            },
            child: const Text('Done', style: TextStyle(fontSize: 22)),
          ),
        ],
      ),
    );
  }

  void _showFineTuneDialog() {
    if (_selectedPieces.length != 2) return;

    final p1 = _selectedPieces[0];
    final p2 = _selectedPieces[1];
    final e1 = widget.startExposure + (widget.exposureIncrement * (p1 - 1));
    final e2 = widget.startExposure + (widget.exposureIncrement * (p2 - 1));
    final minExp = e1 < e2 ? e1 : e2;
    final maxExp = e1 < e2 ? e2 : e1;

    double value = minExp;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setStateDialog) {
          final range = (maxExp - minExp).abs();
          final divisions =
              range <= 0.0001 ? 1 : ((range / 0.05).round()).clamp(1, 1000);

          return GlassAlertDialog(
            title: const Text('Fine-Tune Exposure',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select a value between ${minExp.toStringAsFixed(2)}s and ${maxExp.toStringAsFixed(2)}s',
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                Text(
                  '${value.toStringAsFixed(2)}s',
                  style: TextStyle(
                      fontSize: 42,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary),
                ),
                Slider(
                  value: value,
                  min: minExp,
                  max: maxExp,
                  divisions: divisions,
                  onChanged: (v) {
                    // Snap to 0.05s steps for cleanliness
                    final snapped = (v / 0.05).round() * 0.05;
                    setStateDialog(() {
                      value = double.parse(snapped.toStringAsFixed(2));
                    });
                  },
                ),
              ],
            ),
            actions: [
              GlassButton(
                tint: GlassButtonTint.neutral,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(100, 65),
                ),
                onPressed: () {
                  Navigator.of(context).pop();
                },
                child: const Text('Cancel', style: TextStyle(fontSize: 22)),
              ),
              GlassButton(
                tint: GlassButtonTint.positive,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(100, 65),
                ),
                onPressed: () async {
                  Navigator.of(context).pop();

                  // Fetch current profile to get the actual previous exposure time
                  double previousExposure = widget.startExposure;
                  try {
                    final profileJson =
                        await _backendService.getProfileJson(widget.profileId);
                    final normalized =
                        NanoProfile.normalizeForEdit(profileJson);
                    previousExposure =
                        (normalized['normal_cure_time'] as num?)?.toDouble() ??
                            widget.startExposure;
                  } catch (e) {
                    _logger.warning(
                        'Failed to fetch current profile for comparison: $e');
                    // Continue with widget.startExposure as fallback
                  }

                  // Save the chosen fine-tuned exposure
                  try {
                    final normalized = {'normal_cure_time': value};
                    final backendFields =
                        NanoProfile.denormalizeForBackend(normalized);
                    await _backendService.editProfile(
                        widget.profileId, backendFields);
                  } catch (e) {
                    _logger.warning('Failed to save fine-tuned exposure: $e');
                  }

                  showDialog(
                    context: context,
                    builder: (context) => GlassAlertDialog(
                      title: const Text('Calibration Complete',
                          style: TextStyle(
                              fontSize: 26, fontWeight: FontWeight.bold)),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.resinProfileName ?? 'Resin Profile',
                            style: TextStyle(
                              fontSize: 22,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Column(
                                children: [
                                  Text(
                                    'Previous',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${previousExposure.toStringAsFixed(1)}s',
                                    style: TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey.shade600,
                                      decoration: TextDecoration.lineThrough,
                                    ),
                                  ),
                                ],
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: Theme.of(context).colorScheme.primary,
                                  size: 40,
                                ),
                              ),
                              Column(
                                children: [
                                  Text(
                                    'Fine-Tuned',
                                    style: TextStyle(
                                      fontSize: 18,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${value.toStringAsFixed(2)}s',
                                    style: TextStyle(
                                      fontSize: 42,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Layer exposure time updated',
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      actions: [
                        GlassButton(
                          tint: GlassButtonTint.positive,
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(120, 65),
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            widget.onComplete();
                          },
                          child: const Text('Done',
                              style: TextStyle(fontSize: 22)),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Save', style: TextStyle(fontSize: 22)),
              ),
            ],
          );
        });
      },
    );
  }
}
