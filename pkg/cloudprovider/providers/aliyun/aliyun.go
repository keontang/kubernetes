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

const (
	ProviderName = "aliyun"
)

type LoadBalancerOpts struct {
	// internet | intranet, default: internet
	AddressType        slb.AddressType           `json:"addressType"`
	InternetChargeType common.InternetChargeType `json:"internetChargeType"`
	// Bandwidth peak of the public network instance charged per fixed bandwidth.
	// Value:1-1000(in Mbps), default: 1
	Bandwidth int `json:"bandwidth"`
}

type Config struct {
	Global struct {
		AccessKeyID     string `json:"accessKeyID"`
		AccessKeySecret string `json:"accessKeySecret"`
		RegionID        string `json:"regionID"`
	}
	LoadBalancer LoadBalancerOpts
}

// A single Kubernetes cluster can run in multiple zones,
// but only within the same region (and cloud provider).
type Aliyun struct {
	ecsClient *ecs.Client
	slbClient *slb.Client
	regionID  string
	lbOpts    LoadBalancerOpts
	// InstanceID of the server where this Aliyun object is instantiated.
	localInstanceID string
}

type LoadBalancer struct {
	aly *Aliyun
}

type Instances struct {
	aly *Aliyun
}

func init() {
	cloudprovider.RegisterCloudProvider(ProviderName, func(config io.Reader) (cloudprovider.Interface, error) {
		cfg, err := readConfig(config)
		if err != nil {
			return nil, err
		}
		return newAliyun(cfg)
	})
}

func readConfig(config io.Reader) (Config, error) {
	if config == nil {
		err := fmt.Errorf("No cloud provider config given")
		return Config{}, err
	}

	cfg := Config{}
	if err := json.NewDecoder(config).Decode(&cfg); err != nil {
		glog.Errorf("Couldn't parse config: %v", err)
		return Config{}, err
	}

	return cfg, nil
}

// newAliyun returns a new instance of Aliyun cloud provider.
func newAliyun(config Config) (cloudprovider.Interface, error) {
	ecsClient := ecs.NewClient(config.Global.AccessKeyID, config.Global.AccessKeySecret)
	slbClient := slb.NewClient(config.Global.AccessKeyID, config.Global.AccessKeySecret)

	// Get the local instance by it's hostname.
	hostname, err := os.Hostname()
	if err != nil {
		glog.Errorf("Error get os.Hostname: %v", err)
		return nil, err
	}

	glog.V(4).Infof("Get the local instance hostname: %s", hostname)

	args := ecs.DescribeInstancesArgs{
		RegionId:     common.Region(config.Global.RegionID),
		InstanceName: hostname,
	}
	instances, _, err := ecsClient.DescribeInstances(&args)
	if err != nil {
		glog.Errorf("Couldn't DescribeInstances(%v): %v", args, err)
		return nil, err
	}

	if len(instances) == 0 {
		return nil, fmt.Errorf("Couldn't get Instances by args '%v'", args)
	}

	if config.LoadBalancer.AddressType == "" {
		config.LoadBalancer.AddressType = slb.InternetAddressType
	}

	if config.LoadBalancer.InternetChargeType == "" {
		/* Valid value: paybytraffic|paybybandwidth
		 *  https://help.aliyun.com/document_detail/27577.html?spm=5176.product27537.6.118.R6Bqe6
		 *
		 * aliyun bug:
		 * We cloudn't use common.PayByBandwidth:
		 *     PayByBandwidth = InternetChargeType("PayByBandwidth"))
		 * but InternetChargeType("paybybandwidth")
		 */
		config.LoadBalancer.InternetChargeType = common.InternetChargeType("paybybandwidth")
	}

	if config.LoadBalancer.AddressType == slb.InternetAddressType && config.LoadBalancer.InternetChargeType == common.InternetChargeType("paybybandwidth") {
		if config.LoadBalancer.Bandwidth == 0 {
			config.LoadBalancer.Bandwidth = 1
		}

		if config.LoadBalancer.Bandwidth < 1 || config.LoadBalancer.Bandwidth > 1000 {
			return nil, fmt.Errorf("LoadBalancer.Bandwidth '%d' is out of range [1, 1000]", config.LoadBalancer.Bandwidth)
		}
	}

	aly := Aliyun{
		ecsClient:       ecsClient,
		slbClient:       slbClient,
		regionID:        config.Global.RegionID,
		lbOpts:          config.LoadBalancer,
		localInstanceID: instances[0].InstanceId,
	}

	glog.V(4).Infof("new Aliyun: '%v'", aly)

	return &aly, nil
}

