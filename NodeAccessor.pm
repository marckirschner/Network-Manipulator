package NodeAccessor;
use strict;
use Data::Dumper;
use NetworkBuilder;
use Moose;

has 'network' => (isa=>'Object', is=>'rw');
has 'nb' => (isa=>'Object', is=>'rw');

sub coordinateAccessor {
	my ($this, $x1,$x2,$y1,$y2, $type ) = @_;

	# loop thru networks
	my $returnNet=[];
	my $nodeList = $this->network()->nodeList();

	foreach (@$nodeList) {
		if (!defined($type)) {
			if ($x1 <= $_->x() && $_->x() <= $x2 &&
				$y1 <= $_->y() && $_->y() <= $y2) {
					push @$returnNet, $_;
			} 
		} else {
				if( ($x1 <= $_->x() && $_->x() <= $x2 &&
					$y1 <= $_->y() && $_->y() <= $y2) && 
					$_->type() eq $type) {
						push @$returnNet, $_;
				}
		}
	}
	
	my $nb = NetworkBuilder->new();
	
	return $nb->build($returnNet);
}

1;