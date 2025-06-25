# Project Setup - Work project management
# Provides shortcuts for starting, stopping, and installing work projects

# Start the work project
def up [] {
    let old_dir = $env.PWD
    cd $env.WORK_PROJECT_DIR
    pnpm start
    cd $old_dir
}

# Stop the work project
def down [] {
    let old_dir = $env.PWD
    cd $env.WORK_PROJECT_DIR
    pnpm stop
    cd $old_dir
}

# Install dependencies for the work project
def install [] {
    let old_dir = $env.PWD
    cd $env.WORK_PROJECT_DIR
    ./install.sh
    cd $old_dir
} 