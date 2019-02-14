data "aws_availability_zones" "available" {}

locals {
  az_count = "${length(data.aws_availability_zones.available.names)}"
}

resource "aws_vpc" "main" {
  cidr_block                       = "${var.cidr_block}"
  enable_dns_support               = true
  enable_dns_hostnames             = true
  assign_generated_ipv6_cidr_block = true
  tags                             = "${local.default_tags}"
}

resource "aws_subnet" "private" {
  count                           = "${local.az_count}"
  vpc_id                          = "${aws_vpc.main.id}"
  cidr_block                      = "${cidrsubnet(aws_vpc.main.cidr_block, 8, count.index)}"
  ipv6_cidr_block                 = "${cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, count.index)}"
  availability_zone               = "${element(data.aws_availability_zones.available.names, count.index)}"
  assign_ipv6_address_on_creation = true
  tags                            = "${local.default_tags}"
}

resource "aws_subnet" "public" {
  count                           = "${local.az_count}"
  vpc_id                          = "${aws_vpc.main.id}"
  map_public_ip_on_launch         = true
  assign_ipv6_address_on_creation = true

  # The blocks need offsetting by the az count to account for the private subnets
  cidr_block        = "${cidrsubnet(aws_vpc.main.cidr_block, 8, local.az_count + count.index)}"
  ipv6_cidr_block   = "${cidrsubnet(aws_vpc.main.ipv6_cidr_block, 8, local.az_count + count.index)}"
  availability_zone = "${element(data.aws_availability_zones.available.names, count.index)}"
  tags              = "${local.default_tags}"
}

## Public access

resource "aws_internet_gateway" "gw" {
  # open up the VPC to the internet
  vpc_id = "${aws_vpc.main.id}"
  tags   = "${local.default_tags}"
}

resource "aws_route" "internet_access" {
  # Allow ipv4 traffic to the internet
  route_table_id         = "${aws_vpc.main.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.gw.id}"
}

resource "aws_route" "internet_access_v6" {
  # allow ipv6 traffic to the internet
  route_table_id              = "${aws_vpc.main.main_route_table_id}"
  destination_ipv6_cidr_block = "::/0"
  gateway_id                  = "${aws_internet_gateway.gw.id}"
}

resource "aws_eip" "gw" {
  count = "${local.az_count}"
  vpc   = true

  depends_on = [
    "aws_internet_gateway.gw",
  ]
}

## Private routing

resource "aws_nat_gateway" "gw" {
  count         = "${local.az_count}"
  subnet_id     = "${element(aws_subnet.public.*.id, count.index)}"
  allocation_id = "${element(aws_eip.gw.*.id, count.index)}"
}

resource "aws_egress_only_internet_gateway" "gw" {
  vpc_id = "${aws_vpc.main.id}"
}

resource "aws_route_table" "private" {
  count  = "${local.az_count}"
  vpc_id = "${aws_vpc.main.id}"

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = "${element(aws_nat_gateway.gw.*.id, count.index)}"
  }

  route {
    ipv6_cidr_block        = "::/0"
    egress_only_gateway_id = "${aws_egress_only_internet_gateway.gw.id}"
  }

  tags = "${local.default_tags}"
}

resource "aws_route_table_association" "private" {
  count          = "${local.az_count}"
  subnet_id      = "${element(aws_subnet.private.*.id, count.index)}"
  route_table_id = "${element(aws_route_table.private.*.id, count.index)}"
}
