import json
import os

import boto3

table = boto3.resource("dynamodb").Table(os.environ["TABLE_NAME"])


def lambda_handler(event, context):
    # Atomic update prevents race conditions across concurrent visitors
    response = table.update_item(
        Key={"id": "visitor_count"},
        UpdateExpression="ADD #v :inc",
        ExpressionAttributeNames={"#v": "views"},
        ExpressionAttributeValues={":inc": 1},
        ReturnValues="UPDATED_NEW",
    )
    views = int(response["Attributes"]["views"])
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps({"count": views}),
    }
