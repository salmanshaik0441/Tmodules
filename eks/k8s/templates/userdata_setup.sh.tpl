#!/bin/bash

aws s3 cp "${s3_bucket}userdata_scripts/kubelet-health-check.sh" /home/ec2-user/kubelet-health-check --region ${aws_region}
chmod +x /home/ec2-user/kubelet-health-check

aws s3 cp "${s3_bucket}userdata_scripts/userdata_${node_type}.sh" /home/ec2-user/userdata.sh --region ${aws_region}
chmod +x /home/ec2-user/userdata.sh
bash /home/ec2-user/userdata.sh
