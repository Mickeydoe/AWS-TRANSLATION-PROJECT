import boto3
import json

# Initialize AWS Translate client
translate_client = boto3.client("translate")

def lambda_handler(event, context):
    """Lambda function to process text translation request."""
    try:
        # Parse JSON request body
        body = json.loads(event["body"])
        text = body.get("text", "")
        source_lang = body.get("source_language", "")
        target_lang = body.get("target_language", "")

        # Validate input
        if not text or not source_lang or not target_lang:
            return {"statusCode": 400, "body": json.dumps("Missing required parameters.")}

        # Perform translation
        translated_text = translate_client.translate_text(
            Text=text,
            SourceLanguageCode=source_lang,
            TargetLanguageCode=target_lang
        )["TranslatedText"]

        # Return translated text
        return {
            "statusCode": 200,
            "body": json.dumps({"original_text": text, "translated_text": translated_text})
        }
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {"statusCode": 500, "body": json.dumps("Translation failed")}
