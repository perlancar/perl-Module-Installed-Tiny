#!perl

use strict;
use warnings;
use Test::More 0.98;

use Module::Installed::Tiny qw(module_source module_installed);

subtest module_installed => sub {
    ok( module_installed("Test::More"), "already loaded -> true");
    ok( module_installed("Test/More.pm"), "Foo/Bar.pm-style accepted");
    ok( module_installed("if"), "'if' is installed");
    ok(!exists($INC{"if.pm"}), "if.pm is not actually loaded");
    ok(!module_installed("Local::Foo"), "not found on filesystem -> false");
};

subtest module_source => sub {
    like(module_source("if"), qr/package if/);

    # list context
    my ($source, $path) = module_source("if");
    like($source, qr/package if/);
    diag "path=$path";
    ok($path);

    # XXX option: die

    # option: find_prefix. this is assuming Module.pm does not exist
    subtest "opt: find_prefix" => sub {
        ($source, $path) = module_source("Module", {die=>0});
        is_deeply($source, undef);
        is_deeply($path, undef);

        ($source, $path) = module_source("Module", {die=>0, find_prefix=>1});
        is_deeply($source, undef);
        diag "path=$path";
        ok($path);

        $path = module_source("Module", {die=>0, find_prefix=>1});
        is(ref $path, 'SCALAR');
        diag "path=\\ ".$$path;
    };

};

done_testing;
