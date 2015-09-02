# Anchnet volume example

The folder contains two examples for working with anchnet volume: Pod with volume and Persistent volume.

## Pod with volume

An `anchnetPersistentDisk` volume mounts an Anchnet persistent disk into a pod. Unlike `emptyDir`, which is erased when a Pod is
removed, the contents of a PD are preserved and the volume is merely unmounted.  This means that a PD can be pre-populated with
data, and that data can be "handed off" between pods.

Following is an example Pod, note __You must create a PD using `anchnet` CLI or the anchnet API or UI before you can use it__

### Example pod

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mongo
  labels:
    name: mongo
spec:
  containers:
    - name: mongo
      image: mongo:3.0.5
      ports:
        - containerPort: 27017
      volumeMounts:
        - name: mongo-storage
          mountPath: /data/db
  volumes:
    - name: mongo-storage
      anchnetPersistentDisk:
        volumeID: vol-I3BYQTKX
        fsType: ext4
```

### Workflow

When a pod with anchnet persistent disk is created, kubelet will find the volume in anchnet, then format and mount it to its working
directory (usually `/var/lib/kubelet`). This acutally involues three steps. First, kubelet calls anchnet API to attach the volume to
the instance it currently runs. The volume will then appear as `/dev/sd[a-z]`. Second, kubelet mount the device to a global path, i.e.
`/var/lib/kubelet/plugins/kubernetes.io/anchnet-pd/mounts/vol-I3BYQTKX`. This is the core place where device is mounted. Third, kubelet
performs a bind mount to mount the device to pod, e.g. `/var/lib/kubelet/pods/11053ab6-4ba7/volumes/kubernetes.io~pd/mongodb~volume`.
The above two directories have the same content (since they share the same device, think of hard link). The reason for the bind mount
is because some cloudproviders support mounting a device to multiple pods in read-only mode.

When the pod gets deleted, kubelet will first unmount the bind mount for the pod; then it checks if there is any other reference to
the persistent disk. If there is, then nothing will be done; if there isn't, then the disk will be unmounted from the host. The disk
will become available in anchnet's console, and can be mounted again.

TODO: what if node restart?

## Persistent volume

Persistent volume is a type of resource available to kubernetes cluster, just like node compute resource. For information about how
it works, see [Persistent volume](https://github.com/caicloud/caicloud-kubernetes/blob/master/docs/user-guide/persistent-volumes.md).

### Example persistent volume

Example of persistent volume in anchnet:

```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: anchnet-pv
spec:
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  anchnetPersistentDisk:
    volumeID: vom-PGRF3I54
    fsType: ext4
```

After creating the volume, we can list it:
```sh
$ kubectl get pv
NAME         LABELS    CAPACITY   ACCESSMODES   STATUS      CLAIM     REASON    AGE
anchnet-pv   <none>    10Gi       RWO           Available                       17m
```

Example of persistent volume claim:

```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: myclaim
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 8Gi
```

After creating the volume claim, we can list it:
```sh
$ kubectl get pvc
NAME      LABELS    STATUS    VOLUME       CAPACITY   ACCESSMODES   AGE
myclaim   <none>    Bound     anchnet-pv   10Gi       RWO           23s
```

Until this point, the volume still shows available in anchnet (not mounted to any host yet!). Be careful not to delete the volume, as
it we'll encounter errors when user actually tries to use it.

Example of using a persistent volume claim:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: mongo
  labels:
    name: mongo
spec:
  containers:
    - name: mongo
      image: mongo:3.0.5
      ports:
        - containerPort: 27017
      volumeMounts:
        - name: mongo-storage
          mountPath: /data/db
  volumes:
    - name: mongo-storage
      persistentVolumeClaim:
        claimName: myclaim
```
