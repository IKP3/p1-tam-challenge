#!/usr/bin/env bash
set -euo pipefail

USERNAME="web-user"
NAMESPACE="web-app"
CERT_DIR="cert"


KEY_FILE="${CERT_DIR}/${USERNAME}.key"
CSR_FILE="${CERT_DIR}/${USERNAME}.csr"
CRT_FILE="${CERT_DIR}/${USERNAME}.crt"
KUBECONFIG_OUT="kubeconfig/web-user.kubeconfig"

EXPIRY_SECONDS=3600

rm -rf "${CERT_DIR:?}"
mkdir -p "${CERT_DIR}"

openssl genrsa -out "${KEY_FILE}" 2048 
echo "Generated 2048-bit RSA key."

openssl req -new \
    -key "${KEY_FILE}" \
    -out "${CSR_FILE}" \
    -subj "/CN=${USERNAME}" 
echo "Generated CSR for CN=${USERNAME}."

kubectl delete csr "${USERNAME}" --ignore-not-found

CSR_BASE64=$(base64 < "${CSR_FILE}" | tr -d '\n')

cat <<EOF | kubectl apply -f -
apiVersion: certificates.k8s.io/v1
kind: CertificateSigningRequest
metadata:
  name: ${USERNAME}
spec:
  request: ${CSR_BASE64}
  signerName: kubernetes.io/kube-apiserver-client
  expirationSeconds: ${EXPIRY_SECONDS}
  usages:
  - client auth
EOF

echo "CSR submitted to Kubernetes API."

kubectl certificate approve "${USERNAME}"
echo "CSR approved."

echo -n "Waiting for signed certificate"
for i in $(seq 1 30); do
    CERT=$(kubectl get csr "${USERNAME}" -o jsonpath='{.status.certificate}' || true)
    if [[ -n "${CERT}" ]]; then
        echo ""
        echo "${CERT}" | base64 -d > "${CRT_FILE}"
        echo "Signed certificate saved."
        break
    fi
    echo -n "."
    sleep 1
done

if [[ ! -f "${CRT_FILE}" ]]; then
    echo ""
    echo "ERROR: Timed out waiting for certificate to be issued."
    exit 1
fi

SERVER=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.server}')

CA_FILE_SRC=$(kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority}')

CLUSTER_NAME="minikube"

kubectl --kubeconfig="${KUBECONFIG_OUT}" config set-cluster "${CLUSTER_NAME}" \
    --server="${SERVER}" \
    --certificate-authority="${CA_FILE_SRC}" \
    --embed-certs=true

kubectl --kubeconfig="${KUBECONFIG_OUT}" config set-credentials "${USERNAME}" \
    --client-certificate="${CRT_FILE}" \
    --client-key="${KEY_FILE}" \
    --embed-certs=true

kubectl --kubeconfig="${KUBECONFIG_OUT}" config set-context "${USERNAME}" \
    --cluster="${CLUSTER_NAME}" \
    --namespace="${NAMESPACE}" \
    --user="${USERNAME}"

kubectl --kubeconfig="${KUBECONFIG_OUT}" config use-context "${USERNAME}"

echo "Kubeconfig written to ${KUBECONFIG_OUT}"
