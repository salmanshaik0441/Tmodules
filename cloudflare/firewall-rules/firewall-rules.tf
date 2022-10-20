terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 2.0"
    }
  }
}

resource "cloudflare_filter" "firewall_filter"{
  zone_id = var.zone_id
  description = var.description
  expression = var.expression
}

resource "cloudflare_firewall_rule" "firewall_rule_without_product" {
  count = var.products == "none" ? 1 : 0
  zone_id = var.zone_id
  description = var.description
  filter_id = cloudflare_filter.firewall_filter.id
  action = var.action
  paused = var.paused
}

resource "cloudflare_firewall_rule" "firewall_rule_with_product" {
  count = var.products != "none" ? 1 : 0
  zone_id = var.zone_id
  description = var.description
  filter_id = cloudflare_filter.firewall_filter.id
  action = var.action
  products = [var.products]
  paused = var.paused
}
