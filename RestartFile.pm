package RestartFile;
use strict;
use Moose;
use Data::Dumper;
no warnings;

has 'sec1' => (isa => 'ArrayRef', is=> 'rw');
has 'sec2' => (isa => 'ArrayRef', is=> 'rw');
has 'coords' => (isa => 'ArrayRef', is=>'rw');
has 'connections' => (isa => 'ArrayRef', is=>'rw');

sub getConnections {
	my ($this, $index) = @_;
	return ($this->connections())->[$index];
}

sub getCoords {
	my ($this, $index) = @_;
	return ($this->coords())->[$index];
}

sub parseRestartFile {
	my ($this, $file_name)=@_;
	my @data;
	my @data2;
	
	my $quit = 0;
	
	open FILE, $file_name;
	
	while (<FILE>) {
		chomp;
		&{sub { $quit = 1;}}() if $_ =~ /\/\//;
		push @data, [split('\s+',$_)] unless $quit;
		push @data2, [split('\s+',$_)] if $quit;
	}
	reverse @data;
	pop(@data);
	reverse(@data);
	
	$this->parseCoords(\@data);
	$this->sec1(\@data);
	$this->sec2(\@data2);
}

sub parseCoords {
	my ($this, $restart) = @_;

	my @coords;
	my @connections;
	
	foreach my $line (@$restart) {
		my @d = @$line;
	
		$d[5] =~ s/\(//;
		$d[5] =~ s/\,//;
		$d[6] =~ s/\)//;
		
		my $x = $d[5];
		my $y = $d[6];
		
		my $t = $d[0];
	
		my @con;
		for (my $i=7; $i<scalar(@d); $i++) {
			push @con, $d[$i];
		}
		foreach (@con) {
			s/\[//;
			s/\]//;
			s/\,//;
		}
		
		push @coords, [$x, $y];
		push @connections, \@con;
	}
	
	$this->coords(\@coords);
	$this->connections(\@connections);	
}



sub toString {
	my ($this) = @_;
	my $sec1 = $this->sec1();
	my $sec2 = $this->sec2();
	
	my $restartText="";
	for (my $i=0; $i<scalar(@{$sec1}); $i++) {
		my $str = join(' ', @{$sec1->[$i]});
		$restartText.=$str."\n";
	}
	
	$restartText.="\n";
	for (my $i=0; $i<scalar(@{$sec2}); $i++) {
		my $str = join(' ', @{$sec2->[$i]});
		$restartText.=$str."\n";
	}
	return $restartText;
}







1;