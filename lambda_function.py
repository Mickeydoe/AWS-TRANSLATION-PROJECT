import boto3
import json
import os
from datetime import datetime

# Initialize AWS services
translate_client = boto3.client("translate")
s3_client = boto3.client("s3")

# Get S3 bucket names from environment variables
REQUEST_BUCKET = os.environ["REQUEST_BUCKET"]
RESPONSE_BUCKET = os.environ["RESPONSE_BUCKET"]

def lambda_handler(event, context):
    """Lambda function to process text translation and store results in S3."""
    try:
        # Parse JSON request body
        body = json.loads(event["body"])
        text = body.get("text", "")
        source_lang = body.get("source_language", "")
        target_lang = body.get("target_language", "")

        # Validate input
        if not text or not source_lang or not target_lang:
            return {
                "statusCode": 400,
                "headers": {"Access-Control-Allow-Origin": "*"},
                "body": json.dumps("Missing required parameters.")
            }

        # Perform translation
        translated_text = translate_client.translate_text(
            Text=text,
            SourceLanguageCode=source_lang,
            TargetLanguageCode=target_lang
        )["TranslatedText"]

        # Generate timestamp for storage
        timestamp = datetime.utcnow().strftime("%Y-%m-%dT%H:%M:%SZ")
        request_filename = f"request-{timestamp}.json"
        response_filename = f"response-{timestamp}.json"

        # Save original text to request bucket
        s3_client.put_object(
            Bucket=REQUEST_BUCKET,
            Key=request_filename,
            Body=json.dumps({
                "timestamp": timestamp,
                "source_language": source_lang,
                "target_language": target_lang,
                "original_text": text
            }),
            ContentType="application/json"
        )

        # Save translated text to response bucket
        s3_client.put_object(
            Bucket=RESPONSE_BUCKET,
            Key=response_filename,
            Body=json.dumps({
                "timestamp": timestamp,
                "source_language": source_lang,
                "target_language": target_lang,
                "original_text": text,
                "translated_text": translated_text
            }),
            ContentType="application/json"
        )

        # Return translated text
        return {
            "statusCode": 200,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps({"original_text": text, "translated_text": translated_text})
        }

    except Exception as e:
        print(f"Error: {str(e)}")
        return {
            "statusCode": 500,
            "headers": {"Access-Control-Allow-Origin": "*"},
            "body": json.dumps("Translation failed")
        }