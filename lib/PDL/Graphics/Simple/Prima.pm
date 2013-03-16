######################################################################
######################################################################
######################################################################
###
###
### Prima backend for PDL::Graphics:Simple
###
### See the PDL::Graphics::Simple docs for details
###
##
#
package PDL::Graphics::Simple::Prima;

use PDL;
use PDL::Options q/iparse/;

our $mod = {
    shortname => 'prima',
    module => 'PDL::Graphics::Simple::Prima',
    engine => 'PDL::Graphics::Prima',
    synopsis => 'Prima (interactive, fast, PDL-specific)',
    pgs_version => '1.000'
};
PDL::Graphics::Simple::register('PDL::Graphics::Simple::Prima');


##########
# PDL::Graphics::Simple::Prima::check
# Checker
sub check {
    my $force = shift;
    $force = 0 unless(defined($force));
    
    return $mod->{ok} unless( $force or !defined($mod->{ok}));
    $mod->{ok} = 0; # makes default case simpler

    # Check Prima availability
    my $min_version = 0.13;
    eval { require PDL::Graphics::Prima; };
    if($@) {
	$mod->{msg} = "Couldn't load PDL::Graphics::Prima: ".$@;
	undef $@;
	return 0;
    }
    if ($PDL::Graphics::Prima::VERSION < $min_version) {
	$mod->{msg} = "Prima version $PDL::Graphics::Prima::VERSION is too low ($min_version required)";
	return 0;
    }

    eval { require PDL::Graphics::Prima::Simple; };
    if($@) {
	$mod->{msg} = "Couldn't load PDL::Graphics::Prima::Simple: ".$@;
	undef $@;
	return 0;
    }
    
    eval {
	require Prima::Application;
	Prima::Application->import();
    };
    if($@) {
	$mod->{msg} = "Couldn't load Prima application: ".$@;
	undef $@;
	return 0;
    }

    # Don't know if all these are actually needed; I'm stealing from the demo.
    # --CED
    eval {
	require Prima::Label;
	require Prima::PodView;
	require Prima::Buttons;
	require Prima::Utils;
	require Prima::Edit;
    };
    if($@){ 
	$mod->{msg} = "Couldn't load auxiliary Prima modules: ".$@;
	undef $@;
	return 0;
    }
 
    $mod->{ok} =1;
    return 1;
}


##############################
# New - constructor
our $new_defaults = {
    size => [6,4.5,'in'],
    type=>'i',
    output=>'',
    multi=>undef
};

## Much of this boilerplate is stolen from PDL::Graphics::Prima::Simple...
our $N_windows = 0;

sub new {
    my $class = shift;
    my $opt_in = shift;
    $opt_in = {} unless(defined($opt_in));
    my $opt = { iparse($new_defaults, $opt_in) };
    
    my $pw;

    unless( check() ) {
	die "$mod->{shortname} appears nonfunctional\n" unless(check(1));
    }

    my $size = PDL::Graphics::Simple::_regularize_size($opt->{size},'px');
    
    my $pw = Prima::Window->create( text => $opt->{output} || "PDL/Prima Plot",
				    size => [$size->[0], $size->[1]]
				    onCreate => sub { $N_windows++; },  
				    onDestroy => sub { $N_windows--;}   # Should maybe do something smarter here --like 
	);                                                              # auto-deallocate from the widgets list...

    my $me = { obj => $pw, widgets => [] };
    return bless($me, "PDL::Graphics::Simple::Prima");
}

sub DESTROY {
    my $me = shift;
    $me->{obj}->hide;
    $me->{obj}->destroy;
}

# List of point-style types.  We'll iterate over these to get values for 
# the {style} curve option.  
@pointstylenames = qw/Blobs Triangles Squares Crosses Xs Asterisks/;

# [Need to implement colors too.]
@colors = ();   # What goes in here?  I don't know yet.
 
##############################
# Plot types
#
# This probably needs a little more smarts.  
# Currently each entry is either a ppair::<foo> return or a sub that implements
# the plot type in terms of others. 
our $types = {
    lines => ppair::Lines,
    points => [ map { eval q{ppair::$_()} } @pointstylenames ],
    bins => undef,
    errorbars => undef,
    limitbars => undef,
    image => undef,
    circles => undef,
    labels => undef
};


##############################
# Plot subroutine
#
# Skeletal just now.
#
# Need to figure out how to handle overplotting.
# Also need to figure out how to control layout.
#
sub plot {
    my $me = shift;
    my $ipo = shift;
    print "P::G::S::Plot\n";
    if(defined($ipo->{legend})) {
	printf(STDERR "WARNING: Ignoring 'legend' option (Legends not yet supported by PDL::Graphics::Simple::Prima v%s)",$PDL::Graphics::Simple::VERSION);
    }
    
    # If not overplotting, erase everything in the window...
    unless($ipo->{oplot}) {
	map { $_->{destroy} } @{$me->{widgets}};
    }
    
    if(!defined($ipo->{multi})) {

	for my $block(@_) {
	    my $co = shift @$block;

	    # Get data and generate sequence if necessary
	    if(@$block < 2) {
		unshift(@$block, sequence($block->[0]));
	    }

	    # Parse out curve style (for points type selection)
	    if(defined($co->{style}) and $co->{style}) {
		$me->{curvestyle} = $co->{style};
	    } else {
		$me->{curvestyle}++;
	    }
	    
	    my %plot_args;
	    
	    if( ref $types->{$co->{with}} eq 'CODE' ) {
		&{$types->{$co->{with}}}($me, $block);
	    } else {
		my $pt;
		if(ref $types->{$co->{with}} eq 'ARRAY') {
		    $pt = $types->{$co->{with}}->[ $me->{curvestyle} % @{$types->{$co->{with}}} ];
		} else {
		    $pt = $types->{$co->{with}};
		}

		##############################
		# This isn't quite right yet -- it just stacks up plots in the window 
		# if multiple argument blocks are passed in.

		my %plot_args = (-data    => ds::Pair(@$block),
				 plotType => $pt);

		push(@{$me->{widgets}}, 
		     $me->{obj}->insert('Plot',
					pack=>{fill=>'both',expand=>1},
					%plot_args
		     )
		    );

		Prima::Timer->create(
		    onTick=>sub{$_[0]->stop; die "done with event loop\n"},
		    timeout=>50
		    )->start;
		eval { $::application->go };
		die unless $@ =~ /^done with event loop/;
	    }
	}
    } else {
	die "Multiplots not yet supported by P::G::S::Prima -- coming soon...\n";
    }   
}    
    
    
