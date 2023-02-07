import os

import boto3


class GitlabSecrets:
    def __init__(self, session):
        self.client = session.client("secretsmanager")

    def set_gitlab_pat(self, gitlab_user_name, gitlab_pat):
        self.client.put_secret_value(
            SecretId=f"gitlab-{gitlab_user_name}",
            SecretString='{"GITLAB_PAT":"' + gitlab_pat + '"}',
        )


def main():
    try:
        gitlab_pat = os.environ["GITLAB_PAT"]
        gitlab_user_name = os.environ["GITLAB_USER_NAME"]
    except KeyError:
        raise ValueError(
            "GITLAB_PAT and GITLAB_USER_NAME must be set in your environment"
        )

    gitlab_secrets = GitlabSecrets(session=boto3.Session(profile_name="sagemaker"))
    gitlab_secrets.set_gitlab_pat(gitlab_user_name, gitlab_pat)


if __name__ == "__main__":
    exit(main())
