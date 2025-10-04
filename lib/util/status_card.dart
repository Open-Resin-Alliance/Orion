/*
* Orion - Status Card
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

import 'package:orion/glasser/glasser.dart';
import 'package:orion/backend_service/odyssey/models/status_models.dart';

class StatusCard extends StatefulWidget {
  final bool isCanceling;
  final bool isPausing;
  final double progress;
  final Color statusColor;
  final StatusModel? status;

  const StatusCard({
    super.key,
    required this.isCanceling,
    required this.isPausing,
    required this.progress,
    required this.statusColor,
    required this.status,
  });

  @override
  StatusCardState createState() => StatusCardState();
}

class StatusCardState extends State<StatusCard> {
  Icon cardIcon = const Icon(Icons.help);

  @override
  Widget build(BuildContext context) {
    final s = widget.status;
    // Determine whether a finished snapshot actually indicates a successful
    // completion or a cancellation. Some backends (NanoDLP) do not provide
    // an explicit 'finished' flag; when a snapshot shows idle with a layer
    // but the progress is not 100% we should treat this as a cancel.
    final bool finishedSnapshot = s != null && s.isIdle && s.layer != null;
    final bool effectivelyFinished =
        finishedSnapshot && (widget.progress >= 0.999);

    if (effectivelyFinished) {
      cardIcon = const Icon(Icons.check);
    } else if (widget.isCanceling ||
        (s?.layer == null) ||
        (finishedSnapshot && !effectivelyFinished)) {
      // show stop when actively canceling, when there's no layer (canceled),
      // or when a finished-looking snapshot has progress < 100% (treat as canceled)
      cardIcon = const Icon(Icons.stop);
    } else if (widget.isPausing || s?.isPaused == true) {
      cardIcon = const Icon(Icons.pause);
    }

    // Determine what to show in the progress circle:
    // null = spinning circle (indeterminate)
    // 1.0 = full circle (completed/canceled)
    // widget.progress = current progress (static)

    bool showSpinner = false;
    bool showFullCircle = false;

    // Only show spinner when actively transitioning from printing state
    if (widget.isPausing && s?.isPaused != true) {
      showSpinner = true; // Actively pausing from printing
    } else if (widget.isCanceling &&
        !widget
            .isPausing && // Key: if isPausing is false when canceling, we're canceling from active print
        s?.isPaused != true &&
        s?.layer != null) {
      showSpinner = true; // Actively canceling from printing (not from paused)
    }

    // Show full circle when canceled or canceling from paused. Also treat
    // a finished-looking snapshot with progress < 100% as canceled (full).
    if (s?.layer == null) {
      showFullCircle = true; // Already canceled
    } else if (widget.isCanceling && widget.isPausing) {
      showFullCircle = true; // Canceling from paused state
    } else if (finishedSnapshot && !effectivelyFinished) {
      showFullCircle = true; // Treated as canceled because progress < 100%
    }

    // If we determined a finished-looking snapshot is actually a cancel
    // (progress < 100%), render using the error/canceled color so the
    // progress ring and icon match the stop semantics.
    final effectiveStatusColor = (finishedSnapshot && !effectivelyFinished)
        ? Theme.of(context).colorScheme.error
        : widget.statusColor;

    final circleProgress = showSpinner
        ? null
        : showFullCircle
            ? 1.0
            : widget.progress;

    // If the print is active, not paused, canceled or finished, it is active.
    final isActive = (widget.isPausing == false &&
        widget.isCanceling == false &&
        s?.layer != null &&
        s?.isPaused != true &&
        s?.isIdle != true);

    // While the print is active, show the progress in percentage. (overlapping text for outline effect)
    return isActive
        ? Stack(
            children: <Widget>[
              Text(
                '${(widget.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 75,
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 5
                    ..color = Theme.of(context).colorScheme.primaryContainer,
                ),
              ),
              Text(
                '${(widget.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 75,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          )
        : Builder(
            builder: (context) {
              return GlassCard(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(2.0),
                  child: Stack(
                    children: [
                      Positioned(
                        top: 0,
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            value: circleProgress,
                            strokeWidth: 6,
                            valueColor: AlwaysStoppedAnimation<Color>(
                                effectiveStatusColor),
                            backgroundColor:
                                effectiveStatusColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(25),
                        child: Icon(
                          cardIcon.icon,
                          color: effectiveStatusColor,
                          size: 70,
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
  }
}
