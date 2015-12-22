# Anchnet cloudprovider

The directory contains implementation of anchnet cloud provider.

## List of APIs called

- DescribeInstance
  This is called from kubelet at every sync loop. However, we do aggresive caching to decrease load at anchnet,
  and to minimize its downtime impact. This is also used to list all instances and find node resources, but it
  is never called in kubernetes. (See anchnet_instances.go)

- AttachVolume, DetachVolume
  These are called when Pods with volume (or persistent volumes) are created. (See anchnet_volume.go)

- DescribeLoadbalancer, DeleteLoadbalancer, CreateLoadbalancer
  These are called when Services with type LoadBalancer are created. (see anchnet_lb.go)
