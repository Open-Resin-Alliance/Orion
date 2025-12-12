/*
* Orion - Leveling Configs
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
import 'package:phosphor_flutter/phosphor_flutter.dart';

class LevelingStep {
  final String videoPath;
  final String text;

  const LevelingStep({
    required this.videoPath,
    required this.text,
  });
}

class LevelingGuide {
  final List<LevelingStep> steps;

  const LevelingGuide({
    required this.steps,
  });
}

class LevelingVariant {
  final String id;
  final String label;
  final String description;
  final String? assetPath;
  final IconData? icon;
  final LevelingGuide? guide;

  const LevelingVariant({
    required this.id,
    required this.label,
    required this.description,
    this.assetPath,
    this.icon,
    this.guide,
  });
}

class LevelingConfig {
  final String machineIdPrefix;
  final List<LevelingVariant> variants;

  const LevelingConfig({
    required this.machineIdPrefix,
    required this.variants,
  });
}

const List<LevelingConfig> levelingConfigs = [
  LevelingConfig(
    machineIdPrefix: 'Athena2',
    variants: [
      LevelingVariant(
        id: 'regular',
        label: 'Regular Build Arm',
        description: 'Athena 2 standard build arm.',
        assetPath: 'assets/images/concepts_3d/a2_standard_arm.svg',
        icon: PhosphorIconsFill.wrench,
        guide: LevelingGuide(
          steps: [
            LevelingStep(
              videoPath: 'assets/videos/concepts_3d/athena2_regular_step1.mp4',
              text:
                  'Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua.',
            ),
            LevelingStep(
              videoPath: 'assets/videos/concepts_3d/athena2_regular_step2.mp4',
              text:
                  'Gently press down on the build plate to ensure it is flat against the LCD screen. Tighten the screws in a cross pattern.',
            ),
          ],
        ),
      ),
      LevelingVariant(
        id: 'pro',
        label: 'Pro Build Arm',
        description: 'Improved leveling & latching mechanism.',
        assetPath: 'assets/images/concepts_3d/a2_pro_arm.svg',
        icon: PhosphorIconsFill.star,
        guide: LevelingGuide(
          steps: [
            LevelingStep(
              videoPath: 'assets/videos/concepts_3d/athena2_pro_step1.mp4',
              text:
                  'Unlock the latch on the top of the build arm. The plate should be loose and able to self-level against the screen.',
            ),
            LevelingStep(
              videoPath: 'assets/videos/concepts_3d/athena2_pro_step2.mp4',
              text:
                  'With the plate resting on the screen, lock the latch firmly. Verify that the plate does not shift during locking.',
            ),
          ],
        ),
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
