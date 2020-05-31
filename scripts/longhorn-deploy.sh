#!/bin/bash

main() {
  echo "[TASK] Deploy Longhorn v0.8.1"
  deploy_longhorn_system

  echo "[TASK] Create storage classes"
  create_storage_classes
}

deploy_longhorn_system() {
  cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: longhorn-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: longhorn-service-account
  namespace: longhorn-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: longhorn-role
rules:
- apiGroups:
  - apiextensions.k8s.io
  resources:
  - customresourcedefinitions
  verbs:
  - "*"
- apiGroups: [""]
  resources: ["pods", "events", "persistentvolumes", "persistentvolumeclaims","persistentvolumeclaims/status", "nodes", "proxy/nodes", "pods/log", "secrets", "services", "endpoints", "configmaps"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list"]
- apiGroups: ["apps"]
  resources: ["daemonsets", "statefulsets", "deployments"]
  verbs: ["*"]
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["*"]
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses", "volumeattachments", "csinodes", "csidrivers"]
  verbs: ["*"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["get", "watch", "list", "delete", "update", "create"]
- apiGroups: ["longhorn.io"]
  resources: ["volumes", "volumes/status", "engines", "engines/status", "replicas", "replicas/status", "settings",
              "engineimages", "engineimages/status", "nodes", "nodes/status", "instancemanagers", "instancemanagers/status"]
  verbs: ["*"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: longhorn-bind
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: longhorn-role
subjects:
- kind: ServiceAccount
  name: longhorn-service-account
  namespace: longhorn-system
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  labels:
    longhorn-manager: Engine
  name: engines.longhorn.io
spec:
  group: longhorn.io
  names:
    kind: Engine
    listKind: EngineList
    plural: engines
    shortNames:
    - lhe
    singular: engine
  scope: Namespaced
  version: v1beta1
  subresources:
    status: {}
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  labels:
    longhorn-manager: Replica
  name: replicas.longhorn.io
spec:
  group: longhorn.io
  names:
    kind: Replica
    listKind: ReplicaList
    plural: replicas
    shortNames:
    - lhr
    singular: replica
  scope: Namespaced
  version: v1beta1
  subresources:
    status: {}
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  labels:
    longhorn-manager: Setting
  name: settings.longhorn.io
spec:
  group: longhorn.io
  names:
    kind: Setting
    listKind: SettingList
    plural: settings
    shortNames:
    - lhs
    singular: setting
  scope: Namespaced
  version: v1beta1
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  labels:
    longhorn-manager: Volume
  name: volumes.longhorn.io
spec:
  group: longhorn.io
  names:
    kind: Volume
    listKind: VolumeList
    plural: volumes
    shortNames:
    - lhv
    singular: volume
  scope: Namespaced
  version: v1beta1
  subresources:
    status: {}
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  labels:
    longhorn-manager: EngineImage
  name: engineimages.longhorn.io
spec:
  group: longhorn.io
  names:
    kind: EngineImage
    listKind: EngineImageList
    plural: engineimages
    shortNames:
    - lhei
    singular: engineimage
  scope: Namespaced
  version: v1beta1
  subresources:
    status: {}
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  labels:
    longhorn-manager: Node
  name: nodes.longhorn.io
spec:
  group: longhorn.io
  names:
    kind: Node
    listKind: NodeList
    plural: nodes
    shortNames:
    - lhn
    singular: node
  scope: Namespaced
  version: v1beta1
  subresources:
    status: {}
---
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  labels:
    longhorn-manager: InstanceManager
  name: instancemanagers.longhorn.io
spec:
  group: longhorn.io
  names:
    kind: InstanceManager
    listKind: InstanceManagerList
    plural: instancemanagers
    shortNames:
    - lhim
    singular: instancemanager
  scope: Namespaced
  version: v1beta1
  subresources:
    status: {}
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: longhorn-default-setting
  namespace: longhorn-system
data:
  default-setting.yaml: |-
    backup-target:
    backup-target-credential-secret:
    create-default-disk-labeled-nodes:
    default-data-path:
    replica-soft-anti-affinity:
    storage-over-provisioning-percentage:
    storage-minimal-available-percentage:
    upgrade-checker:
    default-replica-count:
    guaranteed-engine-cpu:
    default-longhorn-static-storage-class:
    backupstore-poll-interval:
    taint-toleration:
    registry-secret:
---
apiVersion: apps/v1
kind: DaemonSet
metadata:
  labels:
    app: longhorn-manager
  name: longhorn-manager
  namespace: longhorn-system
spec:
  selector:
    matchLabels:
      app: longhorn-manager
  template:
    metadata:
      labels:
        app: longhorn-manager
    spec:
      containers:
      - name: longhorn-manager
        image: longhornio/longhorn-manager:v0.8.1
        imagePullPolicy: Always
        securityContext:
          privileged: true
        command:
        - longhorn-manager
        - -d
        - daemon
        - --engine-image
        - longhornio/longhorn-engine:v0.8.1
        - --instance-manager-image
        - longhornio/longhorn-instance-manager:v1_20200301
        - --manager-image
        - longhornio/longhorn-manager:v0.8.1
        - --service-account
        - longhorn-service-account
        ports:
        - containerPort: 9500
          name: manager
        readinessProbe:
          tcpSocket:
            port: 9500
        volumeMounts:
        - name: dev
          mountPath: /host/dev/
        - name: proc
          mountPath: /host/proc/
        - name: varrun
          mountPath: /var/run/
        - name: longhorn
          mountPath: /var/lib/longhorn/
          mountPropagation: Bidirectional
        - name: longhorn-default-setting
          mountPath: /var/lib/longhorn-setting/
        env:
        - name: POD_NAMESPACE
          valueFrom:
            fieldRef:
              fieldPath: metadata.namespace
        - name: POD_IP
          valueFrom:
            fieldRef:
              fieldPath: status.podIP
        - name: NODE_NAME
          valueFrom:
            fieldRef:
              fieldPath: spec.nodeName
        # Should be: mount path of the volume longhorn-default-setting + the key of the configmap data in 04-default-setting.yaml
        - name: DEFAULT_SETTING_PATH
          value: /var/lib/longhorn-setting/default-setting.yaml
      volumes:
      - name: dev
        hostPath:
          path: /dev/
      - name: proc
        hostPath:
          path: /proc/
      - name: varrun
        hostPath:
          path: /var/run/
      - name: longhorn
        hostPath:
          path: /var/lib/longhorn/
      - name: longhorn-default-setting
        configMap:
          name: longhorn-default-setting
#      imagePullSecrets:
#      - name: ""
      serviceAccountName: longhorn-service-account
  updateStrategy:
    rollingUpdate:
      maxUnavailable: "100%"
---
apiVersion: v1
kind: Service
metadata:
  labels:
    app: longhorn-manager
  name: longhorn-backend
  namespace: longhorn-system
spec:
  type: ClusterIP
  sessionAffinity: ClientIP
  selector:
    app: longhorn-manager
  ports:
  - name: manager
    port: 9500
    targetPort: manager
---
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: longhorn-ui
  name: longhorn-ui
  namespace: longhorn-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: longhorn-ui
  template:
    metadata:
      labels:
        app: longhorn-ui
    spec:
      containers:
      - name: longhorn-ui
        image: longhornio/longhorn-ui:v0.8.1
        imagePullPolicy: Always
        securityContext:
          runAsUser: 0
        ports:
        - containerPort: 8000
          name: http
        env:
          - name: LONGHORN_MANAGER_IP
            value: "http://longhorn-backend:9500"
#      imagePullSecrets:
#      - name:
---
kind: Service
apiVersion: v1
metadata:
  labels:
    app: longhorn-ui
  name: longhorn-frontend
  namespace: longhorn-system
spec:
  selector:
    app: longhorn-ui
  ports:
  - port: 80
    targetPort: 8000
    nodePort: null
  type: LoadBalancer
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: longhorn-driver-deployer
  namespace: longhorn-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: longhorn-driver-deployer
  template:
    metadata:
      labels:
        app: longhorn-driver-deployer
    spec:
      initContainers:
        - name: wait-longhorn-manager
          image: longhornio/longhorn-manager:v0.8.1
          command: ['sh', '-c', 'while [ $(curl -m 1 -s -o /dev/null -w "%{http_code}" http://longhorn-backend:9500/v1) != "200" ]; do echo waiting; sleep 2; done']
      containers:
        - name: longhorn-driver-deployer
          image: longhornio/longhorn-manager:v0.8.1
          imagePullPolicy: Always
          command:
          - longhorn-manager
          - -d
          - deploy-driver
          - --manager-image
          - longhornio/longhorn-manager:v0.8.1
          - --manager-url
          - http://longhorn-backend:9500/v1
          env:
          - name: POD_NAMESPACE
            valueFrom:
              fieldRef:
                fieldPath: metadata.namespace
          - name: NODE_NAME
            valueFrom:
              fieldRef:
                fieldPath: spec.nodeName
          - name: SERVICE_ACCOUNT
            valueFrom:
              fieldRef:
                fieldPath: spec.serviceAccountName
          # Manually set root directory for csi
          #- name: KUBELET_ROOT_DIR
          #  value: /var/lib/rancher/k3s/agent/kubelet
          # For AirGap Installation
          # Replace PREFIX with your private registery
          #- name: CSI_ATTACHER_IMAGE
          #  value: PREFIX/csi-attacher:v2.0.0
          #- name: CSI_PROVISIONER_IMAGE
          #  value: PREFIX/csi-provisioner:v1.4.0
          #- name: CSI_NODE_DRIVER_REGISTRAR_IMAGE
          #  value: PREFIX/csi-node-driver-registrar:v1.2.0
          #- name: CSI_RESIZER_IMAGE
          #  value: PREFIX/csi-resizer:v0.3.0
          # Manually specify number of CSI attacher replicas
          #- name: CSI_ATTACHER_REPLICA_COUNT
          #  value: "3"
          # Manually specify number of CSI provisioner replicas
          #- name: CSI_PROVISIONER_REPLICA_COUNT
          #  value: "3"
      #imagePullSecrets:
      #- name:
      serviceAccountName: longhorn-service-account
      securityContext:
        runAsUser: 0
---
EOF
}

create_storage_classes() {
  cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-replicated
  annotations:
    storageclass.kubernetes.io/is-default-class: "true"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "3"
  staleReplicaTimeout: "2880"
  fromBackup: ""
EOF
  cat <<EOF | kubectl apply -f -
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: longhorn-single
provisioner: driver.longhorn.io
allowVolumeExpansion: true
parameters:
  numberOfReplicas: "1"
  staleReplicaTimeout: "2880"
  fromBackup: ""
EOF
}

main "$@"