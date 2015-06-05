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

	request := anchnet.TerminateInstancesRequest{
		Instances: []string{"i-M5JIG74C"},
		IPs:       []string{"eip-TYFJDV7K"},
		Vols:      []string{"vol-46Q60KA1"},
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Println("Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.TerminateInstances(request)
	if err != nil {
		fmt.Println("Error running client %v", err)
		os.Exit(1)
	}

	fmt.Printf("%+v\n", resp)
}
