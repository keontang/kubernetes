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
	"strings"
	"time"
	"unicode"

	"github.com/GoogleCloudPlatform/kubernetes/pkg/api"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/api/resource"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/cloudprovider"

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
	response, err := an.describeInstance(name)
	if err != nil {
		return nil, err
	}
	// TODO: Get internal IP address as well (private SDN).
	addresses := []api.NodeAddress{
		{Type: api.NodeExternalIP, Address: response.ItemSet[0].EIP.EipAddr},
	}
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
// e.g. i-E7MPPDL7.  Querying anchnet can fail unexpectly, so we need retry.
func (an *Anchnet) describeInstance(name string) (*anchnet_client.DescribeInstancesResponse, error) {
	for i := 0; i < 5; i++ {
		request := anchnet_client.DescribeInstancesRequest{
			Instances:  []string{name},
			Verbose:    1,
			Offset:     0,
			SearchWord: "",
			Limit:      1,
		}
		response, err := an.client.DescribeInstances(request)
		if err != nil {
			return nil, err
		}
		if len(response.ItemSet) != 0 {
			return response, nil
		}
		fmt.Printf("Attemp %d: no response for %v\n", i, name)
		time.Sleep(2 * time.Second)
	}
	return nil, errors.New("Not Found")
}

// searchInstances returns nodes matching search_word.
func (an *Anchnet) searchInstances(search_word string) (*anchnet_client.DescribeInstancesResponse, error) {
	request := anchnet_client.DescribeInstancesRequest{
		Verbose:    1,
		SearchWord: search_word,
		Status:     []string{"running"},
	}
	return an.client.DescribeInstances(request)
}

// makeResources converts bare resources to api spec'd resource, cpu is in cores, memory is in GiB.
func makeResources(cpu, memory int) *api.NodeResources {
	return &api.NodeResources{
		Capacity: api.ResourceList{
			api.ResourceCPU:    *resource.NewMilliQuantity(int64(cpu*1000), resource.DecimalSI),
			api.ResourceMemory: *resource.NewQuantity(int64(memory*1024*1024*1024), resource.BinarySI),
		},
	}
}

// convertToInstanceID converts name to anchnet instance ID, e.g.
//   i-ff830wku->i-FF830WKU, i-FF830WKU->i-FF830WKU.
func convertToInstanceID(name string) string {
	s := strings.ToUpper(name)
	a := []rune(s)
	a[0] = unicode.ToLower(a[0])
	return string(a)
}
