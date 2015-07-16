// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet loadbalancer related APIs, except loadbalancer policy related.

//
// DescribeLoadBalancers retrieves information of a list of loadbalancers.
//
type DescribeLoadBalancersRequest struct {
	RequestCommon   `json:",inline"`
	LoadbalancerIDs []string             `json:"loadbalancers,omitempty"`
	SearchWord      string               `json:"search_word,omitempty"`
	Status          []LoadBalancerStatus `json:"status,omitempty"`
	Verbose         int                  `json:"verbose,omitempty"`
	Offset          int                  `json:"offset,omitempty"`
	Limit           int                  `json:"limit,omitempty"`
}

type DescribeLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                         `json:"total_count,omitempty"`
	ItemSet        []DescribeLoadBalancersItem `json:"item_set,omitempty"`
}

type DescribeLoadBalancersItem struct {
	LoadbalancerID   string                             `json:"loadbalancer_id,omitempty"`
	LoadbalancerName string                             `json:"loadbalancer_name,omitempty"`
	LoadbalancerType LoadBalancerType                   `json:"loadbalancer_type,omitempty"`
	Description      string                             `json:"description,omitempty"`
	CreateTime       string                             `json:"create_time,omitempty"`
	StatusTime       string                             `json:"status_time,omitempty"`
	IsApplied        LoadBalancerApply                  `json:"is_applied,omitempty"`
	Status           LoadBalancerStatus                 `json:"status,omitempty"`
	Eips             []DescribeLoadBalancersEIP         `json:"eips,omitempty"`
	Listeners        []DescribeLoadBalancersListener    `json:"listeners,omitempty"`
	SecurityGroup    DescribeLoadBalancersSecurityGroup `json:"security_group,omitempty"`
}

type DescribeLoadBalancersEIP struct {
	EipID   string `json:"eip_id,omitempty"`
	EipName string `json:"eip_name,omitempty"`
	EipAddr string `json:"eip_addr,omitempty"`
}

type DescribeLoadBalancersSecurityGroup struct {
	Attachon          int    `json:"attachon,omitempty"`
	ID                int    `json:"id,omitempty"`
	IsDefault         int    `json:"is_default"`
	SecurityGroupID   string `json:"security_group_id,omitempty"`
	SecurityGroupName string `json:"security_group_name,omitempty"`
}

// Type 'ListenerOptions' is shared across different actions. We use
// embedded struct to stick to our action+type convention.
type DescribeLoadBalancersListener struct {
	LoadBalancerListenerID string `json:"loadbalancer_listener_id,omitempty"`
	ListenerName           string `json:"loadbalancer_listener_name,omitempty"`
	ListenerOptions        `json:",inline"`
}

// See anchnet documentation about how the following fields work:
//   ForwardFor, SessionStick, HealthyCheckMethod, HealthyCheckOption, ListenerOption
// http://43.254.54.122:20992/help/api/LoadBalancer/AddLoadBalancerList.html
type ListenerOptions struct {
	BalanceMode        BalanceMode          `json:"balance_mode,omitempty"`
	ListenerProtocol   ListenerProtocolType `json:"listener_protocol,omitempty"`
	BackendProtocol    BackendProtocolType  `json:"backend_protocol,omitempty"`
	ForwardFor         int                  `json:"forwardfor,omitempty"`
	SessionStick       string               `json:"session_sticky,omitempty"`
	HealthyCheckMethod string               `json:"healthy_check_method,omitempty"`
	HealthyCheckOption string               `json:"healthy_check_option,omitempty"`
	ListenerOption     int                  `json:"listener_option,omitempty"`
	ListenerPort       int                  `json:"listener_port,omitempty"`
	Timeout            int                  `json:"timeout,omitempty"`
}

// LoadBalancerType defines the max concurrent connections allowed on loadbalancer.
type LoadBalancerType int

const (
	LoadBalancerType20K  LoadBalancerType = 1
	LoadBalancerType40K  LoadBalancerType = 2
	LoadBalancerType100K LoadBalancerType = 3
)

// LoadBalancerApply defines whether changes have been applied to loadbalancer.
type LoadBalancerApply int

const (
	LoadBalancerNotApplied LoadBalancerApply = 0
	LoadBalancerApplied    LoadBalancerApply = 1
)

