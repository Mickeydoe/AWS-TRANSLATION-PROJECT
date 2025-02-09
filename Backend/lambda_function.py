import boto3
import json
import os

s3_client = boto3.client("s3")
translate_client = boto3.client("translate")

REQUEST_BUCKET = os.environ["REQUEST_BUCKET"]
RESPONSE_BUCKET = os.environ["RESPONSE_BUCKET"]

def lambda_handler(event, context):
    """Lambda function to process translation request."""
    try:
        # Extract file info from S3 event
        record = event["Records"][0]
        file_name = record["s3"]["object"]["key"]
        bucket_name = record["s3"]["bucket"]["name"]

        # Retrieve file from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=file_name)
        file_content = response["Body"].read().decode("utf-8")

        # Extract source and target languages (assuming filename format: source-target-file.txt)
        source_lang, target_lang, _ = file_name.split("-", 2)

        # Perform translation
        translated_text = translate_client.translate_text(
            Text=file_content,
            SourceLanguageCode=source_lang,
            TargetLanguageCode=target_lang
        )["TranslatedText"]

        # Save translated text to response bucket
        translated_file_name = f"translated-{file_name}"
        s3_client.put_object(
            Bucket=RESPONSE_BUCKET,
            Key=translated_file_name,
            Body=translated_text
        )

        return {"statusCode": 200, "body": json.dumps("Translation successful")}
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return {"statusCode": 500, "body": json.dumps("Translation failed")}
