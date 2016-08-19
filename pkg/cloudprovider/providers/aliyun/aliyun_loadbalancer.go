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

// GetLoadBalancer returns whether the specified load balancer exists, and
// if so, what its status is.
func (aly *Aliyun) GetLoadBalancer(name, region string) (status *api.LoadBalancerStatus, exists bool, err error) {
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
func (aly *Aliyun) EnsureLoadBalancer(name, region string, loadBalancerIP net.IP, ports []*api.ServicePort, hosts []string, serviceName types.NamespacedName, affinityType api.ServiceAffinity, annotations map[string]string) (*api.LoadBalancerStatus, error) {
	if region != aly.regionID {
		return nil, fmt.Errorf("Requested load balancer region '%s' does not match cluster region '%s'", region, aly.regionID)
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

	lb_response, err := aly.createLoadBalancer(name)
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
	if len(ports) > 0 && aly.lbOpts.AddressType == slb.InternetAddressType && aly.lbOpts.InternetChargeType == common.InternetChargeType("paybybandwidth") {
		bandwidth = aly.lbOpts.Bandwidth / len(ports)
	}

	// For every port, we need a listener.
	for _, port := range ports {
		glog.V(4).Infof("Create a listener for port: %v", port)

		if port.Protocol == api.ProtocolTCP {
			err := aly.createLoadBalancerTCPListener(lb_response.LoadBalancerId, port, bandwidth)
			if err != nil {
				glog.Errorf("Error create loadbalancer TCP listener (LoadBalancerId:'%s', Port: '%v', Bandwidth: '%d'): %v", lb_response.LoadBalancerId, port, bandwidth, err)
				return nil, err
			}
			glog.Infof("Created LoadBalancerTCPListener (LoadBalancerId:'%s', Port: '%v', Bandwidth: '%d')", lb_response.LoadBalancerId, port, bandwidth)
		} else if port.Protocol == api.ProtocolUDP {
			err := aly.createLoadBalancerUDPListener(lb_response.LoadBalancerId, port, bandwidth)
			if err != nil {
				glog.Errorf("Error create loadbalancer UDP listener (LoadBalancerId:'%s', Port: '%v', Bandwidth: '%d'): %v", lb_response.LoadBalancerId, port, bandwidth, err)
				return nil, err
			}
			glog.Infof("Created LoadBalancerUDPListener (LoadBalancerId:'%s', Port: '%v', Bandwidth: '%d')", lb_response.LoadBalancerId, port, bandwidth)
		}
	}

	instanceIDs := []string{}
	for _, hostname := range hosts {
		instanceID, err := aly.getInstanceIdByName(hostname)
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

	err = aly.setLoadBalancerStatus(lb_response.LoadBalancerId, slb.ActiveStatus)
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
func (aly *Aliyun) UpdateLoadBalancer(name, region string, hosts []string) error {
	if region != aly.regionID {
		return fmt.Errorf("Requested load balancer region '%s' does not match cluster region '%s'", region, aly.regionID)
	}

	loadbalancer, exists, err := aly.getLoadBalancerByName(name)
	if err != nil {
		return fmt.Errorf("Couldn't get load balancer by name '%s' in region '%s': %v", name, aly.regionID, err)
	}

	if !exists {
		return fmt.Errorf("Couldn't find load balancer by name '%s' in region '%s'", name, aly.regionID)
	}

	// Expected instances for the load balancer.
	expected := sets.NewString()
	for _, hostname := range hosts {
		id, err := aly.getInstanceIdByName(hostname)
		if err != nil {
			glog.Errorf("Couldn't get InstanceID by name '%v' in region '%v': %v", hostname, region, err)
			return err
		}
		expected.Insert(id)
	}

	// Actual instances of the load balancer.
	actual := sets.NewString()
	lb_attribute, err := aly.getLoadBalancerAttribute(loadbalancer.LoadBalancerId)
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
		err := aly.addBackendServers(loadbalancer.LoadBalancerId, instanceIDs)
		if err != nil {
			glog.Errorf("Couldn't add backend servers '%v' to loadbalancer '%v': %v", instanceIDs, name)
			return err
		}
		glog.V(1).Infof("Instances '%v' added to loadbalancer %s", instanceIDs, name)
	}

	if len(removeInstances) > 0 {
		instanceIDs := removeInstances.List()
		err := aly.removeBackendServers(loadbalancer.LoadBalancerId, instanceIDs)
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
func (aly *Aliyun) EnsureLoadBalancerDeleted(name, region string) error {
	if region != aly.regionID {
		return fmt.Errorf("Requested load balancer region '%s' does not match cluster region '%s'", region, lb.aly.regionID)
	}

	loadbalancer, exists, err := aly.getLoadBalancerByName(name)
	if err != nil {
		return fmt.Errorf("Couldn't get load balancer by name '%s' in region '%s': %v", name, lb.aly.regionID, err)
	}

	if !exists {
		glog.Infof(" Loadbalancer '%s', already deleted in region '%s'", name, aly.regionID)
		return nil
	}

	err = aly.deleteLoadBalancer(loadbalancer.LoadBalancerId)
	if err != nil {
		return fmt.Errorf("Error deleting load balancer by name '%s' in region '%s': %v", name, aly.regionID, err)
	}

	glog.Infof("Delete loadbalancer '%s' in region '%s'", name, region)

	return nil
}
