import json

import boto3

if __name__ == "__main__":
    lambda_client = boto3.client("lambda")
    results = json.loads(
        lambda_client.invoke(
            FunctionName=f"sagemaker-police",
            InvocationType="RequestResponse",
        )["Payload"].read()
    )
    print(results)
