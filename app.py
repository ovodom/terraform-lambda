import json
import boto3
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('notes-table')

def lambda_handler(event, context):

    method = event.get("requestContext", {}).get("http", {}).get("method", "")
    path = event.get("rawPath", "")

    body = json.loads(event.get("body") or "{}")

    # POST /notes
    if method == "POST" and "/notes" in path:
        item = {
            "id": str(uuid.uuid4()),
            "title": body.get("title"),
            "content": body.get("content")
        }

        table.put_item(Item=item)

        return {
            "statusCode": 200,
            "body": json.dumps(item)
        }

    # GET /notes
    if method == "GET" and "/notes" in path:
        data = table.scan()

        return {
            "statusCode": 200,
            "body": json.dumps(data.get("Items", []))
        }

    return {
        "statusCode": 400,
        "body": json.dumps({"error": "Invalid route"})
    }