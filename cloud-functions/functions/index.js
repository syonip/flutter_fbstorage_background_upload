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
    const filePath = object.name;
    console.log("filePath:")
    console.log(filePath)
    const extension = filePath.split('.')[filePath.split('.').length - 1];
    if (extension != 'mp4') {
        return console.log(`File extension: ${extension}. This is not a video. Exiting function.`);
    }

    const videoId = filePath.split('.')[0]
    console.log(`Setting data in firestore doc: ${videoId}`)
    await admin.firestore().collection("videos").doc(videoId).set({
        uploadComplete: true
    }, { merge: true });

    console.log('Done');
});
