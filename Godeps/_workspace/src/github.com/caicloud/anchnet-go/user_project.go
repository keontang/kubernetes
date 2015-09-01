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
