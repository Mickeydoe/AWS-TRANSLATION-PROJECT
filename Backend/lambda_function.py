import boto3
import json

translate_client = boto3.client('translate')

def lambda_handler(event, context):
    try:
        # Parse API Gateway request body
        body = json.loads(event["body"])
        source_language = body["source_language"]
        target_language = body["target_language"]
        text = body["text"]

        # Call AWS Translate
        translated_text = translate_client.translate_text(
            Text=text,
            SourceLanguageCode=source_language,
            TargetLanguageCode=target_language
        )["TranslatedText"]

        return {
            "statusCode": 200,
            "headers": {"Content-Type": "application/json"},
            "body": json.dumps({"translated_text": translated_text})
        }

    except Exception as e:
        return {
            "statusCode": 500,
            "body": json.dumps({"error": str(e)})
        }
