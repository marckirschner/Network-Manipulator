package NetworkModifier;
use strict;
use Data::Dumper;
use Moose;

has 'ruleList' => (isa=>'ArrayRef', is=>'rw');
has 'network' => (isa=>'Object', is=>'rw');
has 'ruleMap' => (isa=>'HashRef', is=>'rw');

my $totalSumPowerSubtracted=0;
my $totalSumPowerAdded=0;

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

	my $distSize = $this->network()->size('$1');

	print "Number of Q = " . $distSize . "\n";
	print "Number of nl = " . $nlSize . "\n";
	print "Diff = " . ($nlSize - $distSize) . "\n";

	print "TOTAL = " . ($this->network()->size('$1')+$this->network()->size('$3')) . "\n";

	while ($counter<int($nodeFrac*$nlSize)) {
	#while ($counter < int($nodeFrac*$distSize)) {
		# This operation may be optimized by first building a structure of just the types we want to select from
		$a++;
		my $prob = rand(1);
		my $i = int(rand($nlSize-1));
		
		if ( $nl->[$i]->type() eq '$1' &&
		 	$nodeFrac > $prob && !defined($usedIdx{$i})	) {
			$usedIdx{$i} = 1;
			$counter++;
			
		#	print "NODE PROPERTIES: " . $nl->[$i]->power() . "\n";

			####$this->distributePowerUniform($nl->[$i], $network, $pwr, $nodeFrac, $label,$distSize);
		
			$this->distributePowerUniform($nl->[$i], $network, $pwr, $nodeFrac, $label,$nlSize);
		
		}		
	}

	print "COUNTER RAN = " . $counter . "\n";

#	my $consvPower = ($pwr*$network->power())/($network->size('$2')+$network->size('$3'));
	
	#my $nl = $this->network()->nodeList();
	my $nl2 = $network->nodeList();
	foreach my $nd (@{$nl2}) {
		if ($nd->type() eq '$2' || $nd->type() eq '$3') {
			my $p = $nd->power()*(1-$pwr);
			
			$nd->power($nd->power()*(1-$pwr));

			#print "Subtracting out " . $p . "\n";
			$totalSumPowerSubtracted+=$p;
			
		##	$nd->power( $nd->power() - $consvPower );
		}
	}

	print "Sum Power Subtracted: " . $totalSumPowerSubtracted . "\n";
	print "Sum Power Added: " . $totalSumPowerAdded . "\n";


}
## LOOK OUT : CODE DUPLICATION
sub powerNPProportional {
	my  ($this, $network, $pwr, $nodeFrac, $label) = @_;
	my $nl = $this->network()->nodeList();
	
	my $counter=0;
	my %usedIdx;
	my $nlSize = scalar(@$nl);
	
	my $distSize = $this->network()->size('$1');

	while ($counter<int($nodeFrac*$nlSize)) {
		# This operation may be optimized by first building a structure of just the types we want to select from
		my $i = int(rand($nlSize));
		my $prob = rand(1);
		#
		# Should multiply Total System Power by power fraction and divide this
		# by the number of $1's multiplied by the fraction of generators
		#
		#
		if ( $nl->[$i]->type() eq '$1' &&
		 	 $nodeFrac > $prob && !defined($usedIdx{$i})	) {
		 	 	
				$usedIdx{$i} = 1;
				$counter++;
				$this->distributePowerProportional($nl->[$i],$network, $pwr, $nodeFrac, $label, $distSize);
			}		
	}
	#my $nl2 = network()->nodeList();
	foreach my $nd (@{$nl}) {
		if ($nd->type() eq '$2' || $nd->type() eq '$3') {
			$nd->power($nd->power()*(1-$pwr));
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


	#print "DIST SIZE: " . $distSize;
	# First assumme uniform power

	####my $uniformPower = ( $network->power()*$pwr ) / ( $distSize * $nodeFrac );

	my $uniformPower = ( $network->power()*$pwr ) / ( $distSize * $nodeFrac );

	#print "Power Fraction " . $pwr . "\n";
	#print "Node Fraction " . $nodeFrac . "\n";
	#print "Number Distributed : " . $distSize * $nodeFrac . "\n";
	#print "Distributed Power: " . $uniformPower;

#	print "Expected increase in power: " . ($distSize*$uniformPower) . "\n";

#	print "---------------------------------\n";
	#print $network->power()*$pwr . "\n";
	#print $distSize . "\n";
#	print "UNIFORM POWER: " . $uniformPower . "\n";
#	print "Total power: " . $network->getPower() . "\n";

#	print "Node power before: " . $node->power() . "\n";
	$node->power($uniformPower);
#	print "Node power after: " . $node->power() . "\n";
	$node->type($label);

	$totalSumPowerAdded+=$uniformPower;
}

sub distributePowerProportional {
	my ($this, $node,$network, $pwr, $nodeFrac, $label) = @_;
	
	my $distNodeLoadSum=0;
	my $nl = $this->network()->nodeList();
	foreach my $nd (@{$nl}){
		if ($nd->type() eq '$1') {
			$distNodeLoadSum += $nd->load();
		}
	}
	
	my $proportionality = $node->load() / $distNodeLoadSum;
	my $proportionalPower = $network->power()*$proportionality;
	
	$node->power($proportionalPower);
	$node->type($label);
}

 
#################################################
1;











