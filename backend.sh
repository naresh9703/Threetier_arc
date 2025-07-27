
#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"

VALIDATE(){
    if [ $1 -ne 0 ]
    then
        echo -e "$2 ... $R FAILURE $N"
        exit 1
    else
        echo -e "$2 ... $G SUCCESS $N"
    fi
}

CHECK_ROOT(){
    if [ $USERID -ne 0 ]
    then
        echo "ERROR:: You must have sudo access to execute this script"
        exit 1 #other than 0
    fi
}

mkdir -p $LOGS_FOLDER

echo "Script started executing at: $TIMESTAMP"

CHECK_ROOT

dnf module disable nodejs -y &>>$LOG_FILE
VALIDATE $? "Disabling existing default NodeJS"

dnf module enable nodejs:20 -y &>>$LOG_FILE
VALIDATE $? "Enabling NodeJS 20"

dnf install nodejs -y &>>$LOG_FILE
VALIDATE $? "Installing NodeJS"

id expense &>>$LOG_FILE
if [ $? -ne 0 ]
then
    useradd expense &>>$LOG_FILE
    VALIDATE $? "Adding expense user"
else
    echo -e "expense user already exists ... $Y SKIPPING $N"
fi

mkdir -p /app &>>$LOG_FILE
VALIDATE $? "Creating app directory"

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>$LOG_FILE
VALIDATE $? "Downloading backend"

cd /app
rm -rf /app/*

unzip /tmp/backend.zip &>>$LOG_FILE
VALIDATE $? "unzip backend"

npm install &>>$LOG_FILE
VALIDATE $? "Installing dependencies"

cp /home/ec2-user/shell-project/backend.service /etc/systemd/system/backend.service

# Prepare MySQL Schema

dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "Installing MySQL Client"

mysql -h mysql.jyothi.online -uroot -pExpenseApp@1 < /app/schema/backend.sql &>>$LOG_FILE
VALIDATE $? "Setting up the transactions schema and tables"

systemctl daemon-reload &>>$LOG_FILE
VALIDATE $? "Daemon Reload"

systemctl enable backend &>>$LOG_FILE
VALIDATE $? "Enabling backend"

systemctl restart backend &>>$LOG_FILE
VALIDATE $? "Starting Backend"
