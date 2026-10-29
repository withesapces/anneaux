import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Dessins vectoriels du design system (logo, icônes de navigation, Maître Magnésie).

const _logo = '<svg viewBox="0 0 64 64" fill="none">'
    '<path d="M22 3V21M42 3V21" stroke="#F5F5F2" stroke-width="4" stroke-linecap="round"/>'
    '<circle cx="22" cy="39" r="15" stroke="#FF7A1A" stroke-width="7"/>'
    '<circle cx="42" cy="39" r="15" stroke="#F5F5F2" stroke-width="7"/></svg>';

const navRings = '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="2.4" '
    'stroke-linecap="round"><path d="M9 2V9M17 2V9"/><circle cx="9" cy="15" r="6"/>'
    '<circle cx="17" cy="15" r="6"/></svg>';
const navCalendar = '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="2.4" '
    'stroke-linecap="round"><rect x="3" y="5" width="20" height="18" rx="3"/>'
    '<path d="M3 11H23M8 2V7M18 2V7"/></svg>';
const navTrend = '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="2.4" '
    'stroke-linecap="round" stroke-linejoin="round"><path d="M3 20L10 12L15 16L23 6"/>'
    '<path d="M17 6H23V12"/></svg>';
const navList = '<svg viewBox="0 0 26 26" fill="none" stroke="currentColor" stroke-width="2.4" '
    'stroke-linecap="round"><path d="M9 6H23M9 13H23M9 20H23"/><circle cx="4" cy="6" r="1.2"/>'
    '<circle cx="4" cy="13" r="1.2"/><circle cx="4" cy="20" r="1.2"/></svg>';
const strapIcon = '<svg viewBox="0 0 18 30" fill="none" stroke="currentColor" stroke-width="3" '
    'stroke-linecap="round"><path d="M9 2V18"/><circle cx="9" cy="23" r="5"/></svg>';

const _mage = '<svg viewBox="0 0 240 260">'
    '<ellipse cx="120" cy="252" rx="74" ry="6" fill="#161616"/>'
    '<circle cx="40" cy="120" r="3" fill="#F5F5F2" fill-opacity="0.5"/>'
    '<circle cx="56" cy="92" r="2" fill="#F5F5F2" fill-opacity="0.4"/>'
    '<circle cx="30" cy="160" r="2.5" fill="#F5F5F2" fill-opacity="0.35"/>'
    '<circle cx="66" cy="206" r="4" fill="#F5F5F2" fill-opacity="0.55"/>'
    '<circle cx="56" cy="190" r="2.5" fill="#F5F5F2" fill-opacity="0.45"/>'
    '<circle cx="210" cy="96" r="2.5" fill="#F5F5F2" fill-opacity="0.4"/>'
    '<path d="M178 64V252" stroke="#5C5C5C" stroke-width="7" stroke-linecap="round"/>'
    '<path d="M168 10V24M188 10V24" stroke="#A3A3A3" stroke-width="3" stroke-linecap="round"/>'
    '<circle cx="168" cy="40" r="14" stroke="#FF7A1A" stroke-width="6" fill="none"/>'
    '<circle cx="188" cy="40" r="14" stroke="#F5F5F2" stroke-width="6" fill="none"/>'
    '<path d="M70 252L94 140Q120 120 146 140L170 252Z" fill="#FF7A1A"/>'
    '<path d="M121 142L113 252" stroke="#C85A0C" stroke-width="3"/>'
    '<rect x="95" y="184" width="50" height="10" rx="3" fill="#0A0A0A"/>'
    '<circle cx="120" cy="189" r="6" stroke="#F5F5F2" stroke-width="3" fill="#0A0A0A"/>'
    '<path d="M94 152Q78 176 86 196" stroke="#FF7A1A" stroke-width="15" stroke-linecap="round" fill="none"/>'
    '<circle cx="87" cy="199" r="8" fill="#E9D3BE"/>'
    '<path d="M146 150Q164 160 172 168" stroke="#FF7A1A" stroke-width="15" stroke-linecap="round" fill="none"/>'
    '<circle cx="176" cy="168" r="8" fill="#E9D3BE"/>'
    '<path d="M82 148Q80 86 120 54Q160 86 158 148Q120 128 82 148Z" fill="#2E2E2E"/>'
    '<ellipse cx="120" cy="122" rx="22" ry="25" fill="#0A0A0A"/>'
    '<circle cx="111" cy="117" r="4" fill="#F5F5F2"/>'
    '<circle cx="129" cy="117" r="4" fill="#F5F5F2"/>'
    '<path d="M100 134Q120 192 140 134Q120 146 100 134Z" fill="#F5F5F2"/></svg>';

const _mageBust = '<svg viewBox="0 0 220 240">'
    '<path d="M62 236L84 128Q110 108 136 128L158 236Z" fill="#FF7A1A"/>'
    '<path d="M74 134Q72 76 110 46Q148 76 146 134Q110 116 74 134Z" fill="#2E2E2E"/>'
    '<ellipse cx="110" cy="112" rx="21" ry="23" fill="#0A0A0A"/>'
    '<circle cx="102" cy="108" r="3.5" fill="#F5F5F2"/>'
    '<circle cx="118" cy="108" r="3.5" fill="#F5F5F2"/>'
    '<path d="M92 124Q110 170 128 124Q110 134 92 124Z" fill="#F5F5F2"/></svg>';

class AnneauxLogo extends StatelessWidget {
  final double size;
  const AnneauxLogo({super.key, this.size = 36});
  @override
  Widget build(BuildContext context) => SvgPicture.string(_logo, width: size, height: size);
}

class MageArt extends StatelessWidget {
  final double width;
  final bool bust;
  const MageArt({super.key, this.width = 190, this.bust = false});
  @override
  Widget build(BuildContext context) => SvgPicture.string(bust ? _mageBust : _mage,
      width: width, height: width * (bust ? 240 / 220 : 260 / 240));
}

/// Icône SVG monochrome (stroke="currentColor").
class LineIcon extends StatelessWidget {
  final String svg;
  final double size;
  final Color color;
  final double? height;
  const LineIcon(this.svg, {super.key, this.size = 26, required this.color, this.height});
  @override
  Widget build(BuildContext context) => SvgPicture.string(
        svg,
        width: size,
        height: height ?? size,
        theme: SvgTheme(currentColor: color),
      );
}
