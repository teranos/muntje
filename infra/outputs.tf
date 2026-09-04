output "bucket_name" {
  value = module.site.bucket_name
}

output "distribution_id" {
  value = module.site.distribution_id
}

output "urls" {
  value = module.site.urls
}

output "takes" {
  value = { for k, m in module.take : k => { bucket = m.bucket_name, distribution = m.distribution_id } }
}
