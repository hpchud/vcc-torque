# vcc-torque

This is a VCC built to run a Torque batch scheduling cluster.

## Running it

The VCC tool is shipped inside each image and is used to make the process of starting the containers easier. A description of all available options can be invoked as follows

```
docker run --rm -it hpchud/vcc-torque --help
```

Information about the image can be obtained by running

```
docker run --rm -it hpchud/vcc-torque --info
```

You need to have a discovery service running

```
docker run -d -p 2379:2379 hpchud/vcc-discovery
```

Start a head node first

```
docker run -d --net=host hpchud/vcc-torque \
    --cluster=test \
    --storage-host=STORAGE_HOST_IP \
    --storage-port=2379 \
    --service=headnode
```

An ID for this container will be printed to the screen.

Then, on another host, start a worker node

```
docker run -d --net=host hpchud/vcc-torque \
    --cluster=test \
    --storage-host=STORAGE_HOST_IP \
    --storage-port=2379 \
    --service=workernode
```

And that's it! You can now enter the head node container by executing the following command on the host running it 

```
docker exec -it ID /bin/bash
```
where CID is the ID of the head node container assigned by Docker.

Read on to find out how this image is configured, how to access it using SSH, how to use your own user accounts, etc.

## Configuration

### Services

This image is a *multi-role* image - the same Docker image provides both `headnode` and `workernode` roles in the context of a Torque cluster. If not specified, it will default to `workernode` role.

The default role is configured in `init.yml`.

The services defined in `services.yml` will be launched for both roles. The following services are always required

- clusternet
- clusterdns
- loadtargets
- wait4deps
- registerservice
- clusterwatcher

and should not be removed.

This image is configured so that an SSH daemon will be started for both roles.

Each role also has an associated `services-*.yml` file. This file contains services that must be processed just for that role.

These service files are YAML documents. A service block looks like

```
pbs_server:
    type: daemon
    exec: /usr/sbin/pbs_server -D
    restart_limit: -1
    requires: trqauthd
```

In this example, the service is the PBS server daemon. A `type` of daemon will cause the service manager to write a pid file and log files to the appropriate locations, usually `/run` and `/var/log` respectively. 

`restart_limit: -1` instructs the service manager to always restart this service everytime it is killed - this is required as when the number of hosts in the cluster changes, this service will need to be restarted.

Finally, and most importantly, the PBS server states that it requires the `trqauthd` service to be started before it can start. This pattern can be seen in the other service blocks to ensure execution occurs in the correct order.

If a service block does not define any `requires` it will be triggered to start as soon as the service manager runs.

### Hooks

The `pbsnodes.sh` *cluster hook* is executed everytime a host (or running container) is added or removed from this VCC instance. This facilitates regeneration of the Torque server's node file, and then instructs it to reload the daemon.

The `headnode.sh` *service hook* is run when the provider of a service within the VCC changes, in this case, the `headnode` *cluster service*. This facilitates configuration of the Torque MOM execution node client.

### User Accounts

A user is created in the Dockerfile called `batchuser`.

### Passwordless SSH

For the `batchuser` account, an SSH key is added to the image and to the `authorized_keys` file. The SSH service is configured to run on port `2222` to avoid overlapping with any SSH instance on the host system.

### Shared filesystem

No shared filesystem is configured between the containers using this image, as the container must be run in privileged mode in order to perform a mount. 

A shared filesystem may not be required at all if you customise the container image to include all the files you need.

Alternatively, if your underlying hosts are set up with a shared filesystem mounted, you can pass this through to the container as a volume.

## Customising the cluster

In order to customise the cluster image, such as changing the SSH port, adding/removing users and packages, there are two options: clone this repository and make the changes, or create a new Dockerfile that extends this image.

Which option you choose depends on what you would like to do. If you want to contribute a change, please fork the repository and create a pull request!

If you want to add additional packages, the best way might be to create a new Dockerfile that is based from this image.

However, if for example you want to remove the `batchuser` account, your only choice would be to make a copy of this repository and change it.