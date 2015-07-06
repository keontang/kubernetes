// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet loadbalancer related APIs, except loadbalancer policy related.

type DescribeLoadBalancersRequest struct {
	RequestCommon `json:",inline"`
	Loadbalancers []string             `json:"loadbalancers,omitempty"`
	Status        []LoadBalancerStatus `json:"status,omitempty"`
	SearchWord    string               `json:"search_word,omitempty"`
	Offset        int                  `json:"offset,omitempty"`
	Verbose       int                  `json:"verbose,omitempty"`
	Limit         int                  `json:"limit,omitempty"`
}

type DescribeLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                         `json:"total_count,omitempty"`
	ItemSet        []DescribeLoadBalancersItem `json:"item_set,omitempty"`
}

type DescribeLoadBalancersItem struct {
	Loadbalancer     string                             `json:"loadbalancer_id,omitempty"`
	LoadbalancerName string                             `json:"loadbalancer_name,omitempty"`
	LoadbalancerType LoadBalancerType                   `json:"loadbalancer_type,omitempty"`
	Description      string                             `json:"description,omitempty"`
	CreateTime       string                             `json:"create_time,omitempty"`
	StatusTime       string                             `json:"status_time,omitempty"`
	Status           LoadBalancerStatus                 `json:"status,omitempty"`
	IsApplied        LoadBalancerApply                  `json:"is_applied,omitempty"`
	Eips             []DescribeLoadBalancersEIP         `json:"eips,omitempty"`
	Listeners        []DescribeLoadBalancersListener    `json:"listeners,omitempty"`
	SecurityGroup    DescribeLoadBalancersSecurityGroup `json:"security_group,omitempty"`
}

type DescribeLoadBalancersEIP struct {
	EipID   string `json:"eip_id,omitempty"`
	EipName string `json:"eip_name,omitempty"`
	EipAddr string `json:"eip_addr,omitempty"`
}

// This is the same as AddLoadBalancerListenersListener - both contains all
// information of a listener.
type DescribeLoadBalancersListener struct {
	AddLoadBalancerListenersListener `json:",inline"`
}

