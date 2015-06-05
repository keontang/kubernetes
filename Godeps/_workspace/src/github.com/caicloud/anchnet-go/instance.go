// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"github.com/caicloud/anchnet-go/vendor/_nuts/github.com/mitchellh/mapstructure"
)

// Implements all anchnet instance related APIs. [x] means done, [ ] means not done yet.
//   [x] DescribeInstances
//   [x] RunInstances
//   [x] TerminateInstances
//   [ ] StartInstances
//   [x] StopInstances
//   [ ] RestartInstances
//   [ ] ResetLoginPasswd
//   [ ] ModifyInstanceAttributes

// RunInstancesProduct is a wrapper around Cloud; it describes an anchnet product.
type RunInstancesProduct struct {
	Cloud RunInstancesCloud `json:"cloud,omitempty"`
}

// RunInstancesCloud describes information of a cloud server. The information includes: machine
// resources, disk/volumes, networks, etc.
type RunInstancesCloud struct {
	// VM contains parameters for the virtual machine.
	VM RunInstancesVM `json:"vm,omitempty"`

	// HD contains parameters for hard disks.
	HD []RunInstancesHardDisk `json:"hd,omitempty"`

	// Net0 tells if the new machine will be public or not.
	Net0 bool `json:"net0,omitempty"`

	// Net1 is the SDN network information, either for creating a new one or using existing ones.
	// Anchnet SDN network has two types: public and private. Public network will be created
	// automatically when Net0 is true; while private network is created by user: either here or
	// using Vxnet API. Private network is primarily used to communicate between cloud servers.
	// It's better to create a private SND network in order for two machines in anchnet to communicate
	// with each other.
	Net1 []RunInstancesNet1 `json:"net1,omitempty"`

	// IP creates new or use existing public IP, i.e. EIP resource. If this is used, Net0 must be
	// set to true.
	IP RunInstancesIP `json:"ip,omitempty"`
}

// LoginMode specifies how to login to a machine, only password for now.
type LoginMode string

const (
	LoginModePwd LoginMode = "pwd"
)

// RunInstancesVM sets parameters for a virtual machine.
type RunInstancesVM struct {
	Name      string    `json:"name,omitempty"`
	LoginMode LoginMode `json:"login_mode,omitempty"`
	Mem       int       `json:"mem,omitempty"`      // Choices: 1024,2048,4096,8192,16384,32768 (MB)
	Cpu       int       `json:"cpu,omitempty"`      // Number of cores: 1, 2, 3, etc.
	ImageId   string    `json:"image_id,omitempty"` // Image to use, e.g. opensuse12x64c, trustysrvx64c, etc
	Password  string    `json:"password,omitempty"` // Used if login mode is password
}

// Note HDType is the same as VolumeType. We separate them out due to inconsistency in anchnet.
type HDType int

const (
	HDTypePerformance HDType = 0
	HDTypeCapacity    HDType = 1
)

// RunInstancesHardDisk sets parameters for a hard disk.
type RunInstancesHardDisk struct {
	Name string   `json:"name,omitempty"`
	Type HDType   `json:"type"`           // Type of the disk, see above (Do not omit empty due to type 0)
	Unit int      `json:"unit,omitempty"` // In GB, e.g. 10 means 10GB HardDisk
	HD   []string `json:"hd,omitempty"`   // IDs of existing hard disk; they will be attached to the new machine
}

// RunInstancesNet1 sets SDN information.
type RunInstancesNet1 struct {
	VxnetName string   `json:"vxnet_name,omitempty"`
	Checked   bool     `json:"checked,omitempty"`  // If true, the new machine will be added to the network
	VxnetId   []string `json:"vxnet_id,omitempty"` // IDs of existing SDN network; the new machine wll be added to the network
}

// RunInstancesIP sets parameters for public IP (EIP).
type RunInstancesIP struct {
	Bandwidth int    `json:"bw,omitempty"`       // In MB/s
	IPGroup   string `json:"ip_group,omitempty"` // Only "eipg-00000000" is BGP for now
	IP        string `json:"ip,omitempty"`       // ID of existing EIP, used if the machine chooses existing IP
}

