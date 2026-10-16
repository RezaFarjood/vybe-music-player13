import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import 'approved_music_sites.dart';

/// A bounded, user-initiated HTTPS downloader for direct audio links.
/// No arbitrary browsing, background scraping, or external browser launches.
class VybeDownload {
  VybeDownload(this.url, this.name);
  final String url, name;
  int received = 0;
  int total = 0;
  String status = 'Waiting';
  String? savedPath;
  double? get progress => total > 0 ? (received / total).clamp(0.0, 1.0).toDouble() : null;
}

class VybeDownloadManager extends ChangeNotifier {
  final List<VybeDownload> tasks = [];
  static const maxBytes = 250 * 1024 * 1024;
  static const validTypes = <String>{'audio/mpeg', 'audio/mp3', 'audio/flac',
    'audio/x-flac', 'audio/wav', 'audio/x-wav', 'audio/mp4', 'audio/aac',
    'audio/ogg', 'audio/opus', 'application/ogg', 'application/octet-stream',
    'application/zip', 'application/x-zip-compressed'};

  /// HTTP downloads cannot reproduce some browser-only POST, cookie, or blob
  /// links. Those must be reported as unsupported, never silently rerouted.
  Future<void> downloadDirect(String url, {String? referer}) async {
    if (!isSupportedAudioDownload(url)) throw StateError('Only direct HTTPS music files are supported.');
    final uri = Uri.parse(url);
    final name = uri.pathSegments.isEmpty ? 'music.mp3' : Uri.decodeComponent(uri.pathSegments.last);
    final task = VybeDownload(url, safeFileName(name));
    tasks.insert(0, task);
    notifyListeners();
    HttpClient? client;
    File? temp;
    try {
      task.status = 'Connecting'; notifyListeners();
      client = HttpClient()..connectionTimeout = const Duration(seconds: 25);
      client.maxConnectionsPerHost = 3;
      // Resolve a small number of HTTPS redirects ourselves rather than
      // allowing an HTTP downgrade or a protocol switch during download.
      var current = uri;
      late HttpClientResponse response;
      for (var hop = 0; hop < 5; hop++) {
        final request = await client.getUrl(current);
        request.followRedirects = false;
        if (referer != null && Uri.tryParse(referer)?.scheme == 'https') {
          request.headers.set(HttpHeaders.refererHeader, referer);
        }
        request.headers.set(HttpHeaders.userAgentHeader, 'VYBE/0.4 (in-app download)');
        response = await request.close().timeout(const Duration(seconds: 40));
        if (response.isRedirect) {
          final location = response.headers.value(HttpHeaders.locationHeader);
          if (location == null) throw const FormatException('Redirect with no destination');
          final next = current.resolve(location);
          if (next.scheme != 'https' || next.host.isEmpty) {
            throw const FormatException('Insecure redirect refused');
          }
          await response.drain<void>();
          current = next;
          if (hop == 4) throw const FormatException('Too many redirects');
          continue;
        }
        break;
      }
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException('HTTP ${response.statusCode}', uri: current);
      }
      final type = response.headers.contentType?.mimeType.toLowerCase();
      if (type != null && !validTypes.contains(type)) {
        throw FormatException('Server returned $type instead of a music file.');
      }
      final size = response.contentLength;
      if (size > maxBytes) throw const FormatException('File exceeds 250 MB safety limit.');
      task.total = size > 0 ? size : 0;
      final directory = await targetDirectory();
      await directory.create(recursive: true);
      final path = uniquePath(directory, task.name);
      temp = File('$path.part');
      task.status = 'Downloading'; notifyListeners();
      final sink = temp.openWrite();
      try {
        await for (final data in response.timeout(const Duration(seconds: 60))) {
          task.received += data.length;
          if (task.received > maxBytes) throw const FormatException('Download exceeded 250 MB limit.');
          sink.add(data);
          notifyListeners();
        }
        await sink.flush();
      } finally {
        await sink.close();
      }
      if (task.total > 0 && task.received != task.total) {
        throw const FormatException('Incomplete download');
      }
      final completed = await temp.rename(path);
      task.savedPath = completed.path;
      task.status = 'Completed';
      notifyListeners();
    } catch (error) {
      task.status = 'Failed: $error';
      notifyListeners();
      if (temp != null && await temp.exists()) await temp.delete();
    } finally {
      client?.close(force: true);
    }
  }

  static String safeFileName(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '_').trim();
    return cleaned.isEmpty ? 'download.mp3' : (cleaned.length > 120 ? cleaned.substring(0, 120) : cleaned);
  }

  static Future<Directory> targetDirectory() async {
    if (Platform.isWindows) {
      final home = Platform.environment['USERPROFILE'];
      if (home != null && home.isNotEmpty) return Directory('$home\\Music\\VYBE Downloads');
      final downloads = await getDownloadsDirectory();
      if (downloads != null) return Directory('${downloads.path}\\VYBE');
    }
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}${Platform.pathSeparator}VYBE Downloads');
  }

  static String uniquePath(Directory folder, String fileName) {
    final dot = fileName.lastIndexOf('.');
    final root = dot < 0 ? fileName : fileName.substring(0, dot);
    final ext = dot < 0 ? '' : fileName.substring(dot);
    var path = '${folder.path}${Platform.pathSeparator}$fileName';
    var n = 2;
    while (File(path).existsSync() || File('$path.part').existsSync()) {
      path = '${folder.path}${Platform.pathSeparator}$root ($n)$ext';
      n++;
    }
    return path;
  }

  @override
  void dispose() {
    // Active network requests finish independently; avoid disposing while active.
    super.dispose();
  }
}
