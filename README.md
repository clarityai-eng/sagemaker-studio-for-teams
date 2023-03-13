# SageMaker Studio for Teams

This repo contains terraform code to spin up a SageMaker Studio domain and configure user profiles. In particular, it ensures that users are authenticated with GitLab and provides tools to allow SSH into SageMaker containers (allowing you to debug remotely with PyCharm or Visual Studio Code, run Streamlit dashboards and so on) as well as to run Docker. It also includes a Lambda function to remind users of long running instances to shut them down.

## SageMaker Studio architecture

SageMaker Studio has three concepts which are important to understand: *instances*, *apps* and *sessions*. These can be seen by clicking the "stop button" logo in JupyterLab.

* An *instance* corresponds to an EC2 machine - for example, a `ml.t3.large`. The `ml` prefix means that it is a SageMaker instance (which are between 15% and 40% more expensive than their vanilla EC2 equivalents). At any one time only one instance per type can be running.

* An *app* is a container running a particular image. JupyterLab itself is a JupyterServer app running on a free lightweight instance. All the running apps that appear in the list in JupyterLab are KernelGateway apps. These are intended for running notebooks, terminals or jobs.

* A *session* can be a Kernel Session (not to be confused with KernelGateway) or a Terminal Session. A Kernel Session corresponds to a notebook running with a particular Python kernel (or environment). Terminal Sessions can either be System Terminals (which run on the JupyterServer container) or Image Terminals (which run on KernelGateway containers). The can all be run from the Launcher or File menu.

For the most part, it is almost unnoticeable that you are working across several instances. This is achieved by JupyterLab handling the remote executions and by mounting the same home directory (which is persisted on an EFS) on all instances. However, the JupyterServer container is running Amazon Linux while the KernelGateway containers are running Ubuntu with different versions of Python! The advantage is that you can develop several projects at the same time on different sized machines with a shared workspace and a one-time setup.

## Installation on local machine

Supposing you have credentials for a `<profile>` in an AWS `<account>`, you will need to create a new profile in your `~/.aws/config` file

```config
[profile sagemaker]
region=<region>
source_profile=<profile>
role_arn=arn:aws:iam::<account>:role/<your user name>
output=json
```

Then

```bash
git clone https://github.com/clarityai-eng/sagemaker-studio-for-teams.git
cd sagemaker-studio-for-teams
pip install .
```

## Running SageMaker Studio

### Starting and stopping resources

Every user is responsible for managing the resources they use. That also includes EFS disk space which has a running cost (including the trash in `~/.local/shared/Trash`!). To obtain a pre-signed URL to access SageMaker Studio type

```bash
sm_studio up
```

On clicking this link, a JupyterServer container will be created, if one does not already exist. The idea is that all notebooks and jobs are run in separate KernelGateway containers which are controlled centrally by this JupyterServer. To tear down all KernelGateway containers (apps) you can type

```bash
sm_studio down
```

If you want to shutdown the JupyterServer app, you can do this from the File menu in JupyterLab. Unless you also close the tab, it will automatically start up a new JupyterServer app.

You can see how many running containers you have with

```bash
sm_studio status
```

For a detailed report of all running containers and disk usage per user

```bash
sm_studio status_all
```

### Hidden files

To be able to open hidden system files (i.e., ones that start with a `.`) in the JupyterLab editor, you will need to perform this one-time configuration.

1) Type in a System Terminal
  
   ```bash
   conda activate studio
   jupyter notebook --generate-config
   sed -i 's/# c.ContentsManager.allow_hidden = False/c.ContentsManager.allow_hidden = True/' ~/.jupyter/jupyter_notebook_config.py
   restart-jupyter-server
   ```

2) You should now be able toggle Show Hidden Files on or off in the View menu.

## GitLab authentication

This is handled using a Lifecycle Configuration which pulls the GitLab PAT (Personal Access Token) out of a Secret in AWS. The PAT can be stored by running

```bash
sm_git_auth
```

on your local machine and providing the environmental variables `GITLAB_USER_NAME` and `GITLAB_PAT`. Your SageMaker containers will now automatically authenticate with GitLab.

## Environments

Your workspace is persisted across sessions and containers, but any systems packages you install must either be installed every time (see `.on_start` below) or be included in the image you use. Remember that the JupyterServer runs in a different container from your KernelGateway apps, but the `/home/sagemaker-user` directory in the JupyterServer container is linked to `/home/root` in the Kernel container.

### One time recommended home directory set-up

When you first run JupyterLab from SageMaker Studio, it is recommended that you open a System Terminal and copy your AWS `credentials` and `config` to the `~/.aws` directory. If you populate a `~/.env` file with your environment variables (such as database credentials) and create a `~/.envrc` file containing

```bash
#!/bin/sh
dotenv
```

then every KernelGateway shell (or image terminal) will have these set. (The first time you will need to run `direnv allow`.)

