// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestCreateUserProject tests that we send correct request to create user project.
func TestCreateUserProject(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "loginId": "test@caicloud.io",
  "sex": "M",
  "project_name": "test",
  "email": "test@caicloud.io",
  "contactName": "test",
  "mobile": "13655555555",
  "loginPasswd": "caicloud2015ABC",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "CreateUserProject",
  "zone": "ac1"
}
`)
	fakeResponse := RemoveWhitespaces(`
{
  "api_id": "pro-LW8FN8JY",
  "ret_code": 0,
  "action": "CreateUserProjectResponse",
  "code": 0,
  "job_id": "job-9MF4ORXN"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	request := CreateUserProjectRequest{
		LoginId:     "test@caicloud.io",
		Sex:         "M",
		ProjectName: "test",
		Email:       "test@caicloud.io",
		ContactName: "test",
		Mobile:      "13655555555",
		LoginPasswd: "caicloud2015ABC",
	}
	var response CreateUserProjectResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := CreateUserProjectResponse{
		ResponseCommon: ResponseCommon{
			Action:  "CreateUserProjectResponse",
			RetCode: 0,
			Code:    0,
		},
		ApiId: "pro-LW8FN8JY",
		JobID: "job-9MF4ORXN",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}

}

// TestTransfer tests that we send correct request to tranfer money to sub account
func TestTransfer(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "userId": 503744,
  "value": "1",
  "why": "test",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "Transfer",
  "zone": "ac1"
}
`)
	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "TransferResponse",
  "code": 0
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	request := TransferRequest{
		UserId: 503744,
		Value:  "1",
		Why:    "test",
	}
	var response TransferResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := TransferResponse{
		ResponseCommon: ResponseCommon{
			Action:  "TransferResponse",
			RetCode: 0,
			Code:    0,
		},
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}

}
