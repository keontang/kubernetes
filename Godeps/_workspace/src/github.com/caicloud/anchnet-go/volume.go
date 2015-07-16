// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet instance related APIs.

//
// DescribeVolumes retrieves information of a list of volumes.
//
type DescribeVolumesRequest struct {
	RequestCommon `json:",inline"`
	VolumeIDs     []string       `json:"volumes,omitempty"`
	SearchWord    string         `json:"search_word,omitempty"`
	Status        []VolumeStatus `json:"status,omitempty"`
	Offset        int            `json:"offset,omitempty"`
	Limit         int            `json:"limit,omitempty"`
}

type DescribeVolumesResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                   `json:"total_count,omitempty"`
	ItemSet        []DescribeVolumesItem `json:"item_set,omitempty"`
}

type DescribeVolumesItem struct {
	VolumeID    string                  `json:"volume_id,omitempty"`
	VolumeName  string                  `json:"volume_name,omitempty"`
	Description string                  `json:"description,omitempty"`
	Size        int                     `json:"size,omitempty"` // Unit: GB
	Status      VolumeStatus            `json:"status,omitempty"`
	StatusTime  string                  `json:"status_time,omitempty"`
	VolumeType  VolumeType              `json:"volume_type"`
	CreateTime  string                  `json:"create_time,omitempty"`
	Instance    DescribeVolumesInstance `json:"instance,omitempty"`
}

type DescribeVolumesInstance struct {
	InstanceID   string `json:"instance_id,omitempty"`
	InstanceName string `json:"instance_name,omitempty"`
}

type VolumeStatus string

const (
	VolumeStatusPending   VolumeStatus = "pending"
	VolumeStatusAvailable VolumeStatus = "available"
	VolumeStatusInUse     VolumeStatus = "in-use"
	VolumeStatusSuspended VolumeStatus = "suspended"
	VolumeStatusDeleted   VolumeStatus = "deleted"
)

// Note VolumeType is the same as HDType. We separate them out due inconsistent naming in anchnet.
type VolumeType int

const (
	VolumeTypePerformance VolumeType = 0
	VolumeTypeCapacity    VolumeType = 1
)

//
// CreateVolumes creates given number of volumes.
//
type CreateVolumesRequest struct {
	RequestCommon `json:",inline"`
	VolumeName    string     `json:"volume_name,omitempty"`
	VolumeType    VolumeType `json:"volume_type"`    // Do not omit empty due to type 0
	Size          int        `json:"size,omitempty"` // min 10GB, max 1000GB, unit:GB
	Count         int        `json:"count,omitempty"`
}

type CreateVolumesResponse struct {
	ResponseCommon `json:",inline"`
	VolumeIDs      []string `json:"volumes,omitempty"` // IDs of created volumes
	JobID          string   `json:"job_id,omitempty"`  // Job ID in anchnet
}

//
// DeleteVolumes deletes a list of volumes.
//
type DeleteVolumesRequest struct {
	RequestCommon `json:",inline"`
	VolumeIDs     []string `json:"volumes,omitempty"`
}

type DeleteVolumesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"` // Job ID in anchnet
}

//
// AttachVolumes attaches a list of volumes to an instance.
//
type AttachVolumesRequest struct {
	RequestCommon `json:",inline"`
	InstanceID    string   `json:"instance,omitempty"` // ID of instance to attach volumes
	VolumeIDs     []string `json:"volumes,omitempty"`  // IDs of volumes
}

type AttachVolumesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// DetachVolumes detaches a list of volumes from their resources.
//
type DetachVolumesRequest struct {
	RequestCommon `json:",inline"`
	VolumeIDs     []string `json:"volumes,omitempty"` // IDs of volumes to detach
}

type DetachVolumesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ResizeVolumes resizes a list of volumes.
//
type ResizeVolumesRequest struct {
	RequestCommon `json:",inline"`
	VolumeIDs     []string `json:"volumes,omitempty"` // IDs of volumes to resize
	Size          int      `json:"size,omitempty"`    // Allow increase size only
}

type ResizeVolumesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}

//
// ModifyVolumeAttributes modifies attributes of a volume.
//
type ModifyVolumeAttributesRequest struct {
	RequestCommon `json:",inline"`
	VolumeID      string `json:"volume,omitempty"`
	VolumeName    string `json:"volume_name,omitempty"`
	Description   string `json:"description,omitempty"`
}

type ModifyVolumeAttributesResponse struct {
	ResponseCommon `json:",inline"`
	JobID          string `json:"job_id,omitempty"`
}
