import 'dart:io';
import 'package:flutter_ffmpeg/flutter_ffmpeg.dart';
import 'package:flutter_ffmpeg/log.dart';
import 'package:flutter_ffmpeg/media_information.dart';
import 'package:flutter_ffmpeg/stream_information.dart';

removeExtension(String path) {
  final str = path.substring(0, path.length - 4);
  return str;
}

class EncodingProvider {
  static final FlutterFFmpeg _encoder = FlutterFFmpeg();
  static final FlutterFFprobe _probe = FlutterFFprobe();
  static final FlutterFFmpegConfig _config = FlutterFFmpegConfig();

  static double getAspectRatio(Map<dynamic, dynamic> props) {
    final int width = props['width'];
    final int height = props['height'];
    final double aspect = height / width;
    return aspect;
  }

  static Future<String> getThumb(videoPath, width) async {
    assert(File(videoPath).existsSync());

    final String outPath = '$videoPath.jpg';
    final arguments =
        '-y -i $videoPath -vframes 1 -an -filter:v scale="$width:-1" -ss 1 $outPath';

    final int rc = await _encoder.execute(arguments);
    assert(rc == 0);
    assert(File(outPath).existsSync());

    return outPath;
  }

  static void enableStatisticsCallback(Function cb) {
    return _config.enableStatisticsCallback(cb);
  }

  static Future<void> cancel() async {
    await _encoder.cancel();
  }

  static Future<Map<dynamic, dynamic>> getMediaInformation(String path) async {
    assert(File(path).existsSync());

    final info = await _probe.getMediaInformation(path);
    final streams = info.getStreams();
    for (var stream in streams) {
      final props = stream.getAllProperties();
      if (props['width'] != null) return props;
    }
    return null;
  }

  static int getDuration(Map<dynamic, dynamic> info) {
    return info['duration_ts'];
  }

  static void enableLogCallback(void Function(Log) logCallback) {
    _config.enableLogCallback(logCallback);
  }
}
