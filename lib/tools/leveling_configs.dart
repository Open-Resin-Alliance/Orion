/*
* Orion - Leveling Configs
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
import 'package:phosphor_flutter/phosphor_flutter.dart';

enum LevelingWorkflowStepKind {
  prepare,
  probe,
  finalOffset,
}

class LevelingWorkflowStep {
  final String id;
  final String endpoint;
  final String titleKey;
  final String instructionKey;
  final String? imagePath;
  final IconData icon;
  final LevelingWorkflowStepKind kind;

  /// Custom running title shown during execution (null = default per kind)
  final String? runningTitle;

  /// Custom step title override (null = use titleKey i18n)
  final String? stepTitle;

  /// Custom instruction override (null = use instructionKey i18n)
  final String? stepInstruction;

  /// Intermediate screen to show after completion:
  /// null = none, 'loosen', 'tighten', 'allCorners'
  final String? intermediateScreen;

  /// Special screen to fire on each completion:
  /// null = none, 'center', 'corner-0'..'corner-3'
  final String? specialScreen;

  /// If true, auto-advance to next step after completion
  final bool autoAdvance;

  /// Display label for corner steps (e.g. 'Front Left')
  final String? cornerLabel;

  /// If true, skip the backend endpoint call and mark the step as
  /// complete immediately (for informational/intermediate screens).
  final bool skipBackend;

  const LevelingWorkflowStep({
    required this.id,
    required this.endpoint,
    required this.titleKey,
    required this.instructionKey,
    required this.icon,
    this.imagePath,
    this.kind = LevelingWorkflowStepKind.probe,
    this.runningTitle,
    this.stepTitle,
    this.stepInstruction,
    this.intermediateScreen,
    this.specialScreen,
    this.autoAdvance = false,
    this.cornerLabel,
    this.skipBackend = false,
  });

  /// Create a copy with selected fields overridden.
  LevelingWorkflowStep copyWith({
    String? runningTitle,
    String? stepTitle,
    String? stepInstruction,
    String? intermediateScreen,
    String? specialScreen,
    bool? autoAdvance,
    String? cornerLabel,
    bool? skipBackend,
  }) {
    return LevelingWorkflowStep(
      id: id,
      endpoint: endpoint,
      titleKey: titleKey,
      instructionKey: instructionKey,
      icon: icon,
      imagePath: imagePath,
      kind: kind,
      runningTitle: runningTitle ?? this.runningTitle,
      stepTitle: stepTitle ?? this.stepTitle,
      stepInstruction: stepInstruction ?? this.stepInstruction,
      intermediateScreen: intermediateScreen ?? this.intermediateScreen,
      specialScreen: specialScreen ?? this.specialScreen,
      autoAdvance: autoAdvance ?? this.autoAdvance,
      cornerLabel: cornerLabel ?? this.cornerLabel,
      skipBackend: skipBackend ?? this.skipBackend,
    );
  }
}

class LevelingVariant {
  final String id;
  final String label;
  final String description;
  final String? assetPath;
  final IconData? icon;
  final String finalEndpoint;
  final String successKey;

  const LevelingVariant({
    required this.id,
    required this.label,
    required this.description,
    required this.finalEndpoint,
    required this.successKey,
    this.assetPath,
    this.icon,
  });

  List<LevelingWorkflowStep> buildSteps() {
    // Stage 1 (initial seating + offset) — common to all variants
    final stage1 = <LevelingWorkflowStep>[
      // 0: Prepare — shows loosen intermediate
      athena2BaseWorkflowSteps[0].copyWith(
        intermediateScreen: 'loosen',
      ),
      // 1: Initial leveling — shows tighten intermediate
      athena2BaseWorkflowSteps[1].copyWith(
        stepTitle: 'Initial Leveling',
        stepInstruction: 'The plate will move towards the build plate.',
        intermediateScreen: 'tighten',
      ),
      // 2: Calibrating Offset
      LevelingWorkflowStep(
        id: finalEndpoint,
        endpoint: finalEndpoint,
        titleKey: 'levelingWorkflow.finalOffsetTitle',
        instructionKey: finalEndpoint == 'probe_standardarm'
            ? 'levelingWorkflow.standardArmInstruction'
            : 'levelingWorkflow.offsetInstruction',
        icon: PhosphorIcons.crosshair(),
        kind: LevelingWorkflowStepKind.finalOffset,
        stepTitle: 'Calibrating Offset',
        stepInstruction: 'Saving the calibrated Z offset.',
        runningTitle: 'Calibrating Offset',
        autoAdvance: true,
      ),
    ];

    // Regular build arm: done after stage 1 (no adjustable corner screws)
    if (id != 'pro') return stage1;

    // Pro build arm: Stage 2 adds 4-corner fine leveling
    final cornerDefs = [
      ('Front Left', 'front-left'),
      ('Front Right', 'front-right'),
      ('Back Right', 'back-right'),
      ('Back Left', 'back-left'),
    ];
    final result = <LevelingWorkflowStep>[
      ...stage1,
      // ── Stage 2: 4-corner fine leveling ──
      for (int i = 0; i < 4; i++) ...[
        LevelingWorkflowStep(
          id: 'fine_prepare_${i + 1}',
          endpoint: 'probe_corner_prepare',
          titleKey: 'levelingWorkflow.cornerPrepareTitle',
          instructionKey: 'levelingWorkflow.cornerPrepareInstruction',
          icon: [
            PhosphorIcons.arrowDownLeft(),
            PhosphorIcons.arrowDownRight(),
            PhosphorIcons.arrowUpRight(),
            PhosphorIcons.arrowUpLeft(),
          ][i],
          kind: LevelingWorkflowStepKind.prepare,
          stepTitle: 'Place Calibration Puck',
          stepInstruction:
              'Please place the Leveling Puck in the ${cornerDefs[i].$1} corner',
          specialScreen: 'corner-$i',
        ),
        LevelingWorkflowStep(
          id: 'fine_corner_${i + 1}',
          endpoint: 'probe_corner',
          titleKey: 'levelingWorkflow.cornerTitle',
          instructionKey: 'levelingWorkflow.cornerInstruction',
          icon: PhosphorIconsFill.crosshair,
          kind: LevelingWorkflowStepKind.probe,
          stepTitle: 'Corner: ${cornerDefs[i].$1}',
          stepInstruction: 'Please put the Leveling Puck at the position '
              'indicated on the screen.',
          runningTitle: 'Probing ${cornerDefs[i].$1} Corner',
          cornerLabel: cornerDefs[i].$1,
          autoAdvance:
              i < 3, // auto-advance to next prepare; last shows results
        ),
      ],
      // ── Stage 3: Corner results, remove puck, re-calibrate offset ──
      LevelingWorkflowStep(
        id: 'corner_results',
        endpoint: '',
        titleKey: '',
        instructionKey: '',
        icon: PhosphorIconsFill.checkCircle,
        kind: LevelingWorkflowStepKind.probe,
        skipBackend: true,
        intermediateScreen: 'allCorners',
      ),
      LevelingWorkflowStep(
        id: 'remove_puck',
        endpoint: '',
        titleKey: '',
        instructionKey: '',
        icon: PhosphorIconsFill.hand,
        kind: LevelingWorkflowStepKind.prepare,
        skipBackend: true,
        intermediateScreen: 'removePuck',
      ),
      LevelingWorkflowStep(
        id: 'final_prepare',
        endpoint: 'probe_prepare',
        titleKey: 'levelingWorkflow.prepareTitle',
        instructionKey: 'levelingWorkflow.prepareInstruction',
        icon: PhosphorIconsFill.house,
        kind: LevelingWorkflowStepKind.prepare,
        autoAdvance: true,
      ),
      LevelingWorkflowStep(
        id: '${finalEndpoint}_final',
        endpoint: finalEndpoint,
        titleKey: 'levelingWorkflow.finalOffsetTitle',
        instructionKey: 'levelingWorkflow.offsetInstruction',
        icon: PhosphorIcons.crosshair(),
        kind: LevelingWorkflowStepKind.finalOffset,
        stepTitle: 'Final Calibration',
        stepInstruction: 'Re-calibrating the Z offset.',
        runningTitle: 'Final Calibration',
        autoAdvance: true,
      ),
    ];
    return result;
  }
}

class LevelingConfig {
  final String machineIdPrefix;
  final List<String> checklistKeys;
  final List<LevelingVariant> variants;

  const LevelingConfig({
    required this.machineIdPrefix,
    required this.checklistKeys,
    required this.variants,
  });
}

const List<LevelingWorkflowStep> athena2BaseWorkflowSteps = [
  LevelingWorkflowStep(
    id: 'probe_prepare',
    endpoint: 'probe_prepare',
    titleKey: 'levelingWorkflow.prepareTitle',
    instructionKey: 'levelingWorkflow.prepareInstruction',
    icon: PhosphorIconsFill.house,
    kind: LevelingWorkflowStepKind.prepare,
  ),
  LevelingWorkflowStep(
    id: 'probe_screen',
    endpoint: 'probe_screen',
    titleKey: 'levelingWorkflow.screenTitle',
    instructionKey: 'levelingWorkflow.screenInstruction',
    icon: PhosphorIconsFill.crosshair,
  ),
  LevelingWorkflowStep(
    id: 'probe_corner_prepare',
    endpoint: 'probe_corner_prepare',
    titleKey: 'levelingWorkflow.cornerPrepareTitle',
    instructionKey: 'levelingWorkflow.cornerPrepareInstruction',
    icon: PhosphorIconsFill.house,
    kind: LevelingWorkflowStepKind.prepare,
  ),
  LevelingWorkflowStep(
    id: 'probe_corner',
    endpoint: 'probe_corner',
    titleKey: 'levelingWorkflow.cornerTitle',
    instructionKey: 'levelingWorkflow.cornerInstruction',
    icon: PhosphorIconsFill.crosshair,
  ),
  LevelingWorkflowStep(
    id: 'probe_levelcheck',
    endpoint: 'probe_levelcheck',
    titleKey: 'levelingWorkflow.levelCheckTitle',
    instructionKey: 'levelingWorkflow.levelCheckInstruction',
    icon: PhosphorIconsFill.checkCircle,
  ),
];

const List<LevelingConfig> levelingConfigs = [
  LevelingConfig(
    machineIdPrefix: 'Athena2',
    checklistKeys: [
      'leveling.removeVat',
      'leveling.checkHexKeys',
      'leveling.checkInstallPlate',
      'leveling.checkLcdClean',
    ],
    variants: [
      LevelingVariant(
        id: 'regular',
        label: 'Regular Build Arm',
        description: 'Athena 2 standard build arm.',
        assetPath: 'assets/images/concepts_3d/a2_standard_arm.svg',
        icon: PhosphorIconsFill.wrench,
        finalEndpoint: 'probe_standardarm',
        successKey: 'levelingWorkflow.standardArmSuccess',
      ),
      LevelingVariant(
        id: 'pro',
        label: 'Pro Build Arm',
        description: 'Improved leveling & latching mechanism.',
        assetPath: 'assets/images/concepts_3d/a2_pro_arm.svg',
        icon: PhosphorIconsFill.star,
        finalEndpoint: 'probe_offset',
        successKey: 'levelingWorkflow.offsetSuccess',
      ),
    ],
  ),
];

LevelingConfig? getLevelingConfigForMachine(String machineModel) {
  try {
    return levelingConfigs.firstWhere(
      (config) => machineModel.startsWith(config.machineIdPrefix),
    );
  } catch (_) {
    return null;
  }
}
