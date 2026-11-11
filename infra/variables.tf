variable "domain" {
  description = "Apex domain served by CloudFront"
  type        = string
  default     = "samuelojo.tech"
}

variable "alert_email" {
  description = "Email that receives the primary-site health alarm (leave empty to skip)"
  type        = string
  default     = ""
}
