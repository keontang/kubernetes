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

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command RunInstance: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
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

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command DescribeInstance: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
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

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command DescribeInstance (for searching instance): %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
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

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command TerminateInstances: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
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

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command StopInstances: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
}
