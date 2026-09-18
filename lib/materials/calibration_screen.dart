/*
* Orion - Calibration Screen
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:logging/logging.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:orion/backend_service/providers/resins_provider.dart';
import 'package:orion/backend_service/backend_service.dart';
import 'package:provider/provider.dart';
import 'package:orion/glasser/glasser.dart';
import 'package:orion/widgets/resin_chip.dart';
import 'package:orion/util/providers/theme_provider.dart';
import 'package:orion/materials/calibration_progress_overlay.dart';
import 'package:orion/materials/calibration_context_provider.dart';
import 'package:orion/util/orion_spacing.dart';
import 'package:orion/util/overlay_route.dart';
import 'package:orion/widgets/selection_screens.dart';
import 'package:orion/widgets/zoom_value_editor_dialog.dart';
import 'package:orion/util/orion_config.dart';

/// The calibration tab: what the wizard is for, and the way into it. The setup
/// itself is presented over the shell (see [buildOverlayRoute]), so it gets the
/// whole screen instead of the shell's app bar and bottom navigation.
class CalibrationScreen extends StatelessWidget {
  const CalibrationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 20),
              Text(
                FlutterI18n.translate(context, 'calibration.wizardIntro'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                FlutterI18n.translate(context, 'calibration.wizardIntroDetail'),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  height: 1.4,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
              const SizedBox(height: OrionSpacing.controlGap + 12),
              SizedBox(
                width: 320,
                child: GlassButton(
                  tint: GlassButtonTint.positive,
                  onPressed: () => Navigator.of(context).push(
                    buildOverlayRoute(const CalibrationWizardScreen()),
                  ),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 65),
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        PhosphorIcon(PhosphorIcons.arrowRight(), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          FlutterI18n.translate(context, 'calibration.start'),
                          style: const TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The calibration setup, presented over the shell by [CalibrationScreen].
class CalibrationWizardScreen extends StatefulWidget {
  const CalibrationWizardScreen({super.key});

  @override
  State<CalibrationWizardScreen> createState() =>
      _CalibrationWizardScreenState();
}

/// The calibration workflow: pick the resin, pick the model, set the exposure.
enum _CalibrationStep {
  source,
  resin,
  model,
  startingExposure,
  exposureIncrement
}

/// Where the profile being calibrated comes from: a factory template, or one of
/// the user's own profiles.
enum _ResinSource { template, existing }

class _CalibrationWizardScreenState extends State<CalibrationWizardScreen> {
  final _log = Logger('CalibrationScreen');
  _CalibrationStep _step = _CalibrationStep.source;

  /// Null until the first step is answered.
  _ResinSource? _resinSource;

  /// Set while the printer holds only one kind of profile: there is nothing to
  /// ask, so the source step is not part of the walk.
  bool _sourceSkipped = false;

  /// The steps this session walks.
  List<_CalibrationStep> get _steps => _sourceSkipped
      ? const [
          _CalibrationStep.resin,
          _CalibrationStep.model,
          _CalibrationStep.startingExposure,
          _CalibrationStep.exposureIncrement,
        ]
      : _CalibrationStep.values;

  /// The height every step's control occupies.
  static const double _controlHeight = 88.0;

  /// The gap the step body keeps above its control, matching the one between
  /// the control and the actions.
  static const double _contentGap = 16.0;

  /// The 80%-wide guide column, anchored so tests can assert that the steps do
  /// not shift under each other.
  static const Key _guideColumnKey = Key('calibration-guide-column');

  CalibrationModel? _selectedModel;
  ResinProfile? _selectedResin;
  int? _lastImageFetchRequestModelId;
  double _startingExposure = 1.0; // seconds
  double _exposureIncrement = 0.2; // seconds

  int _currentTestPiecesCount() {
    final count =
        _selectedModel?.testPiecesCount ?? _selectedModel?.models ?? 6;
    return count > 0 ? count : 6;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final resins = Provider.of<ResinsProvider>(context).resins;
    final hasTemplates = resins.any((r) => r.locked);
    final hasExisting = resins.any((r) => !r.locked);
    _sourceSkipped = hasTemplates != hasExisting;
    if (!_sourceSkipped) return;
    _setSource(
        hasTemplates ? _ResinSource.template : _ResinSource.existing);
    if (_step == _CalibrationStep.source) {
      _step = _CalibrationStep.resin;
    }
  }

  @override
  void initState() {
    super.initState();
    // Initialize from cache immediately; refresh in background.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resinsProvider =
          Provider.of<ResinsProvider>(context, listen: false);

      // Prefer cached/provider-selected model immediately.
      final providerModel = resinsProvider.selectedCalibrationModel;
      if (mounted && _selectedModel == null && providerModel != null) {
        setState(() {
          _selectedModel = providerModel;
          _selectedResin = resinsProvider.getRecommendedResin(_selectedModel);
        });
        _lastImageFetchRequestModelId = providerModel.id;
        unawaited(resinsProvider.ensureCalibrationImage(providerModel.id));
      }

      // Refresh latest data without blocking first paint.
      unawaited(resinsProvider.refresh().then((_) {
        if (!mounted) return;
        final refreshedModel = resinsProvider.selectedCalibrationModel;
        if (_selectedModel == null && refreshedModel != null) {
          setState(() {
            _selectedModel = refreshedModel;
            _selectedResin = resinsProvider.getRecommendedResin(_selectedModel);
          });
          _lastImageFetchRequestModelId = refreshedModel.id;
          unawaited(resinsProvider.ensureCalibrationImage(refreshedModel.id));
        }
      }));
    });
  }

  @override
  Widget build(BuildContext context) {
    final resinsProvider = Provider.of<ResinsProvider>(context);
    // Locked (factory) profiles are offered here too: they can be calibrated
    // even though they cannot be edited.
    final resins = resinsProvider.resins;
    final hasResins = resins.isNotEmpty;
    final isResinsLoading = resinsProvider.isLoading && !hasResins;

    // If the selected model has no cached image, force-fetch it immediately.
    final selectedId = _selectedModel?.id;
    if (selectedId != null) {
      final selectedImage = resinsProvider.calibrationImageUrl(selectedId);
      final shouldRequest = (selectedImage == null || selectedImage.isEmpty) &&
          _lastImageFetchRequestModelId != selectedId;
      if (shouldRequest) {
        _lastImageFetchRequestModelId = selectedId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(resinsProvider.ensureCalibrationImage(selectedId));
        });
      }
    }

    // Opaque, as the leveling wizard is: the shell stays behind the barrier but
    // nothing of it shows through the wizard's own surface.
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        body: Padding(
          // Matching the pre-flight page the wizard hands over to.
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: LayoutBuilder(
            key: _guideColumnKey,
            builder: (context, constraints) {
              return Column(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: _buildStepBody(resinsProvider, resins,
                          isResinsLoading, constraints.biggest),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildStepActions(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  /// The changing part of a step: its header and its control, cross-faded the
  /// way the rest of Orion cross-fades a step change. The actions below stay
  /// outside it, so they hold still.
  Widget _buildStepBody(
    ResinsProvider provider,
    List<ResinProfile> resins,
    bool isResinsLoading,
    Size slot,
  ) {
    // The header holds the top of the step and scales down rather than pushing
    // the control or the actions out of the window; the control then centres
    // itself in whatever room is left between the header and the actions.
    final controlHeight = _controlHeightFor(resins, slot.height);
    final headerMaxHeight =
        (slot.height - controlHeight - _contentGap).clamp(0.0, double.infinity);
    return Column(
      key: ValueKey(_step),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxHeight: headerMaxHeight),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: slot.width,
              child: _buildStepHeader(),
            ),
          ),
        ),
        // The control keeps the same distance from the header as the actions
        // keep from it below, with the slack shared either side.
        const SizedBox(height: _contentGap),
        Expanded(
          child: Center(
            child: _buildStepContent(
                provider, resins, isResinsLoading, controlHeight),
          ),
        ),
      ],
    );
  }

  /// The step's header: what to do, then why it matters.
  Widget _buildStepHeader() {
    final (promptKey, helpKey) = switch (_step) {
      // Only the steps that need it carry an explainer.
      _CalibrationStep.source => (
          'calibration.promptSource',
          'calibration.helpSource'
        ),
      // The resin step says which pool it is drawing from.
      _CalibrationStep.resin => (
          _resinSource == _ResinSource.template
              ? 'calibration.promptTemplate'
              : 'calibration.promptResin',
          null
        ),
      _CalibrationStep.model => ('calibration.promptModel', null),
      _CalibrationStep.startingExposure => (
          'calibration.promptStartingExposure',
          'calibration.startingExposureHelp'
        ),
      _CalibrationStep.exposureIncrement => (
          'calibration.promptExposureIncrement',
          'calibration.exposureIncrementHelp'
        ),
    };
    return Column(
      children: [
        Text(
          FlutterI18n.translate(context, promptKey),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        if (helpKey != null) ...[
          const SizedBox(height: 6),
          Text(
            FlutterI18n.translate(context, helpKey),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }

  /// The control the current step asks for.
  Widget _buildStepContent(ResinsProvider provider, List<ResinProfile> resins,
      bool isResinsLoading, double controlHeight) {
    switch (_step) {
      case _CalibrationStep.source:
        return _buildSourceStep(resins);
      case _CalibrationStep.resin:
        return _resinSource == _ResinSource.template
            ? _buildTemplateGrid(resins, controlHeight)
            : _buildResinStep(resins, isResinsLoading);
      case _CalibrationStep.model:
        return _buildModelStep(provider, controlHeight);
      case _CalibrationStep.startingExposure:
        return _buildExposureValue(
          titleKey: 'calibration.startingExposure',
          descriptionKey: 'calibration.exposureDesc',
          value: _startingExposure,
          min: 0.5,
          max: 10,
          decimals: 1,
          onSave: (v) => setState(() => _startingExposure = v),
        );
      case _CalibrationStep.exposureIncrement:
        return _buildExposureValue(
          titleKey: 'calibration.exposureIncrement',
          descriptionKey: 'calibration.incrementDesc',
          value: _exposureIncrement,
          min: 0.1,
          max: 2,
          decimals: 2,
          onSave: (v) => setState(() => _exposureIncrement = v),
        );
    }
  }

  /// One exposure value, edited in the shared zoom editor. The header names the
  /// field, so the card carries the value alone.
  Widget _buildExposureValue({
    required String titleKey,
    required String descriptionKey,
    required double value,
    required double min,
    required double max,
    required int decimals,
    required ValueChanged<double> onSave,
  }) {
    return SizedBox(
      height: 88,
      child: _buildCompactCard(
        value: '${value.toStringAsFixed(2)} $_secondsUnit',
        onTap: () => _editValue(
          title: FlutterI18n.translate(context, titleKey),
          description: FlutterI18n.translate(context, descriptionKey),
          currentValue: value,
          min: min,
          max: max,
          suffix: ' $_secondsUnit',
          decimals: decimals,
          step: 0.1,
          onSave: onSave,
        ),
      ),
    );
  }

  /// Switches pools, dropping a selection the new pool does not hold.
  void _setSource(_ResinSource source) {
    _resinSource = source;
    if (_selectedResin != null &&
        _selectedResin!.locked != (source == _ResinSource.template)) {
      _selectedResin = null;
    }
  }

  /// How tall this step's control needs to be. Everything is one card tall
  /// except the template grid, which grows a row at a time and never takes more
  /// room than the step has.
  double _controlHeightFor(List<ResinProfile> resins, double available) {
    if (_step == _CalibrationStep.model) {
      // Room for the model's preview, with the header's share kept back.
      final wanted = available - 140;
      if (wanted >= _controlHeight) {
        return wanted < 300 ? wanted : 300;
      }
      return available;
    }
    final isTemplateGrid = _step == _CalibrationStep.resin &&
        _resinSource == _ResinSource.template;
    if (!isTemplateGrid) return _controlHeight;
    if (available <= _controlHeight) return available;
    final rows = (_sourceResins(resins).length / 2).ceil();
    final needed = rows * _controlHeight + (rows - 1) * 12;
    if (needed <= _controlHeight) return _controlHeight;
    return needed < available ? needed : available;
  }

  /// The key a profile is identified by, as the provider stores it.
  String _resinKey(ResinProfile resin) => resin.path ?? resin.name;

  /// The profiles the chosen source offers: factory templates, or the user's
  /// own profiles.
  List<ResinProfile> _sourceResins(List<ResinProfile> resins) {
    final templates = _resinSource == _ResinSource.template;
    return resins.where((r) => r.locked == templates).toList();
  }

  /// Step 1: which pool of profiles to pick from next.
  Widget _buildSourceStep(List<ResinProfile> resins) {
    return SizedBox(
      height: _controlHeight,
      child: Row(
        children: [
          Expanded(
            child: _buildSourceCard(
              icon: PhosphorIcons.factory(),
              label: FlutterI18n.translate(context, 'resins.template'),
              source: _ResinSource.template,
              enabled: resins.any((r) => r.locked),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildSourceCard(
              icon: PhosphorIcons.flask(),
              label:
                  FlutterI18n.translate(context, 'calibration.sourceExisting'),
              source: _ResinSource.existing,
              enabled: resins.any((r) => !r.locked),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard({
    required IconData icon,
    required String label,
    required _ResinSource source,
    required bool enabled,
  }) {
    final selected = _resinSource == source;
    final accent = selected ? Colors.green.shade400 : null;
    return GlassCard(
      outlined: false,
      elevation: selected ? 2 : 1,
      margin: EdgeInsets.zero,
      color: selected ? Colors.green.shade400.withValues(alpha: 0.08) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(glassCornerRadius),
        onTap: !enabled ? null : () => setState(() => _setSource(source)),
        child: _selectedOutline(
          selected: selected,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                PhosphorIcon(
                  icon,
                  size: 22,
                  color:
                      enabled ? (accent ?? Colors.grey.shade400) : Colors.grey,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: enabled ? accent : Colors.grey.shade600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The treatment the resin rows use for the chosen one: a green outline over
  /// a green wash, so a selected card reads the same here as in the resin list.
  Widget _selectedOutline({required bool selected, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(glassCornerRadius),
        border: Border.all(
          color: selected
              ? Colors.green.shade400.withValues(alpha: 0.55)
              : Theme.of(context).dividerColor.withValues(alpha: 0.35),
          width: selected ? 1.6 : 1.0,
        ),
      ),
      child: child,
    );
  }

  /// The unit the exposure cards and their editors use.
  String get _secondsUnit =>
      FlutterI18n.translate(context, 'calibration.secondsUnit');

  /// The templates, shown inline instead of behind a picker: the factory ships
  /// a handful of them, so two columns is the whole list.
  Widget _buildTemplateGrid(List<ResinProfile> resins, double height) {
    final templates = _sourceResins(resins);
    return SizedBox(
      height: height,
      width: double.infinity,
      child: GridView.builder(
        padding: EdgeInsets.zero,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          mainAxisExtent: _controlHeight,
        ),
        itemCount: templates.length,
        itemBuilder: (context, i) => _buildTemplateCard(templates[i]),
      ),
    );
  }

  Widget _buildTemplateCard(ResinProfile resin) {
    final selected =
        _selectedResin != null && _resinKey(_selectedResin!) == _resinKey(resin);
    final success = Colors.green.shade400;
    final layerHeightUm = resin.layerHeightUm;

    return GlassCard(
      outlined: false,
      elevation: selected ? 2 : 1,
      margin: EdgeInsets.zero,
      color: selected ? Colors.green.shade400.withValues(alpha: 0.08) : null,
      child: InkWell(
        borderRadius: BorderRadius.circular(glassCornerRadius),
        onTap: () => setState(() => _selectedResin = resin),
        child: _selectedOutline(
          selected: selected,
          child: Padding(
            padding: OrionSpacing.compactCardPadding,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    resin.name,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: selected ? success : null,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (layerHeightUm != null) ...[
                  const SizedBox(width: 8),
                  ResinChip(
                    icon: PhosphorIcons.stack(),
                    label: FlutterI18n.translate(
                        context, 'resins.layerHeightChip',
                        translationParams: {
                          'value': formatResinChipNumber(layerHeightUm)
                        }),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Step 1: the resin profile the calibration will use. It is chosen on its
  /// own screen rather than listed here, and the header already names the
  /// field, so the card shows the profile and its layer height alone.
  Widget _buildResinStep(List<ResinProfile> resins, bool isLoading) {
    final layerHeightUm = _selectedResin?.layerHeightUm;
    return SizedBox(
      height: 88,
      child: _buildCompactCard(
        value: isLoading
            ? 'Loading...'
            : (_selectedResin?.name ??
                FlutterI18n.translate(context, 'calibration.selectResin')),
        trailing: layerHeightUm == null
            ? null
            : ResinChip(
                icon: PhosphorIcons.stack(),
                label: FlutterI18n.translate(context, 'resins.layerHeightChip',
                    translationParams: {
                      'value': formatResinChipNumber(layerHeightUm)
                    }),
              ),
        onTap: isLoading ? () {} : () => _selectResinProfile(resins),
      ),
    );
  }

  Future<void> _selectResinProfile(List<ResinProfile> resins) async {
    if (resins.isEmpty) return;

    final selected = await Navigator.of(context).push<ResinProfile>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => ResinProfileSelectionScreen(
          title: FlutterI18n.translate(context, 'calibration.selectResin'),
          resins: _sourceResins(resins),
          selectedResinKey: _selectedResin == null
              ? null
              : _selectedResin!.path ?? _selectedResin!.name,
          onSelected: (resin) => Navigator.of(context).pop(resin),
        ),
      ),
    );

    if (selected == null || !mounted) return;
    setState(() => _selectedResin = selected);
  }

  /// Step 2: the test model the calibration will print. The preview belongs to
  /// the picker, not to the selector, so this stays a plain value card.
  Widget _buildModelStep(ResinsProvider provider, double controlHeight) {
    final models = provider.calibrationModels;
    final isModelsLoading = provider.isLoading && models.isEmpty;
    final model = _selectedModel;
    final imageUrl =
        model == null ? null : provider.calibrationImageUrl(model.id);

    return SizedBox(
      height: controlHeight,
      child: GlassCard(
        outlined: false,
        margin: EdgeInsets.zero,
        color: model == null
            ? null
            : Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
        child: InkWell(
          borderRadius: BorderRadius.circular(glassCornerRadius),
          onTap: isModelsLoading ? () {} : () => _selectCalibrationModel(models),
          child: Padding(
            padding: OrionSpacing.cardPadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: isModelsLoading
                        ? _buildModelPreviewPlaceholder(
                            FlutterI18n.translate(
                                context, 'calibration.loadingModels'))
                        : imageUrl == null
                            ? _buildModelPreviewPlaceholder(
                                FlutterI18n.translate(
                                    context, 'calibration.noModel'),
                                icon: Icons.science)
                            : Image.network(
                                imageUrl,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) =>
                                    _buildModelPreviewPlaceholder(
                                        FlutterI18n.translate(
                                            context, 'calibration.noModel'),
                                        icon: Icons.science),
                              ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        model?.name ??
                            FlutterI18n.translate(
                                context, 'calibration.selectModel'),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(Icons.chevron_right,
                        color: Colors.grey.shade400, size: 24),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// What the preview area shows until there is an image to show.
  Widget _buildModelPreviewPlaceholder(String label, {IconData? icon}) {
    return Container(
      color: Colors.grey.shade800.withValues(alpha: 0.6),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, size: 48, color: Colors.grey.shade600)
            else
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(fontSize: 15, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Only the last step starts the print; the steps before it just move on.
  /// The first step has nothing to go back to, so it carries the primary action
  /// alone. Both are a fixed 65pt tall and scale their label down rather than
  /// wrapping, so a long translation cannot move the layout either.
  Widget _buildStepActions() {
    final isLast = _steps.last == _step;
    // Every step has to be answered before it lets go.
    final canAdvance = switch (_step) {
      _CalibrationStep.source => _resinSource != null,
      _CalibrationStep.resin ||
      _CalibrationStep.exposureIncrement =>
        _selectedResin != null,
      _CalibrationStep.model || _CalibrationStep.startingExposure => true,
    };

    Widget actionButton({
      required GlassButtonTint tint,
      required IconData icon,
      required VoidCallback? onPressed,
      required String label,
    }) {
      return GlassButton(
        tint: tint,
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(double.infinity, 65),
          maximumSize: const Size(double.infinity, 65),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              PhosphorIcon(icon, size: 20),
              const SizedBox(width: 10),
              Text(
                label,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      );
    }

    final primary = actionButton(
      tint: GlassButtonTint.positive,
      icon: isLast ? PhosphorIcons.checkCircle() : PhosphorIcons.arrowRight(),
      onPressed:
          canAdvance ? (isLast ? _startCalibration : _advanceStep) : null,
      label: FlutterI18n.translate(
          context, isLast ? 'calibration.start' : 'common.next'),
    );

    // The first step has nothing to go back to, so it leaves the wizard.
    final isFirst = _steps.first == _step;

    return Row(
      children: [
        Expanded(
          child: actionButton(
            tint: isFirst ? GlassButtonTint.negative : GlassButtonTint.neutral,
            icon: isFirst ? PhosphorIcons.x() : PhosphorIcons.arrowLeft(),
            onPressed: isFirst ? _cancelWizard : _previousStep,
            label: FlutterI18n.translate(
                context, isFirst ? 'common.cancel' : 'common.back'),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(child: primary),
      ],
    );
  }

  /// Leaves the wizard without starting anything.
  void _cancelWizard() => Navigator.of(context).maybePop();

  void _advanceStep() {
    final steps = _steps;
    final i = steps.indexOf(_step);
    if (i < 0 || i >= steps.length - 1) return;
    setState(() => _step = steps[i + 1]);
  }

  void _previousStep() {
    final steps = _steps;
    final i = steps.indexOf(_step);
    if (i <= 0) return;
    setState(() => _step = steps[i - 1]);
  }

  /// One tappable value card. With no [title] the value stands alone, centred —
  /// for fields whose prompt already names them.
  Widget _buildCompactCard({
    String? title,
    required String value,
    required VoidCallback onTap,
    Widget? trailing,
  }) {
    return GlassCard(
      outlined: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(glassCornerRadius),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // spread when the card is given a height, hug when it is not
                  mainAxisAlignment: title == null
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.spaceBetween,
                  children: [
                    if (title != null) ...[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade400,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      value,
                      style: TextStyle(fontSize: title == null ? 22 : 19),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 12),
                trailing,
              ],
              const SizedBox(width: 8),
              Icon(Icons.chevron_right, color: Colors.grey.shade400, size: 28),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pollSlicerProgress(
    ValueNotifier<double> progressNotifier,
    ValueNotifier<String> messageNotifier,
  ) async {
    messageNotifier.value =
        FlutterI18n.translate(context, 'calibration.slicing');

    final startTime = DateTime.now();
    const timeout = Duration(minutes: 10); // 10 minute timeout for slicing

    // Poll every 1 second
    while (mounted) {
      // Get slicer progress for UI display
      final progress = await BackendService().getSlicerProgress();
      if (!mounted) return;

      if (progress != null) {
        // Treat 93% as complete (show as 100% on progress bar)
        if (progress >= 0.93) {
          progressNotifier.value = 1.0;
        } else {
          // Scale 0-93% to 0-100% for display
          progressNotifier.value = progress / 0.93;
        }
      }

      // Calibration prints don't report percentage correctly in /slicer endpoint
      // so we check plates.json directly for plate 0's Processed flag
      final isProcessed = await BackendService().isCalibrationPlateProcessed();
      if (!mounted) return;

      // Break at 93% or when processed flag is set (print starts at 99%)
      if (isProcessed == true || (progress != null && progress >= 0.93)) {
        messageNotifier.value =
            FlutterI18n.translate(context, 'calibration.slicingComplete');
        progressNotifier.value = 1.0;
        _log.info('Calibration preparation complete');
        break;
      }

      // Check timeout
      if (DateTime.now().difference(startTime) > timeout) {
        _log.warning(
            'Slicer progress polling timed out after ${timeout.inMinutes} minutes');
        throw Exception('Slicing operation timed out');
      }

      await Future.delayed(const Duration(seconds: 1));
    }
  }

  Future<void> _editValue({
    required String title,
    String? description,
    required double currentValue,
    required double min,
    required double max,
    required String suffix,
    required int decimals,
    double? step,
    required ValueChanged<double> onSave,
  }) async {
    final result = await ZoomValueEditorDialog.show(
      context,
      title: title,
      description: description,
      currentValue: currentValue,
      min: min,
      max: max,
      suffix: suffix,
      decimals: decimals,
      step: step,
    );
    if (result != null) onSave(result);
  }

  Future<void> _selectCalibrationModel(List<CalibrationModel> models) async {
    if (models.isEmpty) {
      return;
    }

    final selected = await Navigator.of(context).push<CalibrationModel>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => _CalibrationModelPickerScreen(
          models: models,
          selectedModel: _selectedModel,
        ),
      ),
    );

    if (selected == null || !mounted) return;
    final resinsProvider = Provider.of<ResinsProvider>(context, listen: false);
    setState(() {
      _selectedModel = selected;
    });
    resinsProvider.setSelectedCalibrationModelId(selected.id);
    _lastImageFetchRequestModelId = selected.id;
    unawaited(resinsProvider.ensureCalibrationImage(selected.id));
  }

  void _startCalibration() async {
    _log.info(
        'Starting calibration: model=${_selectedModel?.name} (id=${_selectedModel?.id}), resin=${_selectedResin?.name}, start=$_startingExposure, increment=$_exposureIncrement');

    final testPiecesCount = _currentTestPiecesCount();

    // Build a human-readable sequence of exposures for the selected model's piece count
    // Show unified pre-calibration overlay with info and checklist
    final confirmed = await Navigator.of(context).push<bool>(
      PageRouteBuilder(
        opaque: false,
        barrierDismissible: true,
        transitionDuration: const Duration(milliseconds: 300),
        reverseTransitionDuration: const Duration(milliseconds: 300),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        pageBuilder: (context, _, __) => _PreCalibrationOverlay(
          calibrationModelName: _selectedModel!.name,
          resinProfileName: _selectedResin?.name,
          startingExposure: _startingExposure,
          exposureIncrement: _exposureIncrement,
          calibrationModelId: _selectedModel!.id,
          testPiecesCount: testPiecesCount,
        ),
      ),
    );

    if (confirmed == true) {
      _log.info('Checklist confirmed, starting calibration...');

      // Show progress overlay
      final progressNotifier = ValueNotifier<double>(0.0);
      final messageNotifier = ValueNotifier<String>('');
      final showReadyNotifier = ValueNotifier<bool>(false);

      if (!mounted) return;

      // Reset overlay state for new calibration
      CalibrationProgressOverlay.reset();

      // Show overlay as a route
      Navigator.of(context).push(
        PageRouteBuilder(
          settings: const RouteSettings(name: 'calibration_progress_overlay'),
          opaque: false,
          barrierDismissible: false,
          transitionDuration: const Duration(milliseconds: 300),
          reverseTransitionDuration: const Duration(milliseconds: 300),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          pageBuilder: (context, _, __) => CalibrationProgressOverlay(
            progress: progressNotifier,
            message: messageNotifier,
            showReady: showReadyNotifier,
          ),
        ),
      );

      // Calculate exposure times
      final exposureTimes = List.generate(
        testPiecesCount,
        (i) => _startingExposure + (_exposureIncrement * i),
      );

      try {
        // Prefer the provider helper for consistent resolution logic.
        final resolvedProfileId =
            ResinsProvider.resolveProfileIdFromMeta(_selectedResin?.meta) ?? 0;

        // Store calibration context for post-print evaluation
        if (mounted) {
          context.read<CalibrationContextProvider>().setContext(
                CalibrationContext(
                  calibrationModelName: _selectedModel!.name,
                  resinProfileName: _selectedResin?.name,
                  startExposure: _startingExposure,
                  exposureIncrement: _exposureIncrement,
                  profileId: resolvedProfileId,
                  calibrationModelId: _selectedModel!.id,
                  evaluationGuideUrl: _selectedModel!.evaluationGuideUrl,
                ),
              );
        }

        // Show progress
        messageNotifier.value =
            FlutterI18n.translate(context, 'calibration.submittingJob');
        progressNotifier.value = 0.1;

        final reuseCalibrationPlate = OrionConfig()
            .getFlag('reuseCalibrationPlate', category: 'developer');
        if (reuseCalibrationPlate) {
          _log.info(
              'Developer mode: reusing existing calibration plate, skipping slicer');
          messageNotifier.value =
              'Starting existing calibration plate (debug)...';
          progressNotifier.value = 0.6;
          await BackendService().startPrint('Local', '0');
          showReadyNotifier.value = true;
          _log.info('Calibration print started (reuse mode)');
          return;
        }

        // Submit calibration job to backend
        final success = await BackendService().startCalibrationPrint(
          calibrationModelId: _selectedModel!.id,
          exposureTimes: exposureTimes,
          profileId: resolvedProfileId,
        );

        if (!success) {
          _log.warning('Calibration submission did not receive acknowledgment, '
              'but job may have started. Proceeding with progress polling...');
        }

        // Poll slicer progress regardless of ack
        // (the job may have started even if we timed out waiting for response)
        await _pollSlicerProgress(progressNotifier, messageNotifier);

        _log.info('Calibration preparation complete');

        // Show ready state with green flask
        showReadyNotifier.value = true;

        // StatusScreen will automatically open when print starts
        // and will dismiss overlay + pop CalibrationScreen
        _log.info('Waiting for StatusScreen to open...');
      } catch (e) {
        _log.severe('Error starting calibration: $e');
        messageNotifier.value = 'Error: $e';
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    }
  }
}

class _CalibrationModelPickerScreen extends StatelessWidget {
  final List<CalibrationModel> models;
  final CalibrationModel? selectedModel;

  const _CalibrationModelPickerScreen({
    required this.models,
    required this.selectedModel,
  });

  Widget _buildModelTile({
    required BuildContext context,
    required CalibrationModel model,
    required bool isSelected,
    required String? imageUrl,
  }) {
    final primary = Theme.of(context).colorScheme.primary;

    return GlassCard(
      elevation: isSelected ? 2.0 : 1.0,
      outlined: false,
      color: isSelected
          ? Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.3)
          : null,
      child: InkWell(
        onTap: () => Navigator.of(context).pop(model),
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    height: 96,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.black.withValues(alpha: 0.12),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: Colors.grey.shade800,
                                  child: const Icon(
                                    Icons.image_not_supported_outlined,
                                    size: 36,
                                    color: Colors.grey,
                                  ),
                                );
                              },
                            )
                          : Container(
                              color: Colors.grey.shade800,
                              child: const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                model.name,
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: isSelected ? primary : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .surfaceContainerHighest
                                          .withValues(alpha: 0.45),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.view_module_outlined,
                                          size: 12,
                                          color: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.color,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${model.models} ${model.models == 1 ? 'piece' : 'pieces'}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (model.resinRequired != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? primary.withValues(alpha: 0.2)
                                            : Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest
                                                .withValues(alpha: 0.35),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.water_drop_outlined,
                                            size: 12,
                                            color: isSelected
                                                ? primary
                                                : Theme.of(context)
                                                    .textTheme
                                                    .bodySmall
                                                    ?.color,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${model.resinRequired} ml',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: isSelected
                                                  ? primary
                                                  : Theme.of(context)
                                                      .textTheme
                                                      .bodySmall
                                                      ?.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final resinsProvider = Provider.of<ResinsProvider>(context, listen: false);

    return DetailedSelectionScreen(
      title: FlutterI18n.translate(context, 'calibration.selectModel'),
      padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          const spacing = 10.0;
          final columns = constraints.maxWidth < 560 ? 1 : 2;
          const sizingRows = 2;
          final tileWidth =
              (constraints.maxWidth - ((columns - 1) * spacing)) / columns;
          final tileHeight =
              (constraints.maxHeight - ((sizingRows - 1) * spacing)) /
                  sizingRows;
          final lockedAspectRatio = tileWidth / tileHeight;
          final fitWithoutScroll = models.length <= 4;

          final delegate = SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: lockedAspectRatio,
          );

          return GridView.builder(
            physics: fitWithoutScroll
                ? const NeverScrollableScrollPhysics()
                : const BouncingScrollPhysics(),
            itemCount: models.length,
            gridDelegate: delegate,
            itemBuilder: (context, index) {
              final model = models[index];
              final isSelected = selectedModel?.id == model.id;
              final imageUrl = resinsProvider.calibrationImageUrl(model.id);

              return _buildModelTile(
                context: context,
                model: model,
                isSelected: isSelected,
                imageUrl: imageUrl,
              );
            },
          );
        },
      ),
    );
  }
}

class _PreCalibrationOverlay extends StatelessWidget {
  final String calibrationModelName;
  final String? resinProfileName;
  final double startingExposure;
  final double exposureIncrement;
  final int calibrationModelId;
  final int testPiecesCount;

  const _PreCalibrationOverlay({
    required this.calibrationModelName,
    this.resinProfileName,
    required this.startingExposure,
    required this.exposureIncrement,
    required this.calibrationModelId,
    required this.testPiecesCount,
  });

  @override
  Widget build(BuildContext context) {
    final isGlass =
        Provider.of<ThemeProvider>(context, listen: false).isGlassTheme;
    final primary = Theme.of(context).colorScheme.primary;

    return GlassApp(
      child: Scaffold(
        backgroundColor: isGlass
            ? Colors.transparent
            : Theme.of(context).colorScheme.surface,
        body: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header ──────────────────────────────────────────────
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(PhosphorIconsFill.flask, size: 24, color: primary),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      calibrationModelName,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: primary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              if (resinProfileName != null) ...[
                const SizedBox(height: 6),
                Text(
                  resinProfileName!,
                  style: TextStyle(
                    fontSize: 16,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.5),
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 20),

              // ── Body ─────────────────────────────────────────────────
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Left – What's happening
                    Expanded(
                      child: GlassCard(
                        outlined: true,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                FlutterI18n.translate(
                                        context, 'calibration.whatWillHappen')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.55),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                '$testPiecesCount ${FlutterI18n.translate(context, 'calibration.testPiecesExplanation')}',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.75),
                                  height: 1.55,
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildStatRow(
                                context,
                                icon: Icon(PhosphorIcons.timer()),
                                label: FlutterI18n.translate(
                                    context, 'calibration.startingExposure'),
                                value:
                                    '${startingExposure.toStringAsFixed(1)} s',
                                primary: primary,
                              ),
                              const SizedBox(height: 10),
                              _buildStatRow(
                                context,
                                icon: Icon(PhosphorIcons.arrowRight()),
                                label: FlutterI18n.translate(
                                    context, 'calibration.stepBetween'),
                                value:
                                    '+${exposureIncrement.toStringAsFixed(1)} s',
                                primary: primary,
                              ),
                              const SizedBox(height: 10),
                              _buildStatRow(
                                context,
                                icon: Icon(PhosphorIcons.arrowLineRight()),
                                label: FlutterI18n.translate(
                                    context, 'calibration.finalExposure'),
                                value:
                                    '${(startingExposure + exposureIncrement * (testPiecesCount - 1)).toStringAsFixed(1)} s',
                                primary: primary,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Right – Pre-flight checklist
                    Expanded(
                      child: GlassCard(
                        outlined: true,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Text(
                                FlutterI18n.translate(
                                        context, 'calibration.preFlightCheck')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.55),
                                  letterSpacing: 1.2,
                                ),
                              ),
                              Expanded(
                                child: Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    _buildChecklistItem(
                                        context,
                                        FlutterI18n.translate(
                                            context, 'calibration.checkResin')),
                                    _buildChecklistItem(
                                        context,
                                        FlutterI18n.translate(
                                            context, 'calibration.checkPlate')),
                                    _buildChecklistItem(
                                        context,
                                        FlutterI18n.translate(
                                            context, 'calibration.checkVat')),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── Action buttons ────────────────────────────────────────
              Row(
                children: [
                  Expanded(
                    child: GlassButton(
                      tint: GlassButtonTint.negative,
                      onPressed: () => Navigator.of(context).pop(false),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 65),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(PhosphorIcons.x(), size: 20),
                          const SizedBox(width: 10),
                          Text(FlutterI18n.translate(context, 'common.cancel'),
                              style: TextStyle(fontSize: 20)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: GlassButton(
                      tint: GlassButtonTint.positive,
                      onPressed: () => Navigator.of(context).pop(true),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 65),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                              FlutterI18n.translate(
                                  context, 'calibration.startPrint'),
                              style: TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                          Icon(PhosphorIcons.play(), size: 20),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatRow(
    BuildContext context, {
    required Widget icon,
    required String label,
    required String value,
    required Color primary,
  }) {
    return Row(
      children: [
        IconTheme(
          data: IconThemeData(
            size: 18,
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
          ),
          child: icon,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 15,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: primary,
          ),
        ),
      ],
    );
  }

  Widget _buildChecklistItem(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: Colors.green.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            PhosphorIconsFill.checkCircle,
            size: 20,
            color: Colors.green.shade400,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.85),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
