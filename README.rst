.. highlight:: perl


****
NAME
****


check_file.pl - Plugin to find the latest file in a directory and check against it's size and age


********
SYNOPSIS
********


\ **check_file.pl**\  \ **-d**\  \ *dir*\  \ **-f**\  \ *file*\  [\ **-w**\  \ *age*\ ] [\ **-c**\  \ *age*\ ] [\ **-W**\  \ *size*\ ] [\ **-C**\  \ *size*\ ]


***********
DESCRIPTION
***********


\ **check_file.pl**\  will find the latest file in \ *dir*\  that matches the glob specified in \ *file*\ . It will then
find the age and the size of this file and compare this with specified thresholds.


************
REQUIREMENTS
************


The following Perl modules are required in order for this script to work:


.. code-block:: perl

  * Nagios::Plugin;
  * File::Basename;
  * POSIX qw(strftime);
  * List::Util qw[max];



*******
OPTIONS
*******


\ **-d**\  \ *dir*\ 

Specifies the directory to search for files in. If your directory has date elements in it, you can various
placeholders for these date elements. Depending on the placeholders you set, the script will try to find
directories within a certain period of time before giving up - otherwise the script could potentially run
forever! The valid placeholders are:


.. code-block:: perl

  * #YEAR#  - 4-digit year 
  * #MONTH# - 2-digit month
  * #DAY#   - 3-digit day of year
  * #MDAY#  - 2-digit day of month


The script will try and find directories over the smallest period of time specified, so if #DAY# is given, it will
search over the maximum number of days allowed, regardless of whether or not any other placeholders are specified.

\ **-f**\  \ *file*\ 

Specifies the file glob to search for. This should be specified as a Perl regular expression.

\ **-w**\  \ *age*\ 

Warn if the latest file is older than \ *age*\ . \ *age*\  is specified in seconds, but modifiers may be used. These modifiers
are s, m, h, d and w for "seconds", "minutes", "hours", "days" and "weeks" respectively.

\ **-c**\  \ *age*\ 

Critical if the latest file is older than \ *age*\ . \ *age*\  is specified in seconds, but modifiers may be used. These modifiers
are s, m, h, d and w for "seconds", "minutes", "hours", "days" and "weeks" respectively.

\ **-W**\  \ *size*\ 

Warn if the latest file is smaller than \ *size*\ . \ *size*\  is specified in bytes, but modifiers may be used. These modifiers
are k, M and G for kB, MB and GB respectively

\ **-C**\  \ *size*\ 

Critical if the latest file is smaller than \ *size*\ . \ *size*\  is specified in bytes, but modifiers may be used. These modifiers
are k, M and G for kB, MB and GB respectively


*******
EXAMPLE
*******


./check_file.pl -w 36h -c 3d -f '\\*\.TXT' -d "/path/to/my/files/"

Finds the latest file in "/path/to/my/files/ that matches "\*.TXT" and sends out a warning if that file is older than 36 hours and
a critical alarm if that file is over 3 days old.


***************
ACKNOWLEDGEMENT
***************


This documentation is available as POD and reStructuredText, with the conversion from POD to RST being carried out by \ **pod2rst**\ , which is 
available at http://search.cpan.org/~dowens/Pod-POM-View-Restructured-0.02/bin/pod2rst


******
AUTHOR
******


Tim Barnes <tdba[AT]bas.ac.uk> - British Antarctic Survey, Natural Environmental Research Council, UK


*********************
COPYRIGHT AND LICENSE
*********************


Copyright (C) 2014 by Tim Barnes, British Antarctic Survey, Natural Environmental Research Council, UK

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

