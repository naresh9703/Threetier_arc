
#!/bin/bash
START_TIME=$(date +%s)
USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"
LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD #absolute path

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE




# check the user has root priveleges or not
if [ $USERID -ne 0 ]
then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1 #give other than 0 upto 127
else
    echo "You are running with root access" | tee -a $LOG_FILE
fi

# validate functions takes input as exit status, what command they tried to install
VALIDATE(){
    if [ $1 -eq 0 ]
    then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}



dnf module disable nodejs -y &>>$LOG_FILE 
VALIDATE $? "Disabling default nodejs"

dnf module enable nodejs:20 -y &>>$LOG_FILE 
VALIDATE $? "Enabling nodejs:20"

dnf install nodejs -y &>>$LOG_FILE 
VALIDATE $? "Installing nodejs:20"


id expense
if [ $? -ne 0 ]
then
    useradd --system --home /app --shell /sbin/nologin --comment "expense user" expense &>>$LOG_FILE
    VALIDATE $? "Creating expense user"
else
    echo -e "System user expense already created ... $Y SKIPPING $N"
fi

mkdir -p /app &>>$LOG_FILE
VALIDATE $? "Creating app directory"

curl -o /tmp/backend.zip https://expense-builds.s3.us-east-1.amazonaws.com/expense-backend-v2.zip &>>$LOG_FILE
VALIDATE $? "Downloading Catalogue"

rm -rf /app/*
cd /app 
unzip /tmp/backend.zip &>>$LOG_FILE
VALIDATE $? "unzipping backend"

npm install &>>$LOG_FILE
VALIDATE $? "Installing Dependencies"

#we can give absolute path in that where ever the script it will execute

cp $SCRIPT_DIR/backend.service /etc/systemd/system/backend.service 
VALIDATE $? "Copying backend service"


dnf install mysql -y &>>$LOG_FILE
VALIDATE $? "Installing mysql"

echo "Please enter root password to setup"
read -s MYSQL_ROOT_PASSWORD
#mysql -h mysql.nareshveeranala.shop -uroot -pExpenseApp@1 < /app/schema/backend.sql &>>$LOG_FILE
mysql -h mysql.nareshveeranala.shop -uroot -p$MYSQL_ROOT_PASSWORD < /app/schema/backend.sql &>>$LOG_FILE

VALIDATE $? "Setting up the transactions schema and tables"


systemctl daemon-reload &>>$LOG_FILE
systemctl start backend &>>$LOG_FILE
systemctl enable backend &>>$LOG_FILE
VALIDATE $? "bakend"

systemctl restart backend &>>$LOG_FILE
VALIDATE $? "restarting backend"

END_TIME=$(date +%s)
TOTAL_TIME=$(( $END_TIME - $START_TIME ))

echo -e "Script exection completed successfully, $Y time taken: $TOTAL_TIME seconds $N" | tee -a $LOG_FILE