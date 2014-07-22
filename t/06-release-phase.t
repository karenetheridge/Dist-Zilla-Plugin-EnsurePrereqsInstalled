
use strict;
use warnings FATAL => 'all';

use Test::More;
use if $ENV{AUTHOR_TESTING}, 'Test::Warnings';
use Test::DZil;
use Test::Fatal;
use Test::Deep;
use Path::Tiny;

my $tzil = Builder->from_config(
    { dist_root => 't/does-not-exist' },
    {
        add_files => {
            path(qw(source dist.ini)) => simple_ini(
                [ GatherDir => ],
                [ EnsurePrereqsInstalled => { build_phase => 'release' } ],
                [ Prereqs => {
                        'I::Am::Not::Installed' => 0,
                        'Test::More' => '200.0',
                        'perl' => '500',
                    },
                ],
                [ Prereqs => TestRecommends => { 'Something::Else' => '400.0' } ],
                [ FakeRelease => ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
        },
    },
);

$tzil->chrome->logger->set_debug(1);

is (
    exception { $tzil->build },
    undef,
    'build proceeds normally',
);

like(
    exception { $tzil->release },
    qr/^\Q[EnsurePrereqsInstalled] Unsatisfied\E/m,
    'release aborted',
);

# allow for dev releases - Module::Metadata includes _, but $VERSION does not.
my $TM_VERSION = join '_?', split //, $Test::More::VERSION;

cmp_deeply(
    $tzil->log_messages,
    superbagof(
        '[EnsurePrereqsInstalled] checking that all authordeps are satisfied...',
        '[EnsurePrereqsInstalled] checking that all prereqs are satisfied...',
        re(qr/^\Q[EnsurePrereqsInstalled] Unsatisfied prerequisites:
[EnsurePrereqsInstalled]     Module 'I::Am::Not::Installed' is not installed
[EnsurePrereqsInstalled]     Installed version (\E$TM_VERSION\Q) of Test::More is not in range '200.0'
[EnsurePrereqsInstalled]     \E(Installed version \($]\) of perl is not in range '500'|Your Perl \($]\) is not in the range '500')\Q
[EnsurePrereqsInstalled] To remedy, do:  cpanm I::Am::Not::Installed Test::More
[EnsurePrereqsInstalled] And update your perl!\E$/ms),
    ),
    'release was aborted: checks delayed until the release phase',
) or diag 'got log messages: ', explain $tzil->log_messages;

done_testing;
