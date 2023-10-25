resource "aws_instance" "bastion" {
  # ubuntu 22.04 LTS
  ami                         = "ami-04cebc8d6c4f297a3"
  instance_type               = "t2.micro"
  availability_zone           = var.az[0]
  key_name                    = "gonz-eks"
  subnet_id                   = aws_subnet.public[0].id
  associate_public_ip_address = true

  tags = {
    Name = "${var.nick}-bastion"
  }

}
