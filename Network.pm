package Network;
use strict;
use Moose;
use NodeBuilder;
use Node;
use Data::Dumper;
no warnings;

has 'nodeList' => (isa=>'ArrayRef', is=>'rw');
has 'conMatrix' => (isa=>'HashRef', is=>'rw');
has 'power' => (isa => 'Num', is=>'rw');

#TODO: add getWithX, getWithY, getWithXY - will have to build map of coordinates to nodes
sub size {
	my ($this) = @_;
	return scalar(@{$this->nodeList});
}

sub merge {
	my ($this, $network) = @_;
	
	my $nl = $network->nodeList();
	
	my $myNodeList = $this->nodeList();
	foreach my $node (@$nl) {
		$myNodeList->[$node->idx()] = $node;
	}
}

sub toRestartFile {
	my ($this, $rf) = @_;
	my $nl = $this->nodeList();
	my $sec1= [];
	my $coords = [];
	my $connections = [];
	
	for (my $i=0; $i<scalar(@$nl); $i++) {		
		my $conIds = $nl->[$i]->conListById(); 
		
		my $str='['.$conIds->[0];
		for (my $i=1; $i<scalar(@$conIds); $i++) {
	 		$str .= ','.$conIds->[$i];
		}
		
		$str .= ','. $conIds->[scalar($conIds)-1] . ']';
		
		$str=~ s/\,\]/]/;
	
		push @{$sec1}, [$nl->[$i]->type(), $nl->[$i]->load(), $nl->[$i]->power(),$nl->[$i]->power(),
							$nl->[$i]->name(), '('.$nl->[$i]->x() .',' . $nl->[$i]->y() . ')',
							$str];
			
		push (@{$coords}, [ $nl->[$i]->x(),$nl->[$i]->y() ]);
		push (@{$connections}, $nl->[$i]->conListById());
	}
	
	my $rf2 = RestartFile->new();
	$rf2->sec1($sec1);
	$rf2->sec2($rf->sec2());
	$rf2->connections($connections);
	$rf2->coords($coords);
	return $rf2;
}

sub maxX() {
	my ($this) = @_;
	my $nl = $this->nodeList();
	my $maxX=$nl->[0]->x();
	
	foreach my $nd (@{$nl}) {
		if ($nd->x() > $maxX) {
			$maxX = $nd->x();
		}
	}
	return $maxX;
}

sub maxX() {
	my ($this) = @_;
	my $nl = $this->nodeList();
	my $maxY=$nl->[0]->y();
	foreach my $nd (@{$nl}) {
		if ($nd->y() > $maxY) {
			$maxY = $nd->y();
		}
	}
	return $maxY;
}


sub minX() {
	my ($this) = @_;
	my $nl = $this->nodeList();
	my $minX =$nl->[0]->x();
	
	foreach my $nd (@{$nl}) {
		if ($nd->x() < $minX) {
			$minX = $nd->x();
		}
	}
	return $minX;
}

sub minY() {
	my ($this) = @_;
	my $nl = $this->nodeList();
	my $minY =$nl->[0]->y();
	
	foreach my $nd (@{$nl}) {
		if ($nd->y() < $minY) {
			$minY = $nd->y();
		}
	}
	return $minY;
}

1;