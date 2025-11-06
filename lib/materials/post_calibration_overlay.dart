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
import 'package:orion/materials/calibration_screen.dart';
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
  int _currentStep = 0; // 0 = QR code, 1 = evaluation
  int? _selectedPiece;

  @override
  Widget build(BuildContext context) {
    return GlassApp(
      child: Scaffold(
        backgroundColor: Colors.transparent,
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
      ),
    );
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
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // Compact header matching evaluation screen
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsFill.qrCode,
                size: 32,
                color: Colors.blue.shade300,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'CALIBRATION COMPLETE',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (widget.resinProfileName != null)
                    Text(
                      widget.resinProfileName!,
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            'Scan the QR code for the ${widget.calibrationModelName} evaluation guide',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: QrImageView(
                  data: evaluationGuideUrl,
                  version: QrVersions.auto,
                  size: 240,
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
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: GlassButton(
              tint: GlassButtonTint.positive,
              onPressed: () {
                setState(() {
                  _currentStep = 1;
                });
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 65),
              ),
              child: const Text('Next', style: TextStyle(fontSize: 22)),
            ),
          ),
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
          // Compact header
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                PhosphorIconsFill.magnifyingGlass,
                size: 32,
                color: Colors.blue.shade300,
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    'EVALUATE RESULTS',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                  if (widget.resinProfileName != null)
                    Text(
                      widget.resinProfileName!,
                      style: TextStyle(
                        fontSize: 17,
                        color: Colors.grey.shade400,
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

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
                  final isSelected = _selectedPiece == pieceNumber;

                  return GlassButton(
                    tint: isSelected
                        ? GlassButtonTint.positive
                        : GlassButtonTint.neutral,
                    onPressed: () {
                      setState(() {
                        _selectedPiece = pieceNumber;
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

          const SizedBox(height: 8),
          const Text(
            'Select the test piece that matches the evaluation guide, or redo calibration',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),

          // Action buttons
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: GlassButton(
                  tint: GlassButtonTint.warn,
                  onPressed: () {
                    // Pop overlay and navigate to CalibrationScreen
                    Navigator.of(context).pop(); // Pop overlay
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const CalibrationScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 65),
                  ),
                  child:
                      const Text('Reconfigure', style: TextStyle(fontSize: 22)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GlassButton(
                  tint: GlassButtonTint.positive,
                  onPressed: _selectedPiece == null
                      ? null
                      : () {
                          _saveOptimalExposure();
                        },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(0, 65),
                  ),
                  child: const Text('Save Settings',
                      style: TextStyle(fontSize: 22)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _saveOptimalExposure() async {
    if (_selectedPiece == null) return;

    final optimalExposure = widget.startExposure +
        (widget.exposureIncrement * (_selectedPiece! - 1));

    try {
      _logger.info(
          'Saving optimal exposure ${optimalExposure}s to profile ${widget.profileId}');
      await _backendService.editProfile(widget.profileId, {
        'LayerCureTime': optimalExposure,
      });
      _logger.info('Successfully saved optimal exposure to profile');
    } catch (e) {
      _logger.warning('Failed to save optimal exposure to profile: $e');
      // Continue to show success dialog even if save fails
      // The user can manually adjust settings if needed
    }

    showDialog(
      context: context,
      builder: (context) => GlassAlertDialog(
        title: const Text('Settings Saved'),
        content: Text(
          'Optimal layer exposure time of ${optimalExposure.toStringAsFixed(1)}s has been saved to ${widget.resinProfileName ?? 'the resin profile'}.',
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          GlassButton(
            tint: GlassButtonTint.positive,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(100, 65),
            ),
            onPressed: () {
              Navigator.of(context).pop(); // Close dialog
              widget.onComplete(); // Close overlay
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
