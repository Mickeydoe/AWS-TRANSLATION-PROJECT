import boto3
import json
import os
import base64
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
        print("Event Received:", event)  # Debugging logs
        
        content_type = event.get("headers", {}).get("Content-Type", "")
        text = ""
        source_lang = ""
        target_lang = ""

        # Check if request is JSON or a file upload
        if "application/json" in content_type:
            body = json.loads(event["body"])
            text = body.get("text", "")
            source_lang = body.get("source_language", "")
            target_lang = body.get("target_language", "")

        elif event.get("isBase64Encoded", False):  # File upload scenario
            decoded_file = base64.b64decode(event["body"]).decode("utf-8")
            text = decoded_file.strip()

            # Set default language codes for testing (modify as needed)
            source_lang = "en"  # Change based on input file
            target_lang = "de"

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
        request_filename = f"request-{timestamp}.txt"
        response_filename = f"response-{timestamp}.txt"

        # Save original text to request bucket
        s3_client.put_object(
            Bucket=REQUEST_BUCKET,
            Key=request_filename,
            Body=text,
            ContentType="text/plain"
        )

        # Save translated text to response bucket
        s3_client.put_object(
            Bucket=RESPONSE_BUCKET,
            Key=response_filename,
            Body=translated_text,
            ContentType="text/plain"
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
            "body": json.dumps({"error": str(e)})
        }
