#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
path = ROOT / 'lib/data/plan_time_sequential_cascade.dart'
text = path.read_text(encoding='utf-8')
old = '''    final primaryDur = planWallDurationMinutesForCascade(
      primaryTask,
      resolveDurationMinutes: resolveDurationMinutes,
    );
    final primaryHadEnd =
        targetIntent.draggedHadEnd || primaryTask.endDateTime != null;
    final anchorSchedule = computeTimeViewTargetDropSchedule(
      targetStartWall: targetIntent.targetStartWall,
      targetEndWall: targetIntent.targetEndWall,
      draggedDurationMinutes: primaryDur,
      insertBefore: targetIntent.insertBefore,
      draggedHadEnd: primaryHadEnd,
    );
    final anchorStart = anchorSchedule.startWall;
'''
new = '''    final primaryDur = planWallDurationMinutesForCascade(
      primaryTask,
      resolveDurationMinutes: resolveDurationMinutes,
    );
    final primaryHadEnd =
        targetIntent.draggedHadEnd || primaryTask.endDateTime != null;

    // A multi-selection is one rigid time block. Anchor the block boundary to
    // the target, not just the primary card, otherwise a primary that is not
    // the earliest selected card makes the explicit cascade squeeze the group
    // and reject the drop with `bulkRelativeOffsetsChanged`.
    late final DateTime anchorStart;
    if (draggedPlanIds.length > 1) {
      var minOffset = 0;
      var maxEndOffset = primaryDur;
      for (final id in draggedPlanIds) {
        final offset = offsets[id]!;
        PlanningTask? member;
        for (final candidate in working) {
          if (candidate.planRowIdForBackend == id) {
            member = candidate;
            break;
          }
        }
        if (member == null) {
          return const TimeViewInsertionCascadeResult(
            accepted: false,
            blockedReason: 'bulkScheduleMissing',
          );
        }
        final duration = planWallDurationMinutesForCascade(
          member,
          resolveDurationMinutes: resolveDurationMinutes,
        );
        minOffset = math.min(minOffset, offset);
        maxEndOffset = math.max(maxEndOffset, offset + duration);
      }
      anchorStart = targetIntent.insertBefore
          ? targetIntent.targetStartWall.subtract(
              Duration(minutes: maxEndOffset),
            )
          : targetIntent.targetEndWall.subtract(
              Duration(minutes: minOffset),
            );
    } else {
      final anchorSchedule = computeTimeViewTargetDropSchedule(
        targetStartWall: targetIntent.targetStartWall,
        targetEndWall: targetIntent.targetEndWall,
        draggedDurationMinutes: primaryDur,
        insertBefore: targetIntent.insertBefore,
        draggedHadEnd: primaryHadEnd,
      );
      anchorStart = anchorSchedule.startWall;
    }
'''
count = text.count(old)
if count != 1:
    raise SystemExit(f'expected one target anchor block, found {count}')
path.write_text(text.replace(old, new, 1), encoding='utf-8')
print('Applied rigid bulk target anchoring fix.')
