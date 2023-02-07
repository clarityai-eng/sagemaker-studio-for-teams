#!/usr/bin/env bash
AWS_PROFILE=`terraform output -json | jq -r '.profile.value'` \
ssh -i `terraform output -json | jq -r '.key_filename.value'` \
ubuntu@`terraform output -json | jq -r '.target.value'` \
-o StrictHostKeyChecking=accept-new \
-o ProxyCommand="aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p"
