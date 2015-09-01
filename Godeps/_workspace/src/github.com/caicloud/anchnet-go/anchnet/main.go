// Copyright 2015 anchnet-go authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

package main

import (
	"io"
	"os"

	anchnet "github.com/caicloud/anchnet-go"
	"github.com/spf13/cobra"
)

func main() {
	var cmds = &cobra.Command{
		Use:   "anchnet",
		Short: "anchnet is the command line interface for anchnet",
	}
	var config_path, project string
	cmds.PersistentFlags().StringVarP(&config_path, "config-path", "", "", "configuration path for anchnet")
	cmds.PersistentFlags().StringVarP(&project, "project", "", "", "anchnet sub account id")

	addInstancesCLI(cmds, os.Stdout)
	addEipsCLI(cmds, os.Stdout)
	addVxnetsCLI(cmds, os.Stdout)
	addLoadBalancerCLI(cmds, os.Stdout)
	addSecurityGroupCLI(cmds, os.Stdout)
	addJobCLI(cmds, os.Stdout)
	addUserProjectCLI(cmds, os.Stdout)

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
	var cpu, memory, amount, bandwidth int
	var passwd, image_id, ip_group string
	cmdRunInstance.Flags().IntVarP(&cpu, "cpu", "c", 1, "Number of cpu cores")
	cmdRunInstance.Flags().IntVarP(&amount, "amount", "a", 1, "Number of instances to run")
	cmdRunInstance.Flags().IntVarP(&memory, "memory", "m", 1024, "Number of memory in MB")
	cmdRunInstance.Flags().IntVarP(&bandwidth, "bandwidth", "b", 1, "Public network bandwidth, in MB/s")
	cmdRunInstance.Flags().StringVarP(&passwd, "passwd", "p", "caicloud2015ABC", "Login password for new instance")
	cmdRunInstance.Flags().StringVarP(&image_id, "image-id", "i", "trustysrvx64c", "Image ID used to create new instance")
	cmdRunInstance.Flags().StringVarP(&ip_group, "ip-group", "g", "eipg-00000000", "IP group of the newly created eip")

	cmdDescribeInstance := &cobra.Command{
		Use:   "describeinstance id",
		Short: "Get information of an instance by id",
		Run: func(cmd *cobra.Command, args []string) {
			execDescribeInstance(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdSearchInstance := &cobra.Command{
		Use:   "searchinstance name",
		Short: "Search instances by name",
		Run: func(cmd *cobra.Command, args []string) {
			execSearchInstance(cmd, args, getAnchnetClient(cmd), out)
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
	cmds.AddCommand(cmdSearchInstance)
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
		Short: "Get information of a private SDN network by id",
		Run: func(cmd *cobra.Command, args []string) {
			execDescribeVxnets(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdSearchVxnets := &cobra.Command{
		Use:   "searchvxnets name",
		Short: "Search private SDN network by name",
		Run: func(cmd *cobra.Command, args []string) {
			execSearchVxnets(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdJoinVxnet := &cobra.Command{
		Use:   "joinvxnet vxnet_id instance_ids",
		Short: "Join instancs to vxnet",
		Run: func(cmd *cobra.Command, args []string) {
			execJoinVxnet(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdDeleteVxnets := &cobra.Command{
		Use:   "deletevxnets ids",
		Short: "Delete private SDN network",
		Run: func(cmd *cobra.Command, args []string) {
			execDeleteVxnets(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	// Add all sub-commands.
	cmds.AddCommand(cmdCreateVxnets)
	cmds.AddCommand(cmdDescribeVxnets)
	cmds.AddCommand(cmdSearchVxnets)
	cmds.AddCommand(cmdJoinVxnet)
	cmds.AddCommand(cmdDeleteVxnets)
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

// addSecurityGroupCLI adds SecurityGroup commands.
func addSecurityGroupCLI(cmds *cobra.Command, out io.Writer) {
	var rulename, direction, priority, protocol, action, value1, value2, value3 string
	cmdCreateSecurityGroup := &cobra.Command{
		Use: "createsecuritygroup name",
		Short: "Create a new security group with rules, e.g. anchnet createsecuritygroup sg_group" +
			"--rulename=ssh,http --priority=1,2 --action=accept,accept --protocol=tcp,tcp",
		Run: func(cmd *cobra.Command, args []string) {
			execCreateSecurityGroup(cmd, args, getAnchnetClient(cmd), out)
		},
	}
	cmdCreateSecurityGroup.Flags().StringVarP(&rulename, "rulename", "r", "",
		"Rule names, comma separated list.")
	cmdCreateSecurityGroup.Flags().StringVarP(&direction, "direction", "d", "",
		"Direction of the rule. 0 is down, 1 is up.")
	cmdCreateSecurityGroup.Flags().StringVarP(&action, "action", "a", "",
		"Action of the rule, one of accept and drop.")
	cmdCreateSecurityGroup.Flags().StringVarP(&protocol, "protocol", "c", "",
		"Protocol of the rule, can be tcp, udp or ssh, http, etc.")
	cmdCreateSecurityGroup.Flags().StringVarP(&priority, "priority", "p", "",
		"Priority of the rule, an integer.")
	cmdCreateSecurityGroup.Flags().StringVarP(&value1, "value1", "", "",
		"Value1 of the rule, whose meanning differs based on protocol.")
	cmdCreateSecurityGroup.Flags().StringVarP(&value2, "value2", "", "",
		"Value2 of the rule, whose meanning differs based on protocol.")
	cmdCreateSecurityGroup.Flags().StringVarP(&value3, "value3", "", "",
		"Value3 of the rule, whose meanning differs based on protocol.")

	var add_direction, add_priority int
	cmdAddSecurityGroupRule := &cobra.Command{
		Use:   "addsecuritygrouprule name securitygroup_id",
		Short: "Add a new rule to a given security group",
		Run: func(cmd *cobra.Command, args []string) {
			execAddSecurityGroupRule(cmd, args, getAnchnetClient(cmd), out)
		},
	}
	cmdAddSecurityGroupRule.Flags().IntVarP(&add_direction, "direction", "d", 0,
		"Direction of the rule. 0 is down, 1 is up.")
	cmdAddSecurityGroupRule.Flags().StringVarP(&action, "action", "a", "",
		"Action of the rule, one of accept and drop.")
	cmdAddSecurityGroupRule.Flags().StringVarP(&protocol, "protocol", "c", "",
		"Protocol of the rule, can be tcp, udp or ssh, http, etc.")
	cmdAddSecurityGroupRule.Flags().IntVarP(&add_priority, "priority", "p", 0,
		"Priority of the rule, an integer.")
	cmdAddSecurityGroupRule.Flags().StringVarP(&value1, "value1", "", "",
		"Value1 of the rule, whose meanning differs based on protocol.")
	cmdAddSecurityGroupRule.Flags().StringVarP(&value2, "value2", "", "",
		"Value2 of the rule, whose meanning differs based on protocol.")
	cmdAddSecurityGroupRule.Flags().StringVarP(&value3, "value3", "", "",
		"Value3 of the rule, whose meanning differs based on protocol.")

	cmdApplySecurityGroup := &cobra.Command{
		Use:   "applysecuritygroup securitygroup_id instance_ids",
		Short: "Apply a security group id to a comma separated list of instance ids",
		Run: func(cmd *cobra.Command, args []string) {
			execApplySecurityGroup(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdDescribeSecurityGroup := &cobra.Command{
		Use:   "describesecuritygroup ids",
		Short: "Get security group information by id",
		Run: func(cmd *cobra.Command, args []string) {
			execDescribeSecurityGroup(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdSearchSecurityGroup := &cobra.Command{
		Use:   "searchsecuritygroup name",
		Short: "Search security group by name",
		Run: func(cmd *cobra.Command, args []string) {
			execSearchSecurityGroup(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdDeleteSecurityGroups := &cobra.Command{
		Use:   "deletesecuritygroups securitygroup_ids",
		Short: "Delete of a list of security groups by ids.",
		Run: func(cmd *cobra.Command, args []string) {
			execDeleteSecurityGroups(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	// Add all sub-commands.
	cmds.AddCommand(cmdCreateSecurityGroup)
	cmds.AddCommand(cmdAddSecurityGroupRule)
	cmds.AddCommand(cmdApplySecurityGroup)
	cmds.AddCommand(cmdDescribeSecurityGroup)
	cmds.AddCommand(cmdSearchSecurityGroup)
	cmds.AddCommand(cmdDeleteSecurityGroups)
}

// addJobCLI adds job commands.
func addJobCLI(cmds *cobra.Command, out io.Writer) {
	cmdDescribeJob := &cobra.Command{
		Use:   "describejob id",
		Short: "Get information of a job by id",
		Run: func(cmd *cobra.Command, args []string) {
			execDescribeJob(cmd, args, getAnchnetClient(cmd), out)
		},
	}

	cmdWaitJob := &cobra.Command{
		Use:   "waitjob id",
		Short: "Wait until job becomes desired status, default 'successful'",
		Run: func(cmd *cobra.Command, args []string) {
			execWaitJob(cmd, args, getAnchnetClient(cmd), out)
		},
	}
	var count, interval int
	var status string
	cmdWaitJob.Flags().IntVarP(&count, "count", "c", 20, "Number of retries")
	cmdWaitJob.Flags().IntVarP(&interval, "interval", "i", 3, "Retry interval, in second")
	cmdWaitJob.Flags().StringVarP(&status, "status", "s", string(anchnet.JobStatusSuccessful), "Retry interval, in second")

	// Add all sub-commands.
	cmds.AddCommand(cmdDescribeJob)
	cmds.AddCommand(cmdWaitJob)
}

func addUserProjectCLI(cmds *cobra.Command, out io.Writer) {
	var sex, mobile, loginpasswd string
	cmdCreateUserProject := &cobra.Command{
		Use:   "createuserproject userid",
		Short: "create user project under anchnet account",
		Run: func(cmd *cobra.Command, args []string) {
			execCreateUserProject(cmd, args, getAnchnetClient(cmd), out)
		},
	}
	cmdCreateUserProject.Flags().StringVarP(&sex, "sex", "s", "M",
		"Gender of the person")
	cmdCreateUserProject.Flags().StringVarP(&mobile, "mobile", "m", "13888888888",
		"Cell phone number")
	cmdCreateUserProject.Flags().StringVarP(&loginpasswd, "passwd", "p", "caicloud2015ABC",
		"Password of the sub account")

	// Add all sub-commands.
	cmds.AddCommand(cmdCreateUserProject)
}
