#!/usr/bin/perl

print "{\n";
while (<>)
{
	# skip first line of image description
	next if $. == 1;

	chomp;
	my @props = split /\|/;

	# get scan quality (Q) field
	my $Q = @props[0];
	$Q =~ /(Q)=(\d+)\z/;
	print "  \"$1\": {\"S\": \"$2\"},\n";

	# get remaining fields
	shift @props;
	for my $entry (@props)
	{
		next unless $entry =~ /\=/;
		$entry =~ /\A(.+) = (.+)\z/;
		($name, $value) = ($1, $2);	
		$name =~ s/ //g;
		push @keys, "  \"$name\": {\"S\": \"$value\"}";
	}
	print join ",\n", @keys;
}
print "\n}\n";
