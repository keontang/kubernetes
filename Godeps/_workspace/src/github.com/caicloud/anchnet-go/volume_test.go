// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestCreateVolumes tests that we send correct request to create volumes.
func TestCreateVolumes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "volume_name": "21",
  "count": 1,
  "size": 10,
  "volume_type": 0,
  "zone": "ac1",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "action": "CreateVolumes"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "CreateVolumesResponse",
  "code": 0,
  "volumes": [
    "vol-SHPH11TH"
  ],
  "job_id": "job-G554X3LT"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := CreateVolumesRequest{
		VolumeName: "21",
		Count:      1,
		Size:       10,
		VolumeType: VolumeTypePerformance,
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.CreateVolumes(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &CreateVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "CreateVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		Volumes: []string{"vol-SHPH11TH"},
		JobID:   "job-G554X3LT",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}

// TestDeleteVolumes tests that we send correct request to delete volumes.
func TestDeleteVolumes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "zone": "ac1",
  "volumes": [
    "vol-A8RXJQRC "
  ],
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DeleteVolumes"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DeleteVolumesResponse",
  "code": 0,
  "job_id": "job-V2SOOFXR"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := DeleteVolumesRequest{
		Volumes: []string{"vol-A8RXJQRC"},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.DeleteVolumes(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &DeleteVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DeleteVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-V2SOOFXR",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}

// TestAttachVolumes tests that we send correct request to attach volumes.
func TestAttachVolumes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "zone" :"ac1",
  "volumes": [
    "vol-EAWEJ5RI",
    "vol-A8RXJQRC"
  ],
  "instance": "i-7QAQCZ2E",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "action": " AttachVolumes"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action":" AttachVolumesResponse",
  "code": 0,
  "job_id": "job-OT7LFB3I"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := AttachVolumesRequest{
		Instance: "i-7QAQCZ2E",
		Volumes:  []string{"vol-EAWEJ5RI", "vol-A8RXJQRC"},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.AttachVolumes(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &AttachVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "AttachVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-OT7LFB3I",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}

// TestDetachVolumes tests that we send correct request to detach volumes.
func TestDetachVolumes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "zone" :"ac1",
  "volumes":[
    "vol-EAWEJ5RI",
    "vol-A8RXJQRC"
  ],
  "token":"E5I9QKJF1O2B5PXE68LG",
  "action": "DetachVolumes"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action":" DetachVolumesResponse",
  "code":0,
  "job_id": "job-JRB87I5T"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	body := DetachVolumesRequest{
		Volumes: []string{"vol-EAWEJ5RI", "vol-A8RXJQRC"},
	}

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	resp, err := c.DetachVolumes(body)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}
	if resp == nil {
		t.Errorf("Unexpected nil response")
	}

	expectedResponseBody := &DetachVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DetachVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-JRB87I5T",
	}
	if !reflect.DeepEqual(expectedResponseBody, resp) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponseBody, resp)
	}
}
