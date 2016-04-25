# Infrastructure provisioning for dstl-lighthouse

## Description

Code for provision and deployment for various components of the dstl-lighthouse project

## Table of Contents

- [Requirements](#requirements)
- [Getting started](#getting-started)
  - [Ensure SSH keys are set up for GitHub](#ensure-ssh-keys-are-set-up-for-github)
  - [Clone the `lighthouse-builder` repo to your machine](#clone-the-lighthouse-builder-repo-to-your-machine)
  - [Pull the `lighthouse-secrets` repo](#pull-the-lighthouse-secrets-repo)
- [Provisioning](#provisioning)
  - [Using Terraform to provision](#using-terraform-to-provision)
    - [Create a keypair on AWS](#create-a-keypair-on-aws)
    - [Install Terraform](#install-terraform)
    - [Provision servers in AWS](#provision-servers-in-aws)
    - [How to modify server details](#how-to-modify-server-details)
- [Deploying](#deploying)
  - [Choose an Environment](#choose-an-environment)
    - [Criteria for choosing](#criteria-for-choosing)
      - [Internet access or air-gapped?](#internet-access-or-air-gapped)
      - [Preconfigured or Site Specific?](#preconfigured-or-site-specific)
    - [Preview](#preview)
    - [Copper](#copper)
    - [Bronze](#bronze)
    - [Silver](#silver)
  - [Configure settings](#configure-settings)
    - [Configure Preview](#configure-preview)
    - [Configure Copper](#configure-copper)
    - [Configure Bronze](#configure-bronze)
    - [Configure Silver](#configure-silver)
  - [Rsync dependencies](#rsync-dependencies)
    - [Dependencies for Internet bootstrap](#dependencies-for-internet-bootstrap)
    - [Dependencies for Airgapped deploy](#dependencies-for-airgapped-bootstrap)
  - [Bootstrap Jenkins](#bootstrap-jenkins)
    - [Change the IP of the lighthouse host in site_specific](#change-the-ip-of-the-lighthouse-host-in-site_specific)
    - [Run the bootstrap command](#run-the-bootstrap-command)
  - [Update Jenkins](#update-jenkins)
  - [Restart Jenkins](#restart-jenkins)
- [Package dependencies](#package-dependencies)

- [Configuring your servers with `servers.yml`](#configuring-your-servers-with-serversyml)
- [How is the Lighthouse server typically configured?](#how-is-the-lighthouse-server-typically-configured)
  - [Development](#development)
  - [Production](#production)

## Requirements

* Vagrant
* VirtualBox (or VMware if you prefer)
* Terraform
* A keypair set up with AWS
* This repository and submodules pulled down

If you have the above, you can skip past "Getting started" to
[Provision server in AWS][provaws].

## Getting started

### Ensure SSH keys are set up for GitHub

In order to make changes to this repo you need to create an ssh keypair and add 
it to your GitHub profile. The easiest way to do this is by following
[this handy GitHub tutorial][ghssh].

### Clone the `lighthouse-builder` repo to your machine

```bash
git clone git@github.com:dstl/lighthouse-builder.git
cd lighthouse-builder
```

### Pull the `lighthouse-secrets` repo

The `lighthouse-secrets` repo is a private repo you should have access to.
It's a git submodule of this repo and contains files needed for lighthouse to
operate properly. If it has moved or you are using a different one, you can
change the `.gitmodules` file in this repo to point the new place. You need to
pull down the repo into the `secrets` directory, which can be done like so:

```bash
git submodule update --init
```

## Provisioning

### Using Terraform to provision

**Why would I use Terraform?** Terraform is used for provisioning cloud servers
on Amazon Web Services (AWS). It may at first seem daunting, but it can be a lot
easier and more productive than doing it through the AWS UI. All the
configuration for Lighthouse's AWS server is done in the `terraform` directory
of this repository.

#### Create a keypair on AWS

Follow [this helpful guide provided by Amazon][amzkeypair] in order to
authenticate with AWS in the future, which is required for using Terraform.

#### Install Terraform

[Terraform][trfm] makes provisioning of cloud servers easy for AWS.

On a mac:

```bash
brew install terraform
```

For other platforms, you may be able to use the system package
manager, but it may be easier to download Terraform from the official
website on the [Terraform download page][trfmdl]. For more info on installing
and configuring terraform see [the guide to installing Terraform][trfminst]

#### Provision servers in AWS

All the configuration files are located in `terraform`, so get your shell into
there first:

```bash
cd terraform
```

Then type 

```bash
terraform apply
```

Terraform will create the necessary resources in AWS. Check the AWS console and
you should see 2 servers provisioned.

#### How to modify server details

The `terraform.tfvars` file contains the variables used by Terraform config to
change which network locations can access the Terraformed servers.

In `preview.tf`, each of the IP addresses listed in there are put into the
`ingress` block inside the `"aws_security_group"` resource.

This security group is used in `redhat_preview.tf`, in order to indicate which
IP addresses are able to access the Lighthouse server and the Lighthouse CI
server. `redhat_preview.tf` is also where these two servers are configured in
general, and is a good starting point for configuring new environments.

## Deploying

Deployments in Lighthouse are performed by Jenkins using Ansible.

It is important to understand the differences between the environments so you
can choose which one to deploy using.

**Steps to deploy**

- [Choose an environment](#choose-an-environment)
- [Configure settings](#configure-settings)
- [Rsync dependencies](#rsync-dependencies)
- [Bootstrap Jenkins](#bootstrap-jenkins)
- [Update Jenkins](#update-jenkins)
- [Restart Jenkins](#restart-jenkins)
- [Trigger Lighthouse Deploy](#trigger-lighthouse-deploy)

### Choose an Environment

|               | Has Internet Access | No Internet Access |
|---------------|---------------------|--------------------|
| Preconfigured | [Preview](#preview) | [Copper](#copper)  |
| Site Specific | [Bronze](#bronze)   | [Silver](#silver)  |

#### Criteria for choosing

##### Internet access or air-gapped?

Lighthouse is designed to be deployed into multiple different networks, some
airgapped and some with internet access. Whether you have internet access in
your network decides which [environment you should use](#environment).

##### Preconfigured or Site Specific?

When deploying we have provided settings to "out-of-the-box" deploy to either
a Internet or Airgapped network. Should you need to deploy to another network
you can use [Site Specific settings instead](#site-specific-deploy). Whether you
need to configure these settings in your network decides which
[environment you should use](#environment).


#### Preview

- **Has** internet access.
  Deploys using the internet and pulls all it's packages from public sources.
- **Preconfigured** settings.
  Requires only minimal [configuration before use](#configure-preview).

Preview has been preconfigured to deploy in AWS. It uses the layout created by
Terraform as defined in [terraform/preview.tf][previewtf]. You only need to
[configure a few settings](#configure-preview) before you can use it.

#### Copper

- **No** internet access.
  Requires all [dependencies to be packaged first](#package-dependencies).
- **Preconfigured** settings.
  Requires only minimal [configuration before use](#configure-copper).

Copper has been configured to deploy to AWS. It uses the layout created by
terraform as defined in [terraform/copper.tf][coppertf].

Copper requires an Internet enabled environment to have it's
[dependencies packaged](#package-dependencies) and these dependencies rsynced to
it before it can [bootstrap without internet access](#airgapped-bootstrap).

#### Bronze

- **Has** internet access.
  Deploys using the internet and pulls all it's packages from public sources.
- **Site specific** settings.
  Requires [configuring before use](#configure-bronze).

Bronze is more flexible version of Preview. As such it needs some 
[configuration before use](#configure-bronze).

#### Silver

- **No** internet access.
  Requires all [dependencies to be packaged first](#package-dependencies).
- **Site specific** settings.
  Requires [configuring before use](#configure-silver).

Silver is more flexible version of Copper. As such it needs some 
[configuration before use](#configure-silver).

Silver requires an Internet enabled environment to have it's
[dependencies packaged](#package-dependencies) and these dependencies rsynced to
it before it can [bootstrap without internet access](#airgapped-bootstrap).

### Configure settings

Settings need to be configured before [bootstrapping jenkins](#bootstrap-jenkins).
What needs configured depends greatly on which environment you've chosen to run.

#### Configure Preview

- **In `secrets/preview.inventory` set the internal IP of lighthouse**

    Use the Public IP of the lighthouse box created by terraform.

        [lighthouse-app-server]
        <public lighthouse ip> ansible_ssh_private_key_file=../secrets/preview.deploy.pem ansible_ssh_user=ec2-user

- **In `secrets/preview.site_specific.yml` set the lighthouse ip**

    Use the Public IP of the lighthouse box created by terraform.

        lighthouse_ip: '<public lighthouse ip>'

- **Commit those changes to master**
  
    Update jobs use master to update from so you need to commit these changes
    otherwise they will be overwritten when you update jenkins.

#### Configure Copper

- **In `secrets/copper.inventory` set the internal IP of lighthouse**

    Use the Public IP of the lighthouse box created by terraform.

        [lighthouse-app-server]
        <public lighthouse ip> ansible_ssh_private_key_file=../secrets/preview.deploy.pem ansible_ssh_user=ec2-user

- **In `secrets/copper.site_specific.yml` set the lighthouse ip**

    Use the Public IP of the lighthouse box created by terraform.

        lighthouse_ip: '<public lighthouse ip>'

- **Commit those changes to master**
  
    Update jobs use master to update from so you need to commit these changes
    otherwise they will be overwritten when you update jenkins.

#### Configure Bronze

Bronze requires a number of files to be created in `/opt/secrets` on the VM you
intend to bootstrap.

- **If using RHEL Make sure your VM is registered**

    Our deployments require unrestricted yum access. So ensuring your VM is
    fully registered with RHEL guarantees we can install things from yum.

- **Place an ssh private key that has rights to lighthouse**

    We put ours in `/opt/secrets/ssh.pem`. Use that path anywhere you are asked
    for `<ssh key path>` in this section.

- **Create `/opt/secrets/site_specific.yml`**

        lighthouse_hostname: '<lighthouse url>'
        lighthouse_host: '<lighthouse url>'
        jenkins_url: 'http://<jenkins url>:8080/'
        lighthouse_ci_hostname: '<jenkins url>'
        jenkins_internal_url: 'http://0.0.0.0:8080/'
        github_token: '<github access token>'
        lighthouse_ip: '<lighthouse public ip>'
        lighthouse_secret_key: '<secret key>'
        lighthouse_ssh_key_path: '<ssh key path>'
        lighthouse_ssh_user: '<ssh user>'

    where:

    `<lighthouse url>`: The url you want users to access lighthouse over. Needs
    to be defined in DNS.

    `<jenkins url>`: The url you want to use to access jenkins. Needs to be
    defined in DNS.

    `<lighthouse ip>`: The IP of lighthouse that jenkins can use to ssh to.

    `<github token>`: A github personal access token which has access to
    lighthouse and lighthouse-builder.

    `<secret key>`: Some long random string used for crypto.
    Use `head -30 /dev/urandom | sha256sum` to generate a nice long random
    string.

    `<ssh key path>`: Path to the ssh private key that has `ssh` rights to the
    lighthouse VM, e.g. `/opt/secrets/ssh.pem`

    `<ssh user>`: The user that the `<ssh key path>` has to ssh in to lighthouse
    as. In preview this is `ec2-user`.

- **Create `/opt/secrets/bronze.inventory`**

        [lighthouse-app-server]
        <lighthouse ip> ansible_ssh_private_key_file=<ssh key path> ansible_ssh_user=<ssh user>

        [bronze:children]
        lighthouse-app-server

    where:

    `<lighthouse ip>`: The IP of lighthouse that jenkins can use to ssh to.

    `<ssh key path>`: Path to the ssh private key that has `ssh` rights to the
    lighthouse VM, e.g. `/opt/secrets/ssh.pem`

    `<ssh user>`: The user that the `<ssh key path>` has to ssh in to lighthouse
    as. In preview this is `ec2-user`.

#### Configure Silver

Silver requires a number of files to be created in `/opt/secrets` on the VM you
intend to bootstrap.

- **If using RHEL Make sure your VM is registered**

    Our deployments require unrestricted yum access. So ensuring your VM is
    fully registered with RHEL guarantees we can install things from yum.

- **Place an ssh private key that has rights to lighthouse**

    We put ours in `/opt/secrets/ssh.pem`. Use that path anywhere you are asked
    for `<ssh key path>` in this section.

- **Create `/opt/secrets/site_specific.yml`**

        lighthouse_hostname: '<lighthouse url>'
        lighthouse_host: '<lighthouse url>'
        jenkins_url: 'http://<jenkins url>:8080/'
        lighthouse_ci_hostname: '<jenkins url>'
        jenkins_internal_url: 'http://0.0.0.0:8080/'
        github_token: '<github access token>'
        lighthouse_ip: '<lighthouse public ip>'
        lighthouse_secret_key: '<secret key>'
        lighthouse_ssh_key_path: '<ssh key path>'
        lighthouse_ssh_user: '<ssh user>'

    where:

    `<lighthouse url>`: The url you want users to access lighthouse over. Needs
    to be defined in DNS.

    `<jenkins url>`: The url you want to use to access jenkins. Needs to be
    defined in DNS.

    `<lighthouse ip>`: The IP of lighthouse that jenkins can use to ssh to.

    `<github token>`: A github personal access token which has access to
    lighthouse and lighthouse-builder.

    `<secret key>`: Some long random string used for crypto.
    Use `head -30 /dev/urandom | sha256sum` to generate a nice long random
    string.

    `<ssh key path>`: Path to the ssh private key that has `ssh` rights to the
    lighthouse VM, e.g. `/opt/secrets/ssh.pem`

    `<ssh user>`: The user that the `<ssh key path>` has to ssh in to lighthouse
    as. In preview this is `ec2-user`.

- **Create `/opt/secrets/silver.inventory`**

        [lighthouse-app-server]
        <lighthouse ip> ansible_ssh_private_key_file=<ssh key path> ansible_ssh_user=<ssh user>

        [silver:children]
        lighthouse-app-server

    where:

    `<lighthouse ip>`: The IP of lighthouse that jenkins can use to ssh to.

    `<ssh key path>`: Path to the ssh private key that has `ssh` rights to the
    lighthouse VM, e.g. `/opt/secrets/ssh.pem`

    `<ssh user>`: The user that the `<ssh key path>` has to ssh in to lighthouse
    as. In preview this is `ec2-user`.

### Rsync dependencies

#### Dependencies for Internet deploy

Preview and Bronze both pull dependencies from the public internet. As such the
only thing they need to start the bootstrap is the [lighthouse-builder] repo.

- **Clone the `lighthouse-builder` repo to your machine**

        ~ > git clone git@github.com:dstl/lighthouse-builder.git

- **Ensure `lighthouse-secrets` repo is checked out**

        ~ > cd lighthouse-builder
        ~/lighthouse-builder > git submodule update --init

- **Rsync the lighthouse-builder repo to the jenkins VM**

        ~ > rsync -Pav -e 'ssh -i <ssh key path>' ~/lighthouse-builder/ /tmp/boostrap/

    where:

    `<ssh key path>` is the path to an ssh private key that can ssh in to the
    jenkins VM. For preview we use `secrets/preview.deploy.pem`.

    we assume you have checked out lighthouse-builder to `~/lighthouse-builder`.

#### Dependencies for Airgapped deploy

Copper and Silver both require full dependencies to be packaged on an existing
Internet enabled network.

- **Perform a full deploy to a Preview or Bronze environment**

    This is a full deploy, so it may take a while.

- **Package the dependencies on your Preview or Bronze**

    Follow the [guide to package dependencies](#package-dependencies).

- **Rsync dependencies from the Preview or Bronze jenkins VM**

        ~ > rsync -Pav -e 'ssh -i <ssh key path>' \
                  <ssh user>@<jenkins ip>:/opt/dist/ \
                  /tmp/dist/

    where:

    `<ssh key path>` is the path to an ssh private key that can ssh in to the
    jenkins VM. For preview we use `secrets/preview.deploy.pem`.

    `<ssh user>` is the user that `<ssh key path>` has to login as on jenkins.

    `<jenkins ip>` is the public IP of the jenkins VM.

- **Create the folder `/opt/dist` in the Copper or Silver jenkins VM**

        ~ > ssh -i <ssh key path>' <ssh user>@<target ip>
        <ssh user>@<target ip> > sudo mkdir /opt/dist/
        <ssh user>@<target ip> > sudo chmod <ssh user>:<ssh user> /opt/dist/
        <ssh user>@<target ip> > exit
        ~ >

    where:

    `<ssh key path>` is the path to an ssh private key that can ssh in to the
    jenkins VM. For preview we use `secrets/preview.deploy.pem`.

    `<ssh user>` is the user that `<ssh key path>` has to login as on jenkins.

    `<target ip>` is the public IP of the Copper or Silver jenkins VM.

- **Rsync dependencies to the Copper or Silver jenkins VM**

        ~ > rsync -Pav -e 'ssh -i <ssh key path>' \
                  <ssh user>@<jenkins ip>:/opt/dist/ \
                  /tmp/dist/

    where:

    `<ssh key path>` is the path to an ssh private key that can ssh in to the
    jenkins VM. For preview we use `secrets/preview.deploy.pem`.

    `<ssh user>` is the user that `<ssh key path>` has to login as on jenkins.

    `<jenkins ip>` is the public IP of the jenkins VM.

### Bootstrap Jenkins

Once the VMs are created in AWS you will need to bootstrap Jenkins before we
can get our CI pipeline running. By this point it is _vital_ that you have
pulled down the `lighthouse-secrets` repo.

Get the public IP of the Jenkins server from the AWS console. This IP will be
referred to as `jenkins-public-ip` in the following commands.

First step is to get this repo on to the Jenkins server from AWS. Rsync is the
suggested method. From the root of this repo, run the following.

```bash
rsync --recursive \
    -e 'ssh -i secrets/preview.deploy.pem' \
    . \
    centos@<jenkins-public-ip>:/tmp/bootstrap \
    --exclude-from "rsync_exclude.txt"
```

#### Change the IP of the lighthouse host in site_specific

Edit the relevant site_specific.yml file. In this case we're hacking the
changes into the `preview.site_specific.yml` file. We should have a separate set
of files for a new AWS instance.

```bash
cd /tmp/bootstrap
vi preview.site-specific.yml
```

* Copy the IP of the lighthouse app box from the aws console and set the `lighthouse_host` parameter.

#### Run the bootstrap command

```bash
ssh -i secrets/preview.deploy.pem centos@<jenkins-public-ip>
# You should now be in the Jenkins VM through SSH
(centos@ci) > cd /tmp/bootstrap/ansible
(centos@ci) > ./bootstrap.sh --preview
```

The bootstrap takes a few minutes. Then jenkins should be available at
[ci.lighthouse.pw].

### Update Jenkins

It's _vitally_ important to update jenkins through the internal update job
before trying to run any other jobs.
Run the `Update Jenkins` job from the dashboard.

### Restart Jenkins

Go to hit `http://<jenkins-public-ip>:8080/restart` to restart Jenkins. If and
when this doesn't work, try `ssh`ing onto the server (as described in "Run the
bootstrap command") and run:

```bash
(centos@ci) > sudo service jenkins restart
```

## Package dependencies

## Configuring your servers with `servers.yml`

The `servers.yml` file can be found in the `ansible` directory. It is
responsible for describing how Vagrant and Ansible should be provisioning and
setting up a new VM locally. It looks something like this:

```yaml

---
- name: lighthouse-dev
  box: box-cutter/centos72
  host: lighthouse.dev
  ip: 10.1.1.10
  ram: 1024
  playbook: playbook.yml
  mounts:
    - envvar: DSTL_LIGHTHOUSE
      target: /opt/lighthouse
  groups:
    - vagrant
    - development
```

Most of those yaml items are self-explanatory, but the important part is the
`groups` key. This contains a list of Ansible groups which this VM will fall
under, and thus determines which "plays" to run from the `playbook.yml` file
specified above.

## How does logging work?

Logging is done via uWSGI, and is configured in the Jinja2 template
`ansible/roles/dstl.lighthouse/templates/wsgi.ini.j2`. You should see this line:

```
daemonize={{ uwsgi_log_dir }}/lighthouse.log
```

When Ansible sets up uWSGI (using
`ansible/roles/digi2al.python/tasks/uwsgi.yml`), it'll use the `uwsgi_log_dir`
variable to point the logs at a specified location. The default, which is
configured in `ansible/roles/digi2al.python/defaults/main.yml`, is
`'/var/log/uwsgi'`

If you need to change the log location, your best bet is to do it on an
environmental level by changing the appropriate environment `.site_specific.yml`
file in the secrets folder.

## How is the Lighthouse server typically configured?

### Development

The Lighthouse application is written using Python+Django, and is executed
manually by using Django's usual management tools, `python manage.py runserver
0.0.0.0:3000`. Outside of the VM, that means the app will be available on the
VM's IP address (normally `10.1.1.10`) at port `3000`.

**Where is this configured/where does it happen?** In the `ansible` directory,
find `roles/digi2al.python/tasks`. Three tasks in there, `main.yml`, `nginx.yml`
and `uswsgi.yml` specify how the app is to be run.

### Production

The Lighthouse application is written using Python+Django, and is loaded using
an application server container called uWSGI. uWSGI loads the Django app
and serves it locally on an HTTP port (normally 8080).

**Where is this configured/where does it happen?** In the `ansible` directory,
find `roles/dstl.lighthouse/tasks` and `roles/digi2al.python/tasks`.

The tasks listed in `digi2al.python/tasks` will install `nginx` and `uWSGI`.

In `dstl.lighthouse/tasks`, users are set up, and config files are generated for
`nginx` and `uWSGI` from templates in the `digital.lighthouse/templates` folder.
The task which actually runs `nginx` and `uWSGI` using these new settings is
`service.yml`.

[ghssh]:https://help.github.com/articles/generating-an-ssh-key/
[provaws]:#provision-server-in-aws
[trfm]:https://www.terraform.io
[trfmdl]:https://www.terraform.io/downloads.html
[trfminst]:https://www.terraform.io/intro/getting-started/install.html
[amzkeypair]:http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair
[previewtf]: https://github.com/dstl/lighthouse-builder/blob/master/terraform/preview.tf
[coppertf]: https://github.com/dstl/lighthouse-builder/blob/master/terraform/copper.tf
[lighthouse-builder]: https://github.com/dstl/lighthouse-builder

