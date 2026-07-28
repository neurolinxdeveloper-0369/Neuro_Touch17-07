const https = require('https');

// Replace with your actual backend URL once the domain/SSL is active
const BACKEND_URL = 'https://api.neurolinx.in/api/v1/alexa/directive';

exports.handler = async (event, context) => {
    return new Promise((resolve, reject) => {
        const data = JSON.stringify(event);

        const url = new URL(BACKEND_URL);
        const options = {
            hostname: url.hostname,
            port: 443,
            path: url.pathname,
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'Content-Length': data.length
            },
            // Note: Alexa requires valid CA-signed SSL certificates. Let's Encrypt is perfect.
        };

        const req = https.request(options, (res) => {
            let body = '';
            res.on('data', (chunk) => body += chunk);
            res.on('end', () => {
                if (res.statusCode >= 200 && res.statusCode < 300) {
                    resolve(JSON.parse(body));
                } else {
                    console.error('Backend returned error:', res.statusCode, body);
                    // Still attempt to parse the error message if backend sent one
                    try {
                        resolve(JSON.parse(body));
                    } catch (e) {
                        reject(new Error(`Backend failed with status ${res.statusCode}`));
                    }
                }
            });
        });

        req.on('error', (e) => {
            console.error('Network Error:', e);
            reject(e);
        });

        req.write(data);
        req.end();
    });
};
