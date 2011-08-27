#!/usr/bin/perl

##
## Changed franctions condition to be > instead of < because it was front loading ie
## choosing 80% instead of 20% percent
#if ($param{FracDist} > $prob && !defined($usedIdx{$i})) {
###

use strict;
use Data::Dumper;
use Getopt::Long;

# (1) Put the parameters passed thru command line into the hash %param
my %param;
GetOptions(
'file=s' => \$param{"fileName"},
'c=s'=>\$param{"config"},
'r_file=s' => \$param{"restart"},
'u' => \$param{'uniform'},
'fracP=s' => \$param{'fracP'},
'fracN=s' => \$param{'fracN'}
);

# (2) Display the paramters to STDOUT
#print Dumper(\%param);

# (3) Parse the configuration file and put the data into $d
my $d = parse_config();

parse_restart("r.txt");
exit;

# (4) Put each parameter within the configuration file into the hash %param
foreach (keys %{$d}) {
	$param{$_} = $d->{$_};
}

if (defined($param{fracP}) && defined($param{fracN})) {
  $param{FracPower} = $param{fracP};
  $param{FracDist} = $param{fracN};
}


# (5) Now Parse the Restart File
# We put the data we wish to manipulate in $data and the rest of the data that comes after the 
# forward slashes // into $data2
# After we manipulate the data in $data, we then create a new array called @text and add to it
# everything that is in $data and everything that is in $data2. Thus we create a new Restart file.
my ($data, $data2) = parse_restart();

# (7) @indexDistNodes stores all of the sinks for instance, it would look like ($1, $1, $1, ....)
# $sumSourcePower is the sum of the power of all the sinks and sources, ie, all of the $3's
# $c is the number of all the sinks, ie, number of all the $1's
# $index is the total number of nodes in the system
my @indexDistNodes;
my $sumSourcePower = 0;
my $c=0;
my $index=0;

# (8) Now iterate across the restart data and put the data into the necessary datastructures discussed at (7) (????DEN, is correctly adding both? ???)
foreach (@$data) 
{
	my $node = $_->[0];
	$c++ if $node eq $param{'sink'};
	if ( $node eq $param{'sink'} ) {
		push @indexDistNodes, $index;
	}
	
	if ( $node eq $param{'source'} or $node eq $param{'both'} )
	{
		$sumSourcePower += $_->[3];
	}
	$index++;
}

# (9) $nodeCount1 stores the number of source nodes or $2's
# $nodeCount2 stores the number of $3's
# $totalNumNodes is the total number of nodes in the file. Okay, this is redundant and needs to be cleaned up.
# $numDistNodes is the total number of Distributed nodes, ie, the total number of nodes times the fraction of total distributed nodes, where
#    the fraction of distributed nodes was defined in the config file as FracDist
# $totalPowerDist is the total amount of power that will be distributed across the distributed nodes, ie, the sum of the source & sink power ($3's)
#    times the fraction of distributed power, where the fraction of distributed power was defined in the config file as FracPower
# $unitDistNodePower is the total distributed power divided by the number of distributed nodes, this is used in the uniform case. (???DEN rounding issue .... add one unit???)
my $nodeCount1 = countNode($param{source});
my $nodeCount2 = countNode($param{both});
my $totalNumNodes = scalar(@$data);
my $numDistNodes = round($param{FracDist}*$totalNumNodes);
my $totalPowerDist = $sumSourcePower*$param{FracPower};
my $unitDistNodePower = $totalPowerDist / $numDistNodes;

# (10) Lets print some diagnostics
print "TOTAL NUM NODES: " . $totalNumNodes . "\n";
print "Num Dist Nodes: " . $numDistNodes . "\n";
print "Sum Source Power: " . $sumSourcePower . "\n";
print "Power UNIT: " . $unitDistNodePower . "\n";

# (11) @indexSourceNodes is an array that stores all of the indices of all the sink nodes
# so for instance if the Beginning of the restart file had a first column that looked like this
# 
# $1
# $1
# $3
# $1 
# $2
# $3
# $1
#
# Then the @indexSourceNodes array would look like this (0, 1, 3, 6, ..)
# As you can see, the elements are just the line number of the $1's.
my @indexSourceNodes;
for (my $i=0; $i<scalar(@$data); $i++) {
	# (12) Place the index of each sink into @indexSourceNodes. This code says
	# if line number $i, where  $i = 1,2,3,..., has a string that equals '$2' then add $i
	# to @indexSourceNodes
	push @indexSourceNodes, $i if $data->[$i]->[0] eq $param{sink};
}

# (13) Irrelevant, ignore this.
my $n=$numDistNodes;

# (14) Store the number of $1's that are in the restart file into $numSinks
my $numSinks = scalar(@indexDistNodes);

