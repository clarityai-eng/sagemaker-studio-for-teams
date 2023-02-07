import json
import os
from base64 import b64decode
from time import sleep


class Bastion:
    def __init__(self, session, key_filename=None):
        client = session.client("secretsmanager")
        secret_value = json.loads(
            client.get_secret_value(SecretId="sagemaker-bastion-connection")[
                "SecretString"
            ]
        )
        self.instance_id = secret_value["instance_id"]
        self.private_key = b64decode(secret_value["private_key"]).decode()
        self.client = session.client("ssm")

    def get_instance_id(self):
        return self.instance_id

    def save_private_key(self, key_filename):
        with open(key_filename, "wt") as file:
            file.write(self.private_key)
        os.chmod(key_filename, 0o600)

    def execute_commands(self, commands):
        response = self.client.send_command(
            InstanceIds=[self.instance_id],
            DocumentName="AWS-RunShellScript",
            Parameters={"commands": commands},
        )
        command_id = response["Command"]["CommandId"]
        while True:
            response = self.client.list_command_invocations(
                CommandId=command_id, Details=True
            )
            if len(response["CommandInvocations"]) == 0:
                sleep(0.1)
                continue
            if response["CommandInvocations"][0]["Status"] != "InProgress":
                break
            sleep(1)
        return response["CommandInvocations"][0]["CommandPlugins"][0]["Output"]
