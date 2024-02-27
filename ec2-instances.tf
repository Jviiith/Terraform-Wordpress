# Create private key to access server (define key)
resource "tls_private_key" "key" {
  algorithm = "RSA"
}

# Pull out public key attributes from generated key (generate key)
resource "aws_key_pair" "server_key" {
  key_name   = "server-key"
  public_key = tls_private_key.key.public_key_openssh
}

# Save generated public key on local machine
resource "local_file" "setup_server_key" {
  content  = tls_private_key.key.public_key_pem
  filename = "server-key.pem"
}


# EC2 setup instance to install wordpress
resource "aws_instance" "setup_server" {
  ami                         = "ami-0cf10cdf9fcd62d37"
  instance_type               = "t2.micro"
  key_name                    = "server-key"
  vpc_security_group_ids      = [aws_security_group.Webserver_SG.id, aws_security_group.ALB_SG.id, aws_security_group.SSH_SG.id]
  subnet_id                   = aws_subnet.public_subnet_AZ1.id
  associate_public_ip_address = true
  depends_on                  = [aws_db_instance.RDS_DB, aws_efs_mount_target.efs_mnt_1]
  tags = {
    Name = "Setup-Server"
  }
}



# Launch Bastion Host (SSH Jump Box)
resource "aws_instance" "bastion_host" {
  ami                         = "ami-0cf10cdf9fcd62d37"
  instance_type               = "t2.micro"
  key_name                    = "server-key"
  vpc_security_group_ids      = [aws_security_group.SSH_SG.id]
  subnet_id                   = aws_subnet.public_subnet_AZ1.id
  associate_public_ip_address = true
  tags = {
    Name = "Bastion-Host"
  }

  # connection {
  #   type        = "ssh"
  #   user        = "ec2-user"
  #   private_key = tls_private_key.key.private_key_pem
  #   host        = aws_instance.bastion_host.public_ip
  # }

  # provisioner "remote-exec" {
  #   inline = [
  #     // Automatically SSH into webserver
  #     "sudo ssh ec2-user@${aws_instance.webserver_AZ1.public_ip}",
  #   ]
  # }
}
