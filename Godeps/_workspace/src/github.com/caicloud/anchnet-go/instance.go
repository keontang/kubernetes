// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet instance related APIs.

// DescribeInstancesRequest contains all information needed to get instances metadata.
type DescribeInstancesRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string         `json:"instances,omitempty"`
	Status        []InstanceStatus `json:"status,omitempty"`
	SearchWord    string           `json:"search_word,omitempty"`
	Verbose       int              `json:"verbose,omitempty"`
	Offset        int              `json:"offset,omitempty"`
	Limit         int              `json:"limit,omitempty"`
}

type DescribeInstancesResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                     `json:"total_count,omitempty"`
	ItemSet        []DescribeInstancesItem `json:"item_set,omitempty"`
}

// DescribeInstancesItem contains all information about an instance.
type DescribeInstancesItem struct {
	InstanceID    string                         `json:"instance_id,omitempty"`
	InstanceName  string                         `json:"instance_name,omitempty"`
	Description   string                         `json:"description,omitempty"`
	Status        InstanceStatus                 `json:"status,omitempty"`
	VcpusCurrent  int                            `json:"vcpus_current,omitempty"`  // Number of CPU cores
	MemoryCurrent int                            `json:"memory_current,omitempty"` // Memory size, unit: MB
	StatusTime    string                         `json:"status_time,omitempty"`    // Last date when instance was changed
	CreateTime    string                         `json:"create_time,omitempty"`    // Date when instance was created
	Vxnets        []DescribeInstancesVxnet       `json:"vxnets,omitempty"`         // SDN network information of the instance
	EIP           DescribeInstancesEIP           `json:"eip,omitempty"`            // External IP information of the ip
	Image         DescribeInstancesImage         `json:"image,omitempty"`
	VolumeIDs     []string                       `json:"volume_ids,omitempty"`
	Volumes       []DescribeInstancesVolume      `json:"volumes,omitempty"`
	SecurityGroup DescribeInstancesSecurityGroup `json:"security_group,omitempty"`
}

// DescribeInstancesVxnet contains all information about a SDN network.
type DescribeInstancesVxnet struct {
	VxnetID   string `json:"vxnet_id,omitempty"`
	VxnetName string `json:"vxnet_name,omitempty"`
	// Do not omit empty due to type 0.
	VxnetType int    `json:"vxnet_type"`           // Network type, one of 0 (private), 1 (public). This maybe duplicate with Systype.
	NicID     string `json:"nic_id,omitempty"`     // MAC address of the instance
	PrivateIP string `json:"private_ip,omitempty"` // IP address of the instance in the SDN network
	Systype   string `json:"systype,omitempty"`    // SDN network type, one of "priv", "pub"
}

type DescribeInstancesEIP struct {
	EipID   string `json:"eip_id,omitempty"`
	EipName string `json:"eip_name,omitempty"`
	EipAddr string `json:"eip_addr,omitempty"`
}

// DescribeInstancesImage contains all information about image the instance is using.
type DescribeInstancesImage struct {
	ImageID       string `json:"image_id,omitempty"`
	ImageName     string `json:"image_name,omitempty"`
	ImageSize     int    `json:"image_size,omitempty"`
	OsFamily      string `json:"os_family,omitempty"`      // E.g. windows, centos, ubuntu, etc
	Platform      string `json:"platform,omitempty"`       // One of windows, linux
	ProcessorType string `json:"processor_type,omitempty"` // One of 32bit, 64bit
	Provider      string `json:"provider,omitempty"`       // One of system, self
}

type DescribeInstancesVolume struct {
	Size       string `json:"size,omitempty"`
	VolumeID   string `json:"volume_id,omitempty"`
	VolumeName string `json:"volume_name,omitempty"`
	VolumeType string `json:"volume_type,omitempty"` // One of "0", "1". Note it's string.
}

// DescribeInstancesSecurityGroup contains firewall information of the instance.
type DescribeInstancesSecurityGroup struct {
	Attachon int `json:"attachon,omitempty"`
	// Do not omit empty due to is_default=0
	IsDefault         int    `json:"is_default"`
	SecurityGroupID   string `json:"security_group_id,omitempty"`
	SecurityGroupName string `json:"security_group_name,omitempty"`
}

type InstanceStatus string

const (
	InstanceStatusPending   InstanceStatus = "pending"
	InstanceStatusRunning   InstanceStatus = "running"
	InstanceStatusStopped   InstanceStatus = "stopped"
	InstanceStatusSuspended InstanceStatus = "suspended"
)

// RunInstancesRequest contains all information needed to run (create) instances.
type RunInstancesRequest struct {
	RequestCommon `json:",inline"`
	Product       RunInstancesProduct `json:"product,omitempty"`
}

type RunInstancesResponse struct {
	ResponseCommon `json:",inline"`
	Instances      []string `json:"instances,omitempty"` // IDs of created instances
	Volumes        []string `json:"volumes,omitempty"`   // IDs of created volumes
	EIPs           []string `json:"eips,omitempty"`      // IDs of created public IP
	JobID          string   `json:"job_id,omitempty"`    // Job ID in anchnet
}

