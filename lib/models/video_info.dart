class VideoInfo {
  String videoUrl;
  String thumbUrl;
  String coverUrl;
  double aspectRatio;
  int uploadedAt;
  String videoName;
  bool finishedProcessing;
  String uploadUrl;
  String rawVideoPath;
  bool uploadComplete;

  VideoInfo({
    this.videoUrl,
    this.thumbUrl,
    this.coverUrl,
    this.aspectRatio,
    this.uploadedAt,
    this.videoName,
    this.finishedProcessing,
    this.uploadUrl,
    this.rawVideoPath,
    this.uploadComplete,
  });
}
