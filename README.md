![Install Zabbix 7 + TimescaleDB monitoring server in docker](https://r4ven.me/wp-content/uploads/2024/09/zabbix.resized-1038x576.png)

# Install Zabbix 7 + TimescaleDB monitoring server in docker

### Greetings!

In this tutorial, we will deploy the popular **Zabbix** monitoring system using **TimescaleDB , a** **PostgreSQL** database plugin that allows you to effectively work with “time series”. We will wrap all this goodness inside docker containers 🐳. It will be interesting 😉.

> Please note that all actions described in this guide are done at your own risk and responsibility. My blog is just a platform where I talk about my experience and share my opinion on some things and phenomena. Thank you for understanding.
> 
> Ivan Cherniy

- [Install Zabbix 7 + TimescaleDB monitoring server in docker](#install-zabbix-7--timescaledb-monitoring-server-in-docker)
    - [Greetings!](#greetings)
  - [Introduction](#introduction)
  - [Preparation](#preparation)
    - [Installing the necessary utilities](#installing-the-necessary-utilities)
    - [Downloading project files](#downloading-project-files)
    - [Creating a zabbix service user](#creating-a-zabbix-service-user)
    - [Create a postgres service user](#create-a-postgres-service-user)
  - [Creating a Password for a Postgres Database](#creating-a-password-for-a-postgres-database)
  - [Running Zabbix stack with docker compose](#running-zabbix-stack-with-docker-compose)
    - [Start the Postgres server](#start-the-postgres-server)
    - [Starting Zabbix Server](#starting-zabbix-server)
    - [Creating a Schema for TimescaleDB](#creating-a-schema-for-timescaledb)
    - [Starting the whole stack TimesacleDB + Zabbix server + Zabbix web + Zabbix agent](#starting-the-whole-stack-timesacledb--zabbix-server--zabbix-web--zabbix-agent)
  - [Access to Zabbix web interface](#access-to-zabbix-web-interface)
  - [Optional](#optional)
    - [Minimal initial setup of Zabbix server](#minimal-initial-setup-of-zabbix-server)
    - [Setting up Zabbix stack autostart with systemd](#setting-up-zabbix-stack-autostart-with-systemd)
    - [Installing and running Zabbix agent in docker on a remote host](#installing-and-running-zabbix-agent-in-docker-on-a-remote-host)
    - [Setting up Zabbix notifications in Telegram with a schedule](#setting-up-zabbix-notifications-in-telegram-with-a-schedule)
  - [Conclusion](#conclusion)
  - [Materials used](#materials-used)


## Introduction

**Zabbix** is ​​an open platform for monitoring networks and servers. It uses relational DBMS for data storage, such as PostgreSQL, MySQL, MariaDB, Oracle, SQLite, etc.

**A time series in databases** is a set of data ordered by time, where values ​​are recorded at equal or unequal time intervals.

**Time series databases** are specialized databases designed for efficient storage, management, and analysis of time series. These are often **no sql** databases.

**TimescaleDB (TSDB)** is an extension for PostgreSQL that optimizes work with time series in this DBMS, while maintaining all the power and flexibility of classic SQL-like databases. Since a certain time, Zabbix has learned to work with this DBMS.

Quote from the official Zabbix documentation:

> Zabbix supports TimescaleDB, a PostgreSQL-based database solution of automatically partitioning data into time-based chunks to support faster performance at scale.
> 
> Zabbix.com

Please also pay attention to the warning from the official Zabbix documentation:

> Warning: Currently, TimescaleDB is not supported by Zabbix proxy.
> 
> Zabbix.com 09.2024

I'm sure this will be fixed in the future. But for now, enough chatter, let's get down to business🤵‍♂️.

## Preparation

We will deploy Zabbix in the **Debian 12 💿** [distribution](https://r4ven.me/it-razdel/slovarik/distributiv-linux/) environment with **the Docker engine** 🐳 installed. If you don’t have a ready-made Linux server yet, I recommend my previous articles:

- [Installing Debian 12 Server in VirtualBox](https://r4ven.me/it-razdel/instrukcii/ustanovka-servera-debian-12-v-virtualbox/)
- [Initial setup of Linux server using Debian as an example](https://r4ven.me/it-razdel/instrukcii/nachalnaya-nastrojka-linux-servera-na-primere-debian/)
- [Installing Docker engine on a Linux server running Debian](https://r4ven.me/it-razdel/instrukcii/ustanovka-docker-engine-na-linux-server-pod-upravleniem-debian/)

Also, for further work we will need a user with **root** rights .

> Hey, this article is part of a series about building your own infrastructure. Previous articles:
> 
> - [Install OpenConnect SSL VPN server (ocserv) in docker for internal projects](https://r4ven.me/it-razdel/instrukcii/podnimaem-openconnect-ssl-vpn-server-ocserv-v-docker-dlya-vnutrennih-proektov/)
> - [Install your own DNS server Unbound and ad blocker Pihole in docker](https://r4ven.me/it-razdel/instrukcii/podnimaem-svoj-dns-server-unbound-i-blokirovshhik-reklamy-pihole-v-docker/)
> 
> And here is the diagram, taking into account the addition of a monitoring server:
> 
> [![](https://r4ven.me/wp-content/uploads/2024/09/openconnect_zabbix.jpg)](https://r4ven.me/wp-content/uploads/2024/09/openconnect_zabbix.jpg)

### Installing the necessary utilities

Today we will need utilities for interaction with the web. Open the terminal and install the version control system `git`and the utility `curl`:

```bash
sudo apt update && sudo apt install -y git curl
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-29.png)](https://r4ven.me/wp-content/uploads/2024/09/image-29.png)

### Downloading project files

All project files are in my [repository](https://r4ven.me/it-razdel/slovarik/repozitorij-programmnogo-obespecheniya/) on [GitHub](https://github.com/r4ven-me/zabbix) . Clone it using the previously installed utility `git`along the path `/opt/zabbix`:

```bash
sudo git clone https://github.com/r4ven-me/zabbix /opt/zabbix
```

<details>

<summary>Click here to view the description of the project files</summary>

[![](https://r4ven.me/wp-content/uploads/2024/09/image-108.png)](https://r4ven.me/wp-content/uploads/2024/09/image-108.png)

- `docker-compose.yml`– file describing services launched in docker containers:
    - **The NETWORK** section defines two docker virtual networks:
        - `zbx_net_backend`– an isolated network for interaction between containers `postgres-server,` `zabbix-server`, `zabbix-web`and `zabbix-agent`;
        - `zbx_net_frontend`– network with access to containers from the host OS: for containers `zabbix-server`and `zabbix-web`.
    - **The SERVICES** section defines the parameters of the services/containers being launched:
        - `postgres-server`– TimescaleDB DBMS service;
        - `zabbix-server`– Zabbix server service;
        - `zabbix-web`– web interface service for Zabbix server (under the hood **nginx** + **php-fpm** );
        - `zabbix-agent`– Zabbix agent service for collecting metrics from the Zabbix server itself.
    - **The SECRETS** section defines files containing sensitive information that are dropped into containers `postgres-server`, `zabbix-server`and `zabbix-web`:
        - `POSTGRES_USER`(file `./env/.POSTGRES_USER`) – user name for the Zabbix database in the TimescaleDB DBMS;
        - `POSTGRES_PASSWORD`(file `./env/.POSTGRES_PASSWORD`) – respectively, the user password.
- env – a directory with files containing environment variables, the values ​​of which are passed inside the container when it is launched:
    - `.env_db`– parameters for `postgres-server`;
    - `.env_srv`– parameters for `zabbix-server`;
    - `.env_web`– parameters for `zabbix-web`;
    - `.env_agent`– parameters for local `zabbix-agent`;
    - `.POSTGRES_PASSWORD`– user password in the zabbix database;
    - `.POSTGRES_USER`– user name in the zabbix database.
- `src`– directory with source files for building a custom container `zabbix-server`with extended functionality:
    - `alertscripts`– directory with files for sending notifications to Telegram:
    - `docker-entrypoint.sh`– script for preparing the environment inside the container (not changed);
    - `Dockerfile`– customized image build description file;
    - `externalscripts`– a directory with a script for monitoring the delegated domain.

</details>

[![](https://r4ven.me/wp-content/uploads/2024/09/image-30.png)](https://r4ven.me/wp-content/uploads/2024/09/image-30.png)

If necessary, edit the block `deploy`for the required services in the file `docker-compose.yml`, depending on the server resources you have. By default, the minimum values ​​are used.

### Creating a zabbix service user

For security purposes, we create a group with limited rights and a service user to run zabbix containers:

```bash
sudo addgroup --system --gid 1995 zabbix

sudo adduser --system --gecos "Zabbix monitoring system" \
    --disabled-password --uid 1997 --ingroup zabbix  \
    --shell /sbin/nologin --home /opt/zabbix/zabbix_data zabbix
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-31.png)](https://r4ven.me/wp-content/uploads/2024/09/image-31.png)

### Create a postgres service user

Now, in a similar way, we create a group and user to run the TimescaleDB container:

```bash
sudo addgroup --system --gid 70 postgres

sudo adduser --system --gecos "PostgreSQL database" \
    --disabled-password --uid 70 --ingroup postgres  \
    --shell /sbin/nologin --home /opt/zabbix/postgres_data postgres
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-32.png)](https://r4ven.me/wp-content/uploads/2024/09/image-32.png)

We check the presence of all necessary files and folders:

```bash
ls -l /opt/zabbix
```

> [![](https://r4ven.me/wp-content/uploads/2024/09/image-33.png)](https://r4ven.me/wp-content/uploads/2024/09/image-33.png)

Great, let's move on 🚶.

## Creating a Password for a Postgres Database

By default, `/opt/zabbix/env/.POSTGRES_PASSWORD`I set the same password for the zabbix database in the file. But I highly recommend generating a new one, for example with this command:

```bash
tr -cd "[:alnum:]" < /dev/urandom | head -c 30 \
    | sudo tee /opt/zabbix/env/.POSTGRES_PASSWORD
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-34.png)](https://r4ven.me/wp-content/uploads/2024/09/image-34.png)

> Ignore the character `%`at the end of my example line. This is a quirk of [the ZSH shell](https://r4ven.me/it-razdel/instrukcii/zsh-interaktivnaya-komandnaya-obolochka-dlya-linux-oh-my-zsh/) , which prints it (or `#`for root) when there is no newline character.

## Running Zabbix stack with docker compose

### Start the Postgres server

First, we launch the DBMS server with the following command:

```bash
sudo docker compose -f /opt/zabbix/docker-compose.yml up -d postgres-server
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-35.png)](https://r4ven.me/wp-content/uploads/2024/09/image-35.png)

After loading the image and running the container, we look at its output:

```bash
sudo docker logs -f postgres-server
```

If launched successfully, you will see something like this:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-120-1500x181.png)](https://r4ven.me/wp-content/uploads/2024/09/image-120.png)

At the first start, scripts for preparing the environment and basic DBMS configuration are executed inside the container depending on the server parameters. In one of my tests, such a script set the parameter `max_connections`equal `25`\- which is not enough even to import the zabbix DB schema and the process will fail with an error:

```bash
FATAL:  sorry, too many clients already
```

You can check the value `max_connections`with this command:

```bash
sudo grep 'max_connections' /opt/zabbix/postgres_data/postgresql.conf
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-36.png)](https://r4ven.me/wp-content/uploads/2024/09/image-36.png)

If you have `<=25`, then this parameter needs to be increased. Open the file for editing with any console editor, for example, [Vim/Neovim](https://r4ven.me/tag/vim-neovim/) 😎:

```bash
sudo vim /opt/zabbix/postgres_data/postgresql.conf
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-37.png)](https://r4ven.me/wp-content/uploads/2024/09/image-37.png)

We find the line there:

```plaintext
max_connections = 25
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-38.png)](https://r4ven.me/wp-content/uploads/2024/09/image-38.png)

And we change it, for example, to:

```plaintext
max_connections = 200
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-39.png)](https://r4ven.me/wp-content/uploads/2024/09/image-39.png)

Save the file and exit the editor.

To apply the changes, restart the container `postgres-server`and check the current value `max_connections`:

```bash
sudo docker compose -f /opt/zabbix/docker-compose.yml restart postgres-server

sudo docker exec -it postgres-server psql -U zabbix -c "SHOW max_connections;"
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-40.png)](https://r4ven.me/wp-content/uploads/2024/09/image-40.png)

Everything has been applied, let's move on to launching the container `zabbix-server`.

### Starting Zabbix Server

We launch it with the following command:

```bash
sudo docker compose -f /opt/zabbix/docker-compose.yml up -d zabbix-server
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-41.png)](https://r4ven.me/wp-content/uploads/2024/09/image-41.png)

Let's look at the container output:

```bash
sudo docker logs -f zabbix-server
```

When you first run the container, it will start creating the database. This will take some time. The output will stop at this line:

```plaintext
Creating 'zabbix' schema in PostgreSQL
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-42.png)](https://r4ven.me/wp-content/uploads/2024/09/image-42.png)

Be sure to wait until the database creation procedure is completed!

If it runs successfully, you should see something like this:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-43.png)](https://r4ven.me/wp-content/uploads/2024/09/image-43.png)

Perhaps at the very end there will be a conclusion similar to this:

```plaintext
256:20240922:121849.602 Zabbix agent item "system.cpu.util[,system]" on host "Zabbix server" failed: first network error, wait for 15 seconds
225:20240922:121855.944 item "Zabbix server:zabbix[vmware,buffer,pused]" became not supported: No "vmware collector" processes started.
225:20240922:121858.958 item "Zabbix server:zabbix[process,report writer,avg,busy]" became not supported: No "report writer" processes started.
225:20240922:121859.962 item "Zabbix server:zabbix[process,report manager,avg,busy]" became not supported: No "report manager" processes started.
256:20240922:121904.599 Zabbix agent item "system.users.num" on host "Zabbix server" failed: another network error, wait for 15 seconds
256:20240922:121919.602 Zabbix agent item "system.cpu.load[all,avg5]" on host "Zabbix server" failed: another network error, wait for 15 seconds
225:20240922:121928.010 item "Zabbix server:zabbix[connector_queue]" became not supported: connector is not initialized: please check "StartConnectors" configuration parameter
225:20240922:121929.016 item "Zabbix server:zabbix[process,connector manager,avg,busy]" became not supported: No "connector manager" processes started.
225:20240922:121930.021 item "Zabbix server:zabbix[process,connector worker,avg,busy]" became not supported: No "connector worker" processes started.
256:20240922:121934.600 temporarily disabling Zabbix agent checks on host "Zabbix server": interface unavailable
```

We don't pay attention to him.

Check the status of running containers:

```bash
sudo docker ps
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-44-1500x189.png)](https://r4ven.me/wp-content/uploads/2024/09/image-44.png)

Everything is ok – let's move on.

### Creating a Schema for TimescaleDB

We output the password created earlier to the terminal, we will need it soon. Then we connect to the container shell `zabbix-server`:

```bash
sudo cat /opt/zabbix/env/.POSTGRES_PASSWORD

sudo docker exec -it zabbix-server bash
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-45.png)](https://r4ven.me/wp-content/uploads/2024/09/image-45.png)

Now we import the TimescaleDB schema using the SQL script that the Zabbix developers kindly put in the system files. When entering the import command, we will be asked for the DB password that we got in the previous step:

```bash
psql -h postgres-server -U zabbix zabbix < /usr/share/doc/zabbix-server-postgresql/timescaledb.sql
```

The import process is a simple redirection of the contents of the SQL script to the input of the database connection command using `psql`.

The output should be:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-46.png)](https://r4ven.me/wp-content/uploads/2024/09/image-46.png)

We exit the container `zabbix-server`and check for information about chunks in Postgres:

```bash
exit

sudo docker exec -it postgres-server \
    psql -U zabbix -c "SELECT * FROM chunks_detailed_size('history')"
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-47.png)](https://r4ven.me/wp-content/uploads/2024/09/image-47.png)

If your output is the same as in the screenshot above, then everything was imported successfully 🥳.

At this stage, the Postgres/TimesacleDB database and Zabbix server are ready 😉.

### Starting the whole stack TimesacleDB + Zabbix server + Zabbix web + Zabbix agent

We stop running containers and start the entire installation, including Zabbix web and Zabbix agent:

```bash
sudo docker compose -f /opt/zabbix/docker-compose.yml down

sudo docker compose -f /opt/zabbix/docker-compose.yml up -d
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-48.png)](https://r4ven.me/wp-content/uploads/2024/09/image-48.png)

Let's check if all containers started correctly:

```bash
sudo docker ps

sudo docker compose -f /opt/zabbix/docker-compose.yml logs -f
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-49-1500x196.png)](https://r4ven.me/wp-content/uploads/2024/09/image-49.png)

Great. Now let's check the operation of Zabbix itself:

```bash
curl -I http://localhost:8080

nc -zv localhost 10051

ss -tulnap | grep -E '8080|10051'
```

> With the first command we checked the availability of the web interface from the console, with the second – the availability of the port `zabbix-server`, and with the third we displayed the ports listened to by the host OS.

[![](https://r4ven.me/wp-content/uploads/2024/09/image-50.png)](https://r4ven.me/wp-content/uploads/2024/09/image-50.png)

Great, everything works 🎉🎉🎉.

## Access to Zabbix web interface

The way to access the Zabbix web interface depends on the conditions in which you deployed the stack. I will describe several obvious options.

_Click on the spoiler to view the instructions._

<details>
<summary>1) If Zabbix server is deployed on a local machine</summary>

Just type the URL into your browser 😁😁😁:

```bash
http://127.0.0.1:8080/
```
</details>

<details>
<summary>2) If Zabbix server is deployed on a remote server that is located in a local or VPN network</summary>

In this case, edit the network settings for services `zabbix-server`and `zabbix-web`in `docker-compose.yml`the file.

For example, the internal address of my server in the VPN network is: `192.168.122.24`. I edit `docker-compose.yml`:

```bash
sudo vim /opt/zabbix/docker-compose.yml
```

zabbix-server:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-51.png)](https://r4ven.me/wp-content/uploads/2024/09/image-51.png)

zabbix-web:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-52.png)](https://r4ven.me/wp-content/uploads/2024/09/image-52.png)

I restart all containers:

```bash
sudo docker compose -f /opt/zabbix/docker-compose.yml down

sudo docker compose -f /opt/zabbix/docker-compose.yml up -d

sudo docker ps
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-53-1500x169.png)](https://r4ven.me/wp-content/uploads/2024/09/image-53.png)

On the client connected to the VPN network, I open the following URL in the browser:

```bash
http://192.168.122.24:8080/
```
</details>

<details>
<summary>3) If Zabbix server is deployed on a remote server and is not connected to a local or VPN network</summary>

In this case, you can forward an SSH port or open access directly or through a reverse proxy, like **nginx** . I will consider only the first case, as the simplest. And also because the other two are beyond the scope of this article 😜.

On the client, open the terminal and execute:

```bash
ssh -L 8080:127.0.0.1:8080 user@example.com
```

Where (in order):

- `-L` – local port forwarding key;
- `8080` – the port that the client machine will listen to and redirect it to `8080`the server port;
- `127.0.0.1` – the address of the server on which it listens to the port;
- `8080` – accordingly the port to which we are redirecting;
- `user@example.com` – user and SSH server address.

In my example the command is:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-56.png)](https://r4ven.me/wp-content/uploads/2024/09/image-56.png)

Now open the browser and go to the address: `http://127.0.0.1:8080/`

Access to the web interface will be available as long as the SSH session is open.
</details>

To log in to the web interface, use the standard login: `Admin`and password:`zabbix`

[![](https://r4ven.me/wp-content/uploads/2024/09/image-54-1500x927.png)](https://r4ven.me/wp-content/uploads/2024/09/image-54.png)

If you saw this:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-55-1500x930.png)](https://r4ven.me/wp-content/uploads/2024/09/image-55.png)

Congratulations 😎! Zabbix server with TimescaleDB is up and running 👷‍♂️.

## Optional

Below are some optional but recommended steps of the instructions 😉.

### Minimal initial setup of Zabbix server

<details>
<summary>Click on the spoiler</summary>

I won't go into too much detail about Zabbix settings, as this is a topic for more than one article 🤯. I'll just show you how to change the interface language, create a new user with admin rights, disable the standard Admin and configure a local Zabbix agent to monitor the Zabbix server itself.

All actions are shown in pictures and do not really need any comments 😏.

**Change language**

[![](https://r4ven.me/wp-content/uploads/2024/09/image-57.png)](https://r4ven.me/wp-content/uploads/2024/09/image-57.png)

**Create a new user**

[![](https://r4ven.me/wp-content/uploads/2024/09/image-58-1500x638.png)](https://r4ven.me/wp-content/uploads/2024/09/image-58.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-59.png)](https://r4ven.me/wp-content/uploads/2024/09/image-59.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-60.png)](https://r4ven.me/wp-content/uploads/2024/09/image-60.png)

![](https://r4ven.me/wp-content/uploads/2024/09/image-61.png)

And we re-enter the interface under the new user:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-62.png)](https://r4ven.me/wp-content/uploads/2024/09/image-62.png)

**Disabling the standard Admin user**

[![](https://r4ven.me/wp-content/uploads/2024/09/image-63.png)](https://r4ven.me/wp-content/uploads/2024/09/image-63.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-64.png)](https://r4ven.me/wp-content/uploads/2024/09/image-64.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-65.png)](https://r4ven.me/wp-content/uploads/2024/09/image-65.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-66.png)](https://r4ven.me/wp-content/uploads/2024/09/image-66.png)

**Connecting a local Zabbix agent**

This agent was raised by us at the moment of launching the entire installation and is accessible by domain name `zabbix-agent`within the container network.

[![](https://r4ven.me/wp-content/uploads/2024/09/image-67.png)](https://r4ven.me/wp-content/uploads/2024/09/image-67.png)

Here we must select “Connect via” – **DNS** :

[![](https://r4ven.me/wp-content/uploads/2024/09/image-68.png)](https://r4ven.me/wp-content/uploads/2024/09/image-68.png)

Now we go to the page “Monitoring” – “Problems”. In a few minutes the problem with local availability `zabbix-agent`should be solved:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-69.png)](https://r4ven.me/wp-content/uploads/2024/09/image-69.png)

</details>

### Setting up Zabbix stack autostart with systemd

<details>
<summary>Click on the spoiler</summary>

At the beginning of the article, we created a service user zabbix. We use it to securely run Zabbix stack services.

**Setting up sudoers to run Zabbix as a service user**

> Recently I have been examining the intricacies of the privilege escalation mechanism in Linux. For a better understanding of further actions I recommend reading: [Linux command line, privilege escalation: su, sudo commands](https://r4ven.me/it-razdel/zametki/komandnaya-stroka-linux-povyshenie-privilegij-komandy-su-sudo/) 😌.

Create a new file with a description of limited permissions for the zabbix user:

```bash
sudo visudo -f /etc/sudoers.d/zabbix
```

And fill it with the following:

```bash
Cmnd_Alias ZBX = \
    /usr/bin/docker compose -f /opt/zabbix/docker-compose.yml up, \
    /usr/bin/docker compose -f /opt/zabbix/docker-compose.yml down

zabbix ALL = (:docker) NOPASSWD: ZBX
```

> **We allow the zabbix** user to start and stop the services described in our , on behalf of the privileged **docker**`docker-compose.yml` group using .`sudo`

[![](https://r4ven.me/wp-content/uploads/2024/09/image-70.png)](https://r4ven.me/wp-content/uploads/2024/09/image-70.png)

Save the file and close the editor.

**Creating a systemd service file**

Open for editing:

```bash
sudo vim /etc/systemd/system/zabbix.service
```

And we fill it:

```ini
[Unit]
Description=Zabbix service
Requires=docker.service
After=docker.service

[Service]
Restart=always
RestartSec=5
User=zabbix
ExecStart=/usr/bin/sudo --group=docker /usr/bin/docker compose -f /opt/zabbix/docker-compose.yml up
ExecStop=/usr/bin/sudo --group=docker /usr/bin/docker compose -f /opt/zabbix/docker-compose.yml down

[Install]
WantedBy=multi-user.target
```

Save, close. After that, stop the running containers, reread the systemd configuration, activate the autostart of the zabbix service and start it:

```bash
sudo docker compose -f /opt/zabbix/docker-compose.yml down

sudo systemctl enable --now zabbix

sudo systemctl status zabbix
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-71.png)](https://r4ven.me/wp-content/uploads/2024/09/image-71.png)

Checking the status of containers:

```bash
sudo docker ps
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-49-1500x196.png)](https://r4ven.me/wp-content/uploads/2024/09/image-49.png)

Everything is running. That's great 🙂.

</details>

### Installing and running Zabbix agent in docker on a remote host

<details>
<summary>Click on the spoiler</summary>

Since we deployed Zabbix in Docker, the logical step would be to launch Zabbix agents in a similar way.

> Obviously, this requires [the Docker engine](https://r4ven.me/it-razdel/instrukcii/ustanovka-docker-engine-na-linux-server-pod-upravleniem-debian/) to be installed and running .

**Downloading project files and creating a service user**

Clone the repository with files:

```bash
sudo git clone https://github.com/r4ven-me/zabbix-agent /opt/zabbix-agent
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-72.png)](https://r4ven.me/wp-content/uploads/2024/09/image-72.png)

As in the case of the server, we create a service user to run the Zabbix agent:

```bash
sudo addgroup --system --gid 1995 zabbix

sudo adduser --system --gecos "Zabbix agent" \
    --disabled-password --uid 1997 --ingroup zabbix  \
    --shell /sbin/nologin --home /opt/zabbix-agent/data zabbix
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-76.png)](https://r4ven.me/wp-content/uploads/2024/09/image-76.png)

We correct `.env`the file – the file with Zabbix agent parameters.

```bash
sudo vim /opt/zabbix-agent/.env
```

Here we must specify the existing IP address of the host on which the Zabbix agent service will wait for connections. We also specify the agent hostname and the Zabbix server address.

In my example the data is:

- Zabbix server address:`192.168.122.24`
- Zabbix agent address:`192.168.122.105`
- Zabbix agent hostname:`zabbix-agent.example.com`

[![](https://r4ven.me/wp-content/uploads/2024/09/image-73.png)](https://r4ven.me/wp-content/uploads/2024/09/image-73.png)

Description of all parameters [can be found here](https://registry.hub.docker.com/r/zabbix/zabbix-agent/) .

Now, just in case, we check the finished sudoers file and if everything is ok, we copy it to `/etc/sudoers.d/`:

```bash
sudo visudo -c -f /opt/zabbix-agent/zabbix_agent

sudo cp /opt/zabbix-agent/zabbix_agent /etc/sudoers.d/
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-74.png)](https://r4ven.me/wp-content/uploads/2024/09/image-74.png)

Next, we copy the systemd service file, reread the configuration and run it `zabbix-agent`:

```bash
sudo cp /opt/zabbix-agent/zabbix-agent.service /etc/systemd/system/

sudo systemctl daemon-reload

sudo systemctl enable --now zabbix-agent
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-75.png)](https://r4ven.me/wp-content/uploads/2024/09/image-75.png)

Please note that when you first run docker, it will download the image from the registry.

You can check the agent status with the following commands:

```bash
sudo systemctl status zabbix-agent

sudo journalctl -fu zabbix-agent

sudo docker ps
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-77-1500x664.png)](https://r4ven.me/wp-content/uploads/2024/09/image-77.png)

Zabbix agent is running.

Nuance. If you have many external partitions mounted on your server, you need to add them to the block `volume`in `docker-compose.yml`order for the Zabbix agent to detect them.

**Adding Zabbix Agent to Zabbix Server**

Almost everything is in pictures here 😇.

[![](https://r4ven.me/wp-content/uploads/2024/09/image-78-1500x542.png)](https://r4ven.me/wp-content/uploads/2024/09/image-78.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-79.png)](https://r4ven.me/wp-content/uploads/2024/09/image-79.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-80.png)](https://r4ven.me/wp-content/uploads/2024/09/image-80.png)

Go to “Monitoring” – “Network nodes” and after a while:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-81.png)](https://r4ven.me/wp-content/uploads/2024/09/image-81.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-82.png)](https://r4ven.me/wp-content/uploads/2024/09/image-82.png)

Hooray!🥳🥳🥳

</details>

### Setting up Zabbix notifications in Telegram with a schedule

<details>
<summary>Click on the spoiler</summary>

And now the interesting part 🧐. To implement the ability to send emergency notifications to Telegram with graphs, I rebuilt the container `zabbix-server`, adding a **Python** interpreter , a special **venv** and files from [the GitHub](https://github.com/xxsokolov/Zabbix-Notification-Telegram) repository of the developer **xxsokolov** - this method is marked on [the official Zabbix website](https://www.zabbix.com/ru/integrations/telegram#3rd_party) as valid 👌.

In the instructions below, the option of using my image is considered: [r4venme/zabbix-server-pgsql:alpine-7.0.3](https://hub.docker.com/repository/docker/r4venme/zabbix-server-pgsql/general) , but you can also build your own. You will find all the files for the build in the downloaded repository from the beginning of the article, in the folder `src`.

Let's start setting up.

**Creating an Alert Type (Web Interface)**

[![](https://r4ven.me/wp-content/uploads/2024/09/image-93.png)](https://r4ven.me/wp-content/uploads/2024/09/image-93.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-94.png)](https://r4ven.me/wp-content/uploads/2024/09/image-94.png)

- Name (optional):`Alerter`
- Type:`Скрипт`
- Script name:`zbxTelegram.py`
- Script parameters:
    - `{ALERT.SENDTO}`
    - `{ALERT.SUBJECT}`
    - `{ALERT.MESSAGE}`

[![](https://r4ven.me/wp-content/uploads/2024/09/image-95.png)](https://r4ven.me/wp-content/uploads/2024/09/image-95.png)

Next, go to the templates tab and add 2 pieces: for problems and for recovery:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-96.png)](https://r4ven.me/wp-content/uploads/2024/09/image-96.png)

Template for problems:

- Message Type: Problem
- Subject:`{Problem} Problem ({TRIGGER.SEVERITY})`
- Message:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<root>
    <body>
        <messages>
<![CDATA[
Problem: {EVENT.NAME}

Host: {HOST.NAME} ({HOST.IP})
Start at: {EVENT.TIME} {EVENT.DATE}

Last value: {ITEM.LASTVALUE1}

###########################
]]>
        </messages>
    </body>
    <settings>
        <graphs>True</graphs>
        <hostlinks>True</hostlinks>
        <graphlinks>False</graphlinks>
        <acklinks>True</acklinks>
        <eventlinks>True</eventlinks>
        <triggerlinks>True</triggerlinks>
        <eventtag>False</eventtag>
        <eventidtag>False</eventidtag>
        <itemidtag>False</itemidtag>
        <triggeridtag>False</triggeridtag>
        <actionidtag>False</actionidtag>
        <hostidtag>False</hostidtag>
        <zntsettingstag>True</zntsettingstag>
        <zntmentions>True</zntmentions>
        <keyboard>True</keyboard>
        <graphs_period>default</graphs_period>
        <host>{HOST.HOST}</host>
        <itemid>{ITEM.ID1} {ITEM.ID2} {ITEM.ID3} {ITEM.ID4}</itemid>
        <triggerid>{TRIGGER.ID}</triggerid>
        <eventid>{EVENT.ID}</eventid>
        <actionid>{ACTION.ID}</actionid>
        <hostid>{HOST.ID}</hostid>
        <title><![CDATA[{HOST.NAME} - {EVENT.NAME}]]></title>
        <triggerurl><![CDATA[{TRIGGER.URL}]]></triggerurl>
        <eventtags><![CDATA[{EVENT.TAGS}]]></eventtags>
    </settings>
</root>
```

After filling in, click “Add”:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-97.png)](https://r4ven.me/wp-content/uploads/2024/09/image-97.png)

Then again “Add” the following:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-98.png)](https://r4ven.me/wp-content/uploads/2024/09/image-98.png)

Recovery template:

- Message Type: Problem Recovery
- Subject:`{Resolved} Recovery`
- Message:

```xml
<?xml version="1.0" encoding="UTF-8" ?>
<root>
    <body>
        <messages>
<![CDATA[
Problem: {EVENT.RECOVERY.NAME}

Host: {HOST.NAME} ({HOST.IP})
Duration: {EVENT.DURATION} 
Recovery time: {EVENT.RECOVERY.TIME} {EVENT.RECOVERY.DATE}

Last value: {ITEM.LASTVALUE1}

###########################
]]>
        </messages>
    </body>
    <settings>
        <graphs>True</graphs>
        <hostlinks>True</hostlinks>
        <graphlinks>False</graphlinks>
        <acklinks>True</acklinks>
        <eventlinks>True</eventlinks>
        <triggerlinks>True</triggerlinks>
        <eventtag>False</eventtag>
        <eventidtag>False</eventidtag>
        <itemidtag>False</itemidtag>
        <triggeridtag>False</triggeridtag>
        <actionidtag>False</actionidtag>
        <hostidtag>False</hostidtag>
        <zntsettingstag>True</zntsettingstag>
        <zntmentions>True</zntmentions>
        <keyboard>True</keyboard>
        <graphs_period>default</graphs_period>
        <host>{HOST.HOST}</host>
        <itemid>{ITEM.ID1} {ITEM.ID2} {ITEM.ID3} {ITEM.ID4}</itemid>
        <triggerid>{TRIGGER.ID}</triggerid>
        <eventid>{EVENT.ID}</eventid>
        <actionid>{ACTION.ID}</actionid>
        <hostid>{HOST.ID}</hostid>
        <title><![CDATA[{HOST.NAME} - {EVENT.NAME}]]></title>
        <triggerurl><![CDATA[{TRIGGER.URL}]]></triggerurl>
        <eventtags><![CDATA[{EVENT.TAGS}]]></eventtags>
    </settings>
</root>
```

Next “Add”:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-99.png)](https://r4ven.me/wp-content/uploads/2024/09/image-99.png)

And finally, here again:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-100.png)](https://r4ven.me/wp-content/uploads/2024/09/image-100.png)

It should look like this:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-101.png)](https://r4ven.me/wp-content/uploads/2024/09/image-101.png)

**Creating a service user (web interface)**

Now let's create a service user for sending notifications:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-92.png)](https://r4ven.me/wp-content/uploads/2024/09/image-92.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-91.png)](https://r4ven.me/wp-content/uploads/2024/09/image-91.png)

Fill in all the required fields:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-102.png)](https://r4ven.me/wp-content/uploads/2024/09/image-102.png)

> The background of the graphs in notifications depends on the theme you choose.

After that, go to the “Notifications” tab and in the “Send to” field, specify the Telegram ID of the chat or group ( [instructions from the official Zabbix website on how to get the ID](https://www.zabbix.com/ru/integrations/telegram) ):

[![](https://r4ven.me/wp-content/uploads/2024/09/image-103.png)](https://r4ven.me/wp-content/uploads/2024/09/image-103.png)

Next, go to “Access Rights”. Here, in a good way, you first need to set up limited groups and user roles. But this is a delicate process, and it is also beyond the scope of the article. For a quick solution, I give the service user “superadmin” rights, since the script requires read rights for network nodes and templates to work. This is up to you.

[![](https://r4ven.me/wp-content/uploads/2024/09/image-104.png)](https://r4ven.me/wp-content/uploads/2024/09/image-104.png)

And at the end, click on the main “Add”:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-105.png)](https://r4ven.me/wp-content/uploads/2024/09/image-105.png)

**Setting up notification conditions (web interface)**

Go to “Trigger Actions” and create a new one:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-109.png)](https://r4ven.me/wp-content/uploads/2024/09/image-109.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-110.png)](https://r4ven.me/wp-content/uploads/2024/09/image-110.png)

We set the name and add the condition. In the condition we specify 2 templates, as in the screenshot:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-111.png)](https://r4ven.me/wp-content/uploads/2024/09/image-111.png)

Next, go to the “Operations” tab and add 2 actions there: for “Operations” and “Recovery operations”:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-121.png)](https://r4ven.me/wp-content/uploads/2024/09/image-121.png)

We specify the recipient - our service user, who registered the group/chat ID in the telegram. Here we also specify the sending method: the one we created earlier:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-113.png)](https://r4ven.me/wp-content/uploads/2024/09/image-113.png)

Something like this:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-114.png)](https://r4ven.me/wp-content/uploads/2024/09/image-114.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-115-1500x145.png)](https://r4ven.me/wp-content/uploads/2024/09/image-115.png)

**Editing docker-compose.yml (server console)**

We return to the server and open it for editing:

```bash
sudo vim /opt/zabbix/docker-compose.yml
```

We edit the service `zabbix-server`, block `image`. We comment the current line, and uncomment the line with the address of the image I have assembled:

```yaml
# image: zabbix/zabbix-server-pgsql:alpine-7.0.3
image: r4venme/zabbix-server-pgsql:alpine-7.0.3
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-83.png)](https://r4ven.me/wp-content/uploads/2024/09/image-83.png)

Save and restart `zabbix-server`:

```bash
sudo systemctl restart zabbix

sudo journalctl -fu zabbix

sudo docker ps
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-85-1500x305.png)](https://r4ven.me/wp-content/uploads/2024/09/image-85.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-86-1500x179.png)](https://r4ven.me/wp-content/uploads/2024/09/image-86.png)

`zabbix-server`After launching, we create a folder of alarm scripts, copy the config file of the script for sending notifications to the telegram from the docker container and change its owner:

```bash
sudo mkdir -p /opt/zabbix/zabbix_data/server/alertscripts/

sudo docker cp zabbix-server:/usr/lib/zabbix/alertscripts/zbxTelegram_config.py \
    /opt/zabbix/zabbix_data/server/alertscripts/

sudo chown -R zabbix:zabbix /opt/zabbix/zabbix_data/server/alertscripts/
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-87.png)](https://r4ven.me/wp-content/uploads/2024/09/image-87.png)

Reopening `docker-compose.yml`:

```bash
sudo vim /opt/zabbix/docker-compose.yml
```

For the service `zabbix-server`and in the block, `volume`uncomment the following line:

```yaml
- ./zabbix_data/server/alertscripts/zbxTelegram_config.py:/usr/lib/zabbix/alertscripts/zbxTelegram_config.py
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-84.png)](https://r4ven.me/wp-content/uploads/2024/09/image-84.png)

Don't forget to save.

**Sending settings (server console)**

There's just a little bit left 🥺.

Open the copied config file for editing:

```bash
sudo vim /opt/zabbix/zabbix_data/server/alertscripts/zbxTelegram_config.py
```

And we specify the token of our bot ( [how to get it](https://www.zabbix.com/ru/integrations/telegram) ) in the line `tg_token`inside single quotes:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-89.png)](https://r4ven.me/wp-content/uploads/2024/09/image-89.png)

Scroll down the file and also specify the service user and password that we created earlier:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-90.png)](https://r4ven.me/wp-content/uploads/2024/09/image-90.png)

> `zabbix_api_url`– this is the internal network address of the container. Do not touch it if you have not changed it.

Recreate the container `zabbix-server`:

```bash
sudo docker compose -f /opt/zabbix/docker-compose.yml down zabbix-server

sudo docker compose -f /opt/zabbix/docker-compose.yml up -d zabbix-server
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-119.png)](https://r4ven.me/wp-content/uploads/2024/09/image-119.png)

**Check (server console)**

We check sending messages in the command line:

```bash
sudo docker exec -it zabbix-server \
    /usr/lib/zabbix/alertscripts/zbxTelegram.py 1234567890 test test
```

> Where `1234567890`is the ID of the chat or group in Telegram.

[![](https://r4ven.me/wp-content/uploads/2024/09/image-107-1500x229.png)](https://r4ven.me/wp-content/uploads/2024/09/image-107.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-106.png)](https://r4ven.me/wp-content/uploads/2024/09/image-106.png)

It works 👍.

**Testing in practice**

If you connected the local one `zabbix-agent`during the initial setup step, then to check it, simply stop it with the command:

```bash
sudo docker compose -f /opt/zabbix/docker-compose.yml stop zabbix-agent
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-116.png)](https://r4ven.me/wp-content/uploads/2024/09/image-116.png)

Go to the web interface along the path: “Monitoring” – “Problems”. In a few minutes, the agent will receive the “Unavailable” status, the problem will appear on the corresponding web panel and you should receive a notification in Telegram.

[![](https://r4ven.me/wp-content/uploads/2024/09/image-117-1500x262.png)](https://r4ven.me/wp-content/uploads/2024/09/image-117.png)

[![](https://r4ven.me/wp-content/uploads/2024/09/image-122.png)](https://r4ven.me/wp-content/uploads/2024/09/image-122.png)

The message arrived, great. Now let's launch the agent:

```bash
sudo docker compose -f /opt/zabbix/docker-compose.yml start zabbix-agent
```

[![](https://r4ven.me/wp-content/uploads/2024/09/image-118.png)](https://r4ven.me/wp-content/uploads/2024/09/image-118.png)

In a few minutes it will be restored in the web panel and a corresponding notification will be sent to Telegram:

[![](https://r4ven.me/wp-content/uploads/2024/09/image-123.png)](https://r4ven.me/wp-content/uploads/2024/09/image-123.png)

Lovely 🤤.

</details>

## Conclusion

Phew..🤯 this wasn't the easiest article. Especially in terms of the amount of information we had to sift through. But I think it was worth it. As a result, we got a flexible and easily portable monitoring system project that works inside docker containers. We also set up concise but informative notifications with graphs in Telegram to always be aware of the state of our infrastructure.

I would also like to note the excellent work of Zabbix developers. In particular, the relevance and diversity of docker images and the availability of their build files. After writing this article, I respected them even more 👍.

Thank you for reading 😊. If you have any questions, I invite you to [the Raven Chat](https://t.me/r4ven_me_chat/) , as you guessed, in Telegram 😅. We have a friendly community there 🚶‍♀️🐧🚶🐧🚶‍♂️🐧. And be sure to subscribe to the main Telegram channel: [@r4ven\_me](https://t.me/r4ven_me/) , so as not to miss the publication of new materials on the site.

I wish you success and a successful salesman! 😌

## Materials used

- [My zabbix server repository | GitHub](https://github.com/r4ven-me/zabbix)
- [My zabbix agent repository | GitHub](https://github.com/r4ven-me/zabbix-agent)
- [Using TimescaleDB with Zabbix | Zabbix.com (EN)](https://www.zabbix.com/documentation/current/en/manual/appendix/install/timescaledb)
- [The original docker files I adapted | GitHub](https://github.com/smejdil/zabbix-docker-timescaledb/tree/main/2.7.2-pg14)
- [TimescaleDB docker image registry | Dockerhub](https://hub.docker.com/r/timescale/timescaledb)
- [Description of the PostgresSQL docker image | Dockerhub](https://hub.docker.com/_/postgres)
- [TimescaleDB docker image sources | GitHub](https://github.com/timescale/timescaledb-docker/)
- [Description of Zabbix server docker image | Dockerhub](https://hub.docker.com/r/zabbix/zabbix-server-pgsql)
- [Description of the Zabbix web docker image | Dockerhub](https://hub.docker.com/r/zabbix/zabbix-web-nginx-pgsql)
- [Description of Zabbix agent docker image | Dockerhub](https://registry.hub.docker.com/r/zabbix/zabbix-agent/)
- [Source Dockerfile for Zabbix server | GitHub](https://github.com/zabbix/zabbix-docker/tree/7.0/Dockerfiles/server-pgsql/alpine)
- [Zabbix Notification Telegram Source Files | GitHub](https://github.com/xxsokolov/Zabbix-Notification-Telegram)
- [Description of Zabbix Notification Telegram script | GitHub](https://github.com/xxsokolov/Zabbix-Notification-Telegram?)
- [Zabbix Notification Telegram Installation Guide | GitHub](https://github.com/xxsokolov/Zabbix-Notification-Telegram/wiki/%D0%A3%D1%81%D1%82%D0%B0%D0%BD%D0%BE%D0%B2%D0%BA%D0%B0-%D0%BD%D0%BE%D1%82%D0%B8%D1%84%D0%B8%D0%BA%D0%B0%D1%82%D0%BE%D1%80%D0%B0-Zabbix-Notification-Telegram)