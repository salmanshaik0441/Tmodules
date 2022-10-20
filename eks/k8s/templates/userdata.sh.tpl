#!/bin/bash

set -o xtrace
#exec > >(tee /home/ec2-user/user-data.log|logger -t /home/ec2-user/user-data -s 2>/dev/null) 2>&1

############################## KUBELET HEALTH SECTION ##############################

cat << EOF > /etc/systemd/system/kubelet-health-check.service
[Unit]
Description=Check health of Kubelet service
Wants=kubelet-health-check.timer

[Service]
Type=oneshot
ExecStart=/home/ec2-user/kubelet-health-check

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/kubelet-health-check.timer
[Unit]
Description=Schedule Kubelet health check

[Timer]
Unit=kubelet-health-check.service
OnBootSec=${asg_health_check_grace_period}sec
OnUnitActiveSec=${kubelet_health_check_interval}sec

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable kubelet-health-check.timer
systemctl start kubelet-health-check.timer

############################ END KUBELET HEALTH SECTION ############################

############################ KUBELET PRE-SHUTDOWN DRAIN SERVICE ####################

cat << EOF > /home/ec2-user/pre-shutdown
#!/bin/bash

export KUBECONFIG=/var/lib/kubelet/kubeconfig
K8_HOSTNAME=`curl http://169.254.169.254/latest/meta-data/hostname | cut -d' ' -f1`
kubectl drain \$K8_HOSTNAME --ignore-daemonsets --delete-emptydir-data --grace-period=5 --force

EOF

chmod +x /home/ec2-user/pre-shutdown
# Changing the service to be what we using for Prometheus stand alone services as we know that works
cat << EOF > /etc/systemd/system/k8-drain-node.service
[Unit]
Description=drain node before shutdown so as to make gracefull exit from cluster
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target poweroff.target exit.target

[Service]
Type=oneshot
ExecStart=/bin/true
ExecStop=/bin/bash -x /home/ec2-user/pre-shutdown
TimeoutStartSec=0

[Install]
WantedBy=shutdown.target reboot.target halt.target poweroff.target exit.target

EOF
# Running systemctl daemon-reload and starting the service at the end of userdata because we require 
# /var/lib/kubelet/kubeconfig which only gets created by eks bootstrap

############################ END KUBELET PRE-SHUTDOWN DRAIN SERVICE ################

curl -o /usr/bin/kubectl ${kubectl_binary}
chmod +x /usr/bin/kubectl

export KUBECONFIG=/var/lib/kubelet/kubeconfig

yum update && yum upgrade -y

ec2hostname=$(curl --silent http://169.254.169.254/latest/meta-data/local-hostname  | cut -d '.' -f1)
sudo hostnamectl set-hostname --static $ec2hostname

sudo systemctl stop kubelet

sudo swapoff -a

cat << EOF > /home/ec2-user/appdpull.sh
#!/bin/bash
set -x

############################## APPDYNAMICS SECTION ##############################
# Downloading appd jars that get mounted by pods for appd.
# Putting on all hosts irrespective if appd is enabled or not so that if at a later stage we
# enable appd all we need to do is install the machine agent ds.
sudo mkdir -p /var/lib/kubelet/appdynamics/appdynamics-java-agent
sudo chmod 777 -R /var/lib/kubelet/appdynamics/appdynamics-java-agent
cd /var/lib/kubelet/appdynamics/appdynamics-java-agent
while :; do
  curl -v https://artifactory.orbit.prod.vodacom.co.za/artifactory/local-dists/appdynamics-agents/ > /tmp/appdagent-load-stdout.txt 2> /tmp/appdagent-load-stderr.txt
  if [ ! $? -eq 0 ]; then
    continue;
  fi
  cat /tmp/appdagent-load-stderr.txt | grep 'HTTP.*200'
  if [ ! $? -eq 0 ]; then
    continue;
  fi
  NEEDEDFILES=\$(cat /tmp/appdagent-load-stdout.txt | grep -E '>app.*(gz|tar)<' -o | tr -d '<>' | wc -l)
  if [ \$NEEDEDFILES -eq 0 ];
  then
    continue
  fi
  cat /tmp/appdagent-load-stdout.txt | grep -E '>app.*(gz|tar)<' -o | tr -d '<>' | while read -r art;
    do
      while :;
      do
        rm \$art*;
        curl 'https://artifactory.orbit.prod.vodacom.co.za/artifactory/local-dists/appdynamics-agents/'\$art -O;
        if [ ! $? -eq 0 ]; then
          rm \$art*;
        else
          break;
        fi
      done
    done
    ACTUALFILES=\$(ls . | wc -l)
    if [ "\$ACTUALFILES" -ge "\$NEEDEDFILES" ];
    then
      break
    fi
done
ls | grep 'tar$' | xargs -n1 tar -xf

EOF
chmod +x /home/ec2-user/appdpull.sh


cat << EOF > /etc/systemd/system/appdagentpull.service
[Unit]
Description=Pulls appdynamics agents
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /home/ec2-user/appdpull.sh

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable appdagentpull
systemctl start appdagentpull


line=$(cat /etc/eks/eni-max-pods.txt | grep $(curl http://169.254.169.254/latest/meta-data/instance-type))
instance=$(echo $line | cut -d' ' -f1)
value=$(echo $line | cut -d' ' -f2)
newVal=$(expr $value - 10)
sudo sed -i s/"$line"/"$instance $newVal"/g /etc/eks/eni-max-pods.txt

/etc/eks/bootstrap.sh --b64-cluster-ca '${cluster_auth_base64}' --apiserver-endpoint '${endpoint}' ${bootstrap_extra_args} --kubelet-extra-args "${kubelet_extra_args}" '${cluster_name}' --container-runtime containerd

systemctl daemon-reload
systemctl enable k8-drain-node
