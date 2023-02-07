import os
import re
from datetime import datetime, timedelta, timezone

import boto3

ses_client = boto3.client("ses")
sagemaker_client = boto3.client("sagemaker")

ADMIN_EMAIL = os.environ["ADMIN_EMAIL"]
EMAIL_DOMAIN = os.environ["EMAIL_DOMAIN"]


def is_long_running_instance(app):
    if app["AppType"] == "JupyterServer" or app["Status"] != "InService":
        return False
    instance_type = re.findall(r"(ml-[^-]*-[^-]*)", app["AppName"])[0]
    return (  # cheap instance
        instance_type[3:5] == "t3"
        and datetime.now(timezone.utc) - app["CreationTime"] > timedelta(days=5)
    ) or (  # expensive instance
        instance_type[3:5] != "t3"
        and datetime.now(timezone.utc) - app["CreationTime"] > timedelta(days=1)
    )


def lambda_handler(event, context):
    user_emails = set(
        f"{user_profile['UserProfileName'].replace('-', '.')}@{EMAIL_DOMAIN}"
        for user_profile in sagemaker_client.list_user_profiles()["UserProfiles"]
        for app in sagemaker_client.list_apps(
            UserProfileNameEquals=user_profile["UserProfileName"]
        )["Apps"]
        if is_long_running_instance(app)
    )

    for user_email in user_emails:
        try:
            ses_client.send_email(
                Source=ADMIN_EMAIL,
                Destination={
                    "ToAddresses": [user_email],
                    "CcAddresses": [ADMIN_EMAIL],
                },
                Message={
                    "Subject": {
                        "Data": "You have a long running SageMaker Studio instance",
                        "Charset": "UTF-8",
                    },
                    "Body": {
                        "Text": {
                            "Data": "Please consider whether you should terminate it.",
                            "Charset": "UTF-8",
                        }
                    },
                },
            )

        except ses_client.exceptions.MessageRejected as exception:
            ses_client.send_email(
                Source=ADMIN_EMAIL,
                Destination={"ToAddresses": [ADMIN_EMAIL]},
                Message={
                    "Subject": {
                        "Data": f"Unable to send an email to {user_email}",
                        "Charset": "UTF-8",
                    },
                    "Body": {
                        "Text": {
                            "Data": str(exception),
                            "Charset": "UTF-8",
                        }
                    },
                },
            )

    spaces = set(
        space["SpaceName"]
        for space in sagemaker_client.list_spaces()["Spaces"]
        for app in sagemaker_client.list_apps(SpaceNameEquals=space["SpaceName"])[
            "Apps"
        ]
        if is_long_running_instance(app)
    )

    if len(spaces) > 0:
        ses_client.send_email(
            Source=ADMIN_EMAIL,
            Destination={"ToAddresses": [ADMIN_EMAIL]},
            Message={
                "Subject": {
                    "Data": f"There are long running SageMaker Studio space instances",
                    "Charset": "UTF-8",
                },
                "Body": {
                    "Text": {
                        "Data": f"Please check the following spaces: {', '.join(spaces)}.",
                        "Charset": "UTF-8",
                    }
                },
            },
        )

    return {"statusCode": 200}
