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
    if (id != 'pro') {
      // Regular variant: keep original single-corner flow
      return [
        ...athena2BaseWorkflowSteps,
        LevelingWorkflowStep(
          id: finalEndpoint,
          endpoint: finalEndpoint,
          titleKey: 'levelingWorkflow.finalOffsetTitle',
          instructionKey: finalEndpoint == 'probe_standardarm'
              ? 'levelingWorkflow.standardArmInstruction'
              : 'levelingWorkflow.offsetInstruction',
          icon: PhosphorIcons.crosshair(),
          kind: LevelingWorkflowStepKind.finalOffset,
        ),
      ];
    }

    // Pro variant: Stage 1 (initial seating + offset) + Stage 2 (fine leveling)
    final cornerDefs = [
      ('Front Left', 'front-left'),
      ('Front Right', 'front-right'),
      ('Back Right', 'back-right'),
      ('Back Left', 'back-left'),
    ];
    final result = <LevelingWorkflowStep>[
      // ── Stage 1 ──
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
      // ── Stage 2: 4-corner fine leveling ──
      for (int i = 0; i < 4; i++) ...[
        LevelingWorkflowStep(
          id: 'fine_prepare_${i + 1}',
          endpoint: 'probe_corner_prepare',
          titleKey: 'levelingWorkflow.cornerPrepareTitle',
          instructionKey: 'levelingWorkflow.cornerPrepareInstruction',
          icon: PhosphorIconsFill.house,
          kind: LevelingWorkflowStepKind.prepare,
          stepTitle: 'Preparing Corner Measurement',
          stepInstruction: 'The printer will move to a home position. '
              'Please ensure you have the Leveling Puck ready.',
          autoAdvance: true,
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
    ];
    // Mark the last corner probe to show measurements
    final lastCornerIdx = result.length - 1;
    result[lastCornerIdx] = result[lastCornerIdx].copyWith(
      intermediateScreen: 'allCorners',
    );
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
