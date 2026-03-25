# TODO find the way to track performance in autoload modules

# Remove dist/build artifacts to fix rspack "Formatting argument out of range" panics
# (stale dist files can trigger the bug). Run from monorepo root.
def clean-build [] {
    print "Removing dist artifacts..."
    let dists = (glob "**/dist" --depth 5 | where { |p| ($p | path type) == "dir" })
    if ($dists | is-empty) {
        print "No dist folders found."
    } else {
        $dists | each { |d|
            rm -rf $d
            print $"  removed ($d)"
        }
    }
    print "Done ✓"
}