// RunInstancesRequest contains all information needed to run (create) instances.
type RunInstancesRequest struct {
	RequestCommon `json:",inline"`
	Product       RunInstancesProduct `json:"product,omitempty"`
}

// RunInstanceResponse contains all information returned from anchnet server.
type RunInstancesResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	Instances      []string `json:"instances,omitempty" mapstructure:"instances"` // IDs of created instances
	Volumes        []string `json:"volumes,omitempty" mapstructure:"volumes"`     // IDs of created volumes
	EIPs           []string `json:"eips,omitempty" mapstructure:"eips"`           // IDs of created public IP
	JobID          string   `json:"job_id,omitempty" mapstructure:"job_id"`       // Job ID in anchnet
}

// RunInstances creates new server with given configurations. Newly created
// server is in running state.
// http://cloud.51idc.com/help/api/instance/RunInstances.html
func (c *Client) RunInstances(request RunInstancesRequest) (*RunInstancesResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "RunInstances"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result RunInstancesResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

// TerminateInstancesRequest contains all information needed to terminate instances.
// Note public IPs and volumes attached to the instance won't be deleted unless
// explicitly specified in the request.
type TerminateInstancesRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"`
	IPs           []string `json:"ips,omitempty"`
	Vols          []string `json:"vols,omitempty"`
}

// TerminateInstancesResponse contains all information returned from anchnet server.
type TerminateInstancesResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id""` // Job ID in anchnet
}

// TerminateInstances terminates instances.
func (c *Client) TerminateInstances(request TerminateInstancesRequest) (*TerminateInstancesResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "TerminateInstances"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result TerminateInstancesResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

// DescribeInstancesRequest contains all information needed to get instances metadata.
type DescribeInstancesRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitemtpy"`
	Status        []string `json:"status,omitempty"`
	SearchWord    string   `json:"search_word,omitemtpy"`
	Verbose       int      `json:"verbose,omitemtpy"`
	Offset        int      `json:"offset,omitemtpy"`
	Limit         int      `json:"limit,omitemtpy"`
}

// DescribeInstancesResponse contains all information returned from anchnet server.
type DescribeInstancesResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	TotalCount     int                       `json:"total_count,omitemtpy" mapstructure:"total_count"`
	ItemSet        []DescribeInstanceItemSet `json:"item_set,omitemtpy" mapstructure:"item_set"`
}

// DescribeInstanceItemSet contains all information about an instance.
type DescribeInstanceItemSet struct {
	InstanceID    string                        `json:"instance_id,omitemtpy" mapstructure:"instance_id"`
	InstanceName  string                        `json:"instance_name,omitemtpy" mapstructure:"instance_name"`
	Description   string                        `json:"description,omitemtpy" mapstructure:"description"`
	Status        string                        `json:"status,omitemtpy" mapstructure:"status"`                 // One of "pending", "running", "stopped", "suspended"
	VcpusCurrent  int                           `json:"vcpus_current,omitemtpy" mapstructure:"vcpus_current"`   // Number of CPU cores
	MemoryCurrent int                           `json:"memory_current,omitemtpy" mapstructure:"memory_current"` // Memory size, unit: MB
	StatusTime    string                        `json:"status_time,omitemtpy" mapstructure:"status_time"`       // Last date when instance was changed
	CreateTime    string                        `json:"create_time,omitemtpy" mapstructure:"create_time"`       // Date when instance was created
	Vxnets        []DescribeInstanceVxnets      `json:"vxnets,omitemtpy" mapstructure:"vxnets"`                 // SDN network information of the instance
	EIP           DescribeInstanceEIP           `json:"eip,omitemtpy" mapstructure:"eip"`                       // External IP information of the ip
	Image         DescribeInstanceImage         `json:"image,omitemtpy" mapstructure:"image"`
	VolumeIds     []string                      `json:"volume_ids,omitemtpy" mapstructure:"volume_ids"`
	Volumes       []DescribeInstanceVolume      `json:"volumes,omitemtpy" mapstructure:"volumes"`
	SecurityGroup DescribeInstanceSecurityGroup `json:"security_group,omitemtpy" mapstructure:"security_group"`
}

