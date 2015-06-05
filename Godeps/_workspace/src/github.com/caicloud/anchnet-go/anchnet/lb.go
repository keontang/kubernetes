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

func execCreateLoadBalancer(cmd *cobra.Command, args []string, out io.Writer) {
	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "Load balancer name and public ips required")
		os.Exit(1)
	}

	auth, err := anchnet.LoadConfig(anchnet.DefaultConfigPath())
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	refs := strings.Split(args[1], ",")
	ips := make([]anchnet.CreateLoadBalancerIP, len(refs))

	for i, ip := range refs {
		ips[i].Ref = ip
	}

	request := anchnet.CreateLoadBalancerRequest{
		Product: anchnet.CreateLoadBalancerProduct{
			LB: anchnet.CreateLoadBalancerLB{
				Name: args[0],
				// TODO: Type is hard coded for now to select
				// lb with max connection of 20k
				Type: 1,
			},
			IP: ips,
		},
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.CreateLoadBalancer(request)
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
