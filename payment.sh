#!/bin/bash

user_id=$(id -u)
logs_folder="/var/log/roboshop"
logs_file="${logs_folder}/${0}.log"
domain_name="devops92s.store"
scripts_dir=$( dirname "$(realpath "$0")" )
service_file_dir="${scripts_dir}/service_files"
repos_dir="${scripts_dir}/repos"
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

if [ user_id -ne 0]; then
    echo "Please run this script with sudo access....."
    exit 1
fi

mkdir -p $logs_folder

timestamp() {
    data "+%F %T"
}

validate(){
    if [ $1 -ne 0 ]; then
        echo -e "$(timestamp) [ERROR] ${2}.... ${R}FAILED${N}" | tee -a $logs_file
        exit 1
    else 
        echo -e "$(timestamp) [INFO] ${2}.... ${G}SUCCESS${N}" | tee -a $logs_file
    fi
}

echo "$(timestamp) [INFO] ========= SCRIPT STARTED EXECUTION ===========" | tee -a $logs_file

dnf install python3.14 python3.14-pip -y &>> $logs_file
validate $? "Installing Python 3.14"

id roboshop &>> $logs_file
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>> $logs_file
    validate $? "Creating roboshop system user"
else
    echo -e "$(timestamp) [INFO] System user roboshop already exist...${Y}SKIPPING${N}"
fi

rm -rf /app
validate $? "Removing old app directory"

mkdir -p /app
validate $? "Creating app directory"

curl -L -o /tmp/payment.zip https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/payment-v4.zip &>> $logs_file
validate $? "Downloading payment service source code"

cd /app
unzip /tmp/payment.zip &>> $logs_file
validate $? "Unzipping payment service source code"

python3.14 -m venv /app/.venv &>> $logs_file
validate $? "Creating virtual environment"

/app/.venv/bin/pip install -r requirements.txt &>> $logs_file
validate $? "Installing dependencies"

sed -i "s/DOMAIN_NAME/${domain_name}/g" "${service_file_dir}/payment.service"
cp "${service_file_dir}/payment.service" /etc/systemd/system/payment.service

systemctl daemon-reload &>> $logs_file
systemctl enable --now payment &>> $logs_file
systemctl restart payment &>> $logs_file
validate $? "Enabling, Starting and Restarting Payment service"

systemctl status payment
validate $? "Checking Payment Service Status"

journalctl -u payment -f
validate $? "Checking Payment Service Logs"

curl http://localhost:8080/health
validate $? "Payment backend service health check"

echo "$(timestamp) [INFO] Script completed in ${SECONDS} seconds"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file