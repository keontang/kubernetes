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

func execCreateVxnet(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Vxnet name required")
		os.Exit(1)
	}

	request := anchnet.CreateVxnetsRequest{
		VxnetName: args[0],
		VxnetType: anchnet.VxnetTypePriv,
		Count:     1,
	}
	var response anchnet.CreateVxnetsResponse

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command CreateVxnet: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
}

func execDescribeVxnets(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Vxnet IDs required")
		os.Exit(1)
	}

	request := anchnet.DescribeVxnetsRequest{
		VxnetIDs: strings.Split(args[0], ","),
	}
	var response anchnet.DescribeVxnetsResponse

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command DescribeVxnet: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
}

func execSearchVxnets(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Vxnet name required")
		os.Exit(1)
	}

	request := anchnet.DescribeVxnetsRequest{
		SearchWord: args[0],
		Verbose:    1,
	}
	var response anchnet.DescribeVxnetsResponse

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command DescribeVxnet (for searching vxnet): %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
}

func execJoinVxnet(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "Vxnet and instances IDs required")
		os.Exit(1)
	}

	request := anchnet.JoinVxnetRequest{
		VxnetID:     args[0],
		InstanceIDs: strings.Split(args[1], ","),
	}
	var response anchnet.JoinVxnetResponse

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command JoinVxnet: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
}

func execDeleteVxnets(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Vxnet IDs required")
		os.Exit(1)
	}

	request := anchnet.DeleteVxnetsRequest{
		VxnetIDs: strings.Split(args[0], ","),
	}
	var response anchnet.DeleteVxnetsResponse

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command DeleteVxnets: %v\n", err)
		os.Exit(1)
	}

	sendResult(response, out)
}
