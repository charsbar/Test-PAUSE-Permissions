package Test::PAUSE::Permissions;

use strict;
use warnings;
use parent 'Exporter';
use Test::More;
use PAUSE::Permissions;
use Parse::LocalDistribution;

our $VERSION = '0.04';

our @EXPORT = (@Test::More::EXPORT, qw/all_permissions_ok/);

sub all_permissions_ok {
  my $author = shift;

  plan skip_all => 'Set RELEASE_TESTING environmental variable to test this.' unless $ENV{RELEASE_TESTING};

  # Get your id from .pause
  $author ||= _get_pause_user();

  plan skip_all => "Can't determine who is going to release." unless $author;

  # Get authority from META
  my $meta_authority ||= _get_authority_in_meta();

  # Prepare 06perms for testing
  my $perms = PAUSE::Permissions->new;

  # Get packages (respecting no_index)
  my $provides = Parse::LocalDistribution->new->parse();

  # Iterate
SKIP:
  for my $package (keys %$provides) {
    my $authority = uc(
      $meta_authority
      || _get_authority_in_file($package, $provides->{$package})
      || $author
      || ''
    );

    my $mp = $perms->module_permissions($package);

    if (!$mp) {
      pass "$package: no one has permissions ($authority should have the first come)";
      next;
    }
    my @maintainers = $mp->all_maintainers;

    # Author should have permissions, regardless of the authority
    if (grep { uc $_ eq uc $author } @maintainers) {
      pass "$package: $author has a permission";
    }
    else {
      fail "$package: maintained by ".join ', ', @maintainers;
    }
  }

  done_testing;
}

sub _get_pause_user {
  # Get authority from ~/.pause
  require Config::Identity::PAUSE;
  my %config = Config::Identity::PAUSE->load;
  return $config{user};
}

sub _get_authority_in_meta {
  # Get authority from META
  my $meta = _parse_meta();
  if ($meta && $meta->{x_authority}) {
    my $authority = $meta->{x_authority};
    $authority =~ s/^cpan://i;
    return $authority;
  }
}

sub _parse_meta {
  for my $file (qw/META.json META.yml/) {
    next unless -f $file && -r _;
    my $meta = Parse::CPAN::Meta->load_file($file);
    return $meta if $meta && ref $meta eq ref {};
  }
}

sub _get_authority_in_file {
  my ($package, $package_info) = @_;
  my $file = $package_info->{infile};
  return unless $file && -f $file && -r _;

  open my $fh, '<', $file or return;
  my $in_pod = 0;
  while(<$fh>) {
    last if /__(DATA|END)__/;
    $in_pod = /^=(?!cut?)/ ? 1 : /^=cut/ ? 0 : $in_pod;
    next if $in_pod;

    if (/\$(?:${package}::)?AUTHORITY\s*=.+?(?i:cpan):([A-Za-z0-9]+)/) {
      return $1;
    }
  }
}

1;

__END__

=head1 NAME

Test::PAUSE::Permissions - tests module permissions in your distribution

=head1 SYNOPSIS

    # in your xt/perms.t

    use Test::PAUSE::Permissions;
    
    all_permissions_ok();

=head1 DESCRIPTION

This module is to test if modules in your distribution have proper
permissions or not. You need to set RELEASE_TESTING to test this.

You might also want to prepare .pause file (you should have one to
release distributions anyway).

=head1 FUNCTION

This module exports only one function (yet):

=head2 all_permissions_ok

Looks for packages with L<Parse::LocalDistribution>, and tests
if you (or the registered author) have proper permissions for them
by L<PAUSE::Permissions>, which downloads C<06perms.txt> from CPAN
before testing.

By default, C<all_permissions_ok> looks into C<.pause> file
to find who is releasing the distribution.

You can also pass the author as an argument, though this is only
useful when you generate this test every time you release a
distribution.

    use Test::PAUSE::Permissions;
    
    # assumes ISHIGAKI is going to release the distribution
    all_permissions_ok('ISHIGAKI');

C<all_permissions_ok> also looks into META files for <x_authority>,
and each .pm file for C<$AUTHORITY> variable, for your information.

=head1 SEE ALSO

L<PAUSE::Permissions>, L<App::PAUSE::CheckPerms>

=head1 AUTHOR

Kenichi Ishigaki, E<lt>ishigaki@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Kenichi Ishigaki.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut
