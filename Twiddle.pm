package Term::Twiddle;

use 5.005;
use strict;
use vars qw( @ISA $VERSION );

$VERSION = '2.61';

use Time::HiRes qw(setitimer ITIMER_REAL);
$SIG{'ALRM'} = \&_spin;
$SIG{'INT'} = $SIG{'TERM'} = \&_set_alarm(0);

my ( $thingy, $rate, $probability, $stream, $step );

sub new {
    my $self  = {};
    my $proto = shift;
    my $class = ref($proto) || $proto;
    bless $self, $class;

    $self->init(shift);

    return $self;
}

sub init {
    my $self = shift;
    my $args = shift;

    $self->thingy( ( $args->{'thingy'} ? $args->{'thingy'} : [ "\\", "|", "/", "-" ] ) );
    $self->rate( ( $args->{'rate'}   ? $args->{'rate'}   : 0.175 ) );
    $self->probability( ( $args->{'probability'} ? $args->{'probability'} : 0 ) );
    $self->stream( ( $args->{'stream'} ? $args->{'stream'} : *STDOUT ) );

    $step        = 0;
}

sub start {
    my $self = shift;
    _set_alarm( $rate );
}

sub stop {
    my $self = shift;
    _set_alarm(0);
}

sub thingy {
    my $self       = shift;
    my $new_thingy = shift;
    $step = 0;

    return $thingy = ( $new_thingy
		       ? $new_thingy
		       : $thingy );
}

sub rate {
    my $self     = shift;
    my $new_rate = shift;

    return $rate = ( defined $new_rate
		     ? $new_rate
		     : $rate );
}

sub probability {
    my $self     = shift;
    my $new_prob = shift;

    return $probability = ( defined $new_prob
			    ? $new_prob
			    : $probability );
}

sub stream {
    my $self       = shift;
    my $new_stream = shift;

    return $stream = ( defined $new_stream
		       ? $new_stream
		       : $stream );
}

sub random {
    my $self = shift;
    my $prob = shift;
    $prob = ( defined $prob ? $prob : 25 );
    $self->probability($prob);
}

## send me a SIGALRM in this many seconds (fractions ok)
sub _set_alarm {
    return setitimer(ITIMER_REAL, shift, 0);
}

sub _spin {

  SPIN: {
	my $old_fh = select($stream);
	local $| = 1;
	print $stream $$thingy[$step],
	  chr(8) x length($$thingy[$step]);
	select($old_fh);
    }

    $step = ( $step+1 > $#$thingy ? 0 : $step+1 );

    ## randomize if required
    $rate = rand(0.2)
      if $probability && (rand() * 100) < $probability;

    $SIG{'ALRM'} = \&_spin;
    _set_alarm( $rate );
}

1;
__END__

=head1 NAME

Term::Twiddle - Twiddles a thingy while-u-wait

=head1 SYNOPSIS

  use Term::Twiddle;
  my $spinner = new Term::Twiddle;

  $spinner->start;
  system('tar', '-xvf', 'some_phat_tarfile.tar');
  $spinner->stop;

  $spinner->random;  ## makes it appear to really struggle at times!
  $spinner->start;
  &some_long_function();
  $spinner->stop;

=head1 DESCRIPTION

Always fascinated by the spinner during FreeBSD's loader bootstrap,
I wanted to capture it so I could view it any time I wanted to--and I
wanted to make other people find that same joy I did. Now, anytime you
or your users have to wait for something to finish, instead of
twiddling their thumbs, they can watch the computer twiddle its thumbs.

=head2 During Twiddling

Once the twiddler/spinner is in motion you need to do something (e.g.,
unpack a tar file, call some long function, etc.). You can do almost
anything in between B<start> and B<stop> as long as there are no
B<sleep> calls in there (unless the process has been forked, as in a
Perl B<system> call). From Time::HiRes:

    Use of interval timers may interfere with alarm(), sleep(), and
    usleep().  In standard-speak the "interaction is unspecified",
    which means that anything may happen: it may work, it may not.

Try not to do any terminal I/O while the twiddler is going (unless you
don't mind dragging the twiddler around with your cursor).

=head2 Methods

=over 4

=item B<new>

Creates a new Twiddle object:

    my $spinner = new Term::Twiddle;

Optionally initializes the Twiddle object:

    ## a moderately paced spinner
    my $spinner = new Term::Twiddle( { rate => 0.075 } );

=item B<start>

Starts the twiddler twiddling:

    $spinner->start;

=item B<stop>

Stops the twiddler:

    $spinner->stop;

=item B<thingy>

Creates a new thingy. The argument is a reference to a list of strings
to print (usually single characters) so that animation looks good. The
default spinner sequence looks like this:

    $spinner->thingy( [ "\\", "|", "/", "-" ] );

an arrow could be done like this:
    $spinner->thingy( [
                       "---->",
                       " ----->",
                       "  ----->",
                       "   ----->",
                       "    ----->|",
                       "     ---->|",
                       "      --->|",
                       "       -->|",
                       "        ->|",
                       "         >|",
                       "          |",
                       "           "]);


Look at the test.pl file for this package for more fun thingy ideas.

=item B<rate>

Changes the rate at which the thingy is changing (e.g., spinner is
spinning). This is the time to wait between thingy characters (or
"frames") in seconds. Fractions of seconds are supported. The default
rate is 0.175 seconds.

    $spinner->rate(0.075);  ## faster!

=item B<probability>

Determines how likely it is for each step in the thingy's motion to
change rate of change. That is, each time the thingy advances in its
sequence, a random number from 1 to 100 is generated. If
B<probability> is set, it is compared to the random number. If the
probability is greater than or equal to the randomly generated number,
then a new rate of change is randomly computed (between 0 and 0.2
seconds). 

In short, if you want the thingy to change rates often, set
B<probability> high. Otherwise set it low. If you don't want the rate
to change ever, set it to 0 (zero). 0 is the default.

    ## half of all sequence changes will result in a new rate of change
    $spinner->probability(50);
    $spinner->start;
    do_something;
    $spinner->stop;

The purpose of this is to create a random rate of change for the
thingy, giving the impression that whatever the user is waiting for
is certainly doing a lot of work (e.g., as the rate slows, the
computer is working harder, as the rate increases, the computer is
working very fast. Either way your computer looks good!).

=item B<random>

Invokes the B<probability> method with the argument specified. If no
argument is specified, 25 is the default value. This is meant as a
short-cut for the B<probability> method.

    $spinner->random;

=item B<stream>

Select an alternate stream to print on. By default, STDOUT is printed to.

    $spinner->stream(*STDERR);

=back

=head1 EXAMPLES

    ## show the user something while we unpack the archive
    my $sp = new Term::Twiddle;
    $sp->random;
    $sp->start;
    system('tar', '-zxf', '/some/tarfile.tar.gz');
    $sp->stop;

=head1 AUTHOR

Scott Wiersdorf, E<lt>scott@perlcode.orgE<gt>

=head1 CAVEATS

=over 4

=item *

Prolly won't run on platforms lacking B<setitimer> (Adam Klaum
reported this "caveat"). This would include at least Win32, I think.
Patches/alternative methods welcome. Send me a Win32 box if you want
me to test it out first. For good measure, also send an iMac--they're
sooo cute!

=back

=head1 ACKNOWLEDGEMENTS

=over 4

=item *

Thanks to Tom Christiansen for the timer code (found lurking in an old
FAQ somewhere). He probably never had an idea that it would be part of
one of the most useful modules on CPAN ;o)

The timer code has since been replaced by B<Time::HiRes>'s
B<setitimer> function, but it is good to thank Mr. Christiansen for
his goodness to Perl anyway.

=item *

"Drew" (drew@drewtaylor.com) from rt.cpan.org for suggesting the
removal of 'use warnings' for the faithful 5.005 users.

=back

=head1 SEE ALSO

L<perl>.

=cut
