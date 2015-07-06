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
	"github.com/caicloud/anchnet-go/vendor/_nuts/github.com/spf13/cobra"
)

func execCreateLoadBalancer(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "Load balancer name and public ips required")
		os.Exit(1)
	}

	lb_type := getFlagInt(cmd, "type")

	refs := strings.Split(args[1], ",")
	ips := make([]anchnet.CreateLoadBalancerIP, len(refs))

	for i, ip := range refs {
		ips[i].Ref = ip
	}

	request := anchnet.CreateLoadBalancerRequest{
		Product: anchnet.CreateLoadBalancerProduct{
			LB: anchnet.CreateLoadBalancerLB{
				Name: args[0],
				Type: anchnet.LoadBalancerType(lb_type),
			},
			IP: ips,
		},
	}
	var response anchnet.CreateLoadBalancerResponse

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command: %v", err)
		os.Exit(1)
	}

	sendResult(response, out)
}

func execDeleteLoadBalancer(cmd *cobra.Command, args []string, client *anchnet.Client, out io.Writer) {
	if len(args) != 2 {
		fmt.Fprintln(os.Stderr, "Load balancer id and public ips required")
		os.Exit(1)
	}

	lbs := strings.Split(args[0], ",")
	ips := strings.Split(args[1], ",")

	request := anchnet.DeleteLoadBalancersRequest{
		IPs:           ips,
		Loadbalancers: lbs,
	}
	var response anchnet.DeleteLoadBalancersResponse

	err := client.SendRequest(request, &response)
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error running command: %v", err)
		os.Exit(1)
	}

	sendResult(response, out)
}
