import 'dart:io';
import 'dart:math';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_ffmpeg/statistics.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_uploader/flutter_uploader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';
import 'apis/encoding_provider.dart';
import 'apis/firebase_provider.dart';
import 'package:path/path.dart' as p;
import 'models/video_info.dart';
import 'widgets/player.dart';
import 'package:timeago/timeago.dart' as timeago;

FlutterUploader _uploader = FlutterUploader();

//TODO: go over this
void backgroundHandler() {
  WidgetsFlutterBinding.ensureInitialized();

  // Notice these instances belong to a forked isolate.
  var uploader = FlutterUploader();

  var notifications = FlutterLocalNotificationsPlugin();

  // Only show notifications for unprocessed uploads.
  SharedPreferences.getInstance().then((preferences) {
    var processed = preferences.getStringList('processed') ?? <String>[];

    if (Platform.isAndroid) {
      uploader.progress.listen((progress) {
        if (processed.contains(progress.taskId)) {
          return;
        }

        notifications.show(
          progress.taskId.hashCode,
          'FlutterUploader Example',
          'Upload in Progress',
          NotificationDetails(
            AndroidNotificationDetails(
              'FlutterUploader.Example',
              'FlutterUploader',
              'Installed when you activate the Flutter Uploader Example',
              progress: progress.progress,
              icon: 'ic_upload',
              enableVibration: false,
              importance: Importance.Low,
              showProgress: true,
              onlyAlertOnce: true,
              maxProgress: 100,
              channelShowBadge: false,
            ),
            IOSNotificationDetails(),
          ),
        );
      });
    }

    uploader.result.listen((result) {
      if (processed.contains(result.taskId)) {
        return;
      }

      processed.add(result.taskId);
      preferences.setStringList('processed', processed);

      notifications.cancel(result.taskId.hashCode);

      final successful = result.status == UploadTaskStatus.complete;

      var title = 'Upload Complete';
      if (result.status == UploadTaskStatus.failed) {
        title = 'Upload Failed';
      } else if (result.status == UploadTaskStatus.canceled) {
        title = 'Upload Canceled';
      }

      notifications
          .show(
        result.taskId.hashCode,
        'FlutterUploader Example',
        title,
        NotificationDetails(
          AndroidNotificationDetails(
            'FlutterUploader.Example',
            'FlutterUploader',
            'Installed when you activate the Flutter Uploader Example',
            icon: 'ic_upload',
            enableVibration: !successful,
            importance: result.status == UploadTaskStatus.failed
                ? Importance.High
                : Importance.Min,
          ),
          IOSNotificationDetails(
            presentAlert: true,
          ),
        ),
      )
          .catchError((e, stack) {
        print('error while showing notification: $e, $stack');
      });
    });
  });
}

