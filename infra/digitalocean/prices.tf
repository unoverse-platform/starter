# What this ground costs to run, priced where its sizes are chosen.
#
# ONE HOME FOR THE NUMBERS. These used to live in the CLI's plan summariser and again in
# the docs, so a size change here left two stale copies behind and the deploy screen
# disagreed with the page describing it. The ground owns its sizes, so the ground prices
# them: `unoverse deploy` reads this map out of the plan JSON, and the docs quote the
# same output rather than a table somebody keeps in step by hand.
#
# NOT A COST ORACLE. DigitalOcean's published monthly rates for exactly the slugs this
# ground uses, so a developer sees an order of magnitude instead of a surprise. Rates
# move; the bill is the provider's.

locals {
  # Monthly USD, keyed by the size slug it prices. A slug absent here is simply not
  # priced (the summary shows the resource with no figure) rather than guessed at.
  prices = {
    # Droplets
    "s-4vcpu-16gb-amd" = 96  # small: the POC box
    "g-8vcpu-32gb"     = 252 # medium
    "m-8vcpu-64gb"     = 386 # large
    # Managed Postgres and Redis
    "db-s-1vcpu-1gb" = 15
    "db-s-1vcpu-2gb" = 30
    "db-s-2vcpu-4gb" = 60
    "db-s-4vcpu-8gb" = 120
    # Fixed-price resources, keyed by what they are rather than a size
    "lb" = 12
  }

  # The steady-state bill for THIS universe, as configured. Adopted or bring-your-own
  # Postgres is not in it: that cluster is somebody else's line item, and pricing it here
  # would invent a charge this stack does not create.
  monthly_estimate = sum([
    lookup(local.prices, local.s.droplet, 0),
    local.provision_pg ? lookup(local.prices, local.s.pg, 0) : 0,
    lookup(local.prices, local.s.redis, 0),
    local.prices["lb"],
    # Canvas's own load balancer, so its URL needs no port. Only with a domain: without
    # one it shares the main LB's IP on a second port and costs nothing extra.
    local.has_domain && var.canvas_public ? local.prices["lb"] : 0,
  ])
}

output "prices" {
  description = "Monthly USD by size slug. The CLI's plan summary reads this, so the deploy screen and the docs cannot drift apart."
  value       = local.prices
}

output "monthly_estimate" {
  description = "Roughly what this universe costs a month at list prices, for the size and Postgres mode configured."
  value       = local.monthly_estimate
}
