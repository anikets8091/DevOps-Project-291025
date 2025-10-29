import json
import os
import boto3

sns_topic_arn = os.environ['SNS_TOPIC_ARN']
sns = boto3.client('sns')

def handler(event, context):
    msg = {
        "message": "S3 object created",
        "event": event
    }
    sns.publish(TopicArn=sns_topic_arn, Message=json.dumps(msg))
    return {"status": "ok"}
