/*
Copyright 2015 Caicloud All rights reserved.
*/

package anchang_cloud

import (
	"io"

	"github.com/GoogleCloudPlatform/kubernetes/pkg/api"
	"github.com/GoogleCloudPlatform/kubernetes/pkg/cloudprovider"
)

const ProviderName = "anchang"

type Anchang struct {
}

func init() {
	cloudprovider.RegisterCloudProvider(ProviderName, func(config io.Reader) (cloudprovider.Interface, error) { return newAnchang() })
}

// newAnchang returns a new instance of Anchang cloud provider.
func newAnchang() (cloudprovider.Interface, error) {
	return &Anchang{}, nil
}

// Following methods implement Cloudprovider.Interface. To make a cloud platform a
// kubernetes cloudprovider, it must implement the interface.
var _ cloudprovider.Interface = (*Anchang)(nil)

// TCPLoadBalancer returns an implementation of Interface.TCPLoadBalancer for Anchang cloud.
func (an *Anchang) TCPLoadBalancer() (cloudprovider.TCPLoadBalancer, bool) {
	return nil, false
}

// Instances returns an implementation of Interface.Instances for Anchang cloud.
func (an *Anchang) Instances() (cloudprovider.Instances, bool) {
	return an, true
}

// Zones returns an implementation of Interface.Zones for Anchang cloud.
func (an *Anchang) Zones() (cloudprovider.Zones, bool) {
	return nil, false
}

// Clusters returns an implementation of Interface.Clusters for Anchang cloud.
func (an *Anchang) Clusters() (cloudprovider.Clusters, bool) {
	return nil, false
}

// Routes returns an implementation of Interface.Routes for Anchang cloud.
func (an *Anchang) Routes() (cloudprovider.Routes, bool) {
	return nil, false
}

// ProviderName returns the cloud provider ID.
func (an *Anchang) ProviderName() string {
	return ProviderName
}

// Following methods implement Cloudprovider.Instances. Instances are used by kubernetes
// to get instance information; cloud provider must implement the interface.
var _ cloudprovider.Instances = (*Anchang)(nil)

// NodeAddresses returns an implementation of Instances.NodeAddresses.
func (an *Anchang) NodeAddresses(name string) ([]api.NodeAddress, error) {
	return nil, nil
}

// ExternalID returns the cloud provider ID of the specified instance (deprecated), implements Instances.ExternalID.
func (an *Anchang) ExternalID(name string) (string, error) {
	return "", nil
}

// InstanceID returns the cloud provider ID of the specified instance, implements Instances.InstanceID.
func (an *Anchang) InstanceID(name string) (string, error) {
	return "", nil
}

// List is an implementation of Instances.List.
func (an *Anchang) List(filter string) ([]string, error) {
	return nil, nil
}

// GetNodeResources implements Instances.GetNodeResources
func (an *Anchang) GetNodeResources(name string) (*api.NodeResources, error) {
	return nil, nil
}