func (aly *Aliyun) LoadBalancer() (cloudprovider.LoadBalancer, bool) {
	glog.V(4).Info("aliyun.LoadBalancer() called")
	return &LoadBalancer{aly}, true
}

// Instances returns an implementation of Interface.Instances for Aliyun cloud.
func (aly *Aliyun) Instances() (cloudprovider.Instances, bool) {
	glog.V(4).Info("aliyun.Instances() called")
	return &Instances{aly}, true
}

func (aly *Aliyun) Zones() (cloudprovider.Zones, bool) {
	return aly, true
}

func (aly *Aliyun) Clusters() (cloudprovider.Clusters, bool) {
	glog.V(4).Info("aliyun.Clusters() called")
	return nil, false
}

func (aly *Aliyun) Routes() (cloudprovider.Routes, bool) {
	return nil, false
}

func (aly *Aliyun) ProviderName() string {
	return ProviderName
}

// ScrubDNS filters DNS settings for pods.
func (aly *Aliyun) ScrubDNS(nameservers, searches []string) (nsOut, srchOut []string) {
	return nameservers, searches
}

func (aly *Aliyun) GetZone() (cloudprovider.Zone, error) {
	glog.V(1).Infof("Current zone is %v", aly.regionID)

	return cloudprovider.Zone{Region: aly.regionID}, nil
}

// NodeAddresses returns the addresses of the specified instance.
func (i *Instances) NodeAddresses(name string) ([]api.NodeAddress, error) {
	glog.V(4).Infof("NodeAddresses(%v) called", name)

	addrs, err := i.aly.getAddressesByName(name)
	if err != nil {
		glog.Errorf("Error getting node address by name '%s': %v", name, err)
		return nil, err
	}

	glog.V(4).Infof("NodeAddresses(%v) => %v", name, addrs)
	return addrs, nil
}

// ExternalID returns the cloud provider ID of the specified instance (deprecated).
func (i *Instances) ExternalID(name string) (string, error) {
	instanceID, err := i.aly.getInstanceIdByName(name)
	if err != nil {
		glog.Errorf("Error getting instanceID by name '%s': %v", name, err)
		return "", err
	}
	return instanceID, nil
}

// InstanceID returns the cloud provider ID of the specified instance.
// Note that if the instance does not exist or is no longer running, we must return ("", cloudprovider.InstanceNotFound)
func (i *Instances) InstanceID(name string) (string, error) {
	instanceID, err := i.aly.getInstanceIdByNameAndStatus(name, ecs.Running)
	if err != nil {
		glog.Errorf("Error getting instanceID by name '%s': %v", name, err)
		return "", cloudprovider.InstanceNotFound
	}
	return instanceID, nil
}

// InstanceType returns the type of the specified instance.
func (i *Instances) InstanceType(name string) (string, error) {
	return "", nil
}

