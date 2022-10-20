#!/bin/bash -x
set -e
set -o xtrace
exec > >(tee /home/ec2-user/user-data.log|logger -t /home/ec2-user/user-data -s 2>/dev/null) 2>&1

# NSERVER=$(cat /etc/resolv.conf | grep nameserver | tail -n1 | cut -d' ' -f2)
# RESHOST=$(nslookup bifrost.orbit.vodacom.aws.corp $NSERVER | grep Address | tail -n1 | awk '{print $2}' | cut -d'#' -f1)
# echo $RESHOST bifrost.orbit.vodacom.aws.corp >> /etc/hosts
# RESHOST=$(nslookup artifactory.orbit.vodacom.aws.corp $NSERVER | grep Address | tail -n1 | cut -d' ' -f2)
# echo $RESHOST artifactory.orbit.vodacom.aws.corp >> /etc/hosts

# Adding proxy to yum.conf
echo proxy=http://bifrost.orbit.vodacom.aws.corp:3128 >> /etc/yum.conf

hostip=`curl http://169.254.169.254/latest/meta-data/local-ipv4`
hostname=${env_type}-$hostip
hostnamectl set-hostname $hostname

# Next section creates volumes needed for docker and kubelet
#Creating docker and kubelet volumes
blkname=$(lsblk | grep "${data_mount_size}G" | awk '{print $1}')
pvcreate /dev/$blkname
vgcreate app_vg /dev/$blkname

# Creating logical volumes for docker
lvcreate -y -L "${docker_lv_size}G" -n docker_lv app_vg
mkfs -t xfs -f -n ftype=1 /dev/app_vg/docker_lv
mkdir -p /var/lib/docker
mount -t xfs /dev/app_vg/docker_lv /var/lib/docker

# Creating logical volume for kubelet
lvcreate -y -L "${kubelet_lv_size}G" -n kubelet_lv app_vg
mkfs -t xfs -f -n ftype=1 /dev/app_vg/kubelet_lv
mkdir -p /var/lib/kubelet
mount -t xfs /dev/app_vg/kubelet_lv /var/lib/kubelet

# adding entries to /etc/fstab
echo -e "/dev/app_vg/docker_lv\t\t/var/lib/docker\t\txfs\t\tdefaults\t\t1 2" >> /etc/fstab
echo -e "/dev/app_vg/kubelet_lv\t\t/var/lib/kubelet\t\txfs\t\tdefaults\t\t1 2" >> /etc/fstab
systemctl daemon-reload
################## DONE WITH VOLUME CREATION ##################

## Install SSM Agent needed to for automation that removes ec2 from salt and kubernetes
#yum install -y https://s3.${aws_region}.amazonaws.com/amazon-ssm-${aws_region}/latest/linux_amd64/amazon-ssm-agent.rpm
yum install -y python3

# Installing and configuring salt-minion
wget -O install_salt.sh "http://artifactory.orbit.vodacom.aws.corp/ui/api/v1/download?repoKey=local-dists&path=salt%2Fbootstrap"

yum groupinstall -y 'Development Tools'

sudo sh install_salt.sh -x python3 -P -b -r -A qonl101zatcrh.vodacom.corp -i ${salt_minion_prefix}$hostname git v3001.6
salt-call --local grains.setval roles "${env_type}_kubernetes-pool"
salt-call --local grains.setval env_type ${env_type}

systemctl enable salt-minion
systemctl daemon-reload
systemctl restart salt-minion

# Installing k8 and joining relevant cluster
salt-call state.highstate || true
salt-call state.sls kubectl-conf/ec2-kubectl-setup || true
salt-call state.sls apm/appdynamics/appd-agent || true

sed -i '/overlay2/i"exec-opts": ["native.cgroupdriver=systemd"],' /etc/docker/daemon.json
systemctl daemon-reload

