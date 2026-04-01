# Kubernetes RBAC + Client Certificate User Setup

This project demonstrates how to create a restricted Kubernetes user using client certificates and RBAC, and use that user to deploy an application in a namespace.

## Prerequisites

- Minikube cluster running
- kubectl installed and configured
- OpenSSL installed

> Note: The script currently assumes the cluster name is "minikube".

## Quick Start

```bash
minikube start

chmod +x setup.sh

./setup.sh

kubectl --kubeconfig=kubeconfig/web-user.kubeconfig apply -f k8s/nginx.yaml

kubectl --kubeconfig=kubeconfig/web-user.kubeconfig -n web-app get pods
```

## What this demonstrates

- Creating a namespace
- Defining RBAC roles and role bindings
- Generating a client certificate using OpenSSL
- Submitting and approving a Kubernetes CSR
- Creating a custom kubeconfig for a non-admin user
- Deploying an application with restricted permissions

## Detailed Flow

1. Apply the namespace and RBAC configuration:

   ```bash
   kubectl apply -f k8s/namespace.yaml
   kubectl apply -f k8s/rbac.yaml
   ```

2. Generate credentials for the restricted user:

   ```bash
   chmod +x scripts/create-user.sh
   ./scripts/create-user.sh
   ```

   This step:

   * Creates a private key and CSR
   * Submits and approves the CSR in Kubernetes
   * Retrieves the signed certificate
   * Builds a kubeconfig for `web-user`

3. Authenticate as the restricted user:

   ```bash
   kubectl --kubeconfig=kubeconfig/web-user.kubeconfig get pods
   ```

4. Deploy an application as `web-user`:

   ```bash
   kubectl --kubeconfig=kubeconfig/web-user.kubeconfig apply -f k8s/nginx.yaml
   ```

5. Verify the deployment:

   ```bash
   kubectl --kubeconfig=kubeconfig/web-user.kubeconfig -n web-app get pods
   ```

## RBAC

RBAC (Role-Based Access Control) is used to restrict what the `web-user` can do within the cluster.

A namespace-scoped **Role** and **RoleBinding** are created in the `web-app` namespace.

The Role allows the user to:
- create and update `deployments` and `services`
- read `pods`, `replicasets`, and `events`
- access `pods/log` for troubleshooting

The RoleBinding assigns these permissions to `web-user`.

This ensures the user can deploy and manage the Nginx application while being restricted from accessing other namespaces or sensitive resources like Secrets.

## Certificates

A private key and CSR are generated using OpenSSL.

The CSR is base64-encoded and submitted to Kubernetes as a CertificateSigningRequest.

After approval, the signed certificate is retrieved and used to authenticate the user.

## Kubeconfig

A kubeconfig file is created containing:
- cluster information
- the signed client certificate
- the private key

This allows kubectl to authenticate as `web-user`.

## Security Notes

- Kubernetes does not natively support certificate revocation. If a certificate is compromised, it remains valid until it expires, which is why short-lived certificates are used
- The client certificate is short-lived (1 hour), reducing the risk if credentials are leaked
- Access is restricted to the `web-app` namespace using RBAC (Role + RoleBinding)
- The private key used for authentication must be stored securely, as anyone with access to it can authenticate as the user
- The private key is not encrypted in this setup, so file-level security is important. In production, keys are often encrypted or managed using secure storage solutions
- The kubeconfig file contains embedded credentials (certificate and private key), so it should be protected and not committed to version control
- Nginx runs with dropped capabilities