// RunInstancesProduct is a wrapper around Cloud; it describes an anchnet product.
type RunInstancesProduct struct {
	Cloud RunInstancesCloud `json:"cloud,omitempty"`
}

// RunInstancesCloud describes information of cloud servers, including: machine resources,
// disk/volumes, networks, etc.
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

	// Number of instances to create. All instances will have the same configuration.
	Amount int `json:"amount,omitempty"`
}

// LoginMode specifies how to login to a machine, only password mode is supported.
type LoginMode string

const (
	LoginModePwd LoginMode = "pwd"
)

// RunInstancesVM sets parameters for a virtual machine.
type RunInstancesVM struct {
	Name      string    `json:"name,omitempty"`
	LoginMode LoginMode `json:"login_mode,omitempty"`
	Mem       int       `json:"mem,omitempty"`      // Choices: 1024,2048,4096,8192,16384,32768 (MB)
	Cpu       int       `json:"cpu,omitempty"`      // Choices: 1,2,4,8 (Number of cores)
	ImageID   string    `json:"image_id,omitempty"` // Image to use, e.g. opensuse12x64c, trustysrvx64c, etc
	Password  string    `json:"password,omitempty"` // Used if login mode is password
}

// Note HDType is the same as VolumeType. We separate them out due to inconsistent naming in anchnet.
type HDType int

const (
	HDTypePerformance HDType = 0
	HDTypeCapacity    HDType = 1
)

// RunInstancesHardDisk sets parameters for a hard disk.
type RunInstancesHardDisk struct {
	// Following fields are used when creating hard disk along with new instance.
	Name string `json:"name,omitempty"`
	// Do not omit empty due to type 0.
	Type HDType `json:"type"`           // Type of the disk, see above
	Unit int    `json:"unit,omitempty"` // In GB, e.g. 10 means 10GB HardDisk
	// Following fields are used when using existing hard disks.
	HD []string `json:"hd,omitempty"` // IDs of existing hard disk; they will be attached to the new machine
}

// RunInstancesNet1 sets SDN information.
type RunInstancesNet1 struct {
	// Following fields are used when creating vxnet along with new instance.
	VxnetName string `json:"vxnet_name,omitempty"`
	Checked   bool   `json:"checked,omitempty"` // If true, the new machine will be added to the network
	// Following fields are used when using existing vxnet.
	VxnetID []string `json:"vxnet_id,omitempty"` // IDs of existing SDN network; the new machine wll be added to the network
}

// RunInstancesIP sets parameters for public IP (EIP).
type RunInstancesIP struct {
	// Following fields are used when creating eip along with new instance.
	Bandwidth int    `json:"bw,omitempty"`       // In MB/s
	IPGroup   string `json:"ip_group,omitempty"` // Only "eipg-00000000" is BGP for now
	// Following fields are used when using existing eip.
	IP string `json:"ip,omitempty"` // ID of existing EIP; the ip will be assigned to the new machine
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

type TerminateInstancesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"` // Job ID in anchnet
}

// StartInstancesRequest contains all information needed to start instances.
type StartInstancesRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"`
}

type StartInstancesResponse struct {
	ResponseCommon `json",inline"`
	JobID          string `json:"job_id,omitempty"`
}

// StopInstancesRequest contains all information needed to stop instances.
// Note public IPs and volumes attached to the instance won't be deleted unless
// explicitly specified in the request.
type StopInstancesRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"`
	// Do not omitempty due to non force stop.
	Force StopType `json:"force"`
}

type StopInstancesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"` // Job ID in anchnet
}

// StopType defines how to stop the machine. 1: forcibly shutdown 0: gracefully shutdown.
type StopType int

const (
	ForceStop    StopType = 1
	NonForceStop StopType = 0
)

// RestartInstancesRequest contains all information needed to restart instances.
type RestartInstancesRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"`
}

type RestartInstancesResponse struct {
	ResponseCommon `json",inline"`
	JobID          string `json:"job_id,omitempty"`
}

// ResetLoginPasswdRequest contains all information needed to reset instance password.
// The instance must be shutdown.
type ResetLoginPasswdRequest struct {
	RequestCommon `json:",inline"`
	Instances     []string `json:"instances,omitempty"`
	LoginPasswd   string   `json:"login_passwd,omitempty"`
}

type ResetLoginPasswdResponse struct {
	ResponseCommon `json",inline"`
	JobID          string `json:"job_id,omitempty"`
}

// ModifyInstanceAttributesRequest modifies name, description of an instance.
type ModifyInstanceAttributesRequest struct {
	RequestCommon `json:",inline"`
	Instance      string `json:"instance,omitempty"`
	InstanceName  string `json:"instance_name,omitempty"`
	Description   string `json:"description,omitempty"`
}

type ModifyInstanceAttributesResponse struct {
	ResponseCommon `json:",inline"`
	InstanceID     string `json:"instance_id,omitempty"`
	JobID          string `json:"job_id,omitempty"`
}
