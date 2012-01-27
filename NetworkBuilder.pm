package NetworkBuilder;
use strict;
use Moose;
use NodeBuilder;
use Network;
use Data::Dumper;
no warnings;

sub build {
	my ($this, $nodeList) = @_;
	
	my $k = Network->new();	
	
	# Build Connections between nodes
	my $sumPower=0;
	my $sumLoad=0;

	for (my $i=0; $i<scalar(@$nodeList); $i++) {
		## Network Construction
		$nodeList->[$i];
		my $con = $nodeList->[$i]->conListById();
		my $conListByRef=[];
		foreach my $index (@$con) {
			push @$conListByRef, $nodeList->[$index];
		}
		$nodeList->[$i]->conListByRef($conListByRef);
		
		## Network Analysis ##
		$sumPower += $nodeList->[$i]->power();
		$sumLoad += $nodeList->[$i]->load();
	}
	
	# Next Build the Connection Matrix
	my $matrix = {};
	foreach my $node (@$nodeList) {
		$matrix->{ $node->idx() } = [ map{ $_ - 1 } @{$node->conListById() }];
	}
	
	$k->nodeList($nodeList);
	$k->conMatrix($matrix);
	$k->power($sumPower);
	$k->load($sumLoad);
	
	return $k;
}

1;
