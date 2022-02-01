output "ghost_url" {
  value = local.vars.ghost_url
}

output "ghost_url_no_cache" {
  value = "${local.vars.ghost_url}?cache=false"
}
