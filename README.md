# k8s-local-pv

This component is a Kubernetes automated [local PersistentVolume](https://kubernetes.io/docs/concepts/storage/volumes/#local) provisioner, written in Python.
It's meant to be deployed as DaemonSet listening for PersistentVolume creation/deletion and acting upon by performing the physical provisioning of LVM volumes, taken from a specific VolumeGroup.

# Requirements (as of 201904)
* CentOS-7 (systemd is used to mount and persist the mounts across nodes);
* Your nodes should have labels on the form `node-id.k8s.portavita.net/nodeid: xxxxxx`, where `xxxxxx` will be used to refer to the nodes in the chart, if you use it;
* Your nodes must provide an LVM VolumeGroup, from where the LogicalVolumes are taken;
* Your nodes must provide a `/mnt/pv` mountpoint, where the LVs will be mounted (this path is still hardcoded in a few places).

# How to use
You start by deploying the provisioner as a DaemonSet. See [helm/k8s-local-pv](helm/local-pv).

You'll have to specify the PersistentVolumes youtself, along with the volume options (filesytem type (`fsType`), mount options (`mountOpts`), volume group (`vg`), filesystem formatting options (`fsOpts`)). To make your life easier, refer to [helm/local-volumes](helm/local-volumes). This chart will provide a storageClass, that will act as a pool of PersistentVolumes, which are also automatically handled for you.

... and that's basically it. Once the PersistentVolumes are defined in Kubernetes, the provisioner will take care of the physical provisioning, and patch the PV with status annotation.

If provisioning failed, you'd expect to see the following annotation: `local-pv.k8s.portavita.net/status: Not-Processed-Errors`, after which you should pay a visit to the respective node's pod logs.

Your users can now use the PersistentVolume as in any other situation. An example PVC template (note, that this is definition of StatefulSet, not Deployment, see [this note](https://akomljen.com/kubernetes-persistent-volumes-with-deployment-and-statefulset/)):
```
        volumeMounts:
        - mountPath: /usr/share/elasticsearch/data
          name: data
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 30Gi
      storageClassName: elasticsearch-data
```

To have the physical volumes removed, all you have to do is to remove the PersistentVolume manifest, and the provisioner will take care of it.

# Special features
## PVC Auto-Release
The "release" of the PV happens when you delete the PVC bound to it, and as a security measure (to avoid accidentally losing data) the Kubernetes team requires the admin to perform [manual intervention](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#reclaiming).

If option `-R` is used, the provisioner will search for a specific annotation to determine if it should automatically cleanup the claimRef after the bound PVC is removed.

You can try it against an existing/bound PVC with:
```
$ kubectl patch pv the-pv-you-want-to-test -p '{"metadata":{"annotations":{"local-pv.k8s.portavita.net/autoRelease": "true"}}}'
```
... and then delete the associated PersistentVolumeClaim. The PV should change to `Available` (instead of remaining in `Released`).

# Developing

## Running the tests
* Test error control structures:
 ```kubectl create -f test/pv-with-errors.yaml```
* Provision a Pod which will claim a PV:
  ```kubectl create -f test/pv-in-a-pod.yaml```
* Provision a StatefulSet (which automatically generates PersistentVolumeClaims) with:
  ```kubectl create -f test/pv-in-a-statefulset.yaml```


## Wishlist / improvements
* The default volumeOptions should be in a configMap and read upon start (or trigger a restart upon change)
* Support LV thin provisioning
* Support individual volumes' encryption
* Implement shredding upon removal
* Add complete required PodSecurityPolicy to the helm chart.

# Limitations
* As of 201904, the [helm chart local-volumes](helm/local-volumes) generates mountpoints that do not allow 2 volumes for the same application on the same node. It should be fairly simple to change it, and if you do it for yourself, let us know with a pull request!

# License
[GNU General Public License](https://www.gnu.org/licenses/old-licenses/gpl-2.0.html)
