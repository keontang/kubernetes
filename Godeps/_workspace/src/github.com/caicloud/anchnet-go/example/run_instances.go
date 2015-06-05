package main

import (
	"fmt"
	"os"

	anchnet "github.com/caicloud/anchnet-go"
)

func main() {
	auth, err := anchnet.LoadConfig(anchnet.DefaultConfigPath())
	if err != nil {
		fmt.Println("Error loading auth config %v", err)
		os.Exit(1)
	}

	createWithHDandPrivateSDN := false

	var request anchnet.RunInstancesRequest
	if createWithHDandPrivateSDN {
		request = anchnet.RunInstancesRequest{
			Product: anchnet.RunInstancesProduct{
				Cloud: anchnet.RunInstancesCloud{
					VM: anchnet.RunInstancesVM{
						Name:      "test_instance",
						LoginMode: anchnet.LoginModePwd,
						Mem:       1024, // 1GB
						Cpu:       1,    // 1Core
						Password:  "caicloud2015ABC",
						ImageId:   "centos65x64d",
					},
					HD: []anchnet.RunInstancesHardDisk{
						{
							Name: "test_disk",
							Unit: 10, // 10GB
							Type: anchnet.HDTypePerformance,
						},
					},
					Net0: true, // Create public network
					Net1: []anchnet.RunInstancesNet1{
						{
							VxnetName: "test_vxnet", // Create a private SDN network
							Checked:   true,
						},
					},
					IP: anchnet.RunInstancesIP{
						IPGroup:   "eipg-00000000",
						Bandwidth: 1, // Public network with 1MB/s bandwith
					},
				},
			},
		}
	} else {
		request = anchnet.RunInstancesRequest{
			Product: anchnet.RunInstancesProduct{
				Cloud: anchnet.RunInstancesCloud{
					VM: anchnet.RunInstancesVM{
						Name:      "test_instance",
						LoginMode: anchnet.LoginModePwd,
						Mem:       1024, // 1GB
						Cpu:       1,    // 1Core
						Password:  "caicloud2015ABC",
						ImageId:   "centos65x64d",
					},
					Net0: true, // Create public network
					IP: anchnet.RunInstancesIP{
						IPGroup:   "eipg-00000000",
						Bandwidth: 1, // Public network with 1MB/s bandwith
					},
				},
			},
		}
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Println("Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.RunInstances(request)
	if err != nil {
		fmt.Println("Error running client %v", err)
		os.Exit(1)
	}

	fmt.Printf("%+v\n", resp)
}
