#################################################################################################
#!/bin/bash
# Author: Aloysius Pious
# Version: 1.0
# Date: 2024-08-22
# Description: This script to find and replace string in directory name, filename, string inside the file
#################################################################################################
#!/usr/bin/perl
use strict;
use warnings;
use File::Find;
use File::Copy;
use File::Basename;
# Check for the correct number of command-line arguments
if (@ARGV != 3) {
    die "Usage: $0 <directory_to_search> <string_to_find> <string_to_replace>\n";
}
my ($directory_to_search, $string_to_find, $string_to_replace) = @ARGV;
# Traverse the specified directory and its subdirectories
find(\&process_files, $directory_to_search);
sub process_files {
    my $file = $File::Find::name;
    # Rename directory or file if it contains the string_to_find
    if ($_ =~ /$string_to_find/) {
        my $new_name = $_;
        $new_name =~ s/$string_to_find/$string_to_replace/g;
        rename($_, $new_name) or warn "Failed to rename $_: $!\n";
    }
    # Skip directories since we don't want to open them as files
    return if -d $file;
    # Open the file to read its contents
    open my $in, '<', $file or warn "Could not open '$file': $!\n" and return;
    my @lines = <$in>;
    close $in;
    # Replace strings inside the file
    my $changed = 0;
    for (@lines) {
        if (s/$string_to_find/$string_to_replace/g) {
            $changed = 1;
        }
    }
    # If changes were made, write back to the file
    if ($changed) {
        open my $out, '>', $file or warn "Could not write to '$file': $!\n" and return;
        print $out @lines;
        print $file,"\n";
        close $out;
    }
}