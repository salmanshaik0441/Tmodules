#!/bin/bash

LOGS="["
log_stream_name=`hostname`_`date +'%Y%m%d-%_H%_M'`
aws logs create-log-stream --log-group-name "/aws/eks/${cluster_name}/cluster" --log-stream-name $log_stream_name --region ${aws_region}

function log_to_cloud_watch {
    sv_name=$1
    journal=$(journalctl --since "1 hour ago" -u $1 -n 300 --no-pager -o json | jq -r -c '.')
    while read -r line
    do
      message_time=`echo $line | jq '.__REALTIME_TIMESTAMP' | tr -d '"'`
      # Converting to milliseconds needed by cloudwatch, journalct __REALTIME_TIMESTAMP is in microseconds
      message_time=$${message_time::-3}
      message=$(echo $line | jq '.MESSAGE')
      LOGS+="{\"timestamp\": $message_time, \"message\": $message},"
    done <<< "$journal"

}

if ! systemctl is-active --quiet kubelet; then
    echo "Kubelet not running"
    INSTANCE_ID=$(curl http://169.254.169.254/latest/meta-data/instance-id)
    aws cloudwatch put-metric-data --metric-name InstanceKubeletUnhealthy --namespace ${cluster_name}/autoscaler --unit Count --value 1 --dimensions InstanceId=$INSTANCE_ID --region ${aws_region}

    # Next exporting kubelet and docker logs to cloudwatch
    log_to_cloud_watch kubelet
    log_to_cloud_watch containerd

    LOGS=$${LOGS::-1}
    LOGS+="]"
    echo $LOGS | jq -r -c '.|=sort_by(.timestamp)' > journal_logs.json
    aws logs put-log-events --log-group-name "/aws/eks/${cluster_name}/cluster" --log-stream-name $log_stream_name --log-events=file://journal_logs.json --region ${aws_region}

    # Draining self from the cluster
    export KUBECONFIG=/var/lib/kubelet/kubeconfig
    K8_HOSTNAME=`curl http://169.254.169.254/latest/meta-data/hostname | cut -d' ' -f1`
    kubectl drain $K8_HOSTNAME --force --ignore-daemonsets --delete-emptydir-data --grace-period=10


    # Next terminate instance
    aws autoscaling terminate-instance-in-auto-scaling-group --instance-id $INSTANCE_ID --no-should-decrement-desired-capacity --region ${aws_region}

fi