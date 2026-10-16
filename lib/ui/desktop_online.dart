import 'dart:async';
import 'package:flutter/material.dart';
import 'package:webview_flutter_windows/webview_flutter_windows.dart';
import '../services/approved_music_sites.dart';
import '../services/vybe_download_manager.dart';
import '../services/music_controller.dart';

/// WebView2 stays in VYBE. A small, fixed site switcher prevents arbitrary
/// web navigation; direct audio clicks are handled in-app when possible.
class DesktopOnlinePane extends StatefulWidget {
  const DesktopOnlinePane({super.key, this.immersive = false,
    this.initialSite = primaryMusicSite, this.controller});
  final bool immersive;
  final ApprovedMusicSite initialSite;
  final MusicController? controller;

  @override
  State<DesktopOnlinePane> createState() => _DesktopOnlinePaneState();
}

class _DesktopOnlinePaneState extends State<DesktopOnlinePane> {
  final WebviewController _web = WebviewController();
  final VybeDownloadManager downloads = vybeDownloads;
  StreamSubscription<String>? _urlSubscription;
  StreamSubscription<dynamic>? _messageSubscription;
  StreamSubscription<WebviewDownloadEvent>? _nativeDownloads;
  late ApprovedMusicSite site;
  bool _loading = true;
  bool _changingSite = false;
  String? _error;
  String _nativeStatus = '';

  @override
  void initState() {
    super.initState();
    site = widget.initialSite;
    unawaited(_initialize());
  }

  Future<void> _initialize() async {
    try {
      await _web.initialize();
      await _web.setPopupWindowPolicy(WebviewPopupWindowPolicy.deny);
      // Explicitly block cross-domain document links and forms. Only user
      // clicks on direct HTTPS audio/archive URLs start a bounded download.
      await _web.addScriptToExecuteOnDocumentCreated(r'''
        (() => {
          const clean = (host) => host.replace(/^www\./, '').toLowerCase();
          const direct = (s) => {
            try { const u = new URL(s, document.baseURI);
              return u.protocol === 'https:' && /\.(mp3|flac|wav|m4a|ogg|opus|aac|zip)(\?|#|$)/i.test(u.href);
            } catch (_) { return false; }
          };
          document.addEventListener('click', e => {
            const a = e.target.closest?.('a[href]');
            if (!a) return;
            try {
              const u = new URL(a.href, document.baseURI);
              if (direct(u.href) && (clean(u.hostname) !== clean(location.hostname))) {
                e.preventDefault();
                window.chrome?.webview?.postMessage({type:'download',url:u.href});
                return;
              }
              if (u.protocol !== 'https:' || clean(u.hostname) !== clean(location.hostname)) {
                e.preventDefault();
              }
            } catch (_) { e.preventDefault(); }
          }, true);
          document.addEventListener('submit', e => {
            try { const u = new URL(e.target.action, document.baseURI);
              if (u.protocol !== 'https:' || clean(u.hostname) !== clean(location.hostname)) e.preventDefault();
            } catch (_) { e.preventDefault(); }
          }, true);
        })();
      ''');
      _messageSubscription = _web.webMessage.listen((message) {
        if (message is Map && message['type'] == 'download') {
          final url = message['url'];
          if (url is String && isSupportedAudioDownload(url)) {
            unawaited(downloads.downloadDirect(url, referer: site.url));
            if (mounted) setState(() {});
          }
        }
      });
      _nativeDownloads = _web.onDownloadEvent.listen((event) {
        // WebView2 itself saves same-site downloads rather than opening Chrome.
        // For dynamic endpoints the exact destination is managed by WebView2.
        if (mounted) setState(() { _nativeStatus = '${event.kind}: ${event.url}'; });
      });
      _urlSubscription = _web.url.listen((url) {
        if (!_changingSite && !_allowed(url)) unawaited(_web.loadUrl(site.url));
      });
      await _web.loadUrl(site.url);
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  bool _allowed(String url) => url == 'about:blank' || isUrlOnMusicSite(url, site);

  Future<void> _change(ApprovedMusicSite next) async {
    if (!mounted) return;
    setState(() { site = next; _changingSite = true; _error = null; });
    try { await _web.loadUrl(site.url); } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _changingSite = false);
    }
  }

