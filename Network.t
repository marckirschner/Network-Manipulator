use Test::More;
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

# Parse The Restart
my $rf = RestartFile->new();
$rf->parseRestartFile("r.txt");

# Build the nodes
my $nb = NodeBuilder->new();
$nb->build($rf);
is(scalar(@{$nb->nodeList()}), 200, "NodeBuilder Creates 200 nodes");

# Build the Network
my $netB = NetworkBuilder->new();
my $k = $netB->build($nb->nodeList());

is(scalar(@{$k->nodeList()}), 200, "NetworkBuilder Creates a 200 node network");
ok( defined $k->nodeList()->[0]->conListByRef()->[0]->conListById(), 'Linked list network working' );
is(scalar(keys %{$k->conMatrix()}), 200, "NetworkBuilder Creates 200 a node connection Matrix");

# Locate a bunch of nodes 
my $na = NodeAccessor->new();
$na->network($k);
my $spaceNetwork = $na->coordinateAccessor(0,100,0,100);
my $rnl = $spaceNetwork->nodeList();
foreach my $nd (@{$rnl}) {
	cmp_ok( $nd->x(), '<', 100 );
	cmp_ok( $nd->y(), '<', 100 );
}

ok( defined $spaceNetwork, 'Coordinate Location is Working and a temporary Network has been created' );
cmp_ok( scalar($spaceNetwork->nodeList()), '>', 0 );


my $ntm = NetworkModifier->new();
$ntm->network($spaceNetwork);
$ntm->callback('powerNPTest', [$k, 0.34, 0.7, "3"] );
$ntm->modify();

my %types;
map {$types{$_}=1} @{[ map{$_->type()}@{$spaceNetwork->nodeList()} ]};
ok ( defined($types{'$6'}), 'NetworkModifier added a $6 to the network using the powerNP rule');


# Merge the networks
$k->merge($spaceNetwork);
my %types2;
map {$types2{$_}=1} @{[ map{$_->type()}@{$k->nodeList()} ]};
ok ( defined($types{'$6'}), 'Network merge operation succeeded');

my $rf2 = $k->toRestartFile($rf);
ok (defined $rf2, 'Network to RestartFile operation produced a defined object');

my $text = $rf2->toString();
ok (defined $text, 'RestartFile to String operation produced a defined object');









done_testing();