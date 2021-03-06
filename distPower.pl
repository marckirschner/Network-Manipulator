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

	print "Initial Network Parameters\n";

	my $nodeList = $k->nodeList();

	#print Dumper($k->nodeList());

#	foreach my $n (@$nodeList) {
#		if ($n->type() eq '$1') {
#			print "Node Power = " . $n->power() . "\n";
#		}
#	}

	foreach my $rule (@{$config->{rule}}) {
		my $na = NodeAccessor->new();
		$na->network($k);
		my $ntm = NetworkModifier->new();
		
		if ($rule->{type} eq 'buildRegion') {
			$checks{region} = 1;
			
			my ($x1,$y1,$x2,$y2) = split(',', $rule->{region}->{range});
			my $power = $rule->{region}->{power};
			my $node = $rule->{region}->{node};
			my $distType = $rule->{region}->{distType};
			my $label = $rule->{region}->{label};
			my $accessorType = $rule->{region}->{accessorType};
			my $objectType = $rule->{region}->{objectType};
			my $regionLabel = $rule->{region}->{regionLabel};
			
			my $powerRatio = $rule->{region}->{powerRatio};
			my $prob = $rule->{region}->{prob};
			my $regionType = $rule->{region}->{regionType};

			my $excludeRange = $rule->{region}->{excludeRange};
			
			my $callback="";
			
			if ($distType eq 'proportional') {
				$callback = "powerNPProportional"
			} 
			if ($distType eq 'uniform') {
				$callback = "powerNPUniform";
			}
			

			my $region;
			#if (!defined($excludeRange)) {
			#	$region = $na->coordinateAccessor(int($x1),int($y1),int($x2),int($y2),$accessorType);
			#} else { 
			#	if ($excludeRange eq "true") {
					$region = $na->coordinateAccessor(int($x1),int($y1),int($x2),int($y2),$accessorType);
			#	} else {
			#		$region = $na->coordinateAccessor2(int($x1),int($y1),int($x2),int($y2),$accessorType);
			#	}
			#}

=me 
Example of how to use hasNode and getNode
TODO: Delete this comment once this code is documented and tests are written
				if ($k->hasNode({x => 350, 
					 y => 291,
					 name => "n4"}))  
				{
					my $nd = $k->getNode({x => 350, y => 291, name => "n4"});

					print "WE FOUND THE NODE IN A REGION!\n";
					print "It's " .  $nd->type() . "\n";
				} else {
					print "NOPE!\n";
				}
=cut

			my $regionSize = scalar(@{$region->nodeList()});
			if ($regionSize ==0) {
				print "Empty Region: $x1,$y1,$x2,$y2 : $power $node : $distType : $label\n";
				exit;
			} else {
				print "Region Size $regionSize: $x1,$y1,$x2,$y2 : $power $node : $distType : $label\n";
			}
			
			$ntm->network($region);
			$ntm->callback("applyRegion",[$rule->{region}->{range}]);

			if ($callback ne "") {
				$ntm->callback($callback, [$k, $power, $node, $label] );
			}

			# The object Type is a classification (Which should be a structure of it's own to abstract away properties)
			# Objecttype can be anything. Currently I am seeting the object type to be 'region'
			# So therefore multiple node types $6, $9, etc, can have a common object type associating them

			#$ntm->callback("setObjectType", [$objectType, ['$6', '$9'] ]);
			$ntm->callback("setRegionLabel", [$regionLabel, $prob, $powerRatio, $regionType] );
			
			my $str =  "THE TOTAL NETWORK POWER BEFORE: " . $k->getPower() . "\n";
			print "THE TOTAL REGION POWER BEFORE: " . $region->getPower() . "\n";
			$ntm->modify();
			
			print $str;
			print "THE TOTAL REGION POWER AFTER: " . $region->getPower() . "\n";
			
			# Merge the networks
			$k->merge($region);
			print "THE TOTAL NETWORK POWER AFTER: " . $k->getPower() . "\n";
		}
		
		if ($rule->{type} eq 'buildZone') {
			$checks{region} = 1;
			my ($x1,$y1,$x2,$y2) = split(',', $rule->{zone}->{range});
		
			my $name = $rule->{zone}->{name};
			my $callback = "createZone";
						
			my $region = $na->coordinateAccessor(int($x1),int($y1),int($x2),int($y2));
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
				die "Error: Regions are defined in the config file but not all nodes belong to a region.\n";
			}
		}
	}
	
	if ($checks{zone}) {
		my $nl = $k->nodeList();
		foreach my $nd (@$nl) {
			if (!defined($nd->zone()) || $nd->zone() eq "") {
				die "Error: Zones are defined in the config file but not all nodes belong to a zone.\n";
			}
		}
	}

	my $text = $k->toRestartFile($rf)->toString();
	# Place in DEBUG log	
	#print $text;

	# Put somewhere else
	open FILE, ">RESTARTFILE_NEW.txt";
	print FILE $text;
	close FILE;
	
	createRegionFile($k, "RegionDescription.xml");
	
	# Create Node File
	
}


sub createRegionFile {
	my ($network, $fileName) = @_;

	print "Createing the Region file\n";
	die "Undefined Network" unless defined $network;
	die "Undefined file name" unless defined $fileName;
	
	my $nl = $network->nodeList();
	
	die "Node List undefined" unless defined $nl;
	
	my $fh = new IO::File "> $fileName";
    if (defined $fh) {

    	print $fh "<xml>\n";		
        foreach my $n (@$nl) {
			my $line = "";

			if (defined $n->regionLabel() ) {
=m
				my $xmlString ="".
					"<region>"
					."<nodeNumber>". substr($n->name(), 1)."</nodeNumber>"
					."<regionName>". $n->regionLabel()."</regionName>"
					."<nodeType>".$n->type()."</nodeType>"
					."</region>";
=cut

				my $xmlString ="".
				"<region nodeNumber='".substr($n->name(), 1)."' regionName='".$n->regionLabel()."' nodeType='".$n->type()."' prob='".$n->prob()."' powerRatio='".$n->powerRatio()."' regionType='".$n->regionType() ."' ></region>";
				my $line = $xmlString;
				print $fh $line . "\n";		
				my $pos = $fh->getpos;
		        $fh->setpos($pos);
			}
		}
		print $fh "</xml>";

        undef $fh;       # automatically closes the file
    }
 
}

