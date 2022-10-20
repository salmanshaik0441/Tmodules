'use strict';
var os = require('os');
var fs = require('fs');
var oracledb = require('oracledb-prebuilt-for-lambda');
var AWS = require('aws-sdk');
AWS.config.update({
    logger: console,
    httpOptions: {
        timeout: 5000,
        connectTimeout: 1000
    }
});

function safeString(str, maxlen) {
    let newstring = "";
    maxlen = maxlen || 10000;

    if (!str || !str.length) {
        return "";
    }
    for (var i = 0; i < (maxlen < str.length ? maxlen : str.length); i++) {
        if (str.charCodeAt(i) <= 127) {
            newstring += str.charAt(i);
        }
    }
    return newstring;
}

function paramListToObj(params) {

    let retObj = {};
    for (var p in params) {
        let kname = params[p]["Name"].split('/');
        kname = kname[kname.length - 1];
        retObj[kname] = params[p]["Value"];
    }
    return retObj;
}

let paramdata = {};
let connection = 0;

exports.handler = async (event, context) => {

    let str_host = os.hostname() + ' localhost\n';
    fs.writeFileSync(process.env.HOSTALIASES, str_host, function(err) {
        if (err) throw err;
    });

    let currentEnv = process.env.ENVIRONMENT;
    let currentDomain = process.env.DOMAIN;
    let SSM = new AWS.SSM({
        apiVersion: '2014-11-06',
        region: 'af-south-1'
    });
    let paramlist = {
        Names: ["/" + currentDomain + "/" + currentEnv + "/database/aws/auditevent/password",
            "/" + currentDomain + "/" + currentEnv + "/database/aws/auditevent/username",
            "/" + currentDomain + "/" + currentEnv + "/database/aws/auditevent/connectionstring",
            "/" + currentDomain + "/" + currentEnv + "/database/aws/auditevent/schema"
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

    var connAttr = {
        user: paramdata['username'],
        password: paramdata['password'],
        connectString: paramdata['connectionstring']
    };

    const promise = new Promise(async function(resolve, reject) {
        try {
            if (!connection) {
                connection = await oracledb.getConnection(connAttr);
            }

            let bindParams = [];
            for (let eventItem in event.Records) {

                let eiObj = JSON.parse(event.Records[eventItem].body);

                eiObj.vodMsAuditReponse = eiObj.vodMsAuditReponse || {};
                eiObj.vodMsAuditRequest = eiObj.vodMsAuditRequest || {};
                eiObj.auditLayer = Math.max(['', 'Contoller', 'Service', 'Data', 'Other'].indexOf(eiObj.auditLayer), 0);
                eiObj.auditLevel = Math.max(['', 'High', 'Medium', 'low'].indexOf(eiObj.auditLevel), 0);
                eiObj.operationMethodStatus = Math.max(['FAILED', 'SUCCESS'].indexOf(eiObj.operationMethodStatus), 0);

                let recordArr = [
                    eiObj.guid,
                    new Date(eiObj.dateTime),
                    eiObj.auditLevel,
                    safeString(eiObj.msisdn, 100),
                    safeString(eiObj.message, 300),
                    safeString(eiObj.className, 100),
                    safeString(eiObj.packageName, 100),
                    safeString(eiObj.operationMethod, 50),
                    safeString(eiObj['arguments'], 5000),
                    safeString(eiObj.authenticationName, 50),
                    safeString(eiObj.vodMsAuditRequest.path, 300),
                    safeString(eiObj.vodMsAuditRequest.method, 50),
                    safeString(eiObj.vodMsAuditRequest.queryParams, 300),
                    safeString(eiObj.vodMsAuditRequest.requestBody, 4000),
                    safeString(eiObj.vodMsAuditRequest.headerParams, 400),
                    safeString(eiObj.vodMsAuditRequest.formParams, 300),
                    safeString(eiObj.vodMsAuditRequest.cleint, 200),
                    safeString(eiObj.vodMsAuditRequest.sessionId, 50),
                    eiObj.vodMsAuditReponse.repsonseBody,
                    eiObj.vodMsAuditReponse.statusCode,
                    eiObj.auditLayer,
                    eiObj.operationMethodStatus,
                    eiObj.exception
                ];

                bindParams.push(recordArr);
            }

            let resultData;
            try {
                resultData = await connection.executeMany(
                    'INSERT INTO ' + paramdata['schema'] + '.VOD_MS_AUDIT_EVENT (GUID, EVENT_TIMESTAMP, AUDIT_LEVEL, MSISDN, MESSAGE, CLASS_NAME, PACKAGE_NAME, OPERATION_METHOD, ARGUMENTS,AUTHENTICATION,REQUEST_PATH,REQUEST_MEHOD,REQUEST_QUERY_PARAMTERS,REQUEST_BODY,REQUEST_HEADERS,REQUEST_FORM_PARAMS,REQUEST_CLEINT,REQUEST_SESSIONID,RESPONSE_BODY, RESPONSE_STATUS_CODE, AUDIT_LAYER, OPERATION_METHOD_STATUS, EXCEPTION) VALUES(:0,:1,:2,:3,:4,:5,:6,:7,:8,:9,:10,:11,:12,:13,:14,:15,:16,:17,:18,:19,:20,:21,:22)', bindParams, {
                        autoCommit: true,
                        batchErrors: true
                    });
            } catch (inserr) {
                console.log("EVENT_INSERT_ERROR " + inserr + JSON.stringify({
                    err: inserr,
                }));
            }
            console.log("EVENT_INSERT_SUCCESS " + JSON.stringify({
                result: resultData,
                eventsCount: bindParams.length
            }));

            resolve({
                status: "SUCCESS"
            });
        } catch (err) {
            console.log("DATABASE_ERROR " + err + JSON.stringify(err));
            reject({
                status: "ERROR"
            });
        }
    });
    return promise;
};
