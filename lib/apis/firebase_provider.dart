import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_video_sharing/models/video_info.dart';

class FirebaseProvider {
  static saveVideo(VideoInfo video) async {
    await FirebaseFirestore.instance.collection('videos').doc().set({
      'videoUrl': video.videoUrl,
      'thumbUrl': video.thumbUrl,
      'coverUrl': video.coverUrl,
      'aspectRatio': video.aspectRatio,
      'uploadedAt': video.uploadedAt,
      'videoName': video.videoName,
    });
  }

  static deleteVideo(String videoName) async {
    await FirebaseFirestore.instance
        .collection('videos')
        .doc(videoName)
        .delete();
  }

  static listenToVideos(callback) async {
    FirebaseFirestore.instance.collection('videos').snapshots().listen((qs) {
      final videos = mapQueryToVideoInfo(qs);
      callback(videos);
    });
  }

  static mapQueryToVideoInfo(QuerySnapshot qs) {
    return qs.docs.map((DocumentSnapshot ds) {
      final data = ds.data();
      return VideoInfo(
        videoUrl: data['videoUrl'],
        thumbUrl: data['thumbUrl'],
        coverUrl: data['coverUrl'],
        aspectRatio: data['aspectRatio'],
        videoName: data['videoName'],
        uploadedAt: data['uploadedAt'],
      );
    }).toList();
  }
}
