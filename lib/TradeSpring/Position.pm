package TradeSpring::Position;
use Moose;
use Method::Signatures::Simple;

has broker => (is => "ro", isa => "TradeSpring::Broker");

has status => (is => "rw", isa => "Str");

has order => (is => "rw", isa => "HashRef");

has on_entry => (is => "rw", isa => "CodeRef");
has on_error => (is => "rw", isa => "CodeRef");
has on_exit => (is => "rw", isa => "CodeRef");

has direction => (is => "ro", isa => "Int");

has entry_id => (is => "rw", isa => "Maybe[Str]");
has stp_id => (is => "rw", isa => "Str");
has tp_id => (is => "rw", isa => "Str");


method _submit_order($type, $order) {
    $self->broker->register_order(
        $order,
        on_ready => sub { },
        on_match => sub {
            $self->on_exit->($self, $type, @_);
        },
        on_summary => sub {
        });
}

method create ($entry, $stp, $tp) {

    my $entry_order = { %$entry, dir => $self->direction };

    $self->entry_id(
        $self->broker->register_order
            ($entry_order,
             on_match => sub {
                 my ($price, $qty) = @_;
                 my ($stp_order, $exit_order);
                 $self->on_entry->($self, @_);
             },
             on_ready => sub {
                 my $parent = shift;
                 $self->status('submitted');
                 warn $parent;
                 if ($stp && !$self->stp_id) {
                     my $stp_order = { %$stp,
                                       dir => $self->direction * -1,
                                       attached_to => $parent,
                                       oca_group => $parent };
                     $stp_order->{type} ||= 'stp';
                     $stp_order->{qty} ||= $entry_order->{qty};

                     $self->stp_id($self->_submit_order('stp', $stp_order));
                 }
                 if ($tp && !$self->tp_id) {
                     my $tp_order = { %$tp,
                                      dir => $self->direction * -1,
                                      attached_to => $parent,
                                      oca_group => $parent };
                     $tp_order->{type} ||= 'lmt';
                     $tp_order->{qty} ||= $entry_order->{qty};

                     $self->stp_id($self->_submit_order('tp', $tp_order));
                 }
             },
             on_summary => sub {
                 if ($_[0]) {
                     my $o = $self->broker->get_order($self->entry_id);
                     $self->status('entered');
                     warn $o->{order}{dir}. ' '.$o->{order}{price}.' @ '.$o->{last_fill_time};
                 }
             }));
}

method cancel {
    $self->broker->cancel_order( $self->entry_id, sub { warn 'cancelled' });
    $self->entry_id(undef);
}

__PACKAGE__->meta->make_immutable;
no Moose;
1;
