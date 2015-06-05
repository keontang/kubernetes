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
	"io"

	"github.com/GoogleCloudPlatform/kubernetes/pkg/api"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/cloudprovider"
)

const ProviderName = "anchnet"

type Anchnet struct {
}

func init() {
	cloudprovider.RegisterCloudProvider(ProviderName, func(config io.Reader) (cloudprovider.Interface, error) { return newAnchnet() })
}

// newAnchnet returns a new instance of Anchnet cloud provider.
func newAnchnet() (cloudprovider.Interface, error) {
	return &Anchnet{}, nil
}

// Following methods implement Cloudprovider.Interface. To make a cloud platform a
// kubernetes cloudprovider, it must implement the interface.
var _ cloudprovider.Interface = (*Anchnet)(nil)

// TCPLoadBalancer returns an implementation of Interface.TCPLoadBalancer for Anchnet cloud.
func (an *Anchnet) TCPLoadBalancer() (cloudprovider.TCPLoadBalancer, bool) {
	return nil, false
}

// Instances returns an implementation of Interface.Instances for Anchnet cloud.
func (an *Anchnet) Instances() (cloudprovider.Instances, bool) {
	return an, true
}

// Zones returns an implementation of Interface.Zones for Anchnet cloud.
func (an *Anchnet) Zones() (cloudprovider.Zones, bool) {
	return nil, false
}

// Clusters returns an implementation of Interface.Clusters for Anchnet cloud.
func (an *Anchnet) Clusters() (cloudprovider.Clusters, bool) {
	return nil, false
}

// Routes returns an implementation of Interface.Routes for Anchnet cloud.
func (an *Anchnet) Routes() (cloudprovider.Routes, bool) {
	return nil, false
}

// ProviderName returns the cloud provider ID.
func (an *Anchnet) ProviderName() string {
	return ProviderName
}

// Following methods implement Cloudprovider.Instances. Instances are used by kubernetes
// to get instance information; cloud provider must implement the interface.
var _ cloudprovider.Instances = (*Anchnet)(nil)

// NodeAddresses returns an implementation of Instances.NodeAddresses.
func (an *Anchnet) NodeAddresses(name string) ([]api.NodeAddress, error) {
	return nil, nil
}

// ExternalID returns the cloud provider ID of the specified instance (deprecated), implements Instances.ExternalID.
func (an *Anchnet) ExternalID(name string) (string, error) {
	return "", nil
}

// InstanceID returns the cloud provider ID of the specified instance, implements Instances.InstanceID.
func (an *Anchnet) InstanceID(name string) (string, error) {
	return "", nil
}

// List is an implementation of Instances.List.
func (an *Anchnet) List(filter string) ([]string, error) {
	return nil, nil
}

// GetNodeResources implements Instances.GetNodeResources
func (an *Anchnet) GetNodeResources(name string) (*api.NodeResources, error) {
	return nil, nil
}
