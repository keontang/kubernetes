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
)

// AnchnetDiskUtil implements pdManager which abstracts interface to PD operations.
type AnchnetDiskUtil struct{}

// AttachAndMountDisk attaches a disk specified by a volume.anchnetPersistentDisk to the
// current kubelet. Mounts the disk to it's global path.
func (util *AnchnetDiskUtil) AttachAndMountDisk(b *anchnetPersistentDiskBuilder, globalPDPath string) error {
	volumes, err := b.getVolumeProvider()
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

// DetachDisk detaches the disk from the kubelet's host machine.
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
	volumes, err := c.getVolumeProvider()
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
