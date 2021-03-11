output "garo_external_id" {
  value       = random_integer.garo_external_id.result
  description = "The ExternalId to set in the GitHub repo secret 'RUNNER_EXID'"
}
