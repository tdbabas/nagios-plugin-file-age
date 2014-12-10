#!/usr/bin/perl -w

################################################################################
# check_file.pl
#
# Plugin to find the latest file matching a given pattern in a given directory
# and send out alerts based on the file's age and size
#
# TDBA 2013-08-01 - First version
# TDBA 2014-10-23 - Additional handling to allow day and month directories to be 
#                   searched in a similar way to year directories
# TDBA 2014-12-10 - Replaced constants with variables and added version number
################################################################################
# GLOBAL DECLARATIONS
################################################################################
use warnings;
use strict;
use Nagios::Plugin;
use File::Basename;
use POSIX qw(strftime);
use List::Util qw[max];

# Set default values and version number
my $VERSION         = "1.0.2 [2014-12-10]";
my $SHORT_NAME      = "FILE_AGE";
my $MAX_YEARS_BACK  = 10;  # Number of years back from present to search for year directories
my $MAX_MONTHS_BACK = 12;  # Number of months back from present to search for month directories
my $MAX_DAYS_BACK   = 366; # Number of days back from present to search for day directories 
my $DEF_WARN_TIME   = 240; # Default warn time in seconds
my $DEF_CRIT_TIME   = 600; # Default crit time in seconds
my $DEF_WARN_SIZE   = 0;   # Default warn size
my $DEF_CRIT_SIZE   = 0;   # Default crit size
################################################################################
# MAIN BODY
################################################################################

# Create the usage message
my $usage_msg = qq(Usage: %s -d <dir> -f <file> [-w <age>] [-c <age>] [-W <size>] [-C <size>]

With no modifiers, <age> is expected in seconds. The following modifiers may be used: s,m,h,d,w
With no modifiers, <size> is expected in bytes. The following modifiers may be used: k, M, G
You can use placeholders in <dir> for the date components of a directory. Depending on the modifiers,
the script will try and find directories within a maximum period of time before giving up. The valid placeholders are: 
#YEAR#  - 4-digit year \(maximum search time = $MAX_YEARS_BACK years\)
#MONTH# - 2-digit month \(maximum search time = $MAX_MONTHS_BACK months\)
#DAY#   - 3-digit day of year \(maximum search time = $MAX_DAYS_BACK days\)
#MDAY#  - 2-digit day of month \(maximum search time = $MAX_DAYS_BACK days\)
The script will try and find directories over the smallest period of time specified, so if #DAY# is given, it will
search over $MAX_DAYS_BACK days, regardless of whether or not any other placeholders are specified);

# Now create the new Nagios plugin
my $nagios = Nagios::Plugin->new(shortname => $SHORT_NAME, usage => $usage_msg, version => $VERSION);

# Add command line arguments
$nagios->add_arg("d=s", "-d <dir>\n   Directory to search for files in. Wildcards are permitted, but if used, enclose the directory in quotes", undef, 1);
$nagios->add_arg("f=s", "-f <file>\n   File to search for in the directory. May be specified as a regular expression",                          undef, 1);
$nagios->add_arg("w=s", "-w <age>\n   Warn if latest file is older than <age> seconds (default: $DEF_WARN_TIME seconds)",              $DEF_WARN_TIME, 0);
$nagios->add_arg("c=s", "-c <age>\n   Critical if latest file is older than <age> seconds (default: $DEF_CRIT_TIME seconds)",          $DEF_CRIT_TIME, 0);
$nagios->add_arg("W=s", "-W <size>\n   File must be at least this many bytes long (default: $DEF_WARN_SIZE). Warn if not",             $DEF_WARN_SIZE, 0);
$nagios->add_arg("C=s", "-W <size>\n   File must be at least this many bytes long (default: $DEF_CRIT_SIZE). Critical if not",         $DEF_CRIT_SIZE, 0);

# Parse command line arguments
$nagios->getopts;

# Find the latest non-empty directory matching the specified directory
my $latest_dir = find_latest_directory($nagios->opts->d);
if ($latest_dir =~ m/^-[0-9]$/)
{
   my $die_msg_suffix = "";
   if    ($latest_dir == -1) { $die_msg_suffix = sprintf("%d days old",   $MAX_DAYS_BACK);   }
   elsif ($latest_dir == -2) { $die_msg_suffix = sprintf("%d months old", $MAX_MONTHS_BACK); }
   elsif ($latest_dir == -3) { $die_msg_suffix = sprintf("%d years old",  $MAX_YEARS_BACK);  }

   my $die_msg = sprintf("Cannot find directory. Either the target directory was not specified correctly, or the latest file is over %s", $die_msg_suffix);
   $nagios->nagios_die($die_msg);
}

