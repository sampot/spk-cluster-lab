#!/bin/bash

main() {
  echo "Deploy OpenEBS storage"
  deploy_openebs
}

deploy_openebs() {
  cat <<EOF | kubectl apply -f -
# Create the OpenEBS namespace
apiVersion: v1
kind: Namespace
metadata:
  name: openebs
---
# Create Maya Service Account
apiVersion: v1
kind: ServiceAccount
metadata:
  name: openebs-maya-operator
  namespace: openebs
---
# Define Role that allows operations on K8s pods/deployments
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: openebs-maya-operator
rules:
- apiGroups: ["*"]
  resources: ["nodes", "nodes/proxy"]
  verbs: ["*"]
- apiGroups: ["*"]
  resources: ["namespaces", "services", "pods", "pods/exec", "deployments", "deployments/finalizers", "replicationcontrollers", "replicasets", "events", "endpoints", "configmaps", "secrets", "jobs", "cronjobs"]
  verbs: ["*"]
- apiGroups: ["*"]
  resources: ["statefulsets", "daemonsets"]
  verbs: ["*"]
- apiGroups: ["*"]
  resources: ["resourcequotas", "limitranges"]
  verbs: ["list", "watch"]
- apiGroups: ["*"]
  resources: ["ingresses", "horizontalpodautoscalers", "verticalpodautoscalers", "certificatesigningrequests"]
  verbs: ["list", "watch"]
- apiGroups: ["*"]
  resources: ["storageclasses", "persistentvolumeclaims", "persistentvolumes"]
  verbs: ["*"]
- apiGroups: ["volumesnapshot.external-storage.k8s.io"]
  resources: ["volumesnapshots", "volumesnapshotdatas"]
  verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
- apiGroups: ["apiextensions.k8s.io"]
  resources: ["customresourcedefinitions"]
  verbs: [ "get", "list", "create", "update", "delete", "patch"]
- apiGroups: ["openebs.io"]
  resources: [ "*"]
  verbs: ["*" ]
- apiGroups: ["cstor.openebs.io"]
  resources: [ "*"]
  verbs: ["*" ]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "watch", "list", "delete", "update", "create"]
- apiGroups: ["admissionregistration.k8s.io"]
  resources: ["validatingwebhookconfigurations", "mutatingwebhookconfigurations"]
  verbs: ["get", "create", "list", "delete", "update", "patch"]
- nonResourceURLs: ["/metrics"]
  verbs: ["get"]
- apiGroups: ["*"]
  resources: ["poddisruptionbudgets"]
  verbs: ["get", "list", "create", "delete", "watch"]
---
# Bind the Service Account with the Role Privileges.
# TODO: Check if default account also needs to be there
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: openebs-maya-operator
subjects:
- kind: ServiceAccount
  name: openebs-maya-operator
  namespace: openebs
roleRef:
  kind: ClusterRole
  name: openebs-maya-operator
  apiGroup: rbac.authorization.k8s.io
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: maya-apiserver
  namespace: openebs
  labels:
    name: maya-apiserver
    openebs.io/component-name: maya-apiserver
    openebs.io/version: 1.10.0
