use strict;
use Node;
use NodeBuilder;
use Network;
use RestartFile;
use Data::Dumper;
use NetworkBuilder;
use NodeAccessor;
use NetworkModifier;
no warnings;

main();

sub main
{	
	# Parse The Restart
	my $rf = RestartFile->new();
	$rf->parseRestartFile("r.txt");

	# Build the nodes
	my $nb = NodeBuilder->new();
	$nb->build($rf);

	# Build the Network
	my $netB = NetworkBuilder->new();
	my $k = $netB->build($nb->nodeList());

	# Distribute energy to some nodes
	my $na = NodeAccessor->new();
	$na->network($k);
	my $region1 = $na->coordinateAccessor(0,100,0,100);
	
	my $ntm = NetworkModifier->new();
	$ntm->network($region1);
	$ntm->callback('powerNPProportional', [$k, 0.34, 0.7, '$6'] );	
	$ntm->modify();
	
	# Merge the networks
	$k->merge($region1);

	my $text = $k->toRestartFile($rf)->toString();
	print $text;
}