# Go through this directory and find the most recent file
my ($time, $size, $found) = (-1, -1, "");
my $file_regex = $nagios->opts->f;
foreach my $f (`find $latest_dir -type f -printf "\%T@ \%s \%p\n" | sort -rn`)
{
   chomp $f;
   my ($this_time, $this_size, $this_file) = split(" ", $f);
   my $basename = basename($this_file);
   
   if ($basename =~ m/^$file_regex$/)
   {
      ($time, $size, $found) = ($this_time, $this_size, $this_file);
      last;
   }
}

# If no file found, quit
if ($found eq "") { $nagios->nagios_die("Cannot find a matching file in $latest_dir!"); }

# Work out the file age. When used from nagios, the current time is not reset at each script launch
local $^T = time;
my $age   = time - $time;

# Check values against thresholds
my $w_time = convert_time($nagios->opts->w);
my $c_time = convert_time($nagios->opts->c);
my $w_size = convert_size($nagios->opts->W);
my $c_size = convert_size($nagios->opts->C);
if ($w_time == -1) { $nagios->die($nagios->opts->w . " is an invalid warn time!");     }
if ($c_time == -1) { $nagios->die($nagios->opts->c . " is an invalid critical time!"); }
if ($w_size == -1) { $nagios->die($nagios->opts->W . " is an invalid warn size!");     }
if ($c_size == -1) { $nagios->die($nagios->opts->C . " is an invalid critical size!"); }

my ($age_w,   $age_c) = ($w_time,       $c_time);
my ($size_w, $size_c) = ("$w_size:", "$c_size:");
my $age_alert  = $nagios->check_threshold(check => $age,  warning => $age_w,  critical =>  $age_c);
my $size_alert = $nagios->check_threshold(check => $size, warning => $size_w, critical => $size_c); 
my $alert      = max($age_alert, $size_alert);

# Prepare output string
my $output = sprintf("%s is %d seconds old and %d bytes", $found, $age, $size);

# Add performance data
$nagios->add_perfdata((label => "age", "value" => $age, "uom" => "s", warning => $w_time, critical => $c_time));
$nagios->add_perfdata((label => "size", "value" => $size, "uom" => "B", warning => $w_size, critical => $c_size));
$nagios->add_perfdata((label => "file", "value" => $found));

# Exit with appropriate message
$nagios->nagios_exit(return_code => $alert, message => $output);

