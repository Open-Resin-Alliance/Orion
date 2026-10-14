/*
* Orion - Safe Home Utility
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
import 'package:orion/backend_service/athena_iot/models/athena_kinematic_status.dart';
import 'package:orion/backend_service/providers/manual_provider.dart';
import 'package:orion/backend_service/providers/status_provider.dart';
import 'package:provider/provider.dart';

/// How often the settle poll samples the controller's Z position.
const _settleInterval = Duration(milliseconds: 400);

/// How many samples the settle poll takes before giving up (about 16 s).
const _settleAttempts = 40;

/// Two consecutive position reads closer than this mean the axis has
/// stopped travelling.
const _settleToleranceMm = 0.05;

/// Homes the Z axis and waits until the controller confirms the axis has
/// physically stopped moving.
///
/// Klipper reports the homing command as complete as soon as it's received,
/// before the axis finishes moving.  This polls [StatusProvider]'s kinematic
/// status after the command completes so callers can safely chain further
/// movement commands without racing the axis.
Future<bool> safeHome(BuildContext context) async {
  final manual = Provider.of<ManualProvider>(context, listen: false);
  final ok = await manual.manualHome();
  if (!ok || !context.mounted) return ok;
  return safeHomePoll(context);
}

/// Polls [StatusProvider]'s kinematic status after a move command has
/// already been issued (e.g. by a backend prepare step).  Use this when
/// you only need to wait for the axis to settle, without triggering a
/// new move.
///
/// A single successful read only proves the API answered — the axis can
/// still be travelling.  This samples the reported position until two
/// fresh reads agree, which is what actually says the plate has stopped.
/// Backends that never report a fresh reading (no kinematic endpoint)
/// return straight away, exactly as before.
Future<bool> safeHomePoll(BuildContext context) async {
  final statusProvider =
      Provider.of<StatusProvider>(context, listen: false);
  AthenaKinematicStatus? previous;
  var freshReads = 0;
  for (var attempt = 0; attempt < _settleAttempts; attempt++) {
    if (attempt > 0) {
      await Future.delayed(_settleInterval);
      if (!context.mounted) return false;
    }
    final status = await statusProvider.refreshKinematicStatus(maxAttempts: 1);
    if (status == null) {
      // Nothing to compare against.
      return true;
    }
    // The provider hands back the same instance when a fetch failed, so a
    // new object is the proof that this sample came off the controller.
    final fresh = !identical(status, previous);
    if (fresh && previous != null) {
      if ((status.position - previous.position).abs() <= _settleToleranceMm) {
        return true;
      }
    }
    if (!fresh && freshReads == 0) {
      // This backend answers with a cached reading; polling it further
      // cannot tell us anything new.
      return true;
    }
    if (fresh) freshReads++;
    previous = status;
  }
  return false;
}

/// Moves the Z axis to the floor and waits until the controller confirms
/// the axis has physically stopped.  Like [safeHome], this polls kinematic
/// status after the move command to cover the Klipper race.
Future<bool> safeFloor(BuildContext context) async {
  final manual = Provider.of<ManualProvider>(context, listen: false);
  final ok = await manual.moveToFloor();
  if (!ok || !context.mounted) return ok;
  return safeHomePoll(context);
}

/// Moves the Z axis to the top and waits until the controller confirms
/// the axis has physically stopped.
Future<bool> safeTop(BuildContext context) async {
  final manual = Provider.of<ManualProvider>(context, listen: false);
  final ok = await manual.moveToTop();
  if (!ok || !context.mounted) return ok;
  return safeHomePoll(context);
}
