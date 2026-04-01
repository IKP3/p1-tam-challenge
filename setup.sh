#!/usr/bin/env bash

kubectl apply -f k8s/namespace.yaml

kubectl apply -f k8s/rbac.yaml

chmod +x scripts/create-user.sh

./scripts/create-user.sh
