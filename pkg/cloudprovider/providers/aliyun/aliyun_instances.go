/*
Copyright 2016 The Kubernetes Authors All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package aliyun

import (
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"

	"github.com/denverdino/aliyungo/common"
	"github.com/denverdino/aliyungo/ecs"
	"github.com/denverdino/aliyungo/slb"
	"github.com/golang/glog"
	"k8s.io/kubernetes/pkg/api"
	"k8s.io/kubernetes/pkg/cloudprovider"
	"k8s.io/kubernetes/pkg/types"
	"k8s.io/kubernetes/pkg/util/sets"
)

// NodeAddresses returns the addresses of the specified instance.
func (aly *Aliyun) NodeAddresses(name string) ([]api.NodeAddress, error) {
	glog.V(4).Infof("NodeAddresses(%v) called", name)

	addrs, err := aly.getAddressesByName(name)
	if err != nil {
		glog.Errorf("Error getting node address by name '%s': %v", name, err)
		return nil, err
	}

	glog.V(4).Infof("NodeAddresses(%v) => %v", name, addrs)
	return addrs, nil
}

// ExternalID returns the cloud provider ID of the specified instance (deprecated).
func (aly *Aliyun) ExternalID(name string) (string, error) {
	instanceID, err := aly.getInstanceIdByName(name)
	if err != nil {
		glog.Errorf("Error getting instanceID by name '%s': %v", name, err)
		return "", err
	}
	return instanceID, nil
}

// InstanceID returns the cloud provider ID of the specified instance.
// Note that if the instance does not exist or is no longer running, we must return ("", cloudprovider.InstanceNotFound)
func (aly *Aliyun) InstanceID(name string) (string, error) {
	instanceID, err := aly.getInstanceIdByNameAndStatus(name, ecs.Running)
	if err != nil {
		glog.Errorf("Error getting instanceID by name '%s': %v", name, err)
		return "", cloudprovider.InstanceNotFound
	}
	return instanceID, nil
}

// InstanceType returns the type of the specified instance.
func (aly *Aliyun) InstanceType(name string) (string, error) {
	return "", nil
}

// List lists instances that match 'filter' which is a regular expression which must match the entire instance name (fqdn)
func (aly *Aliyun) List(name_filter string) ([]string, error) {
	instances, err := aly.getInstancesByNameFilter(name_filter)
	if err != nil {
		glog.Errorf("Error getting instances by name_filter '%s': %v", name_filter, err)
		return nil, err
	}
	result := []string{}
	for _, instance := range instances {
		result = append(result, instance.InstanceName)
	}

	glog.V(4).Infof("List instances: %s => %v", name_filter, result)

	return result, nil
}

// AddSSHKeyToAllInstances adds an SSH public key as a legal identity for all instances.
// The method is currently only used in gce.
func (aly *Aliyun) AddSSHKeyToAllInstances(user string, keyData []byte) error {
	return errors.New("Unimplemented")
}

// CurrentNodeName returns the name of the node we are currently running on
// On most clouds (e.g. GCE) this is the hostname, so we provide the hostname
func (aly *Aliyun) CurrentNodeName(hostname string) (string, error) {
	return hostname, nil
}
