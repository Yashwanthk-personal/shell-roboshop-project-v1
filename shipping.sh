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

if [ $user_id -ne 0 ]; then   
    echo "Please run this script with sudo access....."
    exit 1
fi

mkdir -p $logs_folder

timestamp() {
    date "+%F %T"
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

dnf module enable maven:3.9 -y &>> $logs_file
dnf install maven java-25-openjdk-devel -y &>> $logs_file
validate $? "Installing Java and Maven"

alternatives --set java "/usr/lib/jvm/java-25-openjdk/bin/java"
validate $? "Setting Java 25 as default Java version"

echo "export JAVA_HOME=$(dirname $(dirname $(readlink -f /usr/bin/java)))" > /etc/profile.d/java.sh
source /etc/profile.d/java.sh
echo $JAVA_HOME
validate $? "Setting JAVA_HOME for maven"

id roboshop &>> $logs_file
if [ $? -ne 0 ]; then
    useradd --system --home /app --shell /sbin/nologin --comment "roboshop system user" roboshop &>> $logs_file
    validate $? "Creating system user"
else
    echo -e "$(timestamp) [INFO] System user roboshop already exist...${Y}SKIPPING${N}"
fi

rm -rf /app
validate $? "Removing old app directory"

mkdir -p /app
validate $? "Creating app directory"

curl -L -o /tmp/shipping.zip https://raw.githubusercontent.com/daws-92s/roboshop-documentation/refs/heads/main/artifacts/shipping-v4.zip &>> $logs_file
validate $? "Downloading shipping service source code"

cd /app
unzip /tmp/shipping.zip &>> $logs_file
validate $? "Unzipping shipping service source code"

mvn clean package &>> $logs_file
validate $? "Building dependencies"

mv target/shipping.jar shipping.jar
validate $? "Moving shipping.jar file from /app/target to /app folder"

sed -i "s/DOMAIN_NAME/${domain_name}/g" "${service_file_dir}/shipping.service"
cp "${service_file_dir}/shipping.service" /etc/systemd/system/shipping.service

dnf install mysql -y &>> $logs_file
validate $? "Installing MySQL client"

count=$(mysql -h "mysql.${domain_name}" -u root -pRoboShop@1 -N -B -e "SELECT COUNT(*) FROM cities.cities;" 2>> $logs_file )
if [ -z "$count" ] || [ "$count" -eq 0 ]; then
    mysql -h "mysql.$domain_name" -uroot -pRoboShop@1 < /app/db/master-data.sql
    validate $? "Loading shipping data"
else
    echo -e "$(timestamp) [INFO] Master data already loaded... ${Y}SKIPPING${N}"
fi

mysql -h "mysql.$domain_name" -uroot -pRoboShop@1 < /app/db/app-user.sql
validate $? "Creating APP user"

systemctl daemon-reload &>> $logs_file
systemctl enable --now shipping &>> $logs_file
validate $? "Enabling and Starting shipping service"

systemctl restart shipping &>> $logs_file
validate $? "Restarting shipping service"

systemctl status shipping | tee -a $logs_file
validate $? "Checking Shipping Service Status"

journalctl -u shipping -f | tee -a $logs_file
validate $? "Checking Shipping Service Logs"

curl http://localhost:8080/actuator/health | tee -a $logs_file
validate $? "Shipping backend service health check"

curl http://localhost:8080/count | tee -a $logs_file
curl http://localhost:8080/codes | tee -a $logs_file
validate $? "Data Seeding into MySql DB...."

echo "$(timestamp) [INFO] Script completed in $SECONDS seconds"
echo "$(timestamp) [INFO] ==== Script completed Execution =====" | tee -a $logs_file