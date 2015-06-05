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

	request := anchnet.LeaveVxnetRequest{
		Instances: []string{"i-U8DNNTS7"},
		Vxnet:     "vxnet-2VD7OD87",
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Println("Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.LeaveVxnet(request)
	if err != nil {
		fmt.Println("Error running client %v", err)
		os.Exit(1)
	}

	fmt.Printf("%+v\n", resp)
}
