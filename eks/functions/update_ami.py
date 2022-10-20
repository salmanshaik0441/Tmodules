import logging.config
from datetime import date, datetime
from os import environ

import boto3
import botocore
import sys
from botocore.config import Config
from botocore.exceptions import ClientError
from dateutil.tz import tzlocal

LOGGING_LEVEL        = environ.get('LOGGING_LEVEL', logging.INFO)
AWS_REGION           = environ.get('CLUSTER_AWS_REGION')
LAUNCH_TEMPLATE_IDS  = list(environ['LAUNCH_TEMPLATE_IDS'].split(","))
CROSS_ACCOUNT_ID     = environ.get('CROSS_ACCOUNT_ID')
CROSS_ACCOUNT_ROLE   = environ.get('CROSS_ACCOUNT_ROLE')
STS_EXTERNAL_ID      = environ.get('STS_EXTERNAL_ID')
PIPELINE_TO_EXECUTE  = environ.get('PIPELINE_TO_EXECUTE')
AMI_ROLE_ARN         = environ.get('AMI_ROLE_ARN')
AMI_TYPE             = environ.get('AMI_TYPE')
K8_VERSION           = environ.get('K8_VERSION')
CODE_BUILD_ROLE      = f'arn:aws:iam::{environ.get("CROSS_ACCOUNT_ID")}:role/{environ.get("CROSS_ACCOUNT_ROLE")}'

class LambdaError(RuntimeError):
    pass


class LaunchTemplateVersionsListSizeMismatch(LambdaError):
    pass


class InstanceRefreshInProgress(LambdaError):
    pass

logging.config.dictConfig({
    'version': 1,
    'formatters': {
        'default': {
            'format': '[%(asctime)s] <%(levelname)s>: %(message)s',
        },
    },
    'handlers': {
        'console': {
            'class': 'logging.StreamHandler',
            'formatter': 'default',
        },
    },
    'root': {
        'handlers': ('console',),
        'level': LOGGING_LEVEL,
    },
})
logger = logging.getLogger(__name__)


def json_datetime_serializer(obj):
    if isinstance(obj, (datetime, date)):
        return obj.isoformat()
    raise TypeError("Type %s not serializable" % type(obj))

def assumed_role_session(role_arn, base_session=None):
    try:
        base_session = base_session or boto3.session.Session()._session
        fetcher = botocore.credentials.AssumeRoleCredentialFetcher(
            client_creator = base_session.create_client,
            source_credentials = base_session.get_credentials(),
            role_arn = role_arn
        )

        creds = botocore.credentials.DeferredRefreshableCredentials(
            method = 'assume-role',
            refresh_using = fetcher.fetch_credentials,
            time_fetcher = lambda: datetime.now(tzlocal())
        )
        botocore_session = botocore.session.Session()
        botocore_session._credentials = creds
        return boto3.Session(botocore_session = botocore_session)
    except:
        error_msg = "Unexpected error occured assuming role " + role_arn + " error is " + str(sys.exc_info()[0])
        logger.exception(error_msg)
        return None

def assumeTargetAccountRole(role_arn, session_name, sts_external_id=None):
    sts_client = boto3.client('sts')

    try:
        if sts_external_id is None:
            return sts_client.assume_role(RoleArn=role_arn,
                                          RoleSessionName=session_name,
                                          ExternalId=STS_EXTERNAL_ID
                                        )

        response = sts_client.assume_role(RoleArn=role_arn,
                                          RoleSessionName=session_name,
                                          ExternalId=STS_EXTERNAL_ID)
        return response

    except ClientError as error:
        logger.exception(error)
        return None

def ssm_parameter():
    session = assumed_role_session(role_arn=AMI_ROLE_ARN)
    if session is None:
        raise ValueError("Unable to assumed_role_session using role " + AMI_ROLE_ARN)

    ssm_client = session.client("ssm", region_name=AWS_REGION)
    get_response = ssm_client.get_parameter(Name="/ami/vc/" + AWS_REGION + "/os/AMZEKS/" + K8_VERSION + "/" + AMI_TYPE,
                                            WithDecryption=False)
    return get_response['Parameter']['Value']

def lt_config(lt_id):
    client = boto3.client('ec2', region_name=AWS_REGION)
    response = client.describe_launch_template_versions(
        LaunchTemplateId=lt_id,
    )

    return response['LaunchTemplateVersions'][0]['LaunchTemplateData']['ImageId']

def start_pipeline(assume_response):
    aws_access_key_id=assume_response['Credentials']['AccessKeyId']
    aws_secret_access_key=assume_response['Credentials']['SecretAccessKey']
    aws_session_token=assume_response['Credentials']['SessionToken']

    codepipeline_client = boto3.client('codepipeline',
                          aws_access_key_id=aws_access_key_id,
                          aws_secret_access_key=aws_secret_access_key,
                          aws_session_token=aws_session_token,
                          config=Config(region_name='eu-west-1'))


    logger.info("Starting execution of pipeline: %s", PIPELINE_TO_EXECUTE)
    codepipeline_client.start_pipeline_execution(name=PIPELINE_TO_EXECUTE)

def is_pipeline_running(assume_response):
    aws_access_key_id=assume_response['Credentials']['AccessKeyId']
    aws_secret_access_key=assume_response['Credentials']['SecretAccessKey']
    aws_session_token=assume_response['Credentials']['SessionToken']
    
    try:
        codepipeline_client = boto3.client('codepipeline',
                                            aws_access_key_id=aws_access_key_id,
                                            aws_secret_access_key=aws_secret_access_key,
                                            aws_session_token=aws_session_token,
                                            config=Config(region_name='eu-west-1'))
        response = codepipeline_client.list_pipeline_executions(pipelineName=PIPELINE_TO_EXECUTE)
        return response['pipelineExecutionSummaries'][0]['status'] == 'InProgress'
             
    except codepipeline_client.exceptions.PipelineNotFoundException as no_pipeline:
        logger.error("Pipeline " + PIPELINE_TO_EXECUTE + " not found")
        return False
    except ClientError as error:
        logger.error(error)
        raise error
    
def needs_update():
    latest_ami = ssm_parameter().strip()
    needs_update = False
    assume_response = None

    for lt_id in LAUNCH_TEMPLATE_IDS:
        lt_ami = lt_config(lt_id).strip()
        # print(f'LaunchTemplateID:{lt_id} LaunchTemplateAMI:{lt_ami} LatestAMI:{latest_ami}')
        logger.info('LaunchTemplateID:'+lt_id+' LaunchTemplateAMI:'+lt_ami+' LatestAMI:'+latest_ami)

        if latest_ami != lt_ami:
            needs_update = True
            print(f'New AMI release need to trigger build')
            break

    if needs_update:
        assume_response = assumeTargetAccountRole(role_arn=CODE_BUILD_ROLE,
                                                  session_name='eks_ami_triggered_lambda',
                                                  sts_external_id=STS_EXTERNAL_ID)
        if assume_response is None:
            logger.exception("Failed to assume role to kick off pipeline " + PIPELINE_TO_EXECUTE)
            return

        logger.info("AMI needs updating about to trigger the following pipeling " + PIPELINE_TO_EXECUTE)
        # print("AMI needs updating about to trigger the following pipeling " + PIPELINE_TO_EXECUTE)
        if not is_pipeline_running(assume_response):
            logger.info('Triggering Pipeline')
            start_pipeline(assume_response)
        else:
            logger.info('Pipeline already running')

def lambda_handler(event, context):
    # print("in handler")
    try:
        needs_update()

    except ValueError as ssm_error:
        logger.error(ssm_error)
    except:
        return None


