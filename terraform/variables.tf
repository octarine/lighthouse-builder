# (c) Crown Owned Copyright, 2016. Dstl.
variable "office_ip" {}
variable "client_ip" {}
variable "gareth_ip" {}
variable "jenkins_ip" {}
variable "copper_jenkins_ip" {}
variable "copper_lighthouse_ip" {}
variable "robs_ip" {}
variable "github_ip" {}
variable "amazon_internal_ip_range" {}
variable "access_key" {}
variable "secret_key" {}
variable "region" {
    default = "eu-west-1"
}
variable "availability_zone" {
    default = "eu-west-1a"
}
variable "rhel_box" {
    default = "ami-8b8c57f8"
}
variable "centos_box" {
    default = "ami-33734044"
}
