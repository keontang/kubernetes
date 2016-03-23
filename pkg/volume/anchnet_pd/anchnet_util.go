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

package anchnet_pd

import (
	"errors"
	"os"
	"time"

	"github.com/golang/glog"
	"k8s.io/kubernetes/pkg/cloudprovider"
	anchnet_cloud "k8s.io/kubernetes/pkg/cloudprovider/providers/anchnet"
)

// AnchnetDiskUtil implements pdManager which abstracts interface to PD operations.
type AnchnetDiskUtil struct{}

func (util *AnchnetDiskUtil) AttachAndMountDisk(b *anchnetPersistentDiskBuilder, globalPDPath string) error {
	volumes, err := getCloudProvider()
	if err != nil {
		return err
	}
	devicePath, err := volumes.AttachDisk("", b.volumeID, b.readOnly)
	if err != nil {
		return err
	}
	if b.partition != "" {
		devicePath = devicePath + b.partition
	}
	numTries := 0
	for {
		_, err := os.Stat(devicePath)
		if err == nil {
			break
		}
		if err != nil && !os.IsNotExist(err) {
			return err
		}
		numTries++
		if numTries == 10 {
			return errors.New("Could not attach disk: Timeout after 10s (" + devicePath + ")")
		}
		time.Sleep(time.Second)
	}

	// Only mount the PD globally once.
	notMnt, err := b.mounter.IsLikelyNotMountPoint(globalPDPath)
	if err != nil {
		if os.IsNotExist(err) {
			if err := os.MkdirAll(globalPDPath, 0750); err != nil {
				return err
			}
			notMnt = true
		} else {
			return err
		}
	}
	options := []string{}
	if b.readOnly {
		options = append(options, "ro")
	}
	if notMnt {
		err = b.diskMounter.Mount(devicePath, globalPDPath, b.fsType, options)
		if err != nil {
			os.Remove(globalPDPath)
			return err
		}
	}
	return nil
}

func (util *AnchnetDiskUtil) DetachDisk(c *anchnetPersistentDiskCleaner) error {
	// Unmount the global PD mount, which should be the only one.
	globalPDPath := makeGlobalPDPath(c.plugin.host, c.volumeID)
	if err := c.mounter.Unmount(globalPDPath); err != nil {
		glog.Info("Error unmount dir ", globalPDPath, ": ", err)
		return err
	}
	if err := os.Remove(globalPDPath); err != nil {
		glog.Info("Error removing dir ", globalPDPath, ": ", err)
		return err
	}
	// Detach the disk.
	volumes, err := getCloudProvider()
	if err != nil {
		glog.Info("Error getting volume provider for volumeID ", c.volumeID, ": ", err)
		return err
	}
	if err := volumes.DetachDisk("", c.volumeID); err != nil {
		glog.Info("Error detaching disk ", c.volumeID, ": ", err)
		return err
	}
	return nil
}

func (util *AnchnetDiskUtil) CreateDisk(provisioner *anchnetPersistentDiskProvisioner) (volumeID string, volumeSizeGB int, labels map[string]string, err error) {
	return "", 0, nil, nil
}

func (util *AnchnetDiskUtil) DeleteDisk(deleter *anchnetPersistentDiskDeleter) error {
	return nil
}

// getCloudProvider returns cloud provider.
func getCloudProvider() (*anchnet_cloud.Anchnet, error) {
	anchnetCloudProvider, err := cloudprovider.GetCloudProvider("caicloud-anchnet", nil)
	if err != nil || anchnetCloudProvider == nil {
		return nil, err
	}

	// The conversion must be safe otherwise bug in GetCloudProvider()
	return anchnetCloudProvider.(*anchnet_cloud.Anchnet), nil
}
