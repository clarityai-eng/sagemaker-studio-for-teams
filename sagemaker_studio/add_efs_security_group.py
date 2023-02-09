# python add_efs_security_group.py profile region mount_target mount_target_id

import sys

import boto3

session = boto3.Session(profile_name=sys.argv[1], region_name=sys.argv[2])
client = session.client("efs")
mount_targets = client.describe_mount_targets(FileSystemId=sys.argv[3])["MountTargets"]
for mount_target in mount_targets:
    security_groups = client.describe_mount_target_security_groups(
        MountTargetId=mount_target["MountTargetId"]
    )["SecurityGroups"]
    client.modify_mount_target_security_groups(
        MountTargetId=mount_target["MountTargetId"],
        SecurityGroups=security_groups + [sys.argv[4]],
    )
