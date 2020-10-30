const admin = require('firebase-admin');
const axios = require('axios').default;
const queryString = require('query-string');
const serverKey = require('./admin-credentials.json')

admin.initializeApp({
    credential: admin.credential.cert(serverKey),
    storageBucket: "imagesdemo-a95c2.appspot.com",
});


async function run() {
    const bucket = admin.storage().bucket()
    const file = bucket.file(`123456.jpg`)
    const signedUrlArr = await file.createResumableUpload();
    
    const signedUrl = signedUrlArr[0]
    const qsArr = signedUrl.split('?')
    const signedUrlAddress = qsArr[0];
    const signedUrlParams = queryString.parse(qsArr[1]);

    try {

        const response = await axios.put(
                signedUrlAddress,
                '1233456',
                { params: signedUrlParams },
                // options,
            )

        console.log(response)

    } catch (e) {
        console.error(e.response.data)
    }
}


run();
