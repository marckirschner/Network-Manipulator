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
use IO::File;
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
	
	my %checks={region=>0,zone=>0};
	
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

	foreach my $rule (@{$config->{rule}}) {
		my $na = NodeAccessor->new();
		$na->network($k);
		my $ntm = NetworkModifier->new();
		
		if ($rule->{type} eq 'buildRegion') {
			$checks{region} = 1;
			my ($x1,$x2,$y1,$y2) = split(',', $rule->{region}->{range});
			my $power = $rule->{region}->{power};
			my $node = $rule->{region}->{node};
			my $distType = $rule->{region}->{distType};
			my $label = $rule->{region}->{label};
			my $accessorType = $rule->{region}->{accessorType};
			my $objectType = $rule->{region}->{objectType};
			
			my $callback="";
			
			if ($distType eq 'proportional') {
				$callback = "powerNPProportional"
			}
			
			if ($distType eq 'uniform') {
				$callback = "powerNPUniform";
			}
			
			my $region = $na->coordinateAccessor(int($x1),int($x2),int($y1),int($y2),$accessorType);
			my $regionSize = scalar(@{$region->nodeList()});
			if ($regionSize ==0) {
				print "Empty Region: $x1,$x2,$y1,$y2 : $power $node : $distType : $label\n";
				exit;
			} else {
				print "Region Size $regionSize: $x1,$x2,$y1,$y2 : $power $node : $distType : $label\n";
			}
			
			$ntm->network($region);
			$ntm->callback("applyRegion",[$rule->{region}->{range}]);
			$ntm->callback($callback, [$k, $power, $node, $label] );
			$ntm->callback("setObjectType", [$objectType]);
			$ntm->modify();
		
			# Merge the networks
			$k->merge($region);
		}
		
		if ($rule->{type} eq 'buildZone') {
			$checks{region} = 1;
			my ($x1,$x2,$y1,$y2) = split(',', $rule->{zone}->{range});
			my $name = $rule->{zone}->{name};
			my $callback = "createZone";
						
			my $region = $na->coordinateAccessor(int($x1),int($x2),int($y1),int($y2));
			$ntm->network($region);
			
			$ntm->callback("applyZone",[$rule->{zone}->{name}]);
			$ntm->callback($callback, [$name] );
			$ntm->modify();
			# Merge the networks
			$k->merge($region);
		}
	}
	
	if ($checks{region}) {
		my $nl = $k->nodeList();
		foreach my $nd (@$nl) {
			if (!defined($nd->region()) || $nd->region() eq "") {
				print "Error: Regions are defined in the config file but not all nodes belong to a region.\n";
			}
		}
	}
	
	if ($checks{zone}) {
		my $nl = $k->nodeList();
		foreach my $nd (@$nl) {
			if (!defined($nd->zone()) || $nd->zone() eq "") {
				print "Error: Zones are defined in the config file but not all nodes belong to a zone.\n";
			}
		}
	}

	my $text = $k->toRestartFile($rf)->toString();
	print $text;
	
	createRegionFile($k, "RegionFile.txt");
	
	
	# Create Node File
	
}


sub createRegionFile {
	my ($network, $fileName) = @_;

	die "Undefined Network" unless defined $network;
	die "Undefined file name" unless defined $fileName;
	
	my $nl = $network->nodeList();
	
	die "Node List undefined" unless defined $nl;
	
	my $fh = new IO::File "> $fileName";
    if (defined $fh) {
        foreach my $n (@$nl) {
			my $line = "";
			if (defined $n->objectType() && $n->objectType eq "region") {
				my $line = "".$n->type() . "\t" . substr($n->name(), 1);
				print $fh $line . "\n";		
				my $pos = $fh->getpos;
		        $fh->setpos($pos);
			}
		}
        undef $fh;       # automatically closes the file
    }
 
}

