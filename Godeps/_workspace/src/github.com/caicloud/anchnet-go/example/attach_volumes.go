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

	request := anchnet.AttachVolumesRequest{
		Instance: "i-AB2067X2",
		Volumes:  []string{"vom-DAO6C8R1", "vom-34D1SLFG"},
	}

	client, err := anchnet.NewClient(anchnet.DefaultEndpoint, auth)
	if err != nil {
		fmt.Println("Error creating client %v", err)
		os.Exit(1)
	}

	resp, err := client.AttachVolumes(request)
	if err != nil {
		fmt.Println("Error running client %v", err)
		os.Exit(1)
	}

	fmt.Printf("%+v\n", resp)
}
