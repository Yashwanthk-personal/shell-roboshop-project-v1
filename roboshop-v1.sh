#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="devops92s.store"
hosted_zone_id="Z07125641OXP8SCNSKD6L"


for instance in $@
do
aws ec2 run-instances \
            --image-id $ami_id \
            --instance-type $instance_type \
            --security-groups "my-ip" "roboshop-$instance" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]"
done