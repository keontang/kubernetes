# Caicloud baremetal cloudprovider

Baremetal cloudprovider implements kubernetes cloudprovider plugin. It assumes nothing but a few running instances.

## Create a development cluster

To create a kubernetes cluster for local developement, first create VMs using Vagrant file:
```
vagrant up
```

This will create two ubuntu VMs with dedicated IP addresses. Now, to bring up kubernete cluster, simply run:
```
KUBERNETES_PROVIDER=caicloud-baremetal ./cluster/kube-up.sh
```

## Scale up the cluster
To add nodes to a baremetal cluster, you have to know the ssh info of master and nodes to be added. e.g. The cluster to add node to has a master `vagrant:vagrant@192.168.205.10`, and the node to be added is `vagrant:vagrant@192.168.205.13`. To add node to this cluster, run:
```
MASTER_SSH_INFO=vagrant:vagrant@192.168.205.10 NODE_SSH_INFO=vagrant:vagrant@192.168.205.13 KUBERNETES_PROVIDER=caicloud-baremetal ./cluster/kube-add-node.sh
```


#### Options:

There are quite a few options used to create a baremetal cluster, located at `config-default.sh`. Following is a curated list of options
used in kube-up. For a full list of options, consult the file.

* `KUBE_DISTRO`: The Linux distribution of underline OS, currently only ubuntu:trusty is supported.

* `MASTER_SSH_INFO`: The master ssh information in the format of "username:password@ip_address". HA master is currently supported.

* `NODE_SSH_INFO`: The master ssh information in the format of "username:password@ip_address". Multiple nodes are separated via comma.

* `REGISTER_MASTER_KUBELET`: The flag controls whether we registry master as a node, this is true by default.
