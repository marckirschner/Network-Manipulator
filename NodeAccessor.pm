package NodeAccessor;
use strict;
use Data::Dumper;
use NetworkBuilder;
use Moose;

has 'network' => (isa=>'Object', is=>'rw');
has 'nb' => (isa=>'Object', is=>'rw'); # Research get rid of this.

sub coordinateAccessor {
	my ($this, $x1,$y1,$x2,$y2, $type ) = @_;

	# loop thru networks
	my $returnNet=[];
	my $nodeList = $this->network()->nodeList();

	foreach (@$nodeList) {
			if ($_->x() == 350 && $_->y() == 291) {
				print "Located ". $_->name() .  "\n";
			}
		if (!defined($type)) {
			#if ($x1 <= $_->x() && $_->x() <= $x2 &&
			#	$y1 <= $_->y() && $_->y() <= $y2) {
			if ($_->x() == 350 && $_->y() == 291) {
				print "Comparing " . $_->x() . ", " . $_->y() . " with " . "$x1,$y1 - $x2,$y2" . "\n";
			}
			if ($x1 <= $_->x() && $y1 <= $_->y() &&
				 $_->x() <= $x2 && $_->y() <= $y2) {	
				 	if ($_->x() == 350 && $_->y() == 291) {
				print "Createing a network with" . $_->name() . "\n";
			}
					push @$returnNet, $_;
			} 
		} else {
				if( ($x1 <= $_->x() && $y1 <= $_->y() &&
					 $_->x() <= $x2 && $_->y() <= $y2) && 
					$_->type() eq $type) { # More selective only grab those in a rectangle whose type is $type
						push @$returnNet, $_;
				}
		}
	}
	
	my $nb = NetworkBuilder->new();
	
	return $nb->build($returnNet);
}

## NOT TESTED #########################
sub typeAccessor {
	my ($this, $type ) = @_;

	# loop thru networks
	my $returnNet=[];
	my $nodeList = $this->network()->nodeList();

	foreach (@$nodeList) {
		if ($_->type() eq $type) {
			push @$returnNet, $_;
		}
	}
	
	my $nb = NetworkBuilder->new();
	
	return $nb->build($returnNet);
}

# If only a single connection is in common with the list provided then the node will be returned in the net
# Find any nodes who are connnected to these nodes
sub connectionByIdAccessor {
	my ($this, $conById ) = @_;
	
	my %conHash;
	foreach (@$conById) { $conHash{$_} = 1};
	
	my $returnNet=[];
	my $nodeList = $this->network()->nodeList();

	foreach my $nd (@$nodeList) {
		my $con = $nd->conListById();
		my $bool=0;
		foreach my $conIdx (@$con) { $bool=1 if defined($conHash{$conIdx}); }
		
		if ($bool) {
			push @$returnNet, $nd;
		}
	}
	
	my $nb = NetworkBuilder->new();
	
	return $nb->build($returnNet);
}

1;