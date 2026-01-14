#!/bin/bash
# #### Quick fix for kubectl connection to MicroK8s ####
# #### Run this whenever kubectl can't connect ####

# Get MicroK8s kubeconfig
microk8s config > ~/.kube/microk8s-config

# Set as current context
export KUBECONFIG=~/.kube/microk8s-config

# Verify connection
kubectl cluster-info

echo "✅ kubectl is now connected to MicroK8s!"

