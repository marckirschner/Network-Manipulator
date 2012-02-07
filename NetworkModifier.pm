package NetworkModifier;
use strict;
use Data::Dumper;
use Moose;

has 'ruleList' => (isa=>'ArrayRef', is=>'rw');
has 'network' => (isa=>'Object', is=>'rw');
has 'ruleMap' => (isa=>'HashRef', is=>'rw');

my $totalSumPowerSubtracted=0;
my $totalSumPowerAdded=0;
my $E = 0;
my $NUM_COUNT=0;
my $totalNodeLoadCalc = 0;
sub BUILD {
	my ($this) = @_;
	$this->initRuleMap();
}

sub modifyRuleMap {
	my ($this, $callbackKey, $args) = @_;
	my $ruleMap = $this->ruleMap();
	$ruleMap->{$callbackKey}->{'args'} = $args;
	$this->ruleMap($ruleMap);
}

sub callback {
	my ($this, $callbackKey, $args) = @_;
	
	if (!defined($this->ruleMap()->{$callbackKey})) {
		die "$callbackKey does not exist as a rule in NetworkModifier";
	}
	
	$this->modifyRuleMap($callbackKey, $args);
	my $ruleList = $this->ruleList();
	push @$ruleList, $callbackKey;
}

sub modify {
	my ($this) = @_;
	my $ruleMap = $this->ruleMap();
	
	foreach my $callbackKey (@{$this->ruleList()}) {
		my $funcHandl = $ruleMap->{$callbackKey}->{'func'};
		my $funcArgs = $ruleMap->{$callbackKey}->{'args'};
		my @args = ($this);
		map {push @args, $_} @{$funcArgs}; # preserve the 'this' context in the argument list
		
		&{$funcHandl}(@args);
	}
}

################### DEFINE RULES HERE ################################
sub initRuleMap {
	my ($this) = @_;
	my $ruleMap = 
	{
		'powerNPTest' => {	'func'=> \&powerNPTest,
							'args'=>[]
		 				 	},
		'powerNPUniform' => {	'func'=> \&powerNPUniform,
						'args'=>[]
					 		},
		'powerNPProportional' => {	'func'=> \&powerNPProportional,
						'args'=>[]
					 		},
		'createZone' => {	'func'=> \&createZone,
							'args'=>[]
						 		},		
		'applyRegion'	=> {	'func'=> \&applyRegion,
							'args'=>[]
						 		},
		'applyZone'	=> {	'func'=> \&applyZone,
						'args'=>[]
			 		},
		'setObjectType'	=> {
							'func'=> \&setObjectType,
							'args'=>[]
		 		},
					'setRegionLabel'	=> {
										'func'=> \&setRegionLabel,
										'args'=>[]
					 		},

	};
	
	$this->ruleMap( $ruleMap);
	$this->ruleList([]);
}

###################### IMPLEMENT RULES HERE #############

sub applyRegion {
	my ($this, $region) = @_;
		my $nl = $this->network()->nodeList();
		foreach my $nd (@{$nl}) {
			$nd->region($region);
		}
}


sub applyZone {
	my ($this, $zone) = @_;
		my $nl = $this->network()->nodeList();
		foreach my $nd (@{$nl}) {
			$nd->zone($zone);
		}
}

sub setObjectType {
	my ($this, $objectType, $labelList) = @_;
	
		my %labelHash;
		foreach (@$labelList) {
			$labelHash{$_} = 1;
		}
		my $nl = $this->network()->nodeList();
		foreach my $nd (@{$nl}) {
			if (defined($labelHash{$nd->type()})) {
				$nd->objectType($objectType);
			}
		}
}

sub setRegionLabel {
		my ($this, $regionLabel) = @_;
			my $nl = $this->network()->nodeList();
			foreach my $nd (@{$nl}) {
					$nd->regionLabel($regionLabel);
				
			}
}

# For the nodes in this network, take a percent $pwr of the total power from network $network 
# and distribute that power to a percent $nd of the number of nodes in this network. Then change 
# the label of each node that gets distributed energy to a $6

### This needs to be generalized into the architecture because the only difference between this function and 
### powerNPProportional is the call to distributePowerUniform vs distributePowerProportional
### For now I'll leave it as is to get it working. 
sub powerNPUniform {
	my  ($this, $network, $pwr, $nodeFrac, $label) = @_;
	my $nl = $this->network()->nodeList();
	
	my $counter=0;
	my %usedIdx;
	my $nlSize = scalar(@$nl);
	my $a=0;

#	my $distSize = $this->network()->size('$1');

	while ($counter<int($nodeFrac*$nlSize)) {
		my $i = int(rand($nlSize));
		my $prob = rand(1);

		if ( $nl->[$i]->type() eq '$1' &&
		 	 $nodeFrac > $prob && !defined($usedIdx{$i})	) {
				$usedIdx{$i} = 1;
				$counter++;		 	 	
		 	 }
	}

	my $dNodeSize = scalar(keys %usedIdx);

	for my $i (keys %usedIdx) {
		$this->distributePowerUniform($nl->[$i], $network, $pwr, $nodeFrac, $label,$dNodeSize);	
	}

	my $nl2 = $network->nodeList();
	foreach my $nd (@{$nl2}) {
		if ($nd->type() eq '$2' || $nd->type() eq '$3') {
			my $p = $nd->power()*(1-$pwr);
			
			$nd->power($nd->power()*(1-$pwr));

			$totalSumPowerSubtracted+=$p;
		}
	}
}

