import 'dart:async';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

/// Preview media generik (gambar & video) dalam grid/wrap.
/// Ekspektasi tiap item:
/// {
///   'type': 'image' | 'video',
///   'signed_url': 'https://...' // Wajib, karena bucket private
///   'caption': '...'            // opsional
/// }
class MediaPreview extends StatelessWidget {
  final List<Map<String, dynamic>> media;
  final double tileSize;

  const MediaPreview({super.key, required this.media, this.tileSize = 120});

  @override
  Widget build(BuildContext context) {
    if (media.isEmpty) {
      return const Text('Belum ada media terunggah.');
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: media.map((m) {
        final type = (m['type'] as String?)?.toLowerCase();
        final url = (m['signed_url'] as String?) ?? '';
        final isImage = type == 'image';

        Widget tile = InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: url.isEmpty
              ? null
              : () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => _FullscreenViewer(item: m),
                    ),
                  );
                },
          child: Ink(
            width: tileSize,
            height: tileSize,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(8),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: url.isEmpty
                        ? const _ImagePlaceholder()
                        : Image.network(
                            url,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const _ImagePlaceholder(),
                          ),
                  )
                : Stack(
                    fit: StackFit.expand,
                    children: const [
                      ColoredBox(color: Color(0x11000000)),
                      Center(
                        child: Icon(
                          Icons.play_circle_fill,
                          size: 44,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
          ),
        );

        final caption = (m['caption'] as String?)?.trim() ?? '';
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            tile,
            if (caption.isNotEmpty) ...[
              const SizedBox(height: 6),
              SizedBox(
                width: tileSize,
                child: Text(
                  caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        );
      }).toList(),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.broken_image_outlined, size: 36, color: Colors.black38),
    );
  }
}

/// ===================== Fullscreen Viewer =====================
/// - Gambar: InteractiveViewer (zoom/pan)
/// - Video: video_player + controls sederhana (play/pause, seek, scrub)
class _FullscreenViewer extends StatefulWidget {
  final Map<String, dynamic> item;
  const _FullscreenViewer({required this.item});

  @override
  State<_FullscreenViewer> createState() => _FullscreenViewerState();
}

class _FullscreenViewerState extends State<_FullscreenViewer> {
  VideoPlayerController? _vc;
  StreamSubscription? _ticker;
  bool _initialized = false;

  bool get _isVideo =>
      (widget.item['type'] as String?)?.toLowerCase() == 'video';

  String get _url => (widget.item['signed_url'] as String?) ?? '';

  @override
  void initState() {
    super.initState();
    if (_isVideo && _url.isNotEmpty) {
      _vc = VideoPlayerController.networkUrl(Uri.parse(_url));
      _vc!.initialize().then((_) {
        if (mounted) setState(() => _initialized = true);
      });
      // bikin UI slider ter-update
      _ticker = Stream.periodic(const Duration(milliseconds: 250)).listen((_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _vc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final caption = (widget.item['caption'] as String?)?.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(_isVideo ? 'Video' : 'Foto'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(child: _isVideo ? _buildVideo() : _buildImage()),
            ),
            if ((caption ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage() {
    if (_url.isEmpty) {
      return const Icon(Icons.broken_image, color: Colors.white54, size: 64);
    }
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 5,
      child: Image.network(
        _url,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) =>
            const Icon(Icons.broken_image, color: Colors.white54, size: 64),
      ),
    );
  }

  Widget _buildVideo() {
    if (_vc == null) {
      return const Icon(Icons.broken_image, color: Colors.white54, size: 64);
    }
    if (!_initialized) {
      return const CircularProgressIndicator(color: Colors.white);
    }

    final pos = _vc!.value.position;
    final dur = _vc!.value.duration;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: _vc!.value.aspectRatio == 0
              ? (16 / 9)
              : _vc!.value.aspectRatio,
          child: VideoPlayer(_vc!),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              color: Colors.white,
              onPressed: () => _vc!.seekTo(pos - const Duration(seconds: 10)),
              icon: const Icon(Icons.replay_10),
            ),
            IconButton(
              color: Colors.white,
              onPressed: () {
                if (_vc!.value.isPlaying) {
                  _vc!.pause();
                } else {
                  _vc!.play();
                }
                setState(() {});
              },
              icon: Icon(_vc!.value.isPlaying ? Icons.pause : Icons.play_arrow),
            ),
            IconButton(
              color: Colors.white,
              onPressed: () => _vc!.seekTo(pos + const Duration(seconds: 10)),
              icon: const Icon(Icons.forward_10),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Slider(
                value: pos.inMilliseconds
                    .clamp(0, dur.inMilliseconds)
                    .toDouble(),
                max: (dur.inMilliseconds == 0 ? 1 : dur.inMilliseconds)
                    .toDouble(),
                onChanged: (v) =>
                    _vc!.seekTo(Duration(milliseconds: v.toInt())),
                activeColor: Colors.white,
                inactiveColor: Colors.white24,
              ),
              Text(
                '${_fmt(pos)} / ${_fmt(dur)}',
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    return h > 0
        ? '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}
