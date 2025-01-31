import boto3 
import json
import uuid
from datetime import datetime, timezone

# AWS resource configurations
translate_client = boto3.client('translate', region_name='us-east-1')  #Create client for AWS translate
s3_client = boto3.client('s3') #creates a client for amazon s3 which allows interacting with S3 buckets

# S3 bucket names on AWS
REQUEST_BUCKET = "translation-request-bucket"  #Bucket for storing translation request
RESPONSE_BUCKET = "response-and-logs-store-bucket"  #Bucket for storing translation response

def upload_to_s3(bucket_name, file_name, data): #function that uploads JSON file to s3 bucket
    """Upload a file to an S3 bucket."""
    try:
        s3_client.put_object(
            Bucket=bucket_name,
            Key=file_name,
            Body=json.dumps(data, indent=4),
            ContentType="application/json"
        )
        print(f"Uploaded {file_name} to {bucket_name}.")
    except s3_client.exceptions.NoSuchBucket:
        print(f"Error: Bucket '{bucket_name}' does not exist. Please create it before running the script.")
        exit(1)

def translate_text(source_language, target_language, text):
    """Perform translation using AWS Translate."""
    response = translate_client.translate_text(
        Text=text,
        SourceLanguageCode=source_language,
        TargetLanguageCode=target_language
    )
    return response

def main():
    print("=== AWS Translate Script ===")

    # Get user input
    source_language = input("Enter source language code (e.g., 'en' for English): ").strip()
    target_language = input("Enter target language code (e.g., 'es' for Spanish): ").strip()
    text = input("Enter text to translate: ").strip()

    # Generate a unique request ID
    request_id = str(uuid.uuid4())

    # Log the request data
    request_data = {
        "request_id": request_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "source_language": source_language,
        "target_language": target_language,
        "text": text
    }
    request_file_name = f"translation_request_{request_id}.json"
    upload_to_s3(REQUEST_BUCKET, request_file_name, request_data)

    # Perform the translation
    print("Translating text...")
    translation_response = translate_text(source_language, target_language, text)

    # Log the response data
    response_data = {
        "request_id": request_id,
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "source_language": source_language,
        "target_language": target_language,
        "original_text": text,
        "translated_text": translation_response["TranslatedText"]
    }
    response_file_name = f"translation_response_{request_id}.json"
    upload_to_s3(RESPONSE_BUCKET, response_file_name, response_data)

    # Print results
    print("Translation completed!")
    print(f"Original Text: {text}")
    print(f"Translated Text: {translation_response['TranslatedText']}")

if __name__ == "__main__":
    main()
