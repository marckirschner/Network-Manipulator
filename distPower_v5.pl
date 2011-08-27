use strict;
use Node;
use NodeBuilder;
use Network;
use RestartFile;
use Data::Dumper;
use NetworkBuilder;
use NodeAccessor;
use NetworkModifier;
use XML::Simple;
no warnings;

main();

sub main
{		
	my %param;
	( $param{rFile}, $param{config} ) = @ARGV;
				
	unless (-e $param{rFile}) {
			print "Error: $param{rFile} does not exist\n";
			exit;
	}
	unless (defined($param{config}) && -e $param{config}) {
			print "Error: $param{config} does not exist\n";
			exit;
	}
	
	# Parse the config file
	my $config = XMLin($param{config});
	
	my $rf = RestartFile->new();
	$rf->parseRestartFile($param{rFile});
	
	# Build the nodes
	my $nb = NodeBuilder->new();
	$nb->build($rf);
	# Build the Network
	my $netB = NetworkBuilder->new();
	my $k = $netB->build($nb->nodeList());

	# Distribute energy to some nodes
	my $na = NodeAccessor->new();
	$na->network($k);
	my $ntm = NetworkModifier->new();
	
	print Dumper($config);
	
	foreach my $rule (@{$config->{rule}}) {
		if ($rule->{type} eq 'buildRegion') {
			my ($x1,$x2,$y1,$y2) = split(',', $rule->{region}->{range});
			my $power = $rule->{region}->{power};
			my $node = $rule->{region}->{node};
			my $distType = $rule->{region}->{distType};
			my $label = $rule->{region}->{label};
			my $callback="";
			
			if ($distType eq 'proportional') {
				$callback = "powerNPProportional"
			}
			
			if ($distType eq 'uniform') {
				$callback = "powerNPUniform";
			}
			
			my $region = $na->coordinateAccessor(int($x1),int($x2),int($y1),int($y2));
			$ntm->network($region);
			$ntm->callback($callback, [$k, $power, $node, $label] );
			$ntm->modify();
			# Merge the networks
			$k->merge($region);
		}
		
		if ($rule->{type} eq 'buildZone') {
			my ($x1,$x2,$y1,$y2) = split(',', $rule->{zone}->{range});
			my $name = $rule->{zone}->{name};
			my $callback = "createZone";
			
			
			my $region = $na->coordinateAccessor(int($x1),int($x2),int($y1),int($y2));
			$ntm->network($region);
			
			$ntm->callback($callback, [$name] );
			$ntm->modify();
			# Merge the networks
			$k->merge($region);
		}
	}


	my $text = $k->toRestartFile($rf)->toString();
	print $text;
}