// DescribeInstanceVxnets contains all information about a SDN network.
type DescribeInstanceVxnets struct {
	VxnetID   string `json:"vxnet_id,omitemtpy" mapstructure:"vxnet_id"`
	VxnetName string `json:"vxnet_name,omitemtpy" mapstructure:"vxnet_name"`
	VxnetType int    `json:"vxnet_type" mapstructure:"vxnet_type"`           // Network type, one of 0 (private), 1 (public). This maybe duplicate with Systype. Do not omit empty due to type 0
	NicID     string `json:"nic_id,omitemtpy" mapstructure:"nic_id"`         // MAC address of the instance
	PrivateIP string `json:"private_ip,omitemtpy" mapstructure:"private_ip"` // IP address of the instance in the SDN network
	Systype   string `json:"systype,omitemtpy" mapstructure:"systype"`       // SDN network type, one of "priv", "pub"
}

// DescribeInstanceEIP contains all information about instance external ip.
type DescribeInstanceEIP struct {
	EipID   string `json:"eip_id,omitemtpy" mapstructure:"eip_id"`
	EipName string `json:"eip_name,omitemtpy" mapstructure:"eip_name"`
	EipAddr string `json:"eip_addr,omitemtpy" mapstructure:"eip_addr"`
}

// DescribeInstanceImage contains all information about image the instance is using.
type DescribeInstanceImage struct {
	ImageID       string `json:"image_id,omitemtpy" mapstructure:"image_id"`
	ImageName     string `json:"image_name,omitemtpy" mapstructure:"image_name"`
	ImageSize     int    `json:"image_size,omitemtpy" mapstructure:"image_size"`
	OsFamily      string `json:"os_family,omitemtpy" mapstructure:"os_family"`           // E.g. windows, centos, ubuntu, etc
	Platform      string `json:"platform,omitemtpy" mapstructure:"platform"`             // One of windows, linux
	ProcessorType string `json:"processor_type,omitemtpy" mapstructure:"processor_type"` // One of 32bit, 64bit
	Provider      string `json:"provider,omitemtpy" mapstructure:"provider"`             // One of system, self
}

// DescribeInstanceVolume contains all information about volumes of the instance.
type DescribeInstanceVolume struct {
	Size       string `json:"size,omitemtpy" mapstructure:"size"`
	VolumeID   string `json:"volume_id,omitemtpy" mapstructure:"volume_id"`
	VolumeName string `json:"volume_name,omitemtpy" mapstructure:"volume_name"`
	VolumeType string `json:"volume_type,omitemtpy" mapstructure:"volume_type"` // One of "0", "1". Note it's string.
}

// DescribeInstanceSecurityGroup contains firewall information of the instance.
type DescribeInstanceSecurityGroup struct {
	Attachon          int    `json:"attachon,omitemtpy" mapstructure:"attachon"`
	IsDefault         int    `json:"is_default" mapstructure:"is_default"` // Do not omit empty due to is_default=0
	SecurityGroupID   string `json:"security_group_id,omitemtpy" mapstructure:"security_group_id"`
	SecurityGroupName string `json:"security_group_name,omitemtpy" mapstructure:"security_group_name"`
}

// DescribeInstances get instances metadata.
// http://cloud.51idc.com/help/api/instance/DescribeInstances.html
func (c *Client) DescribeInstances(request DescribeInstancesRequest) (*DescribeInstancesResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "DescribeInstances"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result DescribeInstancesResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type StopType int

const (
	ForceStop    StopType = 1
	NonForceStop StopType = 0
)

// StopInstancesRequest contains all information needed to stop instances.
// Note public IPs and volumes attached to the instance won't be deleted unless
// explicitly specified in the request.
type StopInstancesRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"`
	Force         StopType `json:"force"`
}

// StopInstancesResponse contains all information returned from anchnet server.
type StopInstancesResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id""` // Job ID in anchnet
}

// StopInstances stops instances.
func (c *Client) StopInstances(request StopInstancesRequest) (*StopInstancesResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "StopInstances"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result StopInstancesResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}