spec:
  selector:
    matchLabels:
      name: maya-apiserver
      openebs.io/component-name: maya-apiserver
  replicas: 1
  strategy:
    type: Recreate
    rollingUpdate: null
  template:
    metadata:
      labels:
        name: maya-apiserver
        openebs.io/component-name: maya-apiserver
        openebs.io/version: 1.10.0
    spec:
      serviceAccountName: openebs-maya-operator
      containers:
      - name: maya-apiserver
        imagePullPolicy: IfNotPresent
        image: quay.io/openebs/m-apiserver:1.10.0
        ports:
        - containerPort: 5656
        env:
        - name: OPENEBS_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        # OPENEBS_SERVICE_ACCOUNT provides the service account of this pod as
        # environment variable
        - name: OPENEBS_SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
        # OPENEBS_MAYA_POD_NAME provides the name of this pod as
        # environment variable
        - name: OPENEBS_MAYA_POD_NAME
          valueFrom:
            fieldRef:
              fieldPath: metadata.name
        # If OPENEBS_IO_CREATE_DEFAULT_STORAGE_CONFIG is false then OpenEBS default
        # storageclass and storagepool will not be created.
        - name: OPENEBS_IO_CREATE_DEFAULT_STORAGE_CONFIG
          value: "false"
        - name: OPENEBS_IO_INSTALL_DEFAULT_CSTOR_SPARSE_POOL
          value: "false"
        - name: OPENEBS_IO_JIVA_CONTROLLER_IMAGE
          value: "quay.io/openebs/jiva:1.10.0"
        - name: OPENEBS_IO_JIVA_REPLICA_IMAGE
          value: "quay.io/openebs/jiva:1.10.0"
        - name: OPENEBS_IO_JIVA_REPLICA_COUNT
          value: "3"
        - name: OPENEBS_IO_CSTOR_TARGET_IMAGE
          value: "quay.io/openebs/cstor-istgt:1.10.0"
        - name: OPENEBS_IO_CSTOR_POOL_IMAGE
          value: "quay.io/openebs/cstor-pool:1.10.0"
        - name: OPENEBS_IO_CSTOR_POOL_MGMT_IMAGE
          value: "quay.io/openebs/cstor-pool-mgmt:1.10.0"
        - name: OPENEBS_IO_CSTOR_VOLUME_MGMT_IMAGE
          value: "quay.io/openebs/cstor-volume-mgmt:1.10.0"
        - name: OPENEBS_IO_VOLUME_MONITOR_IMAGE
          value: "quay.io/openebs/m-exporter:1.10.0"
        - name: OPENEBS_IO_CSTOR_POOL_EXPORTER_IMAGE
          value: "quay.io/openebs/m-exporter:1.10.0"
        - name: OPENEBS_IO_HELPER_IMAGE
          value: "quay.io/openebs/linux-utils:1.10.0"
        # OPENEBS_IO_ENABLE_ANALYTICS if set to true sends anonymous usage
        # events to Google Analytics
        - name: OPENEBS_IO_ENABLE_ANALYTICS
          value: "true"
        - name: OPENEBS_IO_INSTALLER_TYPE
          value: "openebs-operator"
        # OPENEBS_IO_ANALYTICS_PING_INTERVAL can be used to specify the duration (in hours)
        # for periodic ping events sent to Google Analytics.
        # Default is 24h.
        # Minimum is 1h. You can convert this to weekly by setting 168h
        #- name: OPENEBS_IO_ANALYTICS_PING_INTERVAL
        #  value: "24h"
        livenessProbe:
          exec:
            command:
            - /usr/local/bin/mayactl
            - version
          initialDelaySeconds: 30
          periodSeconds: 60
        readinessProbe:
          exec:
            command:
            - /usr/local/bin/mayactl
            - version
          initialDelaySeconds: 30
          periodSeconds: 60
---
apiVersion: v1
kind: Service
metadata:
  name: maya-apiserver-service
  namespace: openebs
  labels:
    openebs.io/component-name: maya-apiserver-svc
spec:
  ports:
  - name: api
    port: 5656
    protocol: TCP
    targetPort: 5656
  selector:
    name: maya-apiserver
  sessionAffinity: None
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openebs-provisioner
  namespace: openebs
  labels:
    name: openebs-provisioner
    openebs.io/component-name: openebs-provisioner
    openebs.io/version: 1.10.0
spec:
  selector:
    matchLabels:
      name: openebs-provisioner
      openebs.io/component-name: openebs-provisioner
  replicas: 1
  strategy:
    type: Recreate
    rollingUpdate: null
  template:
    metadata:
      labels:
        name: openebs-provisioner
        openebs.io/component-name: openebs-provisioner
        openebs.io/version: 1.10.0
    spec:
      serviceAccountName: openebs-maya-operator
      containers:
      - name: openebs-provisioner
        imagePullPolicy: IfNotPresent
        image: quay.io/openebs/openebs-k8s-provisioner:1.10.0
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: OPENEBS_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - test `pgrep -c "^openebs-provisi.*"` = 1
          initialDelaySeconds: 30
          periodSeconds: 60
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openebs-snapshot-operator
  namespace: openebs
  labels:
    name: openebs-snapshot-operator
    openebs.io/component-name: openebs-snapshot-operator
    openebs.io/version: 1.10.0