// ListenerProtocolType defines protocols to listen, only support http and tcp.
type ListenerProtocolType string

const (
	ListenerProtocolTypeHTTP ListenerProtocolType = "http"
	ListenerProtocolTypeTCP  ListenerProtocolType = "tcp"
)

// ListenerProtocolType defines protocols of backend, this needs to be consistent
// with listener protocol.
type BackendProtocolType string

const (
	BackendProtocolTypeHTTP BackendProtocolType = "http"
	BackendProtocolTypeTCP  BackendProtocolType = "tcp"
)

// LoadBalancerStatus defines status of loadbalancer.
type LoadBalancerStatus string

const (
	LoadBalancerStatusPending   LoadBalancerStatus = "pending"
	LoadBalancerStatusActive    LoadBalancerStatus = "active"
	LoadBalancerStatusStopped   LoadBalancerStatus = "stopped"
	LoadBalancerStatusSuspended LoadBalancerStatus = "suspended"
)

// BalanceMode defines how to do load balance.
type BalanceMode string

const (
	BalanceModeRoundRobin     BalanceMode = "roundrobin"
	BalanceModeRoundLeastConn BalanceMode = "leastconn"
	BalanceModeSource         BalanceMode = "source"
)

//
// CreateLoadBalancer creates a loadbalancer, with optional firewall and eip information.
//
type CreateLoadBalancerRequest struct {
	RequestCommon `json:",inline"`
	Product       CreateLoadBalancerProduct `json:"product,omitempty"`
}

type CreateLoadBalancerResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
	LoadbalancerID string `json:"loadbalancer_id,omitempty"`
}

type CreateLoadBalancerProduct struct {
	Loadbalancer CreateLoadBalancerLB   `json:"lb,omitempty"` // Loadbalancer information
	Firewall     CreateLoadBalancerFW   `json:"fw,omitempty"` // Reference to firewall ID
	Eips         []CreateLoadBalancerIP `json:"ip,omitempty"` // Reference to eip ID
}

type CreateLoadBalancerFW struct {
	RefID string `json:"ref,omitempty"` // ID of the firewall
}

type CreateLoadBalancerLB struct {
	Name string           `json:"name,omitempty"`
	Type LoadBalancerType `json:"type,omitempty"` // Max connections. Choices:1(20k), 2(40k), 3(100k)
}

type CreateLoadBalancerIP struct {
	RefID string `json:"ref,omitempty"` // IDs of public ips that load balancer will bind to
}

//
// DeleteLoadBalancer deletes a list of loadbalancer, with optional eip information.
//
type DeleteLoadBalancersRequest struct {
	RequestCommon   `json:",inline"`
	LoadbalancerIDs []string `json:"loadbalancers,omitempty"`
	EipIDs          []string `json:"ips,omitempty"`
}

type DeleteLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// StartLoadBalancer starts a list of loadbalancers.
//
type StartLoadBalancersRequest struct {
	RequestCommon   `json:",inline"`
	LoadbalancerIDs []string `json:"loadbalancers,omitempty"`
}

type StartLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// StopLoadBalancer stops a list of loadbalancers.
//
type StopLoadBalancersRequest struct {
	RequestCommon   `json:",inline"`
	LoadbalancerIDs []string `json:"loadbalancers,omitempty"`
}

type StopLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ModifyLoadBalancerAttributes modifies attributes of a loadbalancer.
//
type ModifyLoadBalancerAttributesRequest struct {
	RequestCommon    `json:",inline"`
	LoadbalancerID   string `json:"loadbalancer,omitempty"`
	LoadbalancerName string `json:"loadbalancer_name,omitempty"`
	Description      string `json:"description,omitempty"`
}

type ModifyLoadBalancerAttributesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
	LoadbalancerID string `json:"loadbalancer_id,omitempty"`
}

//
// UpdateLoadBalancers updates a list of loadbalancers.
//
type UpdateLoadBalancersRequest struct {
	RequestCommon   `json:",inline"`
	LoadbalancerIDs []string `json:"loadbalancers,omitempty"`
}

type UpdateLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ResizeLoadBalancers resizes a list of loadbalancers, i.e. change its
// type (max connections).
//
type ResizeLoadBalancersRequest struct {
	RequestCommon    `json:",inline"`
	LoadbalancerIDs  []string         `json:"loadbalancers,omitempty"`
	LoadBalancerType LoadBalancerType `json:"loadbalancer_type,omitempty"`
}

type ResizeLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// AssociateEipsToLoadBalancer attaches a list of eips to a loadbalancer.
//
type AssociateEipsToLoadBalancerRequest struct {
	RequestCommon  `json:",inline"`
	LoadbalancerID string   `json:"loadbalancer,omitempty"`
	EipIDs         []string `json:"eips,omitempty"`
}

type AssociateEipsToLoadBalancerResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// DissociateEipsToLoadBalancer detaches a list of eips from a loadbalancer.
//
type DissociateEipsFromLoadBalancerRequest struct {
	RequestCommon  `json:",inline"`
	LoadbalancerID string   `json:"loadbalancer,omitempty"`
	EipIDs         []string `json:"eips,omitempty"`
}

type DissociateEipsFromLoadBalancerResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// AddLoadBalancerListeners adds a list of listeners to a loadbalancer.
//
type AddLoadBalancerListenersRequest struct {
	RequestCommon  `json:",inline"`
	LoadbalancerID string                             `json:"loadbalancer,omitempty"`
	Listeners      []AddLoadBalancerListenersListener `json:"listeners,omitempty"`
}

type AddLoadBalancerListenersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string   `json:"job_id,omitempty"`
	ListenerIDs    []string `json:"loadbalancer_listeners,omitempty"`
}

type AddLoadBalancerListenersListener struct {
	ListenerName    string `json:"loadbalancer_listener_name,omitempty"`
	ListenerOptions `json:",inline"`
}

//
// DeleteLoadBalancerListeners deletes a list of listeners.
//
type DeleteLoadBalancerListenersRequest struct {
	RequestCommon `json:",inline"`
	ListenerIDs   []string `json:"loadbalancer_listeners,omitempty"`
}

type DeleteLoadBalancerListenersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// DescribeLoadBalancerListeners retrieves information of a list of listeners (of a loadbalancer).
// Note that LoadbalancerID is used when we try to get listeners of a loadbalancer.
//
type DescribeLoadBalancerListenersRequest struct {
	RequestCommon  `json:",inline"`
	LoadbalancerID string   `json:"loadbalancer,omitempty"`
	ListenerIDs    []string `json:"loadbalancer_listeners,omitempty"`
	Verbose        int      `json:"verbose,omitempty"`
	Offset         int      `json:"offset,omitempty"`
	Limit          int      `json:"limit,omitempty"`
}

type DescribeLoadBalancerListenersResponse struct {
	ResponseCommon `json:",inline"`
	ItemSet        []DescribeLoadBalancerListenersItem `json:"item_set,omitempty"`
}

type DescribeLoadBalancerListenersItem struct {
	LoadbalancerID  string                                 `json:"loadbalancer_id,omitempty"`
	ListenerID      string                                 `json:"loadbalancer_listener_id,omitempty"`
	ListenerName    string                                 `json:"loadbalancer_listener_name,omitempty"`
	Description     string                                 `json:"description,omitempty"`
	CreateTime      string                                 `json:"create_time,omitempty"`
	Disabled        int                                    `json:"disabled"`
	Backends        []DescribeLoadBalancerListenersBackend `json:"backends,omitempty"`
	ListenerOptions `json:",inline"`
}

type DescribeLoadBalancerListenersBackend struct {
	ListenerID   string `json:"loadbalancer_listener_id,omitempty"`
	ListenerName string `json:"loadbalancer_listener_name,omitempty"`
	CreateTime   string `json:"create_time,omitempty"`
	Port         int    `json:"port,omitempty"`
	Weight       int    `json:"weight,omitempty"`
}

//
// ModifyLoadBalancerListenerAttributes changes attribute of a loadbalancer listener
//
type ModifyLoadBalancerListenerAttributesRequest struct {
	ListenerID      string `json:"loadbalancer_listener_id,omitempty"`
	ListenerName    string `json:"loadbalancer_listener_name,omitempty"`
	ListenerOptions `json:",inline"`
}

