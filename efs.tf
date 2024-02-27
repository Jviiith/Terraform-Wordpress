# Create EFS file system
resource "aws_efs_file_system" "EFS" {
  creation_token   = "efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  encrypted        = false

  tags = {
    Name = "EFS"
  }
}

# Establish EFS mount targets/ security groups in AZ1 & AZ2
resource "aws_efs_mount_target" "efs_mnt_1" {
  file_system_id  = aws_efs_file_system.EFS.id
  subnet_id       = aws_subnet.private_data_subnet_AZ1.id
  security_groups = [aws_security_group.EFS_SG.id]
  depends_on      = [aws_efs_file_system.EFS]
}

resource "aws_efs_mount_target" "efs_mnt-2" {
  file_system_id  = aws_efs_file_system.EFS.id
  subnet_id       = aws_subnet.private_data_subnet_AZ2.id
  security_groups = [aws_security_group.EFS_SG.id]
  depends_on      = [aws_efs_file_system.EFS]
}

# Mount to EC2 server
resource "null_resource" "server_mnt" {
  depends_on = [aws_efs_mount_target.efs_mnt_1, aws_instance.setup_server, aws_db_instance.RDS_DB]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = tls_private_key.key.private_key_pem
    host        = aws_instance.setup_server.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      // Create the html directory and mount the EFS to it
      "sudo yum update -y",
      "sudo mkdir -p /var/www/html",
      "sudo mount -t nfs4 ${aws_efs_mount_target.efs_mnt_1.ip_address}:/ /var/www/html",

      // Install Apache
      "sudo yum install -y httpd httpd-tools mod_ssl",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd",

      // Install PHP 7.4
      "sudo amazon-linux-extras enable php7.4",
      "sudo yum clean metadata",
      "sudo yum install php php-common php-pear -y",
      "sudo yum install php-{cgi,curl,mbstring,gd,mysqlnd,gettext,json,xml,fpm,intl,zip} -y",

      // Install MySQL 5.7
      "sudo rpm -Uvh https://dev.mysql.com/get/mysql57-community-release-el7-11.noarch.rpm",
      "sudo rpm --import https://repo.mysql.com/RPM-GPG-KEY-mysql-2022",
      "sudo yum install mysql-community-server -y",
      "sudo systemctl enable mysqld",
      "sudo systemctl start mysqld",

      // Set Permissions
      "sudo usermod -a -G apache ec2-user",
      "sudo chown -R ec2-user:apache /var/www",
      "sudo chmod 2775 /var/www && find /var/www -type d -exec sudo chmod 2775 {} \\;",
      "sudo find /var/www -type f -exec sudo chmod 0664 {} \\;",
      "sudo chown apache:apache -R /var/www/html",

      // Download WordPress files
      "wget https://wordpress.org/latest.tar.gz",
      "tar -xzf latest.tar.gz",
      "sudo cp -r wordpress/* /var/www/html/",

      // Create the wp-config.php file
      "sudo cp /var/www/html/wp-config-sample.php /var/www/html/wp-config.php",

      // Edit the wp-config.php file using sed
      "sudo sed -i 's/database_name_here/${aws_db_instance.RDS_DB.db_name}/' /var/www/html/wp-config.php",
      "sudo sed -i 's/username_here/${aws_db_instance.RDS_DB.username}/' /var/www/html/wp-config.php",
      "sudo sed -i 's/password_here/${aws_db_instance.RDS_DB.password}/' /var/www/html/wp-config.php",
      "sudo sed -i 's/localhost/${aws_db_instance.RDS_DB.endpoint}/' /var/www/html/wp-config.php",

      // Restart the web server
      "sudo systemctl restart httpd",
    ]
  }
}
