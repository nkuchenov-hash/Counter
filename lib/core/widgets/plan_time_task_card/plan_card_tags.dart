import 'package:counter/core/tag_contrast.dart';
import 'package:counter/core/widgets/chip_component.dart';
import 'package:counter/core/widgets/plan_time_task_card/plan_card_geometry.dart';
import 'package:counter/data/models.dart';
import 'package:flutter/material.dart';

/// Time View tag row — every tag visible (horizontal scroll, never +N).
class TimeViewTagsRow extends StatelessWidget {
  const TimeViewTagsRow({required this.tags, this.trailing});

  final List<Tag> tags;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty && trailing == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: PlanCardGeom.tagRowHeight,
      child: Row(
        children: [
          if (tags.isNotEmpty)
            Expanded(
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                itemCount: tags.length,
                separatorBuilder: (_, _) =>
                    const SizedBox(width: PlanCardGeom.tagGap),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return CategoryChip(
                    mode: CategoryDisplayMode.letterChip,
                    label: tag.name.trim().isNotEmpty
                        ? tag.name.trim()
                        : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}',
                    color: parseTagHexColor(tag.color) ?? scheme.primary,
                    icon: iconForTagKey(tag.icon),
                    compactGlyphLayout: true,
                    syntheticNoTagsMonochrome: tag.tagId == -1,
                  );
                },
              ),
            )
          else
            const Spacer(),
          if (trailing != null) ...[const SizedBox(width: 6), trailing!],
        ],
      ),
    );
  }
}

/// VerySmall tag column — compact CardPlan pills stacked vertically (ref).
class TimeViewTagStack extends StatelessWidget {
  const TimeViewTagStack({required this.tags});

  final List<Tag> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 80),
      child: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < tags.length; i++) ...[
              if (i > 0) const SizedBox(height: 1),
              TimeViewCompactTagPill(tag: tags[i], scheme: scheme),
            ],
          ],
        ),
      ),
    );
  }
}

/// Compact CardPlan tag pill for minimum-density Time View (16px, readable).
class TimeViewCompactTagPill extends StatelessWidget {
  const TimeViewCompactTagPill({required this.tag, required this.scheme});

  final Tag tag;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final color = parseTagHexColor(tag.color) ?? scheme.primary;
    final plate = tagLetterChipPlate(color, scheme.surface);
    final fg = tagVibrantForeground(color);
    final label = tag.name.trim().isNotEmpty
        ? tag.name.trim()
        : '#${tag.tagId != 0 ? tag.tagId : tag.wrapperRowId}';
    return Container(
      height: PlanCardGeom.tagRowHeight,
      padding: const EdgeInsets.symmetric(horizontal: 5),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: plate,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: tagLetterChipBorder(color, scheme.surface)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 10,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}
