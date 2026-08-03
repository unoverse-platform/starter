# What this ground costs to run, priced where its sizes are chosen.
#
# ONE HOME FOR THE NUMBERS, the same arrangement as the DigitalOcean ground: the ground
# owns its sizes, so the ground prices them. `unoverse deploy` reads this map out of the
# plan JSON instead of carrying a second table, which is how the CLI came to quote
# t3-series rates for a ground that had moved to t4g and silently price its database at
# nothing at all.
#
# NOT A COST ORACLE. On-demand rates in a mid-priced region, so a developer sees an order
# of magnitude instead of a surprise. Rates move and vary by region; the bill is AWS's.

locals {
  # Monthly USD, keyed by the instance type it prices. A type absent here is simply not
  # priced (the summary shows the resource with no figure) rather than guessed at.
  prices = {
    # EC2
    "t3.xlarge"   = 120 # small: the POC box
    "m6i.2xlarge" = 280 # medium
    "r6i.2xlarge" = 365 # large
    # RDS Postgres
    "db.t4g.small"  = 25
    "db.t4g.medium" = 50
    "db.m6g.large"  = 125
    # ElastiCache Redis
    "cache.t4g.micro"  = 12
    "cache.t4g.small"  = 25
    "cache.t4g.medium" = 50
    # Fixed-price resources, keyed by what they are rather than a size
    "alb" = 18
    # Not a size: EBS, the public IPv4 charge, Route 53 and egress at POC traffic. Small
    # and unavoidable, so the estimate carries it rather than reading low by a sixth.
    "baseline" = 15
  }

  # The steady-state bill for THIS universe, as configured.
  monthly_estimate = sum([
    lookup(local.prices, local.s.instance, 0),
    lookup(local.prices, local.s.pg, 0),
    lookup(local.prices, local.s.redis, 0),
    local.prices["alb"],
    local.prices["baseline"],
  ])
}

output "prices" {
  description = "Monthly USD by instance type. The CLI's plan summary reads this, so the deploy screen and the docs cannot drift apart."
  value       = local.prices
}

output "monthly_estimate" {
  description = "Roughly what this universe costs a month at on-demand prices, for the size configured."
  value       = local.monthly_estimate
}
