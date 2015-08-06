// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet instance related APIs.

//
// DescribeInstances retrieves information of a list of instances.
//
type DescribeInstancesRequest struct {
	RequestCommon `json:",inline"`
	InstanceIDs   []string         `json:"instances,omitempty"`
	SearchWord    string           `json:"search_word,omitempty"`
	Status        []InstanceStatus `json:"status,omitempty"`
	Verbose       int              `json:"verbose,omitempty"`
	Offset        int              `json:"offset,omitempty"`
	Limit         int              `json:"limit,omitempty"`
}

type DescribeInstancesResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                     `json:"total_count,omitempty"`
	ItemSet        []DescribeInstancesItem `json:"item_set,omitempty"`
}

type DescribeInstancesItem struct {
	InstanceID    string                         `json:"instance_id,omitempty"`
	InstanceName  string                         `json:"instance_name,omitempty"`
	Description   string                         `json:"description,omitempty"`
	VcpusCurrent  int                            `json:"vcpus_current,omitempty"`  // Number of CPU cores
	MemoryCurrent int                            `json:"memory_current,omitempty"` // Memory size, unit: MB
	Status        InstanceStatus                 `json:"status,omitempty"`         // Status of the instance
	StatusTime    string                         `json:"status_time,omitempty"`    // Last date when instance was changed
	CreateTime    string                         `json:"create_time,omitempty"`    // Date when instance was created
	Vxnets        []DescribeInstancesVxnet       `json:"vxnets,omitempty"`         // SDN network information of the instance
	EIP           DescribeInstancesEIP           `json:"eip,omitempty"`            // External IP information of the ip
	Image         DescribeInstancesImage         `json:"image,omitempty"`          // Image information of the instance
	Volumes       []DescribeInstancesVolume      `json:"volumes,omitempty"`        // Volume information of the instance
	SecurityGroup DescribeInstancesSecurityGroup `json:"security_group,omitempty"` // Security group (firewall) information of the instance
	VolumeIDs     []string                       `json:"volume_ids,omitempty"`     // Volume IDs, maybe duplicate with Volumes
}

type DescribeInstancesVxnet struct {
	VxnetID   string    `json:"vxnet_id,omitempty"`
	VxnetName string    `json:"vxnet_name,omitempty"`
	VxnetType VxnetType `json:"vxnet_type"`           // SDN network type, this maybe duplicate with Systype (Do not omit empty due to type 0)
	NicID     string    `json:"nic_id,omitempty"`     // MAC address of the instance
	PrivateIP string    `json:"private_ip,omitempty"` // IP address of the instance in the SDN network
	Systype   string    `json:"systype,omitempty"`    // SDN network type, one of "priv" and "pub"
}

type DescribeInstancesEIP struct {
	EipID   string `json:"eip_id,omitempty"`
	EipName string `json:"eip_name,omitempty"`
	EipAddr string `json:"eip_addr,omitempty"`
}

type DescribeInstancesImage struct {
	ImageID       string             `json:"image_id,omitempty"`
	ImageName     string             `json:"image_name,omitempty"`
	ImageSize     int                `json:"image_size,omitempty"`
	OsFamily      ImageOsFamily      `json:"os_family,omitempty"`
	Platform      ImagePlatform      `json:"platform,omitempty"`
	ProcessorType ImageProcessorType `json:"processor_type,omitempty"`
	Provider      ImageProvider      `json:"provider,omitempty"`
}

type DescribeInstancesVolume struct {
	// Note Size and VolumeType is string instead of int, sxxk. They are integers
	// when using DescribeVolumes.
	Size       string `json:"size,omitempty"`
	VolumeID   string `json:"volume_id,omitempty"`
	VolumeName string `json:"volume_name,omitempty"`
	VolumeType string `json:"volume_type,omitempty"`
}

