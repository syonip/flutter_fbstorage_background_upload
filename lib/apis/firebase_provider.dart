import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_video_sharing/models/video_info.dart';

class FirebaseProvider {
  static createNewVideo(String videoName) async {
    await FirebaseFirestore.instance.collection('videos').doc(videoName).set({
      'finishedProcessing': false,
      'videoName': videoName,
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
        finishedProcessing: data['finishedProcessing'] == true,
      );
    }).toList();
  }
}
