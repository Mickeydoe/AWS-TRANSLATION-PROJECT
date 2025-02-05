import boto3
import json
import os

# AWS Clients
s3_client = boto3.client('s3')
translate_client = boto3.client('translate')

# Environment variables (set in Terraform)
REQUEST_BUCKET = os.environ['REQUEST_BUCKET']
RESPONSE_BUCKET = os.environ['RESPONSE_BUCKET']

def upload_to_s3(bucket_name, file_name, data):
    """Uploads a JSON file to an S3 bucket."""
    try:
        s3_client.put_object(
            Bucket=bucket_name,
            Key=file_name,
            Body=json.dumps(data, indent=4),
            ContentType="application/json"
        )
        print(f"Uploaded {file_name} to {bucket_name}.")
    except Exception as e:
        print(f"Error uploading to S3: {str(e)}")

def translate_text(source_language, target_language, text):
    """Performs translation using AWS Translate."""
    response = translate_client.translate_text(
        Text=text,
        SourceLanguageCode=source_language,
        TargetLanguageCode=target_language
    )
    return response["TranslatedText"]

def lambda_handler(event, context):
    """AWS Lambda function to process S3 translation requests."""
    try:
        # Extract file information from S3 event
        record = event['Records'][0]
        bucket_name = record['s3']['bucket']['name']
        object_key = record['s3']['object']['key']

        # Retrieve file from S3
        response = s3_client.get_object(Bucket=bucket_name, Key=object_key)
        content = json.loads(response['Body'].read().decode('utf-8'))

        # Extract translation details
        source_language = content["source_language"]
        target_language = content["target_language"]
        text = content["text"]

        # Perform the translation
        print(f"Translating from {source_language} to {target_language}: {text}")
        translated_text = translate_text(source_language, target_language, text)

        # Prepare response data
        response_data = {
            "request_id": object_key,  # Using filename as unique request ID
            "source_language": source_language,
            "target_language": target_language,
            "original_text": text,
            "translated_text": translated_text
        }

        # Save response to S3
        response_file_name = object_key.replace("request", "response")  # Naming translated response
        upload_to_s3(RESPONSE_BUCKET, response_file_name, response_data)

        print("Translation completed successfully.")
        return {"statusCode": 200, "body": json.dumps("Translation completed")}

    except Exception as e:
        print(f"Error processing translation: {str(e)}")
        return {"statusCode": 500, "body": json.dumps("Translation failed")}

