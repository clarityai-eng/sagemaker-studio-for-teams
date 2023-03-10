import argparse
import re
from time import sleep

import boto3

from .utils import Bastion


class SageMakerStudio:
    def __init__(
        self,
        session,
        user_profile_name,
        domain_name="datascience",
    ):
        self.client = session.client("sagemaker")
        self.user_profile_name = user_profile_name
        self.profile_name = session.profile_name
        self.domain_id = self.get_domain_id(domain_name)
        self.bastion = Bastion(session=session)
        self.ssm_client = session.client("ssm")

    def get_domain_id(self, domain_name):
        domain = [
            domain
            for domain in self.client.list_domains()["Domains"]
            if domain["DomainName"] == domain_name
        ]
        if len(domain) < 1:
            raise ValueError(
                f"No {domain_name} domain found in {self.profile_name} profile"
            )
        return domain[0]["DomainId"]

    def get_apps(self, user_profile_name, space_name=None):
        if space_name is None:
            return self.client.list_apps(
                UserProfileNameEquals=user_profile_name,
                DomainIdEquals=self.domain_id,
            )["Apps"]
        return self.client.list_apps(
            SpaceNameEquals=space_name,
            DomainIdEquals=self.domain_id,
        )["Apps"]

    def up(self, space_name=None):
        if space_name is not None:
            spaces = self.client.list_spaces(DomainIdEquals=self.domain_id)["Spaces"]
            if space_name not in [space["SpaceName"] for space in spaces]:
                self.client.create_space(DomainId=self.domain_id, SpaceName=space_name)
                print(f"Created space {space_name}")

            response = self.client.create_presigned_domain_url(
                DomainId=self.domain_id,
                UserProfileName=self.user_profile_name,
                SpaceName=space_name,
            )

        else:
            response = self.client.create_presigned_domain_url(
                DomainId=self.domain_id,
                UserProfileName=self.user_profile_name,
            )

        text = "Click here to open SageMaker Studio"
        target = response["AuthorizedUrl"]
        print(target)
        print(f"\u001b]8;;{target}\u001b\\{text}\u001b]8;;\u001b\\")

    def down(self, space_name=None):
        while True:
            apps = self.get_apps(
                user_profile_name=self.user_profile_name, space_name=space_name
            )
            if (
                len(
                    [
                        app
                        for app in apps
                        if app["Status"] == "Pending"
                        and app["AppType"] != "JupyterServer"
                    ]
                )
                == 0
            ):
                break
            sleep(1)
        for app in apps:
            if app["Status"] in ["InService"] and app["AppType"] != "JupyterServer":
                if space_name is None:
                    self.client.delete_app(
                        DomainId=self.domain_id,
                        UserProfileName=self.user_profile_name,
                        AppType=app["AppType"],
                        AppName=app["AppName"],
                    )
                else:
                    self.client.delete_app(
                        DomainId=self.domain_id,
                        SpaceName=space_name,
                        AppType=app["AppType"],
                        AppName=app["AppName"],
                    )

    def delete(self, space_name):
        if (
            input("This will delete all the files in the space, are you sure? (y/n) ")
            == "y"
        ):
            self.client.delete_space(SpaceName=space_name, DomainId=self.domain_id)
            uid = self.client.describe_space(
                DomainId=self.domain_id, SpaceName=space_name
            )["HomeEfsFileSystemUid"]
            self.bastion.execute_commands([f"rm -rf /mnt/efs/{int(uid)}"])
            print(f"Deleted space {space_name}")

    def status(self, user_profile_name, space_name=None, all=False):
        apps = self.get_apps(user_profile_name=user_profile_name, space_name=space_name)
        if not all:
            apps = [app for app in apps if app["Status"] in ["Pending", "InService"]]
        for app in apps:
            instance_type = (
                "default"
                if app["AppName"] == "default"
                else re.findall(r"(ml-[^-]*-[^-]*)", app["AppName"])[0]
            )
            print(
                f"  {app['AppType']}\t {instance_type}\t {app['Status']}\t {app['CreationTime']}"
            )
        if not all and len(apps) == 0:
            print("No running instances")

    def status_all(self):
        du = {
            _.split("\t")[1][len("/mnt/efs/") :]: _.split("\t")[0]
            for _ in self.bastion.execute_commands(["cat /root/du"]).split("\n")[:-1]
        }
        if "" in du:
            print(f"Total EFS {du['']}")
        for user_profile in self.client.list_user_profiles(
            DomainIdEquals=self.domain_id
        )["UserProfiles"]:
            user_profile_name = user_profile["UserProfileName"]
            uid = self.client.describe_user_profile(
                DomainId=self.domain_id, UserProfileName=user_profile_name
            )["HomeEfsFileSystemUid"]
            print(f"User: {user_profile_name} ({du.get(uid, '0K')})")
            self.status(user_profile_name=user_profile_name, space_name=None, all=True)

        for space in self.client.list_spaces(DomainIdEquals=self.domain_id)["Spaces"]:
            space_name = space["SpaceName"]
            uid = self.client.describe_space(
                DomainId=self.domain_id, SpaceName=space_name
            )["HomeEfsFileSystemUid"]
            print(f"Space: {space_name} ({du.get(uid, '0K')})")
            self.status(user_profile_name=None, space_name=space_name, all=True)

    def list_spaces(self):
        for space in self.client.list_spaces(DomainIdEquals=self.domain_id)["Spaces"]:
            print(space["SpaceName"])


def main():
    parser = argparse.ArgumentParser(
        prog="sm_studio", description="Start / stop SageMaker Studio instances"
    )
    parser.add_argument(
        "command", help="up | down | delete | status | status_all | list_spaces"
    )
    parser.add_argument(
        "--space_name",
        type=str,
        help="Stops (down) / destroys (delete) / starts (up) a new space or a presigned link to an existing space",
    )
    parser.add_argument("--domain_name", type=str, help="Defaults to datascience")
    parser.add_argument(
        "--user_profile_name",
        type=str,
        help="Defaults to role_session_name in your AWS config",
    )
    args = parser.parse_args()

    session = boto3.Session(profile_name="sagemaker")
    sts_client = session.client("sts")
    if args.user_profile_name is None:
        user_profile_name = re.findall(
            r"::.*:assumed-role/(.*)/", sts_client.get_caller_identity()["Arn"]
        )[0]
    else:
        user_profile_name = args.user_profile_name

    user_profile_name = user_profile_name.replace(".", "-")
    sagemaker_studio = SageMakerStudio(
        session=session,
        user_profile_name=user_profile_name,
        domain_name="datascience" if args.domain_name is None else args.domain_name,
    )

    if args.command == "up":
        sagemaker_studio.up(space_name=args.space_name)
    elif args.command == "down":
        sagemaker_studio.down(space_name=args.space_name)
    elif args.command == "delete":
        if args.space_name is None:
            raise ValueError("You must specify a space_name to delete")
        sagemaker_studio.delete(space_name=args.space_name)
    elif args.command == "status":
        sagemaker_studio.status(
            user_profile_name=user_profile_name, space_name=args.space_name
        )
    elif args.command == "status_all":
        sagemaker_studio.status_all()
    elif args.command == "list_spaces":
        sagemaker_studio.list_spaces()
    elif args.command == "aws":
        sagemaker_studio.aws()
    else:
        raise ValueError(
            "Command must be one of up, down, delete, status, status_all, list_spaces or aws"
        )
    return 0


if __name__ == "__main__":
    exit(main())
