// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

// Implements anchnet user project related APIs

//
// CreateUserProject creates a user project under anchnet account.
//
type CreateUserProjectRequest struct {
	RequestCommon `json:",inline"`
	LoginId       string `json:"loginId,omitempty"`
	Sex           string `json:"sex,omitempty"`
	ProjectName   string `json:"project_name,omitempty"`
	Email         string `json:"email,omitempty"`
	ContactName   string `json:"contactName,omitempty"`
	Mobile        string `json:"mobile,omitempty"`
	LoginPasswd   string `json:"loginPasswd,omitempty"`
}

type CreateUserProjectResponse struct {
	ResponseCommon `json:",inline"`
	ApiId          string `json:"api_id,omitempty"`
	JobID          string `json:"job_id,omitempty"`
}

type DescribeProjectsRequest struct {
	RequestCommon `json:",inline"`
	Projects      string `json:"projects,omitempty"`
	SearchWord    string `json:"search_word,omitempty"`
}

//
// DescribeProjects returns the information of a project
//
type DescribeProjectsResponse struct {
	ResponseCommon `json:",inline"`
	ItemSet        []DescribeProjectsItem `json:"item_set,omitempty"`
}

type DescribeProjectsItem struct {
	ProjectType string `json:"project_type,omitempty"`
	ProjectId   string `json:"project_id,omitempty"`
	ProjectName string `json:"project_name,omitempty"`
	UserId      int    `json:"userid,omitempty"`
	Status      string `json:"status,omitempty"`
}

//
// Transfer transfers money to sub account
//
type TransferRequest struct {
	RequestCommon `json:",inline"`
	UserId        int    `json:"userId,omitempty"`
	Value         string `json:"value,omitempty"`
	Why           string `json:"why,omitempty"`
}

type TransferResponse struct {
	ResponseCommon `json:",inline"`
}