type DescribeInstancesSecurityGroup struct {
	Attachon          int    `json:"attachon,omitempty"`
	IsDefault         int    `json:"is_default"` // Do not omit empty due to is_default=0
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

type ImagePlatform string

const (
	ImagePlatformWindows ImagePlatform = "windows"
	ImagePlatformLinux   ImagePlatform = "linux"
)

type ImageOsFamily string

const (
	// Note this is not a complete list.
	ImageOsFamilyWindows ImageOsFamily = "windows"
	ImageOsFamilyUbuntu  ImageOsFamily = "ubuntu"
	ImageOsFamilyCentos  ImageOsFamily = "centos"
)

type ImageProcessorType string

const (
	InstanceProcessor32bit ImageProcessorType = "32bit"
	InstanceProcessor64bit ImageProcessorType = "64bit"
)

type ImageProvider string

const (
	ImageProviderSelf   ImageProvider = "self"
	ImageProviderSystem ImageProvider = "system"
)

//
// RunInstancesRequest creates and runs an instances.
//
type RunInstancesRequest struct {
	RequestCommon `json:",inline"`
	Product       RunInstancesProduct `json:"product,omitempty"`
}

type RunInstancesResponse struct {
	ResponseCommon `json:",inline"`
	InstanceIDs    []string `json:"instances,omitempty"` // IDs of created instances
	VolumeIDs      []string `json:"volumes,omitempty"`   // IDs of created volumes
	EipIDs         []string `json:"eips,omitempty"`      // IDs of created public IP
	JobID          string   `json:"job_id,omitempty"`    // Job ID in anchnet
}

// RunInstancesProduct is a wrapper around RunInstancesProduct; it describes an anchnet product.
type RunInstancesProduct struct {
	Cloud RunInstancesCloud `json:"cloud,omitempty"`
}

// RunInstancesCloud describes information of cloud servers, including: machine resources,
// disk/volumes, networks, etc.
type RunInstancesCloud struct {
	// VM contains parameters for the virtual machine.
	VM RunInstancesVM `json:"vm,omitempty"`
	// HD contains parameters for hard disks (volumes).
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

// HDType is the same as VolumeType: we use different type due to inconsistent naming in anchnet.
type HDType int

const (
	HDTypePerformance HDType = 0
	HDTypeCapacity    HDType = 1
)

// RunInstancesHardDisk sets parameters for a hard disk.
type RunInstancesHardDisk struct {
	// Following fields are used when creating hard disk along with new instance.
	Name string `json:"name,omitempty"`
	Type HDType `json:"type"`           // Type of the disk, see above (Do not omit empty due to type 0)
	Unit int    `json:"unit,omitempty"` // In GB, e.g. 10 means 10GB HardDisk

	// Following fields are used when using existing hard disks.
	HdIDs []string `json:"hd,omitempty"` // IDs of existing hard disk; they will be attached to the new machine
}

// RunInstancesNet1 sets SDN information.
type RunInstancesNet1 struct {
	// Following fields are used when creating vxnet along with new instance.
	VxnetName string `json:"vxnet_name,omitempty"`
	Checked   bool   `json:"checked,omitempty"` // If true, the new machine will be added to the network

	// Following fields are used when using existing vxnet.
	VxnetIDs []string `json:"vxnet_id,omitempty"` // IDs of existing SDN network; the new machine wll be added to the network
}

// RunInstancesIP sets parameters for public IP (EIP).
type RunInstancesIP struct {
	// Following fields are used when creating eip along with new instance.
	Bandwidth int         `json:"bw,omitempty"` // In MB/s
	IPGroup   IPGroupType `json:"ip_group,omitempty"`

	// Following fields are used when using existing eip.
	EipID string `json:"ip,omitempty"` // ID of existing EIP; the ip will be assigned to the new machine
}

//
// TerminateInstances terminates a list of instances. External IPs and volumes attached
// to the instance won't be deleted unless explicitly specified in the request.
//
type TerminateInstancesRequest struct {
	RequestCommon `json:",inline"`
	InstanceIDs   []string `json:"instances,omitempty"`
	VolumeIDs     []string `json:"vols,omitempty"`
	EipIDs        []string `json:"ips,omitempty"`
}

type TerminateInstancesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"` // Job ID in anchnet
}

//
// StartInstances starts a list of instances.
//
type StartInstancesRequest struct {
	RequestCommon `json:",inline"`
	InstanceIDs   []string `json:"instances,omitempty"`
}

type StartInstancesResponse struct {
	ResponseCommon `json",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// StopInstances stops a list of instances. External IPs and volumes attached to the
// instance won't be deleted unless explicitly specified in the request.
//
type StopInstancesRequest struct {
	RequestCommon `json:",inline"`
	InstanceIDs   []string         `json:"instances,omitempty"`
	Force         InstanceStopType `json:"force"` // Do not omitempty due to NonForceStop=0
}

type StopInstancesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"` // Job ID in anchnet
}

// InstanceStopType defines how to stop the machine.
type InstanceStopType int

const (
	NonForceStop InstanceStopType = 0
	ForceStop    InstanceStopType = 1
)

//
// RestartInstancesRequest restarts a list of instances.
//
type RestartInstancesRequest struct {
	RequestCommon `json:",inline"`
	InstanceIDs   []string `json:"instances,omitempty"`
}

type RestartInstancesResponse struct {
	ResponseCommon `json",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ResetLoginPasswdRequest resets password for a list of instances. The instance
// must be shutdown first.
//
type ResetLoginPasswdRequest struct {
	RequestCommon `json:",inline"`
	InstanceIDs   []string `json:"instances,omitempty"`
	LoginPasswd   string   `json:"login_passwd,omitempty"`
}

type ResetLoginPasswdResponse struct {
	ResponseCommon `json",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ModifyInstanceAttributesRequest modifies name, description of a single instance.
//
type ModifyInstanceAttributesRequest struct {
	RequestCommon `json:",inline"`
	InstanceID    string `json:"instance,omitempty"`
	InstanceName  string `json:"instance_name,omitempty"`
	Description   string `json:"description,omitempty"`
}

type ModifyInstanceAttributesResponse struct {
	ResponseCommon `json:",inline"`
	InstanceID     string `json:"instance_id,omitempty"`
	JobID          string `json:"job_id,omitempty"`
}
