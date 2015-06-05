// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"github.com/caicloud/anchnet-go/vendor/_nuts/github.com/mitchellh/mapstructure"
)

// Implements all anchnet instance related APIs. [x] means done, [ ] means not done yet.
//   [ ] DescribeVolumes
//   [x] CreateVolumes
//   [x] DeleteVolumes
//   [x] AttachVolumes
//   [x] DetachVolumes
//   [ ] ResizeVolumes
//   [ ] ModifyVolumeAttributes

// Note VolumeType is the same as HDType. We separate them out due to inconsistency in anchnet.
type VolumeType int

const (
	VolumeTypePerformance VolumeType = 0
	VolumeTypeCapacity    VolumeType = 1
)

// CreateVolumesRequest contains all information needed to create volumes.
type CreateVolumesRequest struct {
	RequestCommon `json:",inline"`
	VolumeName    string     `json:"volume_name,omitempty"`
	Count         int        `json:"count,omitempty"`
	Size          int        `json:"size,omitempty"` // min 10GB, max 1000GB, unit:GB
	VolumeType    VolumeType `json:"volume_type"`    // Do not omit empty due to type 0
}

// CreateVolumesResponse contains all information returned from anchnet server.
type CreateVolumesResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	Volumes        []string `json:"volumes,omitempty" mapstructure:"volumes"` // IDs of created volumes
	JobID          string   `json:"job_id,omitempty" mapstructure:"job_id"`   // Job ID in anchnet
}

// CreateVolumes creates volumes.
func (c *Client) CreateVolumes(request CreateVolumesRequest) (*CreateVolumesResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "CreateVolumes"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result CreateVolumesResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

// DeleteVolumesRequest contains all information needed to delete volumes.
type DeleteVolumesRequest struct {
	RequestCommon `json:",inline"`
	Volumes       []string `json:"volumes,omitempty"`
}

// DeleteVolumesResponse contains all information returned from anchnet server.
type DeleteVolumesResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"` // Job ID in anchnet
}

// DeleteVolumes deletes volumes. Volume needs to be detached from instance before deleting.
func (c *Client) DeleteVolumes(request DeleteVolumesRequest) (*DeleteVolumesResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "DeleteVolumes"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result DeleteVolumesResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type AttachVolumesRequest struct {
	RequestCommon `json:",inline"`
	Instance      string   `json:"instance,omitempty"` // ID of instance to attach volumes
	Volumes       []string `json:"volumes,omitempty"`  // IDs of volumes
}

type AttachVolumesResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"`
}

// AttachVolumes attach volumes to an instance.
// http://cloud.51idc.com/help/api/network/Attachvolume.html
func (c *Client) AttachVolumes(request AttachVolumesRequest) (*AttachVolumesResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "AttachVolumes"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result AttachVolumesResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}

type DetachVolumesRequest struct {
	RequestCommon `json:",inline"`
	Volumes       []string `json:"volumes,omitempty"` // IDs of volumes to detach
}

type DetachVolumesResponse struct {
	ResponseCommon `json:",inline" mapstructure:",squash"`
	JobID          string `json:"job_id,omitempty" mapstructure:"job_id"`
}

// DetachVolumes detach volumes; no instance id is needed.
// http://cloud.51idc.com/help/api/network/Detachvolume.html
func (c *Client) DetachVolumes(request DetachVolumesRequest) (*DetachVolumesResponse, error) {
	request.RequestCommon.Token = c.auth.PublicKey
	request.RequestCommon.Action = "DetachVolumes"
	request.RequestCommon.Zone = "ac1" // Only one zone for now
	resp, err := c.sendRequest(request)
	if err != nil {
		return nil, err
	}

	var result DetachVolumesResponse
	err = mapstructure.Decode(resp, &result)
	if err != nil {
		return nil, err
	}

	return &result, nil
}