# (15) This is a very important check-exception. First I'll explain why its necessary then I'll explain what it is. 
# Remember, we calculate the number of distributed nodes as
# The total number of every type of node multiplied by the fraction FracDist that is defined in the config file.
# Also note that once we have a number of distributed nodes we want to create, what we actually do is CHANGE the sinks into 
# distributed nodes, in other words we replace a certain number of $1's with $6's, that number being the number of distributed nodes we 
# wish to create. Therefore it is impossible to create more distributed nodes than there are $1's. 
# Thus, this condition checks to see if the number of Distributed Nodes is Greater than the number of $1's. If it is, then the ability to 
# generate the distributed node network is impossible because we cannot exceed the number of $1's. If this is the case, we simply tell the 
# user this and exit the script.
if ($numDistNodes > $numSinks) {
	my $msg = "The number of sinks is: $numSinks and " . ($param{FracDist}*100)."% of total nodes ($totalNumNodes) is $numDistNodes\n";
	$msg .= "Please lower FracDist so that the number of distributed nodes is less than or equal to\n";
	$msg .= "the number of sinks.\n";
	print $msg;
	exit;
	
}

# (16) Print all the sinks ie, $1, $1, $1
map { print $_ . " " . $data->[$_]->[0] . "\n"; } @indexDistNodes;

# (17) Sorry, again this stupid $n creeps up, I have no idea why I do this. I'll have to clean this later.
# Anyways, just put the number of distributed nodes into $n, we then decrement this value in the while loop that follows 
# during the algorithm which randomly changes the $1's into $6's
my $n=$numDistNodes;

# (18) @distNodeIdx will hold the indices of the $6's that will be added to the restart file, the idea
#   is to add the indices to an array, then later, loop through these indices and change the code from a $1 to a $6.
# %usedIdx makes sure we don't change the same line twice. Since the while loop will continue indefinitely, randomly 
#   sampling line numbers until finally the total number of distributed nodes is created, it is possible to select a given line number
#   many many times, but we wish to avoid this, otherwise we will end up with an incorrect number of distributed nodes, 
#   so everytime we choose a line number to add a $6 to, we add this line number to %usedIdx and then before changing 
#   any $1 to a $6, we check first to see if the line number we are on has already been modified 
#   by checking for it's existence in %usedIdx. 
my @distNodeIdx;
my %usedIdx;
# (19) while $n is greater than zero
#         get a random number between 0 and 1
#         if the fraction of distributed nodes is greater than the random number AND
#             if the current line has never been modified
#         THEN
#            add the current line number to @distNodeIdx
#            indicate in %usedIdx that this line number has been modifed
#            subtract 1 from $n
#            if $n is equal to or less than zero then break from the loop
while ($n>0) {
	foreach my $i (@indexDistNodes) {
		my $prob = rand(1);
		if ($param{FracDist} > $prob && !defined($usedIdx{$i})) {
			push @distNodeIdx, $i;
			print "Pushing " . $data->[$i]->[0] . "\n";
			$usedIdx{$i} = 1;
			$n--;
			last if ($n<=0);
		}
	}
}

# (20) irrelevant testing I was doing, just printing stuff. Will clean up later.
print "indexDistNodes\n";
foreach (@indexDistNodes) { 
print $data->[$_]->[0] . "\n";
}


# (21) $dist_node_load_sum will store the sum of the loads for all the $1's (sinks)  (???DEN should only be over the $1's that have become $6's ...so the sum addeds to one ???)
# This is used for the Proprotional case where we take this into consideration when distributing
# Power around.
my $dist_node_load_sum;
foreach (@distNodeIdx) {
		$dist_node_load_sum += $data->[$_]->[1];
}

# (22) This is where we actually calculate the amount of power to distributed to each node
# We loop through each of the line numbers that are to be changed into distributed nodes ($6's)
# The first bit of code is calculating the proportional power to give to the current node in the loop.
# We multiply the total amount of distributed power by the ratio of this node's load to the total load
# to get the amount of power to give to this node. More verbosely, we do this:
#                 We first put the load of the given node into $this_node_load
#                 Then divide $this_node_load by the sum of the total load ie, $dist_node_load_sum
#                 and put the result into $frac_gen_of_total
#                 We then multiply the fraction $frac_gen_of_total by the total power that is to be distributed, 
#                 ie, $totalPowerDist and put the result into $node_gen
# Next we change the $1 to a $6
# Finally we check to see if the parameter -u was given in the command line, if it has then we will apply 
# the uniform distribution by giving this node a power of $unitDistNodePower, see (9) for more information on $unitDistNodePower
# IF -u was not provided in command line then we will apply the proportional distribution and give this node a power of 
# $node_gen, which was just talked about above.
foreach my $index (@distNodeIdx) {
	# Calculate the sum the generation to give to the node.
	my $this_node_load = $data->[$index]->[1];
	#print "THIS LOAD:" . $this_node_load ."\n";
	my $frac_gen_of_total = $this_node_load / $dist_node_load_sum;
	my $node_gen = $totalPowerDist*$frac_gen_of_total;
	$data->[$index]->[0] = '$6';
	
	if (defined($param{'uniform'}) ) {
		$data->[$index]->[2] = $unitDistNodePower;
		$data->[$index]->[3] = $unitDistNodePower;
	} else {
		$data->[$index]->[2] = $node_gen;   #$unitDistNodePower;
		$data->[$index]->[3] = $node_gen;   #$unitDistNodePower;
	}
}


