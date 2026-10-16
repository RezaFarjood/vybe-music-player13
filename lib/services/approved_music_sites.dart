/// Fixed user-selected websites. The app has no unrestricted address bar.
class ApprovedMusicSite {
  const ApprovedMusicSite(this.name, this.url);
  final String name;
  final String url;
  Uri get uri => Uri.parse(url);
}

const primaryMusicSite = ApprovedMusicSite('BeatMastering', 'https://beatmastering.ir/');
const alternativeMusicSites = <ApprovedMusicSite>[
  ApprovedMusicSite('MusicDel', 'https://musicdel.ir/'),
  ApprovedMusicSite('Musics FA', 'https://musics-fa.com/'),
  ApprovedMusicSite('Music Viral', 'https://musicviral.ir/'),
];

bool isUrlOnMusicSite(String url, ApprovedMusicSite site) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  String canonical(String host) => host.toLowerCase().replaceFirst(RegExp(r'^www\.'), '');
  return canonical(uri.host) == canonical(site.uri.host);
}

bool isSupportedAudioDownload(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme != 'https') return false;
  return RegExp(r'\.(mp3|flac|wav|m4a|ogg|opus|aac|zip)$', caseSensitive: false)
      .hasMatch(uri.path);
}