### On start-up

If you want to install packages on start-up, then add the relevant code to `~/.on_start` and make sure it is executable (i.e., `chmod +x ~/.on_start`). An example `.on_start` could be

```bash
#!/usr/bin/env bash
apt update && apt install nano -y
pip install ~/sagemaker-studio-for-teams
```

### Python environments

At [Clarity AI](https://clarity.ai/) we use `pipenv` to manage Python environments. If you prefer to use a different package manager like `poetry`, say, then it is straightforward to adapt the script in `sageamaker_studio/kernel_lifecycle_configs`.

A typical workflow when working with a new project would be to clone the repo in the Jupyter container and spin up a KernelGateway terminal (with "Open image terminal" or from a notebook) using an image with the appropriate version of Python (and any other system packages you may need) installed. Then run

```bash
cd <project dir>
pipenv install
pipenv shell
pip install ipykernel
python -m ipykernel install --name <project dir>
```

You will now be able to open a notebook in the KernelGateway container and select the corresponding JupyterLab kernel. Next time you start a KernelGateway, the `pipenv` start-up script will automatically install any JupyterLab kernels, provided they were created by `pipenv` and have the `ipykernel` package installed. You will need to refresh your browser in order to see the newly installed kernels.

### Load environment variables in notebooks

If you `pip install python-dotenv` in the relevant kernel, you will be able to automatically load your environment variables from `.env` files along the path of your current directory by running the following cell in your notebooks

```python
%load_ext dotenv
%dotenv
```

## Spaces

A new feature of AWS SageMaker Studio allows you to collaborate with others in a shared "space". One way to do this is to share a notebook from within SageMaker Studio, but this only copies the notebook to the shared space and not the Python environment. A better option is to launch a space with the command

```bash
sm_studio up --space_name <space name>
```

This will create a new space if it does not already exist and provide a pre-signed URL to start it. Collaborating on a notebook in a space is a similar experience to working on a shared Google Doc. You can see who else is connected to your space by clicking the "team" icon. You can list existing spaces with `sm_studio list_spaces` or delete an existing one with `sm_studio delete --space_name <space name>`.

## SSH

While you can access forwarded ports on the JupyterServer container with URLs of the form `https://<domain>.studio.<region>.sagemaker.aws/jupyter/default/proxy/<port>/`, you cannot reach ports on the KernelGateway containers. If you want to connect to instances with SSH, you will need to have installed on your local machine

* [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)
* [session-manager-plugin](https://docs.aws.amazon.com/systems-manager/latest/userguide/session-manager-working-with-install-plugin.html)

The connection is established via AWS Secure Systems Manager (SSM) which not only requires a private key, but appropriate AWS authentication and permissions. This is all handled for you securely by this repo.

### Connecting

Clone this repository from a SageMaker container

```bash
git clone https://github.com/clarityai-eng/sagemaker-studio-for-teams.git
```

and from a console on a KernelGateway container (with a Ubuntu/Debian image) install the package with

```bash
cd sagemaker-studio-for-teams
pip install .
```

Then run the following commands

```bash
sm_init_sm
sm_start_sm
```

noting down the instance `mi-...`.

On your local machine, you will need a private / public key pair with which to connect via SSH over SSM. If you do not already have one in `~/.ssh/id_rsa` / `~/.ssh/id_rsa.pub`, then you can create one with [`ssh-keygen`](https://www.ssh.com/academy/ssh/keygen). Then run

```bash
sm_init_local
sm_start_local mi-...
```

(Note that you will only need to run `sm_init_local` once. You can point to any public key with the `--public_key` flag, but the advantage of using `~/.ssh/id_rsa` is that the associated private key is passed by default by SSH.)

You will then be able to SSH into your KernelGateway container from your local machine by typing `ssh root@mi-...`. This works just like a normal SSH: you can SCP to / from this host, forward ports (for dashboards like Streamlit, Dask, etc) and debug remotely with Visual Studio Code and PyCharm.

### Remote debugging

Visual Studio Code requires an explicit entry in the SSH `config` file for the instance you want to connect to. If you do not already have the Remote Explorer extension installed, you can get it [here](https://marketplace.visualstudio.com/items?itemName=ms-vscode.remote-explorer). Open the Remote Explorer extension, click on + to the right of SSH. Then type the `ssh root@mi-...` and choose an appropriate SSH `config` file.

PyCharm Professional can also be used for remote debugging but needs a larger instance than `ml.t3.medium` to work.

### Agent forwarding

If you need to SSH into other machines from SageMaker (for example, you might prefer to use GitLab over SSH), rather than copy your private keys, you can connect to the SageMaker instance with

```bash
ssh -A mi-...
```

and your local machine will authenticate any further SSH connections you make to other hosts in that shell using your SSH `config` and private keys. Equivalently, you can add the line

```bash
Host mi-...
  ...
  ForwardAgent yes
```

to your SSH `config` file.

## Docker

As SageMaker applications run inside Docker containers and the `docker.sock` of the host is not exposed, it is not possible to run a Docker engine in a SageMaker container. However, it is possible to connect to a remote Docker engine. The terraform code in the `bastion` directory of this repo does exactly that.

All you need to do is run `sm_init_docker` on your KernelGateway container, restart your shell and you will be able to use Docker as if it were running on the same machine. The idea is to use the remote Docker engine to build and push your images directly from SageMaker, but this is not really a scalable way to run big jobs in Docker containers. Stopped containers and dangling or old images will be pruned periodically to prevent the remote Docker engine from running out of disk space.

## EFS

All SageMaker Studio users have a directory on an EFS. This volume is mounted on the `bastion` in `/mnt/efs` which opens up the possibility for periodic backups to S3 and monitoring of disk usage per user (by running `sm_studio status_all`).

## SageMaker Police

This creates a Lambda function that EventBridge runs periodically to monitor long standing KernelGateway instances. All confirmed users will receive an email from the `admin_email` if their `m3-...` instances have been running for more than 5 days, or any other (generally more expensive) instances have been up for more than a day.

## Terraform / terragrunt

To create the SageMaker domain, user profiles, bastion and monitoring function

```bash
terragrunt run-all apply
```

in the root directory and torn down again with

```bash
terragrunt run-all destroy
```

The current configuration also destroys the EFS volume linked to the domain, as this would otherwise continue to incur costs. Alternatively, you can change `main.tf` to

```terraform
  retention_policy {
    home_efs_file_system = "Retain"
  }
```

and, although the link to the EFS would be lost in a new domain, it would be possible to recover the data or relink it.

The configuration variables can be specified in `terragrunt.hcl` in the root directory file as follows:

```terraform
inputs = {
  profile      = "profile"
  key_filename = "/home/user/.ssh/bastion.pem"
  admin_email  = "user.name@domain.com"
  email_domain = "domain.com"
  git_provider = "gitlab.domain.com"
  root_account = "<account>"
  
  users = [
    {
      gitlab_name  = "user.name",
      gitlab_email = "user.name@domain.com"
      is_admin     = true
    },
    {
      ...
    }
  ]
}
```

You will need to have created IAM users with the same names as their `gitlab_name`.

Creating `sagemaker_police` will automatically email all the users asking them to confirm their email address, so you might want to override the `users` variable in `terraform.tfars` in the `sagemaker_police` directory while testing.

If you have not already done so, run the "quick start" for the SSM in the AWS console. In order to be able to SSH into SageMaker instances, the AWS account needs to be configured to have an "advanced activation tier". A one-time command to do achieve this is

```bash
aws ssm update-service-setting \
    --setting-id arn:aws:ssm:<region>:<account>:servicesetting/ssm/managed-instance/activation-tier \
    --setting-value advanced
```

## Troubleshooting

In general, you should always select an image with the version of Python required by your project (i.e., specified in the `Pipfile`) already installed. Nevertheless, you might still run into some weird looking problems.

* `RuntimeError: no .dist-info at ...`

  As all the containers are sharing the same home directory, your user Python can get in a bit of a mess, particularly if you are mixing different image types. Run `rm -rf /root/.local/share/virtualenv` to remove your user Python versions.

* `'EntryPoints' object has no attribute 'get'`

  This method was deprecated in version `5.0.0` of `importlib-metadata`. Run `pip install importlib-metadata==4.13.0`.

* "I have authenticated with `sm_git_auth` but it keeps on asking me for my GitLab credentials..." or
* "I get AWS errors when I run `sm_...` commands on SageMaker"

  Make sure that you have no `default` credentials in your `~/.aws/credentials` file: these will override the SageMaker execution role policies.

## Appendix: running Jupyter notebooks without a KernelGateway instance

Sometimes it is handy to be able to run a lightweight Jupyter notebook without spinning up a KernelGateway instance. A way to do this is as follows.

1) Open a System Terminal, create a conda environment and install Jupyter

   ```bash
   conda create --prefix /home/sagemaker-user/.local/share/conda/test
   conda activate /home/sagemaker-user/.local/share/conda/test
   conda install jupyter
   # install any other packages you need...
   ```

   This environment will persist across sessions, but will be relatively slow to install on EFS. If you want to do something quick without persistence then

   ```bash
   conda create --name test
   conda activate test
   conda install jupyter
   # install any other packages you need...
   ```

2) Run the Jupyter notebook server

   ```bash
   jupyter notebook --NotebookApp.base_url='/jupyter/default/proxy/absolute/8889' --NotebookApp.allow_remote_access=True
   ```

3) Open the Jupyter notebook server in a browser

   Navigate to `https://<domain>.studio.<region>.sagemaker.aws/jupyter/default/proxy/absolute/8889/?token=<token>` where `<token>` is the token output in the previous step.
