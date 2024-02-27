# RDS database
resource "aws_db_instance" "RDS_DB" {
  allocated_storage      = 20
  storage_type           = "gp2"
  db_name                = "mysqldb"
  identifier             = "rds-db-instance"
  multi_az               = false
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t2.micro"
  username               = "admin"
  password               = "password"
  parameter_group_name   = "default.mysql5.7"
  availability_zone      = "us-east-1b"
  vpc_security_group_ids = [aws_security_group.Database_SG.id]
  db_subnet_group_name   = aws_db_subnet_group.DB_subnet_group.name
  skip_final_snapshot    = true
}
