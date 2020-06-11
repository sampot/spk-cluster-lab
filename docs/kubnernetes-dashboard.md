# Install Kubernetes Dashboard

All commands are run from within spkmaster-1.


## Metric server

Deploy `metrics-server` first.

```sh
kubectl apply -f /vagrant/add-ons/metrics-server
```

## Deploy Dashboard UI

Then, deploy dashboard UI.

```sh
kubectl apply -f /vagrant/add-ons/dashboard
```

## Get a Bear Token

```sh
kubectl -n kubernetes-dashboard describe secret $(kubectl -n kubernetes-dashboard get secret | grep admin-user | awk '{print $1}')
```

## Access Dashboard UI

Gain access to the cluster by running proxy locally with following command:

```sh
kubectl proxy
```

The UI can be accssed at `http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/`.