#==
# PRE SHUTDOWN
cat << EOF > /etc/systemd/system/host-cleanup.service
[Unit]
Description=Remove self from K8 and salt
DefaultDependencies=no
Before=shutdown.target reboot.target halt.target poweroff.target exit.target

[Service]
Type=oneshot
ExecStart=/bin/bash -x /home/ec2-user/host-shutdown
TimeoutStartSec=0

[Install]
WantedBy=shutdown.target reboot.target halt.target poweroff.target exit.target

EOF

cat << EOF > /home/ec2-user/host-shutdown
#!/bin/bash
set -x

host=`hostname`
sync
umount -a -t nfs
/usr/bin/salt-call saltutil.revoke_auth
umount /dev/xvdb
INSID=\$(curl http://169.254.169.254/latest/meta-data/instance-id)
VOLID=\$(aws ec2 describe-volumes --region=af-south-1 --filters "Name=tag:Name,Values=prometheus-standalone-volume-${env_type}*" --query 'Volumes[0].VolumeId' | tr -d '"')
aws ec2 detach-volume --region=af-south-1 --device=/dev/xvdb --volume-id=\$VOLID --instance-id=\$INSID
echo "Completed host-shutdown script"

EOF
chmod +x /home/ec2-user/host-shutdown

#==
#POST K8
cat << EOF > /etc/systemd/system/k8-cleanup.service
[Unit]
Description=Attempt safe pod shutdown
Requires=docker.service kubelet.service
After=docker.service kubelet.service 

[Service]
Type=simple
ExecStart=/bin/true
ExecStop=/bin/bash -x /home/ec2-user/pre-shutdown
RemainAfterExit=true


EOF

cat << EOF > /home/ec2-user/pre-shutdown
#!/bin/bash
set -x

host=`hostname`
/usr/bin/kubectl --kubeconfig=/root/.kube/config drain \$host --grace-period=1 --delete-local-data --force --ignore-daemonsets
sleep 10s
/usr/bin/kubectl --kubeconfig=/root/.kube/config delete node \$host
sleep 5s

EOF
chmod +x /home/ec2-user/pre-shutdown

cat << EOF > /home/ec2-user/rht7-pre-startup.sh
#!/bin/sh

if [ -f /usr/bin/salt-call ]; then
    salt-call saltutil.regen_keys
    systemctl restart kubelet
fi

EOF
chmod +x /home/ec2-user/rht7-pre-startup.sh

#==
cat << EOF > /etc/systemd/system/salt-start-register.service
[Unit]
Description=Registers minion with salt master at system start
After=network.target

[Service]
Type=simple
ExecStart=/bin/bash /home/ec2-user/rht7-pre-startup.sh

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /etc/systemd/system/kubeletconfig.service
[Unit]
Description=Do node specific things
After=kubelet.service

[Service]
Type=oneshot
ExecStart=/bin/bash /home/ec2-user/kubeletconfig.sh
RemainAfterExit=true

[Install]
WantedBy=multi-user.target
EOF

cat << EOF > /home/ec2-user/kubeletconfig.sh
#!/bin/sh
host=`hostname`
kubectl --kubeconfig=/root/.kube/config get node \$host
ex=\$?
while [ "\$ex" != "0" ];
do
  kubectl --kubeconfig=/root/.kube/config get node \$host
  ex=\$?
done
sleep 5
/usr/bin/kubectl --kubeconfig=/root/.kube/config label nodes `hostname` hasNFS=false

EOF
chmod +x /home/ec2-user/kubeletconfig.sh

systemctl daemon-reload
systemctl enable salt-start-register.service
systemctl start salt-start-register.service
systemctl enable host-cleanup.service
systemctl enable docker
systemctl restart docker
systemctl enable kubelet
systemctl restart kubelet
systemctl enable kubeletconfig.service
systemctl start kubeletconfig.service
systemctl enable k8-cleanup.service
systemctl start k8-cleanup.service

sleep 10
/usr/bin/kubectl --kubeconfig=/root/.kube/config label nodes `hostname` hasNFS=false