spec:
  selector:
    matchLabels:
      name: openebs-snapshot-operator
      openebs.io/component-name: openebs-snapshot-operator
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        name: openebs-snapshot-operator
        openebs.io/component-name: openebs-snapshot-operator
        openebs.io/version: 1.10.0
    spec:
      serviceAccountName: openebs-maya-operator
      containers:
        - name: snapshot-controller
          image: quay.io/openebs/snapshot-controller:1.10.0
          imagePullPolicy: IfNotPresent
          env:
          - name: OPENEBS_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          livenessProbe:
            exec:
              command:
              - sh
              - -c
              - test `pgrep -c "^snapshot-contro.*"` = 1
            initialDelaySeconds: 30
            periodSeconds: 60
        - name: snapshot-provisioner
          image: quay.io/openebs/snapshot-provisioner:1.10.0
          imagePullPolicy: IfNotPresent
          env:
          - name: OPENEBS_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          livenessProbe:
            exec:
              command:
              - sh
              - -c
              - test `pgrep -c "^snapshot-provis.*"` = 1
            initialDelaySeconds: 30
            periodSeconds: 60
---
# This is the node-disk-manager related config.
# It can be used to customize the disks probes and filters
apiVersion: v1
kind: ConfigMap
metadata:
  name: openebs-ndm-config
  namespace: openebs
  labels:
    openebs.io/component-name: ndm-config
data:
  # udev-probe is default or primary probe which should be enabled to run ndm
  # filterconfigs contails configs of filters - in their form fo include
  # and exclude comma separated strings
  node-disk-manager.config: |
    probeconfigs:
      - key: udev-probe
        name: udev probe
        state: true
      - key: seachest-probe
        name: seachest probe
        state: false
      - key: smart-probe
        name: smart probe
        state: true
    filterconfigs:
      - key: os-disk-exclude-filter
        name: os disk exclude filter
        state: true
        exclude: "/,/etc/hosts,/boot"
      - key: vendor-filter
        name: vendor filter
        state: true
        include: ""
        exclude: "CLOUDBYT,OpenEBS"
      - key: path-filter
        name: path filter
        state: true
        include: ""
        exclude: "loop,/dev/fd0,/dev/sr0,/dev/ram,/dev/dm-,/dev/md,/dev/sda"
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: openebs-ndm
  namespace: openebs
  labels:
    name: openebs-ndm
    openebs.io/component-name: ndm
    openebs.io/version: 1.10.0
spec:
  selector:
    matchLabels:
      name: openebs-ndm
      openebs.io/component-name: ndm
  updateStrategy:
    type: RollingUpdate
  template:
    metadata:
      labels:
        name: openebs-ndm
        openebs.io/component-name: ndm
        openebs.io/version: 1.10.0
    spec:
      # kubectl label node <node-name> "openebs.io/nodegroup"="storage-node"
      #nodeSelector:
      #  "openebs.io/nodegroup": "storage-node"
      serviceAccountName: openebs-maya-operator
      hostNetwork: true
      containers:
      - name: node-disk-manager
        image: quay.io/openebs/node-disk-manager-amd64:0.5.0
        args:
          - -v=4
        # The feature-gate is used to enable the new UUID algorithm.
        # This is a feature currently in Alpha state
        #  - --feature-gates="GPTBasedUUID"
        imagePullPolicy: IfNotPresent
        securityContext:
          privileged: true
        volumeMounts:
        - name: config
          mountPath: /host/node-disk-manager.config
          subPath: node-disk-manager.config
          readOnly: true
        - name: udev
          mountPath: /run/udev
        - name: procmount
          mountPath: /host/proc
          readOnly: true
        - name: basepath
          mountPath: /var/openebs/ndm
        - name: sparsepath
          mountPath: /var/openebs/sparse
        env:
        # namespace in which NDM is installed will be passed to NDM Daemonset
        # as environment variable
        - name: NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        # pass hostname as env variable using downward API to the NDM container
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        # specify the directory where the sparse files need to be created.
        # if not specified, then sparse files will not be created.
        - name: SPARSE_FILE_DIR
          value: "/var/openebs/sparse"
        # Size(bytes) of the sparse file to be created.
        - name: SPARSE_FILE_SIZE
          value: "10737418240"
        # Specify the number of sparse files to be created
        - name: SPARSE_FILE_COUNT
          value: "0"
        livenessProbe:
          exec:
            command:
            - pgrep
            - "ndm"
          initialDelaySeconds: 30
          periodSeconds: 60
      volumes:
      - name: config
        configMap:
          name: openebs-ndm-config
      - name: udev
        hostPath:
          path: /run/udev
          type: Directory
      # mount /proc (to access mount file of process 1 of host) inside container
      # to read mount-point of disks and partitions
      - name: procmount
        hostPath:
          path: /proc
          type: Directory
      - name: basepath
        hostPath:
          path: /var/openebs/ndm
          type: DirectoryOrCreate
      - name: sparsepath
        hostPath:
          path: /var/openebs/sparse
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openebs-ndm-operator
  namespace: openebs
  labels:
    name: openebs-ndm-operator
    openebs.io/component-name: ndm-operator
    openebs.io/version: 1.10.0
