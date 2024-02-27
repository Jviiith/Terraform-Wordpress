# Elastic IP
resource "aws_eip" "eip_nat_az1" {
  depends_on = [aws_internet_gateway.igw]
}

resource "aws_eip" "eip_nat_az2" {
  depends_on = [aws_internet_gateway.igw]
}
