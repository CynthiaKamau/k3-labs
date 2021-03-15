output "control_plane_ip" {
  value = aws_instance.control_plane.public_ip
}

output "control_plane" {
  value = format("%s (%s)", aws_instance.control_plane.public_dns, aws_instance.control_plane.public_ip)
}

output "dns_record" {
  value = aws_route53_record.control_plane
}
