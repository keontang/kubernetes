/*
Copyright 2015 The Kubernetes Authors All rights reserved.

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

package anchnet_cloud

import (
	"errors"
	"fmt"
	"net"
	"os"
	"time"

	"github.com/golang/glog"
	"k8s.io/kubernetes/pkg/api"
	"k8s.io/kubernetes/pkg/cloudprovider"

	anchnet_client "github.com/caicloud/anchnet-go"
)

// IMPORTANT: In kubernetes, hostname is queried from local machine using 'uname -n',
// or is overridden by 'hostnameOverride' flag in kubelet. On the other hand, nodename
// means the name of the node appears to cloudprovider. In anchnet, an example node
// instance has id i-FF830WKU, but has hostname i-i1qnjmt1. According to anchnet, there
// is no relationship between the two names. Therefore, we establish the convention
// that node name equals to lower-cased instance id (i-ff830wku), and hostname is
// overridden to node name as well (i-ff830wku). The hostname assigned by anchnet
// is thus not used. Note all of the names are lowercased since kubernetes expects DNS
// subdomain format.

//
// Following methods implement Cloudprovider.Instances. Instances are used by kubernetes
// to get instance information; cloud provider must implement the interface.
//
var _ cloudprovider.Instances = (*Anchnet)(nil)

// NodeAddresses returns an implementation of Instances.NodeAddresses. The 'name'
// parameter means node name (which equals to lower case'd instance ID). Before
// querying anchnet, we convert it to InstanceID.
func (an *Anchnet) NodeAddresses(name string) ([]api.NodeAddress, error) {
	name = convertToInstanceID(name)

	// Return directly if we find node address in cache.
	data, exists, err := an.addressCache.GetByKey(name)
	if exists && err == nil {
		return data.(AddressCacheEntry).addresses, nil
	}

	// Can't find address in cache, build it.
	var addresses []api.NodeAddress

	// Find public IP address.
	response, err := an.describeInstance(name)
	if err != nil {
		return nil, err
	}
	addresses = append(addresses, api.NodeAddress{Type: api.NodeExternalIP, Address: response.ItemSet[0].EIP.EipAddr})

	// Find private IP address (private SDN). Note it's not possbile to find private IP
	// address for instance other than self, i.e. to find private IP, the function must
	// be called from kubelet running on instance 'name'. An alternative is to ssh into
	// the machine and run `ifconfig`, but this requires setting up ssh.
	// $ ssh ubuntu@external_ip ifconfig | grep -A 1 'eth1' | tail -1 | cut -d ':' -f 2 | cut -d ' ' -f 1
	searchPrivateIP := true
	hostname, err := os.Hostname()
	if err != nil {
		glog.Warningf("unable to get hostname %v", err)
		searchPrivateIP = false
	}
	instanceID := convertToInstanceID(hostname)
	if instanceID != name {
		glog.Warningf("unable to find node addresses for instance other than self instance")
		searchPrivateIP = false
	}

	// Here we assume private SDN is on eth1, and can alwasys be found.
	// TODO: Need a reliable way to get interface name.
	if searchPrivateIP {
		var ip net.IP
		ifaces, _ := net.Interfaces()
		for _, iface := range ifaces {
			if iface.Name == "eth1" {
				addrs, _ := iface.Addrs()
				for _, addr := range addrs {
					switch v := addr.(type) {
					case *net.IPNet:
						if v.IP.To4() != nil {
							ip = v.IP
							break
						}
					}
				}
			}
		}
		addresses = append(addresses, api.NodeAddress{Type: api.NodeInternalIP, Address: ip.String()})
	}

	an.addressCache.Add(AddressCacheEntry{
		name:      name,
		addresses: addresses,
	})

	return addresses, nil
}

// ExternalID returns the cloud provider ID of the specified instance (deprecated).
func (an *Anchnet) ExternalID(name string) (string, error) {
	return convertToInstanceID(name), nil
}

// InstanceID returns the cloud provider ID of the specified instance.
func (an *Anchnet) InstanceID(name string) (string, error) {
	return convertToInstanceID(name), nil
}

// List is an implementation of Instances.List.
// TODO: Figure out how this works.
func (an *Anchnet) List(filter string) ([]string, error) {
	response, err := an.searchInstances(filter)
	if err != nil {
		return nil, err
	}
	result := []string{}
	for _, item := range response.ItemSet {
		result = append(result, item.InstanceID)
	}
	return result, nil
}

// GetNodeResources implements Instances.GetNodeResources. This is acutally not used
// in kubernetes - node resources is now reported by cAdvisor on each node.
func (an *Anchnet) GetNodeResources(name string) (*api.NodeResources, error) {
	name = convertToInstanceID(name)
	response, err := an.describeInstance(name)
	if err != nil {
		return nil, err
	}
	return makeResources(response.ItemSet[0].VcpusCurrent, response.ItemSet[0].MemoryCurrent/1024), nil
}

// AddSSHKeyToAllInstances adds an SSH public key as a legal identity for all instances.
// The method is currently only used in gce.
func (an *Anchnet) AddSSHKeyToAllInstances(user string, keyData []byte) error {
	return errors.New("unimplemented")
}

// CurrentNodeName returns the name of the node we are currently running on. The
// method is used to determine nodename from hostname. Since we already override
// hostname to nodename, simply return hostname.
func (an *Anchnet) CurrentNodeName(hostname string) (string, error) {
	return hostname, nil
}

// describeInstance returns details of node from anchnet; 'name' is instance id,
// e.g. i-E7MPPDL7. Querying anchnet can fail unexpectly, so we need retry.
func (an *Anchnet) describeInstance(name string) (*anchnet_client.DescribeInstancesResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.DescribeInstancesRequest{
			InstanceIDs: []string{name},
			Verbose:     1,
		}
		var response anchnet_client.DescribeInstancesResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			if len(response.ItemSet) == 0 {
				return nil, fmt.Errorf("Instance %v doesn't exist\n", name)
			} else {
				return &response, nil
			}
		}
		glog.Errorf("Attemp %d: failed to send request for %v: %v\n", i, name, err)
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to find instance %v\n", name)
}

// searchInstances returns nodes matching search_word.
func (an *Anchnet) searchInstances(search_word string) (*anchnet_client.DescribeInstancesResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.DescribeInstancesRequest{
			SearchWord: search_word,
			// We must give 'running' status; otherwise, we may find terminated instance.
			Status: []anchnet_client.InstanceStatus{
				anchnet_client.InstanceStatusRunning,
			},
			Verbose: 1,
		}
		var response anchnet_client.DescribeInstancesResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			if len(response.ItemSet) == 0 {
				return nil, fmt.Errorf("Instance with name %v doesn't exist\n", search_word)
			} else {
				return &response, nil
			}
		}
		glog.Errorf("Attemp %d: failed to get instance with name %v: %v\n", i, search_word, err)
		time.Sleep(RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to find instance with name %v\n", search_word)
}
