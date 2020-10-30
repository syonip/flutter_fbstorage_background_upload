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
    })