# (23) We then subtract from every node's power that is a $2 or $3 the ammount $unitDistNodePower (???DEN multiply by (1-parameterfracpower)???)
foreach (my $i=0; $i<scalar(@{$data}); $i++) {
	&{sub{
		# BAD $data->[$i]->[2] -= $unitDistNodePower;
		# BAD $data->[$i]->[3] -= $unitDistNodePower;
		$data->[$i]->[2] *= (1-$param{FracPower});
		$data->[$i]->[3] *= (1-$param{FracPower});
	}}() if $data->[$i]->[0] eq $param{'source'} or $data->[$i]->[0] eq $param{'both'};
}

# (24) We are now done. So create the new Restart file by concatenating the data manipulated plus 
# the data that was spliced out in the beginning
my $text ="";
for (my $i=0; $i<scalar(@{$data}); $i++) {
	$text .= join(' ', @{$data->[$i]}) . "\n";	
}
$text.="\n";
for (my $i=0; $i<scalar(@{$data2}); $i++) {
	$text .= join(' ', @{$data2->[$i]}) . "\n";	
}

my $directory_name = $param{FracPower} . "_" . $param{FracDist};
if (defined($param{'uniform'})) {
  $directory_name .= "_uni";
} else {
  $directory_name .= "_prop";
}

if (! -d $directory_name) {
  `mkdir $directory_name`;
}

my $new_file_name = "$directory_name".'/'."Restart_".$param{FracPower} . "_" . $param{FracDist};
open FILE, ">".$new_file_name;
print FILE $text;
close FILE;
print "Wrote file " . $new_file_name . "\n";

=me
my $opa = "OPA3.2.3.out";
if (-e "OPA3.2.3.out") {
  my $cmd = "cp $opa $directory_name" . '/';
  `$cmd`;
}

my $cmd_f = "tar -cf $directory_name.tar $directory_name".'/';
`$cmd_f`;
=cut

exit;

sub countNode {
	my $nodeType = shift;
	my $data = shift;
	
	my $sum=0;
	foreach (@{$data}) {
		$sum++ if $_->[0] eq $nodeType;
	}
	return $sum;
}


#print Dumper($data);

sub round {
	my $num = shift;
	return int($num + .5);
}

sub parse_config {
	open FILE, "<".$param{"config"};
	my %data=();
	
	while (<FILE>) {
		print $_;
		chomp;
		my @line = split(',', $_);
		for (my $i=0; $i<scalar(@line); $i++) { 
			$line[$i] =~ s/\s+//g;
		}
		$data{$line[0]} = $line[1];
	}
	
	return \%data;
}

sub parse_coords {
	my $restart = shift;
	
	foreach my $line (@$restart) {
		my @d = @$line;
	
		$d[5] =~ s/\(//;
		$d[5] =~ s/\,//;
		$d[6] =~ s/\)//;
		my $x = $d[5];
		my $y = $d[6];
		my $t = $d[0];
		
		print "$x\t$y\n";
	
		my @con;
		for (my $i=7; $i<scalar(@d); $i++) {
			push @con, $d[$i];
		}
		foreach (@con) {
			s/\[//;
			s/\]//;
			s/\,//;
		}
	}
}

sub parse_restart {
	my $file_name=shift;
	my @data;
	my @data2;
	
	my $quit = 0;
	
	open FILE, $file_name;
	print $file_name . "\n";
	while (<FILE>) {
		chomp;
		&{sub { $quit = 1;}}() if $_ =~ /\/\//;
		push @data, [split('\s+',$_)] unless $quit;
		push @data2, [split('\s+',$_)] if $quit;
	}
	reverse @data;
	pop(@data);
	reverse(@data);
	
	
	#print Dumper(\@data);
	
	parse_coords(\@data);
	
	exit;
	
	return (\@data, \@data2);
}

sub verify_node_format {
	my $field = shift;
	die "Format incorrect.\n" unless $field =~ /\$\d{1}/;
}

sub verify_data {
	my $data =shift;
	foreach (@{$data}) {
		my $node = $_->[0];
		verify_node_format($node);
	}
}
