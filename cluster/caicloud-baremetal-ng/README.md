# Caicloud baremetal ng cloudprovider

Baremetal cloudprovider implements kubernetes cloudprovider plugin. It assumes nothing but a few running instances.  

## Create a development cluster

To create a kubernetes cluster for local developement, first create VMs using Vagrant file:
```
vagrant up
```

This will create several ubuntu VMs with dedicated IP addresses. Now, to bring up kubernete cluster, simply run:
```
KUBERNETES_PROVIDER=caicloud-baremetal-ng ./cluster/kube-up.sh
```

