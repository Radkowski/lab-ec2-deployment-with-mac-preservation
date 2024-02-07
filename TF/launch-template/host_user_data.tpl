#!/bin/bash
# sudo yum -y update
sudo yum -y install wget ruby 
sudo mkdir -p /etc/codedeploy-agent/conf/
sudo echo -e ":log_aws_wire: false\n:log_dir: '/var/log/aws/codedeploy-agent/'\n:pid_dir: '/opt/codedeploy-agent/state/.pid/'\n:program_name: codedeploy-agent\n:root_dir: '/opt/codedeploy-agent/deployment-root'\n:verbose: false\n:wait_between_runs: 1\n:proxy_uri:\n:enable_auth_policy: ${enable_policy}" > /etc/codedeploy-agent/conf/codedeployagent.yml
cd /home/ec2-user
wget https://aws-codedeploy-${region}.s3.${region}.amazonaws.com/latest/install
chmod +x ./install
sudo ./install auto


