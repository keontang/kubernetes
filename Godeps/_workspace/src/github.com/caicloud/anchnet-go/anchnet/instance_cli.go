// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"fmt"
	"io"
	"os"
	"strings"

	anchnet "github.com/caicloud/anchnet-go"
	"github.com/spf13/cobra"
)

func execRunInstance(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Instance name required")
		os.Exit(1)
	}

	cpu := getFlagInt(cmd, "cpu")
	amount := getFlagInt(cmd, "amount")
	memory := getFlagInt(cmd, "memory")
	passwd := getFlagString(cmd, "passwd")
	bandwidth := getFlagInt(cmd, "bandwidth")
	image_id := getFlagString(cmd, "image-id")
	ip_group := getFlagString(cmd, "ip-group")

	request := anchnet.RunInstancesRequest{
		Product: anchnet.RunInstancesProduct{
			Cloud: anchnet.RunInstancesCloud{
				VM: anchnet.RunInstancesVM{
					Name:      args[0],
					LoginMode: anchnet.LoginModePwd,
					Mem:       memory,
					Cpu:       cpu,
					Password:  passwd,
					ImageID:   image_id,
				},
				Net0: true, // Create public network
				IP: anchnet.RunInstancesIP{
					IPGroup:   anchnet.IPGroupType(ip_group),
					Bandwidth: bandwidth,
				},
				Amount: amount,
			},
		},
	}
	var response anchnet.RunInstancesResponse
	sendResult(&response, out, "RunInstance", response.Code, client.SendRequest(request, &response))
}

func execDescribeInstance(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Instance id required")
		os.Exit(1)
	}

	request := anchnet.DescribeInstancesRequest{
		InstanceIDs: []string{args[0]},
		Verbose:     1,
	}
	var response anchnet.DescribeInstancesResponse
	sendResult(&response, out, "DescribeInstance", response.Code, client.SendRequest(request, &response))
}

func execSearchInstance(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Instance name required")
		os.Exit(1)
	}

	request := anchnet.DescribeInstancesRequest{
		SearchWord: args[0],
		Status:     []anchnet.InstanceStatus{anchnet.InstanceStatusRunning},
		Verbose:    1,
	}
	var response anchnet.DescribeInstancesResponse
	sendResult(&response, out, "SearchInstance", response.Code, client.SendRequest(request, &response))
}

func execTerminateInstances(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Instance IDs required")
		os.Exit(1)
	}

	request := anchnet.TerminateInstancesRequest{
		InstanceIDs: strings.Split(args[0], ","),
	}
	var response anchnet.TerminateInstancesResponse
	sendResult(&response, out, "TerminateInstance", response.Code, client.SendRequest(request, &response))
}

func execStopInstances(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Instance IDs required")
		os.Exit(1)
	}

	request := anchnet.StopInstancesRequest{
		InstanceIDs: strings.Split(args[0], ","),
	}
	var response anchnet.StopInstancesResponse
	sendResult(&response, out, "StopInstance", response.Code, client.SendRequest(request, &response))
}
