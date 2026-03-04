#!/bin/bash
###############################################################################
#  CKA Practice Exam — Automated Answer Validator
#  -----------------------------------------------
#  Validates your answers for all 17 CKA-PREP-2025-v2 labs and produces a
#  score report identical in style to the real CKA exam.
#
#  Passing score: 66%
#
#  Usage:
#    bash scripts/validate-cka.sh            # run ALL questions
#    bash scripts/validate-cka.sh 1 3 5      # run only Q1, Q3, Q5
#
#  Requirements: kubectl, helm (for Q2), jq (optional, falls back to grep)
###############################################################################
set -o pipefail

# ─── Colors & Symbols ───────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'
PASS_SYM="✅"; FAIL_SYM="❌"; WARN_SYM="⚠️"; LINE="━"

# ─── Global Counters ────────────────────────────────────────────────────────
TOTAL_CHECKS=0
PASSED_CHECKS=0
declare -A Q_TOTAL Q_PASSED Q_TITLE Q_WEIGHT

# ─── Helper Functions ────────────────────────────────────────────────────────

header() {
  local w=70
  printf "\n${CYAN}"
  printf '%*s' "$w" '' | tr ' ' "$LINE"
  printf "\n  %s\n" "$1"
  printf '%*s' "$w" '' | tr ' ' "$LINE"
  printf "${RESET}\n"
}

check() {
  # Usage: check <question_num> <description> <command...>
  local qnum="$1"; shift
  local desc="$1"; shift
  TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
  Q_TOTAL[$qnum]=$(( ${Q_TOTAL[$qnum]:-0} + 1 ))

  if eval "$@" >/dev/null 2>&1; then
    PASSED_CHECKS=$((PASSED_CHECKS + 1))
    Q_PASSED[$qnum]=$(( ${Q_PASSED[$qnum]:-0} + 1 ))
    printf "  ${GREEN}${PASS_SYM}  %-60s${RESET}\n" "$desc"
    return 0
  else
    printf "  ${RED}${FAIL_SYM}  %-60s${RESET}\n" "$desc"
    return 1
  fi
}

register_question() {
  # Usage: register_question <num> <title> <weight>
  Q_TITLE[$1]="$2"
  Q_WEIGHT[$1]="$3"
}

