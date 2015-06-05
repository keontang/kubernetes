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

func execReleaseEips(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "EIP IDs required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(anchnet.DefaultConfigPath())
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	request := anchnet.ReleaseEipsRequest{
		Eips: strings.Split(args[0], ","),
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.ReleaseEips(request)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running client %v", err)
		os.Exit(1)
	}

	if resp.Code == 0 {
		fmt.Fprintln(out, "Released eips")
	} else {
		fmt.Fprintln(out, resp.Message)
	}
}

func execDescribeEips(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) == 0 {
		fmt.Fprintln(os.Stderr, "EIP IDs required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(anchnet.DefaultConfigPath())
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	request := anchnet.DescribeEipsRequest{
		Eips: strings.Split(args[0], ","),
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.DescribeEips(request)
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
