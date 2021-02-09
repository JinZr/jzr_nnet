#!/usr/bin/perl

print "\#\!MLF\!\#\n";

open (IN, $ARGV[0]);

while ($line = <IN>)
{
	chomp($line);
	@chunk = split(/\s+/, $line);
	$name = shift @chunk;
	print "\"" . $name . "\.rec\"\n";
	
	foreach $tmp (@chunk)
	{
		print $tmp . "\n";
	}
	
	print "\.\n";
}

close IN;