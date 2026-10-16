import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class VybeThemeSpec {
  const VybeThemeSpec(this.id, this.title, this.description, {
    required this.background, required this.sidebar, required this.surface,
    required this.raised, required this.accent, required this.mint,
    required this.primaryText, required this.secondaryText,
    required this.subtle, required this.border,
  });

  final String id, title, description;
  final Color background, sidebar, surface, raised, accent, mint,
      primaryText, secondaryText, subtle, border;

  bool get isLight => {'pearl', 'snow', 'sand', 'lavender', 'latte', 'rose'}.contains(id);
}

const vybeThemePresets = <VybeThemeSpec>[
  VybeThemeSpec('obsidian','Obsidian Glass','True black and quiet violet',
    background: Color(0xFF090A10),sidebar: Color(0xFF11111B),
    surface: Color(0xFF1A1824),raised: Color(0xFF292535),
    accent: Color(0xFFB69CFF),mint: Color(0xFF83DDE6),
    primaryText: Color(0xFFF8F6FF),secondaryText: Color(0xFFB0AABC),
    subtle: Color(0xFF827B92),border: Color(0xFF463C55)),
  VybeThemeSpec('pearl','Pearl Light','Pearlescent white and muted purple',
    background: Color(0xFFF6F4FA),sidebar: Color(0xFFF0EDF6),
    surface: Color(0xFFFFFFFF),raised: Color(0xFFE6E0F0),
    accent: Color(0xFF7954C6),mint: Color(0xFF278F9B),
    primaryText: Color(0xFF222030),secondaryText: Color(0xFF6C667E),
    subtle: Color(0xFF857C93),border: Color(0xFFD1C9E0)),
  VybeThemeSpec('midnight','Midnight Violet','Deep violet and cinematic light',
    background: Color(0xFF130D28),sidebar: Color(0xFF1B1232),
    surface: Color(0xFF25183A),raised: Color(0xFF332249),
    accent: Color(0xFFC38DFF),mint: Color(0xFF88D8E8),
    primaryText: Color(0xFFF9F5FF),secondaryText: Color(0xFFB6A8C9),
    subtle: Color(0xFF9082A2),border: Color(0xFF56406C)),
  VybeThemeSpec('frosted','Frosted Crystal','Cool blue, glass and silver',
    background: Color(0xFF102338),sidebar: Color(0xFF162D43),
    surface: Color(0xFF263B52),raised: Color(0xFF355067),
    accent: Color(0xFF9BE7F4),mint: Color(0xFFA5EAD7),
    primaryText: Color(0xFFF7FDFF),secondaryText: Color(0xFFC0D2DE),
    subtle: Color(0xFF96A9B8),border: Color(0xFF527088)),
  VybeThemeSpec('neon','Neon Pulse','Charcoal glass and vibrant fuchsia',
    background: Color(0xFF0D0C16),sidebar: Color(0xFF151222),
    surface: Color(0xFF261C34),raised: Color(0xFF362342),
    accent: Color(0xFFFF7AC8),mint: Color(0xFF70E9EA),
    primaryText: Color(0xFFFCF6FF),secondaryText: Color(0xFFC9B4D0),
    subtle: Color(0xFF9E829E),border: Color(0xFF6B3B66)),
  VybeThemeSpec('emerald','Emerald Noir','Forest black and cool mint',
    background: Color(0xFF071712),sidebar: Color(0xFF0B231A),
    surface: Color(0xFF13332B),raised: Color(0xFF1A4437),
    accent: Color(0xFF8EE8C0),mint: Color(0xFF9BE8E1),
    primaryText: Color(0xFFF4FFF9),secondaryText: Color(0xFFB4D0C4),
    subtle: Color(0xFF799D8B),border: Color(0xFF346452)),
  VybeThemeSpec('solar','Copper Dusk','Warm smoke and copper light',
    background: Color(0xFF1E1215),sidebar: Color(0xFF251719),
    surface: Color(0xFF352124),raised: Color(0xFF493036),
    accent: Color(0xFFFFB58A),mint: Color(0xFFFFD5A8),
    primaryText: Color(0xFFFFF7F0),secondaryText: Color(0xFFD4B8AF),
    subtle: Color(0xFFA28783),border: Color(0xFF704A48)),
  VybeThemeSpec('snow','Snowfall','Soft cool whites and lavender',
    background: Color(0xFFF4F7FC),sidebar: Color(0xFFE9EFF9),
    surface: Color(0xFFFFFFFF),raised: Color(0xFFDCE6F4),
    accent: Color(0xFF5272CB),mint: Color(0xFF2A9D9B),
    primaryText: Color(0xFF1E2A42),secondaryText: Color(0xFF64728B),
    subtle: Color(0xFF8D9AB0),border: Color(0xFFBFCDE1)),
  VybeThemeSpec('sand','Silk Sand','Warm ivory and graphite',
    background: Color(0xFFFFFAF4),sidebar: Color(0xFFF4EDE3),
    surface: Color(0xFFFFFDF9),raised: Color(0xFFECE2D5),
    accent: Color(0xFF9C694F),mint: Color(0xFF55877C),
    primaryText: Color(0xFF352C29),secondaryText: Color(0xFF72665F),
    subtle: Color(0xFF9B8F87),border: Color(0xFFD8C9BA)),
  VybeThemeSpec('blackglass','Black Crystal Glass','Near-black glass with silver accents',
    background: Color(0xFF030406),sidebar: Color(0xFF090A0C),
    surface: Color(0xFF121316),raised: Color(0xFF24262B),
    accent: Color(0xFFE0E4EA),mint: Color(0xFF8FBBB8),
    primaryText: Color(0xFFF7F8FA),secondaryText: Color(0xFFB6B9C0),
    subtle: Color(0xFF92979E),border: Color(0xFF50535A)),
  VybeThemeSpec('oceanmint','Ocean Mint','Deep teal and luminous turquoise',
    background: Color(0xFF071A23),sidebar: Color(0xFF0A222B),
    surface: Color(0xFF10333C),raised: Color(0xFF18464D),
    accent: Color(0xFF71E9CD),mint: Color(0xFF68CBE5),
    primaryText: Color(0xFFF0FFFC),secondaryText: Color(0xFFAFD8D5),
    subtle: Color(0xFF7DABA9),border: Color(0xFF396D73)),
  VybeThemeSpec('lavender','Lavender Milk','Ivory white and gentle purple',
    background: Color(0xFFF9F7FF),sidebar: Color(0xFFF0EAFB),
    surface: Color(0xFFFFFFFF),raised: Color(0xFFE8DDFC),
    accent: Color(0xFF8353BD),mint: Color(0xFF5D929E),
    primaryText: Color(0xFF352440),secondaryText: Color(0xFF806B8E),
    subtle: Color(0xFF9A89A7),border: Color(0xFFD6CAE6)),
  VybeThemeSpec('latte','Caffe Latte','Warm coffee, mocha and oat milk',
    background: Color(0xFFF4EBDD),sidebar: Color(0xFFECE0D0),
    surface: Color(0xFFFFFAF4),raised: Color(0xFFDAC7B4),
    accent: Color(0xFF916749),mint: Color(0xFF77918B),
    primaryText: Color(0xFF32251E),secondaryText: Color(0xFF786253),
    subtle: Color(0xFF968578),border: Color(0xFFCDB8A1)),
  VybeThemeSpec('rose','Rose Quartz','Soft pearl and dusty rose',
    background: Color(0xFFFFF7FA),sidebar: Color(0xFFF7E8F0),
    surface: Color(0xFFFFFFFF),raised: Color(0xFFF4DDE8),
    accent: Color(0xFFBA648A),mint: Color(0xFF83B4AC),
    primaryText: Color(0xFF412C39),secondaryText: Color(0xFF866A7A),
    subtle: Color(0xFFAC8E9F),border: Color(0xFFE4C8D5)),
  VybeThemeSpec('arctic','Arctic Aurora','Night blue with sea-glass highlights',
    background: Color(0xFF09172A),sidebar: Color(0xFF0C2135),
    surface: Color(0xFF153247),raised: Color(0xFF204456),
    accent: Color(0xFF90DAF2),mint: Color(0xFF9CEED9),
    primaryText: Color(0xFFF1FBFF),secondaryText: Color(0xFFB2C9DA),
    subtle: Color(0xFF8CA6BA),border: Color(0xFF3A6179)),

];

class VybeThemeController extends ChangeNotifier {
  VybeThemeSpec selected = vybeThemePresets.first;
  bool loaded = false;
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString('vybe/theme') ?? 'obsidian';
    selected = vybeThemePresets.firstWhere((t) => t.id == id,
        orElse: () => vybeThemePresets.first);
    loaded = true;
    notifyListeners();
  }
  Future<void> choose(String id) async {
    selected = vybeThemePresets.firstWhere((t) => t.id == id,
        orElse: () => vybeThemePresets.first);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vybe/theme', selected.id);
  }
}
