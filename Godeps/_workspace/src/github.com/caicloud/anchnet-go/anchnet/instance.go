// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"

	anchnet "github.com/caicloud/anchnet-go"
	"github.com/caicloud/anchnet-go/vendor/_nuts/github.com/spf13/cobra"
)

func execRunInstance(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Instance name required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(getConfigPath(cmd))
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	cpu := GetFlagInt(cmd, "cpu")
	memory := GetFlagInt(cmd, "memory")
	passwd := GetFlagString(cmd, "passwd")
	bandwidth := GetFlagInt(cmd, "bandwidth")
	image_id := GetFlagString(cmd, "image-id")

	request := anchnet.RunInstancesRequest{
		Product: anchnet.RunInstancesProduct{
			Cloud: anchnet.RunInstancesCloud{
				VM: anchnet.RunInstancesVM{
					Name:      args[0],
					LoginMode: anchnet.LoginModePwd,
					Mem:       memory,
					Cpu:       cpu,
					Password:  passwd,
					ImageId:   image_id,
				},
				Net0: true, // Create public network
				IP: anchnet.RunInstancesIP{
					IPGroup:   "eipg-00000000",
					Bandwidth: bandwidth,
				},
			},
		},
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.RunInstances(request)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running client %v", err)
		os.Exit(1)
	}

	if resp.Code == 0 {
		output, err := json.Marshal(resp)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unexpected error marshaling output %v", err)
			os.Exit(1)
		}
		fmt.Fprintf(out, "%v", string(output))
	} else {
		fmt.Fprintln(out, resp.Message)
	}
}

func execDescribeInstance(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Instance name required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(getConfigPath(cmd))
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	request := anchnet.DescribeInstancesRequest{
		Instances: []string{args[0]},
		Verbose:   1,
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.DescribeInstances(request)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error describening client %v", err)
		os.Exit(1)
	}

	if resp.Code == 0 {
		output, err := json.Marshal(resp)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Unexpected error marshaling output %v", err)
			os.Exit(1)
		}
		fmt.Fprintf(out, "%v", string(output))
	} else {
		fmt.Fprintln(out, resp.Message)
	}
}

func execTerminateInstances(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Instance IDs required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(getConfigPath(cmd))
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	request := anchnet.TerminateInstancesRequest{
		Instances: strings.Split(args[0], ","),
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.TerminateInstances(request)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running client %v", err)
		os.Exit(1)
	}

	if resp.Code == 0 {
		fmt.Fprintln(out, "Terminated instances")
	} else {
		fmt.Fprintln(out, resp.Message)
	}
}

func execStopInstances(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Instance IDs required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(getConfigPath(cmd))
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	request := anchnet.StopInstancesRequest{
		Instances: strings.Split(args[0], ","),
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.StopInstances(request)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running client %v", err)
		os.Exit(1)
	}

	if resp.Code == 0 {
		fmt.Fprintln(out, "Stopped instances")
	} else {
		fmt.Fprintln(out, resp.Message)
	}
}