# ─── Determine which questions to run ────────────────────────────────────────
SELECTED_QUESTIONS=()
if [[ $# -gt 0 ]]; then
  for q in "$@"; do
    SELECTED_QUESTIONS+=("$q")
  done
else
  for i in $(seq 1 17); do
    SELECTED_QUESTIONS+=("$i")
  done
fi

should_run() {
  for q in "${SELECTED_QUESTIONS[@]}"; do
    [[ "$q" == "$1" ]] && return 0
  done
  return 1
}

###############################################################################
#  QUESTION 1 — MariaDB Persistent Volume (7% weight)
###############################################################################
register_question 1 "MariaDB — Persistent Volume" 7

validate_q1() {
  header "Question 1: MariaDB — Persistent Volume"

  # Check PVC exists with correct name in mariadb namespace
  check 1 "PVC 'mariadb' exists in namespace 'mariadb'" \
    "kubectl get pvc mariadb -n mariadb -o name 2>/dev/null | grep -q 'persistentvolumeclaim/mariadb'"

  # Check PVC access mode is ReadWriteOnce
  check 1 "PVC access mode is ReadWriteOnce" \
    "kubectl get pvc mariadb -n mariadb -o jsonpath='{.spec.accessModes[0]}' 2>/dev/null | grep -q 'ReadWriteOnce'"

  # Check PVC storage is 250Mi
  check 1 "PVC storage request is 250Mi" \
    "kubectl get pvc mariadb -n mariadb -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null | grep -q '250Mi'"

  # Check PVC is Bound
  check 1 "PVC is in Bound state" \
    "kubectl get pvc mariadb -n mariadb -o jsonpath='{.status.phase}' 2>/dev/null | grep -q 'Bound'"

  # Check Deployment exists
  check 1 "Deployment 'mariadb' exists in namespace 'mariadb'" \
    "kubectl get deployment mariadb -n mariadb -o name 2>/dev/null | grep -q 'deployment'"

  # Check Deployment uses the PVC
  check 1 "Deployment uses PVC 'mariadb' as volume" \
    "kubectl get deployment mariadb -n mariadb -o jsonpath='{.spec.template.spec.volumes[*].persistentVolumeClaim.claimName}' 2>/dev/null | grep -q 'mariadb'"

  # Check Deployment is Available
  check 1 "Deployment has Available condition" \
    "kubectl get deployment mariadb -n mariadb -o jsonpath='{.status.conditions[?(@.type==\"Available\")].status}' 2>/dev/null | grep -q 'True'"
}

###############################################################################
#  QUESTION 2 — ArgoCD Helm (5% weight)
###############################################################################
register_question 2 "ArgoCD — Helm Template" 5

validate_q2() {
  header "Question 2: ArgoCD — Helm Template"

  # Check argocd helm repo is added
  check 2 "Helm repo 'argocd' is added" \
    "helm repo list 2>/dev/null | grep -qi 'argocd.*argoproj.github.io/argo-helm'"

  # Check namespace argocd exists
  check 2 "Namespace 'argocd' exists" \
    "kubectl get namespace argocd -o name 2>/dev/null | grep -q 'namespace/argocd'"

  # Check /root/argo-helm.yaml exists
  check 2 "File /root/argo-helm.yaml exists" \
    "test -f /root/argo-helm.yaml"

  # Check the file is not empty and contains argocd resources
  check 2 "argo-helm.yaml contains ArgoCD manifests" \
    "grep -qi 'argocd\|argo-cd' /root/argo-helm.yaml 2>/dev/null"

  # Check CRDs are NOT in the generated template
  check 2 "CRDs are NOT included in the template (crds.install=false)" \
    "! grep -q 'kind: CustomResourceDefinition' /root/argo-helm.yaml 2>/dev/null"
}

###############################################################################
#  QUESTION 3 — Sidecar Container (7% weight)
###############################################################################
register_question 3 "Sidecar Container" 7

validate_q3() {
  header "Question 3: Sidecar Container"

  # Check wordpress deployment exists
  check 3 "Deployment 'wordpress' exists" \
    "kubectl get deployment wordpress -o name 2>/dev/null | grep -q 'deployment'"

  # Check sidecar container exists with correct name
  check 3 "Sidecar container 'sidecar' exists in the pod" \
    "kubectl get deployment wordpress -o jsonpath='{.spec.template.spec.containers[*].name}' 2>/dev/null | grep -q 'sidecar'"

  # Check sidecar uses busybox:stable image
  check 3 "Sidecar uses image 'busybox:stable'" \
    "kubectl get deployment wordpress -o jsonpath='{.spec.template.spec.containers[?(@.name==\"sidecar\")].image}' 2>/dev/null | grep -q 'busybox:stable'"

  # Check sidecar command contains tail -f /var/log/wordpress.log
  check 3 "Sidecar runs 'tail -f /var/log/wordpress.log'" \
    "kubectl get deployment wordpress -o json 2>/dev/null | grep -q 'tail -f /var/log/wordpress.log'"

  # Check shared volume exists (emptyDir)
  check 3 "Shared volume (emptyDir) is defined" \
    "kubectl get deployment wordpress -o json 2>/dev/null | grep -q 'emptyDir'"

  # Check sidecar has /var/log mount
  check 3 "Sidecar mounts volume at /var/log" \
    "kubectl get deployment wordpress -o jsonpath='{.spec.template.spec.containers[?(@.name==\"sidecar\")].volumeMounts[*].mountPath}' 2>/dev/null | grep -q '/var/log'"

  # Check wordpress container also mounts /var/log
  check 3 "WordPress container mounts volume at /var/log" \
    "kubectl get deployment wordpress -o jsonpath='{.spec.template.spec.containers[?(@.name==\"wordpress\")].volumeMounts[*].mountPath}' 2>/dev/null | grep -q '/var/log'"
}

###############################################################################
#  QUESTION 4 — Resource Allocation (6% weight)
###############################################################################
register_question 4 "Resource Allocation" 6

validate_q4() {
  header "Question 4: Resource Allocation"

  # Check deployment exists
  check 4 "Deployment 'wordpress' exists" \
    "kubectl get deployment -n resource-allocation wordpress -o name 2>/dev/null | grep -q 'deployment'"

  # Check replicas = 3
  check 4 "Deployment has 3 replicas" \
    "kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.replicas}' 2>/dev/null | grep -q '3'"

  # Check main container has resource requests
  check 4 "Main container has CPU requests defined" \
    "kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null | grep -qE '.+'"

  check 4 "Main container has memory requests defined" \
    "kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null | grep -qE '.+'"

  check 4 "Main container has CPU limits defined" \
    "kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.containers[0].resources.limits.cpu}' 2>/dev/null | grep -qE '.+'"

  check 4 "Main container has memory limits defined" \
    "kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.containers[0].resources.limits.memory}' 2>/dev/null | grep -qE '.+'"

  # Check init container has resource requests/limits
  check 4 "Init container has CPU requests defined" \
    "kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.initContainers[0].resources.requests.cpu}' 2>/dev/null | grep -qE '.+'"

  check 4 "Init container has memory requests defined" \
    "kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.initContainers[0].resources.requests.memory}' 2>/dev/null | grep -qE '.+'"

  # Check init and main containers have SAME resource values
  check 4 "Init and main containers have matching CPU requests" \
    "[ \"\$(kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.containers[0].resources.requests.cpu}' 2>/dev/null)\" = \"\$(kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.initContainers[0].resources.requests.cpu}' 2>/dev/null)\" ]"

  check 4 "Init and main containers have matching memory requests" \
    "[ \"\$(kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.containers[0].resources.requests.memory}' 2>/dev/null)\" = \"\$(kubectl get deployment -n resource-allocation wordpress -o jsonpath='{.spec.template.spec.initContainers[0].resources.requests.memory}' 2>/dev/null)\" ]"

  # Check pods are running
  check 4 "All 3 pods are Running" \
    "[ \$(kubectl get pods -n resource-allocation -l app=wordpress --field-selector=status.phase=Running --no-headers 2>/dev/null | wc -l) -ge 3 ]"
}

###############################################################################
#  QUESTION 5 — HPA (6% weight)
###############################################################################
register_question 5 "HPA — HorizontalPodAutoscaler" 6

validate_q5() {
  header "Question 5: HPA — HorizontalPodAutoscaler"

  # Check HPA exists with correct name
  check 5 "HPA 'apache-server' exists in namespace 'autoscale'" \
    "kubectl get hpa apache-server -n autoscale -o name 2>/dev/null | grep -q 'horizontalpodautoscaler'"

  # Check target deployment
  check 5 "HPA targets deployment 'apache-deployment'" \
    "kubectl get hpa apache-server -n autoscale -o jsonpath='{.spec.scaleTargetRef.name}' 2>/dev/null | grep -q 'apache-deployment'"

  # Check minReplicas
  check 5 "HPA minReplicas is 1" \
    "[ \"\$(kubectl get hpa apache-server -n autoscale -o jsonpath='{.spec.minReplicas}' 2>/dev/null)\" = '1' ]"

  # Check maxReplicas
  check 5 "HPA maxReplicas is 4" \
    "[ \"\$(kubectl get hpa apache-server -n autoscale -o jsonpath='{.spec.maxReplicas}' 2>/dev/null)\" = '4' ]"

  # Check CPU target 50%
  check 5 "HPA targets 50% CPU utilization" \
    "kubectl get hpa apache-server -n autoscale -o json 2>/dev/null | grep -q '\"averageUtilization\":50\|\"averageUtilization\": 50'"

  # Check scaleDown stabilization window = 30
  check 5 "Downscale stabilization window is 30 seconds" \
    "kubectl get hpa apache-server -n autoscale -o json 2>/dev/null | grep -q '\"stabilizationWindowSeconds\":30\|\"stabilizationWindowSeconds\": 30'"
}

###############################################################################
#  QUESTION 6 — CRDs (5% weight)
###############################################################################
register_question 6 "CRDs — cert-manager" 5

validate_q6() {
  header "Question 6: CRDs — cert-manager"

  # Check /root/resources.yaml exists
  check 6 "File /root/resources.yaml exists" \
    "test -f /root/resources.yaml"

  # Check it contains cert-manager CRDs
  check 6 "resources.yaml contains cert-manager CRD entries" \
    "grep -qi 'cert-manager' /root/resources.yaml 2>/dev/null"

  # Check /root/subject.yaml exists
  check 6 "File /root/subject.yaml exists" \
    "test -f /root/subject.yaml"

  # Check it contains subject documentation
  check 6 "subject.yaml contains subject spec documentation" \
    "grep -qiE 'subject|field|kind|description' /root/subject.yaml 2>/dev/null"
}

###############################################################################
#  QUESTION 7 — PriorityClass (6% weight)
###############################################################################
register_question 7 "PriorityClass" 6

validate_q7() {
  header "Question 7: PriorityClass"

  # Check PriorityClass high-priority exists
  check 7 "PriorityClass 'high-priority' exists" \
    "kubectl get priorityclass high-priority -o name 2>/dev/null | grep -q 'priorityclass'"

  # Check value is 999 (one less than user-critical=1000)
  check 7 "PriorityClass value is 999 (one less than highest)" \
    "[ \"\$(kubectl get priorityclass high-priority -o jsonpath='{.value}' 2>/dev/null)\" = '999' ]"

  # Check deployment uses high-priority
  check 7 "Deployment 'busybox-logger' uses 'high-priority' class" \
    "kubectl get deployment busybox-logger -n priority -o jsonpath='{.spec.template.spec.priorityClassName}' 2>/dev/null | grep -q 'high-priority'"

  # Check deployment is running
  check 7 "Deployment 'busybox-logger' pods are running" \
    "kubectl get deployment busybox-logger -n priority -o jsonpath='{.status.availableReplicas}' 2>/dev/null | grep -qE '[1-9]'"
}

###############################################################################
#  QUESTION 8 — CNI & Network Policy (6% weight)
###############################################################################
register_question 8 "CNI & Network Policy" 6

validate_q8() {
  header "Question 8: CNI & Network Policy"

  # Check if a CNI is installed (Calico or Flannel)
  check 8 "A CNI plugin is installed (Calico or Flannel)" \
    "kubectl get pods -A 2>/dev/null | grep -qiE 'calico|flannel|tigera'"

  # Check nodes are Ready (CNI working)
  check 8 "All nodes are in Ready state" \
    "! kubectl get nodes --no-headers 2>/dev/null | grep -q 'NotReady'"

  # Check pods can communicate (coredns running = basic pod networking works)
  check 8 "CoreDNS pods are running (pod networking functional)" \
    "kubectl get pods -n kube-system -l k8s-app=kube-dns --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q '.'"

  # Check NetworkPolicy support (try to list network policies without error)
  check 8 "Cluster supports NetworkPolicy resources" \
    "kubectl api-resources 2>/dev/null | grep -q 'networkpolicies'"
}

###############################################################################
#  QUESTION 9 — Cri-Dockerd (6% weight)
###############################################################################
register_question 9 "Cri-Dockerd" 6

validate_q9() {
  header "Question 9: Cri-Dockerd"

  # Check cri-dockerd is installed
  check 9 "cri-dockerd package is installed" \
    "dpkg -l cri-dockerd 2>/dev/null | grep -q '^ii'"

  # Check cri-docker service is enabled
  check 9 "cri-docker.service is enabled" \
    "systemctl is-enabled cri-docker.service 2>/dev/null | grep -q 'enabled'"

  # Check cri-docker service is active
  check 9 "cri-docker.service is active (running)" \
    "systemctl is-active cri-docker.service 2>/dev/null | grep -q 'active'"

  # Check sysctl: net.bridge.bridge-nf-call-iptables = 1
  check 9 "net.bridge.bridge-nf-call-iptables = 1" \
    "[ \"\$(sysctl -n net.bridge.bridge-nf-call-iptables 2>/dev/null)\" = '1' ]"

  # Check sysctl: net.ipv6.conf.all.forwarding = 1
  check 9 "net.ipv6.conf.all.forwarding = 1" \
    "[ \"\$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null)\" = '1' ]"

  # Check sysctl: net.ipv4.ip_forward = 1
  check 9 "net.ipv4.ip_forward = 1" \
    "[ \"\$(sysctl -n net.ipv4.ip_forward 2>/dev/null)\" = '1' ]"

  # Check sysctl: net.netfilter.nf_conntrack_max = 131072
  check 9 "net.netfilter.nf_conntrack_max = 131072" \
    "[ \"\$(sysctl -n net.netfilter.nf_conntrack_max 2>/dev/null)\" = '131072' ]"
}

###############################################################################
#  QUESTION 10 — Taints & Tolerations (6% weight)
###############################################################################
register_question 10 "Taints & Tolerations" 6

validate_q10() {
  header "Question 10: Taints & Tolerations"

  # Check node01 has the taint PERMISSION=granted:NoSchedule
  check 10 "node01 has taint PERMISSION=granted:NoSchedule" \
    "kubectl describe node node01 2>/dev/null | grep -q 'PERMISSION=granted:NoSchedule'"

  # Check a pod with toleration exists and is Running
  check 10 "A pod with PERMISSION toleration exists and is Running" \
    "kubectl get pods -o json 2>/dev/null | grep -q '\"key\":\"PERMISSION\"'"

  # Check the tolerating pod is actually scheduled on node01
  check 10 "Tolerating pod is scheduled on node01" \
    "kubectl get pods -o wide --no-headers 2>/dev/null | grep -v 'Pending\|nginx-fail' | grep -q 'node01'"
}

###############################################################################
#  QUESTION 11 — Gateway API (7% weight)
###############################################################################
register_question 11 "Gateway API" 7

validate_q11() {
  header "Question 11: Gateway API"

  # Check Gateway resource exists
  check 11 "Gateway 'web-gateway' exists" \
    "kubectl get gateway web-gateway -o name 2>/dev/null | grep -q 'gateway'"

  # Check Gateway uses nginx-class
  check 11 "Gateway uses GatewayClass 'nginx-class'" \
    "kubectl get gateway web-gateway -o jsonpath='{.spec.gatewayClassName}' 2>/dev/null | grep -q 'nginx-class'"

  # Check Gateway hostname
  check 11 "Gateway listener hostname is 'gateway.web.k8s.local'" \
    "kubectl get gateway web-gateway -o json 2>/dev/null | grep -q 'gateway.web.k8s.local'"

  # Check Gateway has HTTPS listener
  check 11 "Gateway has HTTPS listener on port 443" \
    "kubectl get gateway web-gateway -o json 2>/dev/null | grep -qE '\"protocol\":\\s*\"HTTPS\"|\"port\":\\s*443'"

  # Check TLS configuration references web-tls secret
  check 11 "Gateway TLS references secret 'web-tls'" \
    "kubectl get gateway web-gateway -o json 2>/dev/null | grep -q 'web-tls'"

  # Check HTTPRoute exists
  check 11 "HTTPRoute 'web-route' exists" \
    "kubectl get httproute web-route -o name 2>/dev/null | grep -q 'httproute'"

  # Check HTTPRoute references web-gateway
  check 11 "HTTPRoute references parent 'web-gateway'" \
    "kubectl get httproute web-route -o json 2>/dev/null | grep -q 'web-gateway'"

  # Check HTTPRoute hostname
  check 11 "HTTPRoute hostname is 'gateway.web.k8s.local'" \
    "kubectl get httproute web-route -o json 2>/dev/null | grep -q 'gateway.web.k8s.local'"

  # Check HTTPRoute backend references web-service
  check 11 "HTTPRoute backend references 'web-service'" \
    "kubectl get httproute web-route -o json 2>/dev/null | grep -q 'web-service'"
}

###############################################################################
#  QUESTION 12 — Ingress (6% weight)
###############################################################################
register_question 12 "Ingress" 6

validate_q12() {
  header "Question 12: Ingress"

  # Check service exists
  check 12 "Service 'echo-service' exists in namespace 'echo-sound'" \
    "kubectl get svc echo-service -n echo-sound -o name 2>/dev/null | grep -q 'service'"

  # Check service type is NodePort
  check 12 "Service type is NodePort" \
    "kubectl get svc echo-service -n echo-sound -o jsonpath='{.spec.type}' 2>/dev/null | grep -q 'NodePort'"

  # Check service port is 8080
  check 12 "Service port is 8080" \
    "kubectl get svc echo-service -n echo-sound -o jsonpath='{.spec.ports[0].port}' 2>/dev/null | grep -q '8080'"

  # Check ingress exists
  check 12 "Ingress 'echo' exists in namespace 'echo-sound'" \
    "kubectl get ingress echo -n echo-sound -o name 2>/dev/null | grep -q 'ingress'"

  # Check ingress host is example.org
  check 12 "Ingress host is 'example.org'" \
    "kubectl get ingress echo -n echo-sound -o json 2>/dev/null | grep -q 'example.org'"

  # Check ingress path is /echo
  check 12 "Ingress path is '/echo'" \
    "kubectl get ingress echo -n echo-sound -o json 2>/dev/null | grep -q '/echo'"

  # Check ingress backend references echo-service on port 8080
  check 12 "Ingress backend references 'echo-service' port 8080" \
    "kubectl get ingress echo -n echo-sound -o json 2>/dev/null | grep -q 'echo-service'"
}

###############################################################################
#  QUESTION 13 — Network Policy (6% weight)
###############################################################################
register_question 13 "Network Policy" 6

validate_q13() {
  header "Question 13: Network Policy"

  # Check a network policy is applied in backend namespace
  check 13 "A NetworkPolicy exists in namespace 'backend'" \
    "kubectl get networkpolicy -n backend --no-headers 2>/dev/null | grep -q '.'"

  # Check the correct policy (policy-z) is applied — least permissive
  check 13 "NetworkPolicy 'policy-z' is applied (least permissive)" \
    "kubectl get networkpolicy policy-z -n backend -o name 2>/dev/null | grep -q 'networkpolicy'"

  # Check policy targets backend pods
  check 13 "Policy targets pods with label app=backend" \
    "kubectl get networkpolicy policy-z -n backend -o json 2>/dev/null | grep -q '\"app\":\"backend\"\|\"app\": \"backend\"'"

  # Check policy allows from frontend namespace
  check 13 "Policy allows ingress from frontend namespace" \
    "kubectl get networkpolicy policy-z -n backend -o json 2>/dev/null | grep -q 'frontend'"

  # Verify policy-1 (too open) is NOT the only one applied
  check 13 "Over-permissive policy-x is NOT the only active policy" \
    "kubectl get networkpolicy policy-z -n backend -o name 2>/dev/null | grep -q 'policy-z'"
}

###############################################################################
#  QUESTION 14 — Storage Class (6% weight)
###############################################################################
register_question 14 "StorageClass" 6

validate_q14() {
  header "Question 14: StorageClass"

  # Check StorageClass exists
  check 14 "StorageClass 'local-storage' exists" \
    "kubectl get storageclass local-storage -o name 2>/dev/null | grep -q 'storageclass'"

  # Check provisioner
  check 14 "Provisioner is 'rancher.io/local-path'" \
    "kubectl get storageclass local-storage -o jsonpath='{.provisioner}' 2>/dev/null | grep -q 'rancher.io/local-path'"

  # Check VolumeBindingMode
  check 14 "VolumeBindingMode is 'WaitForFirstConsumer'" \
    "kubectl get storageclass local-storage -o jsonpath='{.volumeBindingMode}' 2>/dev/null | grep -q 'WaitForFirstConsumer'"

  # Check it is the default StorageClass
  check 14 "local-storage is marked as default" \
    "kubectl get storageclass local-storage -o jsonpath='{.metadata.annotations.storageclass\\.kubernetes\\.io/is-default-class}' 2>/dev/null | grep -q 'true'"

  # Check no other SC is default
  check 14 "local-storage is the ONLY default StorageClass" \
    "[ \$(kubectl get storageclass -o json 2>/dev/null | grep -c '\"storageclass.kubernetes.io/is-default-class\":\"true\"\|\"storageclass.kubernetes.io/is-default-class\": \"true\"') -le 1 ]"
}

###############################################################################
#  QUESTION 15 — Etcd Fix (7% weight)
###############################################################################
register_question 15 "Etcd Fix" 7

validate_q15() {
  header "Question 15: Etcd Fix"

  # Check kube-apiserver manifest has correct etcd port (2379, not 2380)
  check 15 "kube-apiserver manifest uses etcd port 2379 (not 2380)" \
    "sudo grep -q '2379' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null && ! sudo grep -q 'etcd-servers.*2380' /etc/kubernetes/manifests/kube-apiserver.yaml 2>/dev/null"

  # Check kube-apiserver pod is running
  check 15 "kube-apiserver pod is running" \
    "kubectl get pods -n kube-system -l component=kube-apiserver --field-selector=status.phase=Running --no-headers 2>/dev/null | grep -q 'kube-apiserver'"

  # Check kubectl works (API server is reachable)
  check 15 "kubectl can reach the API server" \
    "kubectl get nodes 2>/dev/null | grep -q '.'"

  # Check etcd pod is running
  check 15 "etcd pod is running in kube-system" \
    "kubectl get pods -n kube-system -l component=etcd --no-headers 2>/dev/null | grep -q 'Running'"
}

###############################################################################
#  QUESTION 16 — NodePort (6% weight)
###############################################################################
register_question 16 "NodePort" 6

validate_q16() {
  header "Question 16: NodePort"

  # Check deployment has container port defined
  check 16 "Deployment has container port 80 defined" \
    "kubectl get deployment nodeport-deployment -n relative -o json 2>/dev/null | grep -q '\"containerPort\":80\|\"containerPort\": 80'"

  # Check container port name is http
  check 16 "Container port name is 'http'" \
    "kubectl get deployment nodeport-deployment -n relative -o json 2>/dev/null | grep -q '\"name\":\"http\"\|\"name\": \"http\"'"

  # Check service exists
  check 16 "Service 'nodeport-service' exists in namespace 'relative'" \
    "kubectl get svc nodeport-service -n relative -o name 2>/dev/null | grep -q 'service'"

  # Check service type is NodePort
  check 16 "Service type is NodePort" \
    "kubectl get svc nodeport-service -n relative -o jsonpath='{.spec.type}' 2>/dev/null | grep -q 'NodePort'"

  # Check service port is 80
  check 16 "Service port is 80" \
    "kubectl get svc nodeport-service -n relative -o jsonpath='{.spec.ports[0].port}' 2>/dev/null | grep -q '80'"

  # Check nodePort is 30080
  check 16 "NodePort is 30080" \
    "kubectl get svc nodeport-service -n relative -o jsonpath='{.spec.ports[0].nodePort}' 2>/dev/null | grep -q '30080'"
}

###############################################################################
#  QUESTION 17 — TLS Config (8% weight)
###############################################################################
register_question 17 "TLS Configuration" 8

validate_q17() {
  header "Question 17: TLS Configuration"

  # Check ConfigMap only has TLSv1.3
  check 17 "ConfigMap 'nginx-config' only supports TLSv1.3" \
    "kubectl get configmap nginx-config -n nginx-static -o jsonpath='{.data.nginx\\.conf}' 2>/dev/null | grep -q 'TLSv1.3' && ! kubectl get configmap nginx-config -n nginx-static -o jsonpath='{.data.nginx\\.conf}' 2>/dev/null | grep -q 'TLSv1.2'"

  # Check /etc/hosts has the entry
  check 17 "/etc/hosts contains 'ckaquestion.k8s.local'" \
    "grep -q 'ckaquestion.k8s.local' /etc/hosts 2>/dev/null"

  # Check deployment is running
  check 17 "Deployment 'nginx-static' is running" \
    "kubectl get deployment nginx-static -n nginx-static -o jsonpath='{.status.availableReplicas}' 2>/dev/null | grep -qE '[1-9]'"

  # Check TLSv1.3 works (if curl available and service is up)
  check 17 "TLSv1.3 connection succeeds" \
    "curl -sk --tlsv1.3 https://ckaquestion.k8s.local 2>/dev/null | grep -qi 'hello\|tls\|200\|nginx'"

  # Check TLSv1.2 is rejected
  check 17 "TLSv1.2 connection is rejected" \
    "! curl -sk --tls-max 1.2 https://ckaquestion.k8s.local 2>/dev/null | grep -qi 'hello\|tls'"
}

###############################################################################
#  MAIN — Run validations & produce score report
###############################################################################

clear 2>/dev/null || true

printf "\n${BOLD}"
cat << 'BANNER'
   ╔═══════════════════════════════════════════════════════════════════╗
   ║          CKA Practice Exam — Automated Validator                ║
   ║          Passing Score: 66%                                     ║
   ╚═══════════════════════════════════════════════════════════════════╝
BANNER
printf "${RESET}\n"

printf "  ${CYAN}Starting validation at $(date '+%Y-%m-%d %H:%M:%S')${RESET}\n"
printf "  ${CYAN}Questions selected: ${SELECTED_QUESTIONS[*]}${RESET}\n"

# Run each selected question
should_run 1  && validate_q1
should_run 2  && validate_q2
should_run 3  && validate_q3
should_run 4  && validate_q4
should_run 5  && validate_q5
should_run 6  && validate_q6
should_run 7  && validate_q7
should_run 8  && validate_q8
should_run 9  && validate_q9
should_run 10 && validate_q10
should_run 11 && validate_q11
should_run 12 && validate_q12
should_run 13 && validate_q13
should_run 14 && validate_q14
should_run 15 && validate_q15
should_run 16 && validate_q16
should_run 17 && validate_q17

###############################################################################
#  SCORE REPORT
###############################################################################

header "EXAM RESULTS"

# Calculate weighted score
WEIGHTED_EARNED=0
WEIGHTED_TOTAL=0

printf "\n  ${BOLD}%-6s %-40s %8s %8s %8s${RESET}\n" "Q#" "Topic" "Checks" "Passed" "Score"
printf "  %-6s %-40s %8s %8s %8s\n" "------" "----------------------------------------" "--------" "--------" "--------"

for q in "${SELECTED_QUESTIONS[@]}"; do
  total=${Q_TOTAL[$q]:-0}
  passed=${Q_PASSED[$q]:-0}
  title=${Q_TITLE[$q]:-"Unknown"}
  weight=${Q_WEIGHT[$q]:-5}

  if [[ $total -gt 0 ]]; then
    q_pct=$(echo "scale=1; $passed * 100 / $total" | bc)
    q_weighted=$(echo "scale=2; $passed * $weight / $total" | bc)
  else
    q_pct="0.0"
    q_weighted="0"
  fi

  WEIGHTED_EARNED=$(echo "scale=2; $WEIGHTED_EARNED + $q_weighted" | bc)
  WEIGHTED_TOTAL=$(echo "scale=2; $WEIGHTED_TOTAL + $weight" | bc)

  if [[ "$passed" == "$total" ]]; then
    color="$GREEN"
  elif [[ "$passed" == "0" ]]; then
    color="$RED"
  else
    color="$YELLOW"
  fi

  printf "  ${color}%-6s %-40s %5s    %5s    %5s%%${RESET}\n" \
    "Q${q}" "$title" "$total" "$passed" "$q_pct"
done

# Final percentage
if [[ $(echo "$WEIGHTED_TOTAL > 0" | bc) -eq 1 ]]; then
  FINAL_SCORE=$(echo "scale=1; $WEIGHTED_EARNED * 100 / $WEIGHTED_TOTAL" | bc)
else
  FINAL_SCORE="0.0"
fi

PASSING_SCORE=66

printf "\n"
printf "  %-6s %-40s %8s %8s\n" "------" "----------------------------------------" "--------" "--------"
printf "  ${BOLD}%-6s %-40s %5s    %5s${RESET}\n" "TOTAL" "All Checks" "$TOTAL_CHECKS" "$PASSED_CHECKS"

printf "\n"
printf "  ${BOLD}╔═══════════════════════════════════════════╗${RESET}\n"

if [[ $(echo "$FINAL_SCORE >= $PASSING_SCORE" | bc) -eq 1 ]]; then
  printf "  ${BOLD}║  ${GREEN}FINAL SCORE: %5s%%   ✅  PASSED!${RESET}${BOLD}        ║${RESET}\n" "$FINAL_SCORE"
else
  printf "  ${BOLD}║  ${RED}FINAL SCORE: %5s%%   ❌  FAILED${RESET}${BOLD}         ║${RESET}\n" "$FINAL_SCORE"
fi

printf "  ${BOLD}║  Passing Score: %3s%%                      ║${RESET}\n" "$PASSING_SCORE"
printf "  ${BOLD}╚═══════════════════════════════════════════╝${RESET}\n"

printf "\n  ${CYAN}Validation completed at $(date '+%Y-%m-%d %H:%M:%S')${RESET}\n\n"

# Exit code: 0 if passed, 1 if failed
[[ $(echo "$FINAL_SCORE >= $PASSING_SCORE" | bc) -eq 1 ]]
