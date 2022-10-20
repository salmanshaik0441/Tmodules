'use strict';
let os = require('os');
let fs = require('fs');
let https = require('https');
let AWS = require('aws-sdk');
AWS.config.update({
    logger: console,
    httpOptions: {
        timeout: 5000,
        connectTimeout: 1000
    }
});

let config = {};

function safeString(str, maxlen) {
    let newstring = "";
    maxlen = maxlen || 10000;

    for (let i = 0; i < (maxlen < str.length ? maxlen : str.length); i++) {
        if (str.charCodeAt(i) <= 127) {
            newstring += str.charAt(i);
        }
    }
    return newstring;
}

function paramListToObj(params) {

    let retObj = {};
    for (let p in params) {
        let kname = params[p]["Name"].split('/');
        kname = kname[kname.length - 1];
        retObj[kname] = params[p]["Value"];
    }
    return retObj;
}

let postToElastic = function(postData, cb) {

    var d = new Date();
    var dateIndex = d.getFullYear() + '-' + ('0' + (d.getMonth() + 1)).slice(-2) + '-' + ('0' + d.getDay()).slice(-2);
    var esindex = config.esindex + '-' + dateIndex;

    let opts = {
        host: config.eshost,
        port: config.esport,
        path: '/' + esindex + '/_bulk',
        method: 'POST',
        headers: {
            'Content-Type': 'application/json'
        }
    };

    let req = https.request(opts, function(response) {
        let body = '';
        response.on('data', function(d) {
            body += d;
        });
        response.on('end', function() {
            cb(null, body);
        });
    });

    req.on('error', function(e) {
        cb(e);
    });
    req.write(postData);
    req.end();

};

let paramdata = {};


exports.handler = async (event, context) => {

    let currentEnv = process.env.ENVIRONMENT;
    let currentDomain = process.env.DOMAIN;
    let SSM = new AWS.SSM({
        apiVersion: '2014-11-06',
        region: 'af-south-1'
    });
    let paramlist = {
        Names: [
            "/" + currentDomain + "/" + currentEnv + "/lambda/aws/auditevent/es/index",
            "/" + currentDomain + "/" + currentEnv + "/lambda/aws/auditevent/elasticsearch/url"
        ],
        WithDecryption: true
    };
    console.log("SSM_DATA_REQUESTED ");

    try {
        paramdata = await SSM.getParameters(paramlist).promise();
    } catch (e) {
        console.log("SSM_DATA_ERROR " + JSON.stringify(e));
        return;
    }
    console.log("SSM_DATA_RECEIVED ");
    paramdata = paramListToObj(paramdata["Parameters"]);

    let esURL = new URL(paramdata['url']);
    config.esport = esURL.port;
    config.eshost = esURL.hostname;
    config.esindex = paramdata['index'];

    const promise = new Promise(async function(resolve, reject) {
        let qItems = [];
        try {
            for (let eventItem in event.Records) {

                let singleData = event.Records[eventItem].body;
                if (event.Records[eventItem].messageAttributes){
                  singleData = JSON.parse(singleData);
                  for (var ma in event.Records[eventItem].messageAttributes){
                      singleData["messageAttribute-" + ma] = event.Records[eventItem].messageAttributes[ma]['stringValue'];
                  }
                  singleData = JSON.stringify(singleData);
                }
                qItems.push('{"index":{}}');
                qItems.push(singleData);
            }

            let postData = qItems.join("\n") + "\n";
            postToElastic(postData, function(e, d) {
                if (e) {
                    console.log("ELASTIC_ERROR " + e + JSON.stringify(e));
                    resolve({
                        status: "ERROR"
                    });
                    return;
                }
                console.log('ES_POST_SUCCESS ' + "Posted " + (qItems.length / 2) + " items");
                resolve({
                    status: "SUCCESS"
                });
            });

        } catch (err) {
            console.log("IO_ERROR " + err + JSON.stringify(err));
            reject({
                status: "ERROR"
            });
        }
    });
    return promise;
};

exports.handler({})
