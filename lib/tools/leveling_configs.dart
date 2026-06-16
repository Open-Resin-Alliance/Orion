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

  const LevelingWorkflowStep({
    required this.id,
    required this.endpoint,
    required this.titleKey,
    required this.instructionKey,
    required this.icon,
    this.imagePath,
    this.kind = LevelingWorkflowStepKind.probe,
  });
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
