/*
Copyright 2014 The Kubernetes Authors All rights reserved.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

package anchnet_cloud

import (
	"errors"
	"fmt"
	"io/ioutil"
	"os"
	"strings"
	"time"

	"github.com/golang/glog"

	anchnet_client "github.com/caicloud/anchnet-go"
)

var _ Volumes = (*Anchnet)(nil)

// AttachDisk attaches the disk to the specified instance. `instanceID` can be empty
// to mean "the instance on which we are running".
// Returns the device path (e.g. /dev/xvdf) where we attached the volume.
func (an *Anchnet) AttachDisk(instanceID string, volumeID string, readOnly bool) (string, error) {
	glog.Infof("AttachDisk(%v, %v, %v)", instanceID, volumeID, readOnly)

	// It's not possible in anchnet to setup disk for other instances.
	if instanceID != "" {
		return "", errors.New("unable to attach disk for instance other than self instance")
	}

	// Get hostname and convert it to instance ID. During cluster provisioning, we set hostname to
	// lowercased instance ID. Ideally, we can issue a request to cloudprovider to get instance
	// information of the host itself, but anchnet lacks the API.
	hostname, err := os.Hostname()
	if err != nil {
		return "", err
	}
	instanceID = convertToInstanceID(hostname)

	// Before attaching volume, check /sys/block for known disks.
	existing, err := readSysBlock("sd")
	if err != nil {
		return "", err
	}
	glog.Infof("AttachDisk found existing disks %+v", existing)

	// Do the volume attach.
	attach_response, err := an.attachVolume(instanceID, volumeID)
	if err != nil {
		return "", err
	}
	err = an.WaitJobStatus(attach_response.JobID, anchnet_client.JobStatusSuccessful)
	if err != nil {
		return "", err
	}

	// After attaching volume, check /sys/block again.
	current, err := readSysBlock("sd")
	if err != nil {
		return "", err
	}
	glog.Infof("AttachDisk found current disks %+v", current)

	existingMap := make(map[string]bool)
	for _, disk := range existing {
		existingMap[disk] = true
	}

	var diff []string
	for _, disk := range current {
		if _, ok := existingMap[disk]; !ok {
			diff = append(diff, disk)
		}
	}
	if len(diff) != 1 {
		return "", fmt.Errorf("Unable to find volume %v", diff)
	}
	glog.Infof("Found device path %+v", "/dev/"+diff[0])

	return "/dev/" + diff[0], nil
}

// DetachDisk detaches the disk from the specified instance. `instanceID` can be empty
// to mean "the instance on which we are running"
func (an *Anchnet) DetachDisk(instanceID string, volumeID string) error {
	glog.Infof("DetachDisk(%v, %v)", instanceID, volumeID)
	detach_response, err := an.detachVolume(volumeID)
	if err != nil {
		return err
	}
	err = an.WaitJobStatus(detach_response.JobID, anchnet_client.JobStatusSuccessful)
	if err != nil {
		return err
	}
	return nil
}

// Create a volume with the specified options.
func (an *Anchnet) CreateVolume(volumeOptions *VolumeOptions) (volumeID string, err error) {
	return "", nil
}

// Delete a volume.
func (an *Anchnet) DeleteVolume(volumeID string) error {
	return nil
}

// attachVolumes attaches a volume to given instance.
func (an *Anchnet) attachVolume(instanceID string, volumeID string) (*anchnet_client.AttachVolumesResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.AttachVolumesRequest{
			InstanceID: instanceID,
			VolumeIDs:  []string{volumeID},
		}
		var response anchnet_client.AttachVolumesResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			glog.Infof("Attached volume %v to instance %v", volumeID, instanceID)
			return &response, nil
		} else {
			glog.Infof("Attempt %d: failed to attach volume: %v\n", i, err)
		}
		time.Sleep(time.Duration(i+1) * RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to attach volume %v to instance %v", volumeID, instanceID)
}

// detachVolumes detaches a volume.
func (an *Anchnet) detachVolume(volumeID string) (*anchnet_client.DetachVolumesResponse, error) {
	for i := 0; i < RetryCountOnError; i++ {
		request := anchnet_client.DetachVolumesRequest{
			VolumeIDs: []string{volumeID},
		}
		var response anchnet_client.DetachVolumesResponse
		err := an.client.SendRequest(request, &response)
		if err == nil {
			glog.Infof("Detached volume %v to", volumeID)
			return &response, nil
		} else {
			glog.Infof("Attempt %d: failed to detach volume: %v\n", i, err)
		}
		time.Sleep(time.Duration(i+1) * RetryIntervalOnError)
	}
	return nil, fmt.Errorf("Unable to detach volume %v", volumeID)
}

// readSysBlock reads /sys/block and returns a list of devices start with `prefix`.
func readSysBlock(prefix string) ([]string, error) {
	dirs, err := ioutil.ReadDir("/sys/block")
	if err != nil {
		return nil, err
	}

	var result []string
	for _, dir := range dirs {
		if strings.HasPrefix(dir.Name(), prefix) {
			result = append(result, dir.Name())
		}
	}

	return result, nil
}
