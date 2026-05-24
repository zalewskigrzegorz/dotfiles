# Lab (minis, Debian) — remote management helpers.
#
# All commands here run on the local Mac, ssh into the lab themselves, and
# stream remote stdout back. No need to manually `ssh lab` first.
#
# Full architecture + service inventory lives in:
#   ~/Code/personal/bazgroly/home-lab/analyze/ONBOARDING.md
# Quick recap: "The Mac is dev-only — Docker runs on the lab, flow is
# `push → ssh lab → git pull → ./update.sh`. update.sh pulls images, builds
# local ones, deploys per-service with snapshot + interactive rollback.
# reload.sh just restarts services one-by-one without changing anything."

# `lab-sync` — pull latest dotfiles + apply on the lab.
#
# Runs `~/.local/bin/chezmoi update` on lab, which does `git pull` inside
# `~/.local/share/chezmoi` and then `chezmoi apply`. Uses the absolute path
# because lab's login shell is bash and `chezmoi` is not on the default PATH.
def lab-sync [] {
    print "🔄  Syncing dotfiles on lab..."
    ^ssh lab '~/.local/bin/chezmoi update'
    print "✓  lab dotfiles synced"
}

# `lab-update` — pull images, build local images, deploy per-service.
#
# The homelab repo lives only at `lab:/opt/homelab/` (no Mac checkout, per
# memory `reference_homelab_repo.md`). `update.sh` snapshots image digests +
# compose.yaml before each service, then health-checks after `up -d` and
# prompts interactively before any rollback. Use after committing changes
# (via `ssh lab` + edit), or after pulling new compose/service definitions.
def lab-update [] {
    print "⬆️   Running homelab update on lab..."
    ^ssh -t lab 'cd /opt/homelab && ./update.sh'
    print "✓  homelab update done"
}

# `lab-reload` — restart-only, no image/config changes.
#
# Per-service rolling restart (`down` → `up -d` for each, one at a time).
# Use when Traefik lost track of services or the stack got into a weird
# state but you don't want to pull new images.
def lab-reload [] {
    print "🔁  Reloading homelab services on lab..."
    ^ssh -t lab 'cd /opt/homelab && ./reload.sh'
    print "✓  homelab reload done"
}
