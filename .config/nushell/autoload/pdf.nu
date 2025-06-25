# PDF - Document management utilities

# Move 2 newest PDFs to LAST month's accounting folder
def move-pdfs [] {
    let current_date = (date now)

    # Get current month and year as integers
    let current_month = ($current_date | format date "%m" | into int)
    let current_year = ($current_date | format date "%y" | into int)

    # Calculate last month and year
    let last_month_info = if $current_month == 1 {
        # January -> December of previous year
        {month: 12, year: ($current_year - 1)}
    } else {
        # Normal case - just subtract 1 from month
        {month: ($current_month - 1), year: $current_year}
    }

    # Format with leading zeros - use a simpler approach
    let year = ($last_month_info.year | into string)
    let month_num = if $last_month_info.month < 10 {
        $"0($last_month_info.month)"
    } else {
        ($last_month_info.month | into string)
    }

    # Polish months
    let month_polish = match $month_num {
        "01" => "01.styczeń",
        "02" => "02.luty",
        "03" => "03.marzec",
        "04" => "04.kwiecień",
        "05" => "05.maj",
        "06" => "06.czerwiec",
        "07" => "07.lipiec",
        "08" => "08.sierpień",
        "09" => "09.wrzesień",
        "10" => "10.październik",
        "11" => "11.listopad",
        "12" => "12.grudzień"
    }

    let target_dir = ($env.USER_HOME | path join "Google Drive/My Drive/faktury" $year $month_polish "ipbox/potwierdzenia")

    print $"📁 Target directory: ($target_dir)"

    # Check if target directory exists
    if not ($target_dir | path exists) {
        print "⚠️  Directory doesn't exist - will be created"
    } else {
        print "✅ Directory exists"
    }

    # Show what PDFs we found
    cd ~/Downloads
    let pdfs = (ls *.pdf | sort-by modified --reverse | take 2)

    if ($pdfs | length) == 0 {
        print "❌ No PDF files found in Downloads"
        return
    }

    print "\n📄 Found PDFs to move:"
    $pdfs | each { |file|
        let size = ($file.size | into string)
        let modified = ($file.modified | format date "%Y-%m-%d %H:%M:%S")
        print $"  📋 ($file.name)"
        print $"     Size: ($size), Modified: ($modified)"
    }

    print $"\n🎯 These files will be moved to:"
    print $"   ($target_dir)"

    # Confirmation prompt
    print "\n❓ Do you want to proceed? (y/N)"
    let response = (input)

    if $response != "y" and $response != "Y" {
        print "❌ Operation cancelled"
        return
    }

    # Create directory if needed
    if not ($target_dir | path exists) {
        print "📁 Creating directory..."
        mkdir $target_dir
    }

    # Move them
    print "\n🚀 Moving files..."
    $pdfs | each { |file|
        print $"  ➡️  Moving ($file.name)..."
        mv $file.name $target_dir
    }

    print "\n✅ Done! All files moved successfully."
} 