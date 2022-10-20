#!/bin/bash -x
set -e

set -o xtrace
exec > >(tee /home/ec2-user/user-data.log|logger -t /home/ec2-user/user-data -s 2>/dev/null) 2>&1

instid=`curl http://169.254.169.254/latest/meta-data/instance-id`
aws ec2 report-instance-status --instances $instid --status impaired --reason-codes unresponsive