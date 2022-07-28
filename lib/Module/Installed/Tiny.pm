package Module::Installed::Tiny;

use strict;
use warnings;

use Exporter qw(import);

# AUTHORITY
# DATE
# DIST
# VERSION

our @EXPORT_OK = qw(module_installed module_source);

our $SEPARATOR;
BEGIN {
    if ($^O =~ /^(dos|os2)/i) {
        $SEPARATOR = '\\';
    } elsif ($^O =~ /^MacOS/i) {
        $SEPARATOR = ':';
    } else {
        $SEPARATOR = '/';
    }
}

sub _parse_name {
    my $name = shift;

    my ($name_mod, $name_pm, $name_path);
    # name_mod is Foo::Bar form, name_pm is Foo/Bar.pm form, name_path is
    # Foo/Bar.pm or Foo\Bar.pm (uses native path separator), name_path_prefix is
    # Foo/Bar.

    if ($name =~ m!/|\.pm\z!) {
        # assume it's name_pm form
        $name_pm = $name;
        $name_mod = $name;    $name_mod =~ s/\.pm\z//; $name_mod =~ s!/!::!g;
        $name_path = $name_pm; $name_path =~ s!/!$SEPARATOR!g if $SEPARATOR ne '/';
    } elsif ($SEPARATOR ne '/' && $name =~ m!\Q$SEPARATOR!) {
        # assume it's name_path form
        $name_path = $name;
        ($name_pm = $name_path) =~ s!\Q$SEPARATOR!/!g;
        $name_mod = $name_pm; $name_mod =~ s/\.pm\z//; $name_mod =~ s!/!::!g;
    } else {
        # assume it's name_mod form
        $name_mod = $name;
        ($name_pm  = "$name_mod.pm") =~ s!::!/!g;
        $name_path = $name_pm; $name_path =~ s!/!$SEPARATOR!g if $SEPARATOR ne '/';
    }

    ($name_mod, $name_pm, $name_path);
}

sub module_source {
    my ($name, $opts) = @_;

    $opts //= {};
    $opts->{die} = 1 unless defined $opts->{die};

    my ($name_mod, $name_pm, $name_path) = _parse_name($name);

    my $index = -1;
    for my $entry (@INC) {
        $index++;
        next unless defined $entry;
        my $ref = ref($entry);
        my ($is_hook, @hook_res);
        if ($ref eq 'ARRAY') {
            $is_hook++;
            eval { @hook_res = $entry->[0]->($entry, $name_pm) };
            if ($@) { if ($opts->{die}) { die "Can't locate $name_pm in \@INC (you may need to install the $name_mod module): $entry: $@ (\@INC contains ".join(" ", @INC).")" } else { return } }
        } elsif (UNIVERSAL::can($entry, 'INC')) {
            $is_hook++;
            eval { @hook_res = $entry->INC($name_pm) };
            if ($@) { if ($opts->{die}) { die "Can't locate $name_pm in \@INC (you may need to install the $name_mod module): $entry: $@ (\@INC contains ".join(" ", @INC).")" } else { return } }
        } elsif ($ref eq 'CODE') {
            $is_hook++;
            eval { @hook_res = $entry->($entry, $name_pm) };
            if ($@) { if ($opts->{die}) { die "Can't locate $name_pm in \@INC (you may need to install the $name_mod module): $entry: $@ (\@INC contains ".join(" ", @INC).")" } else { return } }
        } else {
            my $path = "$entry$SEPARATOR$name_path";
            if (-f $path) {
                my $fh;
                unless (open $fh, "<", $path) {
                    if ($opts->{die}) { die "Can't locate $name_pm in \@INC (you may need to install the $name_mod module): $entry: $path: $! (\@INC contains ".join(" ", @INC).")" } else { return }
                }
                local $/;
                return wantarray ? (scalar <$fh>, $path, $entry, $index) : scalar <$fh>;
            } elsif ($opts->{find_prefix}) {
                $name_path =~ s/\.pm\z//;
                if (-d $path) {
                    return wantarray ? (undef, $path, $entry, $index) : \$path;
                }
            }
        }

        if ($is_hook) {
            next unless @hook_res;
            my ($src, $fh, $code);
            eval {
                my $prepend_ref; $prepend_ref = shift @hook_res if ref($hook_res[0]) eq 'SCALAR';
                $fh                           = shift @hook_res if ref($hook_res[0]) eq 'GLOB';
                $code                         = shift @hook_res if ref($hook_res[0]) eq 'CODE';
                my $code_state ; $code_state  = shift @hook_res if @hook_res;
                if ($fh) {
                    my $src = "";
                    local $_;
                    while (!eof($fh)) {
                        $_ = <$fh>;
                        if ($code) {
                            $code->($code, $code_state);
                        }
                        $src .= $_;
                    }
                    $src = $$prepend_ref . $src if $prepend_ref;
                } elsif ($code) {
                    my $src = "";
                    local $_;
                    while ($code->($code, $code_state)) {
                        $src .= $_;
                    }
                    $src = $$prepend_ref . $src if $prepend_ref;
                }
            }; # eval
            if ($@) { if ($opts->{die}) { die "Can't locate $name_pm in \@INC (you may need to install the $name_mod module): $entry: ".($fh || $code).": $@ (\@INC contains ".join(" ", @INC).")" } else { return } }
            return wantarray ? ($src, undef, $entry, $index) : $src;
        } # if $is_hook
    }

    if ($opts->{die}) {
        die "Can't locate $name_pm in \@INC (you may need to install the $name_mod module) (\@INC contains ".join(" ", @INC).")";
    } else {
        return;
    }
}

