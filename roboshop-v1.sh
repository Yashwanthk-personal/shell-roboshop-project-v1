#!/bin/bash

ami_id="ami-0055977a6e828a4f4"
instance_type="t3.micro"
domain_name="devops92s.store"
hosted_zone_id="Z07125641OXP8SCNSKD6L"


for instance in $@
do
        instance_id=$(aws ec2 run-instances \
            --image-id $ami_id \
            --instance-type $instance_type \
            --security-groups "my-ip" "roboshop-$instance" \
            --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=roboshop-$instance}]" \
            --query 'Instances[0].InstanceId' \
            --output text)
        
        echo "$instance instance ID: $instance_id"

        if [ $instance != "frontend" ]; then
            IP=$(aws ec2 describe-instances --instance-ids "$instance_id" \
                            --query 'Reservations[0].Instances[0].PrivateIpAddress' --output text)
            r53_record="${instance}.${domain_name}"
        else
            IP=$(aws ec2 describe-instances --instance-ids "$instance_id" \
                            --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
            r53_record="${domain_name}"
        fi
    
        echo "Record: ${r53_record}"
        
        aws route53 change-resource-record-sets \
            --hosted-zone-id "$hosted_zone_id" \
            --change-batch '{
                "Changes": [
                {
                    "Action": "UPSERT",
                    "ResourceRecordSet": {
                    "Name": "'${r53_record}'",
                    "Type": "A",
                    "TTL": 1,
                    "ResourceRecords": [{"Value": "'$IP'"}]
                    }
                }
            ]
        }'

        echo "Route 53 record ${r53_records} updated to ${IP}"
done