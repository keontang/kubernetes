// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package anchnet

import (
	"net/http/httptest"
	"reflect"
	"testing"
)

// TestDescribeInstances tests that we send correct request to describe instances.
func TestDescribeInstances(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "limit": 10,
  "status": ["pending", "running", "stopped", "suspended"],
  "search_word":"wet",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "verbose":1,
  "zone": "ac1",
  "action": "DescribeInstances",
  "instances":["i-HNFNPM56"]
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "DescribeInstancesResponse",
  "item_set": [
    {
      "vcpus_current": 1,
      "instance_id": "i-GQZBQ6CP",
      "memory_current": 1024,
      "instance_name": "gao_cent",
      "description": "",
      "status": "running",
      "status_time": "2015-02-15 11:10:37",
      "create_time": "2015-02-15 11:10:37",
      "transition_status": "",
      "vxnets": [
        {
          "nic_id": "52:54:be:c5:38:12",
          "private_ip": "10.57.20.131",
          "vxnet_id": "vxnet-0",
          "vxnet_name": "vxnet1",
          "systype": "pub",
          "vxnet_type": 1
        },
        {
          "nic_id": "52:54:ed:23:99:30",
          "private_ip": "",
          "vxnet_id": "vxnet-VD3VL0YT",
          "vxnet_name": "vxnet2",
          "systype": "priv",
          "vxnet_type": 0
        },
        {
          "nic_id": "52:54:c1:c5:18:79",
          "private_ip": "",
          "vxnet_id": "vxnet-MTQX70SU",
          "vxnet_name": "vxnet3",
          "systype": "priv",
          "vxnet_type": 0
        }
      ],
      "eip": {
        "eip_addr": "103.21.116.122",
        "eip_id": "eip-2Q76L2B9",
        "eip_name": "103.21.116.122"
      },
      "image": {
        "image_id": "centos65x64d",
        "image_name": "CentOS 6.5 64bit",
        "os_family": "centos",
        "platform": "linux",
        "processor_type": "64bit",
        "provider": "system",
        "image_size": 20
      },
      "volumes": [
        {
          "volume_id": "vom-QBU4NHSP",
          "volume_name": "gao",
          "size": "10",
          "volume_type": "1"
        }
      ],
      "security_group": {
        "attachon": 634824,
        "is_default": 1,
        "security_group_id": "sg-ZEVKCIAT",
        "security_group_name": "default_fireware"
      },
      "volume_ids": [
        "vom-QBU4NHSP"
      ]
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

	request := DescribeInstancesRequest{
		InstanceIDs: []string{"i-HNFNPM56"},
		Verbose:     1,
		Offset:      0,
		SearchWord:  "wet",
		Limit:       10,
		Status:      []InstanceStatus{InstanceStatusPending, InstanceStatusRunning, InstanceStatusStopped, InstanceStatusSuspended},
	}
	var response DescribeInstancesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := DescribeInstancesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "DescribeInstancesResponse",
			Code:    0,
			RetCode: 0,
			Message: "",
		},
		TotalCount: 1,
		ItemSet: []DescribeInstancesItem{
			{
				InstanceID:    "i-GQZBQ6CP",
				InstanceName:  "gao_cent",
				Description:   "",
				Status:        InstanceStatusRunning,
				VcpusCurrent:  1,
				MemoryCurrent: 1024,
				StatusTime:    "2015-02-1511:10:37",
				CreateTime:    "2015-02-1511:10:37",
				Vxnets: []DescribeInstancesVxnet{
					{
						VxnetID:   "vxnet-0",
						VxnetName: "vxnet1",
						VxnetType: 1,
						NicID:     "52:54:be:c5:38:12",
						PrivateIP: "10.57.20.131",
						Systype:   "pub",
					},
					{
						VxnetID:   "vxnet-VD3VL0YT",
						VxnetName: "vxnet2",
						VxnetType: 0,
						NicID:     "52:54:ed:23:99:30",
						PrivateIP: "",
						Systype:   "priv",
					},
					{
						VxnetID:   "vxnet-MTQX70SU",
						VxnetName: "vxnet3",
						VxnetType: 0,
						NicID:     "52:54:c1:c5:18:79",
						PrivateIP: "",
						Systype:   "priv",
					},
				},
				EIP: DescribeInstancesEIP{
					EipID:   "eip-2Q76L2B9",
					EipName: "103.21.116.122",
					EipAddr: "103.21.116.122",
				},
				Image: DescribeInstancesImage{
					ImageID:       "centos65x64d",
					ImageName:     "CentOS6.564bit",
					ImageSize:     20,
					OsFamily:      "centos",
					Platform:      "linux",
					ProcessorType: "64bit",
					Provider:      "system"},
				VolumeIDs: []string{"vom-QBU4NHSP"},
				Volumes: []DescribeInstancesVolume{
					{
						Size:       "10",
						VolumeID:   "vom-QBU4NHSP",
						VolumeName: "gao",
						VolumeType: "1",
					},
				},
				SecurityGroup: DescribeInstancesSecurityGroup{
					Attachon:          634824,
					IsDefault:         1,
					SecurityGroupID:   "sg-ZEVKCIAT",
					SecurityGroupName: "default_fireware",
				},
			},
		},
	}

	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestRunInstances tests that we send correct request to run instances.
func TestRunInstances(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "product": {
    "cloud": {
      "amount": 1,
      "vm": {
        "name": "test",
        "login_mode": "pwd",
        "mem": 1024,
        "cpu": 1,
        "image_id": "centos65x64d",
        "password": "1111ssSS"
      },
      "hd": [
        {
          "name": "test1",
          "type": 0,
          "unit": 10
        },
        {
          "name": "test2",
          "type": 0,
          "unit": 10
        }
      ],
      "net0": true,
      "net1": [
        {
          "vxnet_name": "test",
          "checked": true
        }
      ],
      "ip": {
        "bw": 1,
        "ip_group": "eipg-00000000"
      }
    }
  },
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "RunInstances",
  "zone": "ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "RunInstancesResponse",
  "code": 0,
  "volumes": [
    "vol-ZEU3OAQ7",
    "vol-TSNPJC5F",
    "vol-687S884C"
  ],
  "instances": [
    "i-PX4SFNMW",
    "i-88G1K070",
    "i-Q42TL4J4"
  ],
  "eips": [
    "eip-52QPTREJ",
    "eip-Q2C2067R",
    "eip-4OQM5GDN"
  ],
  "job_id": "job-X9FQT4CS"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := RunInstancesRequest{
		Product: RunInstancesProduct{
			Cloud: RunInstancesCloud{
				Amount: 1,
				VM: RunInstancesVM{
					Name:      "test",
					LoginMode: LoginModePwd,
					Mem:       1024,
					Cpu:       1,
					Password:  "1111ssSS",
					ImageID:   "centos65x64d",
				},
				HD: []RunInstancesHardDisk{
					{
						Name: "test1",
						Unit: 10,
						Type: HDTypePerformance,
					},
					{
						Name: "test2",
						Unit: 10,
						Type: HDTypePerformance,
					},
				},
				Net0: true,
				Net1: []RunInstancesNet1{
					{
						VxnetName: "test",
						Checked:   true,
					},
				},
				IP: RunInstancesIP{
					IPGroup:   "eipg-00000000",
					Bandwidth: 1,
				},
			},
		},
	}
	var response RunInstancesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := RunInstancesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "RunInstancesResponse",
			RetCode: 0,
			Code:    0,
		},
		InstanceIDs: []string{"i-PX4SFNMW", "i-88G1K070", "i-Q42TL4J4"},
		VolumeIDs:   []string{"vol-ZEU3OAQ7", "vol-TSNPJC5F", "vol-687S884C"},
		EipIDs:      []string{"eip-52QPTREJ", "eip-Q2C2067R", "eip-4OQM5GDN"},
		JobID:       "job-X9FQT4CS",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestTerminateInstances tests that we send correct request to terminate instances.
func TestTerminateInstances(t *testing.T) {
	// Note "ips" and "vols" are empty.
	expectedJson := RemoveWhitespaces(`
{
  "instances": [
    "i-TXQ59KVB",
    "i-69CFY6RK",
    "i-LQQUNEJX"
  ],
  "zone": "ac1",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "action": "TerminateInstances"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "TerminateInstancesResponse",
  "code": 0,
  "job_id": "job-0FP96OHD"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := TerminateInstancesRequest{
		InstanceIDs: []string{"i-TXQ59KVB", "i-69CFY6RK", "i-LQQUNEJX"},
	}
	var response TerminateInstancesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := TerminateInstancesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "TerminateInstancesResponse",
			Code:    0,
			RetCode: 0,
		},
		JobID: "job-0FP96OHD",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestStartInstances tests that we send correct request to start instances.
func TestStartInstances(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "instances": [
    "i-G74Q69NJ",
    "i-OAEZPC6C"
  ],
  "zone": "ac1",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "action": "StartInstances"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action": "StartInstancesResponse",
  "code": 0,
  "job_id": "job-IAGIH7TT"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := StartInstancesRequest{
		InstanceIDs: []string{"i-G74Q69NJ", "i-OAEZPC6C"},
	}
	var response StartInstancesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := StartInstancesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "StartInstancesResponse",
			Code:    0,
			RetCode: 0,
		},
		JobID: "job-IAGIH7TT",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestStopInstances tests that we send correct request to stop instances.
func TestStopInstance(t *testing.T) {
	// Note "ips" and "vols" are empty.
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
  "ret_code": 0,
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

	request := StopInstancesRequest{
		InstanceIDs: []string{"i-G74Q69NJ", "i-OAEZPC6C"},
		Force:       ForceStop,
	}
	var response StopInstancesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

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

// TestRestartInstances tests that we send correct request to restart instances.
func TestRestartInstances(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "instances": [
    "i-G74Q69NJ",
    "i-OAEZPC6C"
  ],
  "zone": "ac1",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "action": "RestartInstances"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code":0,
  "action": "RestartInstancesResponse",
  "code": 0,
  "job_id": "job-R9HV3XDU"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := RestartInstancesRequest{
		InstanceIDs: []string{"i-G74Q69NJ", "i-OAEZPC6C"},
	}
	var response RestartInstancesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := RestartInstancesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "RestartInstancesResponse",
			Code:    0,
			RetCode: 0,
		},
		JobID: "job-R9HV3XDU",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestResetLoginPasswd tests that we send correct request to reset instance password.
func TestResetLoginPasswd(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "instances": [
    "i-G74Q69NJ"
  ],
  "login_passwd": "2222ssSS",
  "token":"E5I9QKJF1O2B5PXE68LG",
  "action": "ResetLoginPasswd",
  "zone":"ac1"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "ResetLoginPasswdResponse",
  "code ": 0,
  "job_id": "job-GKQTYZR4"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ResetLoginPasswdRequest{
		InstanceIDs: []string{"i-G74Q69NJ"},
		LoginPasswd: "2222ssSS",
	}
	var response ResetLoginPasswdResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ResetLoginPasswdResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ResetLoginPasswdResponse",
			Code:    0,
			RetCode: 0,
		},
		JobID: "job-GKQTYZR4",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}

// TestModifyInstanceAttributes tests that we send correct request to modify instance attributes.
func TestModifyInstanceAttributes(t *testing.T) {
	expectedJson := RemoveWhitespaces(`
{
  "instance": "i-G74Q69NJ",
  "instance_name": "test",
  "description": "testtest",
  "zone": "ac1",
  "token": "E5I9QKJF1O2B5PXE68LG",
  "action": "ModifyInstanceAttributes"
}
`)

	fakeResponse := RemoveWhitespaces(`
{
  "ret_code": 0,
  "action": "ModifyInstanceAttributesResponse",
  "code": 0,
  "instance_id": "i-G74Q69NJ",
  "job_id": "job-8ZZVXC5O"
}
`)

	testServer := httptest.NewServer(&FakeHandler{t: t, ExpectedJson: expectedJson, FakeResponse: fakeResponse})
	defer testServer.Close()

	c, err := NewClient(testServer.URL, &AuthConfiguration{PublicKey: "E5I9QKJF1O2B5PXE68LG", PrivateKey: "secret"})
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	request := ModifyInstanceAttributesRequest{
		InstanceID:   "i-G74Q69NJ",
		InstanceName: "test",
		Description:  "testtest",
	}
	var response ModifyInstanceAttributesResponse

	err = c.SendRequest(request, &response)
	if err != nil {
		t.Errorf("Unexpected non-nil error %v", err)
	}

	expectedResponse := ModifyInstanceAttributesResponse{
		ResponseCommon: ResponseCommon{
			Action:  "ModifyInstanceAttributesResponse",
			Code:    0,
			RetCode: 0,
		},
		InstanceID: "i-G74Q69NJ",
		JobID:      "job-8ZZVXC5O",
	}
	if !reflect.DeepEqual(expectedResponse, response) {
		t.Errorf("Error: expected \n%v, got \n%v", expectedResponse, response)
	}
}