################################################################################
# SUBROUTINES
################################################################################
sub find_latest_directory # Finds the latest directory
{
    my ($search_dir) = @_;
    
    # Get the current year and day number
    my $this_year  = strftime("%Y", localtime());
    my $this_month = strftime("%m", localtime());
    my $this_day   = strftime("%j", localtime());

    # Determine temporal resolution to search for (i.e. days or years)
    # Also, find the date search boundary and the value to return on error
    my ($is_day, $is_month, $is_year, $date_max) = (0, 0, 0, 0);
    my $return_value = 0;
    if    ($search_dir =~ m/#(M)?DAY#/) { $is_day   = 1; $date_max = $MAX_DAYS_BACK;   $return_value = -1; }
    elsif ($search_dir =~ m/#MONTH#/)   { $is_month = 1; $date_max = $MAX_MONTHS_BACK; $return_value = -2; }
    elsif ($search_dir =~ m/#YEAR#/)    { $is_year  = 1; $date_max = $MAX_YEARS_BACK;  $return_value = -3; }

    # Convert the search directory into a POSIX formatted string
    my $posix_dir = $search_dir;
    $posix_dir =~ s/#YEAR#/%Y/g;
    $posix_dir =~ s/#MONTH#/%m/g;
    $posix_dir =~ s/#DAY#/%j/g;
    $posix_dir =~ s/#MDAY#/%d/g;

    # Try to find a valid directory
    for (my $i=0; $i<=$date_max; $i++)
    {
        # Find the target directory
        my $dir = $posix_dir;
        if    ($is_day)   { $dir = strftime($posix_dir, 0, 0, 0, $this_day - $i, 0, $this_year - 1900);       }
        elsif ($is_month) { $dir = strftime($posix_dir, 0, 0, 0, 1, $this_month - 1 - $i, $this_year - 1900); }
        elsif ($is_year)  { $dir = strftime($posix_dir, 0, 0, 0, $this_day, 0, $this_year - 1900 - $i);       }

        # Check if this directory is valid. If so, return
        my $latest_dir = `find $dir -mindepth 0 -maxdepth 0 -type d ! -empty -printf "\%T@ \%p\n" 2> /dev/null | sort -rn | head -1 | awk '{print \$2}'`;
        if ($latest_dir) { chomp $latest_dir; return $latest_dir; }
    }

    # Return the error value
    return $return_value;
}
################################################################################
sub convert_time # Converts time into seconds
{
    my ($time) = @_;
    
    my ($value, $unit) = (0, "");
    if    ($time =~ m/(\d+)(s|m|h|d|w)$/) { ($value, $unit) = ($1,  $2); }
    elsif ($time =~ m/(\d+)$/)            { ($value, $unit) = ($1, "s"); }
    else                                  { return -1; }

    # Perform conversion
    if    ($unit eq "s") { return $value;                    }
    elsif ($unit eq "m") { return $value * 60;               } 
    elsif ($unit eq "h") { return $value * 60 * 60;          } 
    elsif ($unit eq "d") { return $value * 60 * 60 * 24;     } 
    elsif ($unit eq "w") { return $value * 60 * 60 * 24 * 7; } 
    else                 { return -1; }
}
################################################################################
sub convert_size # Converts size into bytes
{   
    my ($time) = @_;
    
    my ($value, $unit) = (0, "");
    if    ($time =~ m/(\d+)(k|M|G)$/) { ($value, $unit) = ($1,  $2); }
    elsif ($time =~ m/(\d+)$/)        { ($value, $unit) = ($1, "B"); }
    else                              { return -1; }
    
    # Perform conversion 
    if    ($unit eq "B") { return $value;                      }
    elsif ($unit eq "k") { return $value * 1024;               }
    elsif ($unit eq "M") { return $value * 1024 * 1024;        }
    elsif ($unit eq "G") { return $value * 1024 * 1024 * 1024; }
    else                 { return -1; }
}
################################################################################
# DOCUMENTATION
################################################################################

=head1 NAME

check_file.pl - Plugin to find the latest file in a directory and check against it's size and age 

=head1 SYNOPSIS

B<check_file.pl> B<-d> I<dir> B<-f> I<file> [B<-w> I<age>] [B<-c> I<age>] [B<-W> I<size>] [B<-C> I<size>] 

=head1 DESCRIPTION

B<check_file.pl> will find the latest file in I<dir> that matches the glob specified in I<file>. It will then
find the age and the size of this file and compare this with specified thresholds. 

=head1 REQUIREMENTS

The following Perl modules are required in order for this script to work:

 * Nagios::Plugin;
 * File::Basename;
 * POSIX qw(strftime);
 * List::Util qw[max];

=head1 OPTIONS

B<-d> I<dir>

Specifies the directory to search for files in. If your directory has date elements in it, you can various
placeholders for these date elements. Depending on the placeholders you set, the script will try to find
directories within a certain period of time before giving up - otherwise the script could potentially run
forever! The valid placeholders are:

 * #YEAR#  - 4-digit year 
 * #MONTH# - 2-digit month
 * #DAY#   - 3-digit day of year
 * #MDAY#  - 2-digit day of month

The script will try and find directories over the smallest period of time specified, so if #DAY# is given, it will
search over the maximum number of days allowed, regardless of whether or not any other placeholders are specified.

B<-f> I<file>

Specifies the file glob to search for. This should be specified as a Perl regular expression.

B<-w> I<age>

Warn if the latest file is older than I<age>. I<age> is specified in seconds, but modifiers may be used. These modifiers
are s, m, h, d and w for "seconds", "minutes", "hours", "days" and "weeks" respectively.

B<-c> I<age>

Critical if the latest file is older than I<age>. I<age> is specified in seconds, but modifiers may be used. These modifiers
are s, m, h, d and w for "seconds", "minutes", "hours", "days" and "weeks" respectively.

B<-W> I<size>

Warn if the latest file is smaller than I<size>. I<size> is specified in bytes, but modifiers may be used. These modifiers
are k, M and G for kB, MB and GB respectively

B<-C> I<size>

Critical if the latest file is smaller than I<size>. I<size> is specified in bytes, but modifiers may be used. These modifiers
are k, M and G for kB, MB and GB respectively

=head1 EXAMPLE

./check_file.pl -w 36h -c 3d -f '\*\.TXT' -d "/path/to/my/files/"

Finds the latest file in "/path/to/my/files/ that matches "*.TXT" and sends out a warning if that file is older than 36 hours and
a critical alarm if that file is over 3 days old.

=head1 ACKNOWLEDGEMENT

This documentation is available as POD and reStructuredText, with the conversion from POD to RST being carried out by B<pod2rst>, which is 
available at http://search.cpan.org/~dowens/Pod-POM-View-Restructured-0.02/bin/pod2rst

=head1 AUTHOR

Tim Barnes E<lt>tdba[AT]bas.ac.ukE<gt> - British Antarctic Survey, Natural Environmental Research Council, UK

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Tim Barnes, British Antarctic Survey, Natural Environmental Research Council, UK

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.
