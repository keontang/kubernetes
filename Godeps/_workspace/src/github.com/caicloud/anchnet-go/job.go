// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements all anchnet job related APIs. Job is not a type of resource
// in anchnet, it's used to query other request status.

//
// DescribeJobs retrieves information of a list of jobs.
//
type DescribeJobsRequest struct {
	RequestCommon `json:",inline"`
	JobIDs        []string `json:"jobs,omitempty"`
}

type DescribeJobsResponse struct {
	ResponseCommon `json:",inline"`
	TotalCount     int                `json:"total_count,omitempty"`
	ItemSet        []DescribeJobsItem `json:"item_set,omitempty"`
}

type DescribeJobsItem struct {
	JobAction  string    `json:"job_action,omitempty"`
	Status     JobStatus `json:"status,omitempty"`      // Status of the job
	StatusTime string    `json:"status_time,omitempty"` // Last date when job was changed
	CreateTime string    `json:"create_time,omitempty"` // Date when job was created
}

type JobStatus string

const (
	JobStatusPending    JobStatus = "pending"
	JobStatusWorking    JobStatus = "working"
	JobStatusSuccessful JobStatus = "successful"
	JobStatusFailed     JobStatus = "failed"
)
