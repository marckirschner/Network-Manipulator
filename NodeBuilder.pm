package NodeBuilder;

use strict;
use Moose;
use Node;
use Data::Dumper;
no warnings;

has "nodeList" => (isa => 'ArrayRef', is=> 'rw');

sub build {
	my ($this, $restartFile) = @_;
	
	my @sec1= @{ $restartFile->sec1() };
	
	my $list=[];
	for (my $i=0; $i<scalar(@sec1); $i++) {
		my $cn = $sec1[$i];
	
		my $n = Node->new();
		
		$n->type($cn->[0]);
		$n->load($cn->[1]);
		$n->power($cn->[3]);
		$n->name($cn->[4]);
		$n->idx($i);

		$n->conListById( $restartFile->getConnections($i) );
		$n->points($restartFile->getCoords($i));
	
		push @$list, $n
	}
	
	$this->nodeList($list);
}

1;