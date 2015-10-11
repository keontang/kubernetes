/*
Copyright 2015 The Kubernetes Authors All rights reserved.

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
	"fmt"
	"os"
	"path"
	"strconv"

	"github.com/golang/glog"

	"k8s.io/kubernetes/pkg/api"
	anchnet_cloud "k8s.io/kubernetes/pkg/cloudprovider/providers/anchnet"
	"k8s.io/kubernetes/pkg/types"
	"k8s.io/kubernetes/pkg/util"
	"k8s.io/kubernetes/pkg/util/exec"
	"k8s.io/kubernetes/pkg/util/mount"
	"k8s.io/kubernetes/pkg/volume"
)

// This is the primary entrypoint for volume plugins. It is called from kubelet
// to register volume plugin.
func ProbeVolumePlugins() []volume.VolumePlugin {
	return []volume.VolumePlugin{&anchnetPersistentDiskPlugin{nil}}
}

// Main implementation of anchnet volume plugin.
type anchnetPersistentDiskPlugin struct {
	// VolumeHost is an interface that plugins can use to access the kubelet.
	host volume.VolumeHost
}

// Make sure anchnetPersistentDiskPlugin acutally implements volume.VolumePlugin.
var _ volume.VolumePlugin = &anchnetPersistentDiskPlugin{}
var _ volume.PersistentVolumePlugin = &anchnetPersistentDiskPlugin{}

const (
	// TODO: Can we change the name to "caicloud.io/anchnet-pd".
	anchnetPersistentDiskPluginName = "kubernetes.io/anchnet-pd"
)

func (plugin *anchnetPersistentDiskPlugin) Init(host volume.VolumeHost) {
	plugin.host = host
}

func (plugin *anchnetPersistentDiskPlugin) Name() string {
	return anchnetPersistentDiskPluginName
}

// CanSupport checks if the PersistentDiskPlugin can support given spec.  It is
// called from plugin manager.
func (plugin *anchnetPersistentDiskPlugin) CanSupport(spec *volume.Spec) bool {
	return (spec.PersistentVolume != nil && spec.PersistentVolume.Spec.AnchnetPersistentDisk != nil) ||
		(spec.Volume != nil && spec.Volume.AnchnetPersistentDisk != nil)
}

func (plugin *anchnetPersistentDiskPlugin) GetAccessModes() []api.PersistentVolumeAccessMode {
	return []api.PersistentVolumeAccessMode{
		// Anchnet persistent disk can only be mounted once.
		api.ReadWriteOnce,
	}
}

// NewBuilder returns a builder interface used for kubelet to setup/mount volume.
// anchnetPersistentDiskBuilder implements the interface.
func (plugin *anchnetPersistentDiskPlugin) NewBuilder(spec *volume.Spec, pod *api.Pod, _ volume.VolumeOptions) (volume.Builder, error) {
	// Inject real implementations here, test through the internal function.
	return plugin.newBuilderInternal(spec, pod.UID, &AnchnetDiskUtil{}, plugin.host.GetMounter())
}

func (plugin *anchnetPersistentDiskPlugin) newBuilderInternal(spec *volume.Spec, podUID types.UID, manager pdManager, mounter mount.Interface) (volume.Builder, error) {
	var pd *api.AnchnetPersistentDiskVolumeSource
	var readOnly bool
	// PDs used directly in a pod have a ReadOnly flag set by the pod author.
	// PDs used as a PersistentVolume gets the ReadOnly flag indirectly through the persistent-claim volume used to mount the PV.
	if spec.Volume != nil && spec.Volume.AnchnetPersistentDisk != nil {
		pd = spec.Volume.AnchnetPersistentDisk
		readOnly = pd.ReadOnly
	} else {
		pd = spec.PersistentVolume.Spec.AnchnetPersistentDisk
		readOnly = spec.ReadOnly
	}

	volumeID := pd.VolumeID
	fsType := pd.FSType
	partition := ""
	if pd.Partition != 0 {
		partition = strconv.Itoa(pd.Partition)
	}

	return &anchnetPersistentDiskBuilder{
		anchnetPersistentDisk: &anchnetPersistentDisk{
			podUID:   podUID,
			volName:  spec.Name(),
			volumeID: volumeID,
			manager:  manager,
			mounter:  mounter,
			plugin:   plugin,
		},
		fsType:      fsType,
		partition:   partition,
		readOnly:    readOnly,
		diskMounter: &mount.SafeFormatAndMount{mounter, exec.New()},
	}, nil
}

func (plugin *anchnetPersistentDiskPlugin) NewCleaner(volName string, podUID types.UID) (volume.Cleaner, error) {
	// Inject real implementations here, test through the internal function.
	return plugin.newCleanerInternal(volName, podUID, &AnchnetDiskUtil{}, plugin.host.GetMounter())
}

func (plugin *anchnetPersistentDiskPlugin) newCleanerInternal(volName string, podUID types.UID, manager pdManager, mounter mount.Interface) (volume.Cleaner, error) {
	return &anchnetPersistentDiskCleaner{&anchnetPersistentDisk{
		podUID:  podUID,
		volName: volName,
		manager: manager,
		mounter: mounter,
		plugin:  plugin,
	}}, nil
}

// pdManager abstracts interface to PD operations.
type pdManager interface {
	// AttachAndMountDisk attaches/mounts the disk to the kubelet's host machine.
	AttachAndMountDisk(b *anchnetPersistentDiskBuilder, globalPDPath string) error
	// DetachDisk detaches/unmount the disk from the kubelet's host machine.
	DetachDisk(c *anchnetPersistentDiskCleaner) error
}

// anchnetPersistentDisk volumes are disk resources provided by Anchnet
// that are attached to the kubelet's host machine and exposed to the pod.
type anchnetPersistentDisk struct {
	// Name of the volume in provider.
	volName string
	// Unique id of the PD, used to find the disk resource in the provider.
	volumeID string
	// Mount the disk to Pod with podUID.
	podUID types.UID
	// Utility interface that provides API calls to the provider to attach/detach disks.
	manager pdManager
	// Mounter interface that provides system calls to mount the global path to the pod local path.
	mounter mount.Interface
	// Reference to PD plugin.
	plugin *anchnetPersistentDiskPlugin
}

// GetPath returns the directory path the volume is mounted to. The path is a host path, e.g.
// /var/lib/kubelet/pods/11053ab6-4ba7/volumes/kubernetes.io~pd/mongodb~volume
func (pd *anchnetPersistentDisk) GetPath() string {
	name := anchnetPersistentDiskPluginName
	return pd.plugin.host.GetPodVolumeDir(pd.podUID, util.EscapeQualifiedNameForDisk(name), pd.volName)
}

// getVolumeProvider returns Anchnet Volumes interface.
func (pd *anchnetPersistentDisk) getVolumeProvider() (anchnet_cloud.Volumes, error) {
	cloud := pd.plugin.host.GetCloudProvider()
	volumes, ok := cloud.(anchnet_cloud.Volumes)
	if !ok {
		return nil, fmt.Errorf("cloudprovider anchnet does not support volumes")
	}
	return volumes, nil
}

// anchnetPersistentDiskBuilder setup and mounts persistent disk.
type anchnetPersistentDiskBuilder struct {
	*anchnetPersistentDisk
	// Filesystem type, optional.
	fsType string
	// Specifies the partition to mount
	partition string
	// Specifies whether the disk will be attached as read-only.
	readOnly bool
	// diskMounter provides the interface that is used to mount the actual block device.
	diskMounter mount.Interface
}

var _ volume.Builder = &anchnetPersistentDiskBuilder{}

// SetUp attaches the disk and bind mounts to default path.
func (b *anchnetPersistentDiskBuilder) SetUp() error {
	return b.SetUpAt(b.GetPath())
}

// SetUpAt attaches the disk and bind mounts to the volume path.
func (b *anchnetPersistentDiskBuilder) SetUpAt(dir string) error {
	notMnt, err := b.mounter.IsLikelyNotMountPoint(dir)
	glog.V(4).Infof("PersistentDisk set up: %s %v %v", dir, !notMnt, err)
	if err != nil && !os.IsNotExist(err) {
		return err
	}
	if !notMnt {
		return nil
	}

	// Get the place where we globally mount the disk. The disk will be mounted at
	// `globalPDPath` first, then will be bind-mounted to `dir`.
	globalPDPath := makeGlobalPDPath(b.plugin.host, b.volumeID)
	glog.Infof("Mount PersistentDisk at %v", globalPDPath)
	if err := b.manager.AttachAndMountDisk(b, globalPDPath); err != nil {
		return err
	}

	// Create `dir` to prepare for bind mount.
	if err := os.MkdirAll(dir, 0750); err != nil {
		// TODO: we should really eject the attach/detach out into its own control loop.
		// detachDiskLogError(b)
		return err
	}

	// Perform a bind mount to the full path to allow duplicate mounts of the same PD.
	options := []string{"bind"}
	if b.readOnly {
		options = append(options, "ro")
	}
	err = b.mounter.Mount(globalPDPath, dir, "", options)
	if err != nil {
		notMnt, mntErr := b.mounter.IsLikelyNotMountPoint(dir)
		if mntErr != nil {
			glog.Errorf("IsLikelyNotMountPoint check failed: %v", mntErr)
			return err
		}
		if !notMnt {
			if mntErr = b.mounter.Unmount(dir); mntErr != nil {
				glog.Errorf("Failed to unmount: %v", mntErr)
				return err
			}
			notMnt, mntErr := b.mounter.IsLikelyNotMountPoint(dir)
			if mntErr != nil {
				glog.Errorf("IsLikelyNotMountPoint check failed: %v", mntErr)
				return err
			}
			if !notMnt {
				// This is very odd, we don't expect it.  We'll try again next sync loop.
				glog.Errorf("%s is still mounted, despite call to unmount().  Will try again next sync loop.", dir)
				return err
			}
		}
		os.Remove(dir)
		// TODO: we should really eject the attach/detach out into its own control loop.
		// detachDiskLogError(b.awsElasticBlockStore)
		return err
	}

	return nil
}

func (b *anchnetPersistentDiskBuilder) IsReadOnly() bool {
	return b.readOnly
}

var _ volume.Cleaner = &anchnetPersistentDiskCleaner{}

// anchnetPersistentDiskCleaner setup and mounts persistent disk.
type anchnetPersistentDiskCleaner struct {
	*anchnetPersistentDisk
}

// Unmounts the bind mount, and detaches the disk only if the PD
// resource was the last reference to that disk on the kubelet.
func (c *anchnetPersistentDiskCleaner) TearDown() error {
	return c.TearDownAt(c.GetPath())
}

// Unmounts the bind mount, and detaches the disk only if the PD
// resource was the last reference to that disk on the kubelet.
func (c *anchnetPersistentDiskCleaner) TearDownAt(dir string) error {
	notMnt, err := c.mounter.IsLikelyNotMountPoint(dir)
	if err != nil {
		glog.Info("Error checking if mountpoint ", dir, ": ", err)
		return err
	}
	if notMnt {
		glog.Info("Not mountpoint, deleting")
		return os.Remove(dir)
	}

	refs, err := mount.GetMountRefs(c.mounter, dir)
	if err != nil {
		glog.Info("Error getting mountrefs for ", dir, ": ", err)
		return err
	}
	if len(refs) == 0 {
		glog.Warning("Did not find pod-mount for ", dir, " during tear-down")
	}
	// Unmount the bind-mount inside this pod
	if err := c.mounter.Unmount(dir); err != nil {
		glog.Info("Error unmounting dir ", dir, ": ", err)
		return err
	}
	// If len(refs) is 1, then all bind mounts have been removed, and the
	// remaining reference is the global mount. It is safe to detach.
	if len(refs) == 1 {
		// c.volumeID is not initially set for volume-cleaners, so set it here.
		c.volumeID = path.Base(refs[0])
		if err := c.manager.DetachDisk(c); err != nil {
			return err
		}
	} else {
		glog.Infof("Found multiple refs; won't detach EBS volume: %v", refs)
	}
	notMnt, mntErr := c.mounter.IsLikelyNotMountPoint(dir)
	if mntErr != nil {
		glog.Errorf("IsLikelyNotMountPoint check failed: %v", mntErr)
		return err
	}
	if notMnt {
		if err := os.Remove(dir); err != nil {
			glog.Info("Error removing mountpoint ", dir, ": ", err)
			return err
		}
	}
	return nil
}

// makeGlobalPDPath creates a directory path which is used to mount the persistent disk.
// Note this is different from dir returned from GetPath(), we will later bind mount that
// directory.
func makeGlobalPDPath(host volume.VolumeHost, volumeID string) string {
	return path.Join(host.GetPluginDir(anchnetPersistentDiskPluginName), "mounts", volumeID)
}
