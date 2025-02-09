# Use AWS Lambda Base Image for Python 3.9
FROM public.ecr.aws/lambda/python:3.9

# Set working directory
WORKDIR /app

# Copy function code
COPY lambda_function.py .


# Command to run AWS Lambda function
CMD ["lambda_function.lambda_handler"]
