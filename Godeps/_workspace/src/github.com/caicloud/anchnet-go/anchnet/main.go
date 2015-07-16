// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"io"
	"os"

	"github.com/spf13/cobra"
)

func main() {
	var cmds = &cobra.Command{
		Use:   "anchnet",
		Short: "anchnet is the command line interface for anchnet",
	}
	var config_path string
	cmds.PersistentFlags().StringVarP(&config_path, "config-path", "", "", "configuration path for anchnet")

	addInstancesCLI(cmds, os.Stdout)
	addEipsCLI(cmds, os.Stdout)
	addVxnetsCLI(cmds, os.Stdout)
	addLoadBalancerCLI(cmds, os.Stdout)

	cmds.Execute()
}

// addInstancesCLI adds instances commands.
func addInstancesCLI(cmds *cobra.Command, out io.Writer) {
	cmdRunInstance := &cobra.Command{
		Use:   "runinstance name",
		Short: "Create an instance",
		Long:  "Create an instance with flag parameters. Output error or instance/eip IDs",
		Run: func(cmd *cobra.Command, args []string) {
			execRunInstance(cmd, args, getAnchnetClient(cmd), out)
		},
	}
	var cpu, memory, bandwidth int
	var passwd, image_id string
	cmdRunInstance.Flags().IntVarP(&cpu, "cpu", "c", 1, "Number of cpu cores")
	cmdRunInstance.Flags().IntVarP(&memory, "memory", "m", 1024, "Number of memory in MB")
	cmdRunInstance.Flags().IntVarP(&bandwidth, "bandwidth", "b", 1, "Public network bandwidth, in MB/s")
	cmdRunInstance.Flags().StringVarP(&passwd, "passwd", "p", "caicloud2015ABC", "Login password for new instance")
	cmdRunInstance.Flags().StringVarP(&image_id, "image-id", "i", "trustysrvx64c", "Image ID used to create new instance")

	cmdDescribeInstance := &cobra.Command{
		Use:   "describeinstance id",
		Short: "Get information of an instance",
		Run: func(cmd *cobra.Command, args []string) {
			execDescribeInstance(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdTerminateInstances := &cobra.Command{
		Use:   "terminateinstances ids",
		Short: "Terminate a comma separated list of instances",
		Run: func(cmd *cobra.Command, args []string) {
			execTerminateInstances(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdStopInstances := &cobra.Command{
		Use:   "stopinstances ids",
		Short: "Stop a comma separated list of instances",
		Run: func(cmd *cobra.Command, args []string) {
			execStopInstances(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	// Add all sub-commands.
	cmds.AddCommand(cmdRunInstance)
	cmds.AddCommand(cmdDescribeInstance)
	cmds.AddCommand(cmdTerminateInstances)
	cmds.AddCommand(cmdStopInstances)
}

// addEipsCLI adds EIP commands.
func addEipsCLI(cmds *cobra.Command, out io.Writer) {
	cmdDescribeEips := &cobra.Command{
		Use:   "describeeips ids",
		Short: "Describe a comma separated list of eips",
		Run: func(cmd *cobra.Command, args []string) {
			execDescribeEips(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdReleaseEips := &cobra.Command{
		Use:   "releaseeips ids",
		Short: "Release a comma separated list of eips",
		Run: func(cmd *cobra.Command, args []string) {
			execReleaseEips(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	// Add all sub-commands.
	cmds.AddCommand(cmdReleaseEips)
	cmds.AddCommand(cmdDescribeEips)
}

// addVxnetsCLI adds Vxnet commands.
func addVxnetsCLI(cmds *cobra.Command, out io.Writer) {
	cmdCreateVxnets := &cobra.Command{
		Use:   "createvxnets id",
		Short: "Create a private SDN network in anchnet",
		Run: func(cmd *cobra.Command, args []string) {
			execCreateVxnet(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdDescribeVxnets := &cobra.Command{
		Use:   "describevxnets id",
		Short: "Describe a private SDN network in anchnet",
		Run: func(cmd *cobra.Command, args []string) {
			execDescribeVxnets(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdJoinVxnet := &cobra.Command{
		Use:   "joinvxnet vxnet_id instance_ids",
		Short: "Join instancs to vxnet",
		Run: func(cmd *cobra.Command, args []string) {
			execJoinVxnet(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	// Add all sub-commands.
	cmds.AddCommand(cmdCreateVxnets)
	cmds.AddCommand(cmdDescribeVxnets)
	cmds.AddCommand(cmdJoinVxnet)
}

// addLoadBalancerCLI adds LoadBalancer commands.
func addLoadBalancerCLI(cmds *cobra.Command, out io.Writer) {
	cmdCreateLoadBalancer := &cobra.Command{
		Use:   "createloadbalancer name ips",
		Short: "Create a load balancer which binds to a comma separated list of ips",
		Run: func(cmd *cobra.Command, args []string) {
			execCreateLoadBalancer(cmd, args, getAnchnetClient(cmd), out)
		},
	}
	var lb_type int
	cmdCreateLoadBalancer.Flags().IntVarP(&lb_type, "type", "t", 1,
		"Type of loadbalancer, i.e. max connection allowed. 1: 20k; 2: 40k; 3: 100k ")

	cmdDeleteLoadBalancer := &cobra.Command{
		Use:   "deleteloadbalancer id ips",
		Short: "Delete a load balancer which binds to a comma separated list of ips",
		Run: func(cmd *cobra.Command, args []string) {
			execDeleteLoadBalancer(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	// Add all sub-commands
	cmds.AddCommand(cmdCreateLoadBalancer)
	cmds.AddCommand(cmdDeleteLoadBalancer)
}
