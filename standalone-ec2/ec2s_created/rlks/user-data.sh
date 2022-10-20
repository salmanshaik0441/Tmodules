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

# adding entries to /etc/fstab
echo -e "/dev/app_vg/docker_lv\t\t/var/lib/docker\t\txfs\t\tdefaults\t\t1 2" >> /etc/fstab
systemctl daemon-reload
################## DONE WITH VOLUME CREATION ##################

## Install SSM Agent needed to for automation that removes ec2 from salt and kubernetes
#yum install -y https://s3.${aws_region}.amazonaws.com/amazon-ssm-${aws_region}/latest/linux_amd64/amazon-ssm-agent.rpm
#yum install -y python3


yum groupinstall -y 'Development Tools'
yum install -y docker jq
systemctl daemon-reload

# Startup
cat << EOF > /home/ec2-user/server.lic
SERVER ZABLVCLC03 0242ac110002 27000
VENDOR ibmratl port=27002
VENDOR telelogic
VENDOR rational
INCREMENT IBMUCD_Server ibmratl 6.01 permanent 1 ISSUED=18-Mar-2022 \
	NOTICE="Sales Order Number:0055679947" SIGN="00EF E202 8F4E \
	DE4C 4BD8 B573 852A CD00 AC80 AF85 7350 807A F351 E206 ED7B"
INCREMENT IBMUCD_Agent ibmratl 6.01 permanent 40 ISSUED=18-Mar-2022 \
	NOTICE="Sales Order Number:0055679947" SIGN="0096 3A6A 0E50 \
	6BEB 2192 C678 4E15 5600 C9C9 A7C7 6B53 9FF7 BC27 AD72 C1A8"
EOF
chmod +r /home/ec2-user/server.lic

#==
cat << EOF > /home/ec2-user/rht7-pre-startup.sh
#!/bin/sh
set -e
set -o xtrace
hostip=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
STS_ROLE=`echo '$(aws sts assume-role --endpoint-url https://sts.af-south-1.amazonaws.com --role-arn "arn:aws:iam::019523953090:role/UCDLicenseServer_dns_role" --role-session-name AWSCLI-Session )'`
export AWS_ACCESS_KEY_ID=`echo '$(echo $STS_ROLE | jq .Credentials.AccessKeyId -r)'`
export AWS_SECRET_ACCESS_KEY=`echo '$(echo $STS_ROLE | jq .Credentials.SecretAccessKey -r)'`
export AWS_SESSION_TOKEN=`echo '$(echo $STS_ROLE | jq .Credentials.SessionToken -r)'`
export AWS_DEFAULT_REGION=$(curl http://169.254.169.254/latest/meta-data/placement/region)
echo -n '{
  "Comment": "Private record for Urbancode License Server ",
  "Changes": [{
     "Action": "UPSERT",
     "ResourceRecordSet": {
     "Name": "urbancode-license.orbit.prod.vodacom.co.za",
     "Type": "A",
     "TTL": 300,
     "ResourceRecords": [{ "Value": "$hostip"}]
}}]
}' | tee /home/ec2-user/iprecord.json

if [ `echo '$(ping -c 1 -w 1 -4 urbancode-license.orbit.prod.vodacom.co.za |grep $hostip|wc -l)'` -eq 0 ]; then
  for zoneID in `echo '$(aws route53 list-hosted-zones | jq -r ".HostedZones[]|select(.Name==\"orbit.prod.vodacom.co.za.\")|.Id" |sed -r "s#/hostedzone/##g" )'`
    do
      if [ `echo '$(aws route53 get-hosted-zone --id $zoneID | jq "select(.HostedZone.Config.PrivateZone == true)"|wc -l)'` -gt 0 ]; then
        `echo 'aws route53 change-resource-record-sets --hosted-zone-id $zoneID --change-batch file:///home/ec2-user/iprecord.json'`
      fi
    done
fi
systemctl start docker
docker pull artifactory.orbit.prod.vodacom.co.za/vod-docker-ms/ibm-rlks:1.0.0
docker run --name rlks --rm -v /home/ec2-user/server.lic:/RLKS/RationalRLKS/config/server.lic -p 27000:27000 -p 27002:27002 \
--privileged --hostname ZABLVCLC03 -d artifactory.orbit.prod.vodacom.co.za/vod-docker-ms/ibm-rlks:1.0.0
EOF
chmod +x /home/ec2-user/rht7-pre-startup.sh

#==
cat << EOF > /etc/systemd/system/rlks.service
[Unit]
Description=Start the RLKS license server

[Service]
Type=simple
ExecStart=/bin/bash /home/ec2-user/rht7-pre-startup.sh

[Install]
WantedBy=multi-user.target
EOF


systemctl enable docker
systemctl enable rlks
systemctl daemon-reload
systemctl start rlks

