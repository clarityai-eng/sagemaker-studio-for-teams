import os
import sys

import boto3

os.environ["AWS_PROFILE"] = sys.argv[1]
client = boto3.client("efs")
mount_targets = client.describe_mount_targets(FileSystemId=sys.argv[2])["MountTargets"]
for mount_target in mount_targets:
    security_groups = client.describe_mount_target_security_groups(
        MountTargetId=mount_target["MountTargetId"]
    )["SecurityGroups"]
    client.modify_mount_target_security_groups(
        MountTargetId=mount_target["MountTargetId"],
        SecurityGroups=security_groups + [sys.argv[3]],
    )
