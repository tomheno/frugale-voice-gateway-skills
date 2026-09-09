// opus_raw_decoder.dart
// Decode the frugale gateway's `opus_raw` (OPUSRAW1) audio to playable wav.
//
// Flutter does NOT call the TTS gateway. Your Laravel backend synthesizes +
// stores the opus_raw bytes and serves them through YOUR OWN API. This file is
// the ONLY thing the Flutter app needs: fetch those stored bytes, decode here,
// play. Works on web (wasm) + Android + iOS + Safari (which play no opus natively).
//
// OPUSRAW1 wire format (all little-endian):
//   offset 0  : 8 bytes magic "OPUSRAW1"
//   offset 8  : u32 sample_rate
//   offset 12 : u8  channels (= 1)
//   offset 13 : u16 pre_skip (in 48 kHz units)
//   then repeated to end: u16 packet_len + packet_len raw libopus bytes
//
// INIT ONCE at app startup, before decoding:
//   import 'package:opus_codec_dart/opus_codec_dart.dart';
//   import 'package:opus_codec/opus_codec.dart' as opus_codec;
//   await initOpus(await opus_codec.load());
// (Confirm the loader package name + version from the opus_codec_dart pub.dev example.)

import 'dart:typed_data';

import 'package:opus_codec_dart/opus_codec_dart.dart';

class OpusRawException implements Exception {
  OpusRawException(this.message);
  final String message;
  @override
  String toString() => 'OpusRawException: $message';
}

class OpusRaw {
  static const List<int> _magic = [0x4F, 0x50, 0x55, 0x53, 0x52, 0x41, 0x57, 0x31]; // "OPUSRAW1"

  // The opus sample rates libopus accepts. The gateway only ever emits these.
  static const Set<int> _validRates = {8000, 12000, 16000, 24000, 48000};

  /// The header sample_rate (u32 at offset 8). Throws OpusRawException (not a raw
  /// RangeError) on a body too short to hold the header.
  static int sampleRate(Uint8List body) {
    if (body.length < 12) throw OpusRawException('opus_raw too short');
    return ByteData.sublistView(body).getUint32(8, Endian.little);
  }

  /// Decode an OPUSRAW1 body to mono PCM16.
  static Int16List decode(Uint8List body) {
    if (body.length < 15) throw OpusRawException('opus_raw too short');
    for (var i = 0; i < 8; i++) {
      if (body[i] != _magic[i]) throw OpusRawException('opus_raw bad magic');
    }
    final bd = ByteData.sublistView(body);
    final rate = bd.getUint32(8, Endian.little);
    final channels = bd.getUint8(12);
    final preSkip = bd.getUint16(13, Endian.little);
    // Guard the header BEFORE constructing the decoder, so a corrupt or
    // adversarial clip throws a typed OpusRawException, not an untyped native
    // error. The gateway only emits mono at these rates (transcode.rs).
    if (channels != 1) throw OpusRawException('opus_raw expects mono, got channels=$channels');
    if (!_validRates.contains(rate)) throw OpusRawException('opus_raw bad sample_rate $rate');

    final decoder = SimpleOpusDecoder(sampleRate: rate, channels: channels);
    final chunks = <Int16List>[];
    var total = 0;
    var off = 15;
    try {
      while (off + 2 <= body.length) {
        final packetLen = bd.getUint16(off, Endian.little);
        off += 2;
        if (packetLen == 0) continue; // skip a padding/empty frame
        if (off + packetLen > body.length) break; // truncation guard
        final packet = Uint8List.sublistView(body, off, off + packetLen);
        off += packetLen;
        final pcm = decoder.decode(input: packet);
        if (pcm.isNotEmpty) {
          chunks.add(pcm);
          total += pcm.length;
        }
      }
    } finally {
      decoder.destroy();
    }

    final all = Int16List(total);
    var p = 0;
    for (final c in chunks) {
      all.setRange(p, p + c.length, c);
      p += c.length;
    }
    // pre_skip is in 48 kHz units → convert to the header sample_rate, trim front.
    final skip = (preSkip * rate) ~/ 48000;
    if (skip <= 0 || skip >= all.length) return all;
    return Int16List.sublistView(all, skip);
  }

  /// Decode an OPUSRAW1 body and wrap the PCM16 in a 44-byte WAV header, so any
  /// player (just_audio, etc.) can play it on every platform.
  static Uint8List toWav(Uint8List body) {
    final pcm = decode(body); // validates length, magic, channels, rate FIRST
    final rate = sampleRate(body);
    return _wavFromPcm16(pcm, rate, 1); // decode() guarantees channels == 1
  }

  static Uint8List _wavFromPcm16(Int16List pcm, int sampleRate, int channels) {
    const bitsPerSample = 16;
    final byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    final blockAlign = channels * bitsPerSample ~/ 8;
    final dataLen = pcm.lengthInBytes;
    final out = Uint8List(44 + dataLen);
    final bd = ByteData.sublistView(out);
    void ascii(int o, String s) {
      for (var i = 0; i < s.length; i++) {
        out[o + i] = s.codeUnitAt(i);
      }
    }

    ascii(0, 'RIFF');
    bd.setUint32(4, 36 + dataLen, Endian.little);
    ascii(8, 'WAVE');
    ascii(12, 'fmt ');
    bd.setUint32(16, 16, Endian.little); // fmt chunk size
    bd.setUint16(20, 1, Endian.little); // PCM
    bd.setUint16(22, channels, Endian.little);
    bd.setUint32(24, sampleRate, Endian.little);
    bd.setUint32(28, byteRate, Endian.little);
    bd.setUint16(32, blockAlign, Endian.little);
    bd.setUint16(34, bitsPerSample, Endian.little);
    ascii(36, 'data');
    bd.setUint32(40, dataLen, Endian.little);
    out.setRange(44, 44 + dataLen, Uint8List.sublistView(pcm));
    return out;
  }
}
