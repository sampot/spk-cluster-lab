#!/bin/bash

main() {
  echo "[TASK] Create cStor storage pool: cstor-disk-pool"
  create_cstor_storage_pool

  echo "[TASK] Create cstor srogae classes: openebs-replicated, openebs-single"
  create_cstor_storage_classes
}


create_cstor_storage_pool() {
  # get all unclaimed block devices
  BD_LIST=$(kubectl -n openebs get blockdevices | grep 'Unclaimed' | awk '{print "      - " $1}')
  echo "[INFO] Unclaimed block devices:"
  echo "${BD_LIST}"

  cat <<EOF | kubectl apply -f -
apiVersion: openebs.io/v1alpha1
kind: StoragePoolClaim
metadata:
  name: cstor-disk-pool
  annotations:
    cas.openebs.io/config: |
      - name: PoolResourceRequests
        value: |-
            memory: 0.1Gi
      - name: PoolResourceLimits
        value: |-
            memory: 1Gi
spec:
  name: cstor-disk-pool
  type: disk
  poolSpec:
    poolType: striped
  blockDevices:
    blockDeviceList:
    # Use the blockdevices that are available to your kubernetes nodes
${BD_LIST}
EOF
}

create_cstor_storage_classes() {
  cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-replicated
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
    openebs.io/cas-type: cstor
    cas.openebs.io/config: |
      - name: StoragePoolClaim
        value: "cstor-disk-pool"
      - name: ReplicaCount
        value: "3"
provisioner: openebs.io/provisioner-iscsi
EOF

  cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-single
  annotations:
    openebs.io/cas-type: cstor
    cas.openebs.io/config: |
      - name: StoragePoolClaim
        value: "cstor-disk-pool"
      - name: ReplicaCount
        value: "1"
provisioner: openebs.io/provisioner-iscsi
EOF

  cat <<EOF | kubectl apply -f -
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: openebs-local
  annotations:
    openebs.io/cas-type: local
    cas.openebs.io/config: |
      - name: StorageType
        value: hostpath
      - name: BasePath
        value: /var/local-hostpath
provisioner: openebs.io/local
reclaimPolicy: Delete
volumeBindingMode: WaitForFirstConsumer
EOF
}


main "$@"