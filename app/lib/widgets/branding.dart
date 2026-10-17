import 'package:flutter/material.dart';
import 'media_image.dart';

const feelfreeHeadingStyle = TextStyle(
  fontFamily: 'Feelfree',
  fontWeight: FontWeight.w400,
  letterSpacing: 0,
  height: 1.2,
);

/// Display the supplied lettering without its large transparent canvas margins.
class BrandWordmark extends StatelessWidget {
  const BrandWordmark({super.key, this.width = 154, this.color});
  final double width;
  final Color? color;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Undertune',
    image: true,
    child: SizedBox(
      width: width,
      height: width / 3,
      child: ClipRect(
        child: Image.asset(
          'assets/branding/wordmark.webp',
          cacheWidth: artworkDecodeWidth(context, width),
          fit: BoxFit.cover,
          alignment: const Alignment(0, .25),
          color: color ?? Theme.of(context).colorScheme.onSurface,
          excludeFromSemantics: true,
          filterQuality: FilterQuality.medium,
        ),
      ),
    ),
  );
}

/// The supplied personal-use display font has decorative replacement glyphs
/// for digits. Keep its lettering while rendering numbers and other scripts
/// with the app's normal font, so provider titles remain readable.
class MediaHeading extends StatelessWidget {
  const MediaHeading(
    this.text, {
    super.key,
    this.fontSize = 44,
    this.maxLines = 3,
  });
  final String text;
  final double fontSize;
  final int maxLines;
  @override
  Widget build(BuildContext context) => Text.rich(
    TextSpan(
      children: [
        for (final run in RegExp(r'[A-Za-z ]+|[^A-Za-z ]+').allMatches(text))
          TextSpan(
            text: run.group(0),
            style: RegExp(r'^[A-Za-z ]+$').hasMatch(run.group(0)!)
                ? null
                : TextStyle(
                    fontFamily:
                        Theme.of(context).textTheme.bodyMedium?.fontFamily ??
                        'Roboto',
                    fontSize: fontSize * .76,
                  ),
          ),
      ],
    ),
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    style: feelfreeHeadingStyle.copyWith(fontSize: fontSize),
  );
}
