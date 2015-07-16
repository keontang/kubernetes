// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.
package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestSendRequest tests c.SendRequest.
func TestSendRequest(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "instances": [
    "i-G74Q69NJ",
    "i-OAEZPC6C"
  ],
  "force": 1,
  "zone": "ac1",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "StopInstances"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0 ,
  "action": "StopInstancesResponse",
  "code": 0,
  "job_id": "job-ZUBILH5I"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	// The acutal type of request doesn't matter (here we use StopInstancesRequest).
	tests := []struct {
		expectError     bool
		sendRequestFunc func(request StopInstancesRequest, response *StopInstancesResponse) error
	}{
		{
			expectError: false,
			sendRequestFunc: func(request StopInstancesRequest, response *StopInstancesResponse) error {
				// Send request with request struct and response pointer is ok.
				return c.SendRequest(request, response)
			},
		},
		{
			expectError: false,
			sendRequestFunc: func(request StopInstancesRequest, response *StopInstancesResponse) error {
				// Send request with request pointer and response pointer is ok.
				return c.SendRequest(&request, response)
			},
		},
		{
			expectError: true,
			sendRequestFunc: func(request StopInstancesRequest, response *StopInstancesResponse) error {
				// Send request with response struct is not ok.
				return c.SendRequest(request, *response)
			},
		},
	}

	for _, test := range tests {
		request := StopInstancesRequest{
			InstanceIDs: []string{"i-G74Q69NJ", "i-OAEZPC6C"},
			Force:       ForceStop,
		}
		var response StopInstancesResponse
		err := test.sendRequestFunc(request, &response)
		if test.expectError == true && err == nil {
			t.Errorf("Unexpected nil error %v", err)
		}
		if test.expectError == false && err != nil {
			t.Errorf("Unexpected non-nil error %v", err)
		}

		if test.expectError == false {
			expectedResponse := StopInstancesResponse{
				ResponseCommon: ResponseCommon{
					Action:  "StopInstancesResponse",
					Code:    0,
					RetCode: 0,
				},
				JobID: "job-ZUBILH5I",
			}
			if !reflect.DeepEqual(expectedResponse, response) {
				t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
			}
		}
	}
}
