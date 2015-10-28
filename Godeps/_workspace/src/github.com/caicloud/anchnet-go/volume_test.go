// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestDescribeVolumes tests that we send correct request to describe volumes.
func TestDescribeVolumes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "limit": 10,
  "search_word": "hh",
  "status": ["pending", "available", "in-use", "suspended"],
  "volumes": ["vol-75LIXUQD"],
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DescribeVolumes",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DescribeVolumesResponse",
  "item_set": [
    {
      "volume_id": "vol-75LIXUQD",
      "volume_name": "hh",
      "description": "51idc",
      "size": "10",
      "status": "in-use",
      "status_time": "2015-02-26 15:19:48",
      "volume_type": "0",
      "create_time": "2015-02-26 13:24:44",
      "instance": {
        "instance_id": "i-UN3CH6YH",
        "instance_name": "yy"
      }
    }
  ],
  "code": 0,
  "total_count": 1
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DescribeVolumesRequest{
		VolumeIDs:  []string{"vol-75LIXUQD"},
		Limit:      10,
		Offset:     0,
		SearchWord: "hh",
		Status:     []VolumeStatus{VolumeStatusPending, VolumeStatusAvailable, VolumeStatusInUse, VolumeStatusSuspended},
	}
	var response DescribeVolumesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DescribeVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		TotalCount: 1,
		ItemSet: []DescribeVolumesItem{
			{
				VolumeID:    "vol-75LIXUQD",
				VolumeName:  "hh",
				Description: "51idc",
				Size:        "10",
				Status:      VolumeStatusInUse,
				StatusTime:  "2015-02-2615:19:48",
				VolumeType:  VolumeTypePerformance,
				CreateTime:  "2015-02-2613:24:44",
				Instance: DescribeVolumesInstance{
					InstanceID:   "i-UN3CH6YH",
					InstanceName: "yy",
				},
			},
		},
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestCreateVolumes tests that we send correct request to create volumes.
func TestCreateVolumes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "volume_name": "21",
  "count": 1,
  "size": 10,
  "volume_type": "0",
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

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := CreateVolumesRequest{
		VolumeName: "21",
		VolumeType: VolumeTypePerformance,
		Count:      1,
		Size:       10,
	}
	var response CreateVolumesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := CreateVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "CreateVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		VolumeIDs: []string{"vol-SHPH11TH"},
		JobID:     "job-G554X3LT",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
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

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DeleteVolumesRequest{
		VolumeIDs: []string{"vol-A8RXJQRC"},
	}
	var response DeleteVolumesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DeleteVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DeleteVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-V2SOOFXR",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestAttachVolumes tests that we send correct request to attach volumes.
func TestAttachVolumes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "zone": "ac1",
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

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := AttachVolumesRequest{
		InstanceID: "i-7QAQCZ2E",
		VolumeIDs:  []string{"vol-EAWEJ5RI", "vol-A8RXJQRC"},
	}
	var response AttachVolumesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := AttachVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "AttachVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-OT7LFB3I",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestDetachVolumes tests that we send correct request to detach volumes.
func TestDetachVolumes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "zone": "ac1",
  "volumes": [
    "vol-EAWEJ5RI",
    "vol-A8RXJQRC"
  ],
  "token": "E5I9QKJF1O2B5PXE68LG",
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

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DetachVolumesRequest{
		VolumeIDs: []string{"vol-EAWEJ5RI", "vol-A8RXJQRC"},
	}
	var response DetachVolumesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DetachVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DetachVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-JRB87I5T",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestResizeVolumes tests that we send correct request to resize volumes.
func TestResizeVolumes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "zone": "ac1",
  "volumes": [
    "vol-EAWEJ5RI"
  ],
  "size": 30,
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "ResizeVolumes"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action":" ResizeVolumesResponse",
  "code":0,
  "job_id": "job-OZNXSPZO"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ResizeVolumesRequest{
		VolumeIDs: []string{"vol-EAWEJ5RI"},
		Size:      30,
	}
	var response ResizeVolumesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ResizeVolumesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ResizeVolumesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-OZNXSPZO",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestModifyVolumeAttributes tests that we send correct request to modify volume attributes.
func TestModifyVolumeAttributes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "zone":"ac1",
  "volume":"vol-GTQZP5KW",
  "volume_name":"hh",
  "description":"bobo",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "action":"ModifyVolumeAttributes"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "volume_id":"vol-GTQZP5KW",
  "action":"ModifyVolumeAttributesResponse",
  "code":0,
  "job_id":"job-6AHS7MN3"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ModifyVolumeAttributesRequest{
		VolumeID:    "vol-GTQZP5KW",
		VolumeName:  "hh",
		Description: "bobo",
	}
	var response ModifyVolumeAttributesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ModifyVolumeAttributesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ModifyVolumeAttributesResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-6AHS7MN3",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}
