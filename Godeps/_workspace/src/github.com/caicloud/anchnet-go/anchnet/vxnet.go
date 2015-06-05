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

func execCreateVxnet(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Vxnet name required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(anchnet.DefaultConfigPath())
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	request := anchnet.CreateVxnetsRequest{
		VxnetName: args[0],
		VxnetType: anchnet.VxnetTypePriv,
		Count:     1,
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.CreateVxnets(request)
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

func execDescribeVxnets(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "Vxnet IDs required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(anchnet.DefaultConfigPath())
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	request := anchnet.DescribeVxnetsRequest{
		Vxnets: strings.Split(args[0], ","),
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.DescribeVxnets(request)
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

func execJoinVxnet(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "Vxnet and instances IDs required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(anchnet.DefaultConfigPath())
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	request := anchnet.JoinVxnetRequest{
		Vxnet:     args[0],
		Instances: strings.Split(args[1], ","),
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.JoinVxnet(request)
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