=m
sub powerNPProportional {
	my  ($this, $network, $pwr, $nodeFrac, $label) = @_;
	my $nl = $this->network()->nodeList();
	
	my $counter=0;
	my %usedIdx;
	my $nlSize = scalar(@$nl);
	my $a=0;

#	my $distSize = $this->network()->size('$1');

	while ($counter<int($nodeFrac*$nlSize)) {
		my $i = int(rand($nlSize));
		my $prob = rand(1);

		if ( $nl->[$i]->type() eq '$1' &&
		 	 $nodeFrac > $prob && !defined($usedIdx{$i})	) {
				$usedIdx{$i} = 1;
				$counter++;		 	 	
		 	 }
	}

	my $dNodeSize = scalar(keys %usedIdx);

	my $totalNodeLoad = 0;
	foreach my $key (keys %usedIdx) {
		$totalNodeLoad += $nl->[$usedIdx{$key} ]->load();
	}

	for my $i (keys %usedIdx) {
		$this->distributePowerProportional($nl->[$i],$network, $pwr, $nodeFrac, $label, $nlSize, $totalNodeLoad);
	}

	my $nl2 = $network->nodeList();
	foreach my $nd (@{$nl2}) {
		if ($nd->type() eq '$2' || $nd->type() eq '$3') {
			my $p = $nd->power()*(1-$pwr);
			
			$nd->power($nd->power()*(1-$pwr));

			$totalSumPowerSubtracted+=$p;
		}
	}
}
=cut

sub powerNPProportional {
	my  ($this, $network, $pwr, $nodeFrac, $label) = @_;
	my $nl = $this->network()->nodeList();
	
	my $counter=0;
	my %usedIdx;
	my $nlSize = scalar(@$nl);
	my $a=0;

#	my $distSize = $this->network()->size('$1');

	while ($counter<int($nodeFrac*$nlSize)) {
		my $i = int(rand($nlSize));
		my $prob = rand(1);

		if ( $nl->[$i]->type() eq '$1' &&
		 	 $nodeFrac > $prob && !defined($usedIdx{$i})	) {
				$usedIdx{$i} = 1;
				$counter++;		 	 	
		 	 }
	}

	my $dNodeSize = scalar(keys %usedIdx);

	print " NODE LOADS-----------------------------------\n";
	my $totalNodeLoad = 0;
	foreach my $key (keys %usedIdx) {
		#print "KEY IS : " . $key . "\n";
		$totalNodeLoad += $nl->[$key ]->load();
		#print "". $nl->[$usedIdx{$key} ]->load() . "\n";
	}

	print "TOTAL NODE LOAD CALCULATE: " . $totalNodeLoad . "\n";

	print "NUMBER OF DIST NODES: " . scalar(keys %usedIdx) . "\n";

	for my $key (keys %usedIdx) {
		$this->distributePowerProportional($nl->[$key],$network, $pwr, $nodeFrac, $label, $nlSize, $totalNodeLoad);
	}

	print "THE CALCULATED NODE LOAD AFTER ITERATION: " . $totalNodeLoadCalc . "\n";

	my $nl2 = $network->nodeList();
	foreach my $nd (@{$nl2}) {
		if ($nd->type() eq '$2' || $nd->type() eq '$3') {
			my $p = $nd->power()*(1-$pwr);
			
			$nd->power($nd->power()*(1-$pwr));

			$totalSumPowerSubtracted+=$p;
		}
	}
}


sub createZone {
	my ($this, $name) = @_;
	my $nl = $this->network()->nodeList();
	foreach my $nd (@{$nl}) {
		my $nodeName = $nd->name();
		# Assume format \w\d
		$nodeName =~ s/\w/$name/;
		$nd->name($nodeName);
	}
}

sub powerNPTest {
	my  ($this, $network, $pwr, $nd, $label) = @_;
	my $nl = ($this->network())->nodeList();
	
	for (my $i=0; $i<scalar(@$nl); $i++) {
		$nl->[$i]->type('$6');
	}
}
###################### UTILITES GO HERE ###########
sub distributePowerUniform {
	my ($this, $node,$network, $pwr, $nodeFrac, $label, $distSize) = @_;

	my $uniformPower = ( $network->power()*$pwr ) / $distSize;#( int($distSize * $nodeFrac) );

	$node->power($uniformPower);

	$node->type($label);

	$totalSumPowerAdded+=$uniformPower;
}

sub distributePowerProportional {
	my ($this, $node,$network, $pwr, $nodeFrac, $label, $distSize, $totalNodeLoad) = @_;

	my $P = $network->power();
	#print "THE POWER IS " . $P . "\n";
	my $mu = $pwr;
	my $rho = $mu*$P;
	my $epsilon = $node->load() / $totalNodeLoad;

	$totalNodeLoadCalc+=$node->load();

	$E += $epsilon;
	$NUM_COUNT++;

	print $node->load() . "\n";

	#print "TOTAL NODE LOAD: " . $totalNodeLoad . "\n";
	#print "E: " . $E . "\n";
	#print "NUM_COUNT: " . $NUM_COUNT . "\n";

	my $newNodePower = $epsilon * $rho;

	$node->power($newNodePower);


	$node->type($label);
}

 
#################################################
1;











