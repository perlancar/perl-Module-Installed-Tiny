#!perl

use strict;
use warnings;
use Test::More 0.98;

use File::Temp qw(tempdir);
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
    {
        my $tempdir = tempdir(CLEANUP => $ENV{DEBUG} ? 0:1);
        note "tempdir=$tempdir";
        my $rand = int(rand()*9000)+1000;
        mkdir "$tempdir/Foo";
        open my $fh, ">", "$tempdir/Foo/Bar$rand.pm" or die;
        print $fh "package Foo::Bar$rand;\n1;\n";
        close $fh;

        local @INC = (@INC, $tempdir);
        my @res = module_source("Foo::Bar$rand");
        my $sep = $Module::Installed::Tiny::SEPARATOR;
        is_deeply(\@res, [
            "package Foo::Bar$rand;\n1;\n",
            "$tempdir${sep}Foo${sep}Bar$rand.pm",
            $tempdir,
            $#INC,
            "Foo::Bar$rand",
            "Foo/Bar$rand.pm",
            "Foo${sep}Bar$rand.pm",
        ]);
    }

    # XXX option: die

    # option: find_prefix. this is assuming Module.pm does not exist
    subtest "opt: find_prefix" => sub {
        my ($source, $path) = module_source("Module", {die=>0});
        is_deeply($source, undef);
        is_deeply($path, undef);

        ($source, $path) = module_source("Module", {die=>0, find_prefix=>1});
        is_deeply($source, undef);
        note "path=$path";
        ok($path);

        $path = module_source("Module", {die=>0, find_prefix=>1});
        is(ref $path, 'SCALAR');
        note "path=\\ ".$$path;
    };

};

done_testing;
