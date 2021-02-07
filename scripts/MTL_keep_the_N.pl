($NN_file, $N) = @ARGV;

if ($N eq "")
{
	$N = 1;
}

$lock = 0;

open (IN, $NN_file);

while ($line = <IN>)
{
	if ($line =~ /<ParallelComponent>/)
	{
		$line =~ s/^\s+//g;
		@chunk = split(/\s+/, $line);
		$num_paral = $chunk[0];
		$lock = 1;
	}
	
	if ($line =~ /<CopyN>/)
	{
		$line =~ s/<CopyN>\s+\d+\s+\d+//g;
	}
	
	if ($line =~ /<NestedNnet>/)
	{
		$line1 = $line;
		chomp $line1;
		$line1 =~ s/.*<NestedNnet>\s+(\d+).*/\1/g;
		if ($line1 == $N)
		{
			$lock = 0;
			$line = <IN>;
		}
		else
		{
			$lock = 1;
		}
	}
	
	if ($lock == 0)
	{
		print $line;
	}
}

close IN;
