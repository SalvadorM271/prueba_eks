#!/bin/bash
/etc/eks/bootstrap.sh --apiserver-endpoint '${endpoint}' --b64-cluster-ca '${ca_cert}' --kubelet-extra-args "--node-labels=node.kubernetes.io/lifecycle=normal'
