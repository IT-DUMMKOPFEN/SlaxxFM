import 'package:flutter/material.dart';

/// Colours taken from the SlaxxFM logo.
const Color kBrandDeep = Color(0xFF071226); // background behind the logo
const Color kBrandNavy = Color(0xFF0D2547); // logo tile
const Color kBrandBlue = Color(0xFF2F7FCF); // wave
const Color kBrandSky = Color(0xFF7CC4F2); // light wave / glow
const Color kBrandSilver = Color(0xFFC9D4E0); // radio body
const Color kBrandSteel = Color(0xFF8FA9C8); // "FM"

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  var scheme = ColorScheme.fromSeed(seedColor: kBrandBlue, brightness: b);
  scheme = scheme.copyWith(
    primary: dark ? kBrandSky : kBrandBlue,
    onPrimary: dark ? kBrandDeep : Colors.white,
    primaryContainer: dark ? const Color(0xFF1B4A80) : const Color(0xFFD3E6FA),
    onPrimaryContainer: dark ? Colors.white : kBrandNavy,
    secondary: dark ? kBrandSilver : kBrandNavy,
    surface: dark ? const Color(0xFF0B1729) : const Color(0xFFF3F7FC),
    surfaceContainerLowest: dark ? const Color(0xFF060E1B) : Colors.white,
    surfaceContainerLow: dark ? const Color(0xFF0E1C31) : const Color(0xFFEDF3FA),
    surfaceContainer: dark ? const Color(0xFF112138) : const Color(0xFFE6EEF8),
    surfaceContainerHigh: dark ? const Color(0xFF152843) : const Color(0xFFDEE8F4),
    surfaceContainerHighest:
        dark ? const Color(0xFF1B3050) : const Color(0xFFD5E1EF),
    outlineVariant: dark ? const Color(0xFF223A5C) : const Color(0xFFC3D2E4),
  );
  final bg = dark ? kBrandDeep : const Color(0xFFF3F7FC);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      scrolledUnderElevation: 0,
      backgroundColor: bg,
      toolbarHeight: 72,
    ),
    sliderTheme: const SliderThemeData(trackHeight: 4),
  );
}

/// Gradient text in the style of the logo lettering.
class _GradientText extends StatelessWidget {
  final String text;
  final List<Color> colors;
  final double size;
  const _GradientText(this.text, this.colors, this.size);

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        colors: colors,
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(r),
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w900,
          fontStyle: FontStyle.italic,
          letterSpacing: -.5,
          height: 1,
        ),
      ),
    );
  }
}

/// Logo + "SlaxxFM" lettering for the app bar.
class BrandTitle extends StatelessWidget {
  final double logoSize;
  const BrandTitle({super.key, this.logoSize = 52});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final slaxx = dark
        ? const [Colors.white, Color(0xFFDDE6F0)]
        : const [Color(0xFF16345E), kBrandNavy];
    final fm = dark
        ? const [Color(0xFFC6D4E4), kBrandSteel]
        : const [Color(0xFF6E92BC), Color(0xFF3F6797)];
    final textSize = logoSize * .56;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(logoSize * .22),
        child: Image.asset('assets/logo.png',
            width: logoSize, height: logoSize, filterQuality: FilterQuality.medium),
      ),
      SizedBox(width: logoSize * .22),
      _GradientText('Slaxx', slaxx, textSize),
      _GradientText('FM', fm, textSize),
    ]);
  }
}
