#!/usr/bin/perl

($text, $map, $invers) = @ARGV;

open (IN, $map);

%mapHash;

while ($line = <IN>)
{
	chomp($line);
	@chunk = split(/\s+/, $line);
	if ($invers eq "yes")
	{
		$mapHash{$chunk[0]} = $chunk[1];
	}
	else
	{
		$mapHash{$chunk[1]} = $chunk[0];
	}
}

close IN;

open (IN, $text);

while ($line = <IN>)
{
	chomp($line);
	@chunk = split(/\s+/, $line);
	$name = shift @chunk;
	print $name;
	foreach $tmp (@chunk)
	{
		$word = $mapHash{$tmp};
		print " $word";
	}
	print "\n";
}

close IN;