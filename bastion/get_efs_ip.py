# python get_efs_ip.py profile region domain_name az_name

import json
import sys

import boto3

try:
    session = boto3.Session(profile_name=sys.argv[1], region_name=sys.argv[2])
    sm_client = session.client("sagemaker")
    efs_client = session.client("efs")
    domains = sm_client.list_domains()["Domains"]
    for domain in domains:
        if domain["DomainName"] == sys.argv[3]:
            break
    assert domain["DomainName"] == sys.argv[4]
    file_system_id = sm_client.describe_domain(DomainId=domain["DomainId"])[
        "HomeEfsFileSystemId"
    ]
    mount_targets = efs_client.describe_mount_targets(FileSystemId=file_system_id)[
        "MountTargets"
    ]
    for mount_target in mount_targets:
        if mount_target["AvailabilityZoneName"] == sys.argv[4]:
            break
    assert mount_target["AvailabilityZoneName"] == sys.argv[4]
    print(json.dumps({"ip": mount_target["IpAddress"]}))
except:
    print(json.dumps({"ip": ""}))
