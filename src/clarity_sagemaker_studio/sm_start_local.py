import argparse
import os
from time import sleep

import boto3


def main():
    if os.path.exists("/opt/ml/metadata/resource-metadata.json"):
        raise ValueError("This should only be run on your local machine")

    parser = argparse.ArgumentParser(
        prog="sm_start_local", description="Start SSH to an EC2 / SageMaker instance"
    )
    parser.add_argument(
        "instance", help="Instance to connect to (of the form i-... or mi-...)"
    )
    parser.add_argument(
        "--public_key",
        type=str,
        help="Public key file (defaults to ~/.ssh/id_rsa.pub)",
    )
    args = parser.parse_args()

    if args.public_key is None:
        args.public_key = (
            f"{os.environ['HOME']}/.ssh/id_rsa.pub"
            if "HOME" in os.environ
            else f"{os.environ['HOMEDRIVE']}{os.environ['HOMEPATH']}\.ssh\id_rsa.pub"
        )

    with open(args.public_key, "rt") as file:
        public_key = file.read().strip()
    boto3.setup_default_session(profile_name="sagemaker")
    client = boto3.client("ssm")
    response = client.send_command(
        InstanceIds=[args.instance],
        DocumentName="AWS-RunShellScript",
        Parameters={
            "commands": [
                "mkdir -p /root/.ssh",
                "touch /root/.ssh/authorized_keys",
                "sed -i '/"
                + public_key.replace("/", "\/")
                + "/d' /root/.ssh/authorized_keys",
                f'echo "{public_key}" >> /root/.ssh/authorized_keys',
            ]
        },
    )
    command_id = response["Command"]["CommandId"]
    while True:
        response = client.list_command_invocations(CommandId=command_id, Details=True)
        if len(response["CommandInvocations"]) == 0:
            sleep(0.1)
            continue
        if response["CommandInvocations"][0]["Status"] != "InProgress":
            break
        sleep(1)
    if response["CommandInvocations"][0]["Status"] == "Success":
        print("You can now connect to your instance with")
        print(f"ssh root@{args.instance}")
    else:
        print(response["CommandInvocations"][0]["Status"])
    return 0


if __name__ == "__main__":
    exit(main())
