import argparse
import os


def main():
    if os.path.exists("/opt/ml/metadata/resource-metadata.json"):
        print("This should only be run on your local machine")
        exit(1)

    parser = argparse.ArgumentParser(
        prog="sm_init_local",
        description="Configure SSH to connect to EC2 / SageMaker instances",
    )
    parser.add_argument(
        "--ssh_config",
        type=str,
        help="SSH config file (defaults to $HOME/.ssh/config or %HOMEDRIVE%\%HOMEPATH%\.ssh\config)",
    )
    args = parser.parse_args()

    if args.ssh_config is None:
        args.ssh_config = (
            f"{os.environ['HOME']}/.ssh/config"
            if "HOME" in os.environ
            else f"{os.environ['HOMEDRIVE']}{os.environ['HOMEPATH']}\.ssh\config"
        )

    start_string = "# >>> AWS SSM config >>>"
    end_string = "# <<< AWS SSM config <<<"

    if os.path.exists(args.ssh_config):
        with open(args.ssh_config, "rt") as file:
            ssh_config = file.read()
        start = ssh_config.find(start_string)
        if start > -1:
            end = ssh_config.find(end_string)
            ssh_config = ssh_config[:start] + ssh_config[end + len(end_string) + 1 :]
    else:
        ssh_config = ""

    if ssh_config != "" and ssh_config[-1] != "\n":
        ssh_config += "\n"
    ssh_config += f"""{start_string}
Host i-* mi-*
    StrictHostKeyChecking accept-new
    ProxyCommand aws ssm start-session --target %h --document-name AWS-StartSSHSession --parameters \"portNumber=%p\" --profile=sagemaker
{end_string}
"""

    with open(args.ssh_config, "wt") as file:
        file.write(ssh_config)
    return 0


if __name__ == "__main__":
    exit(main())