type ModifyLoadBalancerListenerAttributesResponse struct {
	ResponseCommon `json:",inline"`
	Listener       string `json:"loadbalancer_listener_id,omitempty"`
	JobID          string `json:"job_id,omitempty"`
}

//
// AddLoadBalancerBackends adds a list of backends to a listener.
//
type AddLoadBalancerBackendsRequest struct {
	RequestCommon `json:",inline"`
	ListenerID    string                           `json:"loadbalancer_listener,omitempty"`
	Backends      []AddLoadBalancerBackendsBackend `json:"backends,omitempty"`
}

type AddLoadBalancerBackendsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string   `json:"job_id,omitempty"`
	BackendIDs     []string `json:"loadbalancer_backends,omitempty"`
}

type AddLoadBalancerBackendsBackend struct {
	ResourceID string `json:"resource_id,omitempty"` // Instance ID, e.g. i-2H143W3Z
	Port       int    `json:"port,omitempty"`
	Weight     int    `json:"weight,omitempty"`
}

//
// DeleteLoadBalancerBackends deletes a list of backends.
//
type DeleteLoadBalancerBackendsRequest struct {
	RequestCommon `json:",inline"`
	BackendIDs    []string `json:"loadbalancer_backends,omitempty"`
}

type DeleteLoadBalancerBackendsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// DescribeLoadBalancerBackends retrieves information of a list of backends (of a listener).
// Note that LoadbalancerID, ListenerID is used when we try to get backends of a
// listener.
//
type DescribeLoadBalancerBackendsRequest struct {
	RequestCommon  `json:",inline"`
	LoadbalancerID string   `json:"loadbalancer,omitempty"`
	ListenerID     string   `json:"loadbalancer_listener,omitempty"`
	BackendIDs     []string `json:"loadbalancer_backends,omitempty"`
	Verbose        int      `json:"verbose,omitempty"`
	Offset         int      `json:"offset,omitempty"`
	Limit          int      `json:"limit,omitempty"`
}

type DescribeLoadBalancerBackendsResponse struct {
	ResponseCommon `json:",inline"`
	ItemSet        []DescribeLoadBalancerBackendsItem `json:"item_set,omitempty"`
}

type DescribeLoadBalancerBackendsItem struct {
	BackendID   string                               `json:"loadbalancer_backend_id,omitempty"`
	BackendName string                               `json:"loadbalancer_backend_name,omitempty"`
	Description string                               `json:"description,omitempty"`
	CreateTime  string                               `json:"create_time,omitempty"`
	Disabled    int                                  `json:"disabled,omitempty"`
	Status      BackendStatus                        `json:"status,omitempty"`
	Port        int                                  `json:"port,omitempty"`
	Weight      int                                  `json:"weight,omitempty"`
	ResourceID  string                               `json:"resource_id,omitempty"`
	PolicyID    string                               `json:"loadbalancer_policy_id,omitempty"`
	ListenerID  string                               `json:"loadbalancer_listener_id,omitempty"`
	Resource    DescribeLoadBalancerBackendsResource `json:"resource,omitempty"`
}

// DescribeLoadBalancerBackendsResource is the actual instance for the backend.
type DescribeLoadBalancerBackendsResource struct {
	ResourceID   string `json:"resource_id,omitempty"`
	ResourceName string `json:"resource_name,omitempty"`
	ResourceType string `json:"resource_type,omitempty"`
}

// BackendStatus defines status of the backend. Backend can be down even if instance
// is running, e.g. application failed to listen on designated port.
type BackendStatus string

const (
	BackendStatusUp       BackendStatus = "up"
	BackendStatusDown     BackendStatus = "down"
	BackendStatusAbnormal BackendStatus = "abnormal"
)

//
// ModifyLoadBalancerBackendAttributes changes attributes of a backend.
//
type ModifyLoadBalancerBackendAttributesRequest struct {
	BackendID string `json:"loadbalancer_backend_id,omitempty"`
	PolicyID  string `json:"loadbalancer_policy_id,omitempty"`
	Port      int    `json:"port,omitempty"`
	Weight    int    `json:"weight,omitempty"`
	Disabled  int    `json:"disabled,omitempty"`
}

type ModifyLoadBalancerBackendAttributesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
	BackendID      string `json:"loadbalancer_backend_id,omitempty"`
}