// List lists instances that match 'filter' which is a regular expression which must match the entire instance name (fqdn)
func (i *Instances) List(name_filter string) ([]string, error) {
	instances, err := i.aly.getInstancesByNameFilter(name_filter)
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
func (i *Instances) AddSSHKeyToAllInstances(user string, keyData []byte) error {
	return errors.New("Unimplemented")
}

// CurrentNodeName returns the name of the node we are currently running on
// On most clouds (e.g. GCE) this is the hostname, so we provide the hostname
func (i *Instances) CurrentNodeName(hostname string) (string, error) {
	return hostname, nil
}

// GetLoadBalancer returns whether the specified load balancer exists, and
// if so, what its status is.
func (lb *LoadBalancer) GetLoadBalancer(name, region string) (status *api.LoadBalancerStatus, exists bool, err error) {
	if region != lb.aly.regionID {
		return nil, false, fmt.Errorf("Requested load balancer region '%s' does not match cluster region '%s'", region, lb.aly.regionID)
	}

	loadbalancer, exists, err := lb.aly.getLoadBalancerByName(name)
	if err != nil {
		return nil, false, fmt.Errorf("Couldn't get load balancer by name '%s' in region '%s': %v", name, lb.aly.regionID, err)
	}

	glog.V(4).Infof("GetLoadBalancer(%s, %s): %v", name, region, loadbalancer)

	if !exists {
		glog.Infof("Couldn't find the loadbalancer with the name '%v' in the region '%v'", name, region)
		return nil, false, nil
	}

	status = &api.LoadBalancerStatus{}
	status.Ingress = []api.LoadBalancerIngress{{IP: loadbalancer.Address}}

	return status, true, nil
}

// EnsureLoadBalancer creates a new load balancer 'name', or updates the existing one. Returns the status of the balancer
// To create a LoadBalancer for kubernetes, we do the following:
// 1. create a aliyun SLB loadbalancer;
// 2. create listeners for the new loadbalancer, number of listeners = number of service ports;
// 3. add backends to the new loadbalancer.
func (lb *LoadBalancer) EnsureLoadBalancer(name, region string, loadBalancerIP net.IP, ports []*api.ServicePort, hosts []string, serviceName types.NamespacedName, affinityType api.ServiceAffinity, annotations map[string]string) (*api.LoadBalancerStatus, error) {
	if region != lb.aly.regionID {
		return nil, fmt.Errorf("Requested load balancer region '%s' does not match cluster region '%s'", region, lb.aly.regionID)
	}

	glog.V(2).Infof("EnsureLoadBalancer(%v, %v, %v, %v, %v, %v, %v)", name, region, loadBalancerIP, ports, hosts, serviceName, annotations)

	if affinityType != api.ServiceAffinityNone {
		// Aliyun supports sticky sessions, but only when configured for HTTP/HTTPS (cookies based).
		// But Kubernetes Services support TCP and UDP for protocols.
		// Although session affinity is calculated in kube-proxy, where it determines which pod to
		// response a request, we still need to hit the same kube-proxy (the node). Other kube-proxy
		// do not have the knowledge.
		return nil, fmt.Errorf("Unsupported load balancer affinity: %v", affinityType)
	}

	// Aliyun does not support user-specified ip addr for LB. We just
	// print some log and ignore the public ip.
	if loadBalancerIP != nil {
		glog.Warning("Public IP cannot be specified for aliyun SLB")
	}

	glog.V(2).Infof("Checking if aliyun load balancer already exists: %s", name)
	_, exists, err := lb.GetLoadBalancer(name, region)
	if err != nil {
		return nil, fmt.Errorf("Error checking if aliyun load balancer already exists: %v", err)
	}

	// TODO: Implement a more efficient update strategy for common changes than delete & create
	// In particular, if we implement hosts update, we can get rid of UpdateHosts
	if exists {
		err := lb.EnsureLoadBalancerDeleted(name, region)
		if err != nil {
			return nil, fmt.Errorf("Error deleting existing aliyun load balancer: %v", err)
		}

		glog.V(2).Infof("Deleted loadbalancer '%s' before creating in region '%s'", name, region)
	}

	lb_response, err := lb.aly.createLoadBalancer(name)
	if err != nil {
		glog.Errorf("Error creating loadbalancer '%s': %v", name, err)
		return nil, err
	}

	glog.Infof("Create loadbalancer '%s' in region '%s'", name, region)

	// For the public network instance charged per fixed bandwidth
	// the sum of bandwidth peaks allocated to different Listeners
	// cannot exceed the Bandwidth value set when creating the
	// Server Load Balancer instance, and the Bandwidth value on Listener
	// cannot be set to -1
	//
	// For the public network instance charged per traffic consumed,
	// the Bandwidth on Listener can be set to -1, indicating the
	// bandwidth peak is unlimited.
	bandwidth := -1
	if len(ports) > 0 && lb.aly.lbOpts.AddressType == slb.InternetAddressType && lb.aly.lbOpts.InternetChargeType == common.InternetChargeType("paybybandwidth") {
		bandwidth = lb.aly.lbOpts.Bandwidth / len(ports)
	}

	// For every port, we need a listener.
	for _, port := range ports {
		glog.V(4).Infof("Create a listener for port: %v", port)

		if port.Protocol == api.ProtocolTCP {
			err := lb.aly.createLoadBalancerTCPListener(lb_response.LoadBalancerId, port, bandwidth)
			if err != nil {
				glog.Errorf("Error create loadbalancer TCP listener (LoadBalancerId:'%s', Port: '%v', Bandwidth: '%d'): %v", lb_response.LoadBalancerId, port, bandwidth, err)
				return nil, err
			}
			glog.Infof("Created LoadBalancerTCPListener (LoadBalancerId:'%s', Port: '%v', Bandwidth: '%d')", lb_response.LoadBalancerId, port, bandwidth)
		} else if port.Protocol == api.ProtocolUDP {
			err := lb.aly.createLoadBalancerUDPListener(lb_response.LoadBalancerId, port, bandwidth)
			if err != nil {
				glog.Errorf("Error create loadbalancer UDP listener (LoadBalancerId:'%s', Port: '%v', Bandwidth: '%d'): %v", lb_response.LoadBalancerId, port, bandwidth, err)
				return nil, err
			}
			glog.Infof("Created LoadBalancerUDPListener (LoadBalancerId:'%s', Port: '%v', Bandwidth: '%d')", lb_response.LoadBalancerId, port, bandwidth)
		}
	}

	instanceIDs := []string{}
	for _, hostname := range hosts {
		instanceID, err := lb.aly.getInstanceIdByName(hostname)
		if err != nil {
			return nil, fmt.Errorf("Error getting instanceID by hostname(%v): %v", hostname, err)
		}
		instanceIDs = append(instanceIDs, instanceID)
	}

	err = lb.aly.addBackendServers(lb_response.LoadBalancerId, instanceIDs)
	if err != nil {
		glog.Errorf("Couldn't add backend servers '%v' to loadbalancer '%v': %v", instanceIDs, name, err)
		return nil, err
	}

	glog.V(4).Infof("Added backend servers '%v' to loadbalancer '%s'", instanceIDs, name)

	err = lb.aly.setLoadBalancerStatus(lb_response.LoadBalancerId, slb.ActiveStatus)
	if err != nil {
		glog.Errorf("Couldn't activate loadbalancer '%v'", lb_response.LoadBalancerId)
		return nil, err
	}

	status := &api.LoadBalancerStatus{}
	status.Ingress = []api.LoadBalancerIngress{{IP: lb_response.Address}}

	glog.Infof("Activated loadbalancer '%v', ingress ip '%v'", name, lb_response.Address)

	return status, nil
}

// UpdateLoadBalancer updates hosts under the specified load balancer.
func (lb *LoadBalancer) UpdateLoadBalancer(name, region string, hosts []string) error {
	if region != lb.aly.regionID {
		return fmt.Errorf("Requested load balancer region '%s' does not match cluster region '%s'", region, lb.aly.regionID)
	}

	loadbalancer, exists, err := lb.aly.getLoadBalancerByName(name)
	if err != nil {
		return fmt.Errorf("Couldn't get load balancer by name '%s' in region '%s': %v", name, lb.aly.regionID, err)
	}

	if !exists {
		return fmt.Errorf("Couldn't find load balancer by name '%s' in region '%s'", name, lb.aly.regionID)
	}

	// Expected instances for the load balancer.
	expected := sets.NewString()
	for _, hostname := range hosts {
		id, err := lb.aly.getInstanceIdByName(hostname)
		if err != nil {
			glog.Errorf("Couldn't get InstanceID by name '%v' in region '%v': %v", hostname, region, err)
			return err
		}
		expected.Insert(id)
	}

	// Actual instances of the load balancer.
	actual := sets.NewString()
	lb_attribute, err := lb.aly.getLoadBalancerAttribute(loadbalancer.LoadBalancerId)
	if err != nil {
		glog.Errorf("Couldn't get loadbalancer '%v' attribute: %v", name, err)
		return err
	}
	for _, backendserver := range lb_attribute.BackendServers.BackendServer {
		actual.Insert(backendserver.ServerId)
	}

	addInstances := expected.Difference(actual)
	removeInstances := actual.Difference(expected)

	glog.V(4).Infof("For the loadbalancer, expected instances: %v, actual instances: %v, need to remove instances: %v, need to add instances: %v", expected, actual, removeInstances, addInstances)

	if len(addInstances) > 0 {
		instanceIDs := addInstances.List()
		err := lb.aly.addBackendServers(loadbalancer.LoadBalancerId, instanceIDs)
		if err != nil {
			glog.Errorf("Couldn't add backend servers '%v' to loadbalancer '%v': %v", instanceIDs, name)
			return err
		}
		glog.V(1).Infof("Instances '%v' added to loadbalancer %s", instanceIDs, name)
	}

	if len(removeInstances) > 0 {
		instanceIDs := removeInstances.List()
		err := lb.aly.removeBackendServers(loadbalancer.LoadBalancerId, instanceIDs)
		if err != nil {
			glog.Errorf("Couldn't remove backend servers '%v' from loadbalancer '%v': %v", instanceIDs, name)
			return err
		}
		glog.V(1).Infof("Instances '%v' removed from loadbalancer %s", instanceIDs, name)
	}

	return nil
}

// EnsureLoadBalancerDeleted deletes the specified load balancer if it
// exists, returning nil if the load balancer specified either didn't exist or
// was successfully deleted.
// This construction is useful because many cloud providers' load balancers
// have multiple underlying components, meaning a Get could say that the LB
// doesn't exist even if some part of it is still laying around.
func (lb *LoadBalancer) EnsureLoadBalancerDeleted(name, region string) error {
	if region != lb.aly.regionID {
		return fmt.Errorf("Requested load balancer region '%s' does not match cluster region '%s'", region, lb.aly.regionID)
	}

	loadbalancer, exists, err := lb.aly.getLoadBalancerByName(name)
	if err != nil {
		return fmt.Errorf("Couldn't get load balancer by name '%s' in region '%s': %v", name, lb.aly.regionID, err)
	}

	if !exists {
		glog.Infof(" Loadbalancer '%s', already deleted in region '%s'", name, lb.aly.regionID)
		return nil
	}

	err = lb.aly.deleteLoadBalancer(loadbalancer.LoadBalancerId)
	if err != nil {
		return fmt.Errorf("Error deleting load balancer by name '%s' in region '%s': %v", name, lb.aly.regionID, err)
	}

	glog.Infof("Delete loadbalancer '%s' in region '%s'", name, region)

	return nil
}

// getAddressesByName return an instance address slice by it's name.
func (aly *Aliyun) getAddressesByName(name string) ([]api.NodeAddress, error) {
	instance, err := aly.getInstanceByName(name)
	if err != nil {
		glog.Errorf("Error getting instance by name '%s': %v", name, err)
		return nil, err
	}

	addrs := []api.NodeAddress{}

	if len(instance.PublicIpAddress.IpAddress) > 0 {
		for _, ipaddr := range instance.PublicIpAddress.IpAddress {
			addrs = append(addrs, api.NodeAddress{Type: api.NodeExternalIP, Address: ipaddr})
		}
	}

	if instance.EipAddress.IpAddress != "" {
		addrs = append(addrs, api.NodeAddress{Type: api.NodeExternalIP, Address: instance.EipAddress.IpAddress})
	}

	if len(instance.InnerIpAddress.IpAddress) > 0 {
		for _, ipaddr := range instance.InnerIpAddress.IpAddress {
			addrs = append(addrs, api.NodeAddress{Type: api.NodeInternalIP, Address: ipaddr})
		}
	}

	if len(instance.VpcAttributes.PrivateIpAddress.IpAddress) > 0 {
		for _, ipaddr := range instance.VpcAttributes.PrivateIpAddress.IpAddress {
			addrs = append(addrs, api.NodeAddress{Type: api.NodeInternalIP, Address: ipaddr})
		}
	}

	if instance.VpcAttributes.NatIpAddress != "" {
		addrs = append(addrs, api.NodeAddress{Type: api.NodeInternalIP, Address: instance.VpcAttributes.NatIpAddress})
	}

	return addrs, nil
}

func (aly *Aliyun) getInstanceByNameAndStatus(name string, status ecs.InstanceStatus) (*ecs.InstanceAttributesType, error) {
	args := ecs.DescribeInstancesArgs{
		RegionId:     common.Region(aly.regionID),
		InstanceName: name,
		Status:       status,
	}

	instances, _, err := aly.ecsClient.DescribeInstances(&args)
	if err != nil {
		glog.Errorf("Couldn't DescribeInstances(%v): %v", args, err)
		return nil, err
	}

	if len(instances) == 0 {
		return nil, fmt.Errorf("Couldn't get Instances by args '%v'", args)
	}

	return &instances[0], nil
}

func (aly *Aliyun) getInstanceByName(name string) (*ecs.InstanceAttributesType, error) {
	instances, err := aly.getInstancesByNameFilter(name)
	if err != nil {
		glog.Errorf("Error get instances by name_filter '%s': %v", name, err)
		return nil, err
	}

	return &instances[0], nil
}

func (aly *Aliyun) getInstancesByNameFilter(name_filter string) ([]ecs.InstanceAttributesType, error) {
	args := ecs.DescribeInstancesArgs{
		RegionId:     common.Region(aly.regionID),
		InstanceName: name_filter,
	}

	instances, _, err := aly.ecsClient.DescribeInstances(&args)
	if err != nil {
		glog.Errorf("Couldn't DescribeInstances(%v): %v", args, err)
		return nil, err
	}

	if len(instances) == 0 {
		return nil, fmt.Errorf("Couldn't get Instances by args '%v'", args)
	}

	return instances, nil
}

func (aly *Aliyun) getInstanceIdByNameAndStatus(name string, status ecs.InstanceStatus) (string, error) {
	instance, err := aly.getInstanceByNameAndStatus(name, status)
	if err != nil {
		return "", err
	}
	return instance.InstanceId, nil
}

func (aly *Aliyun) getInstanceIdByName(name string) (string, error) {
	instance, err := aly.getInstanceByName(name)
	if err != nil {
		return "", err
	}
	return instance.InstanceId, nil
}

func (aly *Aliyun) createLoadBalancer(name string) (response *slb.CreateLoadBalancerResponse, err error) {
	args := slb.CreateLoadBalancerArgs{
		RegionId:           common.Region(aly.regionID),
		LoadBalancerName:   name,
		AddressType:        aly.lbOpts.AddressType,
		InternetChargeType: aly.lbOpts.InternetChargeType,
		Bandwidth:          aly.lbOpts.Bandwidth,
	}
	response, err = aly.slbClient.CreateLoadBalancer(&args)
	if err != nil {
		glog.Errorf("Couldn't CreateLoadBalancer(%v): %v", args, err)
		return nil, err
	}

	glog.V(4).Infof("CreateLoadBalancer(%v): %v", args, response)

	return response, nil
}

func (aly *Aliyun) deleteLoadBalancer(loadBalancerID string) error {
	return aly.slbClient.DeleteLoadBalancer(loadBalancerID)
}

// Add backend servers to the specified load balancer.
func (aly *Aliyun) addBackendServers(loadbalancerID string, instanceIDs []string) error {
	backendServers := []slb.BackendServerType{}
	for index, instanceID := range instanceIDs {
		backendServers = append(backendServers,
			slb.BackendServerType{
				ServerId: instanceID,
				Weight:   100,
			},
		)

		// For AddBackendServer, The maximum number of elements in backendServers List is 20.
		if index%20 == 19 {
			_, err := aly.slbClient.AddBackendServers(loadbalancerID, backendServers)
			if err != nil {
				glog.Errorf("Couldn't AddBackendServers(%v, %v): %v", loadbalancerID, backendServers, err)
				return err
			}
			backendServers = backendServers[0:0]
		}
	}

	_, err := aly.slbClient.AddBackendServers(loadbalancerID, backendServers)
	if err != nil {
		glog.Errorf("Couldn't AddBackendServers(%v, %v): %v", loadbalancerID, backendServers, err)
		return err
	}

	glog.V(4).Infof("AddBackendServers(%v, %v)", loadbalancerID, backendServers)

	return nil
}

// Remove backend servers from the specified load balancer.
func (aly *Aliyun) removeBackendServers(loadBalancerID string, instanceIDs []string) error {
	_, err := aly.slbClient.RemoveBackendServers(loadBalancerID, instanceIDs)
	if err != nil {
		glog.Errorf("Couldn't RemoveBackendServers(%v, %v): %v", loadBalancerID, instanceIDs, err)
		return err
	}

	return nil
}

func (aly *Aliyun) createLoadBalancerTCPListener(loadBalancerID string, port *api.ServicePort, bandwidth int) error {
	args := slb.CreateLoadBalancerTCPListenerArgs{
		LoadBalancerId:    loadBalancerID,
		ListenerPort:      port.Port,
		BackendServerPort: port.NodePort,
		// Bandwidth peak of Listener Value: -1 | 1 - 1000 Mbps, default is -1.
		Bandwidth: bandwidth,
	}
	return aly.slbClient.CreateLoadBalancerTCPListener(&args)
}

func (aly *Aliyun) createLoadBalancerUDPListener(loadBalancerID string, port *api.ServicePort, bandwidth int) error {
	args := slb.CreateLoadBalancerUDPListenerArgs{
		LoadBalancerId:    loadBalancerID,
		ListenerPort:      port.Port,
		BackendServerPort: port.NodePort,
		Bandwidth:         bandwidth,
	}
	return aly.slbClient.CreateLoadBalancerUDPListener(&args)
}

func (aly *Aliyun) getLoadBalancerByName(name string) (loadbalancer *slb.LoadBalancerType, exists bool, err error) {
	// Find all the loadbalancers in the current region.
	args := slb.DescribeLoadBalancersArgs{
		RegionId: common.Region(aly.regionID),
	}
	loadbalancers, err := aly.slbClient.DescribeLoadBalancers(&args)
	if err != nil {
		glog.Errorf("Couldn't DescribeLoadBalancers(%v): %v", args, err)
		return nil, false, err
	}
	glog.V(4).Infof("getLoadBalancerByName(%s) in region '%s': %v", name, aly.regionID, loadbalancers)

	// Find the specified load balancer with the matching name
	for _, lb := range loadbalancers {
		if lb.LoadBalancerName == name {
			glog.V(4).Infof("Find loadbalancer(%s) in region '%s'", name, aly.regionID)
			return &lb, true, nil
		}
	}

	glog.Infof("Couldn't find loadbalancer by name '%s'", name)

	return nil, false, nil
}

func (aly *Aliyun) getLoadBalancerAttribute(loadBalancerID string) (loadbalancer *slb.LoadBalancerType, err error) {
	loadbalancer, err = aly.slbClient.DescribeLoadBalancerAttribute(loadBalancerID)
	if err != nil {
		glog.Errorf("Couldn't DescribeLoadBalancerAttribute(%s): %v", loadBalancerID, err)
		return nil, err
	}

	return loadbalancer, nil
}

func (aly *Aliyun) setLoadBalancerStatus(loadBalancerID string, status slb.Status) (err error) {
	return aly.slbClient.SetLoadBalancerStatus(loadBalancerID, status)
}
