/*
* Orion - Live print countdown label
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_i18n/flutter_i18n.dart';
import 'package:provider/provider.dart';

import 'package:orion/backend_service/providers/status_provider.dart';

/// Remaining print time of the active job, as HH:MM:SS.
///
/// The backend only sends a status snapshot when something changes, so this
/// rebuilds once a second to keep the countdown ticking in between (see
/// [StatusProvider.remainingPrintTime]). Only this text rebuilds, never the
/// screen around it. Shows the "not available" placeholder when no print is
/// running or the backend reported nothing to estimate from.
class TimeRemainingText extends StatefulWidget {
  const TimeRemainingText({super.key, this.style});

  /// Style for the countdown; defaults to the ambient text style.
  final TextStyle? style;

  @override
  State<TimeRemainingText> createState() => _TimeRemainingTextState();
}

class _TimeRemainingTextState extends State<TimeRemainingText> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remaining =
        context.watch<StatusProvider>().formattedRemainingPrintTime;
    return Text(
      remaining ?? FlutterI18n.translate(context, 'status.na'),
      style: widget.style,
    );
  }
}
