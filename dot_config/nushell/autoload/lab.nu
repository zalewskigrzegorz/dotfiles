# Lab (minis, Debian) — remote management helpers.
#
# All commands here run on the local Mac, ssh into the lab themselves, and
# stream remote stdout back. No need to manually `ssh lab` first.
#
# Full architecture + service inventory lives in:
#   ~/Code/personal/bazgroly/home-lab/analyze/ONBOARDING.md
# Quick recap from there: "The Mac is dev-only — Docker runs on the lab,
# deploy is `push → ssh lab → ./deploy.sh`. deploy.sh handles permissions,
# builds, pulls, force-recreates. update.sh for routine pulls."

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

# `lab-deploy` — run the homelab deploy script on the lab.
#
# The homelab repo lives only at `lab:/opt/homelab/` (no Mac checkout, per
# memory `reference_homelab_repo.md`). `deploy.sh` rebuilds + restarts Docker
# stacks. Use after committing changes there (via `ssh lab` + edit), or after
# pulling new compose/service definitions inside that repo.
def lab-deploy [] {
    print "🚀  Running homelab deploy on lab..."
    ^ssh -t lab 'cd /opt/homelab && ./deploy.sh'
    print "✓  homelab deploy done"
}

# `lab-update` — same as deploy.sh's sibling `update.sh` (pulls images + restarts
# without rebuilding). Faster than deploy when only image tags changed.
def lab-update [] {
    print "⬆️   Running homelab update on lab..."
    ^ssh -t lab 'cd /opt/homelab && ./update.sh'
    print "✓  homelab update done"
}
