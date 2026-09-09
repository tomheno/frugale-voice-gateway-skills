// playback_example.dart
// Minimal: fetch a stored opus_raw file from YOUR OWN Laravel API, decode it
// in-app, and play it. Flutter never touches the TTS gateway or any key.
//
// Startup (once): initialize opus before the first decode.
//   import 'package:opus_codec_dart/opus_codec_dart.dart';
//   import 'package:opus_codec/opus_codec.dart' as opus_codec;
//   await initOpus(await opus_codec.load());

import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';

import 'opus_raw_decoder.dart';

/// Fetch a stored opus_raw file from your Laravel API and return playable wav bytes.
/// `audioUrl` is served by YOUR backend (e.g. https://your-app.example.com/api/tts/42/0).
///
/// Throws on a network failure, a non-200, an empty body, or a malformed clip
/// (OpusRawException). Callers must handle these.
Future<Uint8List> fetchAndDecode(String audioUrl) async {
  final http.Response res;
  try {
    res = await http.get(Uri.parse(audioUrl));
  } catch (e) {
    throw Exception('fetch $audioUrl failed: $e'); // network error or bad URL
  }
  if (res.statusCode != 200) {
    throw Exception('fetch $audioUrl -> HTTP ${res.statusCode}');
  }
  if (res.bodyBytes.isEmpty) {
    throw Exception('fetch $audioUrl -> empty body');
  }
  // res.bodyBytes is the OPUSRAW1 container Laravel stored. toWav throws
  // OpusRawException on a truncated or malformed clip.
  return OpusRaw.toWav(res.bodyBytes);
}

/// Play one stored opus_raw clip.
Future<void> playStored(String audioUrl) async {
  final wav = await fetchAndDecode(audioUrl);
  final player = AudioPlayer();
  await player.setAudioSource(_BytesSource(wav, 'audio/wav'));
  await player.play();
  await player.playerStateStream.firstWhere((s) => s.processingState == ProcessingState.completed);
  await player.dispose();
}

/// Carries in-memory bytes to just_audio on web + mobile.
class _BytesSource extends StreamAudioSource {
  _BytesSource(this._bytes, this._contentType);
  final Uint8List _bytes;
  final String _contentType;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _bytes.length;
    return StreamAudioResponse(
      sourceLength: _bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_bytes.sublist(start, end)),
      contentType: _contentType,
    );
  }
}
