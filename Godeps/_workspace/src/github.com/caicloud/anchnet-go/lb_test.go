// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestDescribeLoadBalancer tests that we send correct request to describe load balancer.
func TestDescribeLoadBalancer(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "limit": 10,
  "token": "E5I9QKJF1O2B5PXE68LG",
  "status": ["pending", "active", "stopped", "suspended"],
  "verbose": 1,
  "action": "DescribeLoadBalancers",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DescribeLoadBalancersResponse",
  "item_set": [
    {
      "is_applied": 1,
      "loadbalancer_id": "lb-0GFUQW2O",
      "loadbalancer_name": "wang_loanbar",
      "description": "51idc",
      "status": "active",
      "status_time": "2015-04-14 14:07:08",
      "loadbalancer_type": 1,
      "create_time": "2015-04-14 14:06:43",
      "listeners": [
      ],
      "eips": [
      ],
      "security_group": {
        "attachon": 605996,
        "id": 605220,
        "is_default": 1,
        "security_group_id": "sg-BP4N974S",
        "security_group_name": "default"
      }
    },
    {
      "is_applied": 1,
      "loadbalancer_id": "lb-FPB98Z0Z",
      "loadbalancer_name": "yy",
      "description": "51idc",
      "status": "active",
      "status_time": "2015-04-16 16:39:28",
      "loadbalancer_type": 1,
      "create_time": "2015-04-16 16:39:05",
      "listeners": [
      ],
      "eips": [
        {
          "eip_addr": "103.21.117.30",
          "eip_id": "eip-2WA55DIC",
          "eip_name": "103.21.117.30"
        }
      ],
      "security_group": {
        "attachon": 606062,
        "id": 605220,
        "is_default": 1,
        "security_group_id": "sg-BP4N974S",
        "security_group_name": "default"
      }
    }
  ],
  "code": 0,
  "total_count": 2
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DescribeLoadBalancersRequest{
		Verbose: 1,
		Limit:   10,
		Offset:  0,
		Status: []LoadBalancerStatus{
			LoadBalancerStatusPending,
			LoadBalancerStatusActive,
			LoadBalancerStatusStopped,
			LoadBalancerStatusSuspended,
		},
	}
	var response DescribeLoadBalancersResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DescribeLoadBalancersResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeLoadBalancersResponse",
			RetCode: 0,
			Code:    0,
		},
		TotalCount: 2,
		ItemSet: []DescribeLoadBalancersItem{
			{
				IsApplied:        LoadBalancerApplied,
				LoadbalancerID:   "lb-0GFUQW2O",
				LoadbalancerName: "wang_loanbar",
				Description:      "51idc",
				Status:           LoadBalancerStatusActive,
				StatusTime:       "2015-04-1414:07:08",
				CreateTime:       "2015-04-1414:06:43",
				LoadbalancerType: LoadBalancerType20K,
				Listeners:        []DescribeLoadBalancersListener{},
				Eips:             []DescribeLoadBalancersEIP{},
				SecurityGroup: DescribeLoadBalancersSecurityGroup{
					Attachon:          605996,
					ID:                605220,
					IsDefault:         1,
					SecurityGroupID:   "sg-BP4N974S",
					SecurityGroupName: "default",
				},
			},
			{
				IsApplied:        LoadBalancerApplied,
				LoadbalancerID:   "lb-FPB98Z0Z",
				LoadbalancerName: "yy",
				Description:      "51idc",
				Status:           LoadBalancerStatusActive,
				StatusTime:       "2015-04-1616:39:28",
				CreateTime:       "2015-04-1616:39:05",
				LoadbalancerType: LoadBalancerType20K,
				Listeners:        []DescribeLoadBalancersListener{},
				Eips: []DescribeLoadBalancersEIP{
					{
						EipID:   "eip-2WA55DIC",
						EipName: "103.21.117.30",
						EipAddr: "103.21.117.30",
					},
				},
				SecurityGroup: DescribeLoadBalancersSecurityGroup{
					Attachon:          606062,
					ID:                605220,
					IsDefault:         1,
					SecurityGroupID:   "sg-BP4N974S",
					SecurityGroupName: "default",
				},
			},
		},
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%+v, got \n%+v", expectedResponse, response)
	}
}

