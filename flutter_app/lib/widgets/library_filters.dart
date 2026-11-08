import 'package:flutter/material.dart';

/// 0 表示未评分，null 表示不限制；实际评分仍为 1～10 分。
bool matchesRating(int? rating, int? minimum) =>
    minimum == null ||
    (minimum == 0 ? rating == null : rating != null && rating >= minimum);

class LibraryFilters extends StatelessWidget {
  const LibraryFilters({
    super.key,
    required this.tags,
    required this.tag,
    required this.minimumRating,
    required this.onTagChanged,
    required this.onRatingChanged,
    required this.onReset,
    this.ratingLabel = '评分',
  });

  final List<String> tags;
  final String? tag;
  final int? minimumRating;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<int?> onRatingChanged;
  final VoidCallback onReset;
  final String ratingLabel;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: LayoutBuilder(builder: (context, constraints) {
          final width = constraints.maxWidth < 400
              ? constraints.maxWidth
              : (constraints.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 10, children: [
            SizedBox(
              width: width,
              child: DropdownButtonFormField<String>(
                key: const Key('tag-filter'),
                // ignore: deprecated_member_use
                value: tag,
                isExpanded: true,
                decoration:
                    const InputDecoration(labelText: '标签', isDense: true),
                hint: const Text('全部标签'),
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('全部标签')),
                  for (final name in tags)
                    DropdownMenuItem(
                        value: name.toLowerCase(),
                        child: Text(name,
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: onTagChanged,
              ),
            ),
            SizedBox(
              width: width,
              child: DropdownButtonFormField<int>(
                key: const Key('rating-filter'),
                // ignore: deprecated_member_use
                value: minimumRating,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: ratingLabel, isDense: true),
                hint: const Text('全部评分'),
                items: [
                  const DropdownMenuItem<int>(value: null, child: Text('全部评分')),
                  const DropdownMenuItem(value: 0, child: Text('未评分')),
                  for (var rating = 1; rating <= 10; rating++)
                    DropdownMenuItem(
                        value: rating,
                        child: Text('$rating 分及以上',
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: onRatingChanged,
              ),
            ),
            if (tag != null || minimumRating != null)
              TextButton.icon(
                key: const Key('reset-library-filters'),
                onPressed: onReset,
                icon: const Icon(Icons.filter_alt_off_outlined, size: 16),
                label: const Text('重置标签与评分'),
              ),
          ]);
        }),
      );
}
