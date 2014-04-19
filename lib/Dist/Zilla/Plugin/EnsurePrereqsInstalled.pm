use strict;
use warnings;
package Dist::Zilla::Plugin::EnsurePrereqsInstalled;
# ABSTRACT: Ensure at build time that all prereqs, including developer, are satisfied
# vim: set ts=8 sw=4 tw=78 et :

use Moose;
with
    'Dist::Zilla::Role::BeforeBuild',
    'Dist::Zilla::Role::AfterBuild';

use CPAN::Meta 2.120920;
use CPAN::Meta::Check 0.007 'check_requirements';
use namespace::autoclean;

sub before_build
{
    my $self = shift;

    $self->log_debug('checking that all authordeps are satisfied...');
    if (my $unsatisfied = $self->_get_authordeps)
    {
        $self->log_fatal(join "\n",
            'Unsatisfied authordeps:',
            $unsatisfied,
            'To remedy, do:  cpanm ' . join(' ', split("\n", $unsatisfied)),
        );
    }
}

sub after_build
{
    my $self = shift;

    $self->log_debug("checking that all prereqs are satisfied...");

    my $prereqs_data = $self->zilla->distmeta->{prereqs};
    my $prereqs = $self->zilla->prereqs->cpan_meta_prereqs;

    # returns: { module name => diagnostic, ... }
    my $requires_result = check_requirements(
        $prereqs->merged_requirements([ keys %$prereqs_data ], ['requires']),
        'requires',
    );
    if (my @unsatisfied = sort grep { defined $requires_result->{$_} } keys %$requires_result)
    {
        $self->log_fatal(join "\n",
            'Unsatisfied prerequisites:',
            (map { '    ' . $requires_result->{$_} } @unsatisfied),
            'To remedy, do:  cpanm ' . join(' ', @unsatisfied),
        );
    }

    my $conflicts_result = check_requirements(
        $prereqs->merged_requirements([ keys %$prereqs_data ], ['conflicts']),
        'conflicts',
    );
    if (my @conflicts = sort grep { defined $conflicts_result->{$_} } keys %$conflicts_result)
    {
        $self->log_fatal(join "\n",
            'Conflicts found:',
            (map { '    ' . $conflicts_result->{$_} } @conflicts),
            'To remedy, do:  pm-uninstall ' . join(' ', @conflicts),
        );
    }


    if (my $x_breaks = $self->zilla->distmeta->{x_breaks})
    {
        $self->log_debug('checking x_breaks...');

        my $reqs = CPAN::Meta::Requirements->new;
        $reqs->add_string_requirement($_, $x_breaks->{$_}) foreach keys %$x_breaks;

        my $result = check_requirements($reqs, 'conflicts');

        if (my @breaks = sort grep { defined $result->{$_} } keys %$result)
        {
            $self->log_fatal(join "\n",
                'Breakages found:',
                (map { '    ' . $result->{$_} } @breaks),
                'To remedy, do:  cpanm ' . join(' ', @breaks),
            );
        }
    }
}

sub _get_authordeps
{
    my $self = shift;

    require Dist::Zilla::Util::AuthorDeps;
    require Path::Class;
    Dist::Zilla::Util::AuthorDeps::format_author_deps(
        Dist::Zilla::Util::AuthorDeps::extract_author_deps(
            Path::Class::dir('.'),  # ugh!
            1,                      # --missing
        ),
        (),                         # --versions
    );
}

__PACKAGE__->meta->make_immutable;
__END__

=pod

=head1 SYNOPSIS

In your F<dist.ini>:

    [EnsurePrereqsInstalled]

=head1 DESCRIPTION

This is a L<Dist::Zilla> plugin that verifies, during the C<dzil build>
process, that all required prerequisites are satisfied, including developer
prereqs.  If any prerequisites are missing, the build is aborted.

=for stopwords Authordeps

Authordeps (developer prerequisites that can be extracted directly from
F<dist.ini>) are checked at the start of the build. This would be equivalent
to calling C<dzil authordeps --missing>.

All prerequisites are fetched from the distribution near the end of the build
and a final validation check is performed at that time.

Only 'requires', 'conflicts' and 'x_breaks' prerequisites are checked; other
types (e.g. 'recommends' and 'suggests' are ignored).

=head1 BACKGROUND

This plugin was written for a distribution that does some fiddly work during
file munging time that required the installation of a module, specified as an
C<; authordep> in F<dist.ini>.  When the module is missing, an ugly exception
is printed, without a clear explanation that this module was a developer
prerequisite that ought to have been installed first.

It is this author's opinion that this check out to be performed by
L<Dist::Zilla> itself, rather than leaving it to an optional plugin.

=head1 CONFIGURATION OPTIONS

There are no options at this time.

=for Pod::Coverage before_build after_build

=head1 POTENTIAL FEATURES

...if anyone has an interest:

=begin :list

* option to exclude modules from being checked
* option to prompt to continue instead of dying on unsatisfied prereqs
* option for different treatment (warn? prompt?) for recommended, suggested prereqs

=end :list

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Plugin-EnsurePrereqsInstalled>
(or L<bug-Dist-Zilla-Plugin-EnsurePrereqsInstalled@rt.cpan.org|mailto:bug-Dist-Zilla-Plugin-EnsurePrereqsInstalled@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 SEE ALSO

These plugins all do somewhat similar and overlapping things, but are all useful in their own way:

=begin :list

* L<Dist::Zilla::Plugin::PromptIfStale>
* L<Dist::Zilla::Plugin::CheckPrereqsIndexed>
* L<Dist::Zilla::Plugin::Test::ReportPrereqs>
* L<Dist::Zilla::Plugin::Test::CheckDeps>
* L<Dist::Zilla::Plugin::Test::CheckBreaks>

=end :list

=cut
