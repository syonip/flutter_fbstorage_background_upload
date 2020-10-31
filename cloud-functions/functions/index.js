const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.uploadNewVideo = functions.firestore
    .document('videos/{videoId}')
    .onCreate(async (snap, context) => {
        const bucket = admin.storage().bucket();
        const fileName = `${context.params.videoId}.mp4`;
        const videoFile = bucket.file(fileName);
        const resumableUpload = await videoFile.createResumableUpload();
        const uploadUrl = resumableUpload[0];

        console.log(uploadUrl);

        await admin.firestore().collection("videos").doc(context.params.videoId).set({
            uploadUrl
        }, { merge: true });
    });

exports.deleteVideo = functions.firestore
    .document('videos/{videoId}')
    .onDelete(async (snap, context) => {
        const bucket = admin.storage().bucket();
        const fileName = `${context.params.videoId}.mp4`;
        const videoFile = bucket.file(fileName);
        await videoFile.delete();
        console.log(`deleted ${fileName}`);
    });

exports.newStorageFile = functions.storage.object().onFinalize(async (object) => {
    const fileBucket = object.bucket; // The Storage bucket that contains the file.
    const filePath = object.name; // File path in the bucket.
    const contentType = object.contentType; // File content type.
    //const metageneration = object.metageneration; // Number of times metadata has been generated. New objects have a value of 1.

    console.log("fileBucket:")
    console.log(fileBucket)
    console.log("filePath:")
    console.log(filePath)
    console.log("contentType:")
    console.log(contentType)

    const extension = filePath.split('.')[filePath.split('.').length - 1];
    if (extension != 'mp4') {
        return console.log(`File extension: ${extension}. This is not a video. Exiting function.`);
    }

    // const fileName = filePath.split("/")[1];


    const bucket = admin.storage().bucket(fileBucket)
    const videoFile = bucket.file(filePath)
    console.log(`Getting signed Url for videoFile: ${videoFile.name}`)
    const downloadUrlArr = await videoFile.getSignedUrl({
        action: 'read',
    })
    const downloadUrl = downloadUrlArr[0]
    console.log(`got signed url: ${downloadUrl}`)


    const videoId = videoFile.name.split('.')[0]
    console.log(`Setting data in firestore doc: ${videoId}`)
    await admin.firestore().collection("videos").doc(videoId).set({
        finishedProcessing: true,
        videoUrl: downloadUrl,
    }, { merge: true });

    console.log('Done')


});