void main() => runApp(MyApp());

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Video Sharing',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Video Sharing'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final thumbWidth = 300;
  List<VideoInfo> _videos = <VideoInfo>[];
  bool _imagePickerActive = false;
  bool _processing = false;
  bool _canceled = false;
  double _progress = 0.0;
  int _videoDuration = 0;
  String _processPhase = '';
  final bool _debugMode = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  _initialize() async {
    await Firebase.initializeApp();

    _uploader.setBackgroundHandler(backgroundHandler);

    var flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    var initializationSettingsAndroid =
        AndroidInitializationSettings('ic_upload');
    var initializationSettingsIOS = IOSInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: true,
      onDidReceiveLocalNotification:
          (int id, String title, String body, String payload) async {},
    );
    var initializationSettings = InitializationSettings(
        initializationSettingsAndroid, initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onSelectNotification: (payload) async {},
    );

    setState(() {
      _loading = false;
    });
    FirebaseProvider.listenToVideos((List<VideoInfo> newVideos) {
      setState(() {
        _videos = newVideos;
      });
      for (VideoInfo video in newVideos) {
        if (video.uploadUrl != null) {
          _processVideo(
              video); // Improvement: process video while waiting for upload url
        }
      }
    });

    EncodingProvider.enableStatisticsCallback((Statistics stats) {
      if (_canceled) return;

      setState(() {
        _progress = stats.time / _videoDuration;
      });
    });
  }

  void _onUploadProgress(event) {
    if (event.type == StorageTaskEventType.progress) {
      final double progress =
          event.snapshot.bytesTransferred / event.snapshot.totalByteCount;
      setState(() {
        _progress = progress;
      });
    }
  }

  Future<String> _uploadFile(filePath, folderName) async {
    final file = new File(filePath);
    final basename = p.basename(filePath);

    final StorageReference ref =
        FirebaseStorage.instance.ref().child(folderName).child(basename);

    StorageUploadTask uploadTask = ref.putFile(file);
    uploadTask.events.listen(_onUploadProgress);
    StorageTaskSnapshot taskSnapshot = await uploadTask.onComplete;
    String videoUrl = await taskSnapshot.ref.getDownloadURL();
    return videoUrl;
  }

  Future<String> _uploadFileBackground(filePath, uploadUrl) async {
    final tag = 'upload';

    final upload = RawUpload(
      url: uploadUrl,
      path: filePath,
      method: UploadMethod.PUT,
      tag: tag,
    );

    await _uploader.enqueue(upload);
  }

  String getFileExtension(String fileName) {
    final exploded = fileName.split('.');
    return exploded[exploded.length - 1];
  }

  void _updatePlaylistUrls(File file, String videoName) {
    final lines = file.readAsLinesSync();
    var updatedLines = List<String>();

    for (final String line in lines) {
      var updatedLine = line;
      if (line.contains('.ts') || line.contains('.m3u8')) {
        updatedLine = '$videoName%2F$line?alt=media';
      }
      updatedLines.add(updatedLine);
    }
    final updatedContents =
        updatedLines.reduce((value, element) => value + '\n' + element);

    file.writeAsStringSync(updatedContents);
  }

  Future<void> _processVideo(VideoInfo video) async {
    final Directory extDir = await getApplicationDocumentsDirectory();
    final outDirPath = '${extDir.path}/Videos/${video.videoName}';
    final videosDir = new Directory(outDirPath);
    videosDir.createSync(recursive: true);

    final rawVideoPath = video.rawVideoPath;
    final info = await EncodingProvider.getMediaInformation(rawVideoPath);
    final aspectRatio = EncodingProvider.getAspectRatio(info);

    setState(() {
      _processPhase = 'Generating thumbnail';
      _videoDuration = EncodingProvider.getDuration(info);
      _progress = 0.0;
    });

    final thumbFilePath =
        await EncodingProvider.getThumb(rawVideoPath, thumbWidth);

    final thumbUrl = await _uploadFile(thumbFilePath, 'thumbnail');
    setState(() {
      _processPhase = 'Uploading video to firebase storage in the';
      _progress = 0.0;
    });

    final uploadTask =
        await _uploadFileBackground(video.rawVideoPath, video.uploadUrl);

    // TODO: move all this to after the task is complete
    // TODO: save thumbUrl in shared prefs?

    // setState(() {
    //   _processPhase = 'Saving video metadata to cloud firestore';
    //   _progress = 0.0;
    // });

    // final videoInfo = VideoInfo(
    //   videoUrl: videoUrl,
    //   thumbUrl: thumbUrl,
    //   coverUrl: thumbUrl,
    //   aspectRatio: aspectRatio,
    //   uploadedAt: DateTime.now().millisecondsSinceEpoch,
    //   videoName: video.videoName,
    // );

    // setState(() {
    //   _processPhase = 'Saving video metadata to cloud firestore';
    //   _progress = 0.0;
    // });

    // await FirebaseProvider.saveVideo(videoInfo);

    // setState(() {
    //   _processPhase = '';
    //   _progress = 0.0;
    //   _processing = false;
    // });
  }

  void _takeVideo() async {
    if (_imagePickerActive) return;

    _imagePickerActive = true;
    FilePickerResult result =
        await FilePicker.platform.pickFiles(type: FileType.video);

    _imagePickerActive = false;

    if (result == null) return;

    setState(() {
      _processing = true;
    });

    try {
      final String rand = '${new Random().nextInt(10000)}';
      final videoName = 'video$rand';
      await FirebaseProvider.createNewVideo(
          videoName, result.files.single.path);
    } catch (e) {
      print('${e.toString()}');
    } finally {
      setState(() {
        _processing = false;
      });
    }
  }

  _getListView() {
    return ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: _videos.length,
        itemBuilder: (BuildContext context, int index) {
          final video = _videos[index];

          return GestureDetector(
            onTap: () {
              if (!video.finishedProcessing) return;

              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return Player(
                      video: video,
                    );
                  },
                ),
              );
            },
            child: Card(
              child: Container(
                padding: EdgeInsets.all(10.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (video.thumbUrl != null)
                      Stack(
                        children: <Widget>[
                          Container(
                            width: thumbWidth.toDouble(),
                            height: video.aspectRatio * thumbWidth.toDouble(),
                            child: Center(child: CircularProgressIndicator()),
                          ),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8.0),
                            child: FadeInImage.memoryNetwork(
                              placeholder: kTransparentImage,
                              image: video.thumbUrl,
                            ),
                          ),
                        ],
                      ),
                    if (!video.finishedProcessing)
                      Container(
                        margin: new EdgeInsets.only(top: 12.0),
                        child: Text('Processing...'),
                      ),
                    SizedBox(
                      height: 20,
                    ),
                    Row(
                      children: <Widget>[
                        Text("${video.videoName}"),
                        Spacer(),
                        IconButton(
                          icon: Icon(Icons.delete),
                          onPressed: () {
                            FirebaseProvider.deleteVideo(video.videoName);
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        });
  }

  _getProgressBar() {
    return Container(
      padding: EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Container(
            margin: EdgeInsets.only(bottom: 30.0),
            child: Text(_processPhase),
          ),
          LinearProgressIndicator(
            value: _progress,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator())
          : Center(child: _processing ? _getProgressBar() : _getListView()),
      floatingActionButton: FloatingActionButton(
          child: _processing
              ? CircularProgressIndicator(
                  valueColor: new AlwaysStoppedAnimation<Color>(Colors.white),
                )
              : Icon(Icons.add),
          onPressed: _takeVideo),
    );
  }
}
