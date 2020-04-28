#!/bin/bash
#
# This is a script that will wait for CSRs to be submitted by OCP worker nodes,
# and will then approve them, based on the input given as parameters.
#
# Parameters:
#   $1 = openshift binary path
#   $2 = cluster runtime information directory
#   $3... = the names of workers to approve (a python array is *expected*)
#
# NOTE: Yes, yes, I know this could have been done way better but it's 2:30am.
if [ -n "$1" ]; then
    OC="$1"
    shift
else
    echo "FATAL: not enough parameters!"
    exit 1
fi

if [ -n "$1" ]; then
    CRT="$1"
    QC="${CRT}/auth/kubeconfig"
    shift
else
    echo "FATAL: not enough parameters!"
    exit 1
fi

if [ ! -d "${CRT}" ]; then
    echo "FATAL: not a directory: ${CRT}"
    exit 1
fi
if [ ! -e "${QC}" ]; then
    echo "FATAL: kubeconfig not found: ${QC}"
    exit 1
fi

CMD="${OC} --kubeconfig=${QC}"


echo "Override Deployment for AIO"
${CMD} get csr | grep Pending | grep :node-bootstrapper

sleep 60

${CMD} patch clusterversion/version --type json --patch '[{"op": "add", "path": "/spec/overrides", "value": [{"group": "apps/v1", "kind": "Deployment", "name": "etcd-quorum-guard", "namespace": "openshift-machine-config-operator", "unmanaged": True}]}]'

sleep 240

echo "Scaleing Deployment for one replica"
${CMD} scale --replicas=1 deployment/etcd-quorum-guard -n openshift-machine-config-operator
${CMD} scale --replicas=1 ingresscontroller/default -n openshift-ingress-operator
${CMD} scale --replicas=1 deployment.apps/console -n openshift-console
${CMD} scale --replicas=1 deployment.apps/downloads -n openshift-console
${CMD} scale --replicas=1 deployment.apps/oauth-openshift -n openshift-authentication
${CMD} scale --replicas=1 deployment.apps/packageserver -n openshift-operator-lifecycle-manager
${CMD} scale --replicas=1 deployment.apps/prometheus-adapter -n openshift-monitoring
${CMD} scale --replicas=1 deployment.apps/thanos-querier -n openshift-monitoring
${CMD} scale --replicas=1 statefulset.apps/prometheus-k8s -n openshift-monitoring
${CMD} scale --replicas=1 statefulset.apps/alertmanager-main -n openshift-monitoring

