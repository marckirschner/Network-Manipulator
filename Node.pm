package Node;
use strict;
use Moose;

has 'power' => (isa => 'Num', is=> 'rw');
has 'load' => (isa => 'Num', is=> 'rw');
has 'conListById' => (isa => 'ArrayRef', is=> 'rw');
has 'conListByRef' => (isa => 'ArrayRef', is=> 'rw');
has 'coords' => (isa => 'ArrayRef', is=> 'rw');
has 'x' => (isa => 'Num', is=> 'rw');
has 'y' => (isa => 'Num', is=> 'rw');
has 'type' => (isa => 'Str', is=> 'rw');
has 'name' => (isa => 'Str', is=> 'rw');
has 'idx'=>(isa=>'Num', is =>'rw');


sub points {
	my ($this, $coords) = @_;
	if (!defined($coords)) {
		return $this->coords();
	}
	
	$this->coords($coords);
	$this->x($coords->[0]);
	$this->y($coords->[1]);
} 


1;

