package Module::Installed::Tiny;

# DATE
# VERSION

use strict;
use warnings;

use Exporter qw(import);
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

sub _module_source {
    my $name_pm = shift;

    for my $entry (@INC) {
        next unless defined $entry;
        my $ref = ref($entry);
        my ($is_hook, @hook_res);
        if ($ref eq 'ARRAY') {
            $is_hook++;
            @hook_res = $entry->[0]->($entry, $name_pm);
        } elsif (UNIVERSAL::can($entry, 'INC')) {
            $is_hook++;
            @hook_res = $entry->INC($name_pm);
        } elsif ($ref eq 'CODE') {
            $is_hook++;
            @hook_res = $entry->($entry, $name_pm);
        } else {
            my $path = "$entry$SEPARATOR$name_pm";
            if (-f $path) {
                open my($fh), "<", $path
                    or die "Can't locate $name_pm: $path: $!";
                local $/;
                return wantarray ? (scalar <$fh>, $path) : scalar <$fh>;
            }
        }

        if ($is_hook) {
            next unless @hook_res;
            my $prepend_ref; $prepend_ref = shift @hook_res if ref($hook_res[0]) eq 'SCALAR';
            my $fh         ; $fh          = shift @hook_res if ref($hook_res[0]) eq 'GLOB';
            my $code       ; $code        = shift @hook_res if ref($hook_res[0]) eq 'CODE';
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
                return wantarray ? ($src, $entry) : $src;
            } elsif ($code) {
                my $src = "";
                local $_;
                while ($code->($code, $code_state)) {
                    $src .= $_;
                }
                $src = $$prepend_ref . $src if $prepend_ref;
                return wantarray ? ($src, $entry) : $src;
            }
        }
    }

    die "Can't locate $name_pm in \@INC (\@INC contains: ".join(" ", @INC).")";
}

sub module_source {
    my $name = shift;

    # convert Foo::Bar -> Foo/Bar.pm
    my $name_pm;
    if ($name =~ /\A\w+(?:::\w+)*\z/) {
        ($name_pm = "$name.pm") =~ s!::!$SEPARATOR!g;
    } else {
        $name_pm = $name;
    }

    _module_source $name_pm;
}

sub module_installed {
    my $name = shift;

    # convert Foo::Bar -> Foo/Bar.pm
    my $name_pm;
    if ($name =~ /\A\w+(?:::\w+)*\z/) {
        ($name_pm = "$name.pm") =~ s!::!$SEPARATOR!g;
    } else {
        $name_pm = $name;
    }

    return 1 if exists $INC{$name_pm};

    if (eval { _module_source $name_pm; 1 }) {
        1;
    } else {
        0;
    }
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

=head2 module_installed($name) => bool

Check that module named C<$name> is available to load. This means that: either
the module file exists on the filesystem and searchable in C<@INC> and the
contents of the file can be retrieved, or when there is a require hook in
C<@INC>, the module's source can be retrieved from the hook.

Note that this does not guarantee that the module can eventually be loaded
successfully, as there might be syntax or runtime errors in the module's source.
To check for that, one would need to actually load the module using C<require>.

=head2 module_source($name) => str | (str, source_name)

Return module's source code, without actually loading it. Die on failure (e.g.
module named C<$name> not found in C<@INC>).

In list context:

 my @res = module_source($name);

will return the list:

(str, source_name)

where C<str> is the module source code and C<source_name> is source information
(file path, or the @INC ref entry when entry is a ref).


=head1 SEE ALSO

L<Module::Load::Conditional> provides C<check_install> which also does what
C<module_installed> does, plus can check module version. It also has a couple
other knobs to customize its behavior. It's less tiny than
Module::Installed::Tiny though.

L<Module::Path> and L<Module::Path::More>. These modules can also be used to
check if a module on the filesystem is available. They do not handle require
hooks, nor do they actually check that the module file is readable.

=cut
