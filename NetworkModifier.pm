package NetworkModifier;
use strict;
use Data::Dumper;
use Moose;

has 'ruleList' => (isa=>'ArrayRef', is=>'rw');
has 'network' => (isa=>'Object', is=>'rw');
has 'ruleMap' => (isa=>'HashRef', is=>'rw');

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
	my  ($this, $network, $pwr, $nd, $label) = @_;
	my $nl = $this->network()->nodeList();
	
	my $counter=0;
	my %usedIdx;
	my $nlSize = scalar(@$nl);
	my $a=0;
	while ($counter<int($nd*$nlSize)) {
		# This operation may be optimized by first building a structure of just the types we want to select from
	#	print "$a, $counter\n";
		$a++;
		my $prob = rand(1);
		my $i = int(rand($nlSize-1));
		
		if ( $nl->[$i]->type() eq '$1' &&
		 	$nd > $prob && !defined($usedIdx{$i})	) {
			$usedIdx{$i} = 1;
			$counter++;
		
			$this->distributePowerUniform($nl->[$i], $network, $pwr, $label);
		
		}		
	}
		#my $nl = $this->network()->nodeList();
		foreach my $nd (@{$nl}) {

			if ($nd->type() eq '$2' || $nd->type() eq '$3') {
				$nd->power($nd->power()*(1-$pwr));
			}
		}
}
## LOOK OUT : CODE DUPLICATION
sub powerNPProportional {
	my  ($this, $network, $pwr, $nd, $label) = @_;
	my $nl = $this->network()->nodeList();
	
	my $counter=0;
	my %usedIdx;
	my $nlSize = scalar(@$nl);
	
	while ($counter<int($nd*$nlSize)) {
		# This operation may be optimized by first building a structure of just the types we want to select from
		my $i = int(rand($nlSize));
		my $prob = rand(1);
		
		if ( $nl->[$i]->type() eq '$1' &&
		 	 $nd > $prob && !defined($usedIdx{$i})	) {
				$usedIdx{$i} = 1;
				$counter++;
				$this->distributePowerProportional($nl->[$i],$network, $pwr, $label);
			}		
	}
	
		#my $nl = $this->network()->nodeList();
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
	my ($this, $node,$network, $pwr, $label) = @_;

	# First assumme uniform power
	my $uniformPower = $network->power() / $this->network()->size();
	$node->power($uniformPower);
	$node->type($label);
	

}

sub distributePowerProportional {
	my ($this, $node,$network, $pwr, $label) = @_;
	
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











