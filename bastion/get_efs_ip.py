# python get_efs_ip profile domain_name az_name

import json
import os
import sys

import boto3

try:
    os.environ["AWS_PROFILE"] = sys.argv[1]
    sm_client = boto3.client("sagemaker")
    efs_client = boto3.client("efs")
    domains = sm_client.list_domains()["Domains"]
    for domain in domains:
        if domain["DomainName"] == sys.argv[2]:
            break
    assert domain["DomainName"] == sys.argv[2]
    file_system_id = sm_client.describe_domain(DomainId=domain["DomainId"])[
        "HomeEfsFileSystemId"
    ]
    mount_targets = efs_client.describe_mount_targets(FileSystemId=file_system_id)[
        "MountTargets"
    ]
    for mount_target in mount_targets:
        if mount_target["AvailabilityZoneName"] == sys.argv[3]:
            break
    assert mount_target["AvailabilityZoneName"] == sys.argv[3]
    print(json.dumps({"ip": mount_target["IpAddress"]}))
except:
    print(json.dumps({"ip": ""}))