sub module_installed {
    my ($name, $opts) = @_;

    # convert Foo::Bar -> Foo/Bar.pm
    my ($name_mod, $name_pm, $name_path) = _parse_name($name);

    return 1 if exists $INC{$name_pm};

    my $res = module_source($name, {%{ $opts || {}}, die=>0});
    $res ? 1:0;
}

1;
# ABSTRACT: Check if a module is installed, with as little code as possible

=head1 SYNOPSIS

 use Module::Installed::Tiny qw(module_installed module_source);

 # check if a module is available
 if (module_installed "Foo::Bar") {
     # Foo::Bar is available
 } elsif (module_installed "Foo/Baz.pm") {
     # Foo::Baz is available
 }

 # get a module's source code, dies on failure
 my $src = module_source("Foo/Baz.pm");


=head1 DESCRIPTION

To check if a module is installed (available), generally the simplest way is to
try to C<require()> it:

 if (eval { require Foo::Bar; 1 }) {
     # Foo::Bar is available
 }
 # or
 my $mod_pm = "Foo/Bar.pm";
 if (eval { require $mod_pm; 1 }) {
     # Foo::Bar is available
 }

However, this actually loads the module. There are some cases where this is not
desirable: 1) we have to check a lot of modules (actually loading the modules
will take a lot of CPU time and memory; 2) some of the modules conflict with one
another and cannot all be loaded; 3) the module is OS specific and might not
load under another OS; 4) we simply do not want to execute the module, for
security or other reasons.

C<Module::Installed::Tiny> provides a routine C<module_installed()> which works
like Perl's C<require> but does not actually load the module.

This module does not require any other module except L<Exporter>.


=head1 FUNCTIONS

=head2 module_source

Usage:

 module_source($name [ , \%opts ]) => str | list

Return module's source code, without actually loading/executing it. Module
source will be searched in C<@INC> the way Perl's C<require()> finds modules.
This include executing require hooks in C<@INC> if there are any.

Die on failure (e.g. module named C<$name> not found in C<@INC> or module source
file cannot be read) with the same/similar message as Perl's C<require()>:

 Can't locate Foo/Bar.pm (you may need to install the Foo::Bar module) ...

Module C<$name> can be in the form of C<Foo::Bar>, C<Foo/Bar.pm> or
F<Foo\Bar.pm> (on Windows).

In list context:

 my ($src, $path, $entry, $index) = module_source($name);

where C<$src> (string) is the module source code, C<$path> (string) is
filesystem path (C<undef> if source comes from a require hook), C<$entry> (the
element in C<@INC> where the source comes from), C<$index> (integer, the index
of entry in C<@INC> where the source comes from, 0 means the first entry).

Options:

=over

=item * die

Bool. Default true. If set to false, won't die upon failure but instead will
return undef (or empty list in list context).

=item * find_prefix

Bool. If set to true, when a module (e.g. C<Foo/Bar.pm>) is not found in the
fileysstem but its directory is (C<Foo/Bar/>), then instead of dying or
returning undef/empty list, the function will return:

 \$path

in scalar context, or:

 (undef, $path, $entry, $index)

in list context. In scalar context, you can differentiate path from module
source because the path is returned as a scalar reference. So to get the path:

 $source_or_pathref = module_source("Foo/Bar.pm");
 if (ref $source_or_pathref eq 'SCALAR') {
     say "Path is ", $$source_or_pathref;
 } else {
     say "Module source code is $source_or_pathref";
 }

=back

=head2 module_installed

Usage:

 module_installed($name [ , \%opts ]) => bool

Check that module named C<$name> is available to load, without actually
loading/executing the module. Module will be searched in C<@INC> the way Perl's
C<require()> finds modules. This include executing require hooks in C<@INC> if
there are any.

Note that this does not guarantee that the module can eventually be loaded
successfully, as there might be syntax or runtime errors in the module's source.
To check for that, one would need to actually load the module using C<require>.

Module C<$name> can be in the form of C<Foo::Bar>, C<Foo/Bar.pm> or
F<Foo\Bar.pm> (on Windows).

Options:

=over

=item * find_prefix

See L</module_source> documentation.

=back


=head1 FAQ

=head2 How to get module source without dying? I want to just get undef if module source is not available.

Set the C<die> option to false:

 my $src = module_source($name, {die=>0});

This is what C<module_installed()> does.

=head2 How to know which @INC entry the source comes from?

Call the L</module_source> in list context, where you will get more information
including the entry. See the function documentation for more details.


=head1 SEE ALSO

L<Module::Load::Conditional> provides C<check_install> which also does what
C<module_installed> does, plus can check module version. It also has a couple
other knobs to customize its behavior. It's less tiny than
Module::Installed::Tiny though.

L<Module::Path> and L<Module::Path::More>. These modules can also be used to
check if a module on the filesystem is available. They do not handle require
hooks, nor do they actually check that the module file is readable.

=cut