// TestCreateLoadBalancer tests that we send correct request to create load balancer.
func TestCreateLoadBalancer(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "product": {
    "fw": {
      "ref": "sg-EFBL5JC2"
    },
    "lb": {
      "name": "wang_test",
      "type": 1
    },
    "ip": [
      {
        "ref": "eip-2WA55DIC"
      }
    ]
  },
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "CreateLoadBalancer",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "loadbalancer_id": "lb-XU9DCS95",
  "action": "CreateLoadBalancerResponse",
  "code": 0,
  "job_id": "job-MO0OBCMY"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := CreateLoadBalancerRequest{
		Product: CreateLoadBalancerProduct{
			FW: CreateLoadBalancerFW{
				Ref: "sg-EFBL5JC2",
			},
			LB: CreateLoadBalancerLB{
				Name: "wang_test",
				Type: 1,
			},
			IP: []CreateLoadBalancerIP{
				{
					Ref: "eip-2WA55DIC",
				},
			},
		},
	}
	var response CreateLoadBalancerResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := CreateLoadBalancerResponse{
		ResponseCommon: ResponseCommon{
			Action:  "CreateLoadBalancerResponse",
			RetCode: 0,
			Code:    0,
		},
		LBID:  "lb-XU9DCS95",
		JobID: "job-MO0OBCMY",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestDeleteLoadBalancers tests that we send correct request to delete load balancers.
func TestDeleteLoadBalancers(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DeleteLoadBalancers",
  "zone": "ac1",
  "loadbalancers": [
    "lb-FPB98Z0Z"
  ]
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DeleteLoadBalancersResponse",
  "code": 0,
  "job_id": "job-UM9QAXC2"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DeleteLoadBalancersRequest{
		IPs:           []string{},
		Loadbalancers: []string{"lb-FPB98Z0Z"},
	}
	var response DeleteLoadBalancersResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DeleteLoadBalancersResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DeleteLoadBalancersResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-UM9QAXC2",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestModifyLoadBalancerAttributes tests that we send correct request to
// modify load balancer attributes.
func TestModifyLoadBalancerAttributes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "action": "ModifyLoadBalancerAttributes",
  "description": "gggg",
  "loadbalancer": "lb-1ZVNHRG5",
  "loadbalancer_name": "b-01",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "loadbalancer_id": "lb-1ZVNHRG5",
  "action": "ModifyLoadBalancerAttributesResponse",
  "code": 0,
  "job_id": "job-RFEVKUUP"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ModifyLoadBalancerAttributesRequest{
		Loadbalancer:     "lb-1ZVNHRG5",
		LoadbalancerName: "b-01",
		Description:      "gggg",
	}
	var response ModifyLoadBalancerAttributesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ModifyLoadBalancerAttributesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ModifyLoadBalancerAttributesResponse",
			RetCode: 0,
			Code:    0,
		},
		Loadbalancer: "lb-1ZVNHRG5",
		JobID:        "job-RFEVKUUP",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestAddLoadBalancerListeners tests that we send correct request to add listeners.
func TestAddLoadBalancerListeners(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "listeners": [{
    "listener_protocol": "tcp",
    "balance_mode": "roundrobin",
    "healthy_check_method": "tcp",
    "healthy_check_option": "10|5|2|5",
    "loadbalancer_listener_name": "gt",
    "session_sticky": "insert|50",
    "backend_protocol":"tcp",
    "listener_port": 80,
    "timeout": 50
  }],
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "AddLoadBalancerListeners",
  "loadbalancer": "lb-XU9DCS95",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "AddLoadBalancerListenersResponse",
  "code": 0,
  "loadbalancer_listeners": [
    "lbl-OKI5C36Z"
  ],
  "job_id": "job-3QHN28QY"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := AddLoadBalancerListenersRequest{
		Loadbalancer: "lb-XU9DCS95",
		Listeners: []AddLoadBalancerListenersListener{
			{
				LoadbalancerListenerName: "gt",
				BalanceMode:              BalanceModeRoundRobin,
				HealthyCheckMethod:       "tcp",
				HealthyCheckOption:       "10|5|2|5",
				ListenerProtocol:         ListenerProtocolTypeTCP,
				BackendProtocol:          BackendProtocolTypeTCP,
				SessionStick:             "insert|50",
				ListenerPort:             80,
				Timeout:                  50,
			},
		},
	}
	var response AddLoadBalancerListenersResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := AddLoadBalancerListenersResponse{
		ResponseCommon: ResponseCommon{
			Action:  "AddLoadBalancerListenersResponse",
			RetCode: 0,
			Code:    0,
		},
		LoadbalancerListeners: []string{"lbl-OKI5C36Z"},
		JobID: "job-3QHN28QY",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestDeleteLoadBalancerListeners tests that we send correct request to delete listeners.
func TestDeleteLoadBalancerListeners(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DeleteLoadBalancerListeners",
  "loadbalancer_listeners": [
    "lbl-OKI5C36Z"
  ],
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DeleteLoadBalancerListenersResponse",
  "code": 0,
  "job_id": "job-OG8CZ30J"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DeleteLoadBalancerListenersRequest{
		LoadbalancerListeners: []string{"lbl-OKI5C36Z"},
	}
	var response DeleteLoadBalancerListenersResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DeleteLoadBalancerListenersResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DeleteLoadBalancerListenersResponse",
			RetCode: 0,
			Code:    0,
		},
		JobID: "job-OG8CZ30J",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestDescribeLoadBalancerListeners tests that we send correct request to describe listeners.
func TestDescribeLoadBalancerListeners(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DescribeLoadBalancerListeners",
  "loadbalancer": "lb-XU9DCS95",
  "verbose":1,
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DescribeLoadBalancerListenersResponse",
  "item_set": [
    {
      "balance_mode": "roundrobin",
      "disabled": 0,
      "forwardfor": 0,
      "healthy_check_method": "tcp",
      "healthy_check_option": "10|5|2|5",
      "loadbalancer_listener_id": "lbl-SV2DLPI3",
      "loadbalancer_listener_name": "yy",
      "description": "51idc",
      "option": 0,
      "listener_port": 80,
      "listener_protocol": "http",
      "session_sticky": "insert|50",
      "timeout": 50,
      "create_time": "2015-04-16 13:43:34",
      "backends": [
        {
          "loadbalancer_listener_id": "lbb-A19KZ5KU",
          "loadbalancer_listener_name": "yy",
          "port": 8080,
          "create_time": "2015-04-16 13:46:39",
          "weight": 1
        }
      ],
      "loadbalancer_id": "lb-TBA0YUMM"
    }
  ],
  "code": 0
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DescribeLoadBalancerListenersRequest{
		Loadbalancer: "lb-XU9DCS95",
		Verbose:      1,
	}
	var response DescribeLoadBalancerListenersResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DescribeLoadBalancerListenersResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeLoadBalancerListenersResponse",
			RetCode: 0,
			Code:    0,
		},
		ItemSet: []DescribeLoadBalancerListenersItem{
			{
				BalanceMode:              BalanceModeRoundRobin,
				Disabled:                 0,
				ForwardFor:               0,
				CreateTime:               "2015-04-1613:43:34",
				Loadbalancer:             "lb-TBA0YUMM",
				LoadbalancerListener:     "lbl-SV2DLPI3",
				LoadbalancerListenerName: "yy",
				Description:              "51idc",
				HealthyCheckMethod:       "tcp",
				HealthyCheckOption:       "10|5|2|5",
				ListenerProtocol:         ListenerProtocolTypeHTTP,
				SessionStick:             "insert|50",
				ListenerPort:             80,
				Backends: []DescribeLoadBalancerListenersBackend{
					{
						LoadbalancerListener:     "lbb-A19KZ5KU",
						LoadbalancerListenerName: "yy",
						CreateTime:               "2015-04-1613:46:39",
						Port:                     8080,
						Weight:                   1,
					},
				},
			},
		},
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%+v, got \n%+v", expectedResponse, response)
	}
}

// TestAddLoadBalancerBackends tests that we send correct request to add backends.
func TestAddLoadBalancerBackends(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "backends": [{
    "port": 8080,
    "resource_id": "i-2H143W3Z",
    "weight": 1
  }],
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "AddLoadBalancerBackends",
  "loadbalancer_listener": "lbl-OKI5C36Z",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "AddLoadBalancerBackendsResponse",
  "code": 0,
  "loadbalancer_backends": [
    "lbb-V0FF855K"
  ],
  "job_id": "job-F2WO22V1"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := AddLoadBalancerBackendsRequest{
		LoadbalancerListener: "lbl-OKI5C36Z",
		Backends: []AddLoadBalancerBackendsBackend{
			{
				ResourceID: "i-2H143W3Z",
				Port:       8080,
				Weight:     1,
			},
		},
	}
	var response AddLoadBalancerBackendsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := AddLoadBalancerBackendsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "AddLoadBalancerBackendsResponse",
			RetCode: 0,
			Code:    0,
		},
		LoadbalancerBackends: []string{"lbb-V0FF855K"},
		JobID:                "job-F2WO22V1",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestDescribeLoadBalancerBackends tests that we send correct request to describe backends.
func TestDescribeLoadBalancerBackends(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "DescribeLoadBalancerBackends",
  "loadbalancer_listener": "lbl-OKI5C36Z",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DescribeLoadBalancerBackendsResponse",
  "item_set": [
    {
      "disabled": 0,
      "loadbalancer_backend_id": "lbb-9J15HR4F",
      "loadbalancer_backend_name": "yy",
      "description": "51idc",
      "loadbalancer_policy_id": "lbp-DST416LN",
      "port": 799,
      "resource_id": "i-SW55FS5W",
      "status": "down",
      "create_time": "2015-04-16 15:07:43",
      "weight": 1,
      "loadbalancer_listener_id": "lbl-OKI5C36Z",
      "resource": {
        "resource_id": "i-SW55FS5W",
        "resource_name": "4gg",
        "resource_type": "instance"
      }
    }
  ],
  "code": 0
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := DescribeLoadBalancerBackendsRequest{
		LoadbalancerListener: "lbl-OKI5C36Z",
	}
	var response DescribeLoadBalancerBackendsResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DescribeLoadBalancerBackendsResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeLoadBalancerBackendsResponse",
			RetCode: 0,
			Code:    0,
		},
		ItemSet: []DescribeLoadBalancerBackendsItem{
			{
				Disabled:                0,
				LoadbalancerBackend:     "lbb-9J15HR4F",
				LoadbalancerBackendName: "yy",
				Description:             "51idc",
				LoadbalancerPolicy:      "lbp-DST416LN",
				Port:                    799,
				ResourceID:              "i-SW55FS5W",
				Status:                  BackendStatusDown,
				Weight:                  1,
				CreateTime:              "2015-04-1615:07:43",
				LoadbalancerListener:    "lbl-OKI5C36Z",
				Resource: DescribeLoadBalancerBackendsResource{
					ResourceID:   "i-SW55FS5W",
					ResourceName: "4gg",
					ResourceType: "instance",
				},
			},
		},
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}
