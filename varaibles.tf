variable "project" {
    type = string
    default = "roboshop"
}
variable  "environment" {
    type = string
    default = "dev"
}
variable "zone_id" {
    type = string
    default = "Z082049010RMR2FN1A4VI"
}
variable "domain_name" {
    type = string
    default = "sowjanya.fun"
}
variable "catalogue_tags" {
    type = map
    default = {}
}
variable "component" {
    type = string
}
variable "app_version" {
    type = string
    default = "v3"
}

variable "rule_priority" {
    
}