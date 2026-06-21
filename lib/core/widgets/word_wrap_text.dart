import 'package:flutter/material.dart';

class WordWrapText extends StatelessWidget {
  const WordWrapText(
    this.text, {
    super.key,
    this.style,
    this.textAlign = TextAlign.start,
    this.spacing = 4,
    this.runSpacing = 0,
  });

  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.length <= 1) {
      return Text(text, style: style, textAlign: textAlign);
    }

    return Wrap(
      alignment: switch (textAlign) {
        TextAlign.center => WrapAlignment.center,
        TextAlign.right || TextAlign.end => WrapAlignment.end,
        _ => WrapAlignment.start,
      },
      spacing: spacing,
      runSpacing: runSpacing,
      children: [
        for (final word in words)
          Text(word, style: style, textAlign: textAlign),
      ],
    );
  }
}
