terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
provider "aws" {
  #   Configuration options
  #     profile = "vscode"
  #     region = "us-east-1"
}
resource "aws_instance" "Jenkins" {
  ami                    = "ami-0f9fc25dd2506cf6d"
  instance_type          = "t3a.small"
  key_name               = "modulcar"
  vpc_security_group_ids = [aws_security_group.Jenkins-eksctl.id]
  tags = {
    Name = "Dev-Jenkins-eksctl-Server"
  }
  root_block_device {
    volume_size = 16
  }
  user_data = <<-EOF
          #! /bin/bash
          yum update -y
          # set server hostname as jenkins-server
          hostnamectl set-hostname jenkins-server
          # install git
          yum install git -y
          # install java 11
          yum install java-11-amazon-corretto -y
          # install jenkins
          wget -O /etc/yum.repos.d/jenkins.repo https://pkg.jenkins.io/redhat-stable/jenkins.repo
          rpm --import https://pkg.jenkins.io/redhat-stable/jenkins.io-2023.key
          yum upgrade -y
          amazon-linux-extras install epel
          yum install jenkins -y
          systemctl daemon-reload
          systemctl start jenkins
          systemctl enable jenkins
          # install docker
          amazon-linux-extras install docker -y
          systemctl start docker
          systemctl enable docker
          usermod -a -G docker ec2-user
          usermod -a -G docker jenkins
          # configure docker as cloud agent for jenkins
          cp /lib/systemd/system/docker.service /lib/systemd/system/docker.service.bak
          sed -i 's/^ExecStart=.*/ExecStart=\/usr\/bin\/dockerd -H tcp:\/\/127.0.0.1:2375 -H unix:\/\/\/var\/run\/docker.sock/g' /lib/systemd/system/docker.service
          systemctl daemon-reload
          systemctl restart docker
          systemctl restart jenkins
          # install docker compose
          curl -L "https://github.com/docker/compose/releases/download/1.26.2/docker-compose-$(uname -s)-$(uname -m)" \
          -o /usr/local/bin/docker-compose
          chmod +x /usr/local/bin/docker-compose
          # uninstall aws cli version 1
          rm -rf /bin/aws
          # install aws cli version 2
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip awscliv2.zip
          ./aws/install
          # install python 3
          yum install python3 -y
          # install ansible
          pip3 install ansible
          # install boto3
          pip3 install boto3
          # install kubectl
          curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
          chmod +x ./kubectl
          mv kubectl /usr/local/bin
          export PATH=/usr/local/bin:$PATH
          source ~/.bash_profile
          # install eksctl
          curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
          mv /tmp/eksctl /usr/local/bin
          # install jq a JSON file parser to help in extracting public key
          yum install jq -y
          EOF
}
resource "aws_security_group" "Jenkins-eksctl" {
  name = "Jenkins-eksctl"
  tags = {
    Name = "Jenkins-eksctl-SG"
  }
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 8080
    protocol    = "tcp"
    to_port     = 8080
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port   = 22
    protocol    = "tcp"
    to_port     = 22
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}
output "Dev-Jenkins-eksctl-Server" {
  value = "http://${aws_instance.Jenkins.public_dns}:8080"
}