type DescribeLoadBalancersSecurityGroup struct {
	Attachon          int    `json:"attachon,omitempty"`
	ID                int    `json:"id,omitempty"`
	IsDefault         int    `json:"is_default"`
	SecurityGroupID   string `json:"security_group_id,omitempty"`
	SecurityGroupName string `json:"security_group_name,omitempty"`
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

type CreateLoadBalancerRequest struct {
	RequestCommon `json:",inline"`
	Product       CreateLoadBalancerProduct `json:"product,omitempty"`
}

type CreateLoadBalancerResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`          // job id in anchnet
	LBID           string `json:"loadbalancer_id,omitempty"` // load balancer id
}

type CreateLoadBalancerProduct struct {
	FW CreateLoadBalancerFW   `json:"fw,omitempty"` // firewall ID
	LB CreateLoadBalancerLB   `json:"lb,omitempty"` // LB information
	IP []CreateLoadBalancerIP `json:"ip,omitempty"` // EIP information
}

type CreateLoadBalancerFW struct {
	Ref string `json:"ref,omitempty"` // ID of the firewall
}

type CreateLoadBalancerLB struct {
	Name string           `json:"name,omitempty"` // name of the lb
	Type LoadBalancerType `json:"type,omitempty"` // maximum connections. Choices:1(20k), 2(40k), 3(100k)
}

type CreateLoadBalancerIP struct {
	Ref string `json:"ref,omitempty"` // IDs of public ips that load balancer will bind to
}

type DeleteLoadBalancersRequest struct {
	RequestCommon `json:",inline"`
	IPs           []string `json:"ips,omitempty"`
	Loadbalancers []string `json:"loadbalancers,omitempty"`
}

type DeleteLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type StartLoadBalancersRequest struct {
	RequestCommon `json:",inline"`
	Loadbalancers []string `json:"loadbalancers,omitempty"`
}

type StartLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type StopLoadBalancersRequest struct {
	RequestCommon `json:",inline"`
	Loadbalancers []string `json:"loadbalancers,omitempty"`
}

type StopLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type ModifyLoadBalancerAttributesRequest struct {
	RequestCommon    `json:",inline"`
	Loadbalancer     string `json:"loadbalancer,omitempty"`
	LoadbalancerName string `json:"loadbalancer_name,omitempty"`
	Description      string `json:"description,omitempty"`
}

type ModifyLoadBalancerAttributesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
	Loadbalancer   string `json:"loadbalancer_id,omitempty"`
}

type UpdateLoadBalancersRequest struct {
	RequestCommon `json:",inline"`
	Loadbalancers []string `json:"loadbalancers,omitempty"`
}

type UpdateLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type ResizeLoadBalancersRequest struct {
	RequestCommon    `json:",inline"`
	Loadbalancers    []string         `json:"loadbalancers,omitempty"`
	LoadBalancerType LoadBalancerType `json:"loadbalancer_type,omitempty"`
}

type ResizeLoadBalancersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type AssociateEipsToLoadBalancerRequest struct {
	RequestCommon `json:",inline"`
	Loadbalancer  string   `json:"loadbalancer,omitempty"`
	Eips          []string `json:"eips,omitempty"`
}

type AssociateEipsToLoadBalancerResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type DissociateEipsFromLoadBalancerRequest struct {
	RequestCommon `json:",inline"`
	Loadbalancer  string   `json:"loadbalancer,omitempty"`
	Eips          []string `json:"eips,omitempty"`
}

type DissociateEipsFromLoadBalancerResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type AddLoadBalancerListenersRequest struct {
	RequestCommon `json:",inline"`
	Loadbalancer  string                             `json:"loadbalancer,omitempty"`
	Listeners     []AddLoadBalancerListenersListener `json:"listeners,omitempty"`
}

type AddLoadBalancerListenersResponse struct {
	ResponseCommon        `json:",inline"`
	LoadbalancerListeners []string `json:"loadbalancer_listeners,omitempty"`
	JobID                 string   `json:"job_id,omitempty"`
}

// See anchnet documentation about how the followinf fields work:
//   ForwardFor, SessionStick, HealthyCheckMethod, HealthyCheckOption, ListenerOption
// http://43.254.54.122:20992/help/api/LoadBalancer/AddLoadBalancerList.html
type AddLoadBalancerListenersListener struct {
	LoadbalancerListenerName string               `json:"loadbalancer_listener_name,omitempty"`
	BalanceMode              BalanceMode          `json:"balance_mode,omitempty"`
	ListenerProtocol         ListenerProtocolType `json:"listener_protocol,omitempty"`
	BackendProtocol          BackendProtocolType  `json:"backend_protocol,omitempty"`
	ForwardFor               int                  `json:"forwardfor,omitempty"`
	SessionStick             string               `json:"session_sticky,omitempty"`
	HealthyCheckMethod       string               `json:"healthy_check_method,omitempty"`
	HealthyCheckOption       string               `json:"healthy_check_option,omitempty"`
	ListenerOption           int                  `json:"listener_option,omitempty"`
	ListenerPort             int                  `json:"listener_port,omitempty"`
	Timeout                  int                  `json:"timeout,omitempty"`
}

type DeleteLoadBalancerListenersRequest struct {
	RequestCommon         `json:",inline"`
	LoadbalancerListeners []string `json:"loadbalancer_listeners,omitempty"`
}

type DeleteLoadBalancerListenersResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type DescribeLoadBalancerListenersRequest struct {
	RequestCommon         `json:",inline"`
	Loadbalancer          string   `json:"loadbalancer,omitempty"`
	LoadbalancerListeners []string `json:"loadbalancer_listeners,omitempty"`
	Offset                int      `json:"offset,omitempty"`
	Verbose               int      `json:"verbose,omitempty"`
	Limit                 int      `json:"limit,omitempty"`
}

type DescribeLoadBalancerListenersResponse struct {
	ResponseCommon `json:",inline"`
	ItemSet        []DescribeLoadBalancerListenersItem `json:"item_set,omitempty"`
}

// Some fields are similar to AddLoadBalancerListenersItem.
type DescribeLoadBalancerListenersItem struct {
	LoadbalancerListener     string                                 `json:"loadbalancer_listener_id,omitempty"`
	LoadbalancerListenerName string                                 `json:"loadbalancer_listener_name,omitempty"`
	BalanceMode              BalanceMode                            `json:"balance_mode,omitempty"`
	ListenerProtocol         ListenerProtocolType                   `json:"listener_protocol,omitempty"`
	ForwardFor               int                                    `json:"forwardfor,omitempty"`
	SessionStick             string                                 `json:"session_sticky,omitempty"`
	HealthyCheckMethod       string                                 `json:"healthy_check_method,omitempty"`
	HealthyCheckOption       string                                 `json:"healthy_check_option,omitempty"`
	ListenerOption           int                                    `json:"listener_option,omitempty"`
	ListenerPort             int                                    `json:"listener_port,omitempty"`
	Description              string                                 `json:"description,omitempty"`
	Disabled                 int                                    `json:"disabled"`
	CreateTime               string                                 `json:"create_time,omitempty"`
	Loadbalancer             string                                 `json:"loadbalancer_id,omitempty"`
	Backends                 []DescribeLoadBalancerListenersBackend `json:"backends,omitempty"`
}

type DescribeLoadBalancerListenersBackend struct {
	LoadbalancerListener     string `json:"loadbalancer_listener_id,omitempty"`
	LoadbalancerListenerName string `json:"loadbalancer_listener_name,omitempty"`
	CreateTime               string `json:"create_time,omitempty"`
	Port                     int    `json:"port,omitempty"`
	Weight                   int    `json:"weight,omitempty"`
}

type ModifyLoadBalancerListenerAttributesRequest struct {
	LoadbalancerListener     string               `json:"loadbalancer_listener_id,omitempty"`
	LoadbalancerListenerName string               `json:"loadbalancer_listener_name,omitempty"`
	BalanceMode              BalanceMode          `json:"balance_mode,omitempty"`
	ListenerProtocol         ListenerProtocolType `json:"listener_protocol,omitempty"`
	HealthyCheckMethod       string               `json:"healthy_check_method,omitempty"`
	HealthyCheckOption       string               `json:"healthy_check_option,omitempty"`
	ListenerOption           int                  `json:"listener_option,omitempty"`
	ListenerPort             int                  `json:"listener_port,omitempty"`
}

type ModifyLoadBalancerListenerAttributesResponse struct {
	ResponseCommon       `json:",inline"`
	LoadbalancerListener string `json:"loadbalancer_listener_id,omitempty"`
	JobID                string `json:"job_id,omitempty"`
}

type AddLoadBalancerBackendsRequest struct {
	RequestCommon        `json:",inline"`
	LoadbalancerListener string                           `json:"loadbalancer_listener,omitempty"`
	Backends             []AddLoadBalancerBackendsBackend `json:"backends,omitempty"`
}

type AddLoadBalancerBackendsResponse struct {
	ResponseCommon       `json:",inline"`
	LoadbalancerBackends []string `json:"loadbalancer_backends,omitempty"`
	JobID                string   `json:"job_id,omitempty"`
}

type AddLoadBalancerBackendsBackend struct {
	ResourceID string `json:"resource_id,omitempty"` // Instance ID, e.g. i-2H143W3Z
	Port       int    `json:"port,omitempty"`
	Weight     int    `json:"weight,omitempty"`
}

type DeleteLoadBalancerBackendsRequest struct {
	RequestCommon        `json:",inline"`
	LoadbalancerBackends []string `json:"loadbalancer_backends,omitempty"`
}

type DeleteLoadBalancerBackendsResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

type DescribeLoadBalancerBackendsRequest struct {
	RequestCommon        `json:",inline"`
	Loadbalancer         string   `json:"loadbalancer,omitempty"`
	LoadbalancerListener string   `json:"loadbalancer_listener,omitempty"`
	LoadbalancerBackends []string `json:"loadbalancer_backends,omitempty"`
	Offset               int      `json:"offset,omitempty"`
	Verbose              int      `json:"verbose,omitempty"`
	Limit                int      `json:"limit,omitempty"`
}

type DescribeLoadBalancerBackendsResponse struct {
	ResponseCommon `json:",inline"`
	ItemSet        []DescribeLoadBalancerBackendsItem `json:"item_set,omitempty"`
}

type DescribeLoadBalancerBackendsItem struct {
	Disabled                int                                  `json:"disabled,omitempty"`
	LoadbalancerBackend     string                               `json:"loadbalancer_backend_id,omitempty"`
	LoadbalancerBackendName string                               `json:"loadbalancer_backend_name,omitempty"`
	Description             string                               `json:"description,omitempty"`
	LoadbalancerPolicy      string                               `json:"loadbalancer_policy_id,omitempty"`
	Port                    int                                  `json:"port,omitempty"`
	ResourceID              string                               `json:"resource_id,omitempty"`
	Status                  BackendStatus                        `json:"status,omitempty"`
	CreateTime              string                               `json:"create_time,omitempty"`
	Weight                  int                                  `json:"weight,omitempty"`
	LoadbalancerListener    string                               `json:"loadbalancer_listener_id,omitempty"`
	Resource                DescribeLoadBalancerBackendsResource `json:"resource,omitempty"`
}

type DescribeLoadBalancerBackendsResource struct {
	ResourceID   string `json:"resource_id,omitempty"`
	ResourceName string `json:"resource_name,omitempty"`
	ResourceType string `json:"resource_type,omitempty"`
}

type BackendStatus string

const (
	BackendStatusUp       BackendStatus = "up"
	BackendStatusDown     BackendStatus = "down"
	BackendStatusAbnormal BackendStatus = "abnormal"
)

type ModifyLoadBalancerBackendAttributesRequest struct {
	LoadbalancerBackend string `json:"loadbalancer_backend_id,omitempty"`
	Port                int    `json:"port,omitempty"`
	Weight              int    `json:"weight,omitempty"`
	Disabled            int    `json:"disabled,omitempty"`
	LoadbalancerPolicy  string `json:"loadbalancer_policy_id,omitempty"`
}

type ModifyLoadBalancerBackendAttributesResponse struct {
	ResponseCommon      `json:",inline"`
	LoadbalancerBackend string `json:"loadbalancer_backend_id,omitempty"`
	JobID               string `json:"job_id,omitempty"`
}