spec:
  selector:
    matchLabels:
      name: openebs-ndm-operator
      openebs.io/component-name: ndm-operator
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        name: openebs-ndm-operator
        openebs.io/component-name: ndm-operator
        openebs.io/version: 1.10.0
    spec:
      serviceAccountName: openebs-maya-operator
      containers:
        - name: node-disk-operator
          image: quay.io/openebs/node-disk-operator-amd64:0.5.0
          imagePullPolicy: IfNotPresent
          readinessProbe:
            exec:
              command:
                - stat
                - /tmp/operator-sdk-ready
            initialDelaySeconds: 4
            periodSeconds: 10
            failureThreshold: 1
          env:
            - name: WATCH_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            # the service account of the ndm-operator pod
            - name: SERVICE_ACCOUNT
              valueFrom:
                fieldRef:
                  fieldPath: spec.serviceAccountName
            - name: OPERATOR_NAME
              value: "node-disk-operator"
            - name: CLEANUP_JOB_IMAGE
              value: "quay.io/openebs/linux-utils:1.10.0"
            # OPENEBS_IO_INSTALL_CRD environment variable is used to enable/disable CRD installation
            # from NDM operator. By default the CRDs will be installed
            #- name: OPENEBS_IO_INSTALL_CRD
            #  value: "true"
          # Process name used for matching is limited to the 15 characters
          # present in the pgrep output.
          # So fullname can be used here with pgrep (cmd is < 15 chars).
          livenessProbe:
            exec:
              command:
              - pgrep
              - "ndo"
            initialDelaySeconds: 30
            periodSeconds: 60
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openebs-admission-server
  namespace: openebs
  labels:
    app: admission-webhook
    openebs.io/component-name: admission-webhook
    openebs.io/version: 1.10.0
spec:
  replicas: 1
  strategy:
    type: Recreate
    rollingUpdate: null
  selector:
    matchLabels:
      app: admission-webhook
  template:
    metadata:
      labels:
        app: admission-webhook
        openebs.io/component-name: admission-webhook
        openebs.io/version: 1.10.0
    spec:
      serviceAccountName: openebs-maya-operator
      containers:
        - name: admission-webhook
          image: quay.io/openebs/admission-server:1.10.0
          imagePullPolicy: IfNotPresent
          args:
            - -alsologtostderr
            - -v=2
            - 2>&1
          env:
            - name: OPENEBS_NAMESPACE
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
            - name: ADMISSION_WEBHOOK_NAME
              value: "openebs-admission-server"
          livenessProbe:
            exec:
              command:
              - sh
              - -c
              - test `pgrep -c "^admission-serve.*"` = 1
            initialDelaySeconds: 30
            periodSeconds: 60
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: openebs-localpv-provisioner
  namespace: openebs
  labels:
    name: openebs-localpv-provisioner
    openebs.io/component-name: openebs-localpv-provisioner
    openebs.io/version: 1.10.0
spec:
  selector:
    matchLabels:
      name: openebs-localpv-provisioner
      openebs.io/component-name: openebs-localpv-provisioner
  replicas: 1
  strategy:
    type: Recreate
  template:
    metadata:
      labels:
        name: openebs-localpv-provisioner
        openebs.io/component-name: openebs-localpv-provisioner
        openebs.io/version: 1.10.0
    spec:
      serviceAccountName: openebs-maya-operator
      containers:
      - name: openebs-provisioner-hostpath
        imagePullPolicy: IfNotPresent
        image: quay.io/openebs/provisioner-localpv:1.10.0
        env:
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        - name: OPENEBS_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        # OPENEBS_SERVICE_ACCOUNT provides the service account of this pod as
        # environment variable
        - name: OPENEBS_SERVICE_ACCOUNT
          valueFrom:
            fieldRef:
              fieldPath: spec.serviceAccountName
        - name: OPENEBS_IO_ENABLE_ANALYTICS
          value: "true"
        - name: OPENEBS_IO_INSTALLER_TYPE
          value: "openebs-operator"
        - name: OPENEBS_IO_HELPER_IMAGE
          value: "quay.io/openebs/linux-utils:1.10.0"
        livenessProbe:
          exec:
            command:
            - sh
            - -c
            - test `pgrep -c "^provisioner-loc.*"` = 1
          initialDelaySeconds: 30
          periodSeconds: 60
---
EOF
}


main "$@"