  Future<void> _alternate() async {
    final result = await showModalBottomSheet<ApprovedMusicSite>(context: context,
      showDragHandle: true, builder: (context) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
          const ListTile(title: Text('Not finding your music?'),
            subtitle: Text('Choose one of the three approved sites.')),
          for (final option in alternativeMusicSites)
            ListTile(title: Text(option.name), subtitle: Text(option.url),
              leading: const Icon(Icons.library_music_rounded),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.pop(context, option)),
          const SizedBox(height: 14),
        ])));
    if (result != null) await _change(result);
  }

  void _openLarge() => Navigator.of(context).push(MaterialPageRoute<void>(
    builder: (context) => Scaffold(body: SafeArea(child: Padding(
      padding: const EdgeInsets.all(18),
      child: DesktopOnlinePane(immersive: true, initialSite: site,
        controller: widget.controller))))));

  void _showDownloads() => showModalBottomSheet<void>(context: context,
    isScrollControlled: true, showDragHandle: true,
    builder: (context) => SafeArea(child: Padding(
      padding: const EdgeInsets.all(18),
      child: SizedBox(height: 450, child: Column(children: [
        const Row(children: [Icon(Icons.downloading_rounded), SizedBox(width: 12),
          Text('VYBE Downloads', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))]),
        const SizedBox(height: 16),
        Expanded(child: AnimatedBuilder(animation: downloads, builder: (context, _) =>
          downloads.tasks.isEmpty ? const Center(child: Text('No downloads yet.')) :
          ListView.separated(itemCount: downloads.tasks.length,
            separatorBuilder: (_, __) => const Divider(height: 18),
            itemBuilder: (context, i) {
              final task = downloads.tasks[i];
              return ListTile(leading: const Icon(Icons.music_note_rounded),
                title: Text(task.name, overflow: TextOverflow.ellipsis),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(task.status, maxLines: 2),
                  if (task.status == 'Downloading')
                    Padding(padding: const EdgeInsets.only(top: 8),
                      child: LinearProgressIndicator(value: task.progress)),
                  Text('${(task.received / 1048576).toStringAsFixed(1)} MB',
                    style: Theme.of(context).textTheme.labelSmall),
                ]),
                trailing: task.savedPath != null && widget.controller != null
                    ? IconButton(tooltip: 'Add to library', icon: const Icon(Icons.playlist_add_rounded),
                        onPressed: () => widget.controller!.addPaths([task.savedPath!]))
                    : null);
            }))),
      ])))));

  @override
  void dispose() {
    unawaited(_urlSubscription?.cancel());
    unawaited(_messageSubscription?.cancel());
    unawaited(_nativeDownloads?.cancel());
    unawaited(_web.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final browser = ClipRRect(borderRadius: BorderRadius.circular(18),
      child: DecoratedBox(decoration: BoxDecoration(
        border: Border.all(color: scheme.primary.withValues(alpha: .18)),
        borderRadius: BorderRadius.circular(18)),
        child: _error != null ? Center(child: Column(
          mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.wifi_off_rounded, size: 37),
            const Text('WebView2 could not start.'),
            Text(_error!, textAlign: TextAlign.center),
          ])) : _loading ? const Center(child: CircularProgressIndicator())
          : Webview(_web)));
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Icon(Icons.language_rounded, size: 26), const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Online', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
            Text('Music discovery · ${site.name}', style: Theme.of(context).textTheme.bodySmall),
          ])),
        if (widget.immersive) IconButton(tooltip: 'Exit expanded view',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.fullscreen_exit_rounded))
        else IconButton(tooltip: 'Expand browser', onPressed: _openLarge,
          icon: const Icon(Icons.open_in_full_rounded)),
        IconButton(tooltip: 'Downloads', onPressed: _showDownloads,
          icon: const Icon(Icons.downloading_rounded)),
        FilledButton.tonalIcon(onPressed: _alternate, icon: const Icon(Icons.travel_explore, size: 18),
          label: const Text('Not find music?')),
      ]),
      const SizedBox(height: 11),
      Card(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Row(children: [
          const Icon(Icons.lock_outline, size: 18), const SizedBox(width: 8),
          Expanded(child: Text(site.url, overflow: TextOverflow.ellipsis)),
          IconButton(tooltip: 'Back', onPressed: _loading ? null : _web.goBack,
            icon: const Icon(Icons.arrow_back)),
          IconButton(tooltip: 'Forward', onPressed: _loading ? null : _web.goForward,
            icon: const Icon(Icons.arrow_forward)),
          IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _web.reload,
            icon: const Icon(Icons.refresh)),
          TextButton(onPressed: () => _change(primaryMusicSite), child: const Text('Home')),
        ]))),
      const SizedBox(height: 9),
      if (widget.immersive) Expanded(child: browser)
      else SizedBox(height: (MediaQuery.sizeOf(context).height - 215).clamp(420.0, 1250.0),
        child: browser),
      if (_nativeStatus.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6),
        child: Text(_nativeStatus, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall)),
      AnimatedBuilder(animation: downloads, builder: (_, __) {
        final active = downloads.tasks.where((task) => task.status == 'Downloading').toList();
        if (active.isEmpty) return const SizedBox(height: 5);
        return Padding(padding: const EdgeInsets.only(top: 8),
          child: Row(children: [const Icon(Icons.downloading_rounded, size: 17),
            const SizedBox(width: 8),
            Expanded(child: LinearProgressIndicator(value: active.first.progress)),
            const SizedBox(width: 12), Text('${active.length} downloading'),
            TextButton(onPressed: _showDownloads, child: const Text('Details'))]));
      }),
    ]);
  }
}

final VybeDownloadManager vybeDownloads = VybeDownloadManager();
