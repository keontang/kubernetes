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
	"encoding/json"
	"fmt"
	"io"
	"time"

	"k8s.io/kubernetes/pkg/api"
	"k8s.io/kubernetes/pkg/client/cache"
	"k8s.io/kubernetes/pkg/cloudprovider"

	anchnet_client "github.com/caicloud/anchnet-go"
)

const (
	ProviderName = "anchnet"

	// Number of retries when getting errors while accessing anchnet, e.g.
	// request too frequent.
	RetryCountOnError = 5
	// Initial interval between two retries for the above situation. Following
	// retry interval will be doubled.
	RetryIntervalOnError = 2 * time.Second

	// Number of retries when waitting on resources to become desired status.
	RetryCountOnWait = 120
	// Initial interval between two retries for the above situation. Following
	// retry interval will be doubled.
	RetryIntervalOnWait = 3 * time.Second

	// TTL for API call cache.
	cacheTTL = 6 * time.Hour
)

// Anchnet is the implementation of kubernetes cloud plugin.
type Anchnet struct {
	// Anchnet SDK client.
	client *anchnet_client.Client

	// An address cache used to cache NodeAddresses.
	addressCache cache.Store
}

// An entry in addressCache.
type AddressCacheEntry struct {
	name      string
	addresses []api.NodeAddress
}

func init() {
	cloudprovider.RegisterCloudProvider(ProviderName, func(config io.Reader) (cloudprovider.Interface, error) { return newAnchnet(config) })
}

// newAnchnet returns a new instance of Anchnet cloud provider.
func newAnchnet(config io.Reader) (cloudprovider.Interface, error) {
	var auth anchnet_client.AuthConfiguration
	if err := json.NewDecoder(config).Decode(&auth); err != nil {
		return nil, err
	}
	client, err := anchnet_client.NewClient(anchnet_client.DefaultEndpoint, &auth)
	if err != nil {
		return nil, err
	}
	keyFunc := func(obj interface{}) (string, error) {
		entry, ok := obj.(AddressCacheEntry)
		if !ok {
			return "", cache.KeyError{Obj: obj, Err: fmt.Errorf("Unable to convert entry object to AddressCacheEntry")}
		}
		return entry.name, nil
	}
	return &Anchnet{
		client:       client,
		addressCache: cache.NewTTLStore(keyFunc, cacheTTL),
	}, nil
}

//
// Following methods implement Cloudprovider.Interface. To make a cloud platform a
// kubernetes cloudprovider, it must implement the interface.
//
var _ cloudprovider.Interface = (*Anchnet)(nil)

// TCPLoadBalancer returns an implementation of Interface.TCPLoadBalancer for Anchnet cloud.
func (an *Anchnet) TCPLoadBalancer() (cloudprovider.TCPLoadBalancer, bool) {
	return an, true
}

// Instances returns an implementation of Interface.Instances for Anchnet cloud.
func (an *Anchnet) Instances() (cloudprovider.Instances, bool) {
	return an, true
}

// Zones returns an implementation of Interface.Zones for Anchnet cloud.
// This interface is used in servicecontroller to create load balancer. Zone
// information is passed to TCPLoadBalancer interface directly so kubernetes
// itself doesn't depend on Zones.
func (an *Anchnet) Zones() (cloudprovider.Zones, bool) {
	return an, true
}

// Clusters returns an implementation of Interface.Clusters for Anchnet cloud.
// This interface doesn't seem to be used in kubernetes, and a lot cloudproviders
// do not implement it, so we ignore it for now.
func (an *Anchnet) Clusters() (cloudprovider.Clusters, bool) {
	return nil, false
}

// Routes returns an implementation of Interface.Routes for Anchnet cloud.
// This interface is used in routecontroller to make sure Node has correct CIDR.
// In GCE, every node is assigned a CIDR, e.g. 10.200.10.0/24. This range will
// be used to create Pod IPs; therefore, each machine has a virtual container
// network. Anchnet doesn't support route configuration, and we use flannel to
// implement this CIDR, so we don't support the interface.
func (an *Anchnet) Routes() (cloudprovider.Routes, bool) {
	return nil, false
}

// ScrubDNS filters DNS settings for pods.
func (an *Anchnet) ScrubDNS(nameservers, searches []string) (nsOut, srchOut []string) {
	return nameservers, searches
}

// ProviderName returns the cloud provider ID.
func (an *Anchnet) ProviderName() string {
	return ProviderName
}

type VolumeOptions struct {
	CapacityMB int
}

// Volumes is an interface for managing cloud-provisioned volumes.
type Volumes interface {
	// AttachDisk attaches the disk to the specified instance. `instanceID` can be empty
	// to mean "the instance on which we are running".
	// Returns the device path (e.g. /dev/xvdf) where we attached the volume.
	AttachDisk(instanceID string, volumeID string, readOnly bool) (string, error)
	// DetachDisk detaches the disk from the specified instance. `instanceID` can be empty
	// to mean "the instance on which we are running"
	DetachDisk(instanceID string, volumeID string) error

	// Create a volume with the specified options.
	CreateVolume(volumeOptions *VolumeOptions) (volumeID string, err error)
	// Delete a volume.
	DeleteVolume(volumeID string) error
}
