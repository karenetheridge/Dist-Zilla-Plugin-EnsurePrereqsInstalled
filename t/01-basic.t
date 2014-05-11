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
                [ EnsurePrereqsInstalled => ],
                [ Prereqs => {
                        'I::Am::Not::Installed' => 0,
                        'Test::More' => '200.0',
                        'perl' => '500',
                    },
                ],
                [ Prereqs => TestRecommends => { 'Something::Else' => '400.0' } ],
            ),
            path(qw(source lib Foo.pm)) => "package Foo;\n1;\n",
        },
    },
);

$tzil->chrome->logger->set_debug(1);

like(
    exception { $tzil->build },
    qr/^\Q[EnsurePrereqsInstalled] Unsatisfied\E/m,
    'build aborted',
);

cmp_deeply(
    $tzil->log_messages,
    superbagof(
        '[EnsurePrereqsInstalled] checking that all authordeps are satisfied...',
        '[EnsurePrereqsInstalled] checking that all prereqs are satisfied...',
        "[EnsurePrereqsInstalled] Unsatisfied prerequisites:
[EnsurePrereqsInstalled]     Module 'I::Am::Not::Installed' is not installed
[EnsurePrereqsInstalled]     Installed version ($Test::More::VERSION) of Test::More is not in range \'200.0\'
[EnsurePrereqsInstalled]     Installed version ($]) of perl is not in range \'500\'
[EnsurePrereqsInstalled] To remedy, do:  cpanm I::Am::Not::Installed Test::More
[EnsurePrereqsInstalled] And update your perl!",
    ),
    'build was aborted, with remedy instructions',
) or diag 'got log messages: ', explain $tzil->log_messages;

done_testing;
