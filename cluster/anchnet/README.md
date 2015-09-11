## Anchnet cloudprovider

Anchnet cloudprovider is internally supported by caicloud.io. It conforms to kubernetes cloudprovider plugin convention, and can be considered natively supported by kubernetes.

### Background on anchnet cloudprovider

[Anchnet](http://cloud.51idc.com/) is one of caicloud's IDC/IaaS parteners. It has most common features seen in other cloudproviders, e.g. Cloud Instances, External IPs, Load
balancers, etc, see [help center](http://cloud.51idc.com/help/cloud/index.html). [API doc](http://cloud.51idc.com/help/api/index.html) lists all public APIs (there are some
internal ones also). SDK is developed by caicloud team at https://github.com/caicloud/anchnet-go.

### Create a cluster using anchnet

To create a kubernetes cluster, make sure you've installed anchnet SDK. To install:
```
go get github.com/caicloud/anchnet-go/anchnet
```

This will install binary `anchnet` under `$GOPATH/bin` - make sure it's in your `PATH` variable. The binary also needs a config file (e.g ~/.anchnet/config) with API keys,
see [anchnet SDK](https://github.com/caicloud/anchnet-go). After the setup, you can create a cluster by simply running:
```
KUBERNETES_PROVIDER=anchnet ./cluster/kube-up.sh
```

##### Options:

There are quite a few options used to create a cluster in anchnet, located at `config-default.sh` and `executor-config.sh`. `config-default.sh` is static information
configured by caicloud admin, like node ip range, admission control plugin, etc. `executor-config.sh` is dynamic information configured by user and executor, like number
of nodes, cluster name, etc. Therefore, most interesting options are in `executor-config.sh`. Following is a curated list of options used for kube-up; for a full list of
options, consult the two files.

* `CLUSTER_NAME`: The name of newly created cluster. This is used to identify a cluster - all resources will be prefixed with this name. The variable is default to
"k8s-default". E.g. the following command will create a cluster named "caicloud-rocks", and all instances (plus other resources like firewall) will be prefixed with
"caicloud-rocks".
    ```
    KUBERNETES_PROVIDER=anchnet CLUSTER_NAME=caicloud-rocks ./cluster/kube-up.sh
    ```

* `PROJECT_ID`: The project to use. In anchnet, project is actually a sub-account, it helps admin to manage resources. All resouces under a project (sub-account) is isolated
  from others. An anchnet account can have multiple sub-accounts. The variable is default to empty string, which means main-account. E.g. following command creates a cluster
  named "caicloud-rocks" under project "pro-H4ZW87K2" ("pro-H4ZW87K2" must exist, see below):
    ```
    KUBERNETES_PROVIDER=anchnet CLUSTER_NAME=caicloud-rocks PROJECT_ID=pro-H4ZW87K2 ./cluster/kube-up.sh
    ```

* `KUBE_USER`: The kubernetes user name. This variable is default to empty string. If `KUBE_USER` is set, the `kubeconfig` file, which has all the information of how to access
  the cluster, will be created at `$HOME/.kube/config_${KUBE_USER}`. If not set, default location (`$HOME/.kube/config`) will be used. In production, we should always set
  `KUBE_USER`, leaving it empty should only be used during development. The variable has some correlation with `PROJECT_ID`:

  * If `PROJECT_ID` is set, it means this `KUBE_USER` has already been accociated with a sub account before, so that we just bring up cluster under that sub account:
    E.g. following command creates a cluster under a specific sub account:
    ```
    KUBERNETES_PROVIDER=anchnet CLUSTER_NAME=caicloud-rocks KUBE_USER=test_user PROJECT_ID=pro-H4ZW87K2 ./cluster/kube-up.sh
    ```

  * If `PROJECT_ID` is not set, it means this is the first time user wants to create a cluster and there is no anchnet sub account associated with `KUBE_USER`. In this case,
    an anchnet sub account will be automatically created and reported back to executor service, and the cluster will be created in the new sub account. E.g. following
    command will create a sub-account and then create a cluster:
    ```
    KUBERNETES_PROVIDER=anchnet CLUSTER_NAME=caicloud-rocks KUBE_USER=test_user ./cluster/kube-up.sh
    ```

* `CAICLOUD_VERSION`: The version of caicloud release to use. If `caicloud_version` is not empty, then use that version directly. Note the version must exist, see
  `hack/caicloud-tools/caicloud-version.sh`. If it's empty, current code base will be built and pushed to file server, see `hack/caicloud-tools/build-tarball.sh`.
  Default value is "v0.1". If `caicloud_version` is explicitly set to empty, the default value is `$(TZ=Asia/Shanghai date +%Y-%m-%d-%H-%M)`.
  E.g., following command creates a cluster using version `v0.2`:
  ```
  KUBERNETES_PROVIDER=anchnet CLUSTER_VERSION=v0.2 ./cluster/kube-up.sh
  ```
  Following command create a cluster from code base tagged with current timestamp:
  ```
  KUBERNETES_PROVIDER=anchnet CLUSTER_VERSION="" ./cluster/kube-up.sh
  ```

* `KUBE_INSTANCE_LOGDIR`: Directory for holding kubeup instance specific logs. During kube-up, instances will be installed/provisioned concurrently; if we just send logs to
  stdout, stdout will mess up. Therefore, we specify a directory to hold instance specific logs. All other logs will be sent to stdout, e.g. create instances from anchnet.
  Default value is "`/tmp/kubeup-$(TZ=Asia/Shanghai date +%Y-%m-%d-%H-%M-%S)`". The log directory looks like:
  ```
  $ ls /tmp/kubeup-2015-09-12-01-00-48
  $ i-6TDSS52U i-ALCWC66X i-JZ9EDO70 i-THBJ0VCD i-UAAE4SUG
  ```
  Where 'i-6TDSS52U' is instance id. If no output is desired, the common pattern is to set `KUBE_INSTANCE_LOGDIR` and redirect stdout to `${KUBE_INSTANCE_LOGDIR}/common-logs`.

* `ANCHNET_CONFIG_FILE`: The config file supplied to `anchnet` SDK CLI. Default value is `~/.anchnet/config`. Usually, you don't have to change the value, unless you want to
  create cluster under another anchnet account (NOT sub-account).

### Delete a cluster

Deleting a cluster will delete everything associated with the cluster, including instances, vxnet, external ips, firewalls, etc. (TODO: delete loadbalancer, see
[issue](https://github.com/caicloud/caicloud-kubernetes/issues/101)). To bring down a cluster, run:

```
KUBERNETES_PROVIDER=anchnet ./cluster/kube-down.sh
```

##### Options:

* `CLUSTER_NAME`: Delete cluster with given name.

* `PROJECT_ID`: Delete cluster from sub-account with given id. E.g. following command deletes cluster "caicloud-rocks" under project "pro-H4ZW87K2".
  ```
  KUBERNETES_PROVIDER=anchnet CLUSTER_NAME=caicloud-rocks PROJECT_ID=pro-H4ZW87K2 ./cluster/kube-down.sh
  ```

### Update a cluster

Updating a cluster will build current code base and push/restart cluster, useful for development. To update a cluster, run:

```
KUBERNETES_PROVIDER=anchnet ./cluster/kube-push.sh
```

##### Options:

Same options as deleting a cluster